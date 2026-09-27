#Requires AutoHotkey v2.0
#Warn All, Off
; P9: 窗口/上下文索引探针 (分层索引+HWND缓存+失效+无类窗不钩)

T(key, *) => key
RimLog(level, msg, err := "") {
    return
}

#Include ..\Core\WindowIndex.ahk

fails := []
Check(name, cond) {
    global fails
    if (!cond)
        fails.Push(name)
}

class FakeWin {
    WinFile := ""
    WinClass := ""
}

class FakeEngine {
    WinList := ""
}

Main() {
    global fails, g_WinIdx, g_CtxCache
    eng := FakeEngine()
    eng.WinList := Map()
    w1 := FakeWin()
    w1.WinFile := "notepad.exe"
    w1.WinClass := "Notepad"
    eng.WinList["notes"] := w1
    w2 := FakeWin()
    w2.WinFile := ""
    w2.WinClass := ""
    eng.WinList["dangling"] := w2
    n := WinIdx_Rebuild(eng)
    Check("rebuild-skips-classless", n = 1)
    Check("byexe", g_WinIdx["byExe"].Has("notepad.exe"))
    Check("match-exe", WinIdx_Match("NOTEPAD.EXE", "Nope", eng) = "notes")
    Check("match-class", WinIdx_Match("other.exe", "Notepad", eng) = "notes")
    Check("match-miss", WinIdx_Match("other.exe", "Nope", eng) = "")
    CtxCache_Put(12345, Map("tag", "CTX1"))
    hit := CtxCache_Get(12345)
    Check("ctx-hit", IsObject(hit) && hit["tag"] = "CTX1")
    CtxCache_Invalidate()
    Check("ctx-miss-after-invalidate", CtxCache_Get(12345) = "")
    WinIdx_Invalidate()
    Check("winidx-invalidate", g_WinIdx["built"] = 0)
    out := A_ScriptDir . "\..\probe_window_index.out.txt"
    try FileDelete(out)
    catch {
    }
    if (fails.Length > 0) {
        txt := "window-index-FAIL:`n"
        for _, x in fails
            txt .= "  - " . x . "`n"
        FileAppend(txt, out, "UTF-8")
        ExitApp(1)
    }
    FileAppend("window-index-ok`n", out, "UTF-8")
    ExitApp(0)
}

Main()
