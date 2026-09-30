#Requires AutoHotkey v2.0
#Warn All, Off
; 插件 DAG + 注册事务回滚探针:
; 拓扑序 (依赖在前, 与注册序无关) / 缺失禁用 / 环禁用 / 阶段失败回滚命令+按键+禁用.
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_plugin_dag.ahk

T(key, *) => key
RimLog(level, msg, err := "") {
    return
}
ObsRecordFailure(stage, id, msg) {
    return
}

#Include ..\Core\Plugin.ahk
#Include ..\Core\Command.ahk
#Include ..\Core\Engine.ahk

fails := []
Check(name, cond, extra := "") {
    global fails
    if (!cond)
        fails.Push(extra != "" ? name . " | got=[" . extra . "]" : name)
}

class DagA extends RimPlugin {
    static Name => "DagA"
    static Dependencies => []
    static RegisterCommands() {
        RimCommand.Register("DagCmdA", "DagCmdA", "", Map("Description", "a"))
    }
}

class DagB extends RimPlugin {
    static Name => "DagB"
    static Dependencies => ["DagA"]
    static RegisterCommands() {
        RimCommand.Register("DagCmdB", "DagCmdB", "", Map("Description", "b"))
    }
}

class DagC extends RimPlugin {
    static Name => "DagC"
    static Dependencies => ["DagB"]
}

class DagGood extends RimPlugin {
    static Name => "DagGood"
    static RegisterCommands() {
        RimCommand.Register("DagGoodCmd", "DagGoodCmd", "", Map("Description", "g"))
    }
    static RegisterKeymaps(engine) {
        engine.SetWin("DagWin", "DagClsZZZ", "")
        engine.MapKey("<F24>", "<Dag_Noop>", "DagWin")
    }
}

class DagFail extends RimPlugin {
    static Name => "DagFail"
    static Dependencies => ["DagGood"]
    static RegisterCommands() {
        RimCommand.Register("DagFailCmd", "DagFailCmd", "", Map("Description", "f"))
        throw Error("fail-commands")
    }
}

class DagFailK extends RimPlugin {
    static Name => "DagFailK"
    static RegisterCommands() {
        RimCommand.Register("DagFailKCmd", "DagFailKCmd", "", Map("Description", "k"))
    }
    static RegisterKeymaps(engine) {
        engine.SetWin("DagWin", "DagClsZZZ", "")
        engine.MapKey("<F23>", "<Dag_Noop>", "DagWin")
        throw Error("fail-keymaps")
    }
}

PosOf(arr, val) {
    i := 1
    while (i <= arr.Length) {
        if (arr[i] = val)
            return i
        i++
    }
    return 0
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
    RimPluginManager.EnabledCache := Map()
    RimCommand.Registry := Map()
    RimCommand.Seq := 0

    ; 逆序注册, 拓扑必须纠正为 A<B<C
    RimPluginManager.Register(DagC)
    RimPluginManager.Register(DagB)
    RimPluginManager.Register(DagA)
    RimPluginManager.Register(DagGood)
    RimPluginManager.Register(DagFail)
    RimPluginManager.Register(DagFailK)
    rep := RimPluginManager.ResolveOrder()
    Check("dag-missing-empty", rep["missing"].Length = 0, String(rep["missing"].Length))
    Check("dag-cycles-empty", rep["cycles"].Length = 0, String(rep["cycles"].Length))
    pa := PosOf(rep["order"], "daga")
    pb := PosOf(rep["order"], "dagb")
    pc := PosOf(rep["order"], "dagc")
    Check("dag-order", pa > 0 && pb > pa && pc > pb, pa . "/" . pb . "/" . pc)
    pg := PosOf(rep["order"], "daggood")
    pf := PosOf(rep["order"], "dagfail")
    Check("dag-dep-after", pg > 0 && pf > pg, pg . "/" . pf)

    eng := VimEngine()
    RimPluginManager.InitAll()
    Check("enabled-cache", RimPluginManager.EnabledCache.Has("daggood"), "")
    n1 := RimPluginManager.RegisterAllCommands()
    Check("good-cmd", RimCommand.Registry.Has("DagCmdA") && RimCommand.Registry.Has("DagCmdB") && RimCommand.Registry.Has("DagGoodCmd"), "")
    Check("fail-cmd-rolled-back", !RimCommand.Registry.Has("DagFailCmd"), "")
    Check("fail-disabled", !RimPluginManager.EnabledPlugins.Has("dagfail"), "")
    n2 := RimPluginManager.RegisterAllKeymaps(eng)
    win := eng.GetWin("DagWin")
    hasF24 := false
    hasF23 := false
    try {
        modeObj := win.modeList["normal"]
        hasF24 := modeObj.keymapList.Has("<F24>")
        hasF23 := modeObj.keymapList.Has("<F23>")
    }
    Check("good-key", hasF24, "")
    Check("fail-key-rolled-back", !hasF23, "")
    Check("failk-cmd-kept", RimCommand.Registry.Has("DagFailKCmd"), "")
    Check("failk-disabled", !RimPluginManager.EnabledPlugins.Has("dagfailk"), "")
    Check("failures-recorded", RimPluginManager.Failures.Length >= 2, String(RimPluginManager.Failures.Length))

    if (fails.Length > 0) {
        txt := "plugin-dag-FAIL:`n"
        for _, x in fails
            txt .= "  - " . x . "`n"
        FileAppend(txt, "*", "UTF-8")
        ExitApp(1)
    }
    FileAppend("plugin-dag-ok`n", "*", "UTF-8")
    ExitApp(0)
}

Main()
