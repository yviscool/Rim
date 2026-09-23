#Requires AutoHotkey v2.0
#Warn All, Off

#Include ..\Core\Common.ahk
#Include ..\Plugins\General.ahk

global g_Gesture := Map("startHwnd", 0, "startContext", "")
global g_WindowName := ""

g := Gui("+ToolWindow", "Rim Toggle Probe")
g.Show("x120 y120 w240 h100")
hwnd := g.Hwnd
g_Gesture["startHwnd"] := hwnd
g_Gesture["startContext"] := {rootHwnd: hwnd}

WinRestore("ahk_id " . hwnd)
wm_max()
Sleep(80)
first := WinGetMinMax("ahk_id " . hwnd)
wm_max()
Sleep(80)
second := WinGetMinMax("ahk_id " . hwnd)
g.Destroy()

if (first != 1 || second != 0) {
    FileAppend("FAIL first=" . first . " second=" . second . "`n", "*")
    ExitApp(1)
}
FileAppend("PASS maximize-restore`n", "*")
ExitApp(0)
