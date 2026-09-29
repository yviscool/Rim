#Requires AutoHotkey v2.0
#Warn All, Off

; === Search - 搜索逻辑 (从 RunZ Core/Search.ahk 移植) ===

; 收集匹配 (Registry 唯一真相源; 返回 matchItems 数组, 每项 {idline, show, exact, row}).
; query 为空串时返回全池 (首屏用). 调用方负责头退化与渲染.
SearchCollectMatches(query, showExt := false, searchFull := false) {
    global g_ExcludedCommandsObj
    ; 同目标只展示首个命中
    seenTargets := Map()
    matchItems := []
    if (IsSet(RimCommand) && IsObject(RimCommand)) {
        for id, cmd in RimCommand.Registry {
            row := ""
            try row := RimCommand.SearchRow(cmd, showExt, searchFull)
            catch {
                continue
            }
            try {
                if (IsObject(g_ExcludedCommandsObj) && g_ExcludedCommandsObj.Has(row["rankKey"]))
                    continue
            } catch {
            }

            if (query = "" || MatchCommand(row["search"], query)) {
                if (seenTargets.Has(row["targetKey"]))
                    continue
                seenTargets[row["targetKey"]] := true
                exactHit := false
                try {
                    exactHit := SI_IsExactHitRow(row, query)
                } catch {
                }
                matchItems.Push(Map("idline", "command | " . row["id"], "show", row["show"], "exact", exactHit, "row", row))
            }
        }
    }
    return matchItems
}

; 核心搜索函数
SearchCommand(command := "", firstRun := false) {
    global g_UseDisplay, g_ExecInterval, g_PipeArg, g_CurrentInput, g_CurrentCommand
    global g_CurrentCommandList, g_FallbackCommands, g_FirstChar, g_DisplayRows
    global g_EnableTCMatch, g_SkinConf
    global g_UseResultFilter, g_UseRealtimeExec, g_InputEdit, g_DisplayEdit
    global g_WindowName, g_UseFallbackCommands, g_Arg, g_Conf, g_RowActive
    global g_ExcludedCommandsObj

    g_UseDisplay := false
    g_RowActive := false
    g_ExecInterval := -1
    result := ""
    ; 排除表用 LoadFiles/ChangeRank 同步维护的 g_ExcludedCommandsObj (键为 rankKey 形)
    static resultToFilter := ""
    commandPrefix := SubStr(command, 1, 1)

    ; 分号/冒号前缀
    if (commandPrefix = ";" || commandPrefix = ":") {
        g_UseResultFilter := false
        g_UseRealtimeExec := false
        resultToFilter := ""
        g_PipeArg := ""

        if (commandPrefix = ";")
            g_CurrentCommand := g_FallbackCommands.Length >= 1 ? g_FallbackCommands[1] : ""
        else if (g_FallbackCommands.Length >= 2)
            g_CurrentCommand := g_FallbackCommands[2]
        else if (g_FallbackCommands.Length >= 1)
            g_CurrentCommand := g_FallbackCommands[1]
        else
            g_CurrentCommand := ""

        g_CurrentCommandList := []
        g_CurrentCommandList.Push(g_CurrentCommand)
        shown := RimCommand.ShowOf(g_CurrentCommand)
        try {
            if ((g_SkinConf.Has("HideCol2") ? g_SkinConf["HideCol2"] : "0") = "1") {
                for _, _tp in ["file | ", "function | ", "cmd | ", "command | ", "url | ", "run | "]
                    shown := StrReplace(shown, _tp)
            } else {
                shown := StrReplace(shown, "file | ", TypeLabel("file"))
                shown := StrReplace(shown, "function | ", TypeLabel("function"))
                shown := StrReplace(shown, "cmd | ", TypeLabel("cmd"))
                shown := StrReplace(shown, "command | ", TypeLabel("command"))
                shown := StrReplace(shown, "url | ", TypeLabel("url"))
                shown := StrReplace(shown, "run | ", TypeLabel("run"))
            }
        } catch {
        }
        result .= Chr(g_FirstChar) ">| " . shown
        DisplaySearchResult(result)
        return result
    }
    ; 管道前缀 |
    else if (commandPrefix = "|" && g_Arg != "") {
        if (g_PipeArg = "")
            g_PipeArg := g_Arg
        command := SubStr(command, 2)
        if (SubStr(command, 1, 1) = "@") {
            command := SubStr(command, 1, 4)
            return
        }
    }
    ; 空格 → 原版行为: 已有当前命令"且空格前就是它"时冻结显示输参;
    ; 头对不上 (IME 尾空格/切词/回退行残留选中) 则当全新查询, 不再卡死旧结果
    else if (InStr(command, " ") && g_CurrentCommand != "" && ShouldFreezeInput(command)) {
        g_PipeArg := ""

        if (g_UseResultFilter) {
            if (resultToFilter = "")
                resultToFilter := g_DisplayEdit.Value
            needle := SubStr(g_CurrentInput, InStr(g_CurrentInput, " ") + 1)
            DisplayResult(FilterResult(resultToFilter, needle))
        } else if (g_UseRealtimeExec) {
            RunCommand(g_CurrentCommand)
            resultToFilter := ""
        } else {
            resultToFilter := ""
        }
        return
    }
    ; @ 前缀
    else if (commandPrefix = "@") {
        g_UseResultFilter := false
        g_UseRealtimeExec := false
        resultToFilter := ""
        return
    }

    g_UseResultFilter := false
    g_UseRealtimeExec := false
    resultToFilter := ""

    if (commandPrefix != "|")
        g_PipeArg := ""

    g_CurrentCommandList := []
    order := g_FirstChar
    ; 命中先收集后渲染 (精确置顶需要稳定分区, 不能边扫边画)
    matchItems := []

    ; P1-4: 配置读出 (CfgGet 统一入口, 永不抛错)
    showExt := CfgGet("Config", "ShowFileExt", "0")
    searchFull := CfgGet("Config", "SearchFullPath", "0")
    ; 搜索 Registry (唯一真相源): 行推导收敛到 RimCommand.SearchRow, 此处只做匹配/去重/收集.
    ; 列表行统一 "command | <id>", 显示串走 row.show, 排序键走 row.rankKey.
    ; 整句零命中且含空格时退化搜命令头 ("Google koa.js" → "Google" 命中 + 参数照进 g_Arg)
    matchItems := SearchCollectMatches(command, showExt = "1", searchFull = "1")
    if (matchItems.Length = 0 && InStr(command, " ")) {
        head := ""
        try head := SI_HeadPure(command)
        catch {
        }
        if (head = "") {
            sp := InStr(command, " ")
            if (sp > 1)
                head := SubStr(command, 1, sp - 1)
        }
        if (head != "" && StrLower(head) != StrLower(command))
            matchItems := SearchCollectMatches(head, showExt = "1", searchFull = "1")
    }

    ; 精确命中置顶 (稳定分区: 精确桶在前, 桶内保持权重+注册序)
    ; 非精确桶内再按 frecency 降序, 前缀子桶优先, 同分保持注册序;
    ; 回车永远跑首行, ghost 也向首行对齐 (见 SI_FindGhost), 三者一致才不会误执行
    g_CurrentCommandList := []
    order := g_FirstChar
    for _mi, mi in matchItems {
        if (mi["exact"] && !SearchRenderItem(mi, &result, &order, firstRun))
            break
    }
    qlow := StrLower(command)
    nonExact := []
    seq := 0
    for _mi, mi in matchItems {
        if (mi["exact"])
            continue
        seq++
        tgt := ""
        try tgt := StrLower(mi["row"]["targetKey"])
        catch {
        }
        isPre := (qlow != "" && SubStr(tgt, 1, StrLen(qlow)) = qlow) ? 1 : 0
        sc := 0.0
        try sc := RankScoreOfElement(mi["row"]["rankKey"])
        catch {
        }
        nonExact.Push(Map("mi", mi, "seq", seq, "score", sc, "pre", isPre))
    }
    ordered := []
    ; P8: 稳定 top-k 替代全量插入排序 (同比较器 pre/score + 同稳定性 seq,
    ; 前缀与旧序逐项一致; 渲染至 DisplayRows 即停, 取 rows+10 冗余)
    topK := g_DisplayRows + 10
    try {
        ordered := Search_TopK(nonExact, topK)
    } catch {
        for _, it in nonExact {
            pos := ordered.Length + 1
            Loop ordered.Length {
                o := ordered[A_Index]
                if (it["pre"] > o["pre"] || (it["pre"] = o["pre"] && it["score"] > o["score"])) {
                    pos := A_Index
                    break
                }
            }
            ordered.InsertAt(pos, it)
        }
    }
    for _, it in ordered {
        if (!SearchRenderItem(it["mi"], &result, &order, firstRun))
            break
    }
    ; 无结果 → 先试计算器, 再回退命令
    if (result = "") {
        tryEval := TryEvalInput(command != "" ? command : g_CurrentInput)
        if (tryEval != "") {
            DisplayResult(tryEval)
            return tryEval
        }
        g_UseFallbackCommands := true
        g_CurrentCommandList := []
        for index, element in g_FallbackCommands {
            shown := ""
            try shown := RimCommand.ShowOf(element)
            catch {
                shown := element
            }
            if (index = 1) {
                g_CurrentCommand := element
                result .= Chr(g_FirstChar - 1 + index++) . ">| " . shown
            } else {
                result .= "`n"
                result .= Chr(g_FirstChar - 1 + index++) . " | " . shown
            }
            g_CurrentCommandList.Push(element)
        }
    } else {
        g_UseFallbackCommands := false
    }

    ; HideCol2 处理
    if (g_SkinConf["HideCol2"] = "1") {
        result := StrReplace(result, "file | ")
        result := StrReplace(result, "function | ")
        result := StrReplace(result, "cmd | ")
        result := StrReplace(result, "command | ")
        result := StrReplace(result, "url | ")
        result := StrReplace(result, "run | ")
    } else {
        result := StrReplace(result, "file | ", TypeLabel("file"))
        result := StrReplace(result, "function | ", TypeLabel("function"))
        result := StrReplace(result, "cmd | ", TypeLabel("cmd"))
        result := StrReplace(result, "command | ", TypeLabel("command"))
        result := StrReplace(result, "url | ", TypeLabel("url"))
        result := StrReplace(result, "run | ", TypeLabel("run"))
    }

    DisplaySearchResult(result)
    return result
}

; 冻结判定: 空格前是当前选中命令本身才冻结输参 (比名不比 id: 别名行按注册名冻结).
; 当前命令可能是历史包装行 (DisplayHistoryCommands 原样入列), 先剥参数栏.
ShouldFreezeInput(command) {
    global g_CurrentCommand
    if (g_CurrentCommand = "")
        return false
    headCore := ""
    try headCore := StrLower(SI_HeadPure(command))
    catch {
        return true
    }
    if (headCore = "")
        return true
    cur := g_CurrentCommand
    try {
        if (IsSet(HistSplit))
            cur := HistSplit(g_CurrentCommand)["el"]
    } catch {
    }
    try {
        core := SI_CoreOfPure(cur)
        if (IsSet(SI_NameOf)) {
            try core := SI_NameOf(core)
            catch {
            }
        }
        if (StrLower(core) = headCore)
            return true
    } catch {
    }
    try {
        pp := CmdLine_Parse(cur)
        if (pp["isFour"]) {
            if (StrLower(pp["key"]) = headCore)
                return true
        } else if (pp["len"] >= 2) {
            if (StrLower(pp["cmd"]) = headCore)
                return true
        }
    } catch {
    }
    return false
}

; 命令匹配
MatchCommand(Haystack, Needle) {
    global g_EnableTCMatch
    if (g_EnableTCMatch)
        return TCMatchFunc(Haystack, Needle)
    else
        return InStr(Haystack, Needle)
}

; 结果匹配
MatchResult(Haystack, Needle) {
    global g_EnableTCMatch
    if (g_EnableTCMatch)
        return TCMatchFunc(Haystack, Needle)
    else
        return InStr(Haystack, Needle)
}

; 过滤结果
FilterResult(text, needle) {
    result := ""
    Loop Parse, text, "`n", "`r" {
        if (!InStr(A_LoopField, " | ") && MatchResult(A_LoopField, needle))
            result .= A_LoopField "`n"
        else if (MatchResult(StrReplace(SubStr(A_LoopField, 5), "\", " "), needle))
            result .= A_LoopField "`n"
    }
    return result
}

; 开启结果过滤模式
TurnOnResultFilter() {
    global g_UseResultFilter, g_CurrentInput, g_InputEdit
    if (!g_UseResultFilter) {
        g_UseResultFilter := true
        if (!InStr(g_CurrentInput, " ")) {
            g_InputEdit.Focus()
            Send("{space}")
        }
    }
}

; 开启实时执行模式
TurnOnRealtimeExec() {
    global g_UseRealtimeExec, g_CurrentInput, g_InputEdit
    if (!g_UseRealtimeExec) {
        g_UseRealtimeExec := true
        if (!InStr(g_CurrentInput, " ")) {
            g_InputEdit.Focus()
            Send("{space}")
        }
    }
}

; 设置间隔执行 (对齐原版; 开关皆用闭包对象, 本构建 SetTimer/Func 皆忌字符串名)
SetExecInterval(second) {
    global g_ExecInterval, g_LastExecCb
    if (g_ExecInterval >= 0) {
        g_ExecInterval := second * 1000
        return true
    } else {
        if (IsObject(g_LastExecCb)) {
            try SetTimer(g_LastExecCb, 0)
        }
        return false
    }
}

; 设置命令过滤器
SetCommandFilter(command) {
    global g_CommandFilter
    g_CommandFilter := command
}

; 无结果时试算表达式 (原版 Eval 语义: 数字非0才显示)
; 仅纯数学表达式才计算, 避免 "calc123+123" 等误触 (原版未知标识符直接失败)
TryEvalInput(input) {
    global g_Conf
    if (input = "")
        return ""
    ; 必须包含数字
    if (!RegExMatch(input, "\d"))
        return ""
    ; 去掉已知函数名/常量/空格后, 必须只剩数字运算符
    tmp := StrLower(input)
    for word in ["asin", "acos", "atan", "ceil", "floor", "round", "sqrt", "choose", "perm", "comb", "gallon", "ounce", "pint", "inch", "foot", "mile", "sin", "cos", "tan", "exp", "log", "ln", "abs", "sgn", "fib", "fac", "gcd", "min", "max", "lb", "oz", "pi", "e", "a", "p", "c"] {
        tmp := StrReplace(tmp, word, "")
    }
    tmp := StrReplace(tmp, " ", "")
    if (!RegExMatch(tmp, "^[\d\+\-\*\/\%\^\(\)\.,!]+$"))
        return ""
    ; 本构建无 IsFunc: 以插件开关代 existence 检查 (Misc 缺席则无计算器)
    if (CfgGet("Plugins", "Misc", "1") = "0")
        return ""
    try {
        val := EvalExpression(input)
        if (val = "" || InStr(val, "错误")) ; i18n:protocol (MonsterEval 错误哨兵, 引擎零 T() 依赖)
            return ""
        if (val + 0 = 0)
            return ""
        return input " = " val
    } catch {
        return ""
    }
}

; 单行渲染 (SearchCommand 精确分区后调用; 返回 false 表示达到截断可停)
; 稳定 top-k: 同比较器 pre/score + 同稳定性 seq (渲染至 DisplayRows 即停, 取 rows+10 冗余)
Search_TopK(scored, k := 50) {
    if (k < 1)
        return []
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

SearchRenderItem(mi, &result, &order, firstRun) {
    global g_CurrentCommandList, g_CurrentCommand, g_FirstChar, g_DisplayRows
    g_CurrentCommandList.Push(mi["idline"])
    if (order = g_FirstChar) {
        g_CurrentCommand := mi["idline"]
        result .= Chr(order++) . ">| " . mi["show"]
    } else {
        result .= "`n" . Chr(order++) . " | " . mi["show"]
    }
    if (order - g_FirstChar >= g_DisplayRows)
        return false
    if (firstRun && (order - g_FirstChar >= g_DisplayRows - 4)) {
        total := 0
        try total := RimCommand.Registry.Count
        catch {
        }
        result .= "`n`n" . T("search.footer_total", total)
        result .= "`n`n" . T("search.footer_hint")
        return false
    }
    return true
}
