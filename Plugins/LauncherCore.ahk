#Requires AutoHotkey v2.0
#Warn All, Off

; === LauncherCore Plugin - 核心功能 ===
; Faithful v2 port of RunZ Plugins Core v1, 207 lines.
; 移植规则如下
; v1 的每个 Label 子程序变为同名 v2 函数, 逻辑不变, GoSub 变为直接调用.
; 每个命令一律先读全局 Arg, 再读剪切板, 两者皆空才弹 InputBox.
; 结果一律走 DisplayResult, 不用 MsgBox 显示结果.
; 本构建加载期检查说明
; 静态调用未知函数名会加载失败, 所以主程序提供的函数一律走 Host 动态调用.
; 加载期读未赋值变量会卡住, 所以 Arg 和 FullPipeArg 在此给顶层空值.
; g_Conf 由主程序赋值, 此处哑赋值仅为通过独立加载检查, 永不执行.
; 本构建把分号当注释, 即使在字符串里, 所以字符串中的分号一律用重音符转义.
; 以下名字已存在于主程序或其他插件, 本文件只注册透传, 不重复定义
; Help KeyHelp ReindexFiles EditConfig CleanupRank 见 Core Hotkeys
; ShowArg 见 Core Execution, RunClipboard 见 Misc 插件

global Arg := ""
global FullPipeArg := ""

__LauncherCore_LoadGuard() {
    global g_Conf
    if (false)
        g_Conf := ""
}

Host(fn, args*) {
    return %fn%(args*)
}

RegisterPlugin_LauncherCore() {
    Core()
}

; ---- 原版 Core 标签 ----
Core() {
    Host("RegisterCommand", "Help", "function", "Help", "帮助信息")
    Host("RegisterCommand", "KeyHelp", "function", "KeyHelp", "置顶的按键帮助信息")
    Host("RegisterCommand", "AhkRun", "function", "AhkRun", "使用 Ahk 的 Run() 运行 `; command")
    Host("RegisterCommand", "CmdRun", "function", "CmdRun", "使用 cmd 运行 : command")
    Host("RegisterCommand", "CmdRunOnly", "function", "CmdRunOnly", "只使用 cmd 运行")
    Host("RegisterCommand", "WinRRun", "function", "WinRRun", "使用 win + r 运行")
    Host("RegisterCommand", "RunAndDisplay", "function", "RunAndDisplay", "使用 cmd 运行，并显示结果")
    Host("RegisterCommand", "ReindexFiles", "function", "ReindexFiles", "重新索引待搜索文件")
    Host("RegisterCommand", "EditConfig", "function", "EditConfig", "编辑配置文件")
    Host("RegisterCommand", "RunClipboard", "function", "RunClipboard", "使用 ahk 的 Run 运行剪切板内容")
    Host("RegisterCommand", "CleanupRank", "function", "CleanupRank", "清理命令权重中的无效命令")
    Host("RegisterCommand", "ShowArg", "function", "ShowArg", "显示参数：ShowArg arg1 arg2 ...")
    Host("RegisterCommand", "AhkTest", "function", "AhkTest", "运行参数或者剪切板中的 AHK 代码")
    Host("RegisterCommand", "InstallPlugin", "function", "InstallPlugin", "安装插件")
    Host("RegisterCommand", "RemovePlugin", "function", "RemovePlugin", "卸载插件")
    Host("RegisterCommand", "ListPlugin", "function", "ListPlugin", "列出插件")
    Host("RegisterCommand", "CleanupPlugin", "function", "CleanupPlugin", "清理插件")
    Host("RegisterCommand", "CountNumber", "function", "CountNumber", "计算数量 wc")
    Host("RegisterCommand", "Open", "function", "Open", "打开")
}

; ---- 输入链 Arg 大于剪切板大于 InputBox ----
CoreInput(prompt, title) {
    global Arg
    if (Arg != "")
        return Arg
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
    input := CoreInput("输入 CMD 命令:", "Cmd 运行")
    if (input != "")
        Host("RunWithCmd", input)
}

; ---- 原版 CmdRunOnly ----
CmdRunOnly() {
    input := CoreInput("输入 CMD 命令:", "Cmd 运行")
    if (input != "")
        Host("RunWithCmd", input, true)
}

; ---- 原版 AhkRun ----
AhkRun() {
    global g_Conf
    input := CoreInput("输入要运行的命令:", "Ahk 运行")
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
            errMsg := "运行命令 " . input . " 失败`n设置配置文件中 DebugMode 为 1 可查看错误详情"
        }
        if (errMsg != "")
            Host("DisplayResult", errMsg)
    } else {
        Run(input)
    }
}

; ---- 原版 RunAndDisplay ----
RunAndDisplay() {
    input := CoreInput("输入命令:", "运行并显示")
    if (input != "")
        Host("DisplayResult", Host("RunAndGetOutput", input))
}

; ---- 原版 WinRRun ----
WinRRun() {
    input := CoreInput("输入运行内容:", "Win+R 运行")
    if (input = "")
        return
    Send("#r")
    Sleep(100)
    Send(input)
    Send("{Enter}")
}

; ---- 原版 AhkTest ----
AhkTest() {
    input := CoreInput("输入要测试的 AHK 代码:", "Ahk 测试")
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
        target := CoreInput("输入要打开的路径:", "打开")
    target := Trim(target)
    if (target != "")
        Run(target)
}

; ---- 原版 CountNumber ----
CountNumber() {
    global Arg, FullPipeArg
    spaceCount := StrSplit(Arg, " ").Length
    lineCount := StrSplit(FullPipeArg, "`n").Length
    if (SubStr(FullPipeArg, -1) = "`n")
        lineCount := lineCount - 1
    result := "* | 数量 | " . spaceCount . " | 以空格为分隔符`n"
    result .= "* | 数量 | " . lineCount . " | 以换行为分隔符`n"
    Host("DisplayResult", Host("AlignText", result))
}

; ---- 原版 InstallPlugin ----
InstallPlugin() {
    global Arg
    pluginPath := Trim(Arg)
    if (pluginPath = "") {
        try {
            pluginPath := Trim(A_Clipboard)
        } catch {
            pluginPath := ""
        }
    }
    if (pluginPath = "") {
        try {
            pluginPath := Trim(InputBox("输入插件路径或 URL:", "安装插件").Value)
        } catch {
            pluginPath := ""
        }
    }
    if (pluginPath = "")
        return
    if (InStr(pluginPath, "http") == 1) {
        Host("DisplayResult", "下载中，请稍后...")
        pluginPath := StrReplace(pluginPath, "\", "/")
        tmpFile := A_Temp . "\RunZ.Plugin.txt"
        dlOk := true
        try {
            Download(pluginPath, tmpFile)
        } catch {
            dlOk := false
        }
        if (!dlOk) {
            Host("DisplayResult", "下载失败: " . pluginPath)
            return
        }
        if (!FileExist(tmpFile)) {
            Host("DisplayResult", "下载失败: " . pluginPath)
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
            Host("DisplayResult", pluginPath . " 并不是有效的 RunZ 插件")
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
            Host("DisplayResult", pluginPath . " 并不是有效的 RunZ 插件")
            return
        }
        destFile := A_ScriptDir . "\Plugins\" . pluginName . ".ahk"
        if (FileExist(destFile)) {
            Host("DisplayResult", "该插件已存在")
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
            Host("DisplayResult", "安装失败，无法复制到 " . destFile)
            return
        }
        Host("DisplayResult", pluginName . " 插件安装成功，RunZ 将重启并启用该插件")
        Sleep(1000)
        Host("RestartRunZ")
    } else {
        Host("DisplayResult", pluginPath . " 文件不存在")
    }
}

; ---- 原版 RemovePlugin ----
RemovePlugin() {
    pluginName := Trim(CoreInput("输入插件名称:", "卸载插件"))
    pluginName := RegExReplace(pluginName, "i)\.ahk$", "")
    if (pluginName = "")
        return
    pluginFile := A_ScriptDir . "\Plugins\" . pluginName . ".ahk"
    if (!FileExist(pluginFile)) {
        Host("DisplayResult", "未安装该插件")
        return
    }
    delOk := true
    try {
        FileDelete(pluginFile)
    } catch {
        delOk := false
    }
    if (!delOk) {
        Host("DisplayResult", pluginName . " 插件删除失败")
        return
    }
    Host("DisplayResult", pluginName . " 插件删除成功，RunZ 将重启以生效")
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
        state := "已启用"
        try {
            if (g_Conf.GetValue("Plugins", pname, "1") = "0")
                state := "已禁用"
        } catch {
            state := "已启用"
        }
        result .= "* | 插件 | " . pname . " | " . state . "  描述：" . SubStr(descLine, 3) . "`n"
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
                result .= pname . " 插件已被清理，下次运行 RunZ 将不再引入`n"
            } catch {
                result .= pname . " 插件清理失败`n"
            }
        }
    }
    Loop Files, A_ScriptDir . "\Plugins\*.bak" {
        try {
            FileDelete(A_LoopFileFullPath)
            result .= A_LoopFileName . " 已清理`n"
        } catch {
        }
    }
    if (result != "")
        Host("DisplayResult", result)
    else
        Host("DisplayResult", "无可清理插件")
}

; ---- 保留的前版帮助文本, 已按实际绑定修正, 走 DisplayResult ----
; 注 Help 与 KeyHelp 命令透传给主程序同名函数, 下面两个仅保留内容备用, 未注册
LauncherCore_ShowHelp() {
    helpText := "Rim 帮助`n`n"
    helpText .= "热键:`n"
    helpText .= "  Enter - 执行选中命令`n"
    helpText .= "  Up Down 或 Ctrl+J K - 上下移动选择`n"
    helpText .= "  Ctrl+F B - 下翻 上翻页`n"
    helpText .= "  Alt+字母 - 按首字母执行`n"
    helpText .= "  Ctrl+Enter - 保存为管道参数`n"
    helpText .= "  Space - 结果过滤模式`n"
    helpText .= "  Ctrl+H - 显示历史`n"
    helpText .= "  Ctrl+N P - 增加 减少权重`n"
    helpText .= "  Ctrl+D - 打开文件目录`n"
    helpText .= "  Ctrl+X - 删除文件`n"
    helpText .= "  Ctrl+S - 显示完整路径`n"
    helpText .= "  Ctrl+L U - 清空输入`n"
    helpText .= "  Ctrl+I O - 光标到行首 行尾`n"
    helpText .= "  F1 - 帮助`n"
    helpText .= "  Shift+F1 - 按键帮助`n"
    helpText .= "  F2 F3 - 编辑配置 自动配置`n"
    helpText .= "  Ctrl+R - 重建索引`n"
    helpText .= "  Ctrl+Q - 重启`n"
    helpText .= "  Esc - 清空 关闭`n`n"
    helpText .= "命令前缀:`n"
    helpText .= "  `; - AHK运行`n"
    helpText .= "  : - CMD运行`n"
    helpText .= "  | - 管道参数`n"
    helpText .= "  @ - 跳转`n"
    helpText .= "  直接输入 URL - 打开浏览器`n"
    Host("DisplayResult", helpText)
}

LauncherCore_ShowKeyHelp() {
    keyHelpText := "Rim 按键帮助`n`n"
    keyHelpText .= "  Shift+F1 - 显示置顶按键帮助`n"
    keyHelpText .= "  Alt+F4 - 关闭`n"
    keyHelpText .= "  Enter - 执行当前命令`n"
    keyHelpText .= "  Esc - 关闭窗口`n"
    keyHelpText .= "  Alt+字母 - 按首字母执行`n"
    keyHelpText .= "  Ctrl+J K - 下 上一个命令`n"
    keyHelpText .= "  Ctrl+F B - 下翻 上翻页`n"
    keyHelpText .= "  Ctrl+H - 显示历史`n"
    keyHelpText .= "  Ctrl+N P - 增加 减少权重`n"
    keyHelpText .= "  Ctrl+L - 清空输入框`n"
    keyHelpText .= "  Ctrl+R - 重建文件索引`n"
    keyHelpText .= "  Ctrl+Q - 重启`n"
    keyHelpText .= "  F2 - 编辑配置文件`n"
    keyHelpText .= "  F3 - 编辑自动配置`n"
    Host("DisplayResult", keyHelpText)
}
