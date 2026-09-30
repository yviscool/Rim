#Requires AutoHotkey v2.0
#Warn All, Off
; Phase1 止血回归: 分发异常/已接管绝不执行 Body (防重复执行/静默失败)
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_exec_dispatch_error.ahk

T(key, *) => key
global g_LogLines := []
RimLog(level, msg, err := "") {
    global g_LogLines
    line := level . "|" . msg
    if (IsObject(err)) {
        try line .= ": " . err.Message
        catch {
        }
    } else if (err != "")
        line .= " " . err
    g_LogLines.Push(line)
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

HasLog(substr) {
    global g_LogLines
    for _, line in g_LogLines
        if (InStr(line, substr) > 0)
            return true
    return false
}

Main() {
    global fails, g_LogLines
    ; 1. function| 未知函数: 分发层记 UNKNOWN_FUNCTION 判死 (HANDLER_FAIL), 不得下坠 Body
    ;    (Body 的裸名直调会再记 EXEC_FAILED; 出现即重复执行证据)
    g_LogLines := []
    r1 := ExecuteAction("function|NoSuchFn_ZZZ999", "", "probe")
    Check("unknown-fn-code", r1["code"] = "HANDLER_FAIL", r1["code"])
    Check("unknown-fn-logged", HasLog("UNKNOWN_FUNCTION"), "")
    Check("unknown-fn-no-body", !HasLog("EXEC_FAILED"), "")

    ; 2. run| 不存在目标: OK_DEFER 必须下坠 Body, Body 的 Run 抛错记 RUN_FAILED
    g_LogLines := []
    r2 := ExecuteAction("run|rim-nonexistent-probe-xyz123", "", "probe")
    Check("defer-code", r2["code"] = "OK_DEFER", r2["code"])
    Check("defer-body-ran", HasLog("RUN_FAILED"), "")

    ; 3. 返回值形态: Map{code,...}
    g_LogLines := []
    r3 := ExecuteAction("function|NoSuchFn_ZZZ999", "", "probe")
    Check("result-shape", IsObject(r3) && r3.Has("code") && r3["code"] = "HANDLER_FAIL", IsObject(r3) ? String(r3.Has("code") ? r3["code"] : "?") : "noobj")
    Check("result-no-body", !HasLog("EXEC_FAILED"), "")

    ; 4. 递归守卫: 自指 command| 深度超限返回 RECURSION 而非栈爆
    g_LogLines := []
    r4 := ExecuteAction("command|self", "", "probe", 11)
    Check("recursion-guard", r4["code"] = "RECURSION", r4["code"])

    if (fails.Length > 0) {
        txt := "exec-dispatch-error-FAIL:`n"
        for _, x in fails
            txt .= "  - " . x . "`n"
        FileAppend(txt, "*", "UTF-8")
        ExitApp(1)
    }
    FileAppend("exec-dispatch-error-ok`n", "*", "UTF-8")
    ExitApp(0)
}

Main()
