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
        ; 内联参数优先 (旧 ExecuteAction_Body 语义: parts[2] 有则用, 否则 actionArg);
        ; 余段用 "|" 接回 (旧逻辑截断丢参, 此处修全). 调用序列收敛到 ActionRunFunction.
        targParts := StrSplit(target, "|")
        fn := Trim(targParts[1])
        if (fn = "")
            return Map("ok", false, "code", "VALIDATE_FAIL", "msg", "empty function")
        inlineArg := ""
        if (targParts.Length >= 2) {
            inlineArg := Trim(targParts[2])
            i := 3
            while (i <= targParts.Length) {
                inlineArg .= "|" . Trim(targParts[i])
                i++
            }
        }
        effArg := inlineArg != "" ? inlineArg : arg
        if (ActionRunFunction(fn, effArg, actMap["raw"]))
            return Map("ok", true, "code", "OK", "msg", "")
        return Map("ok", false, "code", "HANDLER_FAIL", "msg", "unknown function: " . fn)
    }
    if (kind = "combo") {
        ; 手势 combo 起臂收敛到 ActionArmCombo; 无手势引擎时降级为 OK_DEFER
        if (ActionArmCombo(kind . "|" . target))
            return Map("ok", true, "code", "OK", "msg", "")
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

; 统一 function| 调用序列 (Execution / GestureEngine / LegacyDirectCall 三处收敛于此):
; Registry → legacy. → 点式 → 前检 → 直调.
; 调用方保留各自的参数拆分 (Execution 认 actionArg, 手势只认裸名, LegacyDirectCall 认 content 内参).
; 返回 true=已执行; false=无人认领 (调用方记 UNKNOWN, 不再下坠重试).
; quiet=true 跳过 UNKNOWN 日志 (手势旧语义静默); rethrow=true 则最终失败直接抛 (手势旧语义上抛).
; viaRegistry=false 跳过注册表 (LegacyDirectCall 专用: 它本身就是 Registry 动作的实现体,
; 再查表会自指无限递归, 且该环不经过 ExecuteAction 深度守卫, 必栈爆).
ActionRunFunction(fn, fnArg := "", origin := "", quiet := false, rethrow := false, viaRegistry := true) {
    fn := Trim(String(fn))
    if (fn = "")
        return false
    if (fnArg != "") {
        try {
            global g_Arg
            g_Arg := fnArg
        } catch {
        }
    }
    if (viaRegistry && IsSet(ExecuteCommandId)) {
        try {
            if (ExecuteCommandId(fn, fnArg))
                return true
            if (ExecuteCommandId("legacy." . fn, fnArg))
                return true
        } catch {
        }
    } else if (viaRegistry && IsSet(RimCommand) && IsObject(RimCommand) && IsObject(RimCommand.Registry)) {
        ; 探针子集 (未包含 Execution.ahk): 直查注册表, 无合流点可走
        try {
            if (RimCommand.Registry.Has(fn)) {
                RimCommand.Execute(fn, fnArg)
                return true
            }
            if (RimCommand.Registry.Has("legacy." . fn)) {
                RimCommand.Execute("legacy." . fn, fnArg)
                return true
            }
        } catch {
            return false
        }
    }
    ; 点式静态方法: %fn%() 不支持点式, 先试点式; 判死即停, 不再落到 %fn%() 报 Variable not found
    if (InStr(fn, ".")) {
        dottedOk := false
        try dottedOk := ActionCallDotted(fn, fnArg)
        catch {
            dottedOk := false
        }
        if (dottedOk)
            return true
        if (!quiet) {
            try RimLog("UNKNOWN_FUNCTION", (origin != "" ? origin : "function|" . fn) . " fn=" . fn)
            catch {
            }
        }
        return false
    }
    ; 运行时前检: 未知名字直接判死, 不靠 %fn%() 抛错
    try {
        if (!ActionIsCallable(fn)) {
            if (!quiet) {
                try RimLog("UNKNOWN_FUNCTION", (origin != "" ? origin : "function|" . fn) . " fn=" . fn)
                catch {
                }
            }
            return false
        }
    } catch {
        return false
    }
    if (fnArg != "") {
        try {
            %fn%(fnArg)
            return true
        } catch {
        }
    }
    try {
        %fn%()
        return true
    } catch as e {
        if (rethrow)
            throw e
        try RimLog("EXEC_FAILED", (origin != "" ? origin : "function|" . fn) . " fn=" . fn, e)
        catch {
        }
        return false
    }
}

; 统一 combo 起臂 (Execution / ActionDispatch 收敛于此; GestureEngine 内调直连 ComboArm, 同文件零依赖)
ActionArmCombo(actStr) {
    s := Trim(String(actStr))
    if (SubStr(s, 1, 6) != "combo|")
        return false
    try {
        if (IsSet(GestureEngine) && IsObject(GestureEngine)) {
            GestureEngine.ComboArm(s)
            return true
        }
    } catch {
        return false
    }
    return false
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
