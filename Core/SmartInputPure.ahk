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

; 历史元素/命令元素 → 可搜索核心 (与 SearchTargetKey 同一文法, 必须同步改)
;   真四段式 key|type|cmd|desc (parts[2] 是类型词) → key
;   历史 legacy 三段 + 参数 (parts[2] 是命令名) → parts[2], 绝不能取 parts[1]
SI_CoreOfPure(element) {
    parts := StrSplit(element, " | ")
    if (parts.Length >= 4
        && (parts[2] == "file" || parts[2] == "function" || parts[2] == "cmd" || parts[2] == "url" || parts[2] == "run"))
        return Trim(parts[1])
    if (parts.Length >= 2 && parts[1] == "function")
        return Trim(parts[2])
    if (parts.Length >= 2 && parts[1] == "file") {
        fn := ""
        noext := ""
        try {
            SplitPath(parts[2], &fn, , , &noext)
        } catch {
        }
        if (noext != "")
            return noext
        if (fn != "")
            return fn
        return Trim(parts[2])
    }
    if (parts.Length >= 2)
        return Trim(parts[2])
    return Trim(element)
}

; 精确命中判定 (供 SearchCommand 置顶用): 别名核或任一段与 query 全等 (大小写不敏感)
SI_IsExactHit(element, query) {
    if (query == "")
        return false
    q := StrLower(Trim(query))
    if (q == "")
        return false
    try {
        if (StrLower(SI_CoreOfPure(element)) == q)
            return true
        for _i, seg in StrSplit(element, " | ") {
            if (StrLower(Trim(seg)) == q)
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
        extra := Trim(g_Conf.Get("SmartInput", "PrivacyExtra", ""))
        if (extra != "" && InStr(StrLower(text), StrLower(extra)))
            return true
    } catch {
    }
    return false
}

; ---------------- 开关与候选源 ----------------

SI_Enabled() {
    try {
        return g_Conf.Get("SmartInput", "Enabled", "1") = "1"
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

SI_HistoryCores() {
    out := []
    try {
        for _i, element in g_HistoryCommands
            out.Push(SI_CoreOfPure(element))
    } catch {
    }
    return out
}
; 历史条目 → 用户当初的输入态 (含参还原, 供 Alt+UpDown/ghost 整句复现)
;   legacy 三段 + 参数 ("function | X | desc | arg") → "X arg"
;   真四段 + 参数 ("key | type | cmd | desc | arg") → "key arg"
;   无参条目 → 与 CoreOfPure 同值; file 三段 desc/arg 歧义, 保守只取文件名
SI_HistoryInputOfPure(element) {
    parts := StrSplit(element, " | ")
    if (parts.Length >= 5
        && (parts[2] == "file" || parts[2] == "function" || parts[2] == "cmd" || parts[2] == "url" || parts[2] == "run")) {
        arg := Trim(parts[5])
        i := 6
        while (i <= parts.Length) {
            arg .= " | " . Trim(parts[i])
            i++
        }
        if (arg != "")
            return Trim(parts[1]) . " " . arg
        return Trim(parts[1])
    }
    if (parts.Length == 4) {
        if (parts[2] == "file" || parts[2] == "function" || parts[2] == "cmd" || parts[2] == "url" || parts[2] == "run")
            return Trim(parts[1])
        if (parts[1] == "file" || parts[1] == "function" || parts[1] == "cmd" || parts[1] == "url" || parts[1] == "run") {
            arg4 := Trim(parts[4])
            if (arg4 != "")
                return Trim(parts[2]) . " " . arg4
            return Trim(parts[2])
        }
    }
    return SI_CoreOfPure(element)
}
