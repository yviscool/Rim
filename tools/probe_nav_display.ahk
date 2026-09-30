#Requires AutoHotkey v2.0
#Warn All, Off

; 显示区导航探针: 真隐藏 Edit + 直调 Next/PrevCommand, 光标必须对称移动且无选中
; (Up 死键排查沉淀: Focus()+Send 改 ControlSend 直投后锁定)
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_nav_display.ahk
#Include ..\Core\GUI.ahk
#Include ..\Core\Hotkeys.Commands.ahk

global g_Fail := 0
Ck(name, cond, extra := "") {
    global g_Fail
    if (cond)
        FileAppend("PASS: " . name . "`n", "*")
    else {
        FileAppend("FAIL: " . name . (extra != "" ? " | got=[" . extra . "]" : "") . "`n", "*")
        g_Fail++
    }
}

T(key, params*) {
    return key
}

CaretPos(hwnd) {
    packed := DllCall("SendMessageW", "Ptr", hwnd, "UInt", 0x00B0, "Ptr", 0, "Ptr", 0, "Ptr")
    return Map("s", packed & 0xFFFF, "e", (packed >> 16) & 0xFFFF)
}

global g_UseDisplay := true
global g_RowActive := false
global g_SkinConf := Map("HideCol2", "0", "HideCol4IfEmpty", "1", "DisplayCol3MaxLength", "30"
    , "DisplayCol4MaxLength", "36")
global g_MainGui := Gui("+ToolWindow", "NavProbe")
global g_DisplayEdit := g_MainGui.Add("Edit", "w400 h200 -VScroll ReadOnly -WantReturn")

txt := ""
Loop 20 {
    txt .= "line" . A_Index . " padding text`n"
}
g_DisplayEdit.Value := txt
hwnd := g_DisplayEdit.Hwnd

c0 := CaretPos(hwnd)
Ck("init-zero", c0["s"] = 0 && c0["e"] = 0)
NextCommand()
Sleep(80)
c1 := CaretPos(hwnd)
Ck("down-moves", c1["s"] > c0["s"] && c1["s"] = c1["e"], c1["s"] . "-" . c1["e"])
NextCommand()
Sleep(80)
c2 := CaretPos(hwnd)
Ck("down-moves2", c2["s"] > c1["s"] && c2["s"] = c2["e"], c2["s"] . "-" . c2["e"])
PrevCommand()
Sleep(80)
c3 := CaretPos(hwnd)
Ck("up-returns", c3["s"] < c2["s"] && c3["s"] = c3["e"], c3["s"] . "-" . c3["e"])
PrevCommand()
Sleep(80)
c4 := CaretPos(hwnd)
Ck("up-returns2", c4["s"] < c3["s"] && c4["s"] = c4["e"], c4["s"] . "-" . c4["e"])
Ck("up-not-down", c4["s"] <= c1["s"], "c1=" . c1["s"] . " c4=" . c4["s"])

; 垃圾皮肤列宽永不炸对齐 (手改 abc/空串照常出字)
g_SkinConf["DisplayCol3MaxLength"] := "abc"
g_SkinConf["DisplayCol4MaxLength"] := ""
garbageOut := ""
try garbageOut := AlignText("a | b | c")
catch as e {
    garbageOut := "THROW:" . e.Message
}
Ck("garbage-skin", !InStr(garbageOut, "THROW") && InStr(garbageOut, "a") > 0, SubStr(garbageOut, 1, 40))

; SkinNum 三态 (有效/缺键/垃圾)
Ck("skinnum-valid", SkinNum("DisplayCol3MaxLength", 30) = 30)
g_SkinConf.Delete("DisplayCol3MaxLength")
Ck("skinnum-missing", SkinNum("DisplayCol3MaxLength", 30) = 30)
g_SkinConf["DisplayCol3MaxLength"] := "abc"
Ck("skinnum-garbage", SkinNum("DisplayCol3MaxLength", 30) = 30)
g_SkinConf["DisplayCol3MaxLength"] := "-5"
Ck("skinnum-negative", SkinNum("DisplayCol3MaxLength", 30) = -5, "负数照传, 由调用方钳制")

if (g_Fail > 0) {
    FileAppend("probe-nav-display FAIL: " . g_Fail . "`n", "*")
    ExitApp(1)
}
FileAppend("probe-nav-display-ok`n", "*")
ExitApp(0)
