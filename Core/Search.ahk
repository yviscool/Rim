#Requires AutoHotkey v2.0
#Warn All, Off

; === Search - 搜索逻辑 (从 RunZ Core/Search.ahk 移植) ===

; 核心搜索函数
SearchCommand(command := "", firstRun := false) {
    global g_UseDisplay, g_ExecInterval, g_PipeArg, g_CurrentInput, g_CurrentCommand
    global g_CurrentCommandList, g_FallbackCommands, g_FirstChar, g_DisplayRows
    global g_ExcludedCommands, g_Commands, g_EnableTCMatch, g_SkinConf
    global g_UseResultFilter, g_UseRealtimeExec, g_InputEdit, g_DisplayEdit
    global g_WindowName, g_UseFallbackCommands, Arg, g_Conf

    g_UseDisplay := false
    g_ExecInterval := -1
    result := ""
    fullResult := ""
    static resultToFilter := ""
    commandPrefix := SubStr(command, 1, 1)

    ; 分号/冒号前缀
    if (commandPrefix = ";" || commandPrefix = ":") {
        g_UseResultFilter := false
        g_UseRealtimeExec := false
        resultToFilter := ""
        g_PipeArg := ""

        if (commandPrefix = ";")
            g_CurrentCommand := g_FallbackCommands[1]
        else
            g_CurrentCommand := g_FallbackCommands[2]

        g_CurrentCommandList := []
        g_CurrentCommandList.Push(g_CurrentCommand)
        result .= Chr(g_FirstChar) ">| "
            . StrReplace(g_CurrentCommand, "function | ", Chr(0x529F) . Chr(0x80FD) . " | ")
        DisplaySearchResult(result)
        return result
    }
    ; 管道前缀 |
    else if (commandPrefix = "|" && Arg != "") {
        if (g_PipeArg = "")
            g_PipeArg := Arg
        command := SubStr(command, 2)
        if (SubStr(command, 1, 1) = "@") {
            command := SubStr(command, 1, 4)
            return
        }
    }
    ; 空格 → 原版行为: 已有当前命令时冻结显示直接返回, 空格后文字只作参数
    ; (只有结果过滤/实时执行模式才会消费空格后的文字)
    else if (InStr(command, " ") && g_CurrentCommand != "") {
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

    ; 搜索所有命令
    for index, element in g_Commands {
        if (InStr(fullResult, element "`n") || InStr(g_ExcludedCommands, element "`n"))
            continue

        splitedElement := StrSplit(element, " | ")

        if (splitedElement[1] = "file") {
            SplitPath(splitedElement[2], &fileName, , , &fileNameNoExt)

            elementToSearch := fileNameNoExt
            extra := splitedElement.Length >= 3 ? splitedElement[3] : ""
            if (g_Conf.Get("Config", "ShowFileExt", "0") = "1")
                elementToShow := "file | " . fileName . (extra ? " | " . extra : "")
            else
                elementToShow := "file | " . fileNameNoExt . (extra ? " | " . extra : "")

            if (extra)
                elementToSearch .= " " . extra

            if (g_Conf.Get("Config", "SearchFullPath", "0") = "1") {
                SplitPath(splitedElement[2], , &fileDir)
                elementToSearch := StrReplace(fileDir, "\", " ") . " " . elementToSearch
            }
        } else if (splitedElement.Length >= 4
            && (splitedElement[2] = "file" || splitedElement[2] = "function" || splitedElement[2] = "cmd" || splitedElement[2] = "url" || splitedElement[2] = "run")) {
            ; 四段式: key | type | cmd | desc (来自 [Commands] key=type|cmd|desc)
            ; 显示压成三段式 类型 | 别名 | 描述, 与原版列布局一致 (别名进名字列, 照样可搜)
            elementToShow := splitedElement[2] " | " splitedElement[1]
            elementToSearch := splitedElement[1] " " StrReplace(StrReplace(splitedElement[3], "/", " "), "\", " ")

            extra4 := splitedElement[4]
            if (splitedElement.Length > 4) {
                Loop splitedElement.Length - 4
                    extra4 .= " | " . splitedElement[4 + A_Index]
            }
            elementToShow .= " | " extra4
            elementToSearch .= " " extra4
        } else {
            elementToShow := splitedElement[1] " | " splitedElement[2]
            elementToSearch := StrReplace(splitedElement[2], "/", " ")
            elementToSearch := StrReplace(elementToSearch, "\", " ")

            if (splitedElement.Length >= 3) {
                elementToShow .= " | " splitedElement[3]
                elementToSearch .= " " splitedElement[3]
            }
        }

        if (command = "" || MatchCommand(elementToSearch, command)) {
            fullResult .= element "`n"
            g_CurrentCommandList.Push(element)

            if (order = g_FirstChar) {
                g_CurrentCommand := element
                result .= Chr(order++) . ">| " . elementToShow
            } else {
                result .= "`n" . Chr(order++) . " | " . elementToShow
            }

            if (order - g_FirstChar >= g_DisplayRows)
                break
            if (firstRun && (order - g_FirstChar >= g_DisplayRows - 4)) {
                result .= "`n`nTotal " g_Commands.Length " entries."
                result .= "`n`nType to search, Enter to run, Alt+letter to run, F1 for help, Esc to close."
                break
            }
        }
    }

    ; 无结果 → 先试计算器 (对齐原版: IsLabel("Calc") && Eval()!=0 → DisplayResult)
    if (result = "") {
        tryEval := TryEvalInput(command != "" ? command : g_CurrentInput)
        if (tryEval != "") {
            DisplayResult(tryEval)
            return tryEval
        }
        g_UseFallbackCommands := true
        if (g_FallbackCommands.Length > 0)
            g_CurrentCommand := g_FallbackCommands[1]
        g_CurrentCommandList := g_FallbackCommands

        for index, element in g_FallbackCommands {
            if (index = 1)
                result .= Chr(g_FirstChar - 1 + index++) . ">| " element
            else {
                result .= "`n"
                result .= Chr(g_FirstChar - 1 + index++) . " | " element
            }
        }
    } else {
        g_UseFallbackCommands := false
    }

    ; HideCol2 处理
    if (g_SkinConf["HideCol2"] = "1") {
        result := StrReplace(result, "file | ")
        result := StrReplace(result, "function | ")
        result := StrReplace(result, "cmd | ")
        result := StrReplace(result, "url | ")
        result := StrReplace(result, "run | ")
    } else {
        result := StrReplace(result, "file | ", Chr(0x6587) . Chr(0x4EF6) . " | ")
        result := StrReplace(result, "function | ", Chr(0x529F) . Chr(0x80FD) . " | ")
        result := StrReplace(result, "cmd | ", Chr(0x547D) . Chr(0x4EE4) . " | ")
        result := StrReplace(result, "url | ", Chr(0x7F51) . Chr(0x5740) . " | ")
        result := StrReplace(result, "run | ", Chr(0x8FD0) . Chr(0x884C) . " | ")
    }

    DisplaySearchResult(result)
    return result
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
    if (g_Conf.Get("Plugins", "Misc", "1") = "0")
        return ""
    try {
        val := EvalExpression(input)
        if (val = "" || InStr(val, "错误"))
            return ""
        if (val + 0 = 0)
            return ""
        return input " = " val
    } catch {
        return ""
    }
}
