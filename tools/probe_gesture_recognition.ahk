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

Check("RD jitter", GestureRecognizer.DirectionChain(MakePoints([
    [0,0],[20,1],[40,-2],[38,1],[60,2],[85,-1],[100,0],
    [102,20],[99,40],[101,38],[100,62],[102,82],[100,100]])), "R_D")
Check("RD dense", GestureRecognizer.DirectionChain(MakePoints([
    [0,0],[8,0],[16,1],[24,-1],[32,1],[40,-1],[48,0],
    [56,0],[64,1],[72,0],[80,0],[80,8],[81,16],[79,24],
    [81,32],[80,40],[80,48],[80,56],[80,64]])), "R_D")
Check("diagonal", GestureRecognizer.DirectionChain(MakePoints([
    [0,100],[20,79],[40,61],[60,39],[80,20],[100,0]])), "UR")
Check("U then UR", GestureRecognizer.DirectionChain(MakePoints([
    [0,100],[1,80],[-1,60],[0,40],[0,20],[20,0],[40,-20]])), "U_UR")
Check("V stroke", GestureRecognizer.DirectionChain(MakePoints([
    [0,0],[20,20],[40,40],[50,50],[60,40],[80,20],[100,0]])), "DR_UR")
Check("inverted V stroke", GestureRecognizer.DirectionChain(MakePoints([
    [0,100],[20,80],[40,60],[50,50],[60,60],[80,80],[100,100]])), "UR_DR")
Check("inverted V pause split", GestureRecognizer.DirectionChain(MakePoints([
    [0,100],[16,84],[32,68],[44,56],[49,51],[50,50],[50,50],[51,51],
    [56,56],[68,68],[84,84],[100,100]])), "UR_DR")
uChain := GestureRecognizer.DirectionChain(MakePoints([
    [0,0],[0,20],[0,48],[4,72],[18,92],[40,100],[62,92],[76,72],[80,48],[80,20],[80,0]]))
Check("U is not inverted V", uChain != "DR_UR" && uChain != "UR_DR", true)

rawDefs := SPTpl_RawDefs()
for name, def in Tpl_BuiltinDefs() {
    ideal := MakePoints(def[2])
    samples := [Tpl_Prepare(ideal)]
    if (rawDefs.Has(name)) {
        raw := Tpl_Decode(rawDefs[name])
        if (raw.Length >= 3)
            samples.InsertAt(1, Tpl_Prepare(raw))
    }
    g_Templates[name] := {action: def[1], samples: samples, builtin: 1}
}

invVNoisy := MakePoints([
    [0,100],[1,88],[0,76],[2,64],[1,52],[12,40],[24,28],[36,16],[48,5],[50,0],
    [50,0],[53,3],[64,16],[76,28],[88,40],[98,52],[100,64],[99,76],[101,88],[100,100]])
invVMatch := Tpl_Match(invVNoisy, 6)
Check("inverted V noisy pause template", invVMatch[1], "InvV")
Check("inverted V noisy pause score", invVMatch[2] >= 75, true)

invVUneven := MakePoints([
    [0,100],[2,70],[7,48],[19,27],[38,9],[50,0],[62,9],[81,27],[93,48],[98,70],[100,100]])
invVMatch2 := Tpl_Match(invVUneven, 6)
Check("inverted V uneven sampling template", invVMatch2[1], "InvV")
for name, def in Tpl_BuiltinDefs() {
    actual := Tpl_Match(MakePoints(def[2]), 6)
    Check("ideal " . name, actual[1], name)
    if (rawDefs.Has(name)) {
        actual := Tpl_Match(Tpl_Decode(rawDefs[name]), 6)
        Check("recorded " . name, actual[1], name)
    }
}

prevSample := Tpl_Prepare(MakePoints(Tpl_BuiltinDefs()["B"][2]))
g_Templates := Map("B", {action: "key|^d", samples: [prevSample], versions: [2], builtin: 0})
Check("prepared version", Tpl_Match(MakePoints(Tpl_BuiltinDefs()["B"][2]), 6)[1], "B")
Check("current serialization", SubStr(Tpl_JoinSamples(g_Templates["B"]), 1, 3), "v2:")

if failures
    ExitApp(1)
FileAppend("PASS gesture recognition`n", "*")
ExitApp(0)
