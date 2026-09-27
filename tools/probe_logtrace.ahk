#Requires AutoHotkey v2.0
#Warn All, Off
; LogTrace 门控探针: 仅 DebugMode=1 落盘, 生产零开销.
; 串链点 (静态断言): RunCommand 起点, ExecuteAction 续写, 手势 resolve 续写.

global g_DbgMode := "0"
global g_LogLines := []

CfgGet(sec, key, def := "") {
    global g_DbgMode
    if (sec = "Config" && key = "DebugMode")
        return g_DbgMode
    return def
}

RimLog(level, msg, err := "") {
    global g_LogLines
    g_LogLines.Push("[" . level . "] " . msg)
}

#Include ..\Core\Logging.ahk

fails := []
Check(name, cond) {
    global fails
    if (!cond)
        fails.Push(name)
}

Main() {
    global fails, g_DbgMode, g_LogLines
    g_DbgMode := "0"
    g_LogLines := []
    Check("off-begin-zero", LogTrace_Begin("x") = 0)
    Check("off-silent", g_LogLines.Length = 0)
    LogTrace(99, "c", "m")
    Check("off-log-silent", g_LogLines.Length = 0)
    g_DbgMode := "1"
    s := LogTrace_Begin("run foo")
    Check("on-begin", s = 1)
    Check("on-begin-line", InStr(g_LogLines[1], "TRACE_BEGIN sid=1 run foo") > 0)
    LogTrace(s, "exec", "url|x")
    Check("on-log", g_LogLines.Length = 2 && InStr(g_LogLines[2], "sid=1 cat=exec") > 0)
    LogTrace(0, "c", "m")
    Check("zero-sid-silent", g_LogLines.Length = 2)
    ; 接线静态断言
    execSrc := FileRead(A_ScriptDir . "\..\Core\Execution.ahk", "UTF-8")
    Check("wire-run", InStr(execSrc, 'LogTrace_Begin("run "') > 0)
    Check("wire-exec", InStr(execSrc, 'LogTrace(g_LogSid, "exec"') > 0)
    engSrc := FileRead(A_ScriptDir . "\..\Core\Gesture\Engine.ahk", "UTF-8")
    Check("wire-gesture", InStr(engSrc, 'LogTrace_Begin("gesture "') > 0)
    out := A_ScriptDir . "\..\probe_logtrace.out.txt"
    try FileDelete(out)
    catch {
    }
    if (fails.Length > 0) {
        txt := "logtrace-FAIL:`n"
        for _, x in fails
            txt .= "  - " . x . "`n"
        FileAppend(txt, out, "UTF-8")
        ExitApp(1)
    }
    FileAppend("logtrace-ok`n", out, "UTF-8")
    ExitApp(0)
}

Main()
