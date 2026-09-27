#Requires AutoHotkey v2.0
#Warn All, Off
; === Core/Observability.ahk - 配置与插件可观测 ===
; P2-12: scope/来源/待应用/冲突/最近失败, headless 可 dump 为文本

global g_ObsFailures := []
global g_ObsPending := Map()

ObsRecordFailure(stage, id, msg) {
    global g_ObsFailures
    g_ObsFailures.Push(Map("t", A_Now, "stage", stage, "id", id, "msg", SubStr(String(msg), 1, 200)))
    if (g_ObsFailures.Length > 30)
        g_ObsFailures.RemoveAt(1)
    try RimLog("WARN", "OBS_FAIL stage=" . stage . " id=" . id . " " . msg)
}

ObsSetPending(sec, key, val) {
    global g_ObsPending
    g_ObsPending[sec . Chr(1) . key] := val
}

ObsClearPending(sec, key) {
    global g_ObsPending
    try g_ObsPending.Delete(sec . Chr(1) . key)
}

ObsDump() {
    out := "=== Observability Dump ===`n"
    out .= "--- Config scopes ---`n"
    try {
        for _, spec in g_CfgSchema {
            val := ""
            try val := CfgGet(spec["sec"], spec["key"], "")
            scope := spec.Has("scope") ? spec["scope"] : "restart"
            out .= spec["sec"] . "." . spec["key"] . " = " . val . " [" . scope . "]`n"
        }
    }
    out .= "--- Pending ---`n"
    try {
        global g_ObsPending
        for sk, v in g_ObsPending
            out .= sk . " -> " . v . "`n"
    }
    out .= "--- Plugin conflicts ---`n"
    try {
        rep := PluginConflicts()
        for _, c in rep
            out .= c["type"] . ": " . c["id"] . " by " . c["a"] . " vs " . c["b"] . "`n"
    }
    out .= "--- Recent failures ---`n"
    try {
        global g_ObsFailures
        for _, f in g_ObsFailures
            out .= f["t"] . " " . f["stage"] . " " . f["id"] . " " . f["msg"] . "`n"
    }
    return out
}
