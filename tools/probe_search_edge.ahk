#Requires AutoHotkey v2.0
#Warn All, Off

; 搜索/执行边缘探针: 短回退、前缀越界、空池、历史冻结、换行污染
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_search_edge.ahk
#Include ..\Core\Command.ahk
#Include ..\Core\SmartInput.ahk
#Include ..\Core\Files.ahk
#Include ..\Core\Search.ahk
#Include ..\Lib\EasyIni.ahk

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

TypeLabel(type) {
    return type
}

global g_CapResult := ""
DisplaySearchResult(result) {
    global g_CapResult
    g_CapResult := result
}

global g_ExcludedCommandsObj := Map()
global g_SkinConf := Map("HideCol2", "0", "ShowCurrentCommand", "0")
global g_FirstChar := Ord("a")
global g_DisplayRows := 11
global g_CurrentInput := ""
global g_CurrentCommand := ""
global g_CurrentCommandList := []
global g_UseFallbackCommands := false
global g_EnableTCMatch := false
global g_AutoConf := EasyIni()
global g_FallbackCommands := ["function | AhkRun | x"]
global g_HistoryCommands := []
global g_SI := Map("ghostFull", "", "ghostShown", false, "expect", "", "expectOn", false
    , "matches", [], "idx", 0, "query", "", "histOn", false, "inputHist", [])

; ---- 1. 短回退: ":" 只有 1 条回退时不越界抛错 ----
threw := false
try {
    SearchCommand(":")
} catch {
    threw := true
}
Ck("colon-short-fallback", !threw)
Ck("colon-shows-fallback", InStr(g_CapResult, "AhkRun") > 0, g_CapResult)
threw := false
try {
    SearchCommand(";")
} catch {
    threw := true
}
Ck("semi-short-fallback", !threw)

; ---- 2. 空池: 无结果走回退, 不抛错 ----
threw := false
try {
    SearchCommand("zzzqqq-no-such-cmd")
} catch {
    threw := true
}
Ck("empty-pool-no-throw", !threw)
Ck("empty-pool-fallback", g_UseFallbackCommands == true)

; ---- 3. 历史包装行冻结: DisplayHistoryCommands 把包装行设为当前命令后, 输参仍冻结 ----
RimCommand.Register("CalcX", "CalcX", (*) => 0, Map("Description", "计算器"))
g_CurrentCommand := HistPack("command | CalcX", "1 + 1")
Ck("freeze-packed", ShouldFreezeInput("CalcX 2 + 2") == true)
Ck("freeze-packed-negative", ShouldFreezeInput("Other 2") == false)

; ---- 4. 换行污染: 粘贴多行不切断 ini 行 ----
packed := HistPack("command | CalcX", "1 + 2`nrm -rf /")
Ck("pack-no-newline", !InStr(packed, "`n") && !InStr(packed, "`r"), packed)
Ck("pack-arg-kept", HistSplit(packed)["arg"] == "1 + 2 rm -rf /", HistSplit(packed)["arg"])

; ---- 5. 整句无头可退: 头也匹配不到 → 回退, 不抛错 ----
g_CurrentCommand := ""
threw := false
try {
    SearchCommand("zzzqqq yyy")
} catch {
    threw := true
}
Ck("headless-no-throw", !threw)
Ck("headless-fallback", g_UseFallbackCommands == true)

if (g_Fail > 0) {
    FileAppend("probe-search-edge FAIL: " . g_Fail . "`n", "*")
    ExitApp(1)
}
FileAppend("probe-search-edge-ok`n", "*")
ExitApp(0)
