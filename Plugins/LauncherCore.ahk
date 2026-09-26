#Requires AutoHotkey v2.0
#Warn All, Off

; === LauncherCore Plugin - 核心功能 ===
; Faithful v2 port of RunZ Plugins Core v1, 207 lines.
; 移植规则如下
; v1 的每个 Label 子程序变为同名 v2 函数, 逻辑不变, GoSub 变为直接调用.
; 每个命令一律先读全局 g_Arg, 再读剪切板, 两者皆空才弹 InputBox.
; 结果一律走 DisplayResult, 不用 MsgBox 显示结果.
; 本构建加载期检查说明
; 静态调用未知函数名会加载失败, 所以主程序提供的函数一律走 Host 动态调用.
; 加载期读未赋值变量会卡住, 所以 g_Arg 和 FullPipeArg 在此给顶层空值.
; g_Conf 由主程序赋值, 此处哑赋值仅为通过独立加载检查, 永不执行.
; 本构建把分号当注释, 即使在字符串里, 所以字符串中的分号一律用重音符转义.
; 以下名字已存在于主程序或其他插件, 本文件只注册透传, 不重复定义
; Help KeyHelp ReindexFiles EditConfig CleanupRank 见 Core Hotkeys
; ShowArg 见 Core Execution, RunClipboard 见 Misc 插件

; 顶层空值只在未赋值时初始化 (#Include 按 auto-execute 顺序执行, 无条件 := 会清空主入口已赋值, 见 AGENTS 错误 18)
global g_Arg, FullPipeArg
if !IsSet(g_Arg)
    g_Arg := ""
if !IsSet(FullPipeArg)
    FullPipeArg := ""

__LauncherCore_LoadGuard() {
    global g_Conf
    if (false)
        g_Conf := ""
}

Host(fn, args*) {
    return %fn%(args*)
}

class LauncherCorePlugin extends RimPlugin {
    static Name => "LauncherCore"
    static Title => "Launcher Core Commands"
    static Description => "启动器核心命令 (运行/插件管理/参数)"

    static RegisterCommands() {
        Core()
    }
}

if (IsSet(RimPluginManager) && IsObject(RimPluginManager))
    RimPluginManager.Register(LauncherCorePlugin)

; ---- 原版 Core 标签 ----
Core() {
    RimCommand.Register("Help", "Help", MakeLegacyCmd("Help"), Map("Category", "System", "Description", T("cmd.LauncherCore.Help"), "Keywords", "Help"))
    RimCommand.Register("KeyHelp", "KeyHelp", MakeLegacyCmd("KeyHelp"), Map("Category", "System", "Description", T("cmd.LauncherCore.KeyHelp"), "Keywords", "KeyHelp"))
    RimCommand.Register("AhkRun", "AhkRun", MakeLegacyCmd("AhkRun"), Map("Category", "System", "Description", T("cmd.LauncherCore.AhkRun"), "Keywords", "AhkRun"))
    RimCommand.Register("CmdRun", "CmdRun", MakeLegacyCmd("CmdRun"), Map("Category", "System", "Description", T("cmd.LauncherCore.CmdRun"), "Keywords", "CmdRun"))
    RimCommand.Register("CmdRunOnly", "CmdRunOnly", MakeLegacyCmd("CmdRunOnly"), Map("Category", "System", "Description", T("cmd.LauncherCore.CmdRunOnly"), "Keywords", "CmdRunOnly"))
    RimCommand.Register("WinRRun", "WinRRun", MakeLegacyCmd("WinRRun"), Map("Category", "System", "Description", T("cmd.LauncherCore.WinRRun"), "Keywords", "WinRRun"))
    RimCommand.Register("RunAndDisplay", "RunAndDisplay", MakeLegacyCmd("RunAndDisplay"), Map("Category", "System", "Description", T("cmd.LauncherCore.RunAndDisplay"), "Keywords", "RunAndDisplay"))
    RimCommand.Register("ReindexFiles", "ReindexFiles", MakeLegacyCmd("ReindexFiles"), Map("Category", "System", "Description", T("cmd.LauncherCore.ReindexFiles"), "Keywords", "ReindexFiles"))
    RimCommand.Register("EditConfig", "EditConfig", MakeLegacyCmd("EditConfig"), Map("Category", "System", "Description", T("cmd.LauncherCore.EditConfig"), "Keywords", "EditConfig settings"))
    RimCommand.Register("RunClipboard", "RunClipboard", MakeLegacyCmd("RunClipboard"), Map("Category", "System", "Description", T("cmd.LauncherCore.RunClipboard"), "Keywords", "RunClipboard"))
    RimCommand.Register("CleanupRank", "CleanupRank", MakeLegacyCmd("CleanupRank"), Map("Category", "System", "Description", T("cmd.LauncherCore.CleanupRank"), "Keywords", "CleanupRank"))
    RimCommand.Register("ShowArg", "ShowArg", MakeLegacyCmd("ShowArg"), Map("Category", "System", "Description", T("cmd.LauncherCore.ShowArg"), "Keywords", "ShowArg"))
    RimCommand.Register("AhkTest", "AhkTest", MakeLegacyCmd("AhkTest"), Map("Category", "System", "Description", T("cmd.LauncherCore.AhkTest"), "Keywords", "AhkTest"))
    RimCommand.Register("InstallPlugin", "InstallPlugin", MakeLegacyCmd("InstallPlugin"), Map("Category", "System", "Description", T("cmd.LauncherCore.InstallPlugin"), "Keywords", "InstallPlugin"))
    RimCommand.Register("RemovePlugin", "RemovePlugin", MakeLegacyCmd("RemovePlugin"), Map("Category", "System", "Description", T("cmd.LauncherCore.RemovePlugin"), "Keywords", "RemovePlugin"))
    RimCommand.Register("ListPlugin", "ListPlugin", MakeLegacyCmd("ListPlugin"), Map("Category", "System", "Description", T("cmd.LauncherCore.ListPlugin"), "Keywords", "ListPlugin"))
    RimCommand.Register("CleanupPlugin", "CleanupPlugin", MakeLegacyCmd("CleanupPlugin"), Map("Category", "System", "Description", T("cmd.LauncherCore.CleanupPlugin"), "Keywords", "CleanupPlugin"))
    RimCommand.Register("CountNumber", "CountNumber", MakeLegacyCmd("CountNumber"), Map("Category", "System", "Description", T("cmd.LauncherCore.CountNumber"), "Keywords", "CountNumber"))
    RimCommand.Register("Open", "Open", MakeLegacyCmd("Open"), Map("Category", "System", "Description", T("cmd.LauncherCore.Open"), "Keywords", "Open"))
}

; ---- 输入链 g_Arg 大于剪切板大于 InputBox ----
CoreInput(prompt, title) {
    global g_Arg
    if (g_Arg != "")
        return g_Arg
    clip := ""
    try {
        clip := Trim(A_Clipboard)
    } catch {
        clip := ""
    }
    if (clip != "")
        return clip
    try {
        return InputBox(prompt, title).Value
    } catch {
        return ""
    }
}

; ---- 原版 CmdRun ----
CmdRun() {
    input := CoreInput(T("core.prompt_cmd"), T("core.title_cmd"))
    if (input != "")
        Host("RunWithCmd", input)
}

; ---- 原版 CmdRunOnly ----
CmdRunOnly() {
    input := CoreInput(T("core.prompt_cmd"), T("core.title_cmd"))
    if (input != "")
        Host("RunWithCmd", input, true)
}

; ---- 原版 AhkRun ----
AhkRun() {
    global g_Conf
    input := CoreInput(T("core.prompt_ahk"), T("core.title_ahk"))
    if (input = "")
        return
    debugMode := "0"
    try {
        debugMode := g_Conf.Get("Config", "DebugMode", "0")
    } catch {
        debugMode := "0"
    }
    if (debugMode != "1") {
        errMsg := ""
        try {
            Run(input)
        } catch {
            errMsg := T("core.run_failed", input)
        }
        if (errMsg != "")
            Host("DisplayResult", errMsg)
    } else {
        Run(input)
    }
}

; ---- 原版 RunAndDisplay ----
RunAndDisplay() {
    input := CoreInput(T("core.prompt_rundisplay"), T("core.title_rundisplay"))
    if (input != "")
        Host("DisplayResult", Host("RunAndGetOutput", input))
}

; ---- 原版 WinRRun ----
WinRRun() {
    input := CoreInput(T("core.prompt_winr"), T("core.title_winr"))
    if (input = "")
        return
    Send("#r")
    Sleep(100)
    Send(input)
    Send("{Enter}")
}

; ---- 原版 AhkTest ----
AhkTest() {
    input := CoreInput(T("core.prompt_ahktest"), T("core.title_ahktest"))
    if (input = "")
        return
    testFile := A_Temp . "\RunZ.AhkTest.ahk"
    try {
        FileDelete(testFile)
    } catch {
    }
    FileAppend("#Requires AutoHotkey v2.0`n" . input, testFile)
    Run('"' . A_AhkPath . '" "' . testFile . '"')
}

; ---- 原版 Open ----
Open() {
    global FullPipeArg
    target := ""
    if (FullPipeArg != "")
        target := StrSplit(FullPipeArg, "`r")[1]
    else
        target := CoreInput(T("core.prompt_open"), T("core.title_open"))
    target := Trim(target)
    if (target != "")
        Run(target)
}

; ---- 原版 CountNumber ----
CountNumber() {
    global g_Arg, FullPipeArg
    spaceCount := StrSplit(g_Arg, " ").Length
    lineCount := StrSplit(FullPipeArg, "`n").Length
    if (SubStr(FullPipeArg, -1) = "`n")
        lineCount := lineCount - 1
    result := "* | " . T("core.count_type") . " | " . spaceCount . " | " . T("core.count_space") . "`n"
    result .= "* | " . T("core.count_type") . " | " . lineCount . " | " . T("core.count_line") . "`n"
    Host("DisplayResult", Host("AlignText", result))
}

; ---- 原版 InstallPlugin ----
InstallPlugin() {
    global g_Arg
    pluginPath := Trim(g_Arg)
    if (pluginPath = "") {
        try {
            pluginPath := Trim(A_Clipboard)
        } catch {
            pluginPath := ""
        }
    }
    if (pluginPath = "") {
        try {
            pluginPath := Trim(InputBox(T("core.prompt_install"), T("core.title_install")).Value)
        } catch {
            pluginPath := ""
        }
    }
    if (pluginPath = "")
        return
    if (InStr(pluginPath, "http") == 1) {
        Host("DisplayResult", T("core.downloading"))
        pluginPath := StrReplace(pluginPath, "\", "/")
        tmpFile := A_Temp . "\RunZ.Plugin.txt"
        dlOk := true
        try {
            Download(pluginPath, tmpFile)
        } catch {
            dlOk := false
        }
        if (!dlOk) {
            Host("DisplayResult", T("core.download_failed", pluginPath))
            return
        }
        if (!FileExist(tmpFile)) {
            Host("DisplayResult", T("core.download_failed", pluginPath))
            return
        }
        pluginPath := tmpFile
    }
    if (FileExist(pluginPath)) {
        content := ""
        try {
            content := FileRead(pluginPath, "UTF-8")
        } catch {
            content := ""
        }
        if (content = "") {
            Host("DisplayResult", T("core.invalid_plugin", pluginPath))
            return
        }
        if (SubStr(content, 1, 1) = Chr(0xFEFF))
            content := SubStr(content, 2)
        firstLine := StrSplit(content, "`n", "`r")[1]
        pluginName := ""
        if (InStr(firstLine, "`; RunZ:")) {
            nameParts := StrSplit(firstLine, "`; RunZ:")
            if (nameParts.Length >= 2)
                pluginName := Trim(nameParts[2])
        } else if (InStr(content, "RegisterPlugin_")) {
            if RegExMatch(content, "RegisterPlugin_(\w+)", &m)
                pluginName := m[1]
            else {
                SplitPath(pluginPath, &fn)
                pluginName := RegExReplace(fn, "i)\.(ahk|txt)$", "")
            }
        }
        if (pluginName = "") {
            Host("DisplayResult", T("core.invalid_plugin", pluginPath))
            return
        }
        destFile := A_ScriptDir . "\Plugins\" . pluginName . ".ahk"
        if (FileExist(destFile)) {
            Host("DisplayResult", T("core.plugin_exists"))
            return
        }
        moved := false
        try {
            FileMove(pluginPath, destFile)
            moved := true
        } catch {
            moved := false
        }
        if (!moved) {
            try {
                FileCopy(pluginPath, destFile)
                try {
                    FileDelete(pluginPath)
                } catch {
                }
                moved := true
            } catch {
                moved := false
            }
        }
        if (!moved) {
            Host("DisplayResult", T("core.install_failed", destFile))
            return
        }
        Host("DisplayResult", T("core.install_ok", pluginName))
        Sleep(1000)
        Host("RestartRunZ")
    } else {
        Host("DisplayResult", T("core.file_missing", pluginPath))
    }
}

; ---- 原版 RemovePlugin ----
RemovePlugin() {
    pluginName := Trim(CoreInput(T("core.prompt_remove"), T("core.title_remove")))
    pluginName := RegExReplace(pluginName, "i)\.ahk$", "")
    if (pluginName = "")
        return
    pluginFile := A_ScriptDir . "\Plugins\" . pluginName . ".ahk"
    if (!FileExist(pluginFile)) {
        Host("DisplayResult", T("core.not_installed"))
        return
    }
    delOk := true
    try {
        FileDelete(pluginFile)
    } catch {
        delOk := false
    }
    if (!delOk) {
        Host("DisplayResult", T("core.remove_failed", pluginName))
        return
    }
    Host("DisplayResult", T("core.remove_ok", pluginName))
    Sleep(1000)
    Host("RestartRunZ")
}

; ---- 原版 ListPlugin ----
ListPlugin() {
    global g_Conf
    result := ""
    Loop Files, A_ScriptDir . "\Plugins\*.ahk" {
        SplitPath(A_LoopFileName, , , , &pname)
        descLine := ""
        try {
            fc := FileRead(A_LoopFileFullPath, "UTF-8")
            if (SubStr(fc, 1, 1) = Chr(0xFEFF))
                fc := SubStr(fc, 2)
            fl := StrSplit(fc, "`n", "`r")
            if (fl.Length >= 2)
                descLine := fl[2]
        } catch {
            descLine := ""
        }
        state := T("core.state_on")
        try {
            if (g_Conf.GetValue("Plugins", pname, "1") = "0")
                state := T("core.state_off")
        } catch {
            state := T("core.state_on")
        }
        result .= "* | " . T("core.row_plugin") . " | " . pname . " | " . state . "  " . T("core.row_desc") . SubStr(descLine, 3) . "`n"
    }
    Host("DisplayResult", Host("AlignText", result))
    Host("TurnOnResultFilter")
    Host("SetCommandFilter", "RemovePlugin")
}

; ---- 原版 CleanupPlugin 真删文件 ----
CleanupPlugin() {
    global g_Conf
    result := ""
    Loop Files, A_ScriptDir . "\Plugins\*.ahk" {
        SplitPath(A_LoopFileName, , , , &pname)
        disabled := false
        try {
            if (g_Conf.GetValue("Plugins", pname, "1") = "0")
                disabled := true
        } catch {
            disabled := false
        }
        if (disabled) {
            try {
                FileDelete(A_LoopFileFullPath)
                result .= T("core.cleaned", pname) . "`n"
            } catch {
                result .= T("core.clean_failed", pname) . "`n"
            }
        }
    }
    Loop Files, A_ScriptDir . "\Plugins\*.bak" {
        try {
            FileDelete(A_LoopFileFullPath)
            result .= T("core.file_cleaned", A_LoopFileName) . "`n"
        } catch {
        }
    }
    if (result != "")
        Host("DisplayResult", result)
    else
        Host("DisplayResult", T("core.nothing_to_clean"))
}

; ---- 保留的前版帮助文本, 已按实际绑定修正, 走 DisplayResult ----
; 注 Help 与 KeyHelp 命令透传给主程序同名函数, 下面两个仅保留内容备用, 未注册
LauncherCore_ShowHelp() {
    ; 双语文本见 Lang/*.ini help.launcher
    Host("DisplayResult", T("help.launcher"))
}

LauncherCore_ShowKeyHelp() {
    ; 双语文本见 Lang/*.ini help.keyhelp
    Host("DisplayResult", T("help.keyhelp"))
}
