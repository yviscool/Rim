#Requires AutoHotkey v2.0
#Warn All, Off

T(k, params*) {
    return k
}

#Include ..\Core\Gesture.ahk
#Include ..\Core\GestureTemplate.ahk
#Include ..\Core\GestureSPData.ahk

Probe_Fail(e, mode) {
    FileAppend("ERROR " . e.Message . " line=" . e.Line . "`n", "*")
    ExitApp(2)
}
OnError(Probe_Fail, -1)

global failures := 0
Check(label, actual, expected) {
    global failures
    if (actual != expected) {
        FileAppend("FAIL " . label . " expected=" . expected . " actual=" . actual . "`n", "*")
        failures++
    }
}

MakePoints(coords) {
    pts := []
    for _, xy in coords
        pts.Push(Tpl_Pt(xy[1], xy[2]))
    return pts
}

Check("RD jitter", Gesture_DirectionChain(MakePoints([
    [0,0],[20,1],[40,-2],[38,1],[60,2],[85,-1],[100,0],
    [102,20],[99,40],[101,38],[100,62],[102,82],[100,100]])), "R_D")
Check("RD dense", Gesture_DirectionChain(MakePoints([
    [0,0],[8,0],[16,1],[24,-1],[32,1],[40,-1],[48,0],
    [56,0],[64,1],[72,0],[80,0],[80,8],[81,16],[79,24],
    [81,32],[80,40],[80,48],[80,56],[80,64]])), "R_D")
Check("diagonal", Gesture_DirectionChain(MakePoints([
    [0,100],[20,79],[40,61],[60,39],[80,20],[100,0]])), "UR")
Check("U then UR", Gesture_DirectionChain(MakePoints([
    [0,100],[1,80],[-1,60],[0,40],[0,20],[20,0],[40,-20]])), "U_UR")

rawDefs := SPTpl_RawDefs()
for name, def in Tpl_BuiltinDefs() {
    raw := Tpl_Decode(rawDefs[name])
    ideal := MakePoints(def[2])
    g_Templates[name] := {action: def[1], samples: [Tpl_Prepare(raw), Tpl_Prepare(ideal)], builtin: 1}
}
for name, def in Tpl_BuiltinDefs() {
    actual := Tpl_Match(MakePoints(def[2]), 6)
    Check("ideal " . name, actual[1], name)
    actual := Tpl_Match(Tpl_Decode(rawDefs[name]), 6)
    Check("recorded " . name, actual[1], name)
}

legacy := Tpl_PrepareLegacy(MakePoints(Tpl_BuiltinDefs()["B"][2]))
g_Templates := Map("B", {action: "key|^d", samples: [legacy], versions: [1], builtin: 0})
Check("legacy version", Tpl_Match(MakePoints(Tpl_BuiltinDefs()["B"][2]), 6)[1], "B")
Check("legacy serialization", SubStr(Tpl_JoinSamples(g_Templates["B"]), 1, 3), "v1:")

if failures
    ExitApp(1)
FileAppend("PASS gesture recognition`n", "*")
ExitApp(0)
