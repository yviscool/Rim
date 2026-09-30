#Requires AutoHotkey v2.0
#Warn All, Off

; 搜索性能 + 缓存正确性: 真 SearchCommand + 2000 行合成池, 止于执行
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_search_perf.ahk
#Include ..\Core\Command.ahk
#Include ..\Core\SmartInput.ahk
#Include ..\Core\Files.ahk
#Include ..\Core\Search.ahk
#Include ..\Lib\EasyIni.ahk
#Include ..\Lib\MonsterEval.ahk
#Include ..\Lib\TCMatch.ahk

global g_CommandAlias := Map()

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
    if (sec = "Config" && key = "ShowFileExt")
        return "0"
    if (sec = "Config" && key = "SearchFullPath")
        return "0"
    if (sec = "Config" && key = "RunIfOnlyOne")
        return "0"
    if (sec = "Plugins" && key = "Misc")
        return "1"
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

EvalExpression(input) {
    return "EVAL:" . input
}

; ---- 环境 (对齐 Rim.ahk 全局) ----
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
global g_FallbackCommands := ["function | AhkRun | ahkrun"]
global g_RankEpoch := 0

; ---- 全量 ingestion (真 SearchFileList.txt) ----
content := FileRead(A_ScriptDir . "\..\Conf\SearchFileList.txt", "UTF-8")
nIng := 0
Loop Parse, content, "`n", "`r" {
    line := Trim(A_LoopField)
    if (line = "")
        continue
    RimCommand.IngestRow(line)
    nIng++
}
FileAppend("INFO: ingested=" . nIng . " registry=" . RimCommand.Registry.Count . " seq=" . RimCommand.Seq . "`n", "*")

; 直注命令 (通用指令同款: 真实分类, ClearIngested 不得误删)
RimCommand.Register("ProbeDirect", "ProbeDirect", (*) => 0, Map("Description", "direct"))
Ck("direct-registered", RimCommand.Registry.Has("ProbeDirect"))

; ---- 正确性基线 ----
g_CurrentInput := "weixin"
SearchCommand("weixin")
Ck("base-nonempty", g_CurrentCommandList.Length >= 3, String(g_CurrentCommandList.Length))
baseHead := g_CurrentCommand

; ---- 空查询缓存一致性 ----
r1 := SearchCommand("")
n1 := g_CurrentCommandList.Length
Ck("empty-nonempty", n1 > 0, String(n1))
r2 := SearchCommand("")
Ck("empty-stable-result", r2 = r1)
Ck("empty-stable-list", g_CurrentCommandList.Length = n1, String(g_CurrentCommandList.Length))
Ck("empty-stable-head", g_CurrentCommand = g_CurrentCommandList[1])

; 新行收编 + 高权重必须使空查询失效并置顶 (Seq/纪元推进端到端验证)
RimCommand.IngestRow("file | C:\__probe_new_app__.exe")
ChangeRank("command | file:C:\__probe_new_app__.exe", false, 10)
r3 := SearchCommand("")
Ck("empty-invalidated", InStr(r3, "__probe_new_app__") > 0, SubStr(r3, 1, 80))

; ---- ClearIngested: 收编行清、直注行留 ----
RimCommand.IngestRow("file | C:\__probe_delete_me__.exe")
Ck("temp-ingested", RimCommand.Registry.Has("file:C:\__probe_delete_me__.exe"))
cleared := RimCommand.ClearIngested()
Ck("clear-count", cleared > 0, String(cleared))
Ck("clear-temp-gone", !RimCommand.Registry.Has("file:C:\__probe_delete_me__.exe"))
Ck("clear-direct-kept", RimCommand.Registry.Has("ProbeDirect"))
; 重建 (模拟 LoadFiles 收编段)
Loop Parse, content, "`n", "`r" {
    line := Trim(A_LoopField)
    if (line = "")
        continue
    RimCommand.IngestRow(line)
}

; ---- frecency 缓存失效: ChangeRank 前后分数必须变 ----
s0 := RankScoreOfElement("command | ProbeDirect")
ChangeRank("command | ProbeDirect", false, 5)
s1 := RankScoreOfElement("command | ProbeDirect")
Ck("rank-bump", s1 > s0, s0 . "->" . s1)

; ---- 合成膨胀到 2000 行 ----
Loop 1700 {
    RimCommand.IngestRow("file | C:\SynthPool\app" . A_Index . ".exe")
}
FileAppend("INFO: pool2000 registry=" . RimCommand.Registry.Count . "`n", "*")
Ck("pool-2000", RimCommand.Registry.Count >= 1900, String(RimCommand.Registry.Count))

; ---- 计时 (E4 曲线 + 门禁阈值) ----
g_CurrentInput := "weixin"
t0 := A_TickCount
Loop 20 {
    SearchCommand("weixin")
}
tWeixin := A_TickCount - t0
FileAppend("INFO: weixin-20x total=" . tWeixin . "ms avg=" . Round(tWeixin / 20, 1) . "ms`n", "*")

t0 := A_TickCount
Loop 20 {
    SearchCommand("")
}
tEmpty := A_TickCount - t0
FileAppend("INFO: empty-20x total=" . tEmpty . "ms avg=" . Round(tEmpty / 20, 1) . "ms (首轮 miss, 后续命中)`n", "*")

; 无结果查询 (TryEvalInput 门控 + memo 路径)
t0 := A_TickCount
Loop 20 {
    SearchCommand("zzqxj_no_such_app_zzz")
}
tMiss := A_TickCount - t0
FileAppend("INFO: miss-20x total=" . tMiss . "ms avg=" . Round(tMiss / 20, 1) . "ms`n", "*")

Ck("perf-weixin", tWeixin < 4000, String(tWeixin))
Ck("perf-empty", tEmpty < 4000, String(tEmpty))
Ck("perf-miss", tMiss < 4000, String(tMiss))

; ---- TryEvalInput: memo 一致 + 长串拒 ----
e1 := TryEvalInput("1+2*3")
e2 := TryEvalInput("1+2*3")
Ck("eval-memo", e1 = e2 && e1 != "", e1)
; 模糊算法 (无 DLL 时 Match 直落 BuiltInMatch; 纯函数, 与配置无关)
Ck("fuzzy-sub", TCMatch.Match("goo", "Google Chrome") = true)
Ck("fuzzy-seq", TCMatch.Match("gge", "Google Chrome") = true)
Ck("fuzzy-nomatch", TCMatch.Match("zxq", "Google Chrome") = false)
Ck("fuzzy-empty-pat", TCMatch.Match("", "Google") = true)
Ck("fuzzy-empty-text", TCMatch.Match("goo", "") = false)
longStr := ""
Loop 300 {
    longStr .= "1+"
}
longStr .= "1"
Ck("eval-longcap", TryEvalInput(longStr) = "", "len=" . StrLen(longStr))
Ck("monster-cap", SubStr(String(MonsterEval(longStr)), 1, 2) = "错误")

if (g_Fail > 0) {
    FileAppend("probe-search-perf FAIL: " . g_Fail . "`n", "*")
    ExitApp(1)
}
FileAppend("probe-search-perf-ok`n", "*")
ExitApp(0)
