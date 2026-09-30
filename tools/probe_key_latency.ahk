#Requires AutoHotkey v2.0
#Warn All, Off
; R2-1 回归: KeyHandler 单次 ctx 采集 + CheckWin hwnd 键控缓存.
; 1) 1000 次 CollectCtx/CheckWin 耗时 (avg/max/P95, headless 宽阈值, 只拦病态回归);
; 2) hwnd 切换不得命中旧窗缓存 (同 TTL 内换 hwnd 必须重算);
; 3) 注册表变化 (SetWin) 同 hwnd 下不得命中旧缓存 (epoch 失效);
; 4) 对话框 NN 匹配无正则化后语义不变.
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_key_latency.ahk

#Include ..\Core\Engine.ahk

fails := []
Check(name, cond, extra := "") {
    global fails
    if (!cond)
        fails.Push(extra != "" ? name . " | got=[" . extra . "]" : name)
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

Main() {
    global fails
    freq := QpcFreq()
    eng := VimEngine()

    ; ---- 1. 1000 次采集耗时 ----
    n := 1000
    samples := []
    i := 0
    while (i < n) {
        t0 := Qpc()
        ctx := EngineCollectCtx()
        t1 := Qpc()
        samples.Push((t1 - t0) * 1000000 // freq)
        i++
    }
    Check("ctx-shape", ctx.Has("hwnd") && ctx.Has("class") && ctx.Has("procName") && ctx.Has("focusNN"), "")
    total := 0
    worst := 0
    for _, v in samples {
        total += v
        if (v > worst)
            worst := v
    }
    avg := total // n
    p95 := worst
    try {
        samples.Sort((a, b) => a - b)
        p95 := samples[950]
    } catch {
    }
    FileAppend("lat-collect avg=" . avg . "us max=" . worst . "us p95=" . p95 . "us`n", "*")
    Check("ctx-avg-sane", avg < 5000, String(avg))
    Check("ctx-max-sane", worst < 50000, String(worst))

    ; ---- 2. 1000 次 CheckWin(ctx) 耗时 (缓存命中路径 0 问 WinAPI) ----
    ctxA := EngineCollectCtx()
    samples2 := []
    i := 0
    while (i < n) {
        t0 := Qpc()
        eng.CheckWin(ctxA)
        t1 := Qpc()
        samples2.Push((t1 - t0) * 1000000 // freq)
        i++
    }
    total2 := 0
    worst2 := 0
    for _, v in samples2 {
        total2 += v
        if (v > worst2)
            worst2 := v
    }
    FileAppend("lat-checkwin avg=" . (total2 // n) . "us max=" . worst2 . "us`n", "*")
    Check("checkwin-max-sane", worst2 < 50000, String(worst2))

    ; ---- 3. hwnd 切换不命中旧缓存 ----
    fakeA := Map("hwnd", 11111, "class", "NoSuchClassZZZ", "procName", "NoSuchZZZ.exe")
    Check("hwndA-global", eng.CheckWin(fakeA) = "__global__", eng.CheckWin(fakeA))
    eng.SetWin("LateWin", "LateClassZZZ", "")
    fakeB := Map("hwnd", 22222, "class", "LateClassZZZ", "procName", "Other.exe")
    Check("hwndB-latewin", eng.CheckWin(fakeB) = "LateWin", eng.CheckWin(fakeB))
    Check("hwndB-cached", eng.CheckWin(fakeB) = "LateWin", "")

    ; ---- 4. 同 hwnd 下注册表变化, epoch 失效 (旧 TTL 缓存会错回 __global__) ----
    fakeC := Map("hwnd", 33333, "class", "EpochClassZZZ", "procName", "Nope.exe")
    Check("epoch-before", eng.CheckWin(fakeC) = "__global__", eng.CheckWin(fakeC))
    eng.SetWin("EpochWin", "EpochClassZZZ", "")
    Check("epoch-after", eng.CheckWin(fakeC) = "EpochWin", eng.CheckWin(fakeC))

    ; ---- 5. 对话框 NN 语义 (无正则化后) ----
    Check("dlg-edit-nn", DialogShouldPassthrough("#32770", "Edit", "Edit1") = true, "")
    Check("dlg-combo-nn", DialogShouldPassthrough("#32770", "", "ComboBox2") = true, "")
    Check("dlg-combo-bare-nn", DialogShouldPassthrough("#32770", "", "ComboBox") = true, "")
    Check("dlg-edit-bare-nn", DialogShouldPassthrough("#32770", "", "Edit") = false, "")
    Check("dlg-other-class", DialogShouldPassthrough("Notepad", "Edit", "Edit1") = false, "")
    Check("dlg-nn-kind", _DlgNnKind("edit12", "edit") = 2 && _DlgNnKind("edit", "edit") = 1 && _DlgNnKind("edx", "edit") = 0, "")

    if (fails.Length > 0) {
        txt := "key-latency-FAIL:`n"
        for _, x in fails
            txt .= "  - " . x . "`n"
        FileAppend(txt, "*", "UTF-8")
        ExitApp(1)
    }
    FileAppend("key-latency-ok`n", "*", "UTF-8")
    ExitApp(0)
}

Main()
