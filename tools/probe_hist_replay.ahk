#Requires AutoHotkey v2.0
#Warn All, Off

; 回放探针: 真 RunCommand + 真 ExecuteAction + 真 RimCommand 分发, 桩仅在叶子
; 锁死 B bug: 回放 command|...|30 必须带上 30 执行, 不受输入框残留污染
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_hist_replay.ahk
#Include ..\Core\Command.ahk
#Include ..\Core\SmartInputPure.ahk
#Include ..\Core\ActionProtocol.ahk
#Include ..\Core\Execution.ahk

global g_ProbeFail := 0
global g_CapArg := "__unset__"
global g_CapId := ""

ProbeCheck(name, cond, extra := "") {
    global g_ProbeFail
    if (cond) {
        FileAppend("PASS: " . name . "`n", "*")
    } else {
        msg := "FAIL: " . name
        if (extra != "")
            msg .= " | got=[" . extra . "]"
        FileAppend(msg . "`n", "*")
        g_ProbeFail++
    }
}

; ---- 桩 (皆不在引用文件内, 无重定义冲突) ----
CfgGet(sec, key, def := "") {
    if (key = "SaveHistory")
        return "1"
    if (key = "HistorySize")
        return "100"
    if (key = "AutoRank")
        return "0"
    if (key = "RunOnce")
        return "0"
    if (key = "KeepInputText")
        return "1"
    return def
}

ChangeRank(cmd, show := false, inc := 1) {
}

SI_NoteInput(input) {
}

LogTrace_Begin(desc) {
    return 0
}

RimLog(level, msg, err := "") {
}

; 与 Core/Hotkeys.Commands.ahk ParseArg 同语义的桩 (管道/前缀/空格取参)
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

; 捕获分发: 记录 RimCommand 真分发拿到的 id 与 arg
CapCmd(arg := "") {
    global g_CapArg, g_CapId
    g_CapId := "hit"
    g_CapArg := arg
}

; ---- 环境 ----
global g_HistoryCommands := []
global g_CurrentInput := "", g_Arg := "", g_PipeArg := "", g_UseFallbackCommands := false
global g_UseDisplay := false, g_DisableAutoExit := false, g_ExecInterval := 0
global g_LastExecLabel := "", g_LastExecCb := "", FullPipeArg := ""
global g_LogSid := 0

RimCommand.Register("ShutdownTimer", "ShutdownTimer", CapCmd, Map("Category", "System", "Description", "x"))
RimCommand.Register("ShowIp", "ShowIp", CapCmd, Map("Category", "System", "Description", "y"))

; ---- 1. 新鲜执行: 输入框参数进真分发与历史 ----
g_CurrentInput := "ShutdownTimer 30"
RunCommand("command | ShutdownTimer | 定时关机")
ProbeCheck("fresh-dispatched", g_CapId == "hit", g_CapId)
ProbeCheck("fresh-arg", g_CapArg == "30", g_CapArg)
rec1 := HistSplit(g_HistoryCommands[1])
ProbeCheck("fresh-hist-el", rec1["el"] == "command | ShutdownTimer | 定时关机", rec1["el"])
ProbeCheck("fresh-hist-arg", rec1["arg"] == "30", rec1["arg"])

; ---- 2. 回放: 输入框残留不可信, 记录参数权威 (B bug 锁死点) ----
g_CapId := ""
g_CapArg := "__unset__"
g_CurrentInput := "shut"
RunCommand(g_HistoryCommands[1])
ProbeCheck("replay-dispatched", g_CapId == "hit", g_CapId)
ProbeCheck("replay-arg-authoritative", g_CapArg == "30", g_CapArg)
rec2 := HistSplit(g_HistoryCommands[1])
ProbeCheck("replay-hist-stable", rec2["el"] == "command | ShutdownTimer | 定时关机" && rec2["arg"] == "30", g_HistoryCommands[1])

; ---- 3. 无参命令往返干净 ----
g_CapArg := "__unset__"
g_CurrentInput := "ShowIp"
RunCommand("command | ShowIp | 本机IP")
ProbeCheck("bare-arg", g_CapArg == "", g_CapArg)
ProbeCheck("bare-hist-nopack", HistSplit(g_HistoryCommands[1])["has"] == false, g_HistoryCommands[1])

if (g_ProbeFail > 0) {
    FileAppend("probe-hist-replay FAIL: " . g_ProbeFail . "`n", "*")
    ExitApp(1)
}
FileAppend("probe-hist-replay-ok`n", "*")
ExitApp(0)
