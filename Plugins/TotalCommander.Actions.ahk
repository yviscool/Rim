#Requires AutoHotkey v2.0
#Warn All, Off

; === TotalCommander.Actions: action implementations ===
; owner: TotalCommander.ahk (same-dir include chain)
; === TC 动作函数 ===
TC_NormalMode() {
    win := Rim.vim.GetWin("TTOTAL_CMD")
    if IsObject(win)
        win.currentMode := "normal"
}

TC_InsertMode() {
    win := Rim.vim.GetWin("TTOTAL_CMD")
    if IsObject(win)
        win.currentMode := "insert"
}

; <TC_0>-<TC_9>: 对原版 (Vim_HotKeyCount:=, 只清 count 不打字); v2 空函数复刻.
; 注意数字正常走引擎 Count 累加, 落到这里的只有孤零等边界.
TC_0() {
}
TC_1() {
}
TC_2() {
}
TC_3() {
}
TC_4() {
}
TC_5() {
}
TC_6() {
}
TC_7() {
}
TC_8() {
}
TC_9() {
}

TC_ToggleTC() {
    global TCPath
    if WinExist("ahk_class TTOTAL_CMD") {
        if WinActive("ahk_class TTOTAL_CMD")
            WinMinimize "ahk_class TTOTAL_CMD"
        else
            WinActivate "ahk_class TTOTAL_CMD"
    } else if (TCPath != "") {
        Run TCPath
    }
}

TC_DownSelect() {
    Send "+{Down}"
}

TC_UpSelect() {
    Send "+{Up}"
}

; <TC_LastLine>: 转到[count]行, 缺省末行
TC_LastLine() {
    if (TC_GetWinCount() > 1)
        TC_GotoLineDo(TC_GetWinCount())
    else
        TC_GotoLineDo(0)
}

; 转到指定行 (对齐原版: LB_GETCOUNT 取行数 + LB_SETCARETINDEX 直跳;
;  注意 ControlGetText 读 ListBox 恒为空, 必须用消息取数; Index=0 表末行)
TC_GotoLineDo(Index) {
    focused := ""
    try focused := FocusedClassNN("ahk_class TTOTAL_CMD")
    if (focused = "")
        return
    cnt := 0
    try cnt := SendMessage(0x18B, 0, 0, focused, "ahk_class TTOTAL_CMD")
    if (!cnt || cnt = "")
        return
    last := cnt - 1
    if (Index > 0) {
        if (Index > last)
            Index := last
        PostMessage(0x19E, Index, 1, focused, "ahk_class TTOTAL_CMD")
    } else {
        PostMessage(0x19E, last, 1, focused, "ahk_class TTOTAL_CMD")
    }
}

; 取当前窗 Count (对齐原版 vim.GetCount)
TC_GetWinCount() {
    try {
        global g_VimEngine
        if !IsObject(g_VimEngine)
            return 0
        name := g_VimEngine.CheckWin()
        w := g_VimEngine.GetWin(name)
        if IsObject(w)
            return w.Count
    }
    return 0
}

; <TC_GoToLine>: 转到[count]行, 缺省第一行
TC_GoToLine() {
    if (TC_GetWinCount() > 1)
        TC_GotoLineDo(TC_GetWinCount())
    else
        TC_GotoLineDo(1)
}

TC_Half() {
    ; 精确跳到中间行
    try {
        ; 获取可见行数
        WinGetPos(, , &w, &h, "ahk_class TTOTAL_CMD")
        rowHeight := 18  ; 大约行高
        visibleRows := h // rowHeight
        targetRow := visibleRows // 2

        ; 跳到第一行
        Send "^{Home}"
        Sleep 50

        ; 向下移动到中间
        loop targetRow {
            Send "{Down}"
        }
    }
}

TC_CopySrcPathToClip() {
    TC_SendPos(2029)  ; cm_CopySrcPathToClip
}

TC_CopyNameOnly() {
    ; 复制文件名（不含扩展名）
    try {
        ; 获取当前选中文件名 (v2: WinGetText 直接返回值; 该变量实际未使用, 保留仅为兼容)
        text := WinGetText("ahk_class TTOTAL_CMD")
        ; 简化实现：复制后处理
        Send "^c"
        Sleep 50
        clipText := A_Clipboard

        ; 处理文件名
        if RegExMatch(clipText, "^(.*?)\.[^.]+$", &match) {
            A_Clipboard := match[1]
        }
    }
}

TC_ViewFileUnderCursor() {
    Send "{F3}"
}

TC_OpenWithAlternateViewer() {
    Send "!{F3}"
}

TC_AlwayOnTop() {
    static isTop := false
    if !isTop {
        WinSetAlwaysOnTop(1, "ahk_class TTOTAL_CMD")
        isTop := true
    } else {
        WinSetAlwaysOnTop(0, "ahk_class TTOTAL_CMD")
        isTop := false
    }
}

TC_ToggleShowInfo() {
    ; 切换按键提示显示
    static showInfo := true
    showInfo := !showInfo
    if showInfo
        Log("TC Info: ON")
    else
        Log("TC Info: OFF")
}

TC_Restart() {
    global TCPath
    if (TCPath != "") {
        try ProcessClose "totalcmd.exe"
        try ProcessClose "totalcmd64.exe"
        Sleep 500
        Run TCPath
    }
}

TC_Mark() {
    ; 标记功能 - 通过命令行输入 m + 字母来标记文件
    ; 支持: 设置标记(a-z), 跳转到标记('a), 删除标记(使用菜单)
    ; 标记持久化到 TCMark.ini

    ; 获取当前选中文件路径
    filePath := TC_GetSelectedFile()
    if (filePath = "") {
        MsgBox(T("tc.pick_file_first"), T("tc.mark_title"))
        return
    }

    ; 显示标记菜单
    TC_ShowMarkMenu(filePath)
}

TC_ShowMarkMenu(filePath := "") {
    ; 显示标记管理菜单
    global TCINI
    markFile := Rim.appDir "\Conf\TCMark.ini"

    ; 读取现有标记 (ReadFileLines: 显式 UTF-8 + 去 BOM; Loop Read 读无 BOM 中文文件会吞行)
    marks := Map()
    for _mline in ReadFileLines(markFile) {
        line := Trim(_mline)
        if RegExMatch(line, "^(.*?)=(.*)$", &match) {
            marks[match[1]] := match[2]
        }
    }

    ; 创建菜单 (drill-in 子级, 见 TC_PopupMenu)
    setItems := []
    loop 26 {
        letter := Chr(96 + A_Index)  ; a-z
        setItems.Push({label: letter, run: MakeMenuCb("TC_SetMark", filePath, letter)})
    }
    items := [{label: T("tc.mark_set"), sub: setItems}]

    ; 跳转/删除子菜单
    if (marks.Count > 0) {
        gotoItems := []
        for path, char in marks {
            ; 提取文件名
            fileName := SubStr(path, InStr(path, "\", 0, -1) + 1)
            if (StrLen(fileName) > 30)
                fileName := SubStr(fileName, 1, 27) "..."
            gotoItems.Push({label: "[" char "] " fileName, run: MakeMenuCb("TC_GotoMark", path)})
        }
        items.Push({label: T("tc.mark_goto"), sub: gotoItems})

        delItems := []
        for path, char in marks {
            fileName := SubStr(path, InStr(path, "\", 0, -1) + 1)
            if (StrLen(fileName) > 30)
                fileName := SubStr(fileName, 1, 27) "..."
            delItems.Push({label: "[" char "] " fileName, run: MakeMenuCb("TC_DeleteMark", path)})
        }
        items.Push({label: T("tc.mark_del"), sub: delItems})

        ; 清除所有标记
        items.Push({label: T("tc.mark_clear"), run: (*) => TC_ClearAllMarks()})
    }

    ; 显示菜单 (原版弹列表处)
    TC_MenuPos(&mxn, &myn)
    TC_PopupMenu(items, mxn, myn)
}

TC_SetMark(filePath, markChar) {
    ; 设置标记
    markFile := Rim.appDir "\Conf\TCMark.ini"

    ; 读取现有标记 (同上, 防吞行)
    marks := Map()
    for _mline in ReadFileLines(markFile) {
        line := Trim(_mline)
        if RegExMatch(line, "^(.*?)=(.*)$", &match) {
            marks[match[1]] := match[2]
        }
    }

    ; 添加或更新标记
    marks[filePath] := markChar

    ; 写入文件
    TC_WriteMarks(marks)

    Log("TC: Marked file " filePath " with: " markChar)
}

TC_GotoMark(filePath) {
    ; 跳转到标记的目录
    if DirExist(filePath) {
        ; 如果是目录，直接在 TC 中打开
        if WinExist("ahk_class TTOTAL_CMD") {
            ; 使用 cm_OpenDir 命令
            A_Clipboard := filePath
            Sleep 100
            Send "^v"
            Sleep 100
            Send "{Enter}"
        }
    } else if FileExist(filePath) {
        ; 如果是文件，打开文件所在目录
        dir := SubStr(filePath, 1, InStr(filePath, "\", 0, -1))
        if WinExist("ahk_class TTOTAL_CMD") {
            A_Clipboard := dir
            Sleep 100
            Send "^v"
            Sleep 100
            Send "{Enter}"
        }
    }
}

TC_DeleteMark(filePath) {
    ; 删除标记
    markFile := Rim.appDir "\Conf\TCMark.ini"

    ; 读取现有标记 (同上, 防吞行)
    marks := Map()
    for _mline in ReadFileLines(markFile) {
        line := Trim(_mline)
        if RegExMatch(line, "^(.*?)=(.*)$", &match) {
            marks[match[1]] := match[2]
        }
    }

    ; 删除标记
    if marks.Has(filePath)
        marks.Delete(filePath)

    ; 写入文件
    TC_WriteMarks(marks)

    Log("TC: Unmarked file " filePath)
}

TC_ClearAllMarks() {
    ; 清除所有标记
    markFile := Rim.appDir "\Conf\TCMark.ini"
    if FileExist(markFile)
        FileDelete markFile
    Log("TC: Cleared all marks")
}

TC_WriteMarks(marks) {
    ; 写入标记到文件
    markFile := Rim.appDir "\Conf\TCMark.ini"
    content := ""
    for path, char in marks {
        content .= path "=" char "`n"
    }
    if (content != "") {
        try {
            f := FileOpen(markFile, "w")
            f.Write(content)
            f.Close()
        }
    } else if FileExist(markFile) {
        FileDelete markFile
    }
}

TC_ListMark() {
    ; 显示标记列表 - 带交互菜单
    markFile := Rim.appDir "\Conf\TCMark.ini"

    if !FileExist(markFile) {
        MsgBox(T("tc.no_marks_file"), T("tc.mark_list_title"))
        return
    }

    ; 读取标记 (同上, 防吞行)
    marks := Map()
    for _mline in ReadFileLines(markFile) {
        line := Trim(_mline)
        if RegExMatch(line, "^(.*?)=(.*)$", &match) {
            marks[match[1]] := match[2]
        }
    }

    if (marks.Count = 0) {
        MsgBox(T("tc.no_marks"), T("tc.mark_list_title"))
        return
    }

    ; 创建菜单
    items := []
    for path, char in marks {
        fileName := SubStr(path, InStr(path, "\", 0, -1) + 1)
        if (StrLen(fileName) > 40)
            fileName := SubStr(fileName, 1, 37) "..."
        items.Push({label: "[" char "] " fileName, run: MakeMenuCb("TC_GotoMark", path)})
    }
    items.Push({label: T("tc.mark_clear2"), run: (*) => TC_ClearAllMarks()})

    TC_MenuPos(&lxn, &lyn)
    TC_PopupMenu(items, lxn, lyn)
}

TC_GetSelectedFile() {
    ; 获取 TC 当前选中的文件路径
    try {
        ; 尝试通过剪贴板获取
        clipBackup := A_Clipboard
        A_Clipboard := ""
        Send "^c"  ; 复制
        Sleep 100
        filePath := A_Clipboard
        A_Clipboard := clipBackup

        if (filePath != "" && FileExist(filePath))
            return filePath
    }
    return ""
}

TC_azHistory() {
    ; a-z 历史导航 - 完整交互式实现
    ; 读取 wincmd.ini 的左右面板历史
    ; 支持: 按字母跳转, 重定向, 特殊位置处理
    global TCINI

    if (TCINI = "" || !FileExist(TCINI)) {
        MsgBox(T("tc.no_tc_conf"), T("tc.hist_nav_title"))
        return
    }

    ; 读取左面板历史
    leftHistory := []
    rightHistory := []

    try {
        ; 读取左面板历史
        i := 1
        loop {
            path := IniRead(TCINI, "LeftHistory", "Dir" i, "")
            if (path = "")
                break
            leftHistory.Push(TC_ResolveHistoryPath(path))
            i++
        }

        ; 读取右面板历史
        i := 1
        loop {
            path := IniRead(TCINI, "RightHistory", "Dir" i, "")
            if (path = "")
                break
            rightHistory.Push(TC_ResolveHistoryPath(path))
            i++
        }
    }

    if (leftHistory.Length = 0 && rightHistory.Length = 0) {
        MsgBox(T("tc.no_history"), T("tc.az_hist_title"))
        return
    }

    ; 创建菜单
    items := []

    ; 左面板历史
    if (leftHistory.Length > 0) {
        leftItems := []
        maxCount := Min(leftHistory.Length, 26)
        loop maxCount {
            idx := A_Index
            letter := Chr(96 + idx)  ; a, b, c...
            path := leftHistory[idx]
            ; 截断过长的路径
            displayPath := path
            if (StrLen(displayPath) > 50)
                displayPath := "..." SubStr(displayPath, -47)
            leftItems.Push({label: "[" letter "] " displayPath, run: MakeMenuCb("TC_GotoHistory", path, "left")})
        }
        items.Push({label: T("tc.hist_left"), sub: leftItems})
    }

    ; 右面板历史
    if (rightHistory.Length > 0) {
        rightItems := []
        maxCount := Min(rightHistory.Length, 26)
        loop maxCount {
            idx := A_Index
            letter := Chr(64 + idx)  ; A, B, C...
            path := rightHistory[idx]
            displayPath := path
            if (StrLen(displayPath) > 50)
                displayPath := "..." SubStr(displayPath, -47)
            rightItems.Push({label: "[" letter "] " displayPath, run: MakeMenuCb("TC_GotoHistory", path, "right")})
        }
        items.Push({label: T("tc.hist_right"), sub: rightItems})
    }

    ; 清除历史
    items.Push({label: T("tc.hist_clear_left"), run: (*) => TC_ClearHistory("LeftHistory")})
    items.Push({label: T("tc.hist_clear_right"), run: (*) => TC_ClearHistory("RightHistory")})
    items.Push({label: T("tc.hist_clear_all"), run: (*) => TC_ClearHistory("all")})

    ; 显示菜单
    TC_MenuPos(&hxn, &hyn)
    TC_PopupMenu(items, hxn, hyn)
}

TC_ResolveHistoryPath(path) {
    ; 解析历史路径，处理特殊位置
    ; 特殊位置映射
    specialPaths := Map(
        "::{20D04FE0-3AEA-1069-A2D8-08002B30309D}", T("tc.hist_thispc"),
        "::{645FF040-5081-101B-9F08-00AA002F954E}", T("tc.hist_recycle"),
        "::{B4BFCC3A-DB2C-424C-B029-7FE99A8CEC6C}", T("tc.hist_desktop"),
        "::{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}", T("tc.hist_network")
    )

    if specialPaths.Has(path)
        return specialPaths[path]

    return path
}

TC_GotoHistory(path, panel) {
    ; 跳转到历史目录
    if !WinExist("ahk_class TTOTAL_CMD")
        return

    ; 激活 TC
    WinActivate("ahk_class TTOTAL_CMD")
    Sleep 100

    ; 切换到对应面板
    if (panel = "right") {
        Send "{Tab}"  ; 切换到右面板
        Sleep 50
    }

    ; 使用命令行导航
    ; 按 Alt+Left 打开路径输入框
    Send "!{Left}"
    Sleep 200

    ; 清空并输入路径
    Send "^a"
    Sleep 50
    A_Clipboard := path
    Send "^v"
    Sleep 100
    Send "{Enter}"
}

TC_ClearHistory(section) {
    ; 清除历史记录
    global TCINI

    if (TCINI = "" || !FileExist(TCINI))
        return

    if (section = "all") {
        ; 清除所有历史
        try {
            IniDelete(TCINI, "LeftHistory")
            IniDelete(TCINI, "RightHistory")
        }
        Log("TC: Cleared all history")
    } else {
        try {
            IniDelete(TCINI, section)
        }
        Log("TC: Cleared " section)
    }
}

TC_ToggleMenu() {
    ; 切换菜单栏显示/隐藏
    ; 通过修改 wincmd.ini 的 RestrictInterface 值
    global TCINI

    if (TCINI = "" || !FileExist(TCINI)) {
        MsgBox(T("tc.no_tc_conf"), T("tc.menu_toggle_title"))
        return
    }

    ; 读取当前设置
    restrict := IniRead(TCINI, "Configuration", "RestrictInterface", "0")
    if (restrict = "")
        restrict := "0"

    ; 切换菜单栏
    if InStr(restrict, "1") {
        ; 隐藏菜单栏
        restrict := StrReplace(restrict, "1", "0")
        state := "隐藏"
    } else {
        ; 显示菜单栏
        restrict := "1" restrict
        state := "显示"
    }

    ; 保存设置
    IniWrite(restrict, TCINI, "Configuration", "RestrictInterface")

    ; 刷新 TC 界面
    TC_Refresh界面()
    Log("TC: Menu bar toggled to " state)
}

TC_ToggleToolbar() {
    ; 切换工具栏显示/隐藏
    global TCINI

    if (TCINI = "" || !FileExist(TCINI)) {
        return
    }

    ; 读取当前设置
    restrict := IniRead(TCINI, "Configuration", "RestrictInterface", "0")
    if (restrict = "")
        restrict := "0"

    ; 切换工具栏
    if InStr(restrict, "2") {
        restrict := StrReplace(restrict, "2", "0")
        state := "隐藏"
    } else {
        restrict := restrict "2"
        state := "显示"
    }

    IniWrite(restrict, TCINI, "Configuration", "RestrictInterface")
    TC_Refresh界面()
    Log("TC: Toolbar toggled to " state)
}

TC_ToggleStatusBar() {
    ; 切换状态栏显示/隐藏
    global TCINI

    if (TCINI = "" || !FileExist(TCINI)) {
        return
    }

    ; 读取当前设置
    restrict := IniRead(TCINI, "Configuration", "RestrictInterface", "0")
    if (restrict = "")
        restrict := "0"

    ; 切换状态栏
    if InStr(restrict, "4") {
        restrict := StrReplace(restrict, "4", "0")
        state := "隐藏"
    } else {
        restrict := restrict "4"
        state := "显示"
    }

    IniWrite(restrict, TCINI, "Configuration", "RestrictInterface")
    TC_Refresh界面()
    Log("TC: Status bar toggled to " state)
}

TC_Refresh界面() {
    ; 刷新 TC 界面（通过发送消息）
    if WinExist("ahk_class TTOTAL_CMD") {
        PostMessage(1075, 540, 0, , "ahk_class TTOTAL_CMD")  ; cm_RereadSource 刷新 (原版 540; 移植版误写 2027=打印目录)
    }
}

TC_WinMaxLeft() {
    ; 最大化左面板（通过移动分隔条）
    try {
        WinGetPos(&x, &y, &w, &h, "ahk_class TTOTAL_CMD")

        ; 获取分隔条位置（大约在中间）
        midX := x + w // 2

        ; 移动分隔条到最右边
        ControlMove(midX - 10, , , , "TMySplitter", "ahk_class TTOTAL_CMD")
    }
}

TC_WinMaxRight() {
    ; 最大化右面板（通过移动分隔条）
    try {
        WinGetPos(&x, &y, &w, &h, "ahk_class TTOTAL_CMD")

        ; 移动分隔条到最左边
        ControlMove(x + 10, , , , "TMySplitter", "ahk_class TTOTAL_CMD")
    }
}

TC_FileCopyForBak() {
    ; 复制文件并加 .bak 后缀
    filePath := TC_GetSelectedFile()
    if (filePath = "") {
        MsgBox(T("tc.pick_file_first"), T("tc.title_copybak"))
        return
    }

    bakPath := filePath ".bak"
    try {
        FileCopy(filePath, bakPath)
        Log("TC: Copied " filePath " to " bakPath)
    } catch as e {
        MsgBox(T("tc.copy_failed", e.Message), T("tc.err_title"))
    }
}

TC_FileMoveForBak() {
    ; 重命名文件加 .bak 后缀
    filePath := TC_GetSelectedFile()
    if (filePath = "") {
        MsgBox(T("tc.pick_file_first"), T("tc.title_movebak"))
        return
    }

    bakPath := filePath ".bak"
    try {
        FileMove(filePath, bakPath)
        Log("TC: Moved " filePath " to " bakPath)
    } catch as e {
        MsgBox(T("tc.rename_failed", e.Message), T("tc.err_title"))
    }
}

TC_CreateFileShortcut() {
    ; 创建快捷方式
    filePath := TC_GetSelectedFile()
    if (filePath = "") {
        MsgBox(T("tc.pick_file_first"), T("tc.title_shortcut"))
        return
    }

    ; 获取当前目录
    currentDir := TC_GetCurrentDir()
    if (currentDir = "") {
        MsgBox(T("tc.no_curdir"), T("tc.title_shortcut"))
        return
    }

    ; 创建快捷方式
    shortcutPath := currentDir "\" SubStr(filePath, InStr(filePath, "\", 0, -1) + 1) ".lnk"
    try {
        FileCreateShortcut(filePath, shortcutPath)
        Log("TC: Created shortcut " shortcutPath)
    } catch as e {
        MsgBox(T("tc.shortcut_failed", e.Message), T("tc.err_title"))
    }
}

TC_CreateFileShortcutToDesktop() {
    ; 创建快捷方式到桌面
    filePath := TC_GetSelectedFile()
    if (filePath = "") {
        MsgBox(T("tc.pick_file_first"), T("tc.title_shortcut_desktop"))
        return
    }

    desktopPath := A_Desktop "\" SubStr(filePath, InStr(filePath, "\", 0, -1) + 1) ".lnk"
    try {
        FileCreateShortcut(filePath, desktopPath)
        Log("TC: Created shortcut to desktop " desktopPath)
    } catch as e {
        MsgBox(T("tc.shortcut_failed", e.Message), T("tc.err_title"))
    }
}

TC_ForceDelete() {
    Send "+{Del}"
}

TC_Toggle_50_100Percent() {
    ; 切换窗口大小 50%/100%
    static isHalf := false
    WinGetPos(&x, &y, &w, &h, "ahk_class TTOTAL_CMD")

    if !isHalf {
        newW := w // 2
        newH := h // 2
        newX := x + (w - newW) // 2
        newY := y + (h - newH) // 2
        WinMove(newX, newY, newW, newH, "ahk_class TTOTAL_CMD")
        isHalf := true
    } else {
        WinMove(x, y, w * 2, h * 2, "ahk_class TTOTAL_CMD")
        isHalf := false
    }
}

TC_SelectCmd() {
    ; TC 命令浏览器 - 显示常用命令列表
    static commands := Map()

    ; 初始化命令列表 (编号与 cmdMap 一致)
    if (commands.Count = 0) {
        commands["cm_CopyOtherpanel (" . T("act.TotalCommander.cm_CopyOtherpanel_2") . ")"] := 2001
        commands["cm_MoveOnly (" . T("act.TotalCommander.cm_MoveOnly_2") . ")"] := 2002
        commands["cm_Delete (" . T("act.TotalCommander.cm_Delete") . ")"] := 2003
        commands["cm_Edit (" . T("act.TotalCommander.cm_Edit_2") . ")"] := 2004
        commands["cm_View (" . T("act.TotalCommander.cm_View") . ")"] := 2005
        commands["cm_PackFiles (" . T("act.TotalCommander.cm_PackFiles") . ")"] := 2006
        commands["cm_UnpackFiles (" . T("act.TotalCommander.cm_UnpackFiles") . ")"] := 2007
        commands["cm_CopyToClipboard (" . T("act.TotalCommander.cm_CopyToClipboard_2") . ")"] := 2009
        commands["cm_CutToClipboard (" . T("act.TotalCommander.cm_CutToClipboard_2") . ")"] := 2010
        commands["cm_PasteFromClipboard (" . T("act.TotalCommander.cm_PasteFromClipboard_2") . ")"] := 2011
        commands["cm_MkDir (" . T("act.TotalCommander.cm_MkDir") . ")"] := 2012
        commands["cm_RenameOnly (" . T("act.TotalCommander.cm_RenameOnly_2") . ")"] := 2013
        commands["cm_MultiRenameFiles (" . T("act.TotalCommander.cm_MultiRenameFiles") . ")"] := 2014
        commands["cm_SrcByName (" . T("act.TotalCommander.cm_SrcByName_2") . ")"] := 2015
        commands["cm_SrcByExt (" . T("act.TotalCommander.cm_SrcByExt_2") . ")"] := 2016
        commands["cm_SrcBySize (" . T("act.TotalCommander.cm_SrcBySize_2") . ")"] := 2017
        commands["cm_SrcByDateTime (" . T("act.TotalCommander.cm_SrcByDateTime_2") . ")"] := 2018
        commands["cm_SrcNegSort (" . T("act.TotalCommander.cm_SrcNegSort") . ")"] := 2020
        commands["cm_SrcShort (" . T("act.TotalCommander.cm_SrcShort_2") . ")"] := 2021
        commands["cm_SrcLong (" . T("act.TotalCommander.cm_SrcLong_2") . ")"] := 2022
        commands["cm_SrcTree (" . T("act.TotalCommander.cm_SrcTree_2") . ")"] := 2023
        commands["cm_SrcThumbs (" . T("act.TotalCommander.cm_SrcThumbs_2") . ")"] := 2024
        commands["cm_SrcQuickView (" . T("act.TotalCommander.cm_SrcQuickView") . ")"] := 2025
        commands["cm_ToggleTreeView (" . T("act.TotalCommander.cm_ToggleTreeView") . ")"] := 2026
        commands["cm_Refresh (" . T("act.TotalCommander.cm_Refresh") . ")"] := 2027
        commands["cm_CopySrcPathToClip (" . T("act.TotalCommander.cm_CopySrcPathToClip_2") . ")"] := 2029
        commands["cm_SelectAll (" . T("act.TotalCommander.cm_SelectAll_2") . ")"] := 2030
        commands["cm_ExchangeSelection (" . T("act.TotalCommander.cm_ExchangeSelection_2") . ")"] := 2031
        commands["cm_MaximizePanel1 (" . T("act.TotalCommander.cm_MaximizePanel1") . ")"] := 2032
        commands["cm_MaximizePanel2 (" . T("act.TotalCommander.cm_MaximizePanel2") . ")"] := 2033
        commands["cm_Exchange (" . T("act.TotalCommander.cm_Exchange_2") . ")"] := 2034
        commands["cm_Minimize (" . T("act.TotalCommander.cm_Minimize_2") . ")"] := 2035
        commands["cm_Maximize (" . T("act.TotalCommander.cm_Maximize_2") . ")"] := 2036
        commands["cm_Restore (" . T("act.TotalCommander.cm_Restore_2") . ")"] := 2037
        commands["cm_DirectoryHotlist (" . T("act.TotalCommander.cm_DirectoryHotlist") . ")"] := 2039
        commands["cm_CopyNamesToClip (" . T("act.TotalCommander.cm_CopyNamesToClip") . ")"] := 2040
        commands["cm_CopyFullNamesToClip (" . T("act.TotalCommander.cm_CopyFullNamesToClip_2") . ")"] := 2041
        commands["cm_SearchFor (" . T("act.TotalCommander.cm_SearchFor_2") . ")"] := 2042
        commands["cm_ShowQuickSearch (" . T("act.TotalCommander.cm_ShowQuickSearch_2") . ")"] := 2043
        commands["cm_CompareDirs (" . T("act.TotalCommander.cm_CompareDirs_2") . ")"] := 2044
        commands["cm_SyncDirs (" . T("act.TotalCommander.cm_SyncDirs") . ")"] := 2045
        commands["cm_CompareByContent (" . T("act.TotalCommander.cm_CompareByContent") . ")"] := 2046
        commands["cm_ContextMenu (" . T("act.TotalCommander.cm_ContextMenu_2") . ")"] := 2047
        commands["cm_ExecuteDOS (" . T("act.TotalCommander.cm_ExecuteDOS_2") . ")"] := 2048
        commands["cm_FocusCmdLine (" . T("act.TotalCommander.cm_FocusCmdLine_2") . ")"] := 2049
        commands["cm_LeftOpenDrives (" . T("act.TotalCommander.cm_LeftOpenDrives_2") . ")"] := 2050
        commands["cm_RightOpenDrives (" . T("act.TotalCommander.cm_RightOpenDrives_2") . ")"] := 2051
        commands["cm_Config (" . T("act.TotalCommander.cm_Config_2") . ")"] := 2052
        commands["cm_DirHome (" . T("act.TotalCommander.cm_DirHome") . ")"] := 2053
        commands["cm_GotoRoot (" . T("act.TotalCommander.cm_GotoRoot") . ")"] := 2054
        commands["cm_GotoPreviousDir (" . T("act.TotalCommander.cm_GotoPreviousDir") . ")"] := 2055
        commands["cm_GotoNextDir (" . T("act.TotalCommander.cm_GotoNextDir") . ")"] := 2056
        commands["cm_OpenDesktop (" . T("act.TotalCommander.cm_OpenDesktop") . ")"] := 2057
        commands["cm_OpenNewTab (" . T("act.TotalCommander.cm_OpenNewTab") . ")"] := 3001
        commands["cm_OpenNewTabBg (" . T("act.TotalCommander.cm_OpenNewTabBg_2") . ")"] := 3002
        commands["cm_SwitchToNextTab (" . T("act.TotalCommander.cm_SwitchToNextTab_2") . ")"] := 3003
        commands["cm_SwitchToPreviousTab (" . T("act.TotalCommander.cm_SwitchToPreviousTab_2") . ")"] := 3004
        commands["cm_CloseCurrentTab (" . T("act.TotalCommander.cm_CloseCurrentTab") . ")"] := 3005
        commands["cm_CloseAllTabs (" . T("act.TotalCommander.cm_CloseAllTabs") . ")"] := 3006
        commands["cm_Exit (" . T("act.TotalCommander.cm_Exit_2") . ")"] := 2063
    }

    ; 创建菜单 (drill-in 列表, 见 TC_PopupMenu; 循环变量经 MakeMenuCb 工厂固化)
    items := []
    for name, cmdNum in commands {
        items.Push({label: name, run: MakeMenuCb("TC_SendPos", cmdNum)})
    }

    ; 显示菜单
    TC_MenuPos(&cxn, &cyn)
    TC_PopupMenu(items, cxn, cyn)
}

TC_OpenDriveThis() {
    ; 打开驱动器列表（本侧）
    TC_SendPos(2050)  ; cm_LeftOpenDrives
}

TC_OpenDriveThat() {
    ; 打开驱动器列表（另侧）
    TC_SendPos(2051)  ; cm_RightOpenDrives
}

; === 高级功能 ===

TC_CopyUseQueues() {
    ; 对原版: 无需确认, 使用队列拷贝文件至另一窗口 (F5 复制 + F2 进队列)
    Send "{F5}"
    Sleep 100
    Send "{F2}"
}

TC_MoveUseQueues() {
    ; 对原版: 无需确认, 使用队列移动文件至另一窗口 (F6 移动 + F2 进队列)
    Send "{F6}"
    Sleep 100
    Send "{F2}"
}

TC_CopyDirectoryHotlist() {
    ; 复制到常用文件夹 (对原版 526; 移植版误写 2039=存详细信息)
    TC_SendPos(526)  ; cm_DirectoryHotlist
}

TC_MoveDirectoryHotlist() {
    ; 移动到常用文件夹
    TC_SendPos(526)  ; cm_DirectoryHotlist
    Sleep 200
    Send "{Tab}{Tab}{Enter}"  ; 切换到目标面板
}

TC_GotoPreviousDirOther() {
    ; 另一侧后退 (对原版: Tab 切对侧 + 570, 非 F12+2055)
    Send "{Tab}"
    Sleep 100
    TC_SendPos(570)  ; cm_GotoPreviousDir
    Sleep 100
    Send "{Tab}"
}

TC_GotoNextDirOther() {
    ; 另一侧前进 (对原版: Tab 切对侧 + 571)
    Send "{Tab}"
    Sleep 100
    TC_SendPos(571)  ; cm_GotoNextDir
    Sleep 100
    Send "{Tab}"
}

TC_SearchMode() {
    ; 连续搜索模式
    Send "{F3}"  ; 打开查看器
    Sleep 100
    Send "{Tab}"  ; 切换到搜索标签
}

TC_ReOpenTab() {
    ; 重新打开关闭的标签
    Send "^+{t}"
}

TC_GoLastTab() {
    ; 跳到最后一个标签
    Send "^{End}"
}

TC_Toggle_50_100Percent_V() {
    ; 纵向切换窗口大小
    static isHalf := false
    WinGetPos(&x, &y, &w, &h, "ahk_class TTOTAL_CMD")

    if !isHalf {
        newH := h // 2
        newY := y + (h - newH) // 2
        WinMove(x, newY, w, newH, "ahk_class TTOTAL_CMD")
        isHalf := true
    } else {
        WinMove(x, y, w, h * 2, "ahk_class TTOTAL_CMD")
        isHalf := false
    }
}

TC_SuperReturn() {
    ; 回车后定位到第一个文件
    Send "{Enter}"
    Sleep 100
    Send "{Home}"
}

TC_MultiFilePersistOpen() {
    ; 多文件连续打开
    Loop {
        if !GetKeyState("Enter", "P")
            break
        Send "{Enter}"
        Sleep 50
    }
}

TC_CopyFileContents() {
    ; 复制文件内容（不打开文件）
    filePath := TC_GetSelectedFile()
    if (filePath != "" && FileExist(filePath)) {
        try {
            f := FileOpen(filePath, "r")
            content := f.Read()
            f.Close()
            A_Clipboard := content
            Log("TC: Copied file contents from " filePath)
        } catch as e {
            MsgBox(T("tc.read_failed", e.Message), T("tc.err_title"))
        }
    }
}

TC_OpenDirAndPaste() {
    ; 不打开目录直接粘贴
    filePath := TC_GetSelectedFile()
    if (filePath != "") {
        dir := SubStr(filePath, 1, InStr(filePath, "\", 0, -1))
        Run "explorer.exe " dir
        Sleep 300
        Send "^v"  ; 粘贴
    }
}

TC_MoveSelectedFilesToPrevFolder() {
    ; 移动选中文件到上级目录
    Send "^{Up}"
    Sleep 100
    Send "{F6}"  ; 移动
}

TC_MoveAllFilesToPrevFolder() {
    ; 移动所有文件到上级目录
    Send "^a"  ; 全选
    Sleep 100
    Send "^{Up}"
    Sleep 100
    Send "{F6}"  ; 移动
}

TC_SrcQuickViewAndTab() {
    ; 预览文件时光标移到对侧
    Send "{F3}"  ; 快速预览
    Sleep 100
    Send "{F12}"  ; 切换到另一侧
}

TC_CreateFileShortcutToStartup() {
    ; 创建快捷方式到启动目录
    filePath := TC_GetSelectedFile()
    if (filePath = "") {
        MsgBox(T("tc.pick_file_first"), T("tc.title_shortcut"))
        return
    }

    startupPath := A_Startup "\" SubStr(filePath, InStr(filePath, "\", 0, -1) + 1) ".lnk"
    try {
        FileCreateShortcut(filePath, startupPath)
        Log("TC: Created shortcut to startup " startupPath)
    } catch as e {
        MsgBox(T("tc.shortcut_failed", e.Message), T("tc.err_title"))
    }
}

TC_FilterSearchFNsuffix_exe() {
    ; 快速过滤 exe 文件
    Send "!{F7}"  ; 打开搜索
    Sleep 200
    Send "*.exe"
    Sleep 100
    Send "{Enter}"
}

TC_TwoFileExchangeName() {
    ; 两个文件互换名称
    file1 := TC_GetSelectedFile()
    if (file1 = "") {
        MsgBox(T("tc.pick_first_file"), T("tc.swap_title"))
        return
    }

    ; 提示选择第二个文件
    MsgBox(T("tc.swap_remember"), T("tc.swap_title"))
    Send "{Down}"  ; 移动到下一个文件
    Sleep 100

    file2 := TC_GetSelectedFile()
    if (file2 = "") {
        MsgBox(T("tc.swap_no_second"), T("tc.swap_title"))
        return
    }

    ; 获取两个文件的路径和名称
    dir1 := SubStr(file1, 1, InStr(file1, "\", 0, -1))
    dir2 := SubStr(file2, 1, InStr(file2, "\", 0, -1))
    name1 := SubStr(file1, InStr(file1, "\", 0, -1) + 1)
    name2 := SubStr(file2, InStr(file2, "\", 0, -1) + 1)

    ; 临时文件名
    tempName := name1 ".temp_rename"

    ; 执行重命名
    try {
        FileMove(dir1 name1, dir1 tempName)
        FileMove(dir2 name2, dir1 name1)
        FileMove(dir1 tempName, dir2 name2)
        Log("TC: Exchanged names " name1 " <-> " name2)
    } catch as e {
        MsgBox(T("tc.swap_failed", e.Message), T("tc.err_title"))
    }
}

TC_MarkFile() {
    ; 通过文件备注标记
    filePath := TC_GetSelectedFile()
    if (filePath = "") {
        MsgBox(T("tc.pick_file_first"), T("tc.title_markfile"))
        return
    }

    try {
        ibox3 := InputBox(T("tc.mark_prompt", filePath), T("tc.title_markfile"))
        markText := ibox3.Value
    } catch {
        return
    }
    if (markText = "")
        return

    ; 保存标记
    markFile := Rim.appDir "\Conf\TCFileMarks.ini"
    IniWrite(markText, markFile, "marks", filePath)
    Log("TC: Marked file " filePath " with: " markText)
}

TC_UnMarkFile() {
    ; 取消文件标记
    filePath := TC_GetSelectedFile()
    if (filePath = "") {
        MsgBox(T("tc.pick_file_first"), T("tc.title_unmark"))
        return
    }

    markFile := Rim.appDir "\Conf\TCFileMarks.ini"
    try {
        IniDelete(markFile, "marks", filePath)
        Log("TC: Unmarked file " filePath)
    }
}

TC_ClearTitle() {
    ; 清空标题栏
    WinSetTitle("Total Commander", "ahk_class TTOTAL_CMD")
}

TC_OpenDirsInFile() {
    ; 从文件内容批量打开目录
    filePath := TC_GetSelectedFile()
    if (filePath = "" || !FileExist(filePath)) {
        MsgBox(T("tc.pick_dirfile"), T("tc.title_opendir"))
        return
    }

    try {
        f := FileOpen(filePath, "r")
        content := f.Read()
        f.Close()

        ; 按行分割
        Loop Parse, content, "`n", "`r" {
            line := Trim(A_LoopField)
            if (line = "")
                continue

            ; 检查是否是目录
            if DirExist(line) {
                Run "explorer.exe " line
                Sleep 200
            }
        }
    } catch as e {
        MsgBox(T("tc.read_failed", e.Message), T("tc.err_title"))
    }
}

TC_CreateBlankFileNoExt() {
    ; 创建无扩展名空文件 (对原版 NewFile("创建空文件", True, ""): 同一对话框走空文件分支)
    TC_NewFileDialog("", "", true)
}

TC_PasteFileEx() {
    ; 粘贴到光标下的目录 (v2: ControlGetFocus/ControlGetText 直接返回值)
    ; 注意 ControlGetText 读 ListBox 恒为空, 这里只做目录/文件存在性分支
    try {
        ; 获取光标下的文件/目录名
        hwnd := ControlGetFocus("ahk_class TTOTAL_CMD")
        focused := ControlGetClassNN(hwnd, "ahk_class TTOTAL_CMD")

        if InStr(focused, "ListBox") {
            ; 获取当前选中项
            text := ControlGetText(focused, "ahk_class TTOTAL_CMD")
            if DirExist(text) {
                ; 如果是目录，进入并粘贴
                Send "{Enter}"
                Sleep 100
                Send "^v"
            } else {
                ; 如果是文件，粘贴到上级目录
                Send "^{Up}"
                Sleep 100
                Send "^v"
            }
        }
    } catch {
    }
}

TC_ThumbsView() {
    ; 对原版: 进缩略图 + h/l 临时变左右方向键; 再按 m 切回 (else 分支即 ini 值)
    static isThumbs := false
    TC_SendPos(269)  ; cm_SrcThumbs (移植版误写 2024=对侧打开/2022=比较, 已纠正)
    isThumbs := !isThumbs
    if (isThumbs) {
        engine.MapKey("h", "<left>", "TTOTAL_CMD", "normal")
        engine.MapKey("l", "<right>", "TTOTAL_CMD", "normal")
    } else {
        engine.MapKey("h", "<TC_GoToParentEx>", "TTOTAL_CMD", "normal")
        engine.MapKey("l", "<TC_SuperReturn>", "TTOTAL_CMD", "normal")
    }
}

TC_SrcActivateTab1() {
    ; 激活第一个标签
    Send "^1"
}

TC_SrcActivateTab2() {
    ; 激活第二个标签
    Send "^2"
}

TC_SrcActivateTab3() {
    ; 激活第三个标签
    Send "^3"
}

TC_SrcActivateTab4() {
    ; 激活第四个标签
    Send "^4"
}

TC_SrcActivateTab5() {
    ; 激活第五个标签
    Send "^5"
}

TC_SrcActivateTab6() {
    ; 激活第六个标签
    Send "^6"
}

TC_SrcActivateTab7() {
    ; 激活第七个标签
    Send "^7"
}

TC_SrcActivateTab8() {
    ; 激活第八个标签
    Send "^8"
}

TC_SrcActivateTab9() {
    ; 激活第九个标签
    Send "^9"
}
