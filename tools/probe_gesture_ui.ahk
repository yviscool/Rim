#Requires AutoHotkey v2.0
#Warn All, Off
; i18n:protocol-file (对话框层参数 "全局" 固件, 与引擎层 ID 比对)

T(key, *) {
    return key
}

#Include ..\Lib\EasyIni.ahk
#Include ..\Core\Gesture.ahk
#Include ..\Core\GestureTemplate.ahk
#Include ..\Core\GestureSPData.ahk
#Include ..\Core\GestureIni.ahk
#Include ..\Core\GesturePreview.ahk
#Include ..\Gui\GestureUI.ahk

global g_ConfFile := A_Temp . "\rim-gesture-ui-probe-" . A_TickCount . ".ini"
global g_Conf := ""

try {
    FileAppend("[Gesture]`nEnable=1`nTrigger=RButton`nCancelDelay=1500`n"
        . "[Gestures]`nR_D=key|^t`n", g_ConfFile, "UTF-8")
    g_Conf := EasyIni(g_ConfFile)
    GestureEngine.LoadConfig()
    GestureEngine.ReloadLayers()
    Tpl_LoadAll()
    ShowGestureManager()
    dlg := GestureEditDialog("new", "全局", "R_D", "key|^t")
    GestureDlg_OnPreview()
    if !IsObject(dlg) || dlg["tx"].Text = ""
        throw Error("preview was not populated")
    dlg["gui"].Destroy()
    g_GestureMgr["gui"].Destroy()
    FileAppend("PASS gesture UI`n", "*")
} catch Error as e {
    try g_GestureMgr["editGui"]["gui"].Destroy()
    try g_GestureMgr["gui"].Destroy()
    FileAppend("FAIL gesture UI: " . e.Message . " line=" . e.Line . "`n", "*")
    ExitApp(1)
} finally {
    try FileDelete(g_ConfFile)
}
ExitApp(0)
