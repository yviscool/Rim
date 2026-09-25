#Requires AutoHotkey v2.0
#Warn All, Off

; === Hotkeys - 热键绑定 (从 RunZ Core/Hotkeys.ahk 移植) ===

Default(*) {
    return
}

RestartRunZ(*) {
    try FileAppend(A_Now . " RESTART begin`n", A_ScriptDir . "\Rim.error.log")
    catch {
    }
    SaveAutoConf()
    ; 先起新实例再退旧进程: 原生 Reload 若卡在清理阶段会青黄不接 (旧已退、新未生,
    ; 日志停在 RESTART begin 且无进程残留, 10:23 复现). 新实例的 #SingleInstance Force
    ; 会收走旧进程; 即使旧进程卡死, 新实例已在位, 用户永远有可用实例
    cmd := '"' A_AhkPath '" "' A_ScriptFullPath '"'
    for a in A_Args
        cmd .= ' "' a '"'
    try {
        Run(cmd)
        Sleep(1500)
    } catch as e {
        try FileAppend(A_Now . " RESTART spawn failed: " e.Message "`n", A_ScriptDir . "\Rim.error.log")
        catch {
        }
    }
    ExitApp
}

HomeKey(*) {
    Send("{Home}")
}

EndKey(*) {
    Send("{End}")
}

NextPage(*) {
    if (!g_UseDisplay)
        return
    g_DisplayEdit.Focus()
    Send("{PgDn}")
    g_InputEdit.Focus()
}

PrevPage(*) {
    if (!g_UseDisplay)
        return
    g_DisplayEdit.Focus()
    Send("{PgUp}")
    g_InputEdit.Focus()
}

ActivateRunZ(*) {
    g_MainGui.Show()
    if (g_Conf["Config"]["SwitchToEngIME"] = "1")
        SwitchToEngIME()
    Loop 5 {
        Sleep(50)
        try g_MainGui.Show()
        if WinActive(g_WindowName) {
            g_InputEdit.Focus()
            Send("^a")
            break
        }
    }
}

ToggleWindow(*) {
    if WinActive(g_WindowName) {
        if (g_Conf["Config"]["KeepInputText"] != "1")
            g_InputEdit.Value := ""
        g_MainGui.Hide()
    } else {
        ActivateRunZ()
    }
}

ClickFunction(*) {
    global g_UseDisplay, g_CurrentCommandList, g_CurrentLine, g_CurrentCommand, g_WindowName, g_InputEdit
    if (g_UseDisplay)
        return
    index := getMouseCurrentLine()
    if (index < 1 || index > g_CurrentCommandList.Length)
        return
    ; 定位交由 ChangeCommand 统一处理 (对齐原版, 避免预设全局漂移)
    ChangeCommand(index - 1, true)
    if WinExist(g_WindowName) {
        g_InputEdit.Focus()
        Send("{End}")
    }
    if (g_Conf["Config"]["ClickToRun"] = "1")
        RunCommand(g_CurrentCommand)
}

OpenContextMenu(*) {
    if (!g_UseDisplay) {
        currentCommandText := ""
        if (g_CurrentLine <= 0)
            currentCommandText .= Chr(g_FirstChar)
        else
            currentCommandText .= Chr(g_FirstChar + g_CurrentLine - 1)
    }
    contextMenu := Menu()
    if (!g_UseDisplay)
        contextMenu.Add(currentCommandText . ">  " . T("ctx.run"), RunCurrentCommand)
    contextMenu.Add()
    contextMenu.Add(T("ctx.edit"), EditConfig)
    contextMenu.Add(T("ctx.reindex"), ReindexFiles)
    contextMenu.Add(T("ctx.history"), DisplayHistoryCommands)
    contextMenu.Add(T("ctx.updatepath"), ChangePath)
    contextMenu.Add()
    contextMenu.Add(T("ctx.help"), Help)
    contextMenu.Add(T("ctx.restart"), RestartRunZ)
    contextMenu.Add(T("ctx.exit"), ExitRunZ)
    contextMenu.Show()
}

TabFunction(*) {
    global g_InputEdit
    try {
        if (ControlGetFocus("A") = g_InputEdit.Hwnd)
            ControlFocus("Edit2")
        else
            g_InputEdit.Focus()
    } catch {
        try g_InputEdit.Focus()
    }
}

EscFunction(*) {
    ToolTip()
    if (g_Conf["Config"]["ClearInputWithEsc"] = "1" && g_CurrentInput != "")
        ClearInputLabel()
    else {
        if (g_Conf["Config"]["KeepInputText"] != "1")
            g_InputEdit.Value := ""
        HideOrExit()
    }
}

ExitRunZ(*) {
    SaveAutoConf()
    ExitApp
}

HideOrExit(*) {
    global g_Conf, g_MainGui
    ; 防御: g_Conf 未就绪时默认隐藏 (不触发 ExitApp), 见 Config.ahk 注释
    if (!IsSet(g_Conf) || !IsObject(g_Conf)) {
        try g_MainGui.Hide()
        catch {
        }
        return
    }
    if (g_Conf["Config"]["RunInBackground"] = "1")
        g_MainGui.Hide()
    else
        ExitRunZ()
}

; 一键居中活动窗口 (全局热键 !h 入口; 算法对齐 General.ahk wm_center, 最小修复不改数学)
CenterActiveWindow(*) {
    try {
        hwnd := WinExist("A")
        if (!hwnd)
            return
        spec := "ahk_id " hwnd
        ; 最小化/最大化时先还原, 否则 WinMove 无效或无意义
        try {
            if (WinGetMinMax(spec) != 0)
                WinRestore(spec)
        }
        WinGetPos(, , &w, &h, spec)
        x := (A_ScreenWidth - w) // 2
        y := (A_ScreenHeight - h) // 2
        WinMove(x, y, , , spec)
    }
}

NextCommand(*) {
    if (g_UseDisplay) {
        ; 行导航态: ^J 移动 >| 标记 (焦点不出输入框); 非行态才挪文本光标
        if (RowNavActive()) {
            RowNavMove(1)
            return
        }
        g_DisplayEdit.Focus()
        Send("{Down}")
        return
    }
    ChangeCommand(1)
}

PrevCommand(*) {
    if (g_UseDisplay) {
        if (RowNavActive()) {
            RowNavMove(-1)
            return
        }
        g_DisplayEdit.Focus()
        Send("{Up}")
        return
    }
    ChangeCommand(-1)
}

GotoCommand(*) {
    global g_InputEdit, g_CurrentCommandList, g_FirstChar
    try {
        if (ControlGetFocus("A") = g_InputEdit.Hwnd)
            return
    }
    index := Ord(SubStr(A_ThisHotkey, -1)) - g_FirstChar + 1
    if (index >= 1 && index <= g_CurrentCommandList.Length)
        ChangeCommand(index - 1, true)
}

ReindexFiles(*) {
    if WinActive(g_WindowName)
        ToolTip(T("ctx.reindexing"))
    GenerateSearchFileList()
    CleanupRank()  ; 内含 LoadFiles(false)→清理→LoadFiles(), 无需预 LoadFiles
    if WinActive(g_WindowName) {
        ToolTip(T("ctx.reindexed"))
        SetTimer(RemoveToolTip, -800)
    }
}

EditConfig(*) {
    if (g_Conf["Config"]["Editor"] != "")
        Run(g_Conf["Config"]["Editor"] ' "' g_ConfFile '"')
    else
        Run(g_ConfFile)
}

EditAutoConfig(*) {
    if (g_Conf["Config"]["Editor"] != "")
        Run(g_Conf["Config"]["Editor"] ' "' g_AutoConfFile '"')
    else
        Run(g_AutoConfFile)
}

ClearInputLabel(*) {
    ClearInput()
    ; 清空后回到默认结果页 (编程设置 Edit.Value 不保证触发 Change 事件,
    ; 显示区会停留在旧结果, 这里显式重建空串搜索的默认列表)
    SearchCommand("")
}

RunCurrentCommand(*) {
    ; 行导航态回车 = 复制当前行 (不执行、不关窗, 可连复制多行)
    if (RowNavActive()) {
        RowNavCopy()
        return
    }
    ; SmartInput: 有灰字先接受再执行 (否则跑的是旧列表头, 与框内文字脱节)
    try {
        SI_AcceptGhost()
    } catch {
    }
    RunCommand(g_CurrentCommand)
}

ParseArg(*) {
    global g_Arg, g_PipeArg, g_CurrentInput, g_UseFallbackCommands
    if (g_PipeArg != "") {
        g_Arg := g_PipeArg
        return
    }

    commandPrefix := SubStr(g_CurrentInput, 1, 1)

    if (commandPrefix = ";" || commandPrefix = ":") {
        g_Arg := SubStr(g_CurrentInput, 2)
        return
    }
    else if (commandPrefix = "@") {
        g_Arg := SubStr(g_CurrentInput, 4)
        return
    }

    if (InStr(g_CurrentInput, " ") && !g_UseFallbackCommands)
        g_Arg := SubStr(g_CurrentInput, InStr(g_CurrentInput, " ") + 1)
    else if (g_UseFallbackCommands)
        g_Arg := g_CurrentInput
    else
        g_Arg := ""
}

CleanupRank(*) {
    LoadFiles(false)
    for command, rank in g_AutoConf["Rank"] {
        cleanup := true
        for index, element in g_Commands {
            if (InStr(element, command) = 1) {
                cleanup := false
                break
            }
        }
        if (cleanup)
            g_AutoConf.DeleteKey("Rank", command)
    }
    tries := 0
    Loop {
        tries++
        try g_AutoConf.Save()
        catch {
        }
        if (FileExist(g_AutoConfFile))
            break
        if (tries >= 3)
            break
        Sleep(100)
    }
    LoadFiles()
}

RunSelectedCommand(*) {
    global g_InputEdit, g_CurrentCommandList, g_FirstChar
    ; 原版守卫: ~ 键(输入框内按字母)只定位不执行
    try {
        if (SubStr(A_ThisHotkey, 1, 1) = "~" && ControlGetFocus("A") = g_InputEdit.Hwnd)
            return
    }
    index := Ord(SubStr(A_ThisHotkey, -1)) - g_FirstChar + 1
    if (index >= 1 && index <= g_CurrentCommandList.Length)
        RunCommand(g_CurrentCommandList[index])
}

IncreaseRank(*) {
    if (g_CurrentCommand != "") {
        ChangeRank(g_CurrentCommand, true)
        LoadFiles()
    }
}

DecreaseRank(*) {
    if (g_CurrentCommand != "") {
        ChangeRank(g_CurrentCommand, true, -1)
        LoadFiles()
    }
}

DisplayHistoryCommands(*) {
    global g_UseDisplay, g_CurrentCommandList, g_CurrentLine, g_CurrentCommand
    global g_FirstChar, g_HistoryCommands, g_InputEdit
    g_UseDisplay := false
    result := ""
    g_CurrentCommandList := []
    g_CurrentLine := 1

    for index, element in g_HistoryCommands {
        if (index = 1) {
            result .= Chr(g_FirstChar + index - 1) . ">| "
            g_CurrentCommand := element
        } else {
            result .= Chr(g_FirstChar + index - 1) . " | "
        }

        ; 原版格式: c1 | c2 | c3 #arg: c4 (v1 越界取空, v2 用安全取值)
        _hp := StrSplit(element, " | ")
        _h1 := _hp.Length >= 1 ? _hp[1] : ""
        _h2 := _hp.Length >= 2 ? _hp[2] : ""
        _h3 := _hp.Length >= 3 ? _hp[3] : ""
        _h4 := _hp.Length >= 4 ? _hp[4] : ""
        if (_hp.Length > 4) {
            Loop _hp.Length - 4
                _h4 .= " | " . _hp[4 + A_Index]
        }
        result .= _h1 " | " _h2 " | " _h3 . " " . T("hist.argsep") . " " . _h4 "`n"
        g_CurrentCommandList.Push(element)
    }

    DisplayControlText(result)
}

; 从命令中取文件路径 (兼容四段式 key|file|path|desc 与三段式 file|path|desc)
GetFilePathFromCmd(cmd) {
    parts := StrSplit(cmd, " | ")
    if (parts.Length >= 4 && (parts[2] = "file" || parts[2] = "function" || parts[2] = "cmd" || parts[2] = "url" || parts[2] = "run"))
        return parts[3]
    return parts.Length >= 2 ? parts[2] : ""
}

OpenCurrentFileDir(*) {
    OpenPath(GetFilePathFromCmd(g_CurrentCommand))
}

DeleteCurrentFile(*) {
    filePath := GetFilePathFromCmd(g_CurrentCommand)
    if (!FileExist(filePath))
        return
    FileRecycle(filePath)
    ReindexFiles()
}

ShowCurrentFile(*) {
    ; 行导航态 ^S = 复制当前行 (与回车同义)
    if (RowNavActive()) {
        RowNavCopy()
        return
    }
    A_Clipboard := GetFilePathFromCmd(g_CurrentCommand)
    ToolTip(A_Clipboard)
    SetTimer(RemoveToolTip, -800)
}

; 复制显示区全部内容 (行导航/普通展示通用, 不改变焦点)
DisplayCopyAll(*) {
    global g_DisplayEdit
    text := ""
    try text := g_DisplayEdit.Value
    catch {
        return
    }
    if (text = "")
        return
    try A_Clipboard := text
    catch {
        return
    }
    ToolTip(T("ctx.copy_display"))
    SetTimer(RemoveToolTip, -1500)
}

ChangePath(*) {
    UpdateSendTo(g_Conf["Config"]["CreateSendToLnk"], true)
    UpdateStartupLnk(g_Conf["Config"]["CreateStartupLnk"], true)
}

WatchUserFileList(*) {
    static lastUserFileListModifyTime := ""
    static lastConfFileModifyTime := ""
    ; 注意: FileGetTime 失败回 "" (杀软/同步盘/编辑器短暂锁文件);
    ; 空串绝不能当"变化"处理, 更不能存进 last (一次抖动会连炸两次重启,
    ; 配置窗被杀、dirty 丢失 —— "勾选不上/保存无效"的根因之一)
    try {
        newUserFileListModifyTime := FileGetTime(g_UserFileList)
        if (newUserFileListModifyTime = "") {
            try FileAppend("", g_UserFileList)
            catch {
            }
        } else {
            if (lastUserFileListModifyTime != "" && lastUserFileListModifyTime != newUserFileListModifyTime)
                LoadFiles()
            lastUserFileListModifyTime := newUserFileListModifyTime
        }
    }
    try {
        newConfFileModifyTime := FileGetTime(g_ConfFile)
        if (newConfFileModifyTime != "") {
            if (lastConfFileModifyTime != "" && lastConfFileModifyTime != newConfFileModifyTime)
                RestartRunZ()
            lastConfFileModifyTime := newConfFileModifyTime
        }
    }
}

SaveResultAsArg(*) {
    global g_Arg, FullPipeArg, g_DisplayEdit, g_CurrentCommand, g_SkinConf
    global g_InputEdit, g_CommandFilter
    g_Arg := ""
    result := g_DisplayEdit.Value

    if (g_SkinConf["HideCol2"] = "1") {
        FullPipeArg := ""
        Loop Parse, result, "`n", "`r" {
            FullPipeArg .= SubStr(A_LoopField, 1, 2) "| placeholder | " SubStr(A_LoopField, 5) "`n"
        }
    } else {
        FullPipeArg := result
    }

    if (InStr(g_CurrentCommand, "file | ") = 1)
        g_Arg .= StrSplit(g_CurrentCommand, " | ")[2]
    else if (!InStr(result, " | ")) {
        g_Arg .= StrReplace(result, "`n", " ")
        g_Arg := StrReplace(g_Arg, "`r")
    } else {
        if (g_SkinConf["HideCol2"] = "1") {
            Loop Parse, result, "`n", "`r" {
                g_Arg .= Trim(StrSplit(A_LoopField, " | ")[2]) " "
            }
        } else {
            Loop Parse, result, "`n", "`r" {
                g_Arg .= Trim(StrSplit(A_LoopField, " | ")[3]) " "
            }
        }
    }

    g_Arg := Trim(g_Arg)
    g_InputEdit.Value := "|"
    g_InputEdit.Focus()
    Send("{End}")
    if (g_CommandFilter != "") {
        SearchCommand("|" g_CommandFilter)
        g_CommandFilter := ""
    }
}

Help(*) {
    DisplayResult(KeyHelpText() . GetAllFunctions())
}

KeyHelp(*) {
    ToolTip(KeyHelpText())
    SetTimer(RemoveToolTip, -5000)
}

RemoveToolTip(*) {
    ToolTip()
    SetTimer(RemoveToolTip, 0)
}

; ==================== 输入处理 ====================

ProcessInputCommand(*) {
    global g_CurrentInput, g_InputEdit
    g_CurrentInput := g_InputEdit.Value
    if (SubStr(g_CurrentInput, -1) = " ") {
        ProcessInputCommandCallBack()
        return
    }
    SetTimer(ProcessInputCommandCallBack, -1)
}

ProcessInputCommandCallBack(*) {
    SetTimer(ProcessInputCommandCallBack, 0)

    if (g_SkinConf["ShowInputBoxOnlyIfEmpty"] = "1") {
        if (g_CurrentInput != "") {
            if (g_SkinConf["ShowCurrentCommand"] = "1")
                windowHeight := g_SkinConf["BorderSize"] * 4 + g_SkinConf["EditHeight"] * 2 + g_SkinConf["DisplayAreaHeight"]
            else
                windowHeight := g_SkinConf["BorderSize"] * 3 + g_SkinConf["EditHeight"] + g_SkinConf["DisplayAreaHeight"]
            WinMove(, , , windowHeight, g_WindowName)
        } else {
            windowHeight := g_SkinConf["BorderSize"] * 2 + g_SkinConf["EditHeight"]
            WinMove(, , , windowHeight, g_WindowName)
        }

        if (g_SkinConf["RoundCorner"] + 0 > 0) {
            WinSetRegion("0-0 w" g_SkinConf["BorderSize"] * 2 + g_SkinConf["WidgetWidth"] " h" windowHeight
                . " r" g_SkinConf["RoundCorner"] "-" g_SkinConf["RoundCorner"], g_WindowName)
        }
    }

    SearchCommand(g_CurrentInput)
    ; SmartInput: ghost 补全 + 延迟校验 (自家填充经 expect 标记, 内部直接返回)
    try {
        SI_OnInputChanged()
    } catch {
    }
}

StartCommandLine(*) {
    global g_FirstChar, g_CurrentInput
    g_FirstChar := 97
    SearchCommand(g_CurrentInput)
}

; === 统一绑定启动器热键 (窗口级 + 全局级 + ini 定制) ===
BindLauncherHotkeys() {
    global g_WindowName, g_DisplayRows, g_FirstChar, g_Conf

    HotIfWinActive(g_WindowName)

    BindKey("Esc", SI_Esc)
    BindKey("!F4", ExitRunZ)
    BindKey("Tab", SI_Tab)
    BindKey("F1", Help)
    BindKey("+F1", KeyHelp)
    BindKey("F2", EditConfig)
    BindKey("F3", EditAutoConfig)
    BindKey("^q", RestartRunZ)
    BindKey("^l", ClearInputLabel)
    BindKey("^u", ClearInputLabel)
    BindKey("^d", OpenCurrentFileDir)
    BindKey("^x", DeleteCurrentFile)
    BindKey("^s", ShowCurrentFile)
    BindKey("^y", DisplayCopyAll)
    BindKey("^r", ReindexFiles)
    BindKey("^h", DisplayHistoryCommands)
    BindKey("^n", IncreaseRank)
    BindKey("^=", IncreaseRank)
    BindKey("^p", DecreaseRank)
    BindKey("^-", DecreaseRank)
    BindKey("^f", NextPage)
    BindKey("^b", PrevPage)
    BindKey("^i", HomeKey)
    BindKey("^o", EndKey)
    BindKey("^j", NextCommand)
    BindKey("^k", PrevCommand)
    BindKey("Down", NextCommand)
    BindKey("Up", PrevCommand)
    BindKey("Right", SI_Right)
    BindKey("^Right", SI_AcceptWordKey)
    BindKey("Backspace", SI_Backspace)
    BindKey("^Backspace", SI_CtrlBackspace)
    BindKey("Delete", SI_DeleteKey)
    BindKey("!Up", SI_SubstrUp)
    BindKey("!Down", SI_SubstrDown)
    BindKey("~LButton", ClickFunction)
    BindKey("RButton", OpenContextMenu)
    BindKey("AppsKey", OpenContextMenu)
    BindKey("^Enter", SaveResultAsArg)

    ; Alt+字母 快速执行 / Alt+数字直达 (0=第10项)
    Loop g_DisplayRows {
        key := Chr(g_FirstChar + A_Index - 1)
        BindKey("!" key, RunSelectedCommand)
    }
    Loop 10 {
        digit := Mod(A_Index, 10)
        if (A_Index <= g_DisplayRows)
            BindKey("!" . digit, SI_RunByIndex)
    }

    ; 用户自定义热键 (<...> 经工厂绑闭包, 避免循环变量共享)
    if (IsObject(g_Conf) && g_Conf.HasSection("Hotkey")) {
        for key, label in g_Conf["Hotkey"] {
            if (label != "Default") {
                try {
                    if (SubStr(label, 1, 1) = "<") {
                        BindKey(key, MakeVimCb(label))
                    } else {
                        BindKey(key, MakeCb(label))
                    }
                }
            } else {
                try Hotkey(key, "Off")
            }
        }
    }

    HotIfWinActive()

    ; 全局热键 (<...> 经工厂绑闭包, 避免循环变量共享)
    if (IsObject(g_Conf) && g_Conf.HasSection("GlobalHotkey")) {
        for key, label in g_Conf["GlobalHotkey"] {
            if (label != "Default") {
                try {
                    if (SubStr(label, 1, 1) = "<") {
                        BindKey(key, MakeVimCb(label), "On")
                    } else {
                        BindKey(key, MakeCb(label), "On")
                    }
                }
            } else {
                try Hotkey(key, "Off")
            }
        }
    }
}
