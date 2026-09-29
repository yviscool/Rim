#Requires AutoHotkey v2.0
#Warn All, Off

; 搜索端到端: 真 SearchCommand + 真 Registry (294 行全量 ingestion) + 真评分, 止于执行
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_search_e2e.ahk
#Include ..\Core\Command.ahk
#Include ..\Core\SmartInput.ahk
#Include ..\Core\Files.ahk
#Include ..\Core\Search.ahk
#Include ..\Lib\EasyIni.ahk

global g_CommandAlias := Map()

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

CfgGet(sec, key, def := "") {
    if (sec = "Config" && key = "ShowFileExt")
        return "0"
    if (sec = "Config" && key = "SearchFullPath")
        return "0"
    if (sec = "Config" && key = "RunIfOnlyOne")
        return "0"
    return def
}

T(key, params*) {
    return key
}

TypeLabel(type) {
    return type
}

global g_CapResult := ""
DisplaySearchResult(result) {
    global g_CapResult
    g_CapResult := result
}

; ---- 环境 (对齐 Rim.ahk 全局) ----
global g_ExcludedCommandsObj := Map()
global g_SkinConf := Map("HideCol2", "0", "ShowCurrentCommand", "0")
global g_FirstChar := Ord("a")
global g_DisplayRows := 11
global g_CurrentInput := "weixin"
global g_CurrentCommand := ""
global g_CurrentCommandList := []
global g_UseFallbackCommands := false
global g_EnableTCMatch := false
global g_AutoConf := EasyIni()
global g_FallbackCommands := ["function | AhkRun | ahkrun"]

; ---- 全量 ingestion (真 SearchFileList.txt) ----
content := FileRead(A_ScriptDir . "\..\Conf\SearchFileList.txt", "UTF-8")
nIng := 0
Loop Parse, content, "`n", "`r" {
    line := Trim(A_LoopField)
    if (line = "")
        continue
    RimCommand.IngestRow(line)
    nIng++
}
FileAppend("INFO: ingested=" . nIng . " registry=" . RimCommand.Registry.Count . "`n", "*")
RimCommand.Register("ShutdownTimer", "ShutdownTimer", (*) => 0, Map("Description", "定时关机"))
; 别名行收编 (Misc 同款: 名进 Name, 不是 content)
LauncherCompat.AddCommand("Google", "url", "https://www.google.com/search?q={query}", "Google搜索")

; ---- 搜 weixin ----
SearchCommand("weixin")
Ck("list-nonempty", g_CurrentCommandList.Length >= 3, String(g_CurrentCommandList.Length))
Ck("head-is-file", SubStr(g_CurrentCommand, 1, 14) = "command | file", g_CurrentCommand)
Ck("result-shows-weixin", InStr(g_CapResult, "Weixin") > 0)
Ck("result-no-raw-id", !InStr(g_CapResult, "file:D:"))
FileAppend("INFO: head=[" . g_CurrentCommand . "]`n", "*")

; ---- 回车即执行形状 ----
parsed := CmdLine_Parse(g_CurrentCommand)
Ck("enter-parse", parsed["type"] = "command" && parsed["cmd"] != "", parsed["type"] . "/" . parsed["cmd"])
Ck("enter-registry", RimCommand.Registry.Has(parsed["cmd"]), parsed["cmd"])
tgt := RimCommand.Get(parsed["cmd"])
Ck("enter-action", IsObject(tgt) && SubStr(String(tgt.Action), 1, 5) = "file|", IsObject(tgt) ? String(tgt.Action) : "noobj")

; ---- 别名行: 名是 Google 不是 URL ----
grow := RimCommand.SearchRow(RimCommand.Get("url:https://www.google.com/search?q={query}"))
Ck("alias-name", grow["name"] == "Google", grow["name"])
Ck("alias-show", grow["show"] == "url | Google | Google搜索", grow["show"])

; ---- "Google koa.js" 整句零命中 → 退化搜命令头 ----
SearchCommand("Google koa.js")
Ck("headmatch-nonempty", g_CurrentCommandList.Length >= 1, String(g_CurrentCommandList.Length))
Ck("headmatch-is-google", InStr(g_CurrentCommand, "url:https://www.google.com/search?q={query}") > 0, g_CurrentCommand)

; ---- 冻结: 选中 Google 后输参不再重搜 ----
g_CurrentCommand := "command | url:https://www.google.com/search?q={query}"
Ck("freeze-google", ShouldFreezeInput("Google koa.js") == true)
Ck("freeze-bare", ShouldFreezeInput("ShutdownTimer 30") == false)

if (g_Fail > 0) {
    FileAppend("probe-search-e2e FAIL: " . g_Fail . "`n", "*")
    ExitApp(1)
}
FileAppend("probe-search-e2e-ok`n", "*")
ExitApp(0)
