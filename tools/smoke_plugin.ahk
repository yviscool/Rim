#Requires AutoHotkey v2.0
#Warn All, Off

; 冒烟探针: Unified Plugin Architecture (统一插件系统测试)
#Include ..\Lib\EasyIni.ahk
#Include ..\Core\I18n.ahk
#Include ..\Core\Context.ahk
#Include ..\Core\Plugin.ahk
#Include ..\Core\Command.ahk
#Include ..\Core\Execution.ahk
#Include ..\Plugins\Explorer.ahk
#Include ..\Plugins\LauncherSystem.ahk
#Include ..\Plugins\TotalCommander.ahk

Assert(cond, msg) {
    if (!cond) {
        FileAppend("FAIL: " . msg . "`n", "*")
        ExitApp(1)
    }
    FileAppend("PASS: " . msg . "`n", "*")
}

; 1. 验证内置核心插件类已正确挂载至 PluginManager
Assert(RimPluginManager.Get("Explorer") != "", "plugin-get-explorer")
Assert(RimPluginManager.Get("LauncherSystem") != "", "plugin-get-launchersystem")
Assert(RimPluginManager.Get("TotalCommander") != "", "plugin-get-totalcommander")

expCls := RimPluginManager.Get("Explorer")
Assert(expCls.Name == "Explorer", "plugin-name-explorer")
Assert(expCls.Title != "", "plugin-title-explorer")

; 2. 模拟自定义插件，测试完整生命周期
global g_TestPluginFlags := Map(
    "inited", false,
    "context", false,
    "commands", false,
    "keymaps", false,
    "gestures", false,
    "exited", false
)

class MockPlugin extends RimPlugin {
    static Name => "MockFeature"
    static Title => "Mock Test Feature"
    static Description => "Used for lifecycle assertions"

    static Init() {
        global g_TestPluginFlags
        g_TestPluginFlags["inited"] := true
    }

    static RegisterContext() {
        global g_TestPluginFlags
        g_TestPluginFlags["context"] := true
        RimContext.RegisterProvider("mockapp", (hwnd) => Map("appId", "mockapp", "currentDir", "C:\MockDir"))
    }

    static RegisterCommands() {
        global g_TestPluginFlags
        g_TestPluginFlags["commands"] := true
        RimCommand.Register("mock.hello", "Mock Hello", (*) => "Hello from Mock")
    }

    static RegisterKeymaps(engine) {
        global g_TestPluginFlags
        g_TestPluginFlags["keymaps"] := true
    }

    static RegisterGestures() {
        global g_TestPluginFlags
        g_TestPluginFlags["gestures"] := true
    }

    static OnExit() {
        global g_TestPluginFlags
        g_TestPluginFlags["exited"] := true
    }
}

regResult := RimPluginManager.Register(MockPlugin)
Assert(regResult == true, "plugin-register-mock")
Assert(RimPluginManager.Get("mockfeature") != "", "plugin-get-case-insensitive")

; 3. 驱动各生命周期阶段
RimPluginManager.InitAll()
Assert(g_TestPluginFlags["inited"] == true, "lifecycle-init-executed")

RimPluginManager.RegisterAllContexts()
Assert(g_TestPluginFlags["context"] == true, "lifecycle-context-executed")
Assert(RimContext.Providers.Has("mockapp"), "context-provider-registered-by-plugin")

RimPluginManager.RegisterAllCommands()
Assert(g_TestPluginFlags["commands"] == true, "lifecycle-commands-executed")
Assert(RimCommand.Get("mock.hello") != "", "command-registered-by-plugin")
Assert(RimCommand.Get("explorer.open_tc") != "", "explorer-cmd-registered")
Assert(RimCommand.Get("tc.open") != "", "tc-cmd-registered")

mockEngine := { SetAction: (*)=>0, MapKey: (*)=>0, RegisterWin: (*)=>0, SetBeforeActionDoForWin: (*)=>0 }
RimPluginManager.RegisterAllKeymaps(mockEngine)
Assert(g_TestPluginFlags["keymaps"] == true, "lifecycle-keymaps-executed")

RimPluginManager.RegisterAllGestures()
Assert(g_TestPluginFlags["gestures"] == true, "lifecycle-gestures-executed")

RimPluginManager.OnExitAll()
Assert(g_TestPluginFlags["exited"] == true, "lifecycle-onexit-executed")

; 4. 故障隔离沙箱测试 (Broken Plugin 抛出异常不影响系统)
class FaultyPlugin extends RimPlugin {
    static Name => "FaultyBoom"
    static Init() {
        throw Error("Simulated plugin crash during init")
    }
    static RegisterCommands() {
        throw Error("Simulated plugin crash during command registration")
    }
}

RimPluginManager.Register(FaultyPlugin)
try {
    RimPluginManager.InitAll()
    RimPluginManager.RegisterAllCommands()
    Assert(true, "plugin-sandbox-fault-isolated")
} catch Any as e {
    Assert(false, "plugin-sandbox-leaked-error")
}

FileAppend("smoke-plugin-ok`n", A_ScriptDir . "\..\smoke_plugin.out.txt")
ExitApp(0)
