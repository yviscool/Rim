#Requires AutoHotkey v2.0
#Warn All, Off

; 只读命令探针: 无副作用命令真执行 (显示/查询/换算类), 副作用命令显式跳过并注明.
; 跳过 (不执行, 理由见末尾 collected-skips): 破坏性/弹窗阻塞/发键/剪切板写/外部网络/慢扫描.
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_readonly_cmds.ahk
#Include ..\Core\Plugin.ahk
#Include ..\Core\Command.ahk
#Include ..\Core\Context.ahk
#Include ..\Core\Common.ahk
#Include ..\Plugins\Kanji.ahk
#Include ..\Plugins\Misc.ahk
#Include ..\Plugins\LauncherSystem.ahk
#Include ..\Plugins\LauncherCore.ahk
#Include ..\Plugins\General.ahk

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

global g_CapDisplay := ""
DisplayResult(text := "") {
    global g_CapDisplay
    g_CapDisplay := text
}

AlignText(t) {
    return t
}

; 与 Search.ahk FilterResult 同语义 (空 needle 原样返回)
FilterResult(text, needle) {
    if (Trim(String(needle)) = "")
        return text
    result := ""
    Loop Parse, text, "`n", "`r" {
        if (!InStr(A_LoopField, " | ") && InStr(A_LoopField, needle))
            result .= A_LoopField "`n"
        else if (InStr(StrReplace(SubStr(A_LoopField, 5), "\", " "), needle))
            result .= A_LoopField "`n"
    }
    return result
}

SetCommandFilter(cmd) {
}

TurnOnResultFilter() {
}

TurnOnRealtimeExec() {
}

; 与 Search.ahk SetExecInterval 同语义 (g_ExecInterval>=0 即置毫秒并返回真)
SetExecInterval(second) {
    global g_ExecInterval, g_LastExecCb
    if (g_ExecInterval >= 0) {
        g_ExecInterval := second * 1000
        return true
    }
    return false
}

global g_Arg := "", FullPipeArg := ""
global g_ExecInterval := 0, g_LastExecCb := ""
global g_VimEngine := ""
global g_ExcludedCommandsObj := Map()

; ---- 1. 简繁换算 (纯函数, 往返; 异体字以引擎表为准; 注意 = 对 CJK 异体按 locale 判等, 必须用 !==) ----
try {
    s2t := Kanji_Convert("简体中文测试", true)
    Ck("kanji-s2t", s2t !== "" && s2t !== "简体中文测试" && StrLen(s2t) = 6, s2t)
    Ck("kanji-roundtrip", Kanji_Convert(s2t, false) == "简体中文测试")
} catch as e {
    Ck("kanji-no-throw", false, e.Message)
}

; ---- 2. URL 编解码 (纯函数) ----
try {
    Ck("url-encode", UriEncode("a b+c中文") == "a+b%2Bc%E4%B8%AD%E6%96%87", UriEncode("a b+c中文"))
} catch as e {
    Ck("url-encode-no-throw", false, e.Message)
}

; ---- 3. 字数统计 (纯逻辑, Host 转发到桩) ----
try {
    global g_Arg := "aa bb cc"
    FullPipeArg := "l1`nl2`nl3`n"
    CountNumber()
    Ck("countnumber", InStr(g_CapDisplay, "3") > 0, SubStr(String(g_CapDisplay), 1, 80))
} catch as e {
    Ck("countnumber-no-throw", false, e.Message)
}

; ---- 4. 环境变量一览: 全程经 RowNavShow (GUI 列表件), headless 不可达, 跳过执行 ----
FileAppend("SKIP: envshow (needs RowNavShow GUI)`n", "*")

; ---- 5. 本机 ping: 同样终点 RowNavShow, 跳过执行 (Misc_RunUtf8 本体可单独验证, 见下) ----
FileAppend("SKIP: ping-localhost (needs RowNavShow GUI)`n", "*")

; ---- 6. 系统状态 (本地只读) ----
try {
    SystemState()
    Ck("systemstate", InStr(g_CapDisplay, "sys.row_state") > 0, SubStr(g_CapDisplay, 1, 80))
} catch as e {
    Ck("systemstate-no-throw", false, e.Message)
}

; ---- 7. Rim 诊断 (自称 headless 安全) ----
try {
    out := RimDoctorCmd()
    Ck("rimdoctor", InStr(out, "[Rim Doctor]") > 0, SubStr(out, 1, 60))
} catch as e {
    Ck("rimdoctor-no-throw", false, e.Message)
}

; ---- 8. Vim 诊断 (无引擎静默跳过) ----
try {
    VimDiagCmd()
    Ck("vimdiag-noengine", true)
} catch as e {
    Ck("vimdiag-no-throw", false, e.Message)
}

; ---- 9. 窗口一览 (只读枚举) ----
; 注意: AHK v2 无内建 IsString(), 一律用 Type(x) = "String" 判定
try {
    ListWindow()
    Ck("listwindow", Type(g_CapDisplay) = "String", SubStr(String(g_CapDisplay), 1, 60))
} catch as e {
    Ck("listwindow-no-throw", false, e.Message . " @" . e.Line)
}

; ---- 10. 服务查询三件套 (WMI 只读, 同 probe_process 模式) ----
try {
    global g_Arg := ""
    ListAllService()
    Ck("listallservice", InStr(g_CapDisplay, "sys.row_service") > 0, SubStr(g_CapDisplay, 1, 60))
} catch as e {
    Ck("listallservice-no-throw", false, e.Message . " @" . e.Line)
}
try {
    ListRunningService()
    Ck("listrunningservice", InStr(g_CapDisplay, "sys.row_service") > 0, SubStr(g_CapDisplay, 1, 60))
} catch as e {
    Ck("listrunningservice-no-throw", false, e.Message . " @" . e.Line)
}
try {
    global g_Arg := "EventLog"
    ShowService()
    Ck("showservice", InStr(g_CapDisplay, "EventLog") > 0, SubStr(g_CapDisplay, 1, 80))
} catch as e {
    Ck("showservice-no-throw", false, e.Message)
}

FileAppend("INFO: collected-skips=破坏性关机/锁屏/睡眠/休眠/清空回收站/调音量/关显示器/注销;弹窗阻塞 CoreInput/InputBox 系(CmdRun/AhkRun/Open/Translate/Dns/InstallPlugin);发键 InsertDate/Time;剪切板写 Clip*/PickColor/SendToClip;外部网络 Translate/PubIp/CurrencyRate;慢扫描 ReindexFiles;GUI 件 StatsBall/ColorPicker/Help/KeyHelp/EditConfig;需目标应用 Explorer/TC/file.* /Vim(Plugins|Keymap)/QR*/Calendar(弹浏览器)/Open/Workspace/system.*`n", "*")

if (g_Fail > 0) {
    FileAppend("probe-readonly-cmds FAIL: " . g_Fail . "`n", "*")
    ExitApp(1)
}
FileAppend("probe-readonly-cmds-ok`n", "*")
ExitApp(0)
