#Requires AutoHotkey v2.0
#Warn All, Off
; P1-6: 插件契约 v2 探针 (结构化注册+依赖+冲突+失败报告+禁用不阻塞)

T(key, *) => key
RimLog(level, msg, err := "") {
    return
}
ObsRecordFailure(stage, id, msg) {
    return
}

#Include ..\Core\Plugin.ahk

fails := []
Check(name, cond) {
    global fails
    if (!cond)
        fails.Push(name)
}

class ProbePlugA extends RimPlugin {
    static Name => "ProbeA"
    static Version => "2.1.0"
    static ApiVersion => "2"
    static Dependencies => []
    static Capabilities => ["commands"]
    static Init() {
    }
}

class ProbePlugB extends RimPlugin {
    static Name => "ProbeB"
    static Version => "1.0.0"
    static Dependencies => ["ProbeMissing"]
    static Capabilities => ["keymaps"]
}

class ProbeBad extends RimPlugin {
    static Name => "ProbeBad"
    static Init() {
        throw Error("boom")
    }
}

class ProbePlugC extends RimPlugin {
    static Name => "ProbeC"
    static Dependencies => ["ProbeD"]
}

class ProbePlugD extends RimPlugin {
    static Name => "ProbeD"
    static Dependencies => ["ProbeC"]
}

Main() {
    global fails
    RimPluginManager.Plugins := Map()
    RimPluginManager.Registry := Map()
    RimPluginManager.EnabledPlugins := Map()
    RimPluginManager.CommandOwners := Map()
    RimPluginManager.HotkeyOwners := Map()
    RimPluginManager.GestureOwners := Map()
    RimPluginManager.Conflicts := []
    RimPluginManager.Failures := []
    r1 := RimPluginManager.Register(ProbePlugA)
    Check("register-ok", r1["ok"] && r1["id"] = "ProbeA" && r1["version"] = "2.1.0")
    r1b := RimPluginManager.Register(ProbePlugA)
    Check("register-replace-ok", r1b["ok"] && r1b["replaced"] = "ProbeA")
    Check("conflict-on-replace", RimPluginManager.Conflicts.Length >= 1)
    RimPluginManager.Register(ProbePlugB)
    RimPluginManager.Register(ProbePlugC)
    RimPluginManager.Register(ProbePlugD)
    rep := RimPluginManager.CheckDependencies()
    Check("missing-dep", rep["missing"].Length >= 1 && rep["missing"][1]["dep"] = "ProbeMissing")
    Check("missing-disabled", rep["disabled"].Length >= 1)
    Check("order-keeps-healthy", rep["order"].Length >= 1)
    Check("cycle-detected", rep["cycles"].Length >= 1)
    Check("disabled-not-enabled", !RimPluginManager.EnabledPlugins.Has("probeb"))
    Check("claim-first", RimPluginManager.ClaimCommand("MyCmd", "ProbeA") = true)
    Check("claim-conflict", RimPluginManager.ClaimCommand("MyCmd", "ProbeB") = false)
    Check("claim-hotkey", RimPluginManager.ClaimHotkey("ctrl+x", "ProbeA") = true)
    Check("claim-hotkey-conflict", RimPluginManager.ClaimHotkey("ctrl+x", "ProbeB") = false)
    Check("claim-gesture", RimPluginManager.ClaimGesture("R", "ProbeA") = true)
    RimPluginManager._SafeCall(ProbeBad, "Init", "ProbeBad")
    Check("failure-logged", RimPluginManager.Failures.Length >= 1)
    Check("conflicts-query", PluginConflicts().Length >= 2)
    Check("failures-query", PluginFailures().Length >= 1)
    out := A_ScriptDir . "\..\probe_plugin_v2.out.txt"
    try FileDelete(out)
    catch {
    }
    if (fails.Length > 0) {
        txt := "plugin-v2-FAIL:`n"
        for _, x in fails
            txt .= "  - " . x . "`n"
        FileAppend(txt, out, "UTF-8")
        ExitApp(1)
    }
    FileAppend("plugin-v2-ok`n", out, "UTF-8")
    ExitApp(0)
}

Main()
