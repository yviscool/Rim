#Requires AutoHotkey v2.0
#Warn All, Off
; === Core/ActionProtocol.ahk - 统一动作协议 v2 ===
; P1-5: 结构化动作对象 + 字符串边界兼容层
; 形态: Map{kind, target, arg, source, raw}
; kind: run|file|dir|cmd|url|command|function|key|plugin|legacy|combo|unknown
; 错误码: OK/EMPTY/UNKNOWN_KIND/UNKNOWN_COMMAND/RECURSION/VALIDATE_FAIL/HANDLER_FAIL
; 字符串协议冻结为 ABI, 只增不改; 双向兜底保留但收敛到 ActionDispatch 一处

global g_ActionTrace := []

ActionParse(raw, source := "") {
    r := Trim(String(raw))
    if (r = "")
        return Map("ok", false, "code", "EMPTY", "kind", "", "target", "", "arg", "", "source", source, "raw", raw, "msg", "empty action")
    if (SubStr(r, 1, 1) = "<" && SubStr(r, -1) = ">")
        r := SubStr(r, 2, StrLen(r) - 2)
    parts := StrSplit(r, "|", , 2)
    kind := StrLower(Trim(parts[1]))
    target := parts.Length >= 2 ? Trim(parts[2]) : ""
    valid := Map("run", 1, "file", 1, "dir", 1, "cmd", 1, "url", 1, "command", 1, "function", 1, "key", 1, "plugin", 1, "legacy", 1, "combo", 1)
    if (!valid.Has(kind)) {
        if (InStr(r, "|"))
            return Map("ok", false, "code", "UNKNOWN_KIND", "kind", kind, "target", target, "arg", "", "source", source, "raw", raw, "msg", "unknown kind: " . kind)
        return Map("ok", true, "code", "OK", "kind", "command", "target", r, "arg", "", "source", source, "raw", raw, "msg", "")
    }
    return Map("ok", true, "code", "OK", "kind", kind, "target", target, "arg", "", "source", source, "raw", raw, "msg", "")
}

ActionDispatch(actMap, actionArg := "") {
    if (!IsObject(actMap) || !actMap.Has("kind"))
        return Map("ok", false, "code", "VALIDATE_FAIL", "msg", "bad action object")
    if (!actMap["ok"])
        return Map("ok", false, "code", actMap["code"], "msg", actMap["msg"])
    kind := actMap["kind"]
    target := actMap["target"]
    source := actMap.Has("source") ? actMap["source"] : ""
    arg := actionArg != "" ? actionArg : (actMap.Has("arg") ? actMap["arg"] : "")
    try ActionTracePush(kind, target, source)
    if (kind = "command") {
        if (IsSet(RimCommand) && IsObject(RimCommand) && RimCommand.Registry.Has(target)) {
            try {
                RimCommand.Execute(target, arg)
                return Map("ok", true, "code", "OK", "msg", "")
            } catch as ex {
                return Map("ok", false, "code", "HANDLER_FAIL", "msg", ex.Message)
            }
        }
        return Map("ok", false, "code", "UNKNOWN_COMMAND", "msg", "unknown command: " . target)
    }
    if (kind = "function" || kind = "legacy") {
        fn := target
        if (fn = "")
            return Map("ok", false, "code", "VALIDATE_FAIL", "msg", "empty function")
        try {
            if (IsSet(RimCommand) && IsObject(RimCommand) && RimCommand.Registry.Has(fn)) {
                RimCommand.Execute(fn, arg)
                return Map("ok", true, "code", "OK", "msg", "")
            }
            if (IsSet(RimCommand) && IsObject(RimCommand) && RimCommand.Registry.Has("legacy." . fn)) {
                RimCommand.Execute("legacy." . fn, arg)
                return Map("ok", true, "code", "OK", "msg", "")
            }
        } catch as ex {
            return Map("ok", false, "code", "HANDLER_FAIL", "msg", ex.Message)
        }
        return Map("ok", false, "code", "UNKNOWN_COMMAND", "msg", "unknown function: " . fn)
    }
    if (kind = "combo") {
        ; 手势 combo 起臂 (如 combo|zoom): 与 Gesture/Engine.ahk ComboArm 同语义,
        ; 统一入口不再报 UNKNOWN_KIND, 无手势引擎时降级为 OK_DEFER
        try {
            if (IsSet(GestureEngine) && IsObject(GestureEngine)) {
                GestureEngine.ComboArm(kind . "|" . target)
                return Map("ok", true, "code", "OK", "msg", "")
            }
        } catch as ex {
            return Map("ok", false, "code", "HANDLER_FAIL", "msg", ex.Message)
        }
        return Map("ok", true, "code", "OK_DEFER", "msg", "defer to ExecuteAction_Body")
    }
    return Map("ok", true, "code", "OK_DEFER", "msg", "defer to ExecuteAction_Body")
}

ActionTracePush(kind, target, source) {
    global g_ActionTrace
    try {
        g_ActionTrace.Push(Map("t", A_TickCount, "kind", kind, "target", SubStr(target, 1, 80), "source", source))
        if (g_ActionTrace.Length > 50)
            g_ActionTrace.RemoveAt(1)
    }
}

ActionLastTrace() {
    global g_ActionTrace
    out := ""
    try {
        for _, it in g_ActionTrace {
            out .= it["kind"] . "|" . it["target"] . "(" . it["source"] . ") <- "
        }
    }
    return RTrim(out, " <- ")
}

; 运行时前检: 与 probe_dead_refs 同词表语义 (裸函数/点式/Registry 三形态),
; 未知名字直接判 false, 调用方记 UNKNOWN_FUNCTION, 不再靠 %fn%() 抛 "Variable not found"
ActionIsCallable(fn) {
    fn := Trim(String(fn))
    if (fn = "" || InStr(fn, "`n") || InStr(fn, "|") || InStr(fn, " "))
        return false
    if (InStr(fn, ".")) {
        parts := StrSplit(fn, ".")
        if (parts.Length != 2 || parts[1] = "" || parts[2] = "")
            return false
        try {
            clsRef := %parts[1]%
            if (IsObject(clsRef) && HasMethod(clsRef, parts[2]))
                return true
        } catch {
        }
        return false
    }
    try {
        if (IsSet(RimCommand) && IsObject(RimCommand) && IsObject(RimCommand.Registry)) {
            if (RimCommand.Registry.Has(fn) || RimCommand.Registry.Has("legacy." . fn))
                return true
        }
    } catch {
    }
    ; 裸函数名: 双解引用取 Func 对象 (IsFunc 在此构建不存在, 调用即抛, 实测锤实)
    try {
        ref := %fn%
        if (Type(ref) = "Func")
            return true
    } catch {
    }
    return false
}

; 点式静态调用: "Class.Method" (+可选参数). %fn%() 不支持点式 (实测 Variable not found),
; 模板默认动作 (GestureEngine.NoOp/IgnoreNext) 全走此口. 返回 true=已调用.
ActionCallDotted(fn, fnArg := "") {
    parts := StrSplit(fn, ".")
    if (parts.Length != 2 || parts[1] = "" || parts[2] = "")
        return false
    try {
        clsRef := %parts[1]%
        if (!IsObject(clsRef))
            return false
        if (fnArg != "")
            clsRef.%parts[2]%(fnArg)
        else
            clsRef.%parts[2]%()
        return true
    } catch {
        return false
    }
}
