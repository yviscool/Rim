#Requires AutoHotkey v2.0

; === VimEngine - 核心Vim引擎 ===
; 管理窗口、模式、热键映射、Action执行

; 文件对话框输入保护谓词 (纯逻辑, 探针直测; WinAPI 由 KeyHandler 采集后传入):
; #32770 且焦点在输入控件 (文件名框等) 时透传, 其他一律不管.
; 注意: 只认窗类, 不认控件白名单之外的东西; Notepad 主窗 (类名非 #32770) 不受影响,
; TCDialog 不依赖窗内映射 (定时器偷焦点), 也不受影响.
DialogShouldPassthrough(winClass, ctrlClass, ctrlNN) {
    if (winClass != "#32770")
        return false
    try {
        if (IsSet(RimContext) && IsObject(RimContext)) {
            if (RimContext.CheckIsInput(ctrlClass, ctrlNN, winClass))
                return true
        }
    }
    ; #32770 专属放宽: 文件名组合框/类型下拉本身也可打字筛选, 同样透传
    ; (CheckIsInput 不认 Combo 系, 此处补; 其他窗类不受影响)
    if (ctrlClass = "ComboBox" || ctrlClass = "ComboBoxEx32")
        return true
    ; 控件 NN 匹配: 静态前缀 + 全数字后缀 (原两处 RegExMatch, 热路径省正则编译)
    nn := StrLower(String(ctrlNN))
    if (_DlgNnKind(nn, "combobox") > 0)
        return true
    ; RimContext 不可用 (探针/早期) 时的 Edit 兜底
    if (ctrlClass = "Edit")
        return true
    if (_DlgNnKind(nn, "edit") = 2)
        return true
    return false
}

; 控件 NN 形态判定 (DialogShouldPassthrough 专用, 无正则):
; 0=不匹配, 1=裸名相等 ("combobox"), 2=前缀+全数字后缀 ("edit1").
; 原语义: ComboBox 系裸名/带数字全透传; Edit 系仅类名或带数字 NN 透传 (裸 "Edit" NN 不透传).
_DlgNnKind(nn, prefix) {
    if (nn = prefix)
        return 1
    if (SubStr(nn, 1, StrLen(prefix)) != prefix)
        return 0
    rest := SubStr(nn, StrLen(prefix) + 1)
    if (rest = "")
        return 0
    Loop Parse, rest {
        if (A_LoopField < "0" || A_LoopField > "9")
            return 0
    }
    return 2
}

; 单次活动窗口上下文采集 (KeyHandler 入口唯一 WinAPI 批量点):
; 一次拿齐 hwnd/类名/进程路径+名/焦点控件, 后续守卫与 CheckWin 全复用, 不再各自重查.
; 每个查询独立 try, 失败字段回空/0, 永不抛错.
EngineCollectCtx() {
    ctx := Map("hwnd", 0, "class", "", "procPath", "", "procName", "", "focus", 0, "focusClass", "", "focusNN", "")
    try ctx["hwnd"] := WinExist("A")
    catch {
    }
    try ctx["class"] := WinGetClass("A")
    catch {
    }
    try ctx["procPath"] := WinGetProcessPath("A")
    catch {
    }
    try ctx["procName"] := WinGetProcessName("A")
    catch {
    }
    try ctx["focus"] := ControlGetFocus("A")
    catch {
    }
    if (ctx["focus"]) {
        try ctx["focusClass"] := ControlGetClass(ctx["focus"])
        catch {
        }
        try ctx["focusNN"] := ControlGetClassNN(ctx["focus"])
        catch {
        }
    }
    return ctx
}

; IME 组字判定 (hwnd 由调用方传入, KeyHandler 复用 ctx["hwnd"] 不再重查):
; 有组字串 (GCS_COMPSTR 非空) 即组字中. headless/无 IME/控制台/提权窗恒回假.
ImeComposingAt(hwndA) {
    try {
        if (!hwndA)
            return false
        hImc := DllCall("imm32\ImmGetContext", "Ptr", hwndA, "Ptr")
        if (!hImc)
            return false
        len := 0
        try len := DllCall("imm32\ImmGetCompositionStringW", "Ptr", hImc, "UInt", 0x0008, "Ptr", 0, "UInt", 0, "Int")
        catch {
            len := 0
        }
        try DllCall("imm32\ImmReleaseContext", "Ptr", hwndA, "Ptr", hImc)
        catch {
        }
        return len > 0
    } catch {
    }
    return false
}

ImeComposing() {
    hwndA := 0
    try hwndA := WinExist("A")
    catch {
    }
    return ImeComposingAt(hwndA)
}

; 自家进程判定 (纯逻辑可单测): 进程路径等于自身解释器/编译体即自家窗口
; (配置中心/手势UI/QR 等子窗, SelfWinTitle 只保主窗, 这里兜全)
IsSelfProcessPath(p) {
    if (p = "")
        return false
    try {
        mine := A_IsCompiled ? A_ScriptFullPath : A_AhkPath
        return p = mine
    } catch {
    }
    return false
}

; 多键前缀预检 (KeyHandler 前缀分支调用, 纯逻辑可单测):
; BeforeActionDo("", win) 为真即应透传. 存在理由: 前缀键 (g/<C-w>/空格前缀等)
; 走不到动作期回调, 会被 KeyTemp 吞掉出提示菜单 (Explorer 重命名框按 g 即此;
; TC 当年同坑靠 PreKeyFilter 绕过, 见 TotalCommander.ahk 注释). 现有两实现
; (Explorer_ForceInsertMode/TC_BeforeActionDo) 均忽略 actionName, 空串调用安全.
EngineShouldPassthroughPrefix(win, globalBefore) {
    try {
        bf := ""
        try bf := win.BeforeActionDoFunc
        catch {
        }
        if (!IsObject(bf))
            bf := globalBefore
        if (IsObject(bf)) {
            if bf("", win)
                return true
        }
    } catch {
    }
    return false
}

class VimEngine {
    PluginList := Map()
    WinList := Map()
    ActionList := Map()
    ExcludeWinList := Map()
    ActionFromPlugin := Map()
    winGlobal := ""
    debugMode := false
    lastAction := ""
    ; 窗口注册表版本: SetWin/DeleteWin 递增, CheckWin 缓存按此失效 (同 hwnd 下新注册窗不命中旧缓存)
    winEpoch := 0
    ; 自家启动器窗口标题: 激活时直接透传, 不进 vim 分发 (输入框打字安全)
    SelfWinTitle := ""

    ; 回调函数
    BeforeActionDoFunc := ""
    AfterActionDoFunc := ""
    ActionPrefixHandlers := Map()
    ActionValidators := Map()

    __New() {
        ; 创建全局窗口对象
        this.winGlobal := this.SetWin("__global__", "", "")
    }

    ; === 回调设置 ===
    SetBeforeActionDo(func) {
        this.BeforeActionDoFunc := func
    }

    SetAfterActionDo(func) {
        this.AfterActionDoFunc := func
    }

    RegisterPrefixActionHandler(prefix, handler) {
        this.ActionPrefixHandlers[prefix] := handler
    }

    RegisterActionValidator(prefix, validator) {
        this.ActionValidators[prefix] := validator
    }

    IsValidAction(action) {
        if RegExMatch(action, "^<([a-zA-Z0-9]+)_(.+)>$", &_m) {
            prefix := _m[1] . "_"
            if this.ActionValidators.Has(prefix)
                return this.ActionValidators[prefix](action)
        }
        return true
    }

    ; === Action 管理 ===
    SetAction(name, comment := "") {
        if !this.ActionList.Has(name)
            this.ActionList[name] := Action(name)
        this.ActionList[name].Comment := comment
        return this.ActionList[name]
    }

    GetAction(name) {
        if this.ActionList.Has(name)
            return this.ActionList[name]
        return Action(name)
    }

    ; === 窗口管理 ===
    SetWin(name, winClass := "", winFile := "") {
        if !this.WinList.Has(name) {
            this.WinList[name] := WinObj(name, winClass, winFile)
        }
        win := this.WinList[name]
        if (winClass != "")
            win.WinClass := winClass
        if (winFile != "")
            win.WinFile := winFile
        this.winEpoch += 1
        return win
    }

    GetWin(name := "") {
        if (name = "")
            return this.winGlobal
        if this.WinList.Has(name)
            return this.WinList[name]
        return ""
    }

    DeleteWin(name) {
        if this.WinList.Has(name) {
            this.WinList.Delete(name)
            this.winEpoch += 1
        }
    }

    CopyWin(srcName, dstName) {
        src := this.GetWin(srcName)
        if !IsObject(src)
            return ""

        dst := this.SetWin(dstName, src.WinClass, src.WinFile)
        dst.TimeOut := src.TimeOut
        dst.MaxCount := src.MaxCount
        dst.BeforeActionDoFunc := src.BeforeActionDoFunc
        dst.AfterActionDoFunc := src.AfterActionDoFunc
        dst.PreKeyFilterFunc := src.PreKeyFilterFunc

        ; 复制模式
        for modeName, modeObj in src.modeList {
            newMode := dst.modeList.Has(modeName) ? dst.modeList[modeName] : ModeObj(modeName)
            for key, action in modeObj.keymapList {
                newMode.keymapList[key] := action
            }
            for key, val in modeObj.keymoreList {
                newMode.keymoreList[key] := val
            }
            for key, val in modeObj.nowaitList {
                newMode.nowaitList[key] := val
            }
            for key, val in modeObj.keycommentList {
                newMode.keycommentList[key] := val
            }
            dst.modeList[modeName] := newMode
        }
        return dst
    }

    CopyMode(srcWinName, dstWinName, modeName) {
        src := this.GetWin(srcWinName)
        dst := this.GetWin(dstWinName)
        if !IsObject(src) || !IsObject(dst)
            return

        if !src.modeList.Has(modeName)
            return

        srcMode := src.modeList[modeName]
        if !dst.modeList.Has(modeName)
            dst.modeList[modeName] := ModeObj(modeName)
        dstMode := dst.modeList[modeName]

        for key, action in srcMode.keymapList {
            dstMode.keymapList[key] := action
        }
        for key, val in srcMode.keymoreList {
            dstMode.keymoreList[key] := val
        }
        for key, val in srcMode.nowaitList {
            dstMode.nowaitList[key] := val
        }
        for key, val in srcMode.keycommentList {
            dstMode.keycommentList[key] := val
        }
    }

; === 窗口级回调 ===
    SetBeforeActionDoForWin(winName, func) {
        win := this.GetWin(winName)
        if IsObject(win)
            win.BeforeActionDoFunc := func
    }

    SetAfterActionDoForWin(winName, func) {
        win := this.GetWin(winName)
        if IsObject(win)
            win.AfterActionDoFunc := func
    }

    SetPreKeyFilterForWin(winName, func) {
        win := this.GetWin(winName)
        if IsObject(win)
            win.PreKeyFilterFunc := func
    }

    ExcludeWin(name, exclude := true) {
        this.ExcludeWinList[name] := exclude
    }

    ; 解除排除 (ExcludeWin 传 false 只改值不清键, KeyHandler 按 Has() 判定, 必须删键才真恢复)
    UnexcludeWin(name) {
        if this.ExcludeWinList.Has(name)
            this.ExcludeWinList.Delete(name)
    }

    ; === 模式管理 ===
    SetMode(mode, winName := "") {
        win := this.GetWin(winName)
        if !IsObject(win)
            return

        if !win.modeList.Has(mode)
            win.modeList[mode] := ModeObj(mode)
        return win.modeList[mode]
    }

    GetMode(winName := "", modeName := "normal") {
        win := this.GetWin(winName)
        if !IsObject(win)
            return ""
        if win.modeList.Has(modeName)
            return win.modeList[modeName]
        return ""
    }

    mode(mode, winName := "") {
        this.SetMode(mode, winName)
    }

    ; === 热键映射 ===
    MapKey(key, action, winName := "", modeName := "normal") {
        win := this.GetWin(winName)
        if !IsObject(win)
            return

        ; 检查 nowait 前缀
        nowait := false
        if SubStr(key, 1, 8) = "<nowait>" {
            nowait := true
            key := SubStr(key, 9)
        }

        ; 检查 super 前缀
        isSuper := false
        if SubStr(key, 1, 6) = "<super>" {
            isSuper := true
            key := SubStr(key, 7)
        }

        ; 大写单字母归一 <S-X> (对齐原版; KeyHandler 由 Shift 组合反解出同形)
        key := NormalizeVimKey(key)

        ; 注册到 KeyList
        if !win.KeyList.Has(key)
            win.KeyList[key] := true

        ; 获取或创建模式
        modeObj := win.modeList.Has(modeName) ? win.modeList[modeName] : this.SetMode(modeName, winName)

        ; 检查是否是多键序列: 标记全部前缀 (gg→g, fbg→f/fb, 对齐原版 SetMoreKey)
        if (StrLen(key) > 1 && SubStr(key, 1, 1) != "<") {
            Loop StrLen(key) - 1 {
                prefix := SubStr(key, 1, A_Index)
                if !modeObj.keymoreList.Has(prefix)
                    modeObj.keymoreList[prefix] := true
            }
        } else if (StrLen(key) > 1) {
            prefix := SubStr(key, 1, 1)
            if !modeObj.keymoreList.Has(prefix)
                modeObj.keymoreList[prefix] := true
        }

        ; <Default> = 解绑 (与 BindHotkey 同名, 含 $ 前缀; 对齐原版 Hotkey Off)
        if (action = "<Default>") {
            _offKey := this.ConvertFromVim(key)
            if (SubStr(_offKey, 1, 1) != "$")
                _offKey := "$" . _offKey
            try Hotkey(_offKey, "Off")
            if modeObj.keymapList.Has(key)
                modeObj.keymapList.Delete(key)
            return
        }

        ; 设置 nowait
        if nowait
            modeObj.nowaitList[key] := true

        ; 映射到 AHK 热键
        this.BindHotkey(key, win)

        ; 存储映射 (中文注释同步预填, 供 ShowMore; 无 try 无 global, 纯 Map 操作)
        modeObj.keymapList[key] := action
        if this.ActionList.Has(action)
            modeObj.keycommentList[key] := this.ActionList[action].Comment
    }

    MapGlobal(key, action) {
        this.MapKey(key, action, "__global__")
    }

    ; 别名: 兼容 VimDesktop `vim.Map(key, action, win, mode)` 写法
    Map(key, action, winName := "", modeName := "normal") {
        this.MapKey(key, action, winName, modeName)
    }

    ; 解绑 (插件阶段回滚用; 只删映射表, 不 Hotkey Off —— 残留钩子无映射即透传, 比误关别窗同键安全)
    UnmapKey(key, winName := "", modeName := "normal") {
        win := this.GetWin(winName)
        if !IsObject(win)
            return false
        key := NormalizeVimKey(key)
        modeObj := win.modeList.Has(modeName) ? win.modeList[modeName] : ""
        if !IsObject(modeObj)
            return false
        had := modeObj.keymapList.Has(key)
        if (had)
            modeObj.keymapList.Delete(key)
        for _, lst in [modeObj.keymoreList, modeObj.nowaitList, modeObj.keycommentList] {
            try {
                if (lst.Has(key))
                    lst.Delete(key)
            }
        }
        ; 剪掉已无映射的前缀残留 (多键的前缀曾进 keymoreList, 如 gg 留下的 g)
        prune := []
        for pre in modeObj.keymoreList {
            keep := false
            for mk in modeObj.keymapList {
                if (SubStr(mk, 1, StrLen(pre)) = pre && StrLen(mk) > StrLen(pre)) {
                    keep := true
                    break
                }
            }
            if (!keep)
                prune.Push(pre)
        }
        for _, pre in prune
            modeObj.keymoreList.Delete(pre)
        if (win.KeyList.Has(key)) {
            still := false
            for _, m in win.modeList {
                if (m.keymapList.Has(key)) {
                    still := true
                    break
                }
            }
            if (!still)
                win.KeyList.Delete(key)
        }
        return had
    }

    ; 按键快照 (插件阶段回滚基准): {wins: [...], modes: Map, keys: Map, actions: [...]}
    SnapshotKeys() {
        snap := Map("wins", [], "modes", Map(), "keys", Map(), "actions", [])
        for name in this.WinList
            snap["wins"].Push(name)
        for name, win in this.WinList {
            for modeName, modeObj in win.modeList {
                snap["modes"][name . Chr(1) . modeName] := true
                for key in modeObj.keymapList
                    snap["keys"][name . Chr(1) . modeName . Chr(1) . key] := true
            }
        }
        for aname in this.ActionList
            snap["actions"].Push(aname)
        return snap
    }

    ; 回滚到快照 (删本阶段新增映射/窗口/模式/动作; 返回 Map{keys, wins, modes, actions})
    RollbackKeys(snap) {
        done := Map("keys", 0, "wins", 0, "modes", 0, "actions", 0)
        if (!IsObject(snap) || !snap.Has("keys"))
            return done
        cur := []
        for name, win in this.WinList {
            for modeName, modeObj in win.modeList {
                for key in modeObj.keymapList
                    cur.Push([name, modeName, key])
            }
        }
        for _, t in cur {
            k := t[1] . Chr(1) . t[2] . Chr(1) . t[3]
            if (!snap["keys"].Has(k)) {
                this.UnmapKey(t[3], t[1], t[2])
                done["keys"]++
            }
        }
        goneModes := []
        for name, win in this.WinList {
            for modeName, modeObj in win.modeList {
                mk := name . Chr(1) . modeName
                if (!snap["modes"].Has(mk) && modeObj.keymapList.Count = 0)
                    goneModes.Push([name, modeName])
            }
        }
        for _, t in goneModes {
            try {
                if (this.WinList.Has(t[1])) {
                    this.WinList[t[1]].modeList.Delete(t[2])
                    done["modes"]++
                }
            }
        }
        goneWins := []
        for name in this.WinList {
            found := false
            for _, w in snap["wins"] {
                if (w = name) {
                    found := true
                    break
                }
            }
            if (!found)
                goneWins.Push(name)
        }
        for _, name in goneWins {
            this.DeleteWin(name)
            done["wins"]++
        }
        goneActions := []
        for aname in this.ActionList {
            found := false
            for _, a in snap["actions"] {
                if (a = aname) {
                    found := true
                    break
                }
            }
            if (!found)
                goneActions.Push(aname)
        }
        for _, aname in goneActions {
            this.ActionList.Delete(aname)
            done["actions"]++
        }
        return done
    }

    ; === nowait 管理 ===
    SetNoWait(key, winName := "", modeName := "normal") {
        win := this.GetWin(winName)
        if !IsObject(win)
            return
        if win.modeList.Has(modeName)
            win.modeList[modeName].nowaitList[key] := true
    }

    GetNoWait(key, winName := "", modeName := "normal") {
        win := this.GetWin(winName)
        if !IsObject(win)
            return false
        if win.modeList.Has(modeName)
            return win.modeList[modeName].nowaitList.Has(key)
        return false
    }

    ; === AHK 热键绑定 ===
    ; $ 前缀: Send 发出的键不再触发自身, 掐断 Send 回环 (71 hotkeys/94ms 防洪根因)
    ; 逐字符单元注册 (对齐原版 Map 行为: gg 的 g 与 gg 各注一键, 前缀键触发等待)
    BindHotkey(key, win) {
        ; 架构不变量 (终端 3 事件定案):
        ; 无类名+无文件名的非 __global__ 窗 (如 General) 是纯数据窗
        ; (动作注册/按键浏览/中文注释保留), 一律不注册钩子.
        ; 全局钩子只属于 __global__ (用户 [global] 节显式配置才有).
        ; 否则未接管程序的每个按键都要进 KeyHandler 再 Send 回去:
        ; 开销、提权 UIPI 下 Send 投递失败、IME 数字选词被吞, 全是这一笔.
        ; 未命中任何窗时原生输入零经过 Rim, 不再需要 Send 透传.
        if (win.WinClass = "" && win.WinFile = "" && win.Name != "__global__")
            return
        ; 条件热键 (各单元共用上下文, 注册完复位; 全函数式, 命令式在此构建疑似静默无注册)
        if (win.WinClass != "" || win.WinFile != "") {
            if (win.WinFile != "")
                HotIfWinActive("ahk_exe " . win.WinFile)
            else
                HotIfWinActive("ahk_class " . win.WinClass)
        } else {
            HotIfWinActive()
        }

        rest := key
        Loop {
            if (rest = "")
                break
            if (SubStr(rest, 1, 1) = "<") {
                finish := InStr(rest, ">")
                if (!finish)
                    break
                unit := SubStr(rest, 1, finish)
                rest := SubStr(rest, finish + 1)
            } else {
                unit := SubStr(rest, 1, 1)
                rest := SubStr(rest, 2)
            }
            ahkUnit := this.ConvertFromVim(unit)
            if (SubStr(ahkUnit, 1, 1) != "$")
                ahkUnit := "$" . ahkUnit
            try {
                Hotkey(ahkUnit, VimKeyTrampoline)
            } catch as _be {
                try {
                    FileAppend(A_Now . " VIMBIND-FAIL key=" . unit . " ahkkey=" . ahkUnit . " win=" . win.Name . " msg=" . _be.Message . "`n", A_ScriptDir . "\Rim.error.log")
                }
            }
        }
        HotIfWinActive()
    }

    ; 诊断: 当前活动窗口的 vim 状态 (供用户在目标窗口执行后贴回)
    VimDiag(target := "A") {
        out := ""
        out .= "target=" target "`n"
        try {
            out .= "class=" WinGetClass(target) "`n"
        } catch as _e0 {
            out .= "class probe failed: " . _e0.Message . "`n"
        }
        try {
            out .= "exe=" WinGetProcessName(target) "`n"
        } catch as _e1 {
            out .= "exe probe failed: " . _e1.Message . "`n"
        }
        try {
            winName := this.CheckWin()
            out .= "checkwin=" winName "`n"
            win := this.GetWin(winName)
            if IsObject(win) {
                out .= "mode=" win.currentMode . " keytemp=" win.KeyTemp . " count=" win.Count "`n"
                out .= "keys=" win.KeyList.Count " lastAction=" this.lastAction "`n"
                dgMode := win.modeList.Has(win.currentMode) ? win.modeList[win.currentMode] : ""
                if IsObject(dgMode) {
                    out .= "maps=" dgMode.keymapList.Count " prefixes=" dgMode.keymoreList.Count "`n"
                    out .= "has-j=" (dgMode.keymapList.Has("j") ? dgMode.keymapList["j"] : "NONE") "`n"
                } else {
                    out .= "no mode object`n"
                }
                try {
                    fc := FocusedClassNN("A")
                    out .= "focused=" fc "`n"
                } catch as _e2 {
                    out .= "focused probe failed`n"
                }
                try {
                    bf := win.BeforeActionDoFunc ? win.BeforeActionDoFunc : this.BeforeActionDoFunc
                    if IsObject(bf)
                        out .= "before-j=" (bf("<down>", win) ? "passthrough" : "run-action") . "`n"
                    else
                        out .= "before-j=nil-callback`n"
                } catch as _e5 {
                    out .= "before probe failed: " . _e5.Message . "`n"
                }
            } else {
                out .= "no win object`n"
            }
        } catch as _e3 {
            out .= "diag failed: " . _e3.Message . "`n"
        }
        try {
            FileAppend(out, A_ScriptDir . "\Rim.error.log")
        }
        DisplayResult(out)
        return out
    }

    KeyHandler(thisHotkey) {
        ; A_ThisHotkey 自带 $ 前缀 (注册时加的), 先剥掉再参与一切逻辑
        ; 否则 Convert2VIM("$c")→"$c" 查不到映射, ConvertFromVim 又原样 Send("$c") 打进输入框
        thisHotkey := RegExReplace(thisHotkey, "^[$~]+", "")

        ; 先转 Vim 键 (所有透传 Send 都用它, 不用原始名:
        ; ConvertFromVim("Esc") 无尖括号会原样返回, Send("Esc") 就打出 esc 三个字母!)
        vimKey := this.Convert2VIM(thisHotkey)
        if GetKeyState("CapsLock", "T") {
            if RegExMatch(vimKey, "^[a-z]$")
                vimKey := "<S-" StrUpper(vimKey) ">"
            else if RegExMatch(vimKey, "i)^<S\-([a-zA-Z])>$", &cm)
                vimKey := StrLower(cm[1])
        }
        ; 注册/运行两侧统一归一 (ini 小写 <c-b> 与运行时大写 <C-B> 归一, 见 NormalizeVimKey)
        vimKey := NormalizeVimKey(vimKey)

        ; 单次上下文采集: 本函数后续所有守卫与 CheckWin 全复用 ctx, 单键只批量查一次.
        ; 接线顺序不变量 (probe_input_guards 锁死): 自家窗 → 自家进程 → IME → 对话框 → CheckWin
        ctx := EngineCollectCtx()

        ; 自家窗口: 直接透传 (Send 不会回环, 因注册带 $ 前缀)
        if (this.SelfWinTitle != "") {
            try {
                if WinActive(this.SelfWinTitle) {
                    Send(this.ConvertFromVim(vimKey, true))
                    return
                }
            }
        }

        ; 自家进程守卫: 配置中心/手势UI等子窗一律透传 ([global] 字母映射不再劫自家编辑框).
        ; 接线不变量 (probe_input_guards 锁死): 必须在 CheckWin 之前, 逐字键零经过分发
        try {
            if (ctx["procPath"] != "" && IsSelfProcessPath(ctx["procPath"])) {
                Send(this.ConvertFromVim(vimKey, true))
                return
            }
        } catch {
        }

        ; IME 组字保护: 组字中全透传 (提交/取消走原生语义), 组字结束自动恢复分发.
        ; 接线不变量 (probe_input_guards 锁死): 自家守卫之后、CheckWin 之前
        try {
            if (ImeComposingAt(ctx["hwnd"])) {
                Send(this.ConvertFromVim(vimKey, true))
                return
            }
        } catch {
        }

        ; 文件对话框输入保护: #32770 且焦点在输入控件 (文件名框等) 时直接透传,
        ; Typora/记事本另存为不再吃掉 o/i 等键. 用 ctx 现取值 (CheckWin 有 hwnd 缓存,
        ; 对话框刚弹出时缓存还是父窗, 不能用); TCDialog 不依赖窗内映射, 不受影响.
        try {
            if (ctx["class"] = "#32770" && ctx["focus"]) {
                if (DialogShouldPassthrough(ctx["class"], ctx["focusClass"], ctx["focusNN"])) {
                    Send(this.ConvertFromVim(vimKey, true))
                    ; 与其他透传分支对齐清状态: 父窗残留 KeyTemp (如列表里按了 g
                    ; 又进对话框) 不得污染对话框后的按键
                    try {
                        _cw := this.CheckWin(ctx)
                        _w := this.GetWin(_cw)
                        if IsObject(_w) {
                            _w.KeyTemp := ""
                            _w.Count := 0
                            try _w.HideMore()
                        }
                    } catch {
                    }
                    return
                }
            }
        } catch {
        }

        ; 获取当前窗口信息 (复用 ctx, 命中缓存时 0 问 WinAPI)
        winName := this.CheckWin(ctx)
        if (winName = "") {
            Send(this.ConvertFromVim(vimKey, true))
            return
        }

        ; 检查排除列表
        if this.ExcludeWinList.Has(winName) {
            Send(this.ConvertFromVim(vimKey, true))
            return
        }

        ; 获取窗口对象
        win := this.GetWin(winName)
        if !IsObject(win)
            win := this.winGlobal

        ; 获取当前模式
        modeName := win.currentMode
        modeObj := win.modeList.Has(modeName) ? win.modeList[modeName] : ""

        if !IsObject(modeObj) {
            Send(this.ConvertFromVim(vimKey, true))
            return
        }

        ; 窗口级按键拦截/预过滤 (插件按需接管, 避免核心引擎耦合具体应用)
        if (win.PreKeyFilterFunc) {
            try {
                if win.PreKeyFilterFunc(vimKey, win)
                    return
            }
        }

        ; 全局回退: 本窗未映射(且非组合中)则查 __global__ (对齐原版 KeyList 回退)
        if (winName != "__global__" && win.KeyTemp = "") {
            hasLocal := win.KeyList.Has(vimKey)
                || modeObj.keymoreList.Has(vimKey)
                || modeObj.keymapList.Has(vimKey)
            if (!hasLocal) {
                gmode := this.winGlobal.currentMode
                if this.winGlobal.modeList.Has(gmode)
                    modeObj := this.winGlobal.modeList[gmode]
                win := this.winGlobal
                winName := "__global__"
                modeName := gmode
            }
        }

        ; 未映射一律透传 (必须在数字处理之前:
        ; 否则浏览器/终端里按数字只进 Count 永远打不出来, 原版未配置窗口直接 Send)
        if (win.KeyTemp = ""
            && !win.KeyList.Has(vimKey)
            && !modeObj.keymoreList.Has(vimKey)
            && !modeObj.keymapList.Has(vimKey)) {
            Send(this.ConvertFromVim(vimKey, true))
            win.KeyTemp := ""
            win.Count := 0
            win.HideMore()
            return
        }

        ; 数字键处理（Count, 上限 MaxCount, 仅映射窗/组合中生效）
        ; vim 语义: 0 不能开头 Count ("0" 单独=行首, 由映射处理)
        if RegExMatch(vimKey, "^(\d)$", &match) {
            digit := Integer(match[1])
            if (digit = 0 && win.Count = 0) {
                ; 回落正常映射查找 (0=<home> 等)
            } else {
                win.Count := win.Count * 10 + digit
                if (win.Count > win.MaxCount)
                    win.Count := win.MaxCount
                return
            }
        }

        ; 检查热键映射
        actionName := ""

        ; 先检查组合键（KeyTemp + vimKey）
        if (win.KeyTemp != "") {
            combinedKey := win.KeyTemp . vimKey
            if modeObj.keymapList.Has(combinedKey) {
                actionName := modeObj.keymapList[combinedKey]
                win.KeyTemp := ""
            }
        }

        ; 组合未中时回退单键 (对齐原版 GetKeymap(LastKey): 如 gj 直接跑 j)
        if (actionName = "" && win.KeyTemp != "") {
            if modeObj.keymapList.Has(vimKey) {
                actionName := modeObj.keymapList[vimKey]
                win.KeyTemp := ""
            }
        }

        ; 再检查单键（仅在没有组合键前缀时）
        if (actionName = "" && win.KeyTemp = "") {
            if modeObj.keymapList.Has(vimKey)
                actionName := modeObj.keymapList[vimKey]
        }

        if (actionName = "") {
            ; 检查多键序列前缀
            if modeObj.keymoreList.Has(vimKey) {
                ; 前缀同样先过 BeforeActionDo (输入框保护): 否则 g 等前缀键
                ; 在重命名框/地址栏里被 KeyTemp 吞掉出提示菜单, 回调永远走不到
                try {
                    if (EngineShouldPassthroughPrefix(win, this.BeforeActionDoFunc)) {
                        Send(this.ConvertFromVim(vimKey, true))
                        win.KeyTemp := ""
                        win.Count := 0
                        win.HideMore()
                        return
                    }
                } catch {
                }
                win.KeyTemp .= vimKey

                ; 显示按键提示
                win.ShowMore(win.KeyTemp, win.Count)

                ; 检查 nowait - 如果当前按键有 nowait 标记，立即执行
                if modeObj.nowaitList.Has(win.KeyTemp) {
                    if modeObj.keymapList.Has(win.KeyTemp) {
                        actionName := modeObj.keymapList[win.KeyTemp]
                        win.KeyTemp := ""
                        ; 继续执行下面的 Action
                    }
                }

                if (actionName = "") {
                    ; 启动超时计时器
                    SetTimer(() => this.TimeOut(win), -win.TimeOut)
                    return
                }
            }
            ; 无匹配，发送原按键
            if (actionName = "") {
                Send(this.ConvertFromVim(vimKey, true))
                win.KeyTemp := ""
                win.Count := 0
                win.HideMore()
                return
            }
        }

        ; <Pass>/<> = 透传原键
        if (actionName = "<Pass>" || actionName = "<>") {
            Send(this.ConvertFromVim(vimKey, true))
            win.KeyTemp := ""
            win.Count := 0
            win.HideMore()
            return
        }

        ; 执行 Action
        act := this.GetAction(actionName)

        ; BeforeActionDo 回调 - 对齐原版: 返回 true = 透传原键并跳过 Action
        beforeFunc := win.BeforeActionDoFunc ? win.BeforeActionDoFunc : this.BeforeActionDoFunc
        if IsObject(beforeFunc) {
            try {
                if beforeFunc(actionName, win) {
                    Send(this.ConvertFromVim(vimKey, true))
                    win.KeyTemp := ""
                    win.Count := 0
                    win.HideMore()
                    return
                }
            }
        }

        ; 隐藏按键提示
        win.HideMore()

        DoTimes(act, win.Count)
        this.lastAction := actionName

        ; AfterActionDo 回调 - 优先使用窗口级回调
        afterFunc := win.AfterActionDoFunc ? win.AfterActionDoFunc : this.AfterActionDoFunc
        if IsObject(afterFunc) {
            try afterFunc(actionName, win)
        }

        ; 重置状态
        win.KeyTemp := ""
        win.Count := 0
    }

    ; === 窗口检测 (对齐原版: exe 优先于 class, 解决 TConvertForm 撞车) ===
    ; ctx 复用: KeyHandler 入口已批量采集, 传 ctx 则 0 问 WinAPI; 探针/旧调用无参则现查.
    ; 缓存按 hwnd 键控 (窗口一切换即失效, 杜绝 TTL 内命中旧窗) + winEpoch (注册表变化即失效).
    CheckWin(ctx := "") {
        static cacheHwnd := 0, cacheName := "", cacheTick := 0, cacheEpoch := -1
        hwnd := 0
        winClass := ""
        winExe := ""
        if (IsObject(ctx)) {
            try hwnd := ctx["hwnd"] + 0
            catch {
            }
            try winClass := ctx["class"]
            catch {
            }
            try winExe := ctx["procName"]
            catch {
            }
        }
        if (cacheName != "" && hwnd = cacheHwnd && cacheEpoch = this.winEpoch
            && A_TickCount - cacheTick < 2000)
            return cacheName
        ; 缺字段才补查 (返回值形态取值, 此构建 &var 输出型在部分函数上行为异常)
        if (hwnd = 0 && winClass = "" && winExe = "") {
            try hwnd := WinExist("A")
            catch {
            }
        }
        if (winClass = "") {
            try winClass := WinGetClass("A")
            catch {
                winClass := ""
            }
        }
        if (winExe = "") {
            try winExe := WinGetProcessName("A")
            catch {
                winExe := ""
            }
        }

        ; 先按 exe 匹配 (P9: 索引优先, 缺失回退线性)
        try {
            idxHit := WinIdx_Match(winExe, winClass, this)
            if (idxHit != "" && this.WinList.Has(idxHit)) {
                cacheHwnd := hwnd, cacheName := idxHit, cacheTick := A_TickCount, cacheEpoch := this.winEpoch
                return idxHit
            }
        }
        for name, win in this.WinList {
            if (name = "__global__")
                continue
            if (win.WinFile != "" && winExe = win.WinFile) {
                cacheHwnd := hwnd, cacheName := name, cacheTick := A_TickCount, cacheEpoch := this.winEpoch
                return name
            }
        }
        ; 再按 class 匹配
        for name, win in this.WinList {
            if (name = "__global__")
                continue
            if (win.WinClass != "" && winClass = win.WinClass) {
                cacheHwnd := hwnd, cacheName := name, cacheTick := A_TickCount, cacheEpoch := this.winEpoch
                return name
            }
        }
        cacheHwnd := hwnd, cacheName := "__global__", cacheTick := A_TickCount, cacheEpoch := this.winEpoch
        return "__global__"
    }

    ; === 键名转换 ===
    Convert2VIM(key) {
        static cache := Map()
        if cache.Has(key)
            return cache[key]

        res := this._Convert2VIM(key)
        cache[key] := res
        return res
    }

    _Convert2VIM(key) {
        ; AHK 格式 -> Vim 格式
        if RegExMatch(key, "^[A-Z]$")
            return "<S-" StrUpper(key) ">"
        if RegExMatch(key, "i)^((F1)|(F2)|(F3)|(F4)|(F5)|(F6)|(F7)|(F8)|(F9)|(F10)|(F11)|(F12))$")
            return "<" key ">"
        if RegExMatch(key, "i)^((AppsKey)|(Tab)|(Enter)|(Space)|(Home)|(End)|(CapsLock)|(ScrollLock)|(Up)|(Down)|(Left)|(Right)|(PgUp)|(PgDn)|(Pause))$")
            return "<" key ">"
        if RegExMatch(key, "i)^((BS)|(BackSpace))$")
            return "<BS>"
        if RegExMatch(key, "i)^((Esc)|(Escape))$")
            return "<Esc>"
        if RegExMatch(key, "i)^((Ins)|(Insert))$")
            return "<Insert>"
        if RegExMatch(key, "i)^((Del)|(Delete))$")
            return "<Delete>"
        if RegExMatch(key, "i)^PrintScreen$")
            return "<PrtSc>"
        if RegExMatch(key, "i)^shift\s&\s(.*)", &m) or RegExMatch(key, "^\+(.*)", &m)
            return "<S-" StrUpper(m[1]) ">"
        if RegExMatch(key, "i)^lshift\s&\s(.*)", &m) or RegExMatch(key, "^<\+(.*)", &m)
            return "<LS-" StrUpper(m[1]) ">"
        if RegExMatch(key, "i)^rshift\s&\s(.*)", &m) or RegExMatch(key, "^>\+(.*)", &m)
            return "<RS-" StrUpper(m[1]) ">"
        if RegExMatch(key, "i)^Ctrl\s&\s(.*)", &m) or RegExMatch(key, "^\^(.*)", &m)
            return "<C-" StrUpper(m[1]) ">"
        if RegExMatch(key, "i)^lctrl\s&\s(.*)", &m) or RegExMatch(key, "^<\^(.*)", &m)
            return "<LC-" StrUpper(m[1]) ">"
        if RegExMatch(key, "i)^rctrl\s&\s(.*)", &m) or RegExMatch(key, "^>\^(.*)", &m)
            return "<RC-" StrUpper(m[1]) ">"
        if RegExMatch(key, "i)^alt\s&\s(.*)", &m) or RegExMatch(key, "^\!(.*)", &m)
            return "<A-" StrUpper(m[1]) ">"
        if RegExMatch(key, "i)^lalt\s&\s(.*)", &m) or RegExMatch(key, "^<\!(.*)", &m)
            return "<LA-" StrUpper(m[1]) ">"
        if RegExMatch(key, "i)^ralt\s&\s(.*)", &m) or RegExMatch(key, "^>\!(.*)", &m)
            return "<RA-" StrUpper(m[1]) ">"
        if RegExMatch(key, "i)^lwin\s&\s(.*)", &m) or RegExMatch(key, "^#(.*)", &m)
            return "<W-" StrUpper(m[1]) ">"
        if RegExMatch(key, "i)^space\s&\s(.*)", &m)
            return "<SP-" StrUpper(m[1]) ">"
        if RegExMatch(key, "i)^alt$")
            return "<Alt>"
        if RegExMatch(key, "i)^ctrl$")
            return "<Ctrl>"
        if RegExMatch(key, "i)^shift$")
            return "<Shift>"
        if RegExMatch(key, "i)^lwin$")
            return "<Win>"
        return key
    }

    ConvertFromVim(key, ToSend := false) {
        static cacheSend := Map(), cacheNoSend := Map()
        c := ToSend ? cacheSend : cacheNoSend
        if c.Has(key)
            return c[key]

        res := this._ConvertFromVim(key, ToSend)
        c[key] := res
        return res
    }

    _ConvertFromVim(key, ToSend := false) {
        ; Vim 格式 -> AHK 格式
        if RegExMatch(key, "^<.*>$") {
            key := SubStr(key, 2, StrLen(key) - 2)
            if RegExMatch(key, "i)^((F1)|(F2)|(F3)|(F4)|(F5)|(F6)|(F7)|(F8)|(F9)|(F10)|(F11)|(F12))$")
                return ToSend ? "{" key "}" : key
            if RegExMatch(key, "i)^((AppsKey)|(Tab)|(Enter)|(Space)|(Home)|(End)|(CapsLock)|(ScrollLock)|(Up)|(Down)|(Left)|(Right)|(PgUp)|(PgDn)|(BS)|(ESC)|(Insert)|(Delete)|(Pause))$")
                return ToSend ? "{" key "}" : key
            if RegExMatch(key, "i)^PrtSc$")
                return ToSend ? "{PrintScreen}" : "PrintScreen"
            if RegExMatch(key, "i)^alt$")
                return ToSend ? "{!}" : "alt"
            if RegExMatch(key, "i)^ctrl$")
                return ToSend ? "{^}" : "ctrl"
            if RegExMatch(key, "i)^shift$")
                return ToSend ? "{+}" : "shift"
            if RegExMatch(key, "i)^win$")
                return ToSend ? "{#}" : "lwin"
            if RegExMatch(key, "<LT>")
                return "<"
            if RegExMatch(key, "<RT>")
                return ">"
            if RegExMatch(key, "i)^S\-(.*)", &m)
                return ToSend ? "+" this.CheckToSend(m[1], true) : "+" m[1]
            ; 全写修饰符 (NormalizeVimKey 把 <Ctrl-u> 整体大写成 <CTRL-U>,
            ; 单字母分支 ^C\- 匹配不上, 曾导致 Hotkey("$CTRL-U") 非法刷屏)
            if RegExMatch(key, "i)^CTRL\-(.*)", &m)
                return ToSend ? "^" this.CheckToSend(m[1]) : "^" m[1]
            if RegExMatch(key, "i)^LCTRL\-(.*)", &m)
                return ToSend ? "<^" this.CheckToSend(m[1]) : "<^" m[1]
            if RegExMatch(key, "i)^RCTRL\-(.*)", &m)
                return ToSend ? ">^" this.CheckToSend(m[1]) : ">^" m[1]
            if RegExMatch(key, "i)^ALT\-(.*)", &m)
                return ToSend ? "!" this.CheckToSend(m[1]) : "!" m[1]
            if RegExMatch(key, "i)^LALT\-(.*)", &m)
                return ToSend ? "<!" this.CheckToSend(m[1]) : "<!" m[1]
            if RegExMatch(key, "i)^RALT\-(.*)", &m)
                return ToSend ? ">!" this.CheckToSend(m[1]) : ">!" m[1]
            if RegExMatch(key, "i)^SHIFT\-(.*)", &m)
                return ToSend ? "+" this.CheckToSend(m[1], true) : "+" m[1]
            if RegExMatch(key, "i)^LSHIFT\-(.*)", &m)
                return ToSend ? "<+" this.CheckToSend(m[1], true) : "<+" m[1]
            if RegExMatch(key, "i)^RSHIFT\-(.*)", &m)
                return ToSend ? ">+" this.CheckToSend(m[1], true) : ">+" m[1]
            if RegExMatch(key, "i)^WIN\-(.*)", &m)
                return ToSend ? "#" this.CheckToSend(m[1]) : "#" m[1]
            if RegExMatch(key, "i)^LS\-(.*)", &m)
                return ToSend ? "<+" this.CheckToSend(m[1], true) : "<+" m[1]
            if RegExMatch(key, "i)^RS\-(.*)", &m)
                return ToSend ? ">+" this.CheckToSend(m[1], true) : ">+" m[1]
            if RegExMatch(key, "i)^C\-(.*)", &m)
                return ToSend ? "^" this.CheckToSend(m[1]) : "^" m[1]
            if RegExMatch(key, "i)^LC\-(.*)", &m)
                return ToSend ? "<^" this.CheckToSend(m[1]) : "<^" m[1]
            if RegExMatch(key, "i)^RC\-(.*)", &m)
                return ToSend ? ">^" this.CheckToSend(m[1]) : ">^" m[1]
            if RegExMatch(key, "i)^A\-(.*)", &m)
                return ToSend ? "!" this.CheckToSend(m[1]) : "!" m[1]
            if RegExMatch(key, "i)^LA\-(.*)", &m)
                return ToSend ? "<!" this.CheckToSend(m[1]) : "<!" m[1]
            if RegExMatch(key, "i)^RA\-(.*)", &m)
                return ToSend ? ">!" this.CheckToSend(m[1]) : ">!" m[1]
            if RegExMatch(key, "i)^W\-(.*)", &m)
                return ToSend ? "#" this.CheckToSend(m[1]) : "#" m[1]
            if RegExMatch(key, "i)^SP\-(.*)", &m)
                return ToSend ? "{space}" this.CheckToSend(m[1]) : "space & " m[1]
        }
        return key
    }

    ; Send 形态键名规范化. keepCase 专供 Shift 系 (S/SHIFT/LS/RS/LSSHIFT/RSHIFT):
    ; Send 里大写字母自带 Shift ("^C"=Ctrl+Shift+C, 文档实锤), Ctrl/Alt/Win 后
    ; 的单字母必须小写, Shift 后的必须大写. 注册侧 (Hotkey, 大小写无关) 不走此口.
    CheckToSend(key, keepCase := false) {
        if RegExMatch(key, "i)^((F1)|(F2)|(F3)|(F4)|(F5)|(F6)|(F7)|(F8)|(F9)|(F10)|(F11)|(F12))$")
            return "{" key "}"
        if RegExMatch(key, "i)^((AppsKey)|(Tab)|(Enter)|(Space)|(Home)|(End)|(CapsLock)|(ScrollLock)|(Up)|(Down)|(Left)|(Right)|(PgUp)|(PgDn)|(BS)|(ESC)|(Insert)|(Delete)|(Pause))$")
            return "{" key "}"
        if RegExMatch(key, "i)^PrtSc$")
            return "{PrintScreen}"
        if RegExMatch(key, "i)^alt$")
            return "{!}"
        if RegExMatch(key, "i)^ctrl$")
            return "{^}"
        if RegExMatch(key, "i)^shift$")
            return "{+}"
        if RegExMatch(key, "i)^win$")
            return "{#}"
        if RegExMatch(key, "<LT>")
            return "<"
        if RegExMatch(key, "<RT>")
            return ">"
        if (!keepCase && RegExMatch(key, "^[A-Z]$"))
            return StrLower(key)
        return key
    }

    CheckCapsLock(key) {
        if GetKeyState("CapsLock", "T") {
            if RegExMatch(key, "^[a-z]$")
                return "<S-" key ">"
            if RegExMatch(key, "i)^<S\-([a-zA-Z])>", &m) {
                return StrLower(m[1])
            }
        }
        return key
    }

    ; === 超时处理 (补齐回调与 lastAction) ===
    TimeOut(win) {
        if (win.KeyTemp != "") {
            ; 检查当前窗口当前模式是否有匹配
            modeObj := win.modeList.Has(win.currentMode) ? win.modeList[win.currentMode] : ""
            if IsObject(modeObj) && modeObj.keymapList.Has(win.KeyTemp) {
                actionName := modeObj.keymapList[win.KeyTemp]
                act := this.GetAction(actionName)
                beforeFunc := win.BeforeActionDoFunc ? win.BeforeActionDoFunc : this.BeforeActionDoFunc
                veto := false
                if IsObject(beforeFunc) {
                    try veto := beforeFunc(actionName, win)
                }
                if (!veto) {
                    DoTimes(act, win.Count)
                    this.lastAction := actionName
                    afterFunc := win.AfterActionDoFunc ? win.AfterActionDoFunc : this.AfterActionDoFunc
                    if IsObject(afterFunc) {
                        try afterFunc(actionName, win)
                    }
                }
            }
        }
        win.HideMore()
        win.KeyTemp := ""
        win.Count := 0
    }

    HasBinding(key) {
        winName := this.CheckWin()
        win := this.GetWin(winName)
        if !IsObject(win)
            win := this.winGlobal

        modeObj := win.modeList.Has(win.currentMode) ? win.modeList[win.currentMode] : ""
        if IsObject(modeObj) && modeObj.keymapList.Has(key)
            return true
        return false
    }

    ; === 调试 ===
    Debug(enable := true) {
        this.debugMode := enable
    }
}

; === WinObj - 窗口对象 ===
class WinObj {
    Name := ""
    WinClass := ""
    WinFile := ""
    TimeOut := 800
    MaxCount := 99
    Count := 0
    KeyTemp := ""
    currentMode := "normal"
    modeList := Map()
    KeyList := Map()
    BeforeActionDoFunc := ""
    AfterActionDoFunc := ""
    PreKeyFilterFunc := ""
    Comment := ""  ; 帮助文档
    ShowInfo := true  ; 是否显示按键提示 (ini enable_show_info)

    __New(name, winClass := "", winFile := "") {
        this.Name := name
        this.WinClass := winClass
        this.WinFile := winFile
        this.modeList["normal"] := ModeObj("normal")
        this.modeList["insert"] := ModeObj("insert")
    }

    ; 设置窗口级超时
    SetTimeOut(ms) {
        this.TimeOut := ms
    }

    ; 设置帮助文档
    SetComment(text) {
        this.Comment := text
    }

    ; 获取帮助文档
    GetComment() {
        return this.Comment
    }

    ; 显示按键提示
    ShowMore(keyTemp := "", count := 0) {
        if (!this.ShowInfo)
            return
        ; 获取当前可用的按键列表
        modeObj := this.modeList.Has(this.currentMode) ? this.modeList[this.currentMode] : ""
        if !IsObject(modeObj)
            return

        ; 构建提示文本
        tip := ""
        if (count > 0)
            tip .= "Count: " count "`n"
        if (keyTemp != "")
            tip .= "Input: " keyTemp "`n`n"

        ; 收集匹配前缀的按键
        matches := Map()
        for key, action in modeObj.keymapList {
            if (keyTemp = "") {
                ; 无前缀，显示所有单键
                if (StrLen(key) = 1 || SubStr(key, 1, 1) = "<")
                    matches[key] := action
            } else {
                ; 有前缀，显示匹配的后续按键
                if (SubStr(key, 1, StrLen(keyTemp)) = keyTemp && StrLen(key) > StrLen(keyTemp)) {
                    suffix := SubStr(key, StrLen(keyTemp) + 1)
                    if (StrLen(suffix) <= 2)  ; 只显示短后缀
                        matches[suffix] := action
                }
            }
        }

        ; 显示提示 (行格式: 按键 \t 中文注释, 对原版 key\tcomment; 注释缺失回落动作名)
        if (matches.Count > 0) {
            tip .= T("engine.available") . "`n"
            for key, action in matches {
                cmt := action
                full := keyTemp != "" ? keyTemp . key : key
                if (modeObj.keycommentList.Has(full) && modeObj.keycommentList[full] != "")
                    cmt := modeObj.keycommentList[full]
                tip .= "  " key "`t" cmt "`n"
            }
        }

        if (tip != "")
            ToolTip(tip)
    }

    ; 隐藏按键提示
    HideMore() {
        ToolTip()
    }
}

; === ModeObj - 模式对象 ===
class ModeObj {
    Name := ""
    keymapList := Map()
    keymoreList := Map()
    nowaitList := Map()
    keycommentList := Map()
    ; g 面板中文: MapKey 时把动作中文预填于此, ShowMore 直读 (避开方法内 global+try 加载坑)

    __New(name) {
        this.Name := name
    }
}

; === Action - 动作对象 (仅名/注释; 执行一律走统一入口 ExecuteAction) ===
class Action {
    Name := ""
    Comment := ""

    __New(name) {
        this.Name := name
    }

    Do(count := 1) {
        ExecuteAction(this.Name)
    }
}

; 动作按计数重复执行 (count=0 按1次, 上限100; 无 brace 嵌套写法保加载)
DoTimes(act, count) {
    reps := (count <= 0) ? 1 : (count > 100 ? 100 : count)
    Loop reps
        act.Do()
}

; 热键跳板: 与启动器热键同形态 (普通函数引用; BoundFunc 在此构建行为存疑)
VimKeyTrampoline(*) {
    global g_VimEngine
    if (IsSet(g_VimEngine) && IsObject(g_VimEngine)) {
        try {
            g_VimEngine.KeyHandler(A_ThisHotkey)
        } catch as _e {
            try {
                FileAppend(A_Now . " VIMKEY-ERR: " . _e.Message . "`n", A_ScriptDir . "\Rim.error.log")
            }
        }
    }
}

; vim 键归一化: 独立大写字母 → <S-X> (对齐原版 Map 行为);
; <...> 单元整体大写化 (对原版不敏感语义: ini 写 <c-b>/<la-r>/<enter>,
; 运行时 A_ThisHotkey 来的是 <C-B>/<LA-R>/<Enter>, 两边必须归一, 否则 Ctrl 整排失灵)
NormalizeVimKey(key) {
    static cache := Map()
    if cache.Has(key)
        return cache[key]

    out := ""
    rest := key
    Loop {
        if (rest = "")
            break
        if (SubStr(rest, 1, 1) = "<") {
            finish := InStr(rest, ">")
            if (!finish) {
                out .= rest
                break
            }
            out .= "<" StrUpper(SubStr(rest, 2, finish - 2)) ">"
            rest := SubStr(rest, finish + 1)
        } else {
            ch := SubStr(rest, 1, 1)
            if RegExMatch(ch, "^[A-Z]$")
                out .= "<S-" ch ">"
            else
                out .= ch
            rest := SubStr(rest, 2)
        }
    }
    cache[key] := out
    return out
}

; 窗口默认模式应用 (ini [窗名] default_mode): 读 CfgGet, 窗与模式俱在才 SetMode,
; 否则 false (缺键/缺窗/非法值静默忽略, 不断启动; 调用方: Rim.ahk VimdCheckHotKey
; 启动编译 + DoSaveBody 即时生效; 探针直调测真逻辑)
VimdApplyDefaultMode(winName) {
    try {
        global g_VimEngine
        if !IsObject(g_VimEngine)
            return false
        mode := ""
        try mode := CfgGet(winName, "default_mode", "")
        catch {
            return false
        }
        if (mode = "")
            return false
        win := g_VimEngine.GetWin(winName)
        if !IsObject(win)
            return false
        if !win.modeList.Has(mode)
            return false
        ; 注意: Engine.SetMode 只建表不切态, 切态一律直写 currentMode (对齐 Gen_InsertMode)
        win.currentMode := mode
        return true
    } catch {
        return false
    }
}
