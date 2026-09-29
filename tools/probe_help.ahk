#Requires AutoHotkey v2.0
#Warn All, Off

; Help 显示组装探针: KeyHelpText + GetAllFunctions + Help() 全链 (止于显示).
; KeyHelp() 本体弹 ToolTip, 只测文本不执行 (真机手动).
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_help.ahk
#Include ..\Core\Plugin.ahk
#Include ..\Core\Command.ahk
#Include ..\Core\Common.ahk
#Include ..\Core\Execution.ahk
#Include ..\Core\GUI.ahk
#Include ..\Core\Hotkeys.Commands.ahk

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
    out := key
    i := 1
    for _, p in params {
        out := StrReplace(out, "{" . i . "}", String(p))
        i++
    }
    return out
}

CfgGet(sec, key, def := "") {
    return def
}

RimLog(level, msg, err := "") {
}

global g_DisplayEdit := {Value: ""}
global g_UseDisplay := false
global g_RowActive := false

global g_SkinConf := Map("HideCol2", "0", "HideCol4IfEmpty", "1", "DisplayCol3MaxLength", "30", "DisplayCol4MaxLength", "36", "ShowCurrentCommand", "1")
global g_ExcludedCommandsObj := Map()

; ---- GetAllFunctions 列出来自 Registry Kind=function 的行 ----
RimCommand.IngestRow("reload | function | RestartRunZ | 重启")
RimCommand.IngestRow("exit | function | ExitRunZ | 退出")
RimCommand.Register("CalcX", "CalcX", (*) => 0, Map("Description", "计算器"))
try {
    fns := GetAllFunctions()
    Ck("getallfunctions-rows", InStr(fns, "reload") > 0 && InStr(fns, "exit") > 0, SubStr(fns, 1, 80))
    Ck("getallfunctions-skip-command", !InStr(fns, "CalcX"), SubStr(fns, 1, 80))
} catch as e {
    Ck("getallfunctions-no-throw", false, e.Message)
}

; ---- KeyHelpText 纯文本 ----
try {
    kh := KeyHelpText()
    Ck("keyhelptext", Type(kh) = "String", SubStr(String(kh), 1, 40))
} catch as e {
    Ck("keyhelptext-no-throw", false, e.Message)
}

; ---- Help() 全链 (止于真 DisplayResult, 文本进假 Edit) ----
try {
    Help()
    Ck("help-shows", InStr(g_DisplayEdit.Value, "reload") > 0, SubStr(String(g_DisplayEdit.Value), 1, 80))
} catch as e {
    Ck("help-no-throw", false, e.Message)
}

if (g_Fail > 0) {
    FileAppend("probe-help FAIL: " . g_Fail . "`n", "*")
    ExitApp(1)
}
FileAppend("probe-help-ok`n", "*")
ExitApp(0)
