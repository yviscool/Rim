#Requires AutoHotkey v2.0
#Warn All, Off

; === Execution - 命令执行 (从 RunZ Core/Execution.ahk 移植) ===

; 清空输入框
ClearInput() {
    global g_InputEdit, g_CurrentInput
    g_InputEdit.Value := ""
    g_CurrentInput := ""
    g_InputEdit.Focus()
}

; 运行命令并获取输出 (v2: FileRead 为返回值式)
RunAndGetOutput(command) {
    tempFileName := "RunZ.stdout.log"
    fullCommand := A_ComSpec ' /C "' command ' > ' tempFileName '"'
    RunWait(fullCommand, A_Temp, "Hide")
    try {
        result := FileRead(A_Temp "\" tempFileName, "UTF-8")
    } catch {
        result := ""
    }
    try FileDelete(A_Temp "\" tempFileName)
    return result
}

; 核心命令执行
RunCommand(originCmd) {
    global g_UseDisplay, g_DisableAutoExit, g_ExecInterval, g_PipeArg
    global g_HistoryCommands, g_Conf
    global g_CurrentInput, g_AutoConf, g_ExcludedCommands
    global g_LastExecLabel, g_LastExecCb, FullPipeArg, Arg

    if (originCmd = "")
        return

    ParseArg()

    g_UseDisplay := false
    g_DisableAutoExit := true
    g_ExecInterval := 0

    splitedOriginCmd := StrSplit(originCmd, " | ")
    if (splitedOriginCmd.Length < 2)
        return

    ; 元素格式:
    ;   四段式 "key | type | cmd | desc" (来自 [Commands])
    ;   三段式 "type | cmd | desc" (插件/文件列表/回退命令)
    ;   两段式 "file | path" (文件列表)
    if (splitedOriginCmd.Length >= 4
        && (splitedOriginCmd[2] = "file" || splitedOriginCmd[2] = "function" || splitedOriginCmd[2] = "cmd" || splitedOriginCmd[2] = "url" || splitedOriginCmd[2] = "run")) {
        cmdKey := splitedOriginCmd[1]
        cmdType := splitedOriginCmd[2]
        cmd := splitedOriginCmd[3]
        cmdDesc := splitedOriginCmd[4]
    } else {
        cmdKey := ""
        cmdType := splitedOriginCmd[1]
        cmd := splitedOriginCmd[2]
        cmdDesc := splitedOriginCmd.Length >= 3 ? splitedOriginCmd[3] : ""
    }

    if (cmdType = "file" || cmdType = "run") {
        if (InStr(cmd, ".lnk")) {
            try {
                FileGetShortcut(cmd, &filePath)
                if (!FileExist(filePath)) {
                    filePath := StrReplace(filePath, "C:\Program Files (x86)", "C:\Program Files")
                    if (FileExist(filePath))
                        cmd := filePath
                }
            }
        }

        SplitPath(cmd, , &fileDir)

        if (Arg = "")
            Run(cmd, fileDir)
        else
            Run(cmd ' "' Arg '"', fileDir)
    }
    else if (cmdType = "function") {
        ; 历史条目会把旧 Arg 追加在末尾: legacy 为第 4 段, 四段式为第 5 段
        if (cmdKey != "") {
            if (splitedOriginCmd.Length >= 5)
                Arg := splitedOriginCmd[5]
        } else if (splitedOriginCmd.Length >= 4)
            Arg := splitedOriginCmd[4]

        ; 回退别名解析后直调 (本构建无 IsFunc; 缺失走 OnError 网记日志继续)
        cmd := ResolveFuncAlias(cmd)
        %cmd%()
    }
    else if (cmdType = "cmd") {
        RunWithCmd(cmd)
    }
    else if (cmdType = "url") {
        ; {query} 占位: Arg > 剪切板, 编码后替换 (搜索引擎模板)
        if InStr(cmd, "{query}") {
            q := Trim(Arg != "" ? Arg : A_Clipboard)
            cmd := StrReplace(cmd, "{query}", UrlEncode(q))
        }
        if (!InStr(cmd, "http"))
            cmd := "http://" . cmd
        Run(cmd)
    }

    ; 保存历史 (对齐原版: 仅 fresh 命令拼 Arg, 重放历史不再叠加)
    if (g_Conf["Config"]["SaveHistory"] = "1" && cmd != "DisplayHistoryCommands") {
        isFresh := (cmdKey != "" && splitedOriginCmd.Length = 4) || (cmdKey = "" && splitedOriginCmd.Length = 3)
        if (Arg != "" && isFresh)
            g_HistoryCommands.InsertAt(1, originCmd " | " Arg)
        else if (originCmd != "")
            g_HistoryCommands.InsertAt(1, originCmd)

        if (g_HistoryCommands.Length > (g_Conf["Config"]["HistorySize"] + 0))
            g_HistoryCommands.Pop()
    }

    ; SmartInput 输入历史 (隐私黑名单内跳过, 会话级, 供 ghost/Alt+UpDown 用)
    try {
        SI_NoteInput(g_CurrentInput)
    } catch {
    }

    ; 自动排名
    if (g_Conf["Config"]["AutoRank"] = "1")
        ChangeRank(originCmd)

    g_DisableAutoExit := false

    ; RunOnce
    if (g_Conf["Config"]["RunOnce"] = "1" && !g_UseDisplay) {
        if (g_Conf["Config"]["KeepInputText"] != "1")
            ClearInput()
        HideOrExit()
    }

    ; 间隔执行 (闭包对象; 本构建 SetTimer 忌字符串名/Func())
    if (g_ExecInterval > 0 && cmdType = "function") {
        fn := ResolveFuncAlias(cmd)
        g_LastExecCb := MakeCb(fn)
        g_LastExecLabel := fn
        try SetTimer(g_LastExecCb, g_ExecInterval)
    }

    g_PipeArg := ""
    FullPipeArg := ""
}

; 命令名 → 函数名解析
; 现插件注册均为名实合一 (name==content), 别名表仅作兼容兜底; 缺失走 OnError 网
ResolveFuncAlias(cmd) {
    global g_FuncAlias
    if (g_FuncAlias.Has(cmd))
        return g_FuncAlias[cmd]
    return cmd
}

; 通过 cmd 运行
RunWithCmd(command, onlyCmd := false) {
    global g_Conf
    if (!onlyCmd && FileExist("c:\msys64\usr\bin\mintty.exe"))
        Run("mintty -e sh -c '" command "; read'")
    else
        Run(A_ComSpec " /C " command " & pause")
}

; 打开文件路径
OpenPath(filePath) {
    global g_Conf
    if (!FileExist(filePath))
        return
    if (FileExist(g_Conf["Config"]["TCPath"])) {
        TCPath := g_Conf["Config"]["TCPath"]
        Run(TCPath ' /O /A /L="' filePath '"')
    } else {
        SplitPath(filePath, , &fileDir)
        Run('explorer "' fileDir '"')
    }
}

; 显示当前参数 (原版 Core 插件 ShowArg)
ShowArg() {
    global Arg, FullPipeArg
    msg := T("arg.head") . " " . Arg
    if (FullPipeArg != "")
        msg .= "`n" . T("arg.pipehead") . "`n" FullPipeArg
    DisplayResult(msg)
}

; 获取所有函数命令
GetAllFunctions() {
    global g_Commands
    result := ""
    for index, element in g_Commands {
        if ((InStr(element, "function | ") = 1 || InStr(element, " | function | ") > 0) && !InStr(result, element "`n"))
            result .= "* | " element "`n"
    }
    result := StrReplace(result, "function | ", TypeLabel("function"))
    return AlignText(result)
}
