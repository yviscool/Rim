#Requires AutoHotkey v2.0
#Warn All, Off

T(key, *) {
    return key
}

#Include ..\Lib\EasyIni.ahk
#Include ..\Core\Gesture.ahk
#Include ..\Core\GestureTemplate.ahk
#Include ..\Core\GestureSPData.ahk
#Include ..\Core\GestureIni.ahk

global g_ConfFile := A_Temp . "\rim-gesture-unified-" . A_TickCount . ".ini"
global g_Conf := ""
global failures := 0

Check(label, condition) {
    global failures
    if !condition {
        FileAppend("FAIL " . label . "`n", "*")
        failures++
    }
}

try {
    FileAppend("[Gesture]`nTemplateThreshold=75`n[GestureDefinitions]`nV=template`nDR_UR=direction`nD_R=direction`n"
        . "[Gestures]`nV=key|global-v`nDR_UR=key|direction`nD_R=key|direction-dr`n"
        . "[GestureApp:Browser]`nset_file=browser.exe`nV=key|browser-v`n"
        . "[GestureApp:Music]`nset_file=music.exe`nV=key|music-v`n"
        . "[GestureApp:Locked]`nset_file=locked.exe`nnoglobal=1`n", g_ConfFile, "UTF-8")
    g_Conf := EasyIni(g_ConfFile)
    Tpl_LoadAll()
    Gesture_ReloadLayers()
    vPts := []
    for _, xy in Tpl_BuiltinDefs()["V"][2]
        vPts.Push(Tpl_Pt(xy[1], xy[2]))
    Check("browser V", Gesture_ResolveStroke("DR_UR", vPts, "browser.exe", "Browser", "")[1] = "key|browser-v")
    Check("music V", Gesture_ResolveStroke("DR_UR", vPts, "music.exe", "Player", "")[1] = "key|music-v")
    Check("global V", Gesture_ResolveStroke("DR_UR", vPts, "other.exe", "Other", "")[1] = "key|global-v")
    Check("noglobal", Gesture_ResolveStroke("DR_UR", vPts, "locked.exe", "Locked", "")[1] = "")
    Check("direction only", Gesture_ResolveStroke("D_R", [{x: 0, y: 0}, {x: 0, y: 20}, {x: 20, y: 20}], "other.exe", "Other", "")[1] = "key|direction-dr")
    Check("candidate name", IsObject(g_Gesture["candidate"]) && g_Gesture["candidate"].name = "D_R")

    ; 负样本语料 (随手轨迹必须零触发; 确定性序列, 禁 Random, 防误触回归)
    negPts := [{x: 0, y: 0}, {x: 7, y: 3}, {x: 2, y: 9}, {x: 11, y: 5}, {x: 4, y: 12}, {x: 9, y: 2}]
    Check("negative scribble unbound", Gesture_ResolveStroke("D_R", negPts, "other.exe", "Other", "")[1] = "")
    Check("degenerate single point unbound", Gesture_ResolveStroke("D_R", [{x: 5, y: 5}], "other.exe", "Other", "")[1] = "")

    ; 语料文件批量断言 (tools/gesture_negatives.txt, 50 条; 方向无绑定 + 模板分全 < 75)
    negPath := A_ScriptDir . "\gesture_negatives.txt"
    negText := FileRead(negPath, "UTF-8")
    negCount := 0
    negBad := 0
    Loop Parse, negText, "`n", "`r" {
        negLine := Trim(A_LoopField)
        if (negLine = "" || SubStr(negLine, 1, 1) = ";")
            continue
        cPts := []
        for _, tok in StrSplit(negLine, " ") {
            xy := StrSplit(Trim(tok), ",")
            if (xy.Length >= 2)
                cPts.Push(Tpl_Pt(xy[1] + 0.0, xy[2] + 0.0))
        }
        if (cPts.Length < 3)
            continue
        negCount++
        if (Gesture_ResolveStroke("D_R", cPts, "other.exe", "Other", "")[1] != "")
            negBad++
        for _, mcand in Tpl_Candidates(cPts, 20) {
            if (mcand.score >= 75)
                negBad++
        }
    }
    Check("negatives loaded", negCount >= 50)
    Check("negatives zero-fire", negBad = 0)
    Check("no prefix", Gesture_Normalize("V") = "V" && Gesture_Normalize("DR_UR") = "DR_UR")

    enc := "v2:" . Tpl_Encode(Tpl_Prepare(vPts))
    Check("save samples", GestureStore_SetTemplateSamples("V", [enc, enc]))
    Check("samples have no action", SubStr(g_Conf.Get("GestureTemplates", "V"), 1, 3) = "v2:")
    Check("delete sample", Tpl_RemoveSample("V", 2) && Tpl_Get("V").samples.Length = 1)
    Check("definition save", GestureStore_SetDefinition("V", "template")
        && g_Conf.Get("GestureDefinitions", "V") = "template")
    pkg := g_ConfFile . ".export.ini"
    Check("export", GesturePkg_Export(pkg))
    Check("definition export", InStr(FileRead(pkg, "UTF-8"), "[GestureDefinitions]"))
} catch Error as e {
    FileAppend("ERROR " . e.Message . " line=" . e.Line . "`n", "*")
    failures++
} finally {
    try FileDelete(g_ConfFile)
    try FileDelete(g_ConfFile . ".export.ini")
}
FileAppend(failures ? "FAIL " . failures . "`n" : "PASS unified gesture`n", "*")
ExitApp(failures ? 1 : 0)
