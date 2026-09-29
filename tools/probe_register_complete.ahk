#Requires AutoHotkey v2.0
#Warn All, Off

; 注册完备性探针: 全插件 RegisterCommands 跑通 + 111 条动作全部可解 (闭包/已存在函数/合法协议串).
; 锁死"删函数/改名后引用悬空"整类 (契约 1 的 Registry 版): 只注册不执行, 零副作用.
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_register_complete.ahk
#Include ..\Core\Plugin.ahk
#Include ..\Core\Command.ahk
#Include ..\Core\ActionProtocol.ahk
#Include ..\Core\Execution.ahk
#Include ..\Core\Engine.ahk
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
#Include ..\Plugins\Terminal.ahk
#Include ..\Plugins\TotalCommander.ahk
#Include ..\Plugins\VimDConfig.ahk
#Include ..\Plugins\VimEditor.ahk
#Include ..\Plugins\WinMerge.ahk

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
    return key
}

CfgGet(sec, key, def := "") {
    return def
}

RimLog(level, msg, err := "") {
}

; 生产环境桩 (对齐 Rim.ahk RegisterCommand → LauncherCompat; 缺了插件 url/file 行注册即挂)
global g_CommandAlias := Map()
RegisterCommand(name, type, content, description := "") {
    LauncherCompat.AddCommand(name, type, content, description)
}

; ---- 注册 (与生产 LoadFiles 同顺序语义: 通用指令 + 全插件) ----
; 注意: RegisterAll* 只走 InitAll 建好的 EnabledPlugins, 直调等于空转 (阶段耦合, 探针锁死)
InitUniversalCommands()
RimPluginManager.InitAll()
RimPluginManager.RegisterAllCommands()
total := RimCommand.Registry.Count
FileAppend("INFO: registered=" . total . "`n", "*")
Ck("registry-volume", total >= 70, String(total))
Ck("must-have", RimCommand.Registry.Has("ShutdownTimer") && RimCommand.Registry.Has("Calc") && RimCommand.Registry.Has("KillProcess") && RimCommand.Registry.Has("Help"))

; ---- 逐条动作可解 ----
bad := []
for id, cmd in RimCommand.Registry {
    act := ""
    try act := cmd.Action
    catch {
        bad.Push(id . ":unreadable-action")
        continue
    }
    if (IsObject(act)) {
        try {
            if (!HasMethod(act, "Call"))
                bad.Push(id . ":non-callable-object")
        } catch {
            bad.Push(id . ":object-probe-throw")
        }
        continue
    }
    if (Type(act) != "String" || act = "") {
        bad.Push(id . ":empty-action")
        continue
    }
    parsed := ""
    try parsed := ActionParse(act, "probe-register")
    catch {
        bad.Push(id . ":parse-throw")
        continue
    }
    if (!parsed["ok"]) {
        bad.Push(id . ":parse-" . parsed["code"])
        continue
    }
    k := parsed["kind"]
    tgt := parsed["target"]
    if (k = "command") {
        if (!RimCommand.Registry.Has(tgt))
            bad.Push(id . ":dangling-command|" . tgt)
    } else if (k = "function" || k = "legacy") {
        fn := StrSplit(tgt, "|")[1]
        fn := Trim(fn)
        resolved := false
        try resolved := ActionIsCallable(fn)
        catch {
        }
        if (!resolved)
            bad.Push(id . ":dangling-function|" . fn)
    }
    ; run|file|url|key|dir|cmd|combo: 结构合法即过 (目标存在性系机器相关, 不断言)
}
Ck("actions-resolve", bad.Length = 0, bad.Length > 0 ? bad[1] . (bad.Length > 1 ? " (+" . (bad.Length - 1) . " more)" : "") : "")
if (bad.Length > 0) {
    out := ""
    for _, b in bad
        out .= b . ";"
    FileAppend("INFO: all-bad=[" . out . "]`n", "*")
}

if (g_Fail > 0) {
    FileAppend("probe-register-complete FAIL: " . g_Fail . "`n", "*")
    ExitApp(1)
}
FileAppend("probe-register-complete-ok`n", "*")
ExitApp(0)
