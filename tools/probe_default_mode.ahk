#Requires AutoHotkey v2.0
#Warn All, Off

; 回归探针: 窗口默认模式 default_mode
; 1) VimdApplyDefaultMode 真逻辑 (内存态 EasyIni, 不碰用户 ini 文件):
;    合法→true 并切模式; 非法值/缺键/缺窗→false 且模式不动
; 2) Rim.ahk 接线: 纯覆盖节 + 按键循环跳过 + 编译压轴三处俱在
; 3) DoSaveBody 即时生效拦截 + 配置中心 UI 接线俱在 (源码断言)
; 4) 真实 rim.ini 三窗 default_mode=insert
; T 桩必须保留参数 (告警文本带段名, 否则 InStr 永远匹配不上; 纯 key 形态与生产一致)
T(key, args*) {
    out := String(key)
    for _, a in args {
        try out .= "|" . String(a)
        catch {
        }
    }
    return out
}

#Include ..\Lib\EasyIni.ahk
#Include ..\Core\Plugin.ahk
#Include ..\Core\ConfigSchema.ahk
#Include ..\Core\Engine.ahk
#Include ..\Gui\VimCfg_TabsMisc.ahk
#Include ..\Plugins\Browser.ahk

Assert(cond, msg) {
    if (!cond) {
        FileAppend("FAIL: " . msg . "`n", "*")
        ExitApp(1)
    }
    FileAppend("PASS: " . msg . "`n", "*")
}

ReadNorm(path) {
    content := FileRead(path, "UTF-8")
    if (SubStr(content, 1, 1) = Chr(0xFEFF))
        content := SubStr(content, 2)
    return StrReplace(content, "`r`n", "`n")
}

global g_Conf := EasyIni(A_ScriptDir . "\..\Conf\rim.ini")
Assert(IsObject(g_Conf), "conf-load")

global g_VimEngine := VimEngine()
Browser_Keymaps(g_VimEngine)
g_VimEngine.SetWin("W1", "C1", "e1.exe")
w1 := g_VimEngine.GetWin("W1")
Assert(w1.currentMode = "normal", "init-normal")

; --- 1) 真逻辑 ---
g_Conf.Set("W1", "default_mode", "insert")
Assert(VimdApplyDefaultMode("W1") = true, "apply-true")
Assert(w1.currentMode = "insert", "mode-insert")
g_Conf.Set("W1", "default_mode", "visual")
Assert(VimdApplyDefaultMode("W1") = false, "apply-badmode-false")
Assert(w1.currentMode = "insert", "mode-unchanged-bad")
g_Conf.DeleteKey("W1", "default_mode")
Assert(VimdApplyDefaultMode("W1") = false, "apply-missing-false")
Assert(VimdApplyDefaultMode("NoSuchWin") = false, "apply-nowin-false")
; 回切 normal 照样生效 (双向)
g_Conf.Set("W1", "default_mode", "normal")
Assert(VimdApplyDefaultMode("W1") = true, "apply-back-true")
Assert(w1.currentMode = "normal", "mode-normal")

; --- 2) Rim.ahk 接线 ---
rimSrc := ReadNorm(A_ScriptDir . "\..\Rim.ahk")
n := 0
pos := 1
while (pos := InStr(rimSrc, "VimdApplyDefaultMode(sectionName)", false, pos)) {
    n++
    pos += 10
}
Assert(n >= 2, "rim-two-calls")
Assert(InStr(rimSrc, '_k = "default_mode"') > 0, "rim-skip-key")

; --- 3) 保存 + UI 接线 ---
saveSrc := ReadNorm(A_ScriptDir . "\..\Gui\VimCfg_Save.ahk")
Assert(InStr(saveSrc, 'd["key"] = "default_mode"') > 0, "save-intercept")
keysSrc := ReadNorm(A_ScriptDir . "\..\Gui\VimCfg_TabsKeys.ahk")
Assert(InStr(keysSrc, '"kdef"') > 0, "ui-combo")
Assert(InStr(keysSrc, "VimCfg_KeyDefModeReload()") > 0, "ui-reload")
Assert(InStr(keysSrc, "VimCfg_KeyDefModeChange") > 0, "ui-change")

; --- 4) 真实配置含首个用户 ---
iniSrc := ReadNorm(A_ScriptDir . "\..\Conf\rim.ini")
Assert(InStr(iniSrc, "default_mode=insert") > 0, "ini-value")
tplSrc := ReadNorm(A_ScriptDir . "\..\Conf\rim.template.ini")
Assert(InStr(tplSrc, "default_mode=insert") > 0, "tpl-value")

; --- 5) 健康检查: 纯覆盖节不误报, 拼错窗名照样报 ---
res := VimCfg_CheckConflicts()
hit := ""
for _, item in res {
    try txt := String(item["text"])
    catch {
        continue
    }
    for _, wn in ["Browser_Chrome", "Browser_Edge", "Browser_Firefox"] {
        if InStr(txt, wn)
            hit .= wn . ";"
    }
}
Assert(hit = "", "health-no-false-positive")
; 反例: 无引擎窗的纯覆盖节必须告警 (证明检查没被关掉)
try g_Conf.AddSection("Typo_WinX")
catch {
}
try g_Conf.Set("Typo_WinX", "default_mode", "insert")
catch {
}
res := VimCfg_CheckConflicts()
found := false
for _, item in res {
    try {
        if InStr(String(item["text"]), "Typo_WinX")
            found := true
    }
}
Assert(found, "health-typo-still-warns")
try g_Conf.DeleteSection("Typo_WinX")
catch {
}

try FileDelete(A_ScriptDir . "\..\probe_default_mode.out.txt")
FileAppend("probe-default-mode-ok`n", A_ScriptDir . "\..\probe_default_mode.out.txt")
ExitApp(0)
