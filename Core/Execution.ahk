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

; 运行命令并获取输出: 唯一临时文件 (Tick+PID, 防并发覆盖) + 超时 (默认 5s, 超时杀进程) + finally 清理.
; 返回 Map{ok, output, exitCode, timedOut, error, file}; 超时/失败 ok=false, output 为已读到的部分输出.
RunAndGetOutput(command, timeoutMs := 5000) {
    uniq := "Rim.stdout." . DllCall("kernel32\GetCurrentProcessId", "UInt") . "." . A_TickCount . ".log"
    tmpPath := A_Temp . "\" . uniq
    fullCommand := A_ComSpec . ' /C "' . command . ' > "' . tmpPath . '" 2>&1"'
    pid := 0
    try {
        Run(fullCommand, A_Temp, "Hide", &pid)
    } catch Error as e {
        try RimLog("ERROR", "RunAndGetOutput spawn failed: " . SubStr(String(command), 1, 80), e)
        catch {
        }
        return Map("ok", false, "output", "", "exitCode", -1, "timedOut", false, "error", e.Message, "file", "")
    }
    timedOut := false
    exitCode := 0
    try {
        if (timeoutMs > 0 && pid) {
            ; 超时等待: 子进程在时限内不退出则杀掉, 绝不永久阻塞输入线程
            errLevel := ProcessWaitClose(pid, timeoutMs / 1000)
            if (errLevel = 0) {
                timedOut := true
                try ProcessClose(pid)
                catch {
                }
                try {
                    pid2 := pid
                    DllCall("kernel32\TerminateProcess", "Ptr", DllCall("kernel32\OpenProcess", "UInt", 1, "Int", 0, "UInt", pid2, "Ptr"), "UInt", 1)
                } catch {
                }
                try RimLog("WARN", "RunAndGetOutput timeout(" . timeoutMs . "ms) kill: " . SubStr(String(command), 1, 80))
                catch {
                }
            }
            try exitCode := ProcessExist(pid) ? -1 : 0
            catch {
            }
        } else if (pid) {
            ProcessWaitClose(pid)
        }
    } catch Error as e {
        try RimLog("ERROR", "RunAndGetOutput wait failed", e)
        catch {
        }
    }
    output := ""
    try {
        if (FileExist(tmpPath))
            output := FileRead(tmpPath, "UTF-8")
    } catch Error as e {
        try RimLog("WARN", "RunAndGetOutput read failed: " . tmpPath, e)
        catch {
        }
    }
    try FileDelete(tmpPath)
    catch {
    }
    if (timedOut)
        return Map("ok", false, "output", output, "exitCode", -1, "timedOut", true, "error", "timeout", "file", "")
    return Map("ok", true, "output", output, "exitCode", exitCode, "timedOut", false, "error", "", "file", "")
}

; 核心命令执行
RunCommand(originCmd) {
    global g_UseDisplay, g_DisableAutoExit, g_PipeArg
    global g_HistoryCommands, g_Conf
    global g_CurrentInput, g_AutoConf
    global FullPipeArg, g_Arg

    if (originCmd = "")
        return

    ; 规范记录拆包: 历史回放行自带权威参数, 全类型一致, 不再按 type 特判.
    ; 回放时输入框是旧查询 (不可信), 记录内参数优先于 ParseArg 结果
    histRec := HistSplit(originCmd)
    if (histRec["has"]) {
        originCmd := histRec["el"]
        if (originCmd = "")
            return
    }

    ParseArg()

    ; 单链起点 (DebugMode=1 才落盘): 后续 ExecuteAction/手势经 g_LogSid 续写
    try {
        global g_LogSid
        g_LogSid := LogTrace_Begin("run " . SubStr(originCmd, 1, 60))
    } catch {
    }

    g_UseDisplay := false
    g_DisableAutoExit := true

    parsed := CmdLine_Parse(originCmd)
    if (parsed["len"] < 2)
        return

    ; 元素格式 (解析规则见 Core/Command.ahk CmdLine_Parse):
    ;   四段式 "key | type | cmd | desc" (来自 [Commands])
    ;   三段式 "type | cmd | desc" (插件/文件列表/回退命令)
    ;   两段式 "file | path" (文件列表)
    ; 历史回放行已在入口拆包 (HistSplit), 此处只见干净元素 + g_Arg
    cmdType := parsed["type"]
    cmd := parsed["cmd"]
    cmdDesc := parsed["desc"]

    ; 回放权威参数: 覆盖 ParseArg 从残留输入框读出的不可信值 (全类型一致)
    if (histRec["has"] && Trim(histRec["arg"]) != "")
        g_Arg := Trim(histRec["arg"])

    ; 参数校验门 (仅 Registry 有 required 声明的命令; 未声明=全可选, 零行为变化).
    ; 拦下后展示用法, 不执行、不记历史不涨 rank (失败不是使用)
    if (cmdType = "command" && IsSet(RimCommand)) {
        usage := ""
        try usage := RimCommand.CheckArgs(cmd, g_Arg)
        catch Error as e {
            try RimTryLog("RunCommand.CheckArgs", e, cmd)
            catch {
            }
        }
        if (usage != "") {
            try DisplayResult(usage)
            catch Error as e {
                try RimTryLog("RunCommand.DisplayUsage", e, cmd)
                catch {
                }
            }
            return
        }
    }

    if (cmdType = "function") {
        ExecuteAction("function|" cmd, g_Arg)
    }
    else {
        ExecuteAction(cmdType "|" cmd, g_Arg)
    }

    ; 保存历史 (规范记录: 元素与参数分栏存储, 回放/还原按位拆回, 与类型无关)
    saveHist := CfgGet("Config", "SaveHistory", "1")
    histSize := 100
    try histSize := Integer(CfgGet("Config", "HistorySize", "100"))
    catch {
    }
    if (saveHist = "1" && cmd != "DisplayHistoryCommands") {
        g_HistoryCommands.InsertAt(1, HistPack(originCmd, g_Arg))

        if (g_HistoryCommands.Length > histSize)
            g_HistoryCommands.Pop()
    }

    ; SmartInput 输入历史 (隐私黑名单内跳过, 会话级, 供 ghost/Alt+UpDown 用)
    try {
        SI_NoteInput(g_CurrentInput)
    } catch {
    }

    ; 自动排名
    autoRank := CfgGet("Config", "AutoRank", "1")
    if (autoRank = "1")
        ChangeRank(originCmd)

    g_DisableAutoExit := false

    ; RunOnce
    runOnce := CfgGet("Config", "RunOnce", "0")
    keepInput := CfgGet("Config", "KeepInputText", "1")
    if (runOnce = "1" && !g_UseDisplay) {
        if (keepInput != "1")
            ClearInput()
        HideOrExit()
    }

    ; 注: 间隔执行机制已彻底移除 (SetExecInterval/g_ExecInterval/g_LastExecCb 删除);
    ; Calc 实时靠重执行不靠 timer.

    g_PipeArg := ""
    FullPipeArg := ""
}

; legacy function 命令执行体 (参数拆分保留调用方语义, 调用序列收敛到 ActionRunFunction;
; viaRegistry=false: 本体即 Registry 动作实现, 查表自指会无限递归且绕过深度守卫)
LegacyDirectCall(content, callArg := "") {
    global g_Arg
    rest := content
    parts := StrSplit(rest, "|")
    fn := Trim(parts[1])
    fnArg := parts.Length >= 2 ? Trim(parts[2]) : callArg
    if (fnArg = "")
        fnArg := g_Arg
    return ActionRunFunction(fn, fnArg, content, false, false, false)
}

GetRunArg() {
    global g_Arg
    return g_Arg
}

MakeLegacyCmd(content) {
    return (callArg := "") => LegacyDirectCall(content, callArg)
}

; 通过终端运行 (偏好链: wt → PATH 上的 mintty → cmd; 均走 PATH, 不再硬编码 msys 路径)
RunWithCmd(command, onlyCmd := false) {
    if (!onlyCmd) {
        try {
            Run('wt.exe cmd /C "' command ' & pause"')
            return
        } catch {
        }
        try {
            Run("mintty -e sh -c '" command "; read'")
            return
        } catch {
        }
    }
    Run(A_ComSpec " /C " command " & pause")
}

; 打开文件路径
OpenPath(filePath) {
    global g_Conf
    if (!FileExist(filePath))
        return
    if (IsObject(g_Conf) && g_Conf.HasSection("Config")) {
        tc := TC_EffPath()
        if (tc != "" && FileExist(tc)) {
            Run(tc ' /O /A /L="' filePath '"')
            return
        }
    }
    SplitPath(filePath, , &fileDir)
    Run('explorer "' fileDir '"')
}

; === 统一动作/命令执行器 (Unified Action & Command Dispatcher) ===
; 递归守卫: RimCommand.Execute ↔ ExecuteAction 双向互调, 动作串自指 (如 Action="command|self")
; 会无界递归; 深度超 10 直接丢弃并记日志 (调用链见日志 action 字段).
; 统一入口: 先经 ActionDispatch 真执行 (command/function/legacy/combo).
; 只有 OK (已执行) / HANDLER_FAIL (已接管, 含记死) 才跳过 Body;
; OK_DEFER (run|file|key|dir|cmd|url 无人可接) 与 UNKNOWN_COMMAND/解析失败才落到 Body.
; ok=true 不等于已执行, 错判则文件/网址/按键静默死亡 (血泪).
; 分发异常 (ActionParse/ActionDispatch 抛错): 记录并结束, 绝不自动下坠 Body,
; 否则"分发失败"会被误认为"无人处理"导致重复执行或静默失败.
; 结果形态: Map{code, handled, error, source}; code ∈ OK|OK_DEFER|HANDLER_FAIL|UNKNOWN_COMMAND|RECURSION|DISPATCH_ERROR|EMPTY.
ActionResult(code, handled, error := "", source := "") {
    return Map("code", code, "handled", handled, "error", String(error), "source", String(source))
}

; 统一动作/命令执行器 (唯一入口, 返回结构化结果; 调用方忽略返回值即"发后不管")
ExecuteAction(action := "", actionArg := "", source := "", depth := 0) {
    if (depth > 10) {
        try RimLog("ERROR", "ExecuteAction recursion overflow, drop: " . SubStr(String(action), 1, 120))
        catch {
        }
        return ActionResult("RECURSION", true, "depth overflow", source)
    }
    parsed := ""
    try {
        parsed := ActionParse(action, source)
    } catch Error as e {
        try RimLog("ERROR", "ActionParse throw src=" . source, e)
        catch {
        }
        return ActionResult("DISPATCH_ERROR", true, e.Message, source)
    }
    fallCode := "OK_DEFER"
    if (!IsObject(parsed) || !parsed.Has("ok") || !parsed["ok"]) {
        code := ""
        try code := parsed["code"]
        catch {
            code := "EMPTY"
        }
        fallCode := code != "" ? code : "EMPTY"
        try RimLog("WARN", "ActionParse " . fallCode . " src=" . source . " raw=" . SubStr(String(action), 1, 80))
        catch {
        }
    } else {
        disp := ""
        try {
            disp := ActionDispatch(parsed, actionArg)
        } catch Error as e {
            ; 分发异常: 记录并结束, 不下坠 Body (止血点)
            try RimLog("ERROR", "ActionDispatch throw src=" . source . " raw=" . SubStr(String(action), 1, 80), e)
            catch {
            }
            return ActionResult("DISPATCH_ERROR", true, e.Message, source)
        }
        code := ""
        try code := disp["code"]
        catch {
        }
        if (code = "OK" || code = "HANDLER_FAIL")
            return ActionResult(code, true, disp.Has("msg") ? disp["msg"] : "", source)
        fallCode := code != "" ? code : "OK_DEFER"
    }
    try {
        global g_LogSid
        if (IsSet(g_LogSid) && g_LogSid)
            LogTrace(g_LogSid, "exec", SubStr(String(action), 1, 60))
    } catch {
    }
    ExecuteAction_Body(action, actionArg, depth)
    return ActionResult(fallCode, true, "", source)
}

; command|id 与裸 ID 的 RimCommand 分发合流点 (原两处手写 IsSet+Registry.Has, 现收敛一处)
ExecuteCommandId(id, actionArg := "") {
    if (IsSet(RimCommand) && IsObject(RimCommand) && RimCommand.Registry.Has(id)) {
        RimCommand.Execute(id, actionArg)
        return true
    }
    return false
}

ExecuteAction_Body(action := "", actionArg := "", depth := 0) {
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
    ; wshkey| 旧动作兼容: 与 key| 同义直通 (SendLevel 差异可忽略, 老行不断功能)
    else if (SubStr(action, 1, 7) = "wshkey|") {
        Send(SubStr(action, 8))
    }
    else if (SubStr(action, 1, 4) = "dir|") {
        OpenPath(SubStr(action, 5))
    }
    else if (SubStr(action, 1, 4) = "cmd|") {
        RunWithCmd(SubStr(action, 5))
    }
    else if (SubStr(action, 1, 8) = "command|") {
        if (!ExecuteCommandId(SubStr(action, 9), actionArg))
            ExecuteAction(SubStr(action, 9), actionArg, "", depth + 1)
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
    ; function|/combo| 已收归 ActionDispatch (统一入口先行), Body 不再重复实现;
    ; 残缺子集 (未走统一入口的直调) 落到 else 按裸名处理
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
            } catch Error as e1 {
                try %fn%()
                catch Error as e2 {
                    try RimTryLog("ExecuteAction.Body:" . fn, e2, action)
                    catch {
                    }
                    try RimLog("EXEC_FAILED", action . " fn=" . fn . " argErr=" . e1.Message, e2)
                    catch {
                    }
                }
                return
            }
        }
        try %fn%()
        catch as e {
            try RimLog("EXEC_FAILED", action . " fn=" . fn, e)
            catch {
            }
        }
    }
}

; 显示当前参数 (原版 Core 插件 ShowArg)
ShowArg() {
    global g_Arg, FullPipeArg
    msg := T("arg.head") . " " . g_Arg
    if (FullPipeArg != "")
        msg .= "`n" . T("arg.pipehead") . "`n" FullPipeArg
    DisplayResult(msg)
}

; 获取所有函数命令 (F1 Help 用; Registry Kind=function 行, 与旧池行输出同形)
GetAllFunctions() {
    result := ""
    try {
        if (IsSet(RimCommand) && IsObject(RimCommand)) {
            for id, cmd in RimCommand.Registry {
                try {
                    if (StrLower(cmd.Kind) != "function")
                        continue
                    row := RimCommand.SearchRow(cmd)
                    line := "* | " . row["show"]
                    if (!InStr(result, line "`n"))
                        result .= line "`n"
                } catch {
                }
            }
        }
    } catch {
    }
    result := StrReplace(result, "function | ", TypeLabel("function"))
    return AlignText(result)
}
