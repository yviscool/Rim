#Requires AutoHotkey v2.0
#Warn All, Off

; 常驻冒烟探针 2/2: 注册线束 (CI + 本地)
; 用桩替换注册 API, 依次调用 16 个 RegisterPlugin_*, 导出动作/命令描述;
; 外部断言: 0 退出 + 无 F| 行 + 描述无空/CJK/raw-key.
; (en 下跑: 证明英文包零缺键; 详见 tools/i18n_audit.py)
#Include ..\Core\I18n.ahk
#Include ..\Core\Context.ahk
#Include ..\Core\Plugin.ahk
#Include ..\Core\Command.ahk
#Include ..\Core\Engine.ahk
#Include ..\Core\Gesture.ahk

global g_RegActions := []
global g_RegCommands := []
global g_RegFails := []
; 经 Rim.vim 方法注册的动作 (VimEditor 通道), 单列断言, 不混入 A| 导出
global g_EngineActions := []

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
    SetPreKeyFilterForWin(a, b) {
    }
    RegisterPrefixActionHandler(a, b) {
    }
    RegisterActionValidator(a, b) {
    }
    IsValidAction(a) {
        return true
    }
    SetAction(a, b := "") {
        global g_EngineActions
        g_EngineActions.Push([String(a), String(b)])
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
TryReg("RegisterPlugin_VimEditor")
TryReg("RegisterPlugin_WinMerge")

; VimEditor 绑定干跑: DoBind 经 SetTimer 异步, 探针退出前跑不到, 此处直调
; (EngineStub 吞掉全部副作用; 实例调静态的 bug 在此现形, 真机 error.log 曾红)
try {
    VimEditorPlugin().DoBind()
} catch as e {
    global g_RegFails
    g_RegFails.Push("VimEditorDoBind: " . e.Message . " @line=" . e.Line)
}
; 幂等回归: 双通道各调一次的插件, 调两次也只留一份命令
TryReg("RegisterPlugin_StatsBall")
TryReg("RegisterPlugin_StrokePlus")

; VimEditor 经引擎方法注册, 动作数即接线证据 (InitActions 约 100+)
veCount := 0
for r in g_EngineActions {
    if (SubStr(r[1], 1, 10) = "VimEditor_")
        veCount++
}
if (veCount < 50) {
    global g_RegFails
    g_RegFails.Push("VimEditorActions: only " . veCount . " (expect >=50)")
}
sbCount := 0
for r in g_RegCommands {
    if (r[1] = "StatsBall" || r[1] = "StatsBallBoost")
        sbCount++
}
if (sbCount != 2) {
    global g_RegFails
    g_RegFails.Push("StatsBallIdempotent: got " . sbCount . " rows (expect 2)")
}
for pname, _ in RimPluginManager.LegacyVimPlugins {
    fn := ""
    try fn := %("RegisterPlugin_" . pname)%
    catch {
        fn := ""
    }
    if (!IsObject(fn) || !HasMethod(fn, "Call")) {
        global g_RegFails
        g_RegFails.Push("LegacyNoEntry:" . pname)
    }
}

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
; zh-CN 回落断言: 中文包就绪且非 raw key (只读检查, 不影响上面的 en 导出)
I18nSetLang("zh-CN", false)
if (T("tray.show") = "tray.show") {
    FileAppend("F|i18n-zh-canary: zh-CN map empty`n", A_ScriptDir . "\..\smoke_register.out.txt")
    ExitApp(1)
}
ExitApp(0)
