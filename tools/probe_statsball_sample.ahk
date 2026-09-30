#Requires AutoHotkey v2.0
#Warn All, Off
; R2-4 回归: StatsBall 分层采样.
; 运行: Sample/SampleNet 快照形态 (6 字段数值) + 节流复用 + Merge 不碰共享缓存;
; 静态: Tick 全量 1s 门控 + 网速快车道并入, TopProcs 唯一调用点在 RefreshPanel (面板+5s).
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_statsball_sample.ahk

#Include ..\Core\Common.ahk
#Include ..\Core\Utils.ahk
#Include ..\Plugins\StatsBall.Sample.ahk

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

IsNum(v) {
    return (Type(v) = "Integer" || Type(v) = "Float")
}

s1 := StatsBall_Sample()
Ck("sample-shape", IsObject(s1) && s1.HasProp("cpu") && s1.HasProp("memPct") && s1.HasProp("dn") && s1.HasProp("up"), Type(s1))
Ck("sample-nums", IsNum(s1.cpu) && IsNum(s1.memPct) && IsNum(s1.dn) && IsNum(s1.up), s1.cpu . "/" . s1.memPct)
s2 := StatsBall_Sample()
Ck("sample-throttle-same", s2.cpu = s1.cpu && s2.memPct = s1.memPct, "")

n1 := StatsBall_SampleNet()
Ck("net-shape", IsObject(n1) && n1.HasProp("up") && n1.HasProp("dn"), Type(n1))
Ck("net-nums", IsNum(n1.up) && IsNum(n1.dn), String(n1.up) . "/" . String(n1.dn))
n2 := StatsBall_SampleNet()
Ck("net-throttle-same", n2.up = n1.up && n2.dn = n1.dn, "")

m := StatsBall_MergeSample(s1, n1)
Ck("merge-shape", IsObject(m) && m.cpu = s1.cpu && m.memPct = s1.memPct && m.up = n1.up && m.dn = n1.dn, "")
Ck("merge-fresh", m !== s1, "")

ballSrc := FileRead(A_ScriptDir . "\..\Plugins\StatsBall.ahk", "UTF-8")
Ck("tick-full-gate", InStr(ballSrc, "lastFullTick") > 0 && InStr(ballSrc, "A_TickCount - this.lastFullTick >= 1000") > 0, "")
Ck("tick-net-merge", InStr(ballSrc, "StatsBall_MergeSample(s, n)") > 0, "")
p1 := InStr(ballSrc, "StatsBall_TopProcs(")
p2 := p1 > 0 ? InStr(ballSrc, "StatsBall_TopProcs(", false, p1 + 1) : -1
Ck("topprocs-single-site", p1 > 0 && p2 = 0, "p1=" . p1 . " p2=" . p2)
rp := InStr(ballSrc, "RefreshPanel(s) {")
Ck("topprocs-in-panel", rp > 0 && p1 > rp, "")
Ck("topprocs-5s", InStr(ballSrc, "A_TickCount - this.lastTopTick >= 5000") > 0, "")
pollSrc := FileRead(A_ScriptDir . "\..\Core\Gesture\Hook.ahk", "UTF-8")
Ck("poll-clamp", InStr(pollSrc, "pollInterval := 20") > 0 && InStr(pollSrc, "Min(cfgPoll, 120)") > 0, "")
Ck("poll-selfstop", InStr(pollSrc, "SetTimer(GestureHook_PollTimer, 0)") > 0, "")
gestSrc := FileRead(A_ScriptDir . "\..\Core\Gesture.ahk", "UTF-8")
Ck("poll-default-20", InStr(gestSrc, '"poll", 20') > 0, "")

if (g_Fail > 0) {
    FileAppend("probe-statsball-sample FAIL: " . g_Fail . "`n", "*")
    ExitApp(1)
}
FileAppend("probe-statsball-sample-ok`n", "*", "UTF-8")
ExitApp(0)
