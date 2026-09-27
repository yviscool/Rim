#Requires AutoHotkey v2.0
#Warn All, Off
; === Core/Logging.ahk - 日志与诊断基础设施 ===
; P1-7: 等级+分类+会话ID+轮转; 生产默认 INFO; 输入/剪贴板正文永不落盘
; 单链: LogTrace_Begin() -> id 全程透传 capture/recognize/select/execute

global g_LogSession := 0
global g_LogCat := Map()

; trace 总闸: 仅 DebugMode=1 落盘 (生产零开销, 调试才有单链).
; 探针/早期无 CfgGet 时一律关闭.
LogTraceOn() {
    try {
        return CfgGet("Config", "DebugMode", "0") = "1"
    } catch {
    }
    return false
}

LogTrace_Begin(label := "") {
    global g_LogSession
    if (!LogTraceOn())
        return 0
    g_LogSession++
    sid := g_LogSession
    try RimLog("INFO", "TRACE_BEGIN sid=" . sid . " " . label)
    return sid
}

LogTrace(sid, cat, msg) {
    if (!sid || !LogTraceOn())
        return
    line := "sid=" . sid . " cat=" . cat . " " . msg
    try RimLog("INFO", line)
}

LogRedact(s) {
    s := String(s)
    if (StrLen(s) > 120)
        s := SubStr(s, 1, 120) . "...[trunc]"
    return s
}

LogInputSafe(kind, meta) {
    try RimLog("DEBUG", "input kind=" . kind . " " . LogRedact(meta))
}
