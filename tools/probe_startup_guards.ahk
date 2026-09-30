#Requires AutoHotkey v2.0
#Warn All, Off

; 启动期裸访问探针: v2 Map 缺键即抛, 启动顶层代码禁裸键访问 (TCMatchPath 崩过一次)
; 段级访问 (for in g_Conf["段"]) 返回空 Map, 安全, 不管
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_startup_guards.ahk

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

rimSrc := FileRead(A_ScriptDir . "\..\Rim.ahk", "UTF-8")
; 规则: 键级裸访问必须与 try 同行 (单行守卫); 否则只能走 CfgGet
BadBare(src, pat) {
    Loop Parse, src, "`n", "`r" {
        if (RegExMatch(A_LoopField, pat) && !InStr(A_LoopField, "try ")) {
            ; CfgGet 行豁免 (函数内已兜底)
            if (!InStr(A_LoopField, "CfgGet("))
                return A_LoopField
        }
    }
    return ""
}
Ck("no-bare-config-key", (bad := BadBare(rimSrc, 'g_Conf\["Config"\]\["\w+"\]')) = "", bad)
Ck("no-bare-gui-key", (bad := BadBare(rimSrc, 'g_Conf\["Gui"\]\["\w+"\]')) = "", bad)
Ck("no-bare-auto-key", (bad := BadBare(rimSrc, 'g_AutoConf\["Auto"\]\["\w+"\]')) = "", bad)
Ck("tcmatch-cfgget", InStr(rimSrc, 'TCMatchInit(CfgGet(') > 0)
Ck("skin-guarded", InStr(rimSrc, 'try skinName := g_Conf["Gui"]["Skin"]') > 0)
; 启动阶段打点成对出现 (plugin-init/commands/files/gui/hotkeys/state/vim/gestures/finalize),
; 错误网按阶段归因, BootMark 序列原样保留 (见 probe_startup_marks)
for _, ph in ["plugin-init", "commands", "files", "gui", "hotkeys", "state", "vim", "gestures", "finalize"] {
    Ck("phase-" . ph, InStr(rimSrc, 'RimPhaseBegin("' . ph . '")') > 0 && InStr(rimSrc, 'RimPhaseEnd("' . ph . '")') > 0)
}
Ck("phase-query", InStr(rimSrc, "BootPhases() {") > 0)
Ck("phase-onerror", InStr(rimSrc, "g_BootPhase") > 0)

if (g_Fail > 0) {
    FileAppend("probe-startup-guards FAIL: " . g_Fail . "`n", "*")
    ExitApp(1)
}
FileAppend("probe-startup-guards-ok`n", "*")
ExitApp(0)
