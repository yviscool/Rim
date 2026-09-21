#Requires AutoHotkey v2.0

; === VimEngine - 核心Vim引擎 ===
; 管理窗口、模式、热键映射、Action执行

class VimEngine {
    PluginList := Map()
    WinList := Map()
    ActionList := Map()
    ExcludeWinList := Map()
    ActionFromPlugin := Map()
    VIMD_CMD_LIST := Map()
    winGlobal := ""
    debugMode := false
    lastAction := ""
    ; 自家启动器窗口标题: 激活时直接透传, 不进 vim 分发 (输入框打字安全)
    SelfWinTitle := ""

    ; 回调函数
    BeforeActionDoFunc := ""
    AfterActionDoFunc := ""

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

    ; === 插件管理 ===
    SetPlugin(name, author, ver, comment) {
        plugin := Plugin(name, author, ver, comment)
        this.PluginList[name] := plugin
        return plugin
    }

    LoadPlugin(name) {
        if !this.PluginList.Has(name)
            this.PluginList[name] := Plugin(name, "", "", "")

        plugin := this.PluginList[name]
        plugin.CheckSub()
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

    ExcludeWin(name, exclude := true) {
        this.ExcludeWinList[name] := exclude
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

    ; === 配置持久化 ===
    SaveWinList() {
        config := Rim.config
        winSection := Map()

        for name, win in this.WinList {
            winData := Map()
            winData["class"] := win.winClass
            winData["exe"] := win.winFile
            winSection[name] := winData
        }

        config.data["winlist"] := winSection
        config.Save()
    }

    LoadWinList() {
        config := Rim.config
        winSection := config.GetSection("winlist")

        for name, data in winSection {
            if IsObject(data) {
                winClass := data.Has("class") ? data["class"] : ""
                winFile := data.Has("exe") ? data["exe"] : ""
                this.AddWin(name, winClass, winFile)
            }
        }
    }

    SaveModeList() {
        config := Rim.config

        for winName, win in this.WinList {
            modeSection := Map()
            for modeName, modeObj in win.modeList {
                modeData := Map()
                modeData["name"] := modeName
                modeSection[modeName] := modeData
            }
            config.data["modelist_" winName] := modeSection
        }

        config.Save()
    }

    LoadModeList() {
        config := Rim.config

        for winName, win in this.WinList {
            sectionName := "modelist_" winName
            if config.data.Has(sectionName) {
                modeSection := config.data[sectionName]
                for modeName, data in modeSection {
                    this.SetMode(modeName, winName)
                }
            }
        }
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
    VimDiag() {
        out := ""
        ; 优先探 TC 窗 (问题域), 不存在才探活动窗: 避免焦点切走失真
        target := ""
        try {
            if WinExist("ahk_class TTOTAL_CMD")
                target := "ahk_class TTOTAL_CMD"
        } catch {
        }
        if (target = "")
            target := "A"
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
            twin := this.GetWin("TTOTAL_CMD")
            if IsObject(twin) {
                out .= "TCwin mode=" twin.currentMode . " keytemp=[" twin.KeyTemp . "] count=" twin.Count "`n"
                out .= "TCwin keys=" twin.KeyList.Count "`n"
                tmode := twin.modeList.Has(twin.currentMode) ? twin.modeList[twin.currentMode] : ""
                if IsObject(tmode) {
                    out .= "TCmaps=" tmode.keymapList.Count . " prefixes=" tmode.keymoreList.Count "`n"
                    out .= "TC-has-j=" (tmode.keymapList.Has("j") ? tmode.keymapList["j"] : "NONE") "`n"
                } else {
                    out .= "TC no mode object`n"
                }
                try {
                    fc2 := FocusedClassNN("ahk_class TTOTAL_CMD")
                    out .= "TC-focused=" fc2 "`n"
                } catch as _e6 {
                    out .= "TC focused probe failed`n"
                }
                try {
                    bf2 := twin.BeforeActionDoFunc ? twin.BeforeActionDoFunc : this.BeforeActionDoFunc
                    if IsObject(bf2)
                        out .= "TC-before-j=" (bf2("<down>", twin) ? "passthrough" : "run-action") . "`n"
                    else
                        out .= "TC-before-j=nil-callback`n"
                } catch as _e7 {
                    out .= "TC before probe failed: " . _e7.Message . "`n"
                }
            } else {
                out .= "no TTOTAL_CMD win object`n"
            }
        } catch as _e8 {
            out .= "TC diag failed: " . _e8.Message . "`n"
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

        ; 自家窗口: 直接透传 (Send 不会回环, 因注册带 $ 前缀)
        if (this.SelfWinTitle != "") {
            try {
                if WinActive(this.SelfWinTitle) {
                    Send(this.ConvertFromVim(vimKey, true))
                    return
                }
            }
        }

        ; 获取当前窗口信息
        winName := this.CheckWin()
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
    CheckWin() {
        ; 返回值形态取值 (此构建 &var 输出型在部分函数上行为异常, try 吞错会导致全盲回退)
        winClass := ""
        winExe := ""
        try {
            winClass := WinGetClass("A")
        } catch {
            winClass := ""
        }
        try {
            winExe := WinGetProcessName("A")
        } catch {
            winExe := ""
        }

        ; 先按 exe 匹配
        for name, win in this.WinList {
            if (name = "__global__")
                continue
            if (win.WinFile != "" && winExe = win.WinFile)
                return name
        }
        ; 再按 class 匹配
        for name, win in this.WinList {
            if (name = "__global__")
                continue
            if (win.WinClass != "" && winClass = win.WinClass)
                return name
        }
        return "__global__"
    }

    ; === 键名转换 ===
    Convert2VIM(key) {
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
        ; Vim 格式 -> AHK 格式
        this.CheckCapsLock(key)
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
                return ToSend ? "+" this.CheckToSend(m[1]) : "+" m[1]
            if RegExMatch(key, "i)^LS\-(.*)", &m)
                return ToSend ? "<+" this.CheckToSend(m[1]) : "<+" m[1]
            if RegExMatch(key, "i)^RS\-(.*)", &m)
                return ToSend ? ">+" this.CheckToSend(m[1]) : ">+" m[1]
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

    CheckToSend(key) {
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

; === Action - 动作对象 ===
class Action {
    Name := ""
    Comment := ""
    Type := 0  ; 0=Label, 1=Function, 2=CmdLine, 3=HotString
    Function := ""
    CmdLine := ""
    HotString := ""
    MaxTimes := 99

    __New(name) {
        this.Name := name
    }

    SetFunction(funcName) {
        this.Type := 1
        this.Function := funcName
    }

    Do(count := 1) {
        switch this.Type {
            case 0:  ; 函数调用 - 去掉 <> 再调用 (直调, 缺失走 OnError 网)
                funcName := ActionToFuncName(this.Name)

                ; 检查是否是 TC cm_ 命令
                if RegExMatch(funcName, "^cm_(.+)$", &cmMatch) {
                    ; 映射 cm_ 命令到 SendPos 编号
                    cmNum := TC_GetCommandNumber(funcName)
                    if (cmNum > 0) {
                        TC_SendPos(cmNum)
                        return
                    }
                }

                %funcName%()
            case 1:  ; Function (直调, 缺失走 OnError 网)
                f := this.Function
                %f%()
            case 2:  ; CmdLine
                Run this.CmdLine
            case 3:  ; HotString
                Send this.HotString
        }
    }
}

; === Plugin - 插件对象 ===
class Plugin {
    PluginName := ""
    Author := ""
    Ver := ""
    Comment := ""

    __New(name, author, ver, comment) {
        this.PluginName := name
        this.Author := author
        this.Ver := ver
        this.Comment := comment
    }

    CheckSub() {
        ; 直调同名函数 (缺失走 OnError 网); 本构建无 Func()
        pn := this.PluginName
        %pn%()
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
    if IsObject(g_VimEngine) {
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
    return out
}
