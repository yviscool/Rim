#Requires AutoHotkey v2.0
#Warn All, Off

; 配置 scope 诚实性探针: 徽标必须与真实生效路径一致
; (语言rebuild有订阅、CPL/快捷方式live有订阅、TC段一律restart)
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_config_scope.ahk
#Include ..\Core\ConfigSchema.ahk
#Include ..\Gui\VimCfg_Save.ahk

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

; ---- schema scope ----
Ck("scope-cpl-live", CfgScope("Config", "LoadControlPanelFunctions") = "live")
Ck("scope-sendto-live", CfgScope("Config", "CreateSendToLnk") = "live")
Ck("scope-startup-live", CfgScope("Config", "CreateStartupLnk") = "live")
Ck("scope-lang-rebuild", CfgScope("Config", "Language") = "rebuild")

; ---- Rim.ahk 订阅接线 (静态) ----
rimSrc := FileRead(A_ScriptDir . "\..\Rim.ahk", "UTF-8")
Ck("sub-lang-gui", InStr(rimSrc, 'CfgSubscribe("Config", "Language", (*) => Launcher_ApplyGui())') > 0)
Ck("sub-cpl", InStr(rimSrc, 'CfgSubscribe("Config", "LoadControlPanelFunctions", (*) => LoadFiles())') > 0)
Ck("sub-sendto", InStr(rimSrc, 'CfgSubscribe("Config", "CreateSendToLnk", (*) => ChangePath())') > 0)
Ck("sub-startup", InStr(rimSrc, 'CfgSubscribe("Config", "CreateStartupLnk", (*) => ChangePath())') > 0)

; ---- TC 段一律 restart (Setup 时读一次, 无订阅) ----
Ck("scope-tc-asdlg", VimCfg_ItemScope("TotalCommander_Config", "AsOpenFileDialog", false) = "restart")
Ck("scope-tc-path", VimCfg_ItemScope("TotalCommander_Config", "TCPath", false) = "restart")
Ck("scope-tc-exclude", VimCfg_ItemScope("TotalCommander_Config", "OpenFileDialogExclude", false) = "restart")

; ---- TC 页无死控件引用 ----
tcSrc := FileRead(A_ScriptDir . "\..\Gui\VimCfg_TabsKeys.ahk", "UTF-8")
Ck("tc-no-dead", !InStr(tcSrc, "tc_savemark") && !InStr(tcSrc, "tc_iconsize")
    && !InStr(tcSrc, '"SaveMark"') && !InStr(tcSrc, '"MenuIconSize"'))

if (g_Fail > 0) {
    FileAppend("probe-config-scope FAIL: " . g_Fail . "`n", "*")
    ExitApp(1)
}
FileAppend("probe-config-scope-ok`n", "*")
ExitApp(0)
