#Requires AutoHotkey v2.0
#Warn All, Off
; P2-12: 可观测探针 (scope/来源/待应用/冲突/失败 dump)

T(key, *) => key
RimLog(level, msg, err := "") {
    return
}

global g_Conf := Map()
global g_CfgSchema := [Map("sec", "Config", "key", "SaveHistory", "type", "bool", "default", "1", "scope", "live")]
CfgGet(sec, key, def := "") {
    return "1"
}
CfgScope(sec, key) {
    return "live"
}
PluginConflicts() {
    return [Map("type", "command", "id", "MyCmd", "a", "A", "b", "B")]
}

#Include ..\Core\Observability.ahk

fails := []
Check(name, cond) {
    global fails
    if (!cond)
        fails.Push(name)
}

Main() {
    global fails
    ObsRecordFailure("gesture", "R", "test fail")
    ObsSetPending("Config", "SaveHistory", "0")
    d := ObsDump()
    Check("dump-scope", InStr(d, "Config.SaveHistory") > 0 && InStr(d, "[live]") > 0)
    Check("dump-pending", InStr(d, "Pending") > 0)
    Check("dump-conflict", InStr(d, "MyCmd") > 0)
    Check("dump-failure", InStr(d, "test fail") > 0)
    ObsClearPending("Config", "SaveHistory")
    d2 := ObsDump()
    Check("pending-cleared", !InStr(d2, "SaveHistory") || InStr(d2, "Pending") > 0)
    out := A_ScriptDir . "\..\probe_observability.out.txt"
    try FileDelete(out)
    catch {
    }
    if (fails.Length > 0) {
        txt := "observability-FAIL:`n"
        for _, x in fails
            txt .= "  - " . x . "`n"
        FileAppend(txt, out, "UTF-8")
        ExitApp(1)
    }
    FileAppend("observability-ok`n", out, "UTF-8")
    ExitApp(0)
}

Main()
