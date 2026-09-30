#Requires AutoHotkey v2.0
#Warn All, Off

; TC 页整合探针: 动作浏览器识 LauncherCompat 行; Collect 只写 TC 段且路径可清空;
; tc_note 双语与单真相一致
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_vimcfg_tc.ahk
#Include ..\Lib\EasyIni.ahk
#Include ..\Core\ConfigSchema.ahk
#Include ..\Gui\VimCfg_Save.ahk
#Include ..\Gui\VimCfg_TabsKeys.ahk

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

class FakeEdit {
    Value := ""
}

; ---- 静态: 动作浏览器 ----
acSrc := FileRead(A_ScriptDir . "\..\Gui\VimCfg_TabsMisc.ahk", "UTF-8")
Ck("ac-newform", InStr(acSrc, "LauncherCompat\.AddCommand") > 0)
Ck("ac-nooldform", !InStr(acSrc, 'RegisterCommand\s*\(\s*"') && !InStr(acSrc, 'Host("RegisterCommand"'))

; ---- 静态: Collect 只写 TC 段 ----
collectSrc := FileRead(A_ScriptDir . "\..\Gui\VimCfg_TabsKeys.ahk", "UTF-8")
Ck("collect-tc-only", InStr(collectSrc, 'VimCfg_PutDirty("TotalCommander_Config", "TCPath"') > 0
    && !InStr(collectSrc, 'VimCfg_PutDirty("Config", "TCPath"'))
collectBody := SubStr(collectSrc, InStr(collectSrc, "VimCfg_CollectTCTab() {"))
collectBody := SubStr(collectBody, 1, InStr(collectBody, "`n}") + 2)
Ck("collect-noguard", InStr(collectBody, "路径框允许清空") > 0 && !InStr(collectBody, 'if (p != "")'))

; ---- 静态: tc_note 双语 ----
zhSrc := FileRead(A_ScriptDir . "\..\Lang\zh-CN.ini", "UTF-8")
enSrc := FileRead(A_ScriptDir . "\..\Lang\en.ini", "UTF-8")
Ck("note-zh", InStr(zhSrc, "本页全部写入 [TotalCommander_Config]") > 0 && !InStr(zhSrc, "同时写入 [Config]"))
Ck("note-en", InStr(enSrc, "writes to [TotalCommander_Config]") > 0 && !InStr(enSrc, "written to both"))

; ---- 行为: 路径可清空 (空串照样进 dirty, 非 no-op) ----
global g_Conf := EasyIni()
global g_VimCfg := Map("dirty", Map())
g_Conf.Set("TotalCommander_Config", "TCPath", "D:\tc\totalcmd64.exe")
g_VimCfg["tc_path"] := FakeEdit()
g_VimCfg["tc_path"].Value := ""
g_VimCfg["tc_ini"] := FakeEdit()
g_VimCfg["tc_savemark"] := FakeEdit()
g_VimCfg["tc_iconsize"] := FakeEdit()
g_VimCfg["tc_iconsize"].Value := "20"
g_VimCfg["tc_asdlg"] := FakeEdit()
g_VimCfg["tc_exclude"] := FakeEdit()
VimCfg_CollectTCTab()
dirtyKey := "TotalCommander_Config" . Chr(1) . "TCPath"
Ck("clear-dirty", g_VimCfg["dirty"].Has(dirtyKey)
    && g_VimCfg["dirty"][dirtyKey]["val"] = "", "dirty=" . g_VimCfg["dirty"].Count)

; ---- 行为: 有值照常写 (与预填不同才进 dirty) ----
g_VimCfg["dirty"] := Map()
g_VimCfg["tc_path"].Value := "D:\tc\newpath\totalcmd64.exe"
VimCfg_CollectTCTab()
Ck("set-dirty", g_VimCfg["dirty"].Has(dirtyKey)
    && g_VimCfg["dirty"][dirtyKey]["val"] = "D:\tc\newpath\totalcmd64.exe")

if (g_Fail > 0) {
    FileAppend("probe-vimcfg-tc FAIL: " . g_Fail . "`n", "*")
    ExitApp(1)
}
FileAppend("probe-vimcfg-tc-ok`n", "*")
ExitApp(0)
