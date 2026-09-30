#Requires AutoHotkey v2.0
#Warn All, Off
; 搜索排序探针: 稳定 top-k (pre/score/seq 比较器, 与旧插入排序逐项一致)
; (token/前缀索引/Candidates/Build 预热已随 SearchIndex.ahk 退役: 生产零调用)

T(key, *) => key
RimLog(level, msg, err := "") {
    return
}

#Include ..\Core\Search.ahk

fails := []
Check(name, cond) {
    global fails
    if (!cond)
        fails.Push(name)
}

Main() {
    global fails
    scored := [Map("pre", 1, "score", 5.0, "seq", 3), Map("pre", 0, "score", 9.0, "seq", 1), Map("pre", 1, "score", 7.0, "seq", 2)]
    top := Search_TopK(scored, 2)
    Check("topk-len", top.Length = 2)
    Check("topk-order", top[1]["score"] = 7.0 && top[2]["score"] = 5.0)
    Check("topk-empty-k", Search_TopK(scored, 0).Length = 0)
    ; O(n²) 字符串去重已消除 (等价 Map 替代, 排除表用镜像 Obj; 注释提及不算)
    searchSrc := FileRead(A_ScriptDir . "\..\Core\Search.ahk", "UTF-8")
    Check("no-fullresult", !RegExMatch(searchSrc, "fullResult\s*(:=|\.=)"))
    Check("no-fullresult-instr", !RegExMatch(searchSrc, "InStr\(fullResult"))
    Check("no-gcommands-loop", !InStr(searchSrc, "for index, element in g_Commands"))
    Check("registry-loop", InStr(searchSrc, "for id, cmd in RimCommand.Registry") > 0)
    Check("excluded-obj", InStr(searchSrc, 'excludedObj.Has(row["rankKey"])') > 0
        && InStr(searchSrc, "SearchCollectOne(id, cmd, query, showExt, searchFull, seenTargets, matchItems, g_ExcludedCommandsObj)") > 0)
    Check("seen-targets", InStr(searchSrc, 'seenTargets[row["targetKey"]] := true') > 0)
    Check("topk-wired", InStr(searchSrc, "Search_TopK(nonExact, topK)") > 0)
    Check("no-searchidx", !InStr(searchSrc, "SearchIdx_"))
    scored := []
    Loop 60 {
        i := A_Index
        scored.Push(Map("pre", Mod(i, 3) = 0 ? 1 : 0, "score", Mod(i * 7, 11) + 0.0, "seq", i))
    }
    ref := []
    for _, it in scored {
        pos := ref.Length + 1
        Loop ref.Length {
            o := ref[A_Index]
            if (it["pre"] > o["pre"] || (it["pre"] = o["pre"] && it["score"] > o["score"])) {
                pos := A_Index
                break
            }
        }
        ref.InsertAt(pos, it)
    }
    for _, k in [1, 5, 15, 59, 60, 200] {
        got := Search_TopK(scored, k)
        want := Min(k, ref.Length)
        ok := (got.Length = want)
        if (ok) {
            Loop want {
                if (got[A_Index]["seq"] != ref[A_Index]["seq"]) {
                    ok := false
                    break
                }
            }
        }
        Check("topk-parity-k" . k, ok)
    }
    out := A_ScriptDir . "\..\probe_search_index.out.txt"
    try FileDelete(out)
    catch {
    }
    if (fails.Length > 0) {
        txt := "search-index-FAIL:`n"
        for _, x in fails
            txt .= "  - " . x . "`n"
        FileAppend(txt, out, "UTF-8")
        ExitApp(1)
    }
    FileAppend("search-index-ok`n", out, "UTF-8")
    ExitApp(0)
}

Main()
