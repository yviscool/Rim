#Requires AutoHotkey v2.0
#Warn All, Off

; === Hotkeys - 热键绑定 (从 RunZ Core/Hotkeys.ahk 移植) ===
; 子模块: Hotkeys.Commands (业务命令池); 绑定入口 BindLauncherHotkeys 留本文件

#Include Hotkeys.Commands.ahk

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
