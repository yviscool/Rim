#Requires AutoHotkey v2.0
#Warn All, Off
; 点式动作探针: %fn%() 不支持 "Class.Method" (实测 Variable not found),
; 模板默认动作 (GestureEngine.NoOp/IgnoreNext) 全死于此.
; 修法: ActionProtocol.ActionCallDotted, 两处执行器 (Execution/GestureEngine) 优先试点式.

T(key, *) => key
RimLog(level, msg, err := "") {
    return
}

#Include ..\Core\Runtime.ahk
#Include ..\Core\ActionProtocol.ahk

class ProbeDotCls {
    static Ping(arg := "") {
        global g_ProbeDotHit
        g_ProbeDotHit := "hit:" . arg
    }
}

global g_ProbeDotHit := ""

fails := []
Check(name, cond) {
    global fails
    if (!cond)
        fails.Push(name)
}

Main() {
    global fails, g_ProbeDotHit
    Check("dotted-arg", ActionCallDotted("ProbeDotCls.Ping", "hi") && g_ProbeDotHit = "hit:hi")
    g_ProbeDotHit := ""
    Check("dotted-noarg", ActionCallDotted("ProbeDotCls.Ping") && g_ProbeDotHit = "hit:")
    Check("dotted-missing", !ActionCallDotted("ProbeDotCls.Nope"))
    Check("dotted-noclass", !ActionCallDotted("NoSuchCls.Ping"))
    Check("dotted-malformed", !ActionCallDotted("NoDot") && !ActionCallDotted("A.B.C") && !ActionCallDotted(".Ping"))
    Check("bare-still-false", !ActionCallDotted("BareFunc"))
    ; 真接线静态断言 (调用序列收敛到 ActionRunFunction, 手势探针子集保留直调兜底)
    protoSrc := FileRead(A_ScriptDir . "\..\Core\ActionProtocol.ahk", "UTF-8")
    Check("wire-exec", InStr(protoSrc, "ActionCallDotted(fn, fnArg)") > 0 && InStr(protoSrc, "ActionRunFunction(fn, fnArg") > 0)
    engSrc := FileRead(A_ScriptDir . "\..\Core\Gesture\Engine.ahk", "UTF-8")
    Check("wire-engine", InStr(engSrc, "ActionCallDotted(fn)") > 0)
    iniSrc := FileRead(A_ScriptDir . "\..\Conf\rim.ini", "UTF-8")
    Check("ini-dotted", InStr(iniSrc, "function|GestureEngine.IgnoreNext") > 0 && InStr(iniSrc, "function|GestureEngine.NoOp") > 0)
    Check("ini-no-bare", !InStr(iniSrc, "function|Gesture_IgnoreNext") && !InStr(iniSrc, "function|Gesture_NoOp"))
    tplSrc := FileRead(A_ScriptDir . "\..\Conf\rim.template.ini", "UTF-8")
    Check("tpl-dotted", InStr(tplSrc, "function|GestureEngine.NoOp") > 0)
    out := A_ScriptDir . "\..\probe_dotted_action.out.txt"
    try FileDelete(out)
    catch {
    }
    if (fails.Length > 0) {
        txt := "dotted-action-FAIL:`n"
        for _, x in fails
            txt .= "  - " . x . "`n"
        FileAppend(txt, out, "UTF-8")
        ExitApp(1)
    }
    FileAppend("dotted-action-ok`n", out, "UTF-8")
    ExitApp(0)
}

Main()
