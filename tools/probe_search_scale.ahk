#Requires AutoHotkey v2.0
#Warn All, Off
; R2-2 回归: 1 万条池下索引与全量扫描行为一致 + 耗时对比.
; 一致性: 索引/forceFull 的 idline 序列逐项相等 (默认开关; 开关查询同样比).
; 性能: 选择性查询索引 P95 必须显著低于全量; 打印 avg/P50/P95 供基线存档.
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_search_scale.ahk

#Include ..\Core\Command.ahk
#Include ..\Core\SmartInputPure.ahk
#Include ..\Core\Search.ahk

global g_CommandAlias := Map()
global g_EnableTCMatch := false
global g_ExcludedCommandsObj := Map()
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

T(key, params*) {
    return key
}

TypeLabel(type) {
    return type
}

CfgGet(sec, key, def := "") {
    return def
}

Qpc() {
    t := 0
    DllCall("kernel32\QueryPerformanceCounter", "Int64*", &t)
    return t
}

QpcFreq() {
    f := 0
    DllCall("kernel32\QueryPerformanceFrequency", "Int64*", &f)
    return f
}

IdLines(items) {
    out := []
    for _, mi in items
        out.Push(mi["idline"])
    return out
}

SameSeq(a, b) {
    if (a.Length != b.Length)
        return false
    i := 1
    while (i <= a.Length) {
        if (a[i] != b[i])
            return false
        i++
    }
    return true
}

StatsOf(samples, freq) {
    n := samples.Length
    total := 0
    for _, v in samples
        total += v
    try {
        samples.Sort((a, b) => a - b)
    } catch {
    }
    p50 := samples[n // 2]
    p95 := samples[n * 95 // 100]
    return Map("avg", total // n, "p50", p50, "p95", p95)
}

Bench(query, reps, freq, label) {
    ; 预热 (索引构建 + 行缓存, 不计入)
    SearchCollectMatches(query)
    SearchCollectMatches(query, false, false, true)
    idx := []
    ful := []
    i := 0
    while (i < reps) {
        t0 := Qpc()
        SearchCollectMatches(query)
        t1 := Qpc()
        idx.Push((t1 - t0) * 1000000 // freq)
        t0 := Qpc()
        SearchCollectMatches(query, false, false, true)
        t1 := Qpc()
        ful.Push((t1 - t0) * 1000000 // freq)
        i++
    }
    si := StatsOf(idx, freq)
    sf := StatsOf(ful, freq)
    FileAppend("INFO: " . label . " idx avg=" . si["avg"] . "us p50=" . si["p50"] . "us p95=" . si["p95"]
        . "us | full avg=" . sf["avg"] . "us p50=" . sf["p50"] . "us p95=" . sf["p95"] . "us`n", "*")
    return Map("idx", si, "full", sf)
}

; ---- 建池 1 万条 ----
Loop 10000 {
    RimCommand.IngestRow("file | C:\SynthScale\app" . A_Index . ".exe")
}
RimCommand.IngestRow("file | D:\software\Weixin\Weixin.exe")
RimCommand.IngestRow("url | https://www.google.com/search?q=test | Google")
FileAppend("INFO: registry=" . RimCommand.Registry.Count . " seq=" . RimCommand.Seq . "`n", "*")
Ck("pool-10k", RimCommand.Registry.Count >= 10000, String(RimCommand.Registry.Count))

; ---- 一致性 ----
for _, q in ["weixin", "goo", "app9999", "zxq_nothing_here", "e", "app1", "Google koa.js"] {
    a := IdLines(SearchCollectMatches(q))
    b := IdLines(SearchCollectMatches(q, false, false, true))
    Ck("parity-" . q, SameSeq(a, b), "idx=" . a.Length . " full=" . b.Length)
}
a := IdLines(SearchCollectMatches("weixin", true, true))
b := IdLines(SearchCollectMatches("weixin", true, true, true))
Ck("parity-switches", SameSeq(a, b), "n=" . a.Length)
Ck("weixin-hit", IdLines(SearchCollectMatches("weixin")).Length >= 1, "")

; ---- 耗时对比 ----
freq := QpcFreq()
r1 := Bench("weixin", 15, freq, "q=weixin")
Ck("perf-weixin-idx-faster", r1["idx"]["p95"] < r1["full"]["p50"], "idxp95=" . r1["idx"]["p95"] . " fullp50=" . r1["full"]["p50"])
Ck("perf-weixin-idx-sane", r1["idx"]["p95"] < 20000, String(r1["idx"]["p95"]))
r2 := Bench("app9999", 15, freq, "q=app9999")
Ck("perf-app9999-idx-faster", r2["idx"]["p95"] < r2["full"]["p50"], "idxp95=" . r2["idx"]["p95"] . " fullp50=" . r2["full"]["p50"])
r3 := Bench("zxq_nothing_here", 15, freq, "q=miss")
Ck("perf-miss-sane", r3["idx"]["p95"] < 20000, String(r3["idx"]["p95"]))

if (g_Fail > 0) {
    FileAppend("probe-search-scale FAIL: " . g_Fail . "`n", "*")
    ExitApp(1)
}
FileAppend("probe-search-scale-ok`n", "*")
ExitApp(0)
