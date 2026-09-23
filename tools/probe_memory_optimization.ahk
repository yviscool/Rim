#Requires AutoHotkey v2.0
#Warn All, Off

#Include ..\Core\Common.ahk
#Include ..\Core\Utils.ahk
#Include ..\Plugins\StatsBall.ahk

global g_Fail := 0
Check(name, condition) {
    global g_Fail
    if (!condition) {
        FileAppend("FAIL|" . name . "`n", "*")
        g_Fail++
    }
}

st1 := GlobalMemoryStatusEx()
st2 := GlobalMemoryStatusEx()
Check("memory-status", IsObject(st1) && st1[2] > 0 && st1[3] > 0)
Check("memory-status-reuse", ObjPtr(st1) = ObjPtr(st2))

s1 := StatsBall_Sample()
s2 := StatsBall_Sample()
Check("sample-values", IsObject(s1) && s1.totalGB > 0 && s1.memPct >= 0 && s1.memPct <= 100)
Check("sample-reuse", ObjPtr(s1) = ObjPtr(s2))

n1 := StatsBall_NetRate()
n2 := StatsBall_NetRate()
Check("net-values", IsObject(n1) && n1.up >= 0 && n1.dn >= 0)
Check("net-reuse", ObjPtr(n1) = ObjPtr(n2))
Check("memory-manager", MemoryManager.GetUsage() >= 0)
rows := StatsBall_TopProcs(3)
Check("top-n-limit", rows.Length <= 3)
if (rows.Length > 1)
    Check("top-n-order", rows[1].ws >= rows[2].ws)

if (g_Fail) {
    FileAppend("RESULT|FAIL|" . g_Fail . "`n", "*")
    ExitApp(1)
}
FileAppend("RESULT|PASS`n", "*")
ExitApp(0)
