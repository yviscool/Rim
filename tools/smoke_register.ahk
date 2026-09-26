#Requires AutoHotkey v2.0
#Warn All, Off

; 常驻冒烟探针 2/2: 注册线束 (CI + 本地)
; 直调 Hybrid RegisterKeymaps/RegisterCommands, 导出动作/命令描述;
; 外部断言: 0 退出 + 无 F| 行 + 描述无空/CJK/raw-key.
; (en 下跑: 证明英文包零缺键; 详见 tools/i18n_audit.py)
#Include ..\Core\I18n.ahk
#Include ..\Core\Context.ahk
#Include ..\Core\Plugin.ahk
#Include ..\Core\Command.ahk
#Include ..\Core\Execution.ahk
#Include ..\Core\Engine.ahk
#Include ..\Core\Gesture.ahk

global g_RegCommands := []
global g_RegFails := []
; 经 Rim.vim 方法注册的动作 (VimEditor 通道), 单列断言, 不混入 A| 导出
global g_EngineActions := []

class ConfStub {
    Get(s, k, d := "") {
        if (s = "TotalCommander_Config" && k = "AsOpenFileDialog")
            return "1"
        if (k = "TCPath")
            return A_ScriptFullPath
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
    static W := 0
    static A := 0
    static M := 0
    static G := 0
    static Mode := 0
    static X := 0
    static Reset() {
        EngineStub.W := 0
        EngineStub.A := 0
        EngineStub.M := 0
        EngineStub.G := 0
        EngineStub.Mode := 0
        EngineStub.X := 0
    }
    static Counts() {
        return [EngineStub.W, EngineStub.A, EngineStub.M, EngineStub.G, EngineStub.Mode, EngineStub.X]
    }
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
        EngineStub.A++
        g_EngineActions.Push([String(a), String(b)])
    }
    SetWin(a, b := "", c := "") {
        EngineStub.W++
    }
    SetMode(a, b := "") {
        EngineStub.Mode++
    }
    MapKey(a, b, c := "", d := "") {
        EngineStub.M++
    }
    MapGlobal(a, b) {
        EngineStub.G++
    }
    ExcludeWin(a) {
        EngineStub.X++
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

RegisterCommand(name, type, content, desc := "") {
    global g_RegCommands
    g_RegCommands.Push([String(name), String(type), String(content), String(desc)])
}
; 注意: 不定义 Host —— LauncherCore.ahk 自带 Host(fn, args*) 动态分发,
; 现仅用于 RunWithCmd/DisplayResult 等运行时调用, 注册期已直注 RimCommand

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

I18nBoot()
I18nSetLang("en", false)
; 金丝雀: 语言表为空时直接失败, 禁止带着 raw key 往下跑
; (曾实测: 探针放 tools/ 下跑, A_ScriptDir\Lang 不存在导致静默空表)
if (I18nAvailable().Length < 2 || T("tray.show") = "tray.show") {
    FileAppend("F|i18n-canary: language maps empty (root=" . I18nRoot() . ")`n", A_ScriptDir . "\..\smoke_register.out.txt")
    ExitApp(1)
}
TryRegE(fnName, eng) {
    global g_RegFails
    try {
        fn := %(fnName)%
        fn(eng)
    } catch as e {
        g_RegFails.Push(fnName . ": " . e.Message . " @line=" . e.Line)
    }
}

; Vim 键位经 Hybrid RegisterKeymaps 直注引擎 (计数断言 = 迁移对等基线, 增映射须同步更新此处)
vimExpect := Map("General", [1, 88, 47, 0, 0, 0], "Explorer", [1, 21, 28, 0, 0, 0]
    , "TCCompare", [1, 16, 23, 0, 0, 0], "WinMerge", [1, 19, 26, 0, 0, 0]
    , "BeyondCompare4", [1, 16, 23, 0, 0, 0], "Foobar2000", [1, 17, 24, 0, 0, 0]
    , "TCDialog", [0, 7, 0, 0, 0, 0], "StrokePlus", [0, 20, 0, 0, 0, 0]
    , "VimDConfig", [0, 3, 0, 0, 0, 0], "TotalCommander", [2, 650, 143, 0, 4, 0])
for _pn in ["General", "Explorer", "TCCompare", "WinMerge", "BeyondCompare4", "Foobar2000", "TCDialog", "StrokePlus", "VimDConfig", "TotalCommander"] {
    EngineStub.Reset()
    TryRegE(_pn . "_Keymaps", g_VimEngine)
    got := EngineStub.Counts()
    want := vimExpect[_pn]
    ok := true
    Loop 6 {
        if (got[A_Index] != want[A_Index])
            ok := false
    }
    if (!ok) {
        global g_RegFails
        g_RegFails.Push("VimParity:" . _pn . " got=" . got[1] . "/" . got[2] . "/" . got[3] . "/" . got[4] . "/" . got[5] . "/" . got[6])
    }
}
; 命令插件经 Hybrid RegisterCommands 直注 (Misc/LauncherCore/System/QRCode/Kanji/StatsBall/VimDConfig/General/Explorer/TotalCommander)
for _cls in [MiscPlugin, LauncherCorePlugin, LauncherSystemPlugin, QRCodePlugin, KanjiPlugin, StatsBallPlugin, VimDConfigPlugin, GeneralPlugin, ExplorerPlugin, TotalCommanderPlugin] {
    try {
        _cls.RegisterCommands()
    } catch as e {
        global g_RegFails
        g_RegFails.Push("CmdDirect:" . _cls.Name . ": " . e.Message . " @line=" . e.Line)
    }
}

; VimEditor 经引擎直注 + 绑定干跑: DoBind 经 SetTimer 异步, 探针退出前跑不到, 此处直调
; (EngineStub 吞掉全部副作用; 实例调静态的 bug 在此现形, 真机 error.log 曾红)
TryRegE("VimEditor_Keymaps", g_VimEngine)
try {
    VimEditorPlugin().DoBind()
} catch as e {
    global g_RegFails
    g_RegFails.Push("VimEditorDoBind: " . e.Message . " @line=" . e.Line)
}
; 幂等回归: 同一 RegisterCommands 调两次也只留一份命令
StatsBallPlugin.RegisterCommands()
StatsBallPlugin.RegisterCommands()

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
; 直注 RimCommand 的命令 (function 内联迁移后) 从真实 Registry 收割, 与桩 C| 行同断言
for id, cmd in RimCommand.Registry {
    try {
        g_RegCommands.Push([String(id), "command", String(id), String(cmd.Description)])
    } catch as e {
        global g_RegFails
        g_RegFails.Push("RegistryHarvest:" . id . ": " . e.Message)
    }
    if (id = "StatsBall" || id = "StatsBallBoost")
        sbCount++
}
if (sbCount != 2) {
    global g_RegFails
    g_RegFails.Push("StatsBallIdempotent: got " . sbCount . " rows (expect 2)")
}
; 全插件 Hybrid 自注册覆盖断言 (include 即注册, 缺类名即 TotalCommander 式漏尾)
for _hpn in ["General", "Explorer", "TCCompare", "WinMerge", "BeyondCompare4", "Foobar2000", "TCDialog", "TotalCommander", "StrokePlus", "VimDConfig", "VimEditor", "Misc", "LauncherCore", "LauncherSystem", "QRCode", "Kanji", "StatsBall"] {
    if (RimPluginManager.Get(_hpn) = "") {
        global g_RegFails
        g_RegFails.Push("HybridMissing:" . _hpn)
    }
}

out := ""
for r in g_EngineActions
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
