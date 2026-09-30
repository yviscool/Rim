#Requires AutoHotkey v2.0
#Warn All, Off

; Rank 上限探针: [Rank] 超 600 键即淘汰到 500 (visits 升序, 排除项永生)
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_rank_cap.ahk
#Include ..\Lib\EasyIni.ahk
#Include ..\Core\SmartInputPure.ahk
#Include ..\Core\Files.ahk

global g_Fail := 0
Ck(name, cond, extra := "") {
    global g_Fail
    if (cond)
        FileAppend("PASS: " . name . "`n", "*")
    else {
        FileAppend("FAIL: " . name . (extra != "" ? " | got=[" . extra . "]" : "") . "`n", "*")
        g_Fail++
    }
}

CfgGet(sec, key, def := "") {
    return def
}

T(key, params*) {
    return key
}

RankCount() {
    n := 0
    try {
        for _k in g_AutoConf["Rank"]
            n++
    }
    return n
}

global g_AutoConf := EasyIni()
global g_ExcludedCommandsObj := Map()
global g_RankEpoch := 0

; 小表不剪
g_AutoConf.AddKey("Rank", "command | tiny", "3|20260930")
Ck("noop-small", RankPrune() = 0 && RankCount() = 1, String(RankCount()))

; 造 650 个 visits=1 老键 + 5 排除 + 1 高权重
Loop 650 {
    g_AutoConf.AddKey("Rank", "command | app" . A_Index, "1|20250101")
}
Loop 5 {
    g_AutoConf.AddKey("Rank", "command | hidden" . A_Index, "-1")
}
g_AutoConf.AddKey("Rank", "command | fav", "900|20260930")
Ck("setup-count", RankCount() = 657, String(RankCount()))

; 一次执行触发剪枝 (新键 + 剪枝同 ChangeRank 内)
ChangeRank("command | probe_trigger", false, 1)
Ck("trimmed-to-cap", RankCount() = 500, String(RankCount()))
Ck("excluded-kept", g_AutoConf.Get("Rank", "command | hidden3", "") = "-1")
Ck("fav-kept", g_AutoConf.Get("Rank", "command | fav", "") = "900|20260930")
Ck("trigger-kept", g_AutoConf.Get("Rank", "command | probe_trigger", "") != "")
Ck("oldest-evicted", g_AutoConf.Get("Rank", "command | app1", "GONE") = "GONE")
Ck("newer-kept", g_AutoConf.Get("Rank", "command | app650", "") != "")

if (g_Fail > 0) {
    FileAppend("probe-rank-cap FAIL: " . g_Fail . "`n", "*")
    ExitApp(1)
}
FileAppend("probe-rank-cap-ok`n", "*")
ExitApp(0)
