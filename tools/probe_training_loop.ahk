#Requires AutoHotkey v2.0
#Warn All, Off
; P2-11: 训练闭环探针 (候选展示+纠错追加+禁用+配置包)

T(key, *) => key
RimLog(level, msg, err := "") {
    return
}

global g_GestureDefs := Map("R", Map("method", "direction"))
global g_GestureDisabled := Map()

Tpl_AddSample(label, pts) {
    global g_GestureDefs
    g_GestureDefs[label] := Map("method", "template")
    return true
}

#Include ..\Core\TrainingLoop.ahk

fails := []
Check(name, cond) {
    global fails
    if (!cond)
        fails.Push(name)
}

Main() {
    global fails, g_GestureDisabled
    dec := Map("reason", "ok", "selected", Map("name", "R"), "candidates", [Map("name", "R", "score", 88.5, "layer", "global", "method", "direction"), Map("name", "L", "score", 60.0, "layer", "global", "method", "direction")])
    s := Training_Summary(dec)
    Check("summary", InStr(s, "candidates=2") > 0 && InStr(s, "selected=R") > 0 && InStr(s, "score=88.5") > 0)
    r := Training_AppendSample("U", [{x: 1, y: 2}])
    Check("append", r["ok"])
    d := Training_Disable("R")
    Check("disable", d["ok"] && g_GestureDisabled.Has("R"))
    p := A_ScriptDir . "\..\probe_pack_test.ini"
    try FileDelete(p)
    catch {
    }
    e := Training_ExportPack(p)
    Check("export", e["ok"] && FileExist(p))
    try FileDelete(p)
    catch {
    }
    out := A_ScriptDir . "\..\probe_training_loop.out.txt"
    try FileDelete(out)
    catch {
    }
    if (fails.Length > 0) {
        txt := "training-loop-FAIL:`n"
        for _, x in fails
            txt .= "  - " . x . "`n"
        FileAppend(txt, out, "UTF-8")
        ExitApp(1)
    }
    FileAppend("training-loop-ok`n", out, "UTF-8")
    ExitApp(0)
}

Main()
