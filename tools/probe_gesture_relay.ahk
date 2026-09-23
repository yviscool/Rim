#Requires AutoHotkey v2.0
#Warn All, Off

#Include ..\Core\Gesture.ahk
#Include ..\Core\GestureTemplate.ahk

global relayEvents := []
global relayTarget := 0

Relay_OnMessage(wParam, lParam, msg, hwnd) {
    global relayEvents, relayTarget
    if (hwnd = relayTarget)
        relayEvents.Push(msg)
}

CoordMode("Mouse", "Screen")
MouseGetPos(&oldX, &oldY)
oldHwnd := WinExist("A")
probeGui := Gui("-Caption +AlwaysOnTop +ToolWindow")
probeGui.BackColor := "FFFFFF"
probeGui.Show("x120 y120 w240 h120")
relayTarget := probeGui.Hwnd
OnMessage(0x204, Relay_OnMessage)
OnMessage(0x205, Relay_OnMessage)
OnMessage(0x200, Relay_OnMessage)

g_Gesture["trigger"] := "RButton"
g_Gesture["points"] := [{x: 145, y: 145}, {x: 175, y: 145}, {x: 205, y: 160}]
MouseMove(205, 160, 0)
ok := Gesture_RelayStroke(true)
Sleep(150)

downAt := 0, moveAt := 0, upAt := 0
for i, msg in relayEvents {
    if (msg = 0x204 && !downAt)
        downAt := i
    else if (msg = 0x200 && downAt && !moveAt)
        moveAt := i
    else if (msg = 0x205 && downAt && !upAt)
        upAt := i
}
complete := ok && downAt > 0 && moveAt > downAt && upAt > moveAt

relayEvents := []
MouseMove(205, 160, 0)
held := Gesture_RelayStroke(false)
Sleep(100)
releasedEarly := false
for _, msg in relayEvents
    if (msg = 0x205)
        releasedEarly := true
SendEvent("{RButton Up}")
Sleep(100)
releasedAfter := false
for _, msg in relayEvents
    if (msg = 0x205)
        releasedAfter := true

relayEvents := []
g_Gesture["down"] := 1
g_Gesture["gesturing"] := 0
g_Gesture["cancelled"] := 0
g_Gesture["recording"] := 0
g_Gesture["tplRecording"] := 0
g_Gesture["noMatch"] := "passthrough"
g_Gesture["points"] := [{x: 145, y: 145}]
g_Gesture["startX"] := 145
g_Gesture["startY"] := 145
g_Gesture["startContext"] := ""
g_Templates := Map()
MouseMove(205, 160, 0)
Gesture_UpCore()
Sleep(100)
endSampled := g_Gesture["points"].Length > 1
endRelayed := false
for _, msg in relayEvents
    if (msg = 0x205)
        endRelayed := true

try probeGui.Destroy()
MouseMove(oldX, oldY, 0)
if (oldHwnd)
    try WinActivate("ahk_id " . oldHwnd)

if (!complete || !held || releasedEarly || !releasedAfter || !endSampled || !endRelayed) {
    FileAppend("FAIL gesture relay: complete=" . complete . " held=" . held
        . " early=" . releasedEarly . " released=" . releasedAfter
        . " sampled=" . endSampled . " end-relayed=" . endRelayed . "`n", "*")
    ExitApp(1)
}
FileAppend("PASS gesture relay`n", "*")
ExitApp(0)
