#Requires AutoHotkey v2.0
#Warn All, Off
; P8: 搜索索引探针 (预计算+token/前缀+top-k+TTL+回退一致)

T(key, *) => key
RimLog(level, msg, err := "") {
    return
}

global g_Commands := ["run | notepad.exe |记事本", "file | C:\Windows\System32\calc.exe |计算器", "key | ctrl+s |保存", "run | mspaint.exe |画图"]
global g_ExcludedCommands := ""

#Include ..\Core\SearchIndex.ahk

fails := []
Check(name, cond) {
    global fails
    if (!cond)
        fails.Push(name)
}

Main() {
    global fails, g_Commands, g_SearchIdx
    n := SearchIdx_Build(true)
    Check("built", n = 4 && g_SearchIdx["items"].Length = 4)
    Check("norm", SearchIdx_Norm("A/B\C|D") = "a b c d")
    c := SearchIdx_Candidates("notepad")
    Check("candidates-hit", IsObject(c) && c.Length >= 1)
    c2 := SearchIdx_Candidates("zzzqqq")
    Check("candidates-miss", !IsObject(c2) || c2.Length = 0)
    scored := [Map("pre", 1, "score", 5.0, "seq", 3), Map("pre", 0, "score", 9.0, "seq", 1), Map("pre", 1, "score", 7.0, "seq", 2)]
    top := SearchIdx_TopK(scored, 2)
    Check("topk-len", top.Length = 2)
    Check("topk-order", top[1]["score"] = 7.0 && top[2]["score"] = 5.0)
    SearchIdx_Invalidate()
    Check("invalidate", g_SearchIdx["built"] = 0)
    n2 := SearchIdx_Build(false)
    Check("rebuild", n2 = 4)
    ; 命令数变化自动失稳重建 (不等 TTL)
    g_Commands.Push("run | calc.exe |计算器2")
    n3 := SearchIdx_Build(false)
    Check("count-change-rebuild", n3 = 5)
    g_Commands.Pop()
    ; O(n²) 字符串去重已消除 (等价 Map 替代, 排除表用镜像 Obj; 注释提及不算)
    searchSrc := FileRead(A_ScriptDir . "\..\Core\Search.ahk", "UTF-8")
    Check("no-fullresult", !RegExMatch(searchSrc, "fullResult\s*(:=|\.=)"))
    Check("no-fullresult-instr", !RegExMatch(searchSrc, "InStr\(fullResult"))
    Check("seenexact-wired", InStr(searchSrc, "seenExact[element] := true") > 0)
    Check("excluded-obj", InStr(searchSrc, "g_ExcludedCommandsObj.Has(element)") > 0)
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
        got := SearchIdx_TopK(scored, k)
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
