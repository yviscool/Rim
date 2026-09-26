#Requires AutoHotkey v2.0
#Warn All, Off

; 手势结构性修复探针: 命名空间 / 模板覆盖 / 控件匹配 / 颜色 / 起点窗 / 组合
; 纯逻辑验证, 不碰热键/界面. 失败即非 0 退出.

; 注意: 不得重定义 ToolTip/SetTimer 等内建函数 (会挂起/弹框);
; headless 下真内建调用无害 (ComboArm 的 SetTimer 在 ExitApp 前无机会触发)
T(k, params*) {
    return k
}

#Include ..\Core\Gesture.ahk
#Include ..\Core\GestureTemplate.ahk
#Include ..\Core\GestureSPData.ahk
#Include ..\Core\GestureTrail.ahk
#Include ..\Core\GesturePreview.ahk

; 模态错误框会挂起探针: 转存档 + 非 0 退出
Probe_OnError(e, mode) {
    try FileAppend("FAIL|unhandled: " . e.Message . " @line=" . e.Line . " what=" . e.What . "`n"
        , A_ScriptDir . "\probe_gesture_fix.out.txt")
    catch {
    }
    ExitApp(3)
}
OnError(Probe_OnError, -1)

global g_Fails := 0

Chk(name, cond) {
    global g_Fails
    if (cond) {
        FileAppend("OK|" . name . "`n", A_ScriptDir . "\probe_gesture_fix.out.txt")
    } else {
        FileAppend("FAIL|" . name . "`n", A_ScriptDir . "\probe_gesture_fix.out.txt")
        g_Fails++
    }
}

try FileDelete(A_ScriptDir . "\probe_gesture_fix.out.txt")
catch {
}

; ---- 1. 归一化命名空间 ----
Chk("norm-name", GestureRecognizer.Normalize("letter_u") = "LETTER_U")
Chk("norm-chain", GestureRecognizer.Normalize("d_r") = "D_R")
Chk("normfull-mods", GestureRecognizer.NormalizeFull("ctrl + d_r") = "CTRL+D_R")
Chk("normfull-name", GestureRecognizer.NormalizeFull("ctrl+letter_u") = "CTRL+LETTER_U")

; ---- 2. 内置模板装载 (复刻 Tpl_LoadAll 内置段, 不依赖 g_Conf) ----
try {
    probeRaw := SPTpl_RawDefs()
} catch {
    probeRaw := Map()
}
for name, def in Tpl_BuiltinDefs() {
    probeSamples := []
    try {
        if (probeRaw.Has(name)) {
            probePts := Tpl_Decode(probeRaw[name])
            if (probePts.Length >= 3)
                probeSamples.Push(Tpl_Prepare(probePts))
        }
    }
    probeSamples.Push(Tpl_Synth(def[2]))
    g_Templates[name] := {action: def[1], samples: probeSamples, builtin: 1}
}
Chk("tpl-builtins", g_Templates.Count >= 16)

; 字母 U 候选应命中模板 U (用合成样本点反查, 分数达标)
rawU := []
for i, w in [["20","15"],["20","70"],["35","88"],["60","88"],["78","68"],["80","15"]] {
    rawU.Push(Tpl_Pt(w[1] + 0.0, w[2] + 0.0))
}
m := Tpl_Match(rawU, 6)
Chk("tpl-match-U", m[1] = "U" && m[2] >= 75)

; ---- 4. 控件级应用匹配 ----
g_GestureApps := [{name: "Desk", exe: "explorer.exe", cls: "", title: "", titleRx: "",
    ownerCls: "WorkerW|Progman", ctrlCls: "SysListView32", ctrlTitle: "FolderView", noglobal: 0, map: Map()}]
hit := GestureEngine.MatchApp("explorer.exe", "Progman", "", "WorkerW|Shell_TrayWnd", "SysListView32", "FolderView")
Chk("app-ctrl-hit", IsObject(hit) && hit.name = "Desk")
miss := GestureEngine.MatchApp("explorer.exe", "Progman", "", "OtherOwner", "OtherCls", "FolderView")
Chk("app-ctrl-miss", !IsObject(miss))

; ---- 5. TrailColor 生效 ----
g_Gesture["trailColor"] := "45ABFF"
Chk("trail-color", GestureTrail_Color() = 0xFFAB45)
g_Gesture["trailColor"] := "notacolor"
Chk("trail-color-fallback", GestureTrail_Color() = 0xFFFFFF)

; ---- 6. 起点窗口 ----
g_Gesture["startHwnd"] := 0
Chk("actionwin-fallback", GestureHook.ActionWin() = "A")
g_Gesture["startHwnd"] := 12345
g_Gesture["startContext"] := {rootHwnd: 12345, exe: "start.exe", cls: "StartClass",
    title: "Start Window", ownerCls: "OwnerClass", ctrlCls: "ControlClass", ctrlTitle: "Start Control"}
Chk("actionwin-start", GestureHook.ActionWin() = "ahk_id 12345")
GestureHook.StartIds(&startExe, &startCls, &startTitle, &startOwner, &startCtrl, &startCtrlTitle)
Chk("start-context-snapshot", startExe = "start.exe" && startCls = "StartClass"
    && startTitle = "Start Window" && startOwner = "OwnerClass"
    && startCtrl = "ControlClass" && startCtrlTitle = "Start Control")
g_Gesture["startHwnd"] := 0
g_Gesture["startContext"] := ""

; ---- 7. 组合武装 ----
g_Gesture["comboUntil"] := 0
Chk("combo-idle", !GestureEngine.ComboActive())
g_Gesture["comboKind"] := "zoom"
g_Gesture["comboUntil"] := A_TickCount + 500
Chk("combo-armed", GestureEngine.ComboActive())
g_Gesture["comboUntil"] := 0
g_Gesture["comboKind"] := ""

; ---- 8. 按下快照默认值 ----
Chk("downmods-field", g_Gesture.Has("downMods"))
Chk("leftcombo-field", g_Gesture.Has("leftCombo"))
Chk("phase-field", g_Gesture.Has("phase") && g_Gesture["phase"] = "idle")

; ---- 9. soak: 200 次预览位图构建+释放无错; 50 段轨迹 Show/Line/Hide 无挂起 ----
; 只观测不修 (Preview 按 HWND 跟踪句柄、Trail XOR 重绘, 先拿基线数据)
soakPts := []
for _, xy in Tpl_BuiltinDefs()["V"][2]
    soakPts.Push(Tpl_Pt(xy[1], xy[2]))
soakOk := 0
Loop 200 {
    try {
        hbm := GesturePreview_PointsBitmap(soakPts, 120, 120)
        if (hbm) {
            DllCall("DeleteObject", "Ptr", hbm)
            soakOk++
        }
    }
}
Chk("soak-bitmap-200", soakOk = 200)
trailOk := true
try {
    GestureTrail_Show()
    Loop 50
        GestureTrail_Line(A_Index * 3, A_Index * 2, A_Index * 3 + 5, A_Index * 2 + 5)
    GestureTrail_Hide()
} catch {
    trailOk := false
}
Chk("soak-trail-50", trailOk)

if (g_Fails > 0) {
    FileAppend("RESULT|FAIL|" . g_Fails . "`n", A_ScriptDir . "\probe_gesture_fix.out.txt")
    ExitApp(1)
}
FileAppend("RESULT|PASS`n", A_ScriptDir . "\probe_gesture_fix.out.txt")
ExitApp(0)
