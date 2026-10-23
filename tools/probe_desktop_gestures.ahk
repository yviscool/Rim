#Requires AutoHotkey v2.0
#Warn All, Off
; 回归探针: 桌面不得被独立手势层吞键
; 历史坑: [GestureApp:Desktop] 把 UR/DL/UL 映射到 NoOp, 桌面上最大化/最小化/Alt+F4
; 全部静默失效; 默认模板必须让这些手势回落到全局。

T(key, *) => key

#Include ..\Lib\EasyIni.ahk
#Include ..\Core\ConfigSchema.ahk
#Include ..\Core\Gesture.ahk
#Include ..\Core\GestureTemplate.ahk
#Include ..\Core\GestureSPData.ahk
#Include ..\Core\GestureIni.ahk

fails := []
Check(name, cond) {
    global fails
    if (!cond)
        fails.Push(name)
    FileAppend((cond ? "PASS: " : "FAIL: ") . name . "`n", "*")
}

global g_Conf := EasyIni(A_ScriptDir . "\..\Conf\rim.template.ini")
Tpl_LoadAll()
GestureEngine.ReloadLayers()

DesktopResolve(g) {
    return GestureEngine.ResolveFor(g, "explorer.exe", "Progman", "", "Program Manager",
        "SHELLDLL_DefView|Progman", "SysListView32", "FolderView")
}

Check("desktop-max-global", DesktopResolve("UR")[1] = "<wm_max>" && DesktopResolve("UR")[2] = "全局")
Check("desktop-min-global", DesktopResolve("DL")[1] = "<wm_min>" && DesktopResolve("DL")[2] = "全局")
Check("desktop-altf4-global", DesktopResolve("UL")[1] = "key|!{F4}" && DesktopResolve("UL")[2] = "全局")
Check("desktop-no-noop", !InStr(FileRead(A_ScriptDir . "\..\Conf\rim.template.ini", "UTF-8"), "[GestureApp:Desktop]"))

if (fails.Length > 0) {
    txt := "desktop-gestures-FAIL:`n"
    for _, x in fails
        txt .= "  - " . x . "`n"
    FileAppend(txt, A_ScriptDir . "\..\probe_desktop_gestures.out.txt", "UTF-8")
    ExitApp(1)
}
FileAppend("desktop-gestures-ok`n", A_ScriptDir . "\..\probe_desktop_gestures.out.txt", "UTF-8")
ExitApp(0)
