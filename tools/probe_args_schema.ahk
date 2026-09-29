#Requires AutoHotkey v2.0
#Warn All, Off

; 参数规格探针: 全插件 Args 声明 well-formed + 校验门行为 + Usage 文本.
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_args_schema.ahk
#Include ..\Core\Plugin.ahk
#Include ..\Core\Command.ahk
#Include ..\Core\Execution.ahk
#Include ..\Plugins\LauncherSystem.ahk
#Include ..\Plugins\LauncherCore.ahk
#Include ..\Plugins\Misc.ahk

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

; 生产环境桩 (对齐 Rim.ahk RegisterCommand → LauncherCompat)
global g_CommandAlias := Map()
RegisterCommand(name, type, content, description := "") {
    LauncherCompat.AddCommand(name, type, content, description)
}

LauncherSystemPlugin.RegisterCommands()
LauncherCorePlugin.RegisterCommands()
MiscPlugin.RegisterCommands()

; ---- 全表 well-formed ----
badShape := 0
nSpec := 0
for id, cmd in RimCommand.Registry {
    try {
        for _, spec in cmd.Args {
            nSpec++
            if (!IsObject(spec) || !spec.Has("name") || Trim(String(spec["name"])) = "")
                badShape++
        }
    } catch {
        badShape++
    }
}
FileAppend("INFO: specced-args=" . nSpec . "`n", "*")
Ck("args-wellformed", badShape = 0, String(badShape))
Ck("args-present", nSpec >= 15, String(nSpec))

; ---- 门行为: required 拦, optional 放 ----
Ck("gate-sendtoclip", RimCommand.CheckArgs("SendToClip", "") != "", RimCommand.CheckArgs("SendToClip", ""))
Ck("gate-sendtoclip-pass", RimCommand.CheckArgs("SendToClip", "hi") == "")
Ck("gate-shutdowntimer", RimCommand.CheckArgs("ShutdownTimer", "") == "")
Ck("gate-unknown", RimCommand.CheckArgs("NoSuchCmdZZZ", "") == "")

; ---- Usage 文本 ----
u1 := RimCommand.Usage("ShutdownTimer")
Ck("usage-shutdowntimer", InStr(u1, "ShutdownTimer") > 0 && InStr(u1, "[时长]") > 0, u1)
u2 := RimCommand.Usage("KillProcess")
Ck("usage-killprocess", InStr(u2, "<进程名>") > 0, u2)
Ck("usage-unknown", RimCommand.Usage("NoSuchCmdZZZ") == "")
Ck("usage-noargs", SubStr(RimCommand.Usage("ShowIp"), 1, 6) == "ShowIp", RimCommand.Usage("ShowIp"))

if (g_Fail > 0) {
    FileAppend("probe-args-schema FAIL: " . g_Fail . "`n", "*")
    ExitApp(1)
}
FileAppend("probe-args-schema-ok`n", "*")
ExitApp(0)
