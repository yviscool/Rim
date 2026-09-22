#Requires AutoHotkey v2.0
#Warn All, Off

; 常驻冒烟探针 2/2: 注册线束 (CI + 本地)
; 用桩替换注册 API, 依次调用 16 个 RegisterPlugin_*, 导出动作/命令描述;
; 外部断言: 0 退出 + 无 F| 行 + 描述无空/CJK/raw-key.
; (en 下跑: 证明英文包零缺键; 详见 tools/i18n_audit.py)
#Include ..\Core\I18n.ahk
#Include ..\Core\Engine.ahk
#Include ..\Core\Gesture.ahk

global g_RegActions := []
global g_RegCommands := []
global g_RegFails := []

class ConfStub {
    Get(s, k, d := "") {
        return d
    }
    GetValue(s, k, d := "") {
        return d
    }
    Set(s, k, v) {
    }
    GetSection(s) {
        return Map()
    }
    HasSection(s) {
        return false
    }
    HasKey(s, k) {
        return false
    }
    AddKey(s, k, v) {
    }
}
class EngineStub {
    SetBeforeActionDoForWin(a, b) {
    }
    SetAction(a, b := "") {
    }
    SetWin(a, b := "", c := "") {
    }
    SetMode(a, b := "") {
    }
    MapKey(a, b, c := "", d := "") {
    }
    MapGlobal(a, b) {
    }
    ExcludeWin(a) {
    }
}
global g_Conf := ConfStub()
global g_VimEngine := EngineStub()
global g_ConfFile := ""
class Rim {
    static config := ConfStub()
    static vim := EngineStub()
    static engine := EngineStub()
}

RegisterAction(name, comment := "") {
    global g_RegActions
    g_RegActions.Push([String(name), String(comment)])
}
RegisterCommand(name, type, content, desc := "") {
    global g_RegCommands
    g_RegCommands.Push([String(name), String(type), String(content), String(desc)])
}
RegisterWin(name, wc := "", wf := "") {
}
RegisterMode(mode, win := "") {
}
MapKey(k, a, w := "", m := "normal") {
}
MapGlobal(k, a) {
}
ExcludeWindow(n) {
}
; 注意: 不定义 Host —— LauncherCore.ahk 自带 Host(fn, args*) 动态分发,
; 注册期的 Host("RegisterCommand", ...) 会落到上面的 RegisterCommand 桩上

#Include ..\Plugins\BeyondCompare4.ahk
#Include ..\Plugins\Explorer.ahk
#Include ..\Plugins\Foobar2000.ahk
#Include ..\Plugins\General.ahk
#Include ..\Plugins\Kanji.ahk
#Include ..\Plugins\LauncherCore.ahk
#Include ..\Plugins\LauncherSystem.ahk
#Include ..\Plugins\Misc.ahk
#Include ..\Plugins\QRCode.ahk
#Include ..\Plugins\StatsBall.ahk
#Include ..\Plugins\StrokePlus.ahk
#Include ..\Plugins\TCCompare.ahk
#Include ..\Plugins\TCDialog.ahk
#Include ..\Plugins\TotalCommander.ahk
#Include ..\Plugins\VimDConfig.ahk
#Include ..\Plugins\VimEditor.ahk
#Include ..\Plugins\WinMerge.ahk

TryReg(fn) {
    global g_RegFails
    try {
        %fn%()
    } catch as e {
        g_RegFails.Push(fn . ": " . e.Message . " @line=" . e.Line)
    }
}

I18nBoot()
I18nSetLang("en", false)
; 金丝雀: 语言表为空时直接失败, 禁止带着 raw key 往下跑
; (曾实测: 探针放 tools/ 下跑, A_ScriptDir\Lang 不存在导致静默空表)
if (I18nAvailable().Length < 2 || T("tray.show") = "tray.show") {
    FileAppend("F|i18n-canary: language maps empty (root=" . I18nRoot() . ")`n", A_ScriptDir . "\..\smoke_register.out.txt")
    ExitApp(1)
}
TryReg("RegisterPlugin_BeyondCompare4")
TryReg("RegisterPlugin_Explorer")
TryReg("RegisterPlugin_Foobar2000")
TryReg("RegisterPlugin_General")
TryReg("RegisterPlugin_Kanji")
TryReg("RegisterPlugin_LauncherCore")
TryReg("RegisterPlugin_LauncherSystem")
TryReg("RegisterPlugin_Misc")
TryReg("RegisterPlugin_QRCode")
TryReg("RegisterPlugin_StatsBall")
TryReg("RegisterPlugin_StrokePlus")
TryReg("RegisterPlugin_TCCompare")
TryReg("RegisterPlugin_TCDialog")
TryReg("RegisterPlugin_TotalCommander")
TryReg("RegisterPlugin_VimDConfig")
TryReg("RegisterPlugin_WinMerge")

out := ""
for r in g_RegActions
    out .= "A|" . r[1] . "|" . r[2] . "`n"
for r in g_RegCommands
    out .= "C|" . r[1] . "|" . r[2] . "|" . r[3] . "|" . r[4] . "`n"
for f in g_RegFails
    out .= "F|" . f . "`n"
FileAppend(out, A_ScriptDir . "\..\smoke_register.out.txt")
if (g_RegFails.Length > 0)
    ExitApp(1)
ExitApp(0)
