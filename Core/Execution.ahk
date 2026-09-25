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

    if (cmdType = "function") {
        ; 历史条目会把旧 Arg 追加在末尾: legacy 为第 4 段, 四段式为第 5 段
        if (cmdKey != "") {
            if (splitedOriginCmd.Length >= 5)
                Arg := splitedOriginCmd[5]
        } else if (splitedOriginCmd.Length >= 4)
            Arg := splitedOriginCmd[4]

        ExecuteAction("function|" cmd, Arg)
    }
    else {
        ExecuteAction(cmdType "|" cmd, Arg)
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
    if (IsObject(g_Conf) && g_Conf.HasSection("Config")) {
        sec := g_Conf["Config"]
        if (sec.Has("TCPath") && sec["TCPath"] != "" && FileExist(sec["TCPath"])) {
            Run(sec["TCPath"] ' /O /A /L="' filePath '"')
            return
        }
    }
    SplitPath(filePath, , &fileDir)
    Run('explorer "' fileDir '"')
}

; === 统一动作/命令执行器 (Unified Action & Command Dispatcher) ===
ExecuteAction(action := "", actionArg := "") {
    global g_VimEngine
    if (action = "") {
        if (IsSet(g_VimEngine) && IsObject(g_VimEngine))
            action := g_VimEngine.lastAction
    }
    action := Trim(action)
    if (action = "")
        return

    cleanAction := action
    if (SubStr(action, 1, 1) = "<" && SubStr(action, -1) = ">")
        cleanAction := SubStr(action, 2, StrLen(action) - 2)

    ; 1. 优先检查插件注册的前缀动作分发器 (如 tccmd|, cm_ 等, 兼容 <cm_...>)
    if (IsSet(g_VimEngine) && IsObject(g_VimEngine)) {
        for prefix, handler in g_VimEngine.ActionPrefixHandlers {
            pLen := StrLen(prefix)
            if (SubStr(cleanAction, 1, pLen) = prefix) {
                if handler(cleanAction)
                    return
            } else if (SubStr(action, 1, pLen) = prefix) {
                if handler(action)
                    return
            }
        }
    }

    ; 2. 核心动作类型派发
    if (SubStr(action, 1, 4) = "run|" || SubStr(action, 1, 5) = "file|") {
        target := SubStr(action, SubStr(action, 1, 4) = "run|" ? 5 : 6)
        if (InStr(target, ".lnk")) {
            try {
                FileGetShortcut(target, &filePath)
                if (!FileExist(filePath)) {
                    filePath := StrReplace(filePath, "C:\Program Files (x86)", "C:\Program Files")
                    if (FileExist(filePath))
                        target := filePath
                }
            }
        }
        SplitPath(target, , &fileDir)
        try {
            if (fileDir != "" && DirExist(fileDir)) {
                if (actionArg = "")
                    Run(target, fileDir)
                else
                    Run(target ' "' actionArg '"', fileDir)
            } else {
                if (actionArg = "")
                    Run(target)
                else
                    Run(target ' "' actionArg '"')
            }
        } catch as e {
            try FileAppend(A_Now . " RUN_FAILED: " . target . " err=" . e.Message . "`n", A_ScriptDir . "\Rim.error.log")
        }
    }
    else if (SubStr(action, 1, 4) = "key|") {
        Send(SubStr(action, 5))
    }
    else if (SubStr(action, 1, 7) = "wshkey|") {
        SendLevel 1
        Send(SubStr(action, 8))
        SendLevel 0
    }
    else if (SubStr(action, 1, 4) = "dir|") {
        OpenPath(SubStr(action, 5))
    }
    else if (SubStr(action, 1, 4) = "cmd|") {
        RunWithCmd(SubStr(action, 5))
    }
    else if (SubStr(action, 1, 8) = "command|") {
        if (IsSet(RimCommand) && IsObject(RimCommand))
            RimCommand.Execute(SubStr(action, 9), actionArg)
    }
    else if (SubStr(action, 1, 4) = "url|") {
        url := SubStr(action, 5)
        if InStr(url, "{query}") {
            q := Trim(actionArg != "" ? actionArg : A_Clipboard)
            url := StrReplace(url, "{query}", UrlEncode(q))
        }
        if (!InStr(url, "http"))
            url := "http://" . url
        Run(url)
    }
    else if (SubStr(action, 1, 9) = "function|") {
        global Arg
        rest := SubStr(action, 10)
        parts := StrSplit(rest, "|")
        fn := Trim(parts[1])
        fnArg := parts.Length >= 2 ? Trim(parts[2]) : actionArg
        if (fnArg != "")
            Arg := fnArg
        fn := ResolveFuncAlias(fn)
        if (fnArg != "") {
            try {
                %fn%(fnArg)
                return
            } catch {
            }
        }
        try %fn%()
        catch as e {
            try FileAppend(A_Now . " EXEC_FAILED: " . fn . " err=" . e.Message . "`n", A_ScriptDir . "\Rim.error.log")
        }
    }
    else {
        ; 检查是否为已注册的 RimCommand
        if (IsSet(RimCommand) && IsObject(RimCommand) && RimCommand.Registry.Has(action)) {
            RimCommand.Execute(action, actionArg)
            return
        }

        ; <ActionName> 或普通函数名: 转函数名后直调
        fn := ActionToFuncName(action)
        fn := ResolveFuncAlias(fn)
        if (actionArg != "") {
            try {
                %fn%(actionArg)
                return
            } catch {
            }
        }
        try %fn%()
        catch as e {
            try FileAppend(A_Now . " EXEC_FAILED: " . fn . " err=" . e.Message . "`n", A_ScriptDir . "\Rim.error.log")
        }
    }
}

; VIMD_CMD 兼容接口: 委托至 ExecuteAction
VIMD_CMD(action := "") {
    ExecuteAction(action)
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
