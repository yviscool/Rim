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

global g_ConfFile := A_Temp . "\rim-gesture-store-probe-" . A_TickCount . ".ini"
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
    FileAppend("[Gesture]`nEnable=1`n[Gestures]`nL=key|^a`n"
        . "[GestureApp:Probe]`nset_file=probe.exe`nnoglobal=1`n"
        . "[GestureDisabled]`n全局:L`n[GestureDesc]`n全局:L=old description`n", g_ConfFile, "UTF-8")
    g_Conf := EasyIni(g_ConfFile)
    Gesture_ReloadLayers()
    Tpl_LoadAll()

    Check("save new", GestureStore_SaveGesture("全局", "R_D", "key|^b", "new description"))
    Check("new action", g_Conf.Get("Gestures", "R_D") = "key|^b")
    Check("new description", Gesture_GetGestureDesc("全局", "R_D") = "new description")
    Check("move disabled", GestureStore_MoveGesture("全局", "L", "Probe", "U_D", "key|^c", "moved description"))
    Check("old removed", !g_Conf.HasKey("Gestures", "L"))
    Check("old description removed", Gesture_GetGestureDesc("全局", "L") = "")
    Check("old off removed", !Gesture_ChainOff("全局", "L"))
    Check("new off transferred", Gesture_ChainOff("Probe", "U_D"))
    Check("new description", Gesture_GetGestureDesc("Probe", "U_D") = "moved description")
    beforeFailedMove := FileRead(g_ConfFile, "UTF-8")
    Check("missing old binding rejected", !GestureStore_MoveGesture("全局", "MISSING", "Probe", "R", "key|^x", "invalid"))
    Check("failed move rolled back", FileRead(g_ConfFile, "UTF-8") = beforeFailedMove)
    Check("memory rolled back", !g_Conf.HasKey("GestureApp:Probe", "R"))

    pts := []
    for _, xy in Tpl_BuiltinDefs()["V"][2]
        pts.Push(Tpl_Pt(xy[1], xy[2]))
    Check("unbound shape does not execute", Gesture_ResolveStroke("DR_UR", pts, "other.exe", "OtherClass", "")[1] = "")

    pkgPath := g_ConfFile . ".export.ini"
    Check("export", GesturePkg_Export(pkgPath))
    exported := FileRead(pkgPath, "UTF-8")
    Check("description in export", InStr(exported, "[GestureDesc]") && InStr(exported, "Probe:U_D=moved description"))
    Check("delete exported desc", GestureStore_DelGestureDesc("Probe", "U_D"))
    Check("import", GesturePkg_Import(pkgPath, true)[3] > 0)
    Check("description restored", Gesture_GetGestureDesc("Probe", "U_D") = "moved description")
} catch Error as e {
    FileAppend("ERROR " . e.Message . " line=" . e.Line . "`n", "*")
    failures++
} finally {
    try FileDelete(g_ConfFile)
    try FileDelete(g_ConfFile . ".export.ini")
}

FileAppend(failures ? "FAIL " . failures . "`n" : "PASS gesture store`n", "*")
ExitApp(failures ? 1 : 0)
