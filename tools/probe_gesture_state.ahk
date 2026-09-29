#Requires AutoHotkey v2.0
#Warn All, Off
#Include ..\Core\ConfigSchema.ahk
#Include ..\Core\Gesture.ahk

g_Gesture["phase"] := "pending"
g_Gesture["down"] := 1
g_Gesture["points"] := [{x: 1, y: 2}]
g_Gesture["dirs"] := ["R"]
g_Gesture["gesture"] := "R"
g_Gesture["startHwnd"] := 123
GestureHook.ClearStartContext()
if (g_Gesture["phase"] != "idle" || g_Gesture["points"].Length != 0 || g_Gesture["dirs"].Length != 0 || g_Gesture["gesture"] != "")
    ExitApp(1)
try FileDelete(A_ScriptDir . "\..\probe_gesture_state.out.txt")
FileAppend("probe-gesture-state-ok`n", A_ScriptDir . "\..\probe_gesture_state.out.txt")
ExitApp(0)
