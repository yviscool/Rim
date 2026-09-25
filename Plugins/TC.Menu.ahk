#Requires AutoHotkey v2.0
#Warn All, Off

; === TC.Menu - 自造 Gui 菜单 + 新建文件对话框 (定位/级联/字母跳转/回车确认, 组装见 TotalCommander.ahk) ===

; 菜单弹出位置: 焦点控件原点 (对原版 ControlGetFocus+ControlGetPos, 不限列表框);
; 取不到焦点时回退 TC 窗口左上+偏移; v2 Menu.Show/Gui.Show 坐标即屏幕坐标)
TC_MenuPos(&mx, &my) {
    if TC_FocusRect(&mx, &my) {
        return
    }
    try {
        WinGetPos(&wx, &wy, , , "ahk_class TTOTAL_CMD")
        mx := wx + 100
        my := wy + 100
        try FileAppend(A_Now . " TCMENUPOS fallback-win " mx "," my "`n", A_ScriptDir "\Rim.error.log")
        catch {
        }
        return
    }
    mx := 0
    my := 0
}

; TC 焦点控件矩形左上 (屏幕坐标; 原版即取焦点控件, 不限列表)
TC_FocusRect(&xn, &yn) {
    try {
        hwnd := ControlGetFocus("ahk_class TTOTAL_CMD")
        if (!hwnd)
            return false
        cls := ""
        try cls := ControlGetClassNN(hwnd)
        catch {
        }
        rc := Buffer(16, 0)
        DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rc)
        xn := NumGet(rc, 0, "Int")
        yn := NumGet(rc, 4, "Int")
        xw := NumGet(rc, 8, "Int")
        yh := NumGet(rc, 12, "Int")
        try FileAppend(A_Now . " TCLISTBOX cls=" cls " rect=" xn "," yn "," xw "," yh "`n", A_ScriptDir "\Rim.error.log")
        catch {
        }
        return true
    }
    return false
}

; TC 安装目录下的模板仓 (对原版 TCDir\shellnew\)
TC_ShellNewDir() {
    global TCPath
    dir := ""
    try {
        if (TCPath != "")
            SplitPath(TCPath, , &dir)
    }
    return dir != "" ? dir "\shellnew\" : ""
}

; 模板仓文件项: [{label, path}] (label 带首字母前缀可键盘定位, 对原版两式 FileTempMenuCheck)
TC_ShellNewDirTemplates(newStyle := true) {
    items := []
    sndir := TC_ShellNewDir()
    if (sndir = "" || !DirExist(sndir))
        return items
    idx := 0
    Loop Files, sndir "*.*" {
        idx++
        name := A_LoopFileName
        prefix := newStyle ? SubStr(name, 1, 1) : Chr(64 + idx)
        items.Push({label: prefix " >> " name, path: A_LoopFileFullPath, ext: A_LoopFileExt = "" ? "" : "." A_LoopFileExt})
    }
    return items
}

; 注册表 ShellNew 类型: [{desc, ext, src, blank}]
; (对原版 ReadNewFile: 连续同 ext 去重; 模板源即模板仓下的 FileName, 找不到按空文件走)
TC_RegistryNewTemplates() {
    items := []
    lastExt := ""
    sndir := TC_ShellNewDir()
    try {
        Loop Reg, "HKEY_CLASSES_ROOT", "K" {
            ext := A_LoopRegName
            if (SubStr(ext, 1, 1) != "." || ext = ".lnk")
                continue
            fn := ""
            hasShellNew := false
            try {
                fn := RegRead("HKEY_CLASSES_ROOT\" ext "\ShellNew", "FileName")
                hasShellNew := true
            } catch {
                try {
                    RegRead("HKEY_CLASSES_ROOT\" ext "\ShellNew", "NullFile")
                    hasShellNew := true
                } catch {
                }
            }
            if !hasShellNew
                continue
            if (ext = lastExt)
                continue
            lastExt := ext
            ft := ""
            try ft := RegRead("HKEY_CLASSES_ROOT\" ext)
            catch {
            }
            desc := ft
            if (ft != "") {
                try desc := RegRead("HKEY_CLASSES_ROOT\" ft)
                catch {
                    desc := ft
                }
            }
            if (desc = "")
                desc := ext
            src := (fn != "" && sndir != "") ? sndir fn : ""
            items.Push({desc: desc, ext: ext, src: src, blank: (src = "" || !FileExist(src))})
        }
    }
    return items
}

; === TC 弹出菜单 (Gui 实现, 替代 Menu() 对象) ===
; 背景: v2 的 Menu() 弹 XAML 岛窗口, 不抢键盘焦点 —— 按键落在 TC 主窗,
; 钩子吞掉有映射的键、原生键又进错窗, 菜单就"看得见按不动"。
; 此 helper 用可聚焦 Gui+ListBox, 原生支持字母跳转/上下, 回车确认/Esc 返回/双击确认,
; 失焦自动取消, 子级单窗 drill-in (Enter 进/Esc 退), 弹出即聚焦, TC 钩子因活动窗不同而静默。
; items: [{label, run}] | [{label, sub:[...]}] (run 为零参可调用对象, 常用 MakeMenuCb 绑定)
global g_TCMenuGui := "", g_TCMenuLV := "", g_TCMenuIL := 0, g_TCMenuItems := [], g_TCMenuStack := [], g_TCMenuTimer := "", g_TCMenuShownTick := 0, g_TCMenuKeys := [], g_TCMenuFocusHwnd := 0
; 上一次菜单矩形 (菜单关闭/进二级前保存, 供子菜单级联与新建文件对话框定位到首菜单右侧)
global g_TCMenuLastX := -1, g_TCMenuLastY := -1, g_TCMenuLastW := 0, g_TCMenuLastH := 0

; 文件类型图标解析 (对原版 RegGetNewFileIcon + shellnew\icons\<ext>.ico 逻辑)
; 返回 {file, idx}, 取不到时 file="" (调用方显示无图标行)
TC_ResolveIcon(ext := "") {
    out := {file: "", idx: 1}
    sndir := TC_ShellNewDir()
    if (ext != "") {
        cleanExt := RegExReplace(ext, "^\.", "")
        if (sndir != "" && FileExist(sndir "icons\" cleanExt ".ico")) {
            out.file := sndir "icons\" cleanExt ".ico"
            out.idx := 1
            return out
        }
        ft := ""
        try ft := RegRead("HKEY_CLASSES_ROOT\" ext)
        catch {
        }
        if (ft != "") {
            iconVal := ""
            try iconVal := RegRead("HKEY_CLASSES_ROOT\" ft "\DefaultIcon")
            catch {
            }
            if (iconVal != "") {
                iconVal := StrReplace(iconVal, "%SystemRoot%", A_WinDir)
                iconVal := StrReplace(iconVal, "%systemroot%", A_WinDir)
                iconVal := StrReplace(iconVal, "%ProgramFiles%", A_ProgramFiles)
                iconVal := StrReplace(iconVal, '"', "")
                commaPos := InStr(iconVal, ",", 0, -1)
                if (commaPos > 0) {
                    idxStr := Trim(SubStr(iconVal, commaPos + 1))
                    iconVal := Trim(SubStr(iconVal, 1, commaPos - 1))
                    if RegExMatch(idxStr, "^-?\d+$") {
                        idxNum := Integer(idxStr)
                        out.idx := idxNum >= 0 ? idxNum + 1 : idxNum
                    }
                }
                if FileExist(iconVal)
                    out.file := iconVal
            }
        }
    }
    if (out.file = "") {
        out.file := A_WinDir "\system32\Shell32.dll"
        out.idx := 1
    }
    return out
}

TC_PopupMenu(items, x, y) {
    global g_TCMenuGui, g_TCMenuLV, g_TCMenuIL, g_TCMenuItems, g_TCMenuStack, g_TCMenuTimer, g_TCMenuShownTick, g_TCMenuFocusHwnd
    global g_TCMenuLastX, g_TCMenuLastY, g_TCMenuLastW, g_TCMenuLastH
    TC_ClosePopupMenu()
    if (items.Length = 0)
        return
    ; 清掉 TC 侧残留前缀 (之前按过 f/g 等提示框还开着时再按 i, 否则组合键逻辑吃掉首键)
    try {
        global g_VimEngine
        if IsObject(g_VimEngine) {
            tcw := g_VimEngine.GetWin("TTOTAL_CMD")
            if IsObject(tcw) {
                tcw.KeyTemp := ""
                tcw.Count := 0
                tcw.HideMore()
            }
        }
    }
    g_TCMenuStack := []
    g_TCMenuItems := items
    try g_TCMenuFocusHwnd := ControlGetFocus("ahk_class TTOTAL_CMD")
    catch {
        g_TCMenuFocusHwnd := 0
    }
    g := Gui("+ToolWindow -Caption +AlwaysOnTop", "TCMenu")
    g.BackColor := "FFFFFF"
    try {
        tcHwnd := WinExist("ahk_class TTOTAL_CMD")
        if (tcHwnd)
            g.Opt("+Owner" tcHwnd)
    }
    n := items.Length
    rows := n < 2 ? 2 : (n > 16 ? 16 : n)
    listW := TC_MenuFitWidth(items)
    lv := g.Add("ListView", "x0 y0 w" listW " h" rows * 20 " -Hdr -Multi NoSortHdr NoSort BackgroundFFFFFF", [""])
    lv.ModifyCol(1, listW - 24)
    TC_MenuLoadItems(g, lv, items)
    try lv.Modify(1, "Select Focus")
    catch {
    }
    okBtn := g.Add("Button", "x" listW - 1 " y0 w1 h1 Default", "OK")
    lv.OnEvent("DoubleClick", (*) => TC_MenuConfirm())
    okBtn.OnEvent("Click", (*) => TC_MenuConfirm())
    g.OnEvent("Escape", (*) => TC_MenuBackOrClose())
    g.OnEvent("Close", (*) => TC_ClosePopupMenu())
    w := listW
    h := rows * 20
    if (x + w > A_ScreenWidth)
        x := A_ScreenWidth - w
    if (y + h > A_ScreenHeight)
        y := A_ScreenHeight - h
    if (x < 0)
        x := 0
    if (y < 0)
        y := 0
    g.Show("x" x " y" y " w" w " h" h)
    try lv.Focus()
    catch {
    }
    ; 同进程抢前台不一定成功 (TC 是另一进程), 显式激活一次; 失败走下面的 KeyHandler 竞态兜底
    try WinActivate("ahk_id " g.Hwnd)
    catch {
    }
    ; 字母键常驻 (注册时已绑, 见 RegisterPlugin_TotalCommander 尾; 此处不再逐弹绑定)
    g_TCMenuGui := g
    g_TCMenuLV := lv
    g_TCMenuShownTick := A_TickCount
    try FileAppend(A_Now . " IFDBG popup show x=" x " y=" y " w=" w " h=" h " items=" n "`n", A_ScriptDir "\Rim.error.log")
    catch {
    }
    ; 记住本次菜单矩形 (子菜单级联/新建文件对话框定位到其右侧用)
    g_TCMenuLastX := x
    g_TCMenuLastY := y
    g_TCMenuLastW := w
    g_TCMenuLastH := h
    g_TCMenuTimer := () => TC_MenuAutoClose()
    SetTimer(g_TCMenuTimer, 200)
}

; 字母/数字直达键 (弹窗作用域, 开弹注册/关弹注销):
; 原生 ListView 跳转受 IME/焦点/钩子回环影响不可靠, 这里显式接管, 且同首字母可循环定位
TC_MenuBindKeys() {
    global g_TCMenuKeys
    TC_MenuUnbindKeys()
    try HotIfWinActive("TCMenu ahk_class AutoHotkeyGUI")
    catch {
    }
    Loop 26 {
        ch := Chr(96 + A_Index)
        try {
            cb := MakeMenuCb("TC_MenuLetterJump", ch)
            Hotkey("$" ch, cb, "On")
            g_TCMenuKeys.Push({key: "$" ch, cb: cb})
        }
    }
    Loop 10 {
        ch := "" Mod(A_Index, 10)
        try {
            cb := MakeMenuCb("TC_MenuLetterJump", ch)
            Hotkey("$" ch, cb, "On")
            g_TCMenuKeys.Push({key: "$" ch, cb: cb})
        }
    }
    try HotIfWinActive()
    catch {
    }
}

TC_MenuUnbindKeys() {
    global g_TCMenuKeys
    try HotIfWinActive("TCMenu ahk_class AutoHotkeyGUI")
    catch {
    }
    for rec in g_TCMenuKeys {
        try Hotkey(rec.key, "Off")
    }
    g_TCMenuKeys := []
    try HotIfWinActive()
    catch {
    }
}

; 跳到以该字母/数字开头的行: 唯一命中直接执行 (i 菜单按 F 即建文件夹, 免回车),
; 多个命中则从当前行之后循环定位, 回车确认; 无匹配不动
TC_MenuLetterJump(ch) {
    global g_TCMenuGui, g_TCMenuLV, g_TCMenuItems
    if !IsObject(g_TCMenuGui)
        return
    n := g_TCMenuItems.Length
    if (n = 0)
        return
    L := StrUpper(ch)
    matches := []
    Loop n {
        try {
            if (StrUpper(SubStr(g_TCMenuItems[A_Index].label, 1, 1)) = L)
                matches.Push(A_Index)
        }
    }
    try FileAppend(A_Now . " IFDBG letterjump ch=" ch " matches=" matches.Length "`n", A_ScriptDir "\Rim.error.log")
    catch {
    }
    if (matches.Length = 0)
        return
    if (matches.Length = 1) {
        try g_TCMenuLV.Modify(matches[1], "Select Focus")
        catch {
        }
        TC_MenuConfirm()
        return
    }
    cur := 0
    try cur := g_TCMenuLV.GetNext(0, "Focused")
    catch {
    }
    Loop n {
        i := Mod(cur + A_Index - 1, n) + 1
        try {
            if (StrUpper(SubStr(g_TCMenuItems[i].label, 1, 1)) = L) {
                g_TCMenuLV.Modify(i, "Select Focus")
                g_TCMenuLV.Focus()
                return
            }
        }
    }
}

; Engine 竞态兜底直调入口: 菜单开着但焦点还在 TC 时, KeyHandler 不经 Send
; ($ 热键收不到 Send 来的键, 且 WinActivate+Sleep 会吞掉快速连按的第二个键),
; 而是直接把归一化后的 vimKey 路由到菜单. 返回 true=已消费.
; 注意 vimKey 已由 NormalizeVimKey 归一: 大写字母形如 <S-F>,  digits 为 "0".."9".
TC_MenuRouteKey(vimKey) {
    global g_TCMenuGui
    if !IsObject(g_TCMenuGui)
        return false
    if (vimKey = "<ESCAPE>" || vimKey = "<ESC>") {
        TC_MenuBackOrClose()
        return true
    }
    if (vimKey = "<ENTER>") {
        TC_MenuConfirm()
        return true
    }
    if (vimKey = "<UP>") {
        TC_MenuMoveSel(-1)
        return true
    }
    if (vimKey = "<DOWN>") {
        TC_MenuMoveSel(1)
        return true
    }
    ch := ""
    if RegExMatch(vimKey, "^<S\-(.)>$", &m)
        ch := m[1]
    else if (StrLen(vimKey) = 1)
        ch := vimKey
    else
        return false
    if RegExMatch(ch, "^[a-zA-Z0-9]$") {
        TC_MenuLetterJump(ch)
        return true
    }
    return false
}

; 上下移动选中行 (供路由直调; 原生 ListView 焦点不在时上下键进错窗)
TC_MenuMoveSel(delta) {
    global g_TCMenuGui, g_TCMenuLV, g_TCMenuItems
    if !IsObject(g_TCMenuGui)
        return
    n := g_TCMenuItems.Length
    if (n = 0)
        return
    cur := TC_MenuCurrentIdx()
    if (cur < 1)
        cur := delta > 0 ? 0 : n + 1
    nxt := Mod(cur - 1 + delta + n, n) + 1
    try {
        g_TCMenuLV.Modify(nxt, "Select Focus")
        g_TCMenuLV.Focus()
    }
}

; 子菜单级联: 同窗 drill-in 时把窗口搬到父菜单右侧 (对原生子菜单向右展开),
; 屏边钳制; 无矩形时不动
TC_MenuCascadeRight() {
    global g_TCMenuGui, g_TCMenuLastX, g_TCMenuLastY, g_TCMenuLastW, g_TCMenuLastH
    if !IsObject(g_TCMenuGui)
        return
    try {
        curX := 0
        curY := 0
        curW := 0
        curH := 0
        WinGetPos(&curX, &curY, &curW, &curH, "ahk_id " g_TCMenuGui.Hwnd)
        nx := curX + curW + 4
        ny := curY
        if (nx + curW > A_ScreenWidth)
            nx := A_ScreenWidth - curW
        if (ny + curH > A_ScreenHeight)
            ny := A_ScreenHeight - curH
        if (nx < 0)
            nx := 0
        if (ny < 0)
            ny := 0
        g_TCMenuGui.Show("x" nx " y" ny)
        g_TCMenuLastX := nx
        g_TCMenuLastY := ny
    }
    catch {
    }
}

; 菜单宽度按内容自适应 (半角 8px/全角 15px 估算 + 图标边距; 原版原生菜单同为内容撑开)
TC_MenuFitWidth(items) {
    maxW := 0
    for it in items {
        w := 0
        Loop Parse, it.label {
            w += Ord(A_LoopField) < 128 ? 8 : 15
        }
        if (w > maxW)
            maxW := w
    }
    w := maxW + 56
    if (w < 170)
        w := 170
    if (w > 400)
        w := 400
    return w
}
; ListView 行加载 (图标经 ImageList; 无图标项用 Icon0)
; 注意: 全局 LV_* 函数在此 headless 探针环境会 hang, 一律用控件方法 + 原生消息
TC_MenuLoadItems(g, lv, items) {
    global g_TCMenuIL
    try {
        if (g_TCMenuIL != 0)
            IL_Destroy(g_TCMenuIL)
    }
    catch {
    }
    g_TCMenuIL := IL_Create(8)
    try DllCall("SendMessage", "Ptr", lv.Hwnd, "UInt", 0x1003, "Ptr", 1, "Ptr", g_TCMenuIL)
    catch {
    }
    for it in items {
        iconIdx := 0
        if it.HasOwnProp("icon") {
            try {
                got := IL_Add(g_TCMenuIL, it.icon.file, it.icon.idx)
                if (got > 0)
                    iconIdx := got
            }
        }
        if (iconIdx > 0)
            lv.Add("Icon" iconIdx, it.label)
        else
            lv.Add(, it.label)
    }
}

TC_MenuSetItems(items) {
    global g_TCMenuLV, g_TCMenuGui, g_TCMenuItems
    g_TCMenuItems := items
    try {
        g_TCMenuLV.Delete()
        TC_MenuLoadItems(g_TCMenuGui, g_TCMenuLV, items)
        g_TCMenuLV.Modify(1, "Select Focus")
    }
}

TC_MenuCurrentIdx() {
    global g_TCMenuLV
    idx := 0
    try idx := g_TCMenuLV.GetNext(0)
    catch {
    }
    if (!idx) {
        try idx := g_TCMenuLV.GetNext(0, "Focused")
        catch {
        }
    }
    return idx
}

TC_MenuConfirm() {
    global g_TCMenuGui, g_TCMenuItems, g_TCMenuStack
    global g_TCMenuLastX, g_TCMenuLastY, g_TCMenuLastW, g_TCMenuLastH
    if !IsObject(g_TCMenuGui)
        return
    idx := TC_MenuCurrentIdx()
    if (idx < 1 || idx > g_TCMenuItems.Length)
        return
    it := g_TCMenuItems[idx]
    try FileAppend(A_Now . " IFDBG confirm idx=" idx " label=" it.label "`n", A_ScriptDir "\Rim.error.log")
    catch {
    }
    if it.HasOwnProp("sub") {
        ; 进二级前记住父菜单矩形, 子级向其右侧级联 (原版原生子菜单即向右展开)
        try {
            WinGetPos(&px, &py, &pw, &ph, "ahk_id " g_TCMenuGui.Hwnd)
            g_TCMenuLastX := px
            g_TCMenuLastY := py
            g_TCMenuLastW := pw
            g_TCMenuLastH := ph
        }
        g_TCMenuStack.Push(g_TCMenuItems)
        TC_MenuSetItems(it.sub)
        TC_MenuCascadeRight()
        return
    }
    ; 叶子执行前记住菜单矩形, 供新建文件对话框贴到菜单右侧 (而非回退到列表左上)
    try {
        WinGetPos(&lx, &ly, &lw, &lh, "ahk_id " g_TCMenuGui.Hwnd)
        g_TCMenuLastX := lx
        g_TCMenuLastY := ly
        g_TCMenuLastW := lw
        g_TCMenuLastH := lh
    }
    cb := it.run
    TC_ClosePopupMenu()
    try cb()
    catch as e {
        try FileAppend(A_Now . " TCPOPUP-ERR: " . e.Message . " @" . e.Line . "`n", A_ScriptDir . "\Rim.error.log")
        catch {
        }
    }
}

TC_MenuBackOrClose() {
    global g_TCMenuStack
    if (g_TCMenuStack.Length > 0) {
        parent := g_TCMenuStack.Pop()
        TC_MenuSetItems(parent)
        return
    }
    TC_ClosePopupMenu()
}

TC_ClosePopupMenu() {
    global g_TCMenuGui, g_TCMenuLV, g_TCMenuIL, g_TCMenuItems, g_TCMenuStack, g_TCMenuTimer, g_TCMenuFocusHwnd
    global g_TCMenuLastX, g_TCMenuLastY, g_TCMenuLastW, g_TCMenuLastH
    ; 关弹前留住矩形 (模板项关菜单即弹新建文件对话框, 对话框贴此矩形右侧)
    ; 字母键常驻不再解绑 (HotIf 作用域休眠, 见 RegisterPlugin_TotalCommander 尾)
    try {
        if IsObject(g_TCMenuGui) {
            WinGetPos(&cx, &cy, &cw, &ch, "ahk_id " g_TCMenuGui.Hwnd)
            if (cw > 0) {
                g_TCMenuLastX := cx
                g_TCMenuLastY := cy
                g_TCMenuLastW := cw
                g_TCMenuLastH := ch
            }
        }
    }
    catch {
    }
    try {
        if (g_TCMenuTimer != "")
            SetTimer(g_TCMenuTimer, 0)
    }
    catch {
    }
    g_TCMenuTimer := ""
    popupHwnd := 0
    try {
        if IsObject(g_TCMenuGui) {
            popupHwnd := g_TCMenuGui.Hwnd
            g_TCMenuGui.Destroy()
        }
    }
    catch {
    }
    try {
        if (g_TCMenuIL != 0)
            IL_Destroy(g_TCMenuIL)
    }
    catch {
    }
    ; 焦点归位 (Gui 抢过激活, 关后送回 TC 原控件; 用户已切去别处则不动。
    ; 否则第二次起按 i 时焦点不在列表, 菜单永远弹回退位置)
    try {
        curHwnd := WinExist("A")
        tcHwnd := WinExist("ahk_class TTOTAL_CMD")
        if (tcHwnd && (curHwnd = popupHwnd || curHwnd = tcHwnd || curHwnd = 0)) {
            WinActivate("ahk_class TTOTAL_CMD")
            if (g_TCMenuFocusHwnd != 0)
                ControlFocus(g_TCMenuFocusHwnd, "ahk_class TTOTAL_CMD")
        }
    }
    catch {
    }
    g_TCMenuIL := 0
    g_TCMenuGui := ""
    g_TCMenuLV := ""
    g_TCMenuItems := []
    g_TCMenuStack := []
    g_TCMenuFocusHwnd := 0
}

; 失焦自动取消 (菜单语义: 点别处=取消; 500ms 宽限避开 Show 瞬间的激活竞态)
TC_MenuAutoClose() {
    global g_TCMenuGui, g_TCMenuShownTick
    if !IsObject(g_TCMenuGui)
        return
    if (A_TickCount - g_TCMenuShownTick < 500)
        return
    try {
        if !WinActive("ahk_id " . g_TCMenuGui.Hwnd)
            TC_ClosePopupMenu()
    } catch {
    }
}

; i: 新风格菜单 (1:1 对原版 <TC_CreateNewFileNewStyle>: 文件夹/快捷方式/仓模板)
TC_CreateNewFileNewStyle() {
    shellDll := A_WinDir "\system32\Shell32.dll"
    items := [
        {label: "F >> " . T("tc.new_folder"), run: (*) => TC_SendPos(907), icon: {file: shellDll, idx: 4}},
        {label: "S >> " . T("tc.new_shortcut"), run: (*) => TC_SendPos(1004), icon: {file: shellDll, idx: 264}}
    ]
    for tp in TC_ShellNewDirTemplates(true)
        items.Push({label: tp.label, run: MakeMenuCb("TC_NewFileFromTemplate", tp.path), icon: TC_ResolveIcon(tp.ext)})
    TC_MenuPos(&xn, &yn)
    TC_PopupMenu(items, xn, yn)
}

; I: 完整菜单 (1:1 对原版 <TC_CreateNewFile>: 0 新建文件/1 文件夹/2 快捷方式/3 加模板 + 仓模板)
TC_CreateNewFile() {
    shellDll := A_WinDir "\system32\Shell32.dll"
    regItems := []
    n := 0
    for r in TC_RegistryNewTemplates() {
        n++
        regItems.Push({label: Chr(65 + Mod(n - 1, 26)) " >> " r.desc " (" r.ext ")", run: MakeMenuCb("TC_NewFileFromReg", r), icon: TC_ResolveIcon(r.ext)})
    }
    items := []
    if (n > 0)
        items.Push({label: "0 " . T("tc.new_regfile"), sub: regItems})
    items.Push({label: "1 " . T("tc.new_folder"), run: (*) => TC_SendPos(907), icon: {file: shellDll, idx: 4}})
    items.Push({label: "2 " . T("tc.new_shortcut"), run: (*) => TC_SendPos(1004), icon: {file: shellDll, idx: 264}})
    items.Push({label: "3 " . T("tc.new_addtpl"), run: (*) => TC_AddToTemplate()})
    for tp in TC_ShellNewDirTemplates(false)
        items.Push({label: tp.label, run: MakeMenuCb("TC_NewFileFromTemplate", tp.path), icon: TC_ResolveIcon(tp.ext)})
    TC_MenuPos(&xn, &yn)
    TC_PopupMenu(items, xn, yn)
}

TC_NewFileFromTemplate(srcPath, *) {
    TC_NewFileDialog(srcPath, "", false)
}

TC_NewFileFromReg(r, *) {
    TC_NewFileDialog(r.src, r.ext, r.blank)
}

; 新建文件对话框 (对原版 NewFile(): 模板源只读 + 文件名 + 确认/取消, 有主名时预选)
TC_NewFileDialog(srcPath := "", ext := "", blank := false) {
    global g_TCMenuLastX, g_TCMenuLastY, g_TCMenuLastW, g_TCMenuLastH
    if (blank || srcPath = "" || !FileExist(srcPath)) {
        fileName := "New" (ext != "" ? ext : "")
        srcShow := T("tc.new_blank") (ext != "" ? " (" ext ")" : "")
        srcPath := ""
        blank := true
    } else {
        SplitPath(srcPath, &fileName)
        srcShow := srcPath
    }
    SplitPath(fileName, , , , &noExt)
    dlg := Gui(, T("tc.title_newfile"))
    dlg.Add("Text", "x12 y20 w50 h20 +Center", T("tc.new_source"))
    dlg.Add("Edit", "x72 y20 w300 h20 ReadOnly Disabled", srcShow)
    dlg.Add("Text", "x12 y50 w50 h20 +Center", T("tc.new_filename"))
    nameEdit := dlg.Add("Edit", "x72 y50 w300 h20", fileName)
    okBtn := dlg.Add("Button", "x162 y80 w90 h30 Default", T("tc.new_confirm"))
    cancelBtn := dlg.Add("Button", "x282 y80 w90 h30", T("tc.new_cancel"))
    okBtn.OnEvent("Click", (*) => TC_DoCreateFile(dlg, nameEdit.Text, srcPath, blank))
    cancelBtn.OnEvent("Click", (*) => dlg.Destroy())
    dlg.OnEvent("Close", (*) => dlg.Destroy())
    dlg.OnEvent("Escape", (*) => dlg.Destroy())
    ; 贴到首菜单右侧 (菜单关弹前已记矩形; 无矩形才居中. 原版新建文件窗即跟在菜单旁,
    ; 之前无坐标 Show 默认居中/回列表左上, 与菜单脱节)
    dlgX := ""
    dlgY := ""
    if (g_TCMenuLastX >= 0) {
        dlgX := g_TCMenuLastX + g_TCMenuLastW + 8
        dlgY := g_TCMenuLastY
        if (dlgX + 400 > A_ScreenWidth)
            dlgX := g_TCMenuLastX - 408
        if (dlgX < 0)
            dlgX := 0
        if (dlgY + 120 > A_ScreenHeight)
            dlgY := A_ScreenHeight - 120
        if (dlgY < 0)
            dlgY := 0
    }
    if (dlgX = "")
        dlg.Show("w400 h120")
    else
        dlg.Show("x" dlgX " y" dlgY " w400 h120")
    try FileAppend(A_Now . " IFDBG newfiledlg x=" dlgX " y=" dlgY " menulast=" g_TCMenuLastX "," g_TCMenuLastY "," g_TCMenuLastW "," g_TCMenuLastH "`n", A_ScriptDir "\Rim.error.log")
    catch {
    }
    if (noExt != "") {
        try {
            nameEdit.Focus()
            PostMessage(0xB1, 0, StrLen(noExt), "ahk_id " nameEdit.Hwnd)  ; EM_SETSEL 选中主名
        }
    }
}

; 落盘: 目标目录走剪贴板 (对原版 cm_CopySrcPathToClip, 比标题栏解析可靠);
; 完事刷新 + 光标定位到新文件
TC_DoCreateFile(dlg, newName, srcPath, blank) {
    newName := Trim(newName)
    if (newName = "")
        return
    dst := TC_ClipCmd(2029, 2)  ; cm_CopySrcPathToClip
    if (dst = "")
        dst := TC_GetCurrentDir()
    if RegExMatch(dst, "^\\\\(计算机|所有控制面板项|Fonts|网络|打印机|回收站)$")
        return
    if RegExMatch(dst, "^\\\\桌面$")
        dst := A_Desktop
    if (dst = "")
        return
    newPath := dst "\" newName
    if FileExist(newPath) {
        if (MsgBox(T("tc.new_overwrite"), T("tc.confirm_title"), "YesNo") != "Yes")
            return
    }
    try {
        if (blank || srcPath = "" || !FileExist(srcPath)) {
            f := FileOpen(newPath, "w")
            f.Close()
        } else {
            FileCopy(srcPath, newPath, true)
        }
    } catch as e {
        MsgBox(T("tc.create_failed", e.Message), T("tc.err_title"))
        return
    }
    try dlg.Destroy()
    catch {
    }
    try WinActivate("ahk_class TTOTAL_CMD")
    TC_SendPos(540)  ; cm_RereadSource
    Sleep 200
    TC_FocusListText(newName)
}

; 3 添加到新模板 (对原版 AddToTempFiles+AddTempOK: 取选中文件全路径拷进模板仓)
TC_AddToTemplate() {
    addPath := TC_ClipCmd(2018, 2)  ; cm_CopyFullNamesToClip
    if (addPath = "" || !FileExist(addPath))
        return
    SplitPath(addPath, &fileName)
    try {
        ibox := InputBox(T("tc.new_tplname"), T("tc.new_tpltitle"), , fileName)
        newName := Trim(ibox.Value)
    } catch {
        return
    }
    if (newName = "")
        return
    sndir := TC_ShellNewDir()
    if (sndir = "")
        return
    try DirCreate(sndir)
    try FileCopy(addPath, sndir newName, true)
    catch as e {
        MsgBox(T("tc.create_failed", e.Message), T("tc.err_title"))
    }
}

; 对原版 TC_Run: 把命令打进 TC 下方命令行并回车执行 (64 位 Edit1; 非直接 Run)
TC_Run(cmd := "") {
    if (cmd = "")
        return
    try {
        ControlSetText(cmd, "Edit1", "ahk_class TTOTAL_CMD")
        ControlSend("{Enter}", "Edit1", "ahk_class TTOTAL_CMD")
    } catch {
        Run(cmd)
    }
}

TC_GetCurrentDir() {
    ; 获取 TC 当前目录 (v2: WinGetTitle/ControlGetText 直接返回值)
    try {
        title := WinGetTitle("ahk_class TTOTAL_CMD")
        ; 从标题栏提取路径
        if RegExMatch(title, "([A-Z]:\\[^\s]*)", &match) {
            return match[1]
        }
    } catch {
    }

    ; 备用：尝试从控件获取
    try {
        ; 获取左侧路径
        text1 := ControlGetText("Edit1", "ahk_class TTOTAL_CMD")
        if (text1 != "" && RegExMatch(text1, "^([A-Z]:\\)", &pathMatch))
            return pathMatch[1]
    } catch {
    }

    return ""
}

TC_CreateBlankFile() {
    ; 创建空文件
    currentDir := TC_GetCurrentDir()
    if (currentDir = "") {
        MsgBox(T("tc.no_curdir"), T("tc.title_newfile"))
        return
    }

    try {
        ibox2 := InputBox(T("tc.input_empty_name"), T("tc.title_empty_file"))
        fileName := ibox2.Value
    } catch {
        return
    }
    if (fileName = "")
        return

    filePath := currentDir "\" fileName
    try {
        f := FileOpen(filePath, "w")
        f.Close()
        Log("TC: Created blank file " filePath)
    } catch as e {
        MsgBox(T("tc.create_failed", e.Message), T("tc.err_title"))
    }
}

; 发 cm_ 并取剪贴板结果 (对原版 GoSub+ClipWait: 先清空再等, 超时不抛错)
TC_ClipCmd(cmdNum, timeout := 2) {
    result := ""
    try {
        old := ClipboardAll()
        A_Clipboard := ""
        TC_SendPos(cmdNum)
        try ClipWait(timeout)
        catch {
        }
        result := A_Clipboard
        try A_Clipboard := old
        catch {
        }
    } catch {
    }
    return result
}

; 在当前 TC 列表框里定位首个命中的行 (对原版 ControlGet List+Parse+0x19E;
;  v2 ControlGetText 读 ListBox 恒为空, 改用 LB_GETCOUNT/LB_GETTEXT 消息取数)
TC_FocusListText(pattern) {
    focused := ""
    try focused := FocusedClassNN("ahk_class TTOTAL_CMD")
    if (focused = "")
        return false
    if !(InStr(focused, "LCLListBox") || InStr(focused, "TMyListBox"))
        return false
    cnt := 0
    try cnt := SendMessage(0x18B, 0, 0, focused, "ahk_class TTOTAL_CMD")
    if (!cnt)
        return false
    Loop cnt {
        idx := A_Index - 1
        len := 0
        try len := SendMessage(0x18A, idx, 0, focused, "ahk_class TTOTAL_CMD")
        if (!len)
            continue
        buf := Buffer((len + 1) * 2, 0)
        try SendMessage(0x189, idx, buf, focused, "ahk_class TTOTAL_CMD")
        txt := ""
        try txt := StrGet(buf, "UTF-16")
        if (txt != "" && RegExMatch(txt, pattern)) {
            PostMessage(0x19E, idx, 1, focused, "ahk_class TTOTAL_CMD")
            return true
        }
    }
    return false
}

; <TC_GoToParentEx>: 返回上层, 根目录则进驱动器列表并定位当前盘 (1:1 对原版 IsRootDir+cm_GoToParent)
TC_GoToParentEx() {
    path := TC_ClipCmd(2029, 1)  ; cm_CopySrcPathToClip
    if RegExMatch(path, "^.:\\$") {
        TC_SendPos(2122)  ; cm_OpenDrives
        Sleep 200
        TC_FocusListText("i)" . StrReplace(path, "\", ""))
    }
    TC_SendPos(2002)  ; cm_GoToParent
}

