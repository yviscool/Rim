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
Chk("norm-tpl", Gesture_Normalize("TPL:u") = "TPL:U")
Chk("norm-dir", Gesture_Normalize("dir:u_d") = "DIR:U_D")
Chk("norm-chain", Gesture_Normalize("d_r") = "D_R")
Chk("normfull-mods", Gesture_NormalizeFull("ctrl + d_r") = "CTRL+D_R")
Chk("normfull-tpl", Gesture_NormalizeFull("TPL:u") = "TPL:U")
Chk("normfull-modtpl", Gesture_NormalizeFull("ctrl+TPL:u") = "CTRL+TPL:U")

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

; ---- 3. 链优先 + TPL 全局覆盖 ----
g_GestureMap := Map("U", "key|^c", "TPL:U", "key|^z")
res := Gesture_ResolveStroke("U", [{x: 0, y: 0}], "x.exe", "cls", "", "")
Chk("chain-first", res[1] = "key|^c")
res2 := Gesture_ResolveTpl("", rawU, "x.exe", "cls", "", "")
Chk("tpl-global-override", res2[1] = "key|^z")

; ---- 4. 控件级应用匹配 ----
g_GestureApps := [{name: "Desk", exe: "explorer.exe", cls: "", title: "", titleRx: "",
    ownerCls: "WorkerW|Progman", ctrlCls: "SysListView32", ctrlTitle: "FolderView", noglobal: 0, map: Map()}]
hit := Gesture_MatchApp("explorer.exe", "Progman", "", "WorkerW|Shell_TrayWnd", "SysListView32", "FolderView")
Chk("app-ctrl-hit", IsObject(hit) && hit.name = "Desk")
miss := Gesture_MatchApp("explorer.exe", "Progman", "", "OtherOwner", "OtherCls", "FolderView")
Chk("app-ctrl-miss", !IsObject(miss))

; ---- 5. TrailColor 生效 ----
g_Gesture["trailColor"] := "45ABFF"
Chk("trail-color", GestureTrail_Color() = 0xFFAB45)
g_Gesture["trailColor"] := "notacolor"
Chk("trail-color-fallback", GestureTrail_Color() = 0xFFFFFF)

; ---- 6. 起点窗口 ----
g_Gesture["startHwnd"] := 0
Chk("actionwin-fallback", Gesture_ActionWin() = "A")
g_Gesture["startHwnd"] := 12345
g_Gesture["startContext"] := {rootHwnd: 12345, exe: "start.exe", cls: "StartClass",
    title: "Start Window", ownerCls: "OwnerClass", ctrlCls: "ControlClass", ctrlTitle: "Start Control"}
Chk("actionwin-start", Gesture_ActionWin() = "ahk_id 12345")
Gesture_StartIds(&startExe, &startCls, &startTitle, &startOwner, &startCtrl, &startCtrlTitle)
Chk("start-context-snapshot", startExe = "start.exe" && startCls = "StartClass"
    && startTitle = "Start Window" && startOwner = "OwnerClass"
    && startCtrl = "ControlClass" && startCtrlTitle = "Start Control")
g_Gesture["startHwnd"] := 0
g_Gesture["startContext"] := ""

; ---- 7. 组合武装 ----
g_Gesture["comboUntil"] := 0
Chk("combo-idle", !Gesture_ComboActive())
g_Gesture["comboKind"] := "zoom"
g_Gesture["comboUntil"] := A_TickCount + 500
Chk("combo-armed", Gesture_ComboActive())
g_Gesture["comboUntil"] := 0
g_Gesture["comboKind"] := ""

; ---- 8. 按下快照默认值 ----
Chk("downmods-field", g_Gesture.Has("downMods"))
Chk("leftcombo-field", g_Gesture.Has("leftCombo"))

; ---- 9. SP 真实样本 + 动作对齐 ----
Chk("tpl-U-dualsample", g_Templates["U"].samples.Length >= 2)
Chk("tpl-S-action", Tpl_Get("S").action = "run|D:\software\SublimeText\sublime_text.exe")
Chk("tpl-e-noop", Tpl_Get("e").action = "function|Gesture_NoOp")
mS := Tpl_Match(rawU, 6)
Chk("tpl-real-U-wins", mS[1] = "U" && mS[2] >= 75)

; ---- 10. Browser direction and template scope ----
browserMap := Map("U_UR", "key|!{Right}", "U_UL", "key|!{Left}", "R_U", "key|{F11}",
    "TPL:Z", "combo|zoom", "TPL:B", "key|^d", "TPL:J", "key|^j",
    "TPL:H", "key|{Browser_Home}", "TPL:3", "key|^t")
g_GestureApps.Push({name: "Browsers", exe: "chrome.exe | firefox.exe | iexplore.exe", cls: "",
    title: "", titleRx: "", ownerCls: "", ctrlCls: "", ctrlTitle: "",
    noglobal: 0, map: browserMap})
resB := Gesture_ResolveFor("U_UR", "chrome.exe", "Chrome_WidgetWin_1", "", "")
Chk("browsers-up-right", resB[1] = "key|!{Right}")
resBLeft := Gesture_ResolveFor("U_UL", "chrome.exe", "Chrome_WidgetWin_1", "", "")
Chk("browsers-up-left", resBLeft[1] = "key|!{Left}")
resB2 := Gesture_ResolveFor("R_U", "chrome.exe", "Chrome_WidgetWin_1", "", "")
Chk("browsers-r-u", resB2[1] = "key|{F11}")
resB3 := Gesture_ResolveFor("U_UR", "notepad.exe", "Notepad", "", "")
Chk("browsers-scope", resB3[1] = "")

builtinDefs := Tpl_BuiltinDefs()
for tplName in ["Z", "B", "J", "h", "3"] {
    tplPts := []
    for _, waypoint in builtinDefs[tplName][2]
        tplPts.Push(Tpl_Pt(waypoint[1] + 0.0, waypoint[2] + 0.0))
    explicitMatch := Tpl_Match(tplPts, 6, tplName)
    Chk("browser-tpl-explicit-match-" . tplName,
        explicitMatch[1] = tplName && explicitMatch[2] >= 75)
    tplRes := Gesture_ResolveStroke("TPL:" . tplName, tplPts, "chrome.exe", "Chrome_WidgetWin_1", "")
    expected := (tplName = "Z") ? "combo|zoom" : browserMap["TPL:" . StrUpper(tplName)]
    Chk("browser-tpl-" . tplName, tplRes[1] = expected)
    outsideRes := Gesture_ResolveStroke("TPL:" . tplName, tplPts, "notepad.exe", "Notepad", "")
    Chk("browser-tpl-scope-" . tplName, outsideRes[1] = "function|Gesture_NoOp")
}
Chk("tpl-lowercase-normalized", Gesture_NormalizeFull("TPL:h") = "TPL:H")

if (g_Fails > 0) {
    FileAppend("RESULT|FAIL|" . g_Fails . "`n", A_ScriptDir . "\probe_gesture_fix.out.txt")
    ExitApp(1)
}
FileAppend("RESULT|PASS`n", A_ScriptDir . "\probe_gesture_fix.out.txt")
ExitApp(0)
