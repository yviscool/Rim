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
    global g_LastExecLabel, g_LastExecCb, FullPipeArg, g_Arg

    if (originCmd = "")
        return

    ParseArg()

    g_UseDisplay := false
    g_DisableAutoExit := true
    g_ExecInterval := 0

    parsed := CmdLine_Parse(originCmd)
    splitedOriginCmd := parsed["parts"]
    if (parsed["len"] < 2)
        return

    ; 元素格式 (解析规则见 Core/Command.ahk CmdLine_Parse):
    ;   四段式 "key | type | cmd | desc" (来自 [Commands])
    ;   三段式 "type | cmd | desc" (插件/文件列表/回退命令)
    ;   两段式 "file | path" (文件列表)
    cmdKey := parsed["key"]
    cmdType := parsed["type"]
    cmd := parsed["cmd"]
    cmdDesc := parsed["desc"]

    if (cmdType = "function") {
        ; 历史条目会把旧 g_Arg 追加在末尾: legacy 为第 4 段, 四段式为第 5 段
        if (cmdKey != "") {
            if (splitedOriginCmd.Length >= 5)
                g_Arg := splitedOriginCmd[5]
        } else if (splitedOriginCmd.Length >= 4)
            g_Arg := splitedOriginCmd[4]

        ExecuteAction("function|" cmd, g_Arg)
    }
    else {
        ExecuteAction(cmdType "|" cmd, g_Arg)
    }

    ; 保存历史 (对齐原版: 仅 fresh 命令拼 g_Arg, 重放历史不再叠加)
    if (g_Conf["Config"]["SaveHistory"] = "1" && cmd != "DisplayHistoryCommands") {
        isFresh := (cmdKey != "" && splitedOriginCmd.Length = 4) || (cmdKey = "" && splitedOriginCmd.Length = 3)
        if (g_Arg != "" && isFresh)
            g_HistoryCommands.InsertAt(1, originCmd " | " g_Arg)
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
    ; legacy function 命令 (ShutdownTimer 倒计时/Calc 实时) 经同一 function| 入口重进, 与单次语义一致
    if (g_ExecInterval > 0 && cmdType = "function") {
        g_LastExecCb := (*) => ExecuteAction("function|" . cmd, GetRunArg())
        g_LastExecLabel := cmd
        try SetTimer(g_LastExecCb, g_ExecInterval)
    }

    g_PipeArg := ""
    FullPipeArg := ""
}

; legacy function 命令执行体 (语义与旧分支逐行一致: effective-arg 优先显式参数, 否则 g_Arg;
; 直接调真实函数, 不重进协议, 无递归)
LegacyDirectCall(content, callArg := "") {
    global g_Arg
    rest := content
    parts := StrSplit(rest, "|")
    fn := Trim(parts[1])
    fnArg := parts.Length >= 2 ? Trim(parts[2]) : callArg
    if (fnArg = "")
        fnArg := g_Arg
    if (fnArg != "")
        g_Arg := fnArg
    if (fnArg != "") {
        try {
            %fn%(fnArg)
            return true
        } catch {
        }
    }
    try {
        %fn%()
        return true
    } catch as e {
        try RimLog("EXEC_FAILED", fn, e)
        catch {
        }
        return false
    }
}

GetRunArg() {
    global g_Arg
    return g_Arg
}

MakeLegacyCmd(content) {
    return (callArg := "") => LegacyDirectCall(content, callArg)
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
; 递归守卫: RimCommand.Execute ↔ ExecuteAction 双向互调, 动作串自指 (如 Action="command|self")
; 会无界递归; 深度超 10 直接丢弃并记日志 (调用链见日志 action 字段)
ExecuteAction(action := "", actionArg := "") {
    static execDepth := 0
    execDepth += 1
    if (execDepth > 10) {
        execDepth -= 1
        try RimLog("ERROR", "ExecuteAction recursion overflow, drop: " . SubStr(action, 1, 120))
        catch {
        }
        return
    }
    try {
        ExecuteAction_Body(action, actionArg)
    } finally {
        execDepth -= 1
    }
}

; command|id 与裸 ID 的 RimCommand 分发合流点 (原两处手写 IsSet+Registry.Has, 现收敛一处)
ExecuteCommandId(id, actionArg := "") {
    if (IsSet(RimCommand) && IsObject(RimCommand) && RimCommand.Registry.Has(id)) {
        RimCommand.Execute(id, actionArg)
        return true
    }
    return false
}

ExecuteAction_Body(action := "", actionArg := "") {
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
            try RimLog("RUN_FAILED", target, e)
            catch {
            }
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
        if (!ExecuteCommandId(SubStr(action, 9), actionArg))
            ExecuteAction(SubStr(action, 9), actionArg)
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
        global g_Arg
        rest := SubStr(action, 10)
        parts := StrSplit(rest, "|")
        fn := Trim(parts[1])
        ; 桥接命令优先走 Registry (id = 显示名, 冲突时 legacy. 显示名); 找不到才直调 (手写行兜底)
        if (ExecuteCommandId(fn, parts.Length >= 2 ? Trim(parts[2]) : actionArg))
            return
        if (ExecuteCommandId("legacy." . fn, parts.Length >= 2 ? Trim(parts[2]) : actionArg))
            return
        fnArg := parts.Length >= 2 ? Trim(parts[2]) : actionArg
        if (fnArg != "")
            g_Arg := fnArg
        if (fnArg != "") {
            try {
                %fn%(fnArg)
                return
            } catch {
            }
        }
        try %fn%()
        catch as e {
            try RimLog("EXEC_FAILED", fn, e)
            catch {
            }
        }
    }
    else {
        ; 已注册的 RimCommand (合流点, 未注册则落到函数名直调)
        if (ExecuteCommandId(action, actionArg))
            return

        ; <ActionName> 或普通函数名: 转函数名后直调
        fn := ActionToFuncName(action)
        if (actionArg != "") {
            try {
                %fn%(actionArg)
                return
            } catch {
            }
        }
        try %fn%()
        catch as e {
            try RimLog("EXEC_FAILED", fn, e)
            catch {
            }
        }
    }
}

; VIMD_CMD 兼容接口: 委托至 ExecuteAction (垫片保留: 插件/手势动作串经此进入, 退役需全仓动作串审计)
VIMD_CMD(action := "") {
    ExecuteAction(action)
}

; 显示当前参数 (原版 Core 插件 ShowArg)
ShowArg() {
    global g_Arg, FullPipeArg
    msg := T("arg.head") . " " . g_Arg
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
