#Requires AutoHotkey v2.0
#Warn All, Off
; P1-5: 统一动作协议探针 (结构化解析+错误码+来源+循环检测)

T(key, *) => key
global g_LastRimLog := ""
RimLog(level, msg, err := "") {
    global g_LastRimLog
    g_LastRimLog := level . "|" . msg
}

#Include ..\Core\Runtime.ahk
#Include ..\Core\ActionProtocol.ahk
#Include ..\Core\Execution.ahk

fails := []
Check(name, cond, extra := "") {
    global fails
    if (!cond)
        fails.Push(extra != "" ? name . " | got=[" . extra . "]" : name)
}

Main() {
    global fails
    a := ActionParse("run|notepad.exe", "launcher")
    Check("parse-run", a["ok"] && a["kind"] = "run" && a["target"] = "notepad.exe" && a["source"] = "launcher")
    b := ActionParse("<command|MyCmd>", "vim")
    Check("parse-angle", b["ok"] && b["kind"] = "command" && b["target"] = "MyCmd")
    c := ActionParse("", "x")
    Check("empty-code", !c["ok"] && c["code"] = "EMPTY")
    d := ActionParse("bogus|zzz", "x")
    Check("unknown-kind", !d["ok"] && d["code"] = "UNKNOWN_KIND")
    e := ActionParse("bareCommand", "hist")
    Check("bare-is-command", e["ok"] && e["kind"] = "command" && e["target"] = "bareCommand")
    f := ActionDispatch(Map("ok", false, "code", "EMPTY", "kind", "", "msg", "e"), "")
    Check("dispatch-validate-fail", !f["ok"] && f["code"] = "EMPTY")
    g := ActionDispatch(ActionParse("command|NoSuchCmd12345", "probe"), "")
    Check("unknown-command", !g["ok"] && g["code"] = "UNKNOWN_COMMAND")
    h := ActionDispatch(ActionParse("function|NoSuchFn12345", "probe"), "")
    Check("unknown-function", !h["ok"] && h["code"] = "HANDLER_FAIL")
    ; 分发层已接管死判 (记 UNKNOWN_FUNCTION, 不再下坠 Body 重试): 真执行走 probe_hist_replay
    i := ActionDispatch(ActionParse("combo|zoom", "probe"), "")
    Check("combo-defer-noengine", i["ok"] && i["code"] = "OK_DEFER")
    ; OK_DEFER 必须落到 Body 真执行 (ok=true 不等于已执行):
    ; run|/file| 指不存在目标 → Body 的 Run 抛错 → RUN_FAILED, 证明 Body 跑了.
    ; (此断言即 Weixin 回车静默死回归: 旧接线条件 disp["ok"] 直接 return, Body 永不到达)
    global g_LastRimLog
    g_LastRimLog := ""
    ExecuteAction("run|rim-nonexistent-probe-xyz123", "probe")
    Check("defer-run-body", InStr(g_LastRimLog, "RUN_FAILED") > 0 && InStr(g_LastRimLog, "rim-nonexistent-probe-xyz123") > 0, g_LastRimLog)
    g_LastRimLog := ""
    ExecuteAction("file|C:\rim-nonexistent-probe-xyz123.exe", "probe")
    Check("defer-file-body", InStr(g_LastRimLog, "RUN_FAILED") > 0, g_LastRimLog)
    ActionTracePush("run", "notepad.exe", "probe")
    Check("trace", InStr(ActionLastTrace(), "run|notepad.exe") > 0)
    ; wshkey| 旧别名不断功能 (静态锁分支存在; 真 Send 不在 headless 执行)
    execSrc := FileRead(A_ScriptDir . "\..\Core\Execution.ahk", "UTF-8")
    Check("wshkey-alias", InStr(execSrc, 'SubStr(action, 1, 7) = "wshkey|"') > 0
        && InStr(execSrc, "Send(SubStr(action, 8))") > 0)
    out := A_ScriptDir . "\..\probe_action_protocol.out.txt"
    try FileDelete(out)
    catch {
    }
    if (fails.Length > 0) {
        txt := "action-protocol-FAIL:`n"
        for _, x in fails
            txt .= "  - " . x . "`n"
        FileAppend(txt, out, "UTF-8")
        ExitApp(1)
    }
    FileAppend("action-protocol-ok`n", out, "UTF-8")
    ExitApp(0)
}

Main()
