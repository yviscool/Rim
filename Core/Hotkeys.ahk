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
        contextMenu.Add(currentCommandText ">  Run &Z", RunCurrentCommand)
    contextMenu.Add()
    contextMenu.Add("Edit Config &E", EditConfig)
    contextMenu.Add("Reindex &S", ReindexFiles)
    contextMenu.Add("History &H", DisplayHistoryCommands)
    contextMenu.Add("Update Path &C", ChangePath)
    contextMenu.Add()
    contextMenu.Add("Help &A", Help)
    contextMenu.Add("Restart &R", RestartRunZ)
    contextMenu.Add("Exit &X", ExitRunZ)
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
    if (g_Conf["Config"]["RunInBackground"] = "1")
        g_MainGui.Hide()
    else
        ExitRunZ()
}

NextCommand(*) {
    if (g_UseDisplay) {
        g_DisplayEdit.Focus()
        Send("{Down}")
        return
    }
    ChangeCommand(1)
}

PrevCommand(*) {
    if (g_UseDisplay) {
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
        ToolTip("Reindexing...")
    GenerateSearchFileList()
    CleanupRank()  ; 内含 LoadFiles(false)→清理→LoadFiles(), 无需预 LoadFiles
    if WinActive(g_WindowName) {
        ToolTip("Reindex done")
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
}

RunCurrentCommand(*) {
    RunCommand(g_CurrentCommand)
}

ParseArg(*) {
    global Arg, g_PipeArg, g_CurrentInput, g_UseFallbackCommands
    if (g_PipeArg != "") {
        Arg := g_PipeArg
        return
    }

    commandPrefix := SubStr(g_CurrentInput, 1, 1)

    if (commandPrefix = ";" || commandPrefix = ":") {
        Arg := SubStr(g_CurrentInput, 2)
        return
    }
    else if (commandPrefix = "@") {
        Arg := SubStr(g_CurrentInput, 4)
        return
    }

    if (InStr(g_CurrentInput, " ") && !g_UseFallbackCommands)
        Arg := SubStr(g_CurrentInput, InStr(g_CurrentInput, " ") + 1)
    else if (g_UseFallbackCommands)
        Arg := g_CurrentInput
    else
        Arg := ""
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
        result .= _h1 " | " _h2 " | " _h3 " #arg: " _h4 "`n"
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
    A_Clipboard := GetFilePathFromCmd(g_CurrentCommand)
    ToolTip(A_Clipboard)
    SetTimer(RemoveToolTip, -800)
}

ChangePath(*) {
    UpdateSendTo(g_Conf["Config"]["CreateSendToLnk"], true)
    UpdateStartupLnk(g_Conf["Config"]["CreateStartupLnk"], true)
}

WatchUserFileList(*) {
    static lastUserFileListModifyTime := ""
    static lastConfFileModifyTime := ""
    try {
        newUserFileListModifyTime := FileGetTime(g_UserFileList)
        if (newUserFileListModifyTime = "")
            FileAppend("", g_UserFileList)
        if (lastUserFileListModifyTime != "" && lastUserFileListModifyTime != newUserFileListModifyTime)
            LoadFiles()
        lastUserFileListModifyTime := newUserFileListModifyTime
    }
    try {
        newConfFileModifyTime := FileGetTime(g_ConfFile)
        if (lastConfFileModifyTime != "" && lastConfFileModifyTime != newConfFileModifyTime)
            RestartRunZ()
        lastConfFileModifyTime := newConfFileModifyTime
    }
}

SaveResultAsArg(*) {
    global Arg, FullPipeArg, g_DisplayEdit, g_CurrentCommand, g_SkinConf
    global g_InputEdit, g_CommandFilter
    Arg := ""
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
        Arg .= StrSplit(g_CurrentCommand, " | ")[2]
    else if (!InStr(result, " | ")) {
        Arg .= StrReplace(result, "`n", " ")
        Arg := StrReplace(Arg, "`r")
    } else {
        if (g_SkinConf["HideCol2"] = "1") {
            Loop Parse, result, "`n", "`r" {
                Arg .= Trim(StrSplit(A_LoopField, " | ")[2]) " "
            }
        } else {
            Loop Parse, result, "`n", "`r" {
                Arg .= Trim(StrSplit(A_LoopField, " | ")[3]) " "
            }
        }
    }

    Arg := Trim(Arg)
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
}

StartCommandLine(*) {
    global g_FirstChar, g_CurrentInput
    g_FirstChar := 97
    SearchCommand(g_CurrentInput)
}
