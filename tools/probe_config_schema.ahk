#Requires AutoHotkey v2.0
#Warn All, Off
FileEncoding "UTF-8"

; 配置中心契约探针: schema 完整性 / CfgGet-Validate / 发布订阅 / WriteIni事务
; 判定: 0 退出 + 无 FAIL 行 + probe_config_schema.out.txt 有 ok 标记
#Include ..\Core\I18n.ahk
#Include ..\Core\Common.ahk
#Include ..\Core\ConfigSchema.ahk
#Include ..\Core\ConfigTxn.ahk
#Include ..\Gui\VimConfigUI.ahk
#Include ..\Gui\VimCfg_Save.ahk
#Include ..\Gui\VimCfg_Schema.ahk
#Include ..\Gui\VimCfg_TabsKeys.ahk
#Include ..\Gui\VimCfg_TabsMisc.ahk

global g_ProbeFails := 0
global g_ProbeHits := []

Check(name, cond) {
    global g_ProbeFails
    if (cond) {
        FileAppend("PASS: " . name . "`n", "*")
    } else {
        g_ProbeFails++
        FileAppend("FAIL: " . name . "`n", "*")
    }
}

class ConfStub2 {
    Get(sec, key, def := "") {
        if (sec = "Config" && key = "HistorySize")
            return "stubval"
        return def
    }
}

; ---- 语言固定英文, 断言 label/help 零缺键 (缺键时 T 回落 key 本身) ----
I18nSetLang("en", false)

Check("schema-count-51", g_CfgSchema.Length = 51)
seen := Map()
dupFound := false
typeOk := true
scopeOk := true
minmaxOk := true
labelOk := true
for spec in g_CfgSchema {
    sk := spec["sec"] . Chr(1) . spec["key"]
    if (seen.Has(sk))
        dupFound := true
    seen[sk] := true
    kind := spec["type"]
    if (kind != "bool" && kind != "text" && kind != "int" && kind != "lang" && kind != "skin" && kind != "choice" && kind != "slider")
        typeOk := false
    scope := spec["scope"]
    if (scope != "live" && scope != "rebuild" && scope != "restart")
        scopeOk := false
    if ((kind = "int" || kind = "slider") && (!spec.Has("min") || !spec.Has("max") || !(spec["min"] < spec["max"])))
        minmaxOk := false
    if (T(spec["label"]) = spec["label"] || T(spec["help"]) = spec["help"])
        labelOk := false
}
Check("schema-unique", !dupFound)
Check("schema-types", typeOk)
Check("schema-scopes", scopeOk)
Check("schema-minmax", minmaxOk)
Check("schema-i18n", labelOk)

; ---- CfgGet: 无 g_Conf 回 default; 有桩回桩值; 未知键回传入 def ----
Check("get-default", CfgGet("Config", "HistorySize") = "100")
Check("get-default-skin", CfgGet("Gui", "Skin") = "New")
Check("get-unknown-def", CfgGet("Nope", "Nope", "dd") = "dd")
Check("get-unknown-empty", CfgGet("Nope", "Nope") = "")
global g_Conf := ConfStub2()
Check("get-stub", CfgGet("Config", "HistorySize") = "stubval")
Check("get-stub-miss-default", CfgGet("Config", "RunOnce") = "0")
g_Conf := ""

; ---- CfgValidate ----
Check("val-int-ok", CfgValidate("Config", "HistorySize", "200") = "")
Check("val-int-bad", CfgValidate("Config", "HistorySize", "abc") != "")
Check("val-int-range", CfgValidate("Config", "HistorySize", "9999") != "")
Check("val-bool-bad", CfgValidate("Config", "RunOnce", "2") != "")
Check("val-bool-ok", CfgValidate("Config", "RunOnce", "1") = "")
Check("val-color-ok", CfgValidate("Gui", "FontColor", "ff00aa") = "")
Check("val-color-bad", CfgValidate("Gui", "FontColor", "zzzzzz") != "")
Check("val-unknown-passthrough", CfgValidate("Nope", "Nope", "anything") = "")

; ---- 发布订阅 ----
global g_ProbeHits := []
ProbeHitA(val, sec, key) {
    global g_ProbeHits
    g_ProbeHits.Push("A:" . val)
}
ProbeHitB(val, sec, key) {
    global g_ProbeHits
    g_ProbeHits.Push("B:" . val)
}
ProbeHitBoom(val, sec, key) {
    x := 1 + "x"
}
tokA := CfgSubscribe("Config", "RunOnce", ProbeHitA)
tokB := CfgSubscribe("Config", "RunOnce", ProbeHitB)
tokBoom := CfgSubscribe("Config", "RunOnce", ProbeHitBoom)
pub := CfgPublish([Map("sec", "Config", "key", "RunOnce", "val", "1")])
Check("pub-delivers", g_ProbeHits.Length = 2)
Check("pub-isolates-thrower", !pub["ok"] && pub["failed"].Length = 1)
Check("unsub", CfgUnsubscribe(tokA) && CfgUnsubscribe(tokB) && CfgUnsubscribe(tokBoom))
Check("unsub-unknown", !CfgUnsubscribe(999999))
global g_ProbeHits := []
CfgPublish([Map("sec", "Config", "key", "RunOnce", "val", "1")])
Check("pub-quiet-after-unsub", g_ProbeHits.Length = 0)
Check("scope-unknown-restart", CfgScope("Nope", "Nope") = "restart")
Check("scope-known", CfgScope("Config", "HistorySize") = "live")

; ---- VimCfg_WriteIni 保注释写回 ----
tmpIni := A_Temp . "\probe_cfg_schema.ini"
try FileDelete(tmpIni)
FileAppend("; head comment`r`n[Config]`r`nHistorySize=100`r`nOldKey=gone`r`n`r`n[Gui]`r`nSkin=New`r`n", tmpIni, "UTF-8")
final := Map()
final["Config" . Chr(1) . "HistorySize"] := Map("key", "HistorySize", "val", "200", "del", false)
final["Config" . Chr(1) . "OldKey"] := Map("key", "OldKey", "val", "", "del", true)
final["Config" . Chr(1) . "FreshKey"] := Map("key", "FreshKey", "val", "1", "del", false)
final["BrandNew" . Chr(1) . "K"] := Map("key", "K", "val", "v", "del", false)
VimCfg_WriteIni(tmpIni, final)
back := FileRead(tmpIni, "UTF-8")
Check("write-update", InStr(back, "HistorySize=200") > 0)
Check("write-del", !InStr(back, "OldKey="))
Check("write-newkey", InStr(back, "FreshKey=1") > 0)
Check("write-newsec", InStr(back, "[BrandNew]") > 0)
Check("write-comment", InStr(back, "; head comment") > 0)
Check("write-skin-kept", InStr(back, "Skin=New") > 0)
try FileDelete(tmpIni)

; ---- VimCfg_ValidateDirty + ItemScope ----
dirty2 := Map()
dirty2["Config" . Chr(1) . "HistorySize"] := Map("key", "HistorySize", "val", "abc", "del", false)
dirty2["Config" . Chr(1) . "RunOnce"] := Map("key", "RunOnce", "val", "1", "del", false)
errs := VimCfg_ValidateDirty(dirty2)
Check("dirty-validation", errs.Length = 1)
Check("scope-item-plugins", VimCfg_ItemScope("Plugins", "X", false) = "restart")
Check("scope-item-del", VimCfg_ItemScope("TTOTAL_CMD", "j", true) = "restart")
Check("scope-item-schema", VimCfg_ItemScope("Config", "HistorySize", false) = "live")
Check("scope-item-vimadd", VimCfg_ItemScope("TTOTAL_CMD", "j", false) = "live")

; ---- 订阅契约: 全仓 CfgSubscribe("sec", "key") 目标必须在 schema 内 (防手误订阅不存在的键) ----
subFiles := [A_ScriptDir . "\..\Rim.ahk"]
Loop Files, A_ScriptDir . "\..\Core\*.ahk" {
    subFiles.Push(A_LoopFileFullPath)
}
Loop Files, A_ScriptDir . "\..\Gui\*.ahk" {
    subFiles.Push(A_LoopFileFullPath)
}
Loop Files, A_ScriptDir . "\..\Plugins\*.ahk" {
    subFiles.Push(A_LoopFileFullPath)
}
subTotal := 0
subBad := []
for subFile in subFiles {
    content := ""
    try content := FileRead(subFile, "UTF-8")
    catch {
        continue
    }
    pos := 1
    while (pos := RegExMatch(content, 'CfgSubscribe\("([^"]+)", "([^"]+)"', &subM, pos)) {
        subTotal++
        if (!IsObject(CfgFind(subM[1], subM[2])))
            subBad.Push(subFile . ": [" . subM[1] . "] " . subM[2])
        pos := pos + StrLen(subM[0])
    }
}
Check("sub-targets-known", subTotal > 0 && subBad.Length = 0)
for badEntry in subBad
    FileAppend("FAIL detail: " . badEntry . "`n", "*")

; ---- VimCfg_LogHistory: 单行格式 + 可解析回 dirty ----
hisLog := A_Temp . "\probe_cfg_history.log"
try FileDelete(hisLog)
hisDirty := Map()
hisDirty["Config" . Chr(1) . "HistorySize"] := Map("key", "HistorySize", "val", "200", "del", false)
hisDirty["TTOTAL_CMD" . Chr(1) . "j"] := Map("key", "j", "val", "", "del", true)
hisUndo := [Map("sec", "Config", "key", "HistorySize", "had", true, "val", "100")
    , Map("sec", "TTOTAL_CMD", "key", "j", "had", true, "val", "<down>")]
VimCfg_LogHistory(hisDirty, hisUndo, "APPLIED", [], "", hisLog)
hisContent := FileRead(hisLog, "UTF-8")
Check("history-line", InStr(hisContent, "APPLIED") > 0 && InStr(hisContent, "[Config] HistorySize: 100 → 200") > 0)
Check("history-del", InStr(hisContent, "(delete)") > 0)
try FileDelete(hisLog)

if (g_ProbeFails > 0) {
    FileAppend("FAIL total=" . g_ProbeFails . "`n", "*")
    ExitApp(1)
}
try FileDelete(A_ScriptDir . "\..\probe_config_schema.out.txt")
FileAppend("probe-config-schema-ok`n", A_ScriptDir . "\..\probe_config_schema.out.txt")
ExitApp(0)
