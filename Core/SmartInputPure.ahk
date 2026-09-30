#Requires AutoHotkey v2.0
#Warn All, Off

; === SmartInputPure - 输入框纯函数库 (零 GUI/零配置依赖, 探针直测; 文法与 CmdLine_Parse 同源, 改一处必须同步另一处) ===

; ---------------- 纯函数 (无 GUI 依赖, 探针可直测) ----------------

; 前缀补全: 返回首个比 prefix 长的前缀命中, 否则 ""
SI_MatchPrefixPure(prefix, candidates) {
    if (prefix == "")
        return ""
    p := StrLower(prefix)
    plen := StrLen(prefix)
    for _i, cand in candidates {
        if (cand == "")
            continue
        if (StrLen(cand) > plen && SubStr(StrLower(cand), 1, plen) == p)
            return cand
    }
    return ""
}

; 子串过滤: 保持原序, 空 query 返回全池
SI_SubstrPure(query, pool) {
    out := []
    if (query == "") {
        for _i, cand in pool
            out.Push(cand)
        return out
    }
    q := StrLower(query)
    for _i, cand in pool {
        if (cand != "" && InStr(StrLower(cand), q))
            out.Push(cand)
    }
    return out
}

; 接受一词: 从 prefixLen 向后吞掉 [空白* + 非空白+] , 返回新的全文前缀
SI_NextWordPure(full, prefixLen) {
    if (prefixLen >= StrLen(full))
        return full
    rest := SubStr(full, prefixLen + 1)
    if RegExMatch(rest, "^\s*\S+", &m)
        return SubStr(full, 1, prefixLen + StrLen(m[0]))
    return full
}

; 向后删一词: 从 prefixLen 向前吞掉 [空白* + 非空白+], 返回新的全文前缀
SI_PrevWordPure(full, prefixLen) {
    if (prefixLen <= 0)
        return ""
    if (prefixLen > StrLen(full))
        prefixLen := StrLen(full)
    head := RTrim(SubStr(full, 1, prefixLen))
    if (head == "")
        return ""
    if RegExMatch(head, "^(.*\s)?\S+$", &m)
        return m[1] == "" ? "" : RTrim(m[1])
    return ""
}

; 列表行 → 可搜索核心: "command|<id>" 取 id, 裸行取自身.
; 名解析 (id→Name) 在应用层 SI_NameOf 做, 此处保持纯函数零依赖.
; 历史行一律先经 HistSplit 拆包再进此函数, 此处只见干净元素, 不处理参数.
SI_CoreOfPure(element) {
    parts := StrSplit(String(element), " | ")
    if (parts.Length >= 2)
        return Trim(parts[2])
    return Trim(element)
}

; 精确命中判定 (供 SearchCommand 置顶用): 名/id/目标/描述任一与 query 全等 (大小写不敏感).
; 行形态为 SearchRow 产物 Map; 纯函数, 探针手拼 Map 即可测.
SI_IsExactHitRow(row, query) {
    if (query == "" || !IsObject(row))
        return false
    q := StrLower(Trim(String(query)))
    if (q == "")
        return false
    try {
        for _, k in ["name", "id", "target", "desc"] {
            if (row.Has(k) && Trim(String(row[k])) != "" && StrLower(Trim(String(row[k]))) == q)
                return true
        }
    } catch {
    }
    return false
}

; 取命令头 (首空格前): 搜索框里空格=参数分隔符, 含参整句不能直接拿去搜
SI_HeadPure(text) {
    sp := InStr(text, " ")
    if (sp > 0)
        return SubStr(text, 1, sp - 1)
    return text
}

; 隐私: 命中黑名单的不记历史、不参与补全
SI_BlockedPure(text) {
    if (text == "")
        return true
    if RegExMatch(text, "i)(password|passwd|pwd|token|secret|apikey|api_key|creditcard|ssn|身份证|密码|口令)") ; i18n:protocol (隐私黑名单功能词, 非 UI)
        return true
    try {
        extra := Trim(CfgGet("SmartInput", "PrivacyExtra", ""))
        if (extra != "" && InStr(StrLower(text), StrLower(extra)))
            return true
    } catch {
    }
    return false
}

; ---------------- 开关与候选源 ----------------

SI_Enabled() {
    try {
        return CfgGet("SmartInput", "Enabled", "1") = "1"
    } catch {
        return true
    }
}

SI_InputHistAll() {
    global g_SI
    try {
        return g_SI["inputHist"]
    } catch {
        return []
    }
}

; ---------------- 历史规范记录 (结构化, 参数边界与类型无关) ----------------
; 写时归一: HistPack(元素, 参数) 把参数钉在 Chr(1) 之后, 读时 HistSplit 按位拆回.
; 无参数栏即无参条目 (HistPack 无参时不钉分隔符, 现行格式).

HistPack(el, arg := "") {
    el := String(el)
    arg := Trim(String(arg))
    el := StrReplace(el, Chr(1), "")
    arg := StrReplace(arg, Chr(1), "")
    ; ini 行存储: 换行会切断行, 空格化 (粘贴多行/管道参数亦如此)
    el := StrReplace(StrReplace(el, "`r", " "), "`n", " ")
    arg := StrReplace(StrReplace(arg, "`r", " "), "`n", " ")
    if (arg != "")
        return el . Chr(1) . arg
    return el
}

HistSplit(line) {
    line := String(line)
    pos := InStr(line, Chr(1))
    if (pos > 0)
        return Map("el", SubStr(line, 1, pos - 1), "arg", SubStr(line, pos + 1), "has", true)
    return Map("el", line, "arg", "", "has", false)
}

SI_HistoryCores() {
    out := []
    try {
        for _i, element in g_HistoryCommands {
            core := SI_CoreOfPure(HistSplit(element)["el"])
            ; id→名 (文件行 id 含路径, 直接进 Alt+Up 池会污染输入框; 无 Registry 回落裸核)
            try {
                if (IsSet(RimCommand) && IsObject(RimCommand)) {
                    rc := RimCommand.Get(core)
                    if (IsObject(rc) && rc.Name != "")
                        core := rc.Name
                }
            } catch {
            }
            out.Push(core)
        }
    } catch {
    }
    return out
}
; 历史条目 → 用户当初的输入态 (含参还原, 供 Alt+UpDown/ghost 整句复现)
;   规范记录 ("el" . Chr(1) . "arg") → "核 arg"; 无参/旧行 → 与 CoreOfPure 同值
SI_HistoryInputOfPure(element) {
    rec := HistSplit(element)
    core := SI_CoreOfPure(rec["el"])
    if (rec["has"] && Trim(rec["arg"]) != "")
        return core . " " . Trim(rec["arg"])
    return core
}
