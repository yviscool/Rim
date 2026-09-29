#Requires AutoHotkey v2.0
#Warn All, Off

; 计算器差分探针: 无匹配回退 (TryEvalInput) vs calc 直调 (MonsterEval).
; 引擎算得出但回退吞掉的, 全部列出来 (用户报: 两条路不一样, 阶乘/排列组合不支持).
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_calc_diff.ahk
#Include ..\Lib\MonsterEval.ahk
#Include ..\Core\Search.ahk

CfgGet(sec, key, def := "") {
    return def
}

; 与 Plugins/Misc.ahk EvalExpression 同语义 (薄包装直调引擎)
EvalExpression(input) {
    try {
        if (Trim(input) = "")
            return ""
        return String(MonsterEval(input))
    } catch as e {
        return "错误: " e.Message
    }
}

global g_Fail := 0
vectors := ["5!", "fac(5)", "perm(5,2)", "P(5,3)", "A(5,3)", "C(5,2)", "comb(5,2)",
    "choose(5,2)", "5-5", "0", "2+3*4", "sqrt(16)", "(1+2)!", "2^10",
    "pi*2", "fib(10)", "gcd(12,8)", "min(3,9)", "2.5*4", "10%3", "sin(0)"]
for _, v in vectors {
    eng := ""
    try eng := String(MonsterEval(v))
    catch {
        eng := "错误: throw"
    }
    engOk := eng != "" && !InStr(eng, "错误") && IsNumber(eng)
    gate := ""
    try gate := TryEvalInput(v)
    catch as e {
        gate := "错误: throw " . e.Message
    }
    if (engOk && gate = "") {
        FileAppend("GAP: [" . v . "] engine=" . eng . " gate=空`n", "*")
        global g_Fail
        g_Fail++
    } else {
        FileAppend("ok: [" . v . "] engine=" . eng . " gate=[" . gate . "]`n", "*")
    }
}

if (g_Fail > 0) {
    FileAppend("probe-calc-diff GAP: " . g_Fail . "`n", "*")
    ExitApp(1)
}
FileAppend("probe-calc-diff-ok`n", "*")
ExitApp(0)
