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
    tempFileName := "Rim.stdout.log"
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
        catch {
        }
        if (usage != "") {
            try DisplayResult(usage)
            catch {
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
; 会无界递归; 深度超 10 直接丢弃并记日志 (调用链见日志 action 字段)
; 统一入口: 先经 ActionDispatch 真执行 (command/function/legacy/combo),
; OK/HANDLER_FAIL 表示分发层已接管 (执行或记死), 不再重进 Body;
; OK_DEFER/UNKNOWN_COMMAND/解析失败才落到 ExecuteAction_Body (前缀处理器 + run/file/key 等 + 递归)
ExecuteAction(action := "", actionArg := "", source := "") {
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
        try {
            parsed := ActionParse(action, source)
            if (!parsed["ok"]) {
                try RimLog("WARN", "ActionParse " . parsed["code"] . " src=" . source . " raw=" . SubStr(String(action), 1, 80))
                catch {
                }
; 统一入口: 先经 ActionDispatch 真执行.
; 只有 OK (已执行) / HANDLER_FAIL (已接管, 含记死) 才跳过 Body;
; OK_DEFER (run|file|key|dir|cmd|url 无人可接) 与 UNKNOWN_COMMAND 必须落到 Body,
; ok=true 不等于已执行, 错判则文件/网址/按键静默死亡 (血泪).
            } else {
                disp := ActionDispatch(parsed, actionArg)
                code := ""
                try code := disp["code"]
                catch {
                }
                if (code = "OK" || code = "HANDLER_FAIL")
                    return
            }
        } catch {
        }
        try {
            global g_LogSid
            if (IsSet(g_LogSid) && g_LogSid)
                LogTrace(g_LogSid, "exec", SubStr(String(action), 1, 60))
        }
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
            } catch {
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
