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
    FileAppend("[Gesture]`nTemplateThreshold=75`n[GestureDefinitions]`nV=template`nDR_UR=direction`n"
        . "[Gestures]`nV=key|global-v`nDR_UR=key|direction`n"
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
    Check("direction only", Gesture_ResolveStroke("DR_UR", [{x: 0, y: 0}], "other.exe", "Other", "")[1] = "key|direction")
    Check("candidate name", IsObject(g_Gesture["candidate"]) && g_Gesture["candidate"].name = "DR_UR")
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
