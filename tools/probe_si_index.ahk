#Requires AutoHotkey v2.0
#Warn All, Off
; R2-3 回归: ghost 保序一致 + CheckState 前缀集合等价 + ValidateDelay 缓存.
; ghost: 新分段 (小源线性+大表缓存数组) vs 旧全拼 cands 后 SI_MatchPrefixPure, 逐前缀相等.
; state: SI_CheckState vs 三表暴力前缀扫描, 逐输入相等.
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_si_index.ahk

#Include ..\Core\Command.ahk
#Include ..\Core\SmartInputPure.ahk
#Include ..\Core\SmartInput.ahk
#Include ..\Core\Search.ahk

global g_CommandAlias := Map()
global g_HistoryCommands := []
global g_CurrentCommandList := []
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

TypeLabel(type) {
    return type
}

CfgGet(sec, key, def := "") {
    return def
}

EvalExpression(input) {
    return ""
}

OldGhost(prefix) {
    global g_CurrentCommandList
    cands := []
    try {
        if (g_CurrentCommandList.Length > 0) {
            headCore := SI_NameOf(SI_CoreOfPure(HistSplit(g_CurrentCommandList[1])["el"]))
            if (headCore != "")
                cands.Push(headCore)
        }
    } catch {
    }
    try {
        for _i, element in g_CurrentCommandList {
            if (_i > 30)
                break
            cands.Push(SI_NameOf(SI_CoreOfPure(HistSplit(element)["el"])))
        }
    } catch {
    }
    for _, cand in SI_InputHistAll()
        cands.Push(cand)
    for _, cand in SI_HistoryInputs()
        cands.Push(cand)
    for _, cand in SI_HistoryCores()
        cands.Push(cand)
    for _, cand in SI_CommandCores()
        cands.Push(cand)
    return SI_MatchPrefixPure(prefix, cands)
}

OldState(input) {
    if (input == "")
        return -1
    first := SubStr(input, 1, 1)
    if (first == "@" || first == "|" || first == ";" || first == ":")
        return -1
    head := input
    sp := InStr(input, " ")
    if (sp > 0)
        head := SubStr(input, 1, sp - 1)
    if (head == "")
        return -1
    try {
        if (TryEvalInput(input) != "")
            return 1
    } catch {
    }
    hl := StrLower(head)
    hlen := StrLen(head)
    try {
        for _, cand in SI_InputHistAll() {
            if (cand != "" && SubStr(StrLower(cand), 1, hlen) == hl)
                return 1
        }
        for _, cand in SI_HistoryCores() {
            if (cand != "" && SubStr(StrLower(cand), 1, hlen) == hl)
                return 1
        }
        for _, cand in SI_CommandCores() {
            if (cand != "" && SubStr(StrLower(cand), 1, hlen) == hl)
                return 1
        }
    } catch {
        return -1
    }
    return 0
}

; ---- 建表 ----
RimCommand.Register("Weixin", "Weixin", "", Map("Description", "chat"))
RimCommand.Register("ShutdownTimer", "ShutdownTimer", "", Map("Description", "timer"))
RimCommand.Register("ShowIp", "ShowIp", "", Map("Description", "ip"))
global g_SI
g_SI["inputHist"] := ["weixin", "ShutdownTimer 30"]
g_HistoryCommands.Push("command | Weixin")
g_CurrentCommandList := ["command | Weixin", "command | ShutdownTimer", "command | ShowIp"]

for _, p in ["w", "we", "wei", "weix", "weixi", "weixin", "s", "sh", "shu", "shutdowntimer", "x", "zz", ""] {
    Ck("ghost-" . (p = "" ? "empty" : p), SI_FindGhost(p) = OldGhost(p), "new=[" . SI_FindGhost(p) . "] old=[" . OldGhost(p) . "]")
}
for _, ipt in ["weixin", "weixin x", "ShutdownTimer", "qq", "zz_nomatch", "", "@x", "1+2", "ShowIp"] {
    Ck("state-" . (ipt = "" ? "empty" : ipt), SI_CheckState(ipt) = OldState(ipt), "new=" . SI_CheckState(ipt) . " old=" . OldState(ipt))
}
; 全表兜底分支 (小源无命中时走缓存数组): 前缀只在全表有
g_CurrentCommandList := []
g_SI["inputHist"] := []
g_HistoryCommands := []
Ck("ghost-table-only", SI_FindGhost("show") = OldGhost("show"), SI_FindGhost("show"))
Ck("state-table-only", SI_CheckState("show") = OldState("show"), String(SI_CheckState("show")))
; 延迟缓存: 默认 300, 两次一致
d1 := SI_ValidateDelay()
d2 := SI_ValidateDelay()
Ck("delay-default", d1 = 300 && d2 = 300, d1 . "/" . d2)
; 前缀集合非空且含预期键
Ck("prefixset-hit", SI_PrefixSet().Has("weixin") && SI_PrefixSet().Has("sh"), "")

if (g_Fail > 0) {
    FileAppend("probe-si-index FAIL: " . g_Fail . "`n", "*")
    ExitApp(1)
}
FileAppend("probe-si-index-ok`n", "*")
ExitApp(0)
