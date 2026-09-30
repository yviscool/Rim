#Requires AutoHotkey v2.0
#Warn All, Off

; TC 路径单真相探针: 唯一写入口=TC 页→[TotalCommander_Config];
; 读经 TC_EffPath (TC 段优先, [Config] 兜底); 启动器页无 TCPath 行
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_tc_singletruth.ahk
#Include ..\Lib\EasyIni.ahk
#Include ..\Core\ConfigSchema.ahk
#Include ..\Core\Utils.ahk

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

; ---- 静态: schema 无 Config.TCPath (启动器页重复行消失) ----
hasDup := false
for spec in g_CfgSchema {
    if (spec["sec"] = "Config" && spec["key"] = "TCPath")
        hasDup := true
}
Ck("schema-no-dup", !hasDup)

; ---- 静态: Collect 只写 TC 段 ----
collectSrc := FileRead(A_ScriptDir . "\..\Gui\VimCfg_TabsKeys.ahk", "UTF-8")
Ck("collect-tc-only", InStr(collectSrc, 'VimCfg_PutDirty("TotalCommander_Config", "TCPath"') > 0
    && !InStr(collectSrc, 'VimCfg_PutDirty("Config", "TCPath"'))
; ---- 静态: 6 处读取经 TC_EffPath ----
for _, f in ["Core\Execution.ahk", "Core\Command.ahk", "Core\Workspace.ahk"
    , "Plugins\Explorer.ahk", "Plugins\TCDialog.ahk", "Plugins\TotalCommander.ahk"] {
    src := FileRead(A_ScriptDir . "\..\" . f, "UTF-8")
    Ck("reader-" . f, InStr(src, "TC_EffPath()") > 0, f)
    Ck("reader-noraw-" . f, !InStr(src, 'CfgGet("Config", "TCPath"')
        && !InStr(src, '"TotalCommander_Config", "TCPath", Rim.config.Get("Config"'), f)
}

; ---- 行为: TC_EffPath 优先级 (真 g_Conf 驱动) ----
global g_Conf := EasyIni()
g_Conf.Set("TotalCommander_Config", "TCPath", "D:\tc\totalcmd64.exe")
g_Conf.Set("Config", "TCPath", "D:\old\tc.exe")
Ck("pref-tc", TC_EffPath() = "D:\tc\totalcmd64.exe", TC_EffPath())
g_Conf.DeleteKey("TotalCommander_Config", "TCPath")
Ck("fallback-config", TC_EffPath() = "D:\old\tc.exe", TC_EffPath())
g_Conf.DeleteKey("Config", "TCPath")
Ck("empty-missing", TC_EffPath() = "")

if (g_Fail > 0) {
    FileAppend("probe-tc-singletruth FAIL: " . g_Fail . "`n", "*")
    ExitApp(1)
}
FileAppend("probe-tc-singletruth-ok`n", "*")
ExitApp(0)
