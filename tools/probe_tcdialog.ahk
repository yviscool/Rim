#Requires AutoHotkey v2.0
#Warn All, Off

; TCDialog 纯静态迁移探针: 无实例基类, 未就绪入口静默 no-op, 无 TC 时 Setup 早退
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_tcdialog.ahk

CfgGet(sec, key, def := "") {
    if (sec = "Plugins" && key = "TCDialog")
        return "1"
    return def
}

T(key, params*) {
    return key
}

Log(msg, level := "INFO") {
}

class ConfStub {
    Get(s, k, d := "") {
        return d
    }
}

class Rim {
    static config := ConfStub()
}

class RimPluginManager {
    static Register(c) {
        return true
    }
}

class RimPlugin {
}

#Include ..\Plugins\TCDialog.ahk

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

; 旧体系残留静态断言
src := FileRead(A_ScriptDir . "\..\Plugins\TCDialog.ahk", "UTF-8")
Ck("no-old-base", !InStr(src, "extends Plugin") || InStr(src, "extends RimPlugin") > 0)
Ck("no-instance", !InStr(src, "Plugin_TCDialog(") && !InStr(src, "g_TCDialog"))
Ck("no-dead-maps", !InStr(src, "TCDialog_Callers") && !InStr(src, "TCDialog_IsDialogMode"))

; 静态形状
Ck("is-class", IsObject(TCDialog))
Ck("has-setup", HasMethod(TCDialog, "Setup"))
Ck("has-check", HasMethod(TCDialog, "CheckFileDialog"))
Ck("ready-false", TCDialog.Ready = false)

; 未就绪入口全部 no-op 不抛错
try {
    TCD_Select()
    TCD_Cancel()
    TCD_PreSelected()
    TCD_Selected()
    TCD_SelectedCurrentDir()
    TCD_ReturnToCaller()
    TCD_OpenTCDialog()
    Ck("entry-noop", true)
} catch as e {
    Ck("entry-noop", false, e.Message)
}

; 无 TC 环境 Setup 早退 (AsOpenFileDialog 缺省 0), 不武装 timer, Ready 保持假
TCDialog_Keymaps("")
Ck("setup-early", TCDialog.Ready = false && TCDialog.CheckTimer = "")

if (g_Fail > 0) {
    FileAppend("probe-tcdialog FAIL: " . g_Fail . "`n", "*")
    ExitApp(1)
}
FileAppend("probe-tcdialog-ok`n", "*")
ExitApp(0)
