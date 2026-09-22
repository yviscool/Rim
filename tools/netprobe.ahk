#Requires AutoHotkey v2.0
#Warn All, Off

pTable := 0
hr := DllCall("iphlpapi\GetIfTable2", "Ptr*", &pTable, "UInt")
out := "hr=" . hr . " p=" . pTable . "`n"
if (hr = 0 && pTable) {
    num := NumGet(pTable, 0, "UInt")
    out .= "num=" . num . "`n"
    out .= "raw8=" . NumGet(pTable, 8, "UInt64") . "`n"
    probeSizes := [840, 848, 856, 1336, 1352, 1360, 1368, 1400, 1424, 1472, 1512, 1544]
    for rs in probeSizes {
        base := pTable + 8
        ii := NumGet(base, 8, "UInt")
        typ := NumGet(base, 1128, "UInt")
        ops := NumGet(base, 1156, "UInt")
        ino := NumGet(base, 1208, "UInt64")
        oub := NumGet(base, 1280, "UInt64")
        out .= "rs=" . rs . " ii=" . ii . " type=" . typ . " oper=" . ops . " in=" . ino . " out=" . oub . "`n"
        if (num > 1) {
            b2 := base + rs
            out .= "  r2 ii=" . NumGet(b2, 8, "UInt") . " type=" . NumGet(b2, 1128, "UInt") . " in=" . NumGet(b2, 1208, "UInt64") . "`n"
        }
    }
    DllCall("iphlpapi\FreeMibTable", "Ptr", pTable)
}
FileAppend(out, A_ScriptDir "\netprobe.out.txt")
ExitApp(0)
