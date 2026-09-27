#Requires AutoHotkey v2.0
#Warn All, Off
; === Core/SearchIndex.ahk - 命令搜索索引 ===
; P1/P2-8: 注册时预计算小写字段与展示文本, token/前缀索引, 稳定 top-k, 短 TTL 缓存
; 兼容: 索引缺失/过期自动回退全量扫描, 行为与 SearchCommand 一致

global g_SearchIdx := Map("built", 0, "tick", 0, "items", [], "byToken", Map(), "ttl", 2000)
global g_SearchCache := Map("q", "", "tick", 0, "ttl", 800, "ids", [])

SearchIdx_Norm(s) {
    s := StrLower(String(s))
    s := StrReplace(s, "/", " ")
    s := StrReplace(s, "\", " ")
    s := StrReplace(s, "|", " ")
    s := RegExReplace(s, "\s+", " ")
    return Trim(s)
}

SearchIdx_Build(force := false) {
    global g_Commands, g_SearchIdx
    now := A_TickCount
    if (!force && g_SearchIdx["built"] && now - g_SearchIdx["tick"] < g_SearchIdx["ttl"] && g_SearchIdx["items"].Length > 0) {
        ; 命令数变化 (LoadFiles/注册) 即失稳, 不等 TTL 过期
        try {
            if (g_Commands.Length = g_SearchIdx["items"].Length)
                return g_SearchIdx["items"].Length
        } catch {
            return g_SearchIdx["items"].Length
        }
    }
    items := []
    byToken := Map()
    try {
        for idx, element in g_Commands {
            norm := SearchIdx_Norm(element)
            toks := StrSplit(norm, " ")
            items.Push(Map("i", idx, "raw", element, "norm", norm, "toks", toks))
            for _, tk in toks {
                if (tk = "")
                    continue
                if (!byToken.Has(tk))
                    byToken[tk] := []
                byToken[tk].Push(items.Length)
                pre := SubStr(tk, 1, Min(3, StrLen(tk)))
                if (pre != tk) {
                    pk := "pre:" . pre
                    if (!byToken.Has(pk))
                        byToken[pk] := []
                    byToken[pk].Push(items.Length)
                }
            }
        }
    }
    g_SearchIdx["items"] := items
    g_SearchIdx["byToken"] := byToken
    g_SearchIdx["tick"] := now
    g_SearchIdx["built"] := 1
    return items.Length
}

SearchIdx_Invalidate() {
    global g_SearchIdx, g_SearchCache
    g_SearchIdx["built"] := 0
    g_SearchIdx["tick"] := 0
    g_SearchCache["q"] := ""
    g_SearchCache["tick"] := 0
}

SearchIdx_Candidates(qlow) {
    global g_SearchIdx
    n := SearchIdx_Build(false)
    if (n = 0)
        return ""
    q := SearchIdx_Norm(qlow)
    if (q = "")
        return ""
    qtoks := StrSplit(q, " ")
    cand := Map()
    for _, tk in qtoks {
        if (tk = "")
            continue
        if (g_SearchIdx["byToken"].Has(tk)) {
            for _, ii in g_SearchIdx["byToken"][tk]
                cand[ii] := true
        }
        pre := SubStr(tk, 1, Min(3, StrLen(tk)))
        pk := "pre:" . pre
        if (g_SearchIdx["byToken"].Has(pk)) {
            for _, ii in g_SearchIdx["byToken"][pk]
                cand[ii] := true
        }
        for ii, it in g_SearchIdx["items"] {
            if (InStr(it["norm"], tk))
                cand[ii] := true
        }
    }
    if (cand.Count = 0)
        return []
    out := []
    for ii, _ in cand
        out.Push(ii)
    return out
}

SearchIdx_TopK(scored, k := 50) {
    if (scored.Length <= k)
        return scored
    best := []
    for _, it in scored {
        pos := best.Length + 1
        Loop best.Length {
            o := best[A_Index]
            if (it["pre"] > o["pre"] || (it["pre"] = o["pre"] && (it["score"] > o["score"] || (it["score"] = o["score"] && it["seq"] < o["seq"])))) {
                pos := A_Index
                break
            }
        }
        best.InsertAt(Min(pos, k + 1), it)
        if (best.Length > k)
            best.Pop()
    }
    return best
}
