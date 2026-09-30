#Requires AutoHotkey v2.0
#Warn All, Off

; 启动分段门禁: 解析 Rim.error.log 最后一个 RESTART 块的 BootMark 行,
; 断言分段顺序 + 宽松预算 (本地 578~968ms 实测, 门禁按 5s/3s 防 CI 抖动).
; 无日志/无新分段 → SKIP exit 0 (CI fresh checkout 无 error.log, 它被 gitignore).
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_startup_marks.ahk

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

logPath := A_ScriptDir . "\..\Rim.error.log"
if (!FileExist(logPath)) {
    FileAppend("SKIP: no Rim.error.log`n", "*")
    FileAppend("probe-startup-marks-skip`n", "*")
    ExitApp(0)
}
content := ""
try content := FileRead(logPath, "UTF-8")
catch {
    FileAppend("SKIP: unreadable log`n", "*")
    ExitApp(0)
}
; 取最后一个 RESTART 块
blocks := StrSplit(content, "RESTART begin")
lastBlk := Trim(blocks[blocks.Length])
if (!InStr(lastBlk, "STARTUP begin")) {
    FileAppend("SKIP: no STARTUP block`n", "*")
    ExitApp(0)
}
marks := ["STARTUP begin", "STARTUP config-ok", "STARTUP files-loaded", "STARTUP gui-shown"
    , "STARTUP keymaps-ready", "STARTUP vimcheck-ready", "STARTUP gestures-ready", "STARTUP plugins-ready"]
times := Map()
for _, mk in marks {
    pos := InStr(lastBlk, "+" , 1)
    found := ""
    Loop Parse, lastBlk, "`n", "`r" {
        fld := Trim(A_LoopField)
        if (InStr(fld, mk) > 0 && RegExMatch(fld, "\+(\d+)ms", &m)) {
            found := m[1]
        }
    }
    if (found != "")
        times[mk] := Integer(found)
}
if (!times.Has("STARTUP files-loaded")) {
    FileAppend("SKIP: old marks (pre-segment binary), rerun app to populate`n", "*")
    ExitApp(0)
}
; 顺序断言
order := ["STARTUP begin", "STARTUP config-ok", "STARTUP files-loaded", "STARTUP gui-shown"
    , "STARTUP keymaps-ready", "STARTUP vimcheck-ready", "STARTUP gestures-ready", "STARTUP plugins-ready"]
prev := -1
seqOk := true
for _, mk in order {
    if (!times.Has(mk)) {
        seqOk := false
        break
    }
    if (times[mk] < prev) {
        seqOk := false
        break
    }
    prev := times[mk]
}
Ck("marks-order", seqOk)
segLine := ""
for _, mk in order
    segLine .= mk . "=" . (times.Has(mk) ? times[mk] : "?") . "ms "
FileAppend("INFO: " . segLine . "`n", "*")
total := times["STARTUP plugins-ready"]
Ck("total-budget", total < 5000, String(total))
Ck("files-budget", times["STARTUP files-loaded"] < 3000, String(times["STARTUP files-loaded"]))
Ck("keymaps-segment", (times["STARTUP vimcheck-ready"] - times["STARTUP gui-shown"]) < 3000
    , String(times["STARTUP vimcheck-ready"] - times["STARTUP gui-shown"]))

if (g_Fail > 0) {
    FileAppend("probe-startup-marks FAIL: " . g_Fail . "`n", "*")
    ExitApp(1)
}
FileAppend("probe-startup-marks-ok`n", "*")
ExitApp(0)
