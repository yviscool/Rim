#Requires AutoHotkey v2.0
#Warn All, Off

; process 系探针: WMI 枚举 + KillProcess 真杀 (一次性进程, 有用户进程则跳过杀戮) + ShowProcess 形状
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_process.ahk
#Include ..\Core\Plugin.ahk
#Include ..\Plugins\LauncherSystem.ahk

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

global g_CapDisplay := ""
DisplayResult(text := "") {
    global g_CapDisplay
    g_CapDisplay := text
}

SetCommandFilter(cmd) {
}

TurnOnResultFilter() {
}

TurnOnRealtimeExec() {
}

AlignText(t) {
    return t
}

FilterResult(text, needle) {
    if (Trim(String(needle)) = "")
        return text
    result := ""
    Loop Parse, text, "`n", "`r" {
        if (!InStr(A_LoopField, " | ") && InStr(A_LoopField, needle))
            result .= A_LoopField "`n"
        else if (InStr(StrReplace(SubStr(A_LoopField, 5), "\", " "), needle))
            result .= A_LoopField "`n"
    }
    return result
}

; Sort 用内建 (v2 有 Sort() 行排序; 曾在此处手写冒泡桩 shadow 内建并抛错, 已删)

; ---- 1. WMI 进程枚举 ----
procs := []
try {
    for p in ComObjGet("winmgmts:").ExecQuery("select * from Win32_Process") {
        procs.Push(p.Name)
        if (procs.Length >= 5)
            break
    }
} catch as e {
    FileAppend("FAIL: wmi-query | got=[" . e.Message . "]`n", "*")
    global g_Fail
    g_Fail++
}
Ck("wmi-query", procs.Length > 0, String(procs.Length))

; ---- 2. ListProcess 全链 (桩显示层, 真 WMI, 计时) ----
global g_Arg := ""
t0 := A_TickCount
try {
    ListProcess()
    dt := A_TickCount - t0
    FileAppend("INFO: ListProcess took " . dt . "ms, outlen=" . StrLen(g_CapDisplay) . "`n", "*")
    Ck("listprocess-shows", InStr(g_CapDisplay, "AutoHotkey") > 0 || InStr(g_CapDisplay, "explorer") > 0 || StrLen(g_CapDisplay) > 100, SubStr(g_CapDisplay, 1, 60))
} catch as e {
    Ck("listprocess-no-throw", false, e.Message . " @ " . e.File . ":" . e.Line)
}

; ---- 3. KillProcess 真杀一次性记事本 (用户若开着记事本则跳过) ----
before := []
try {
    for p in ComObjGet("winmgmts:").ExecQuery("select ProcessId from Win32_Process where Name='notepad.exe'") {
        try before.Push(p.ProcessId)
        catch {
        }
    }
} catch {
}
if (before.Length = 0) {
    Run("notepad.exe")
    Sleep(1200)
    mine := 0
    try {
        for p in ComObjGet("winmgmts:").ExecQuery("select ProcessId from Win32_Process where Name='notepad.exe'") {
            try {
                mine := p.ProcessId
                break
            } catch {
            }
        }
    } catch {
    }
    Ck("sacrificial-up", mine != 0, String(mine))
    if (mine != 0) {
        global g_Arg := String(mine)
        try {
            KillProcess()
            Ck("killprocess-display", InStr(g_CapDisplay, "kill", false) > 0, SubStr(g_CapDisplay, 1, 60))
        } catch as e {
            Ck("killprocess-no-throw", false, e.Message)
        }
        Sleep(1200)
        gone := true
        try {
            for p in ComObjGet("winmgmts:").ExecQuery("select ProcessId from Win32_Process where Name='notepad.exe'") {
                try {
                    if (p.ProcessId = mine)
                        gone := false
                } catch {
                }
            }
        } catch {
        }
        Ck("killprocess-killed", gone)
    }
} else {
    FileAppend("SKIP: killprocess-killed (user has notepad open, refusing collateral)`n", "*")
}

; ---- 4. ShowProcess 形状 ----
global g_Arg := "explorer.exe"
try {
    ShowProcess()
    Ck("showprocess-shape", InStr(g_CapDisplay, "explorer.exe") > 0, SubStr(g_CapDisplay, 1, 80))
} catch as e {
    Ck("showprocess-no-throw", false, e.Message)
}

if (g_Fail > 0) {
    FileAppend("probe-process FAIL: " . g_Fail . "`n", "*")
    ExitApp(1)
}
FileAppend("probe-process-ok`n", "*")
ExitApp(0)
