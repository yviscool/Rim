#Requires AutoHotkey v2.0
#Warn All, Off
; P1-5: 统一动作协议探针 (结构化解析+错误码+来源+循环检测)

T(key, *) => key
RimLog(level, msg, err := "") {
    return
}

#Include ..\Core\ActionProtocol.ahk

fails := []
Check(name, cond) {
    global fails
    if (!cond)
        fails.Push(name)
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
    Check("unknown-function", !h["ok"] && h["code"] = "UNKNOWN_COMMAND")
    ActionTracePush("run", "notepad.exe", "probe")
    Check("trace", InStr(ActionLastTrace(), "run|notepad.exe") > 0)
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
