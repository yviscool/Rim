#Requires AutoHotkey v2.0
#Warn All, Off
; i18n:protocol-file (错误哨兵 "错误" 是 Search/Misc 的 InStr gate + 本引擎零 T() 依赖, 中文错误串永不翻译)
; === MonsterEval - 表达式引擎 (RunZ Lib/Eval.ahk v1 MONSTER → v2 忠实移植) ===
; 规则: 无 try / 无 IsFunc / 无 Func() / 无动态调用, 错误以 "错误..." 字符串值传递.
; 与原版差异 (有意):
;   - "^" 与 "**" 都是乘方 (原版 ^ 是异或; 启动器习惯 ^ 为乘方)
;   - 后缀 "!" = 阶乘 (3!, (1+2)!); 前缀 "!" 仍是逻辑非
;   - 新增: fac/Fac, Perm, A/P (排列, A(n) 默认 k=n), Comb, C (组合, =Choose)
;   - 不支持: ":=" 赋值/用户函数 (; 分句不拆), 位运算 | ^ & << >>
;   - 常量: e pi inch foot mile ounce pint gallon oz lb (整词匹配, 大小写不敏感)

global MONSTER_CONST := Map("e", "2.718281828459045", "pi", "3.141592653589793"
    , "inch", "2.54", "foot", "30.48", "mile", "1.609344", "ounce", "0.02841"
    , "pint", "0.5682", "gallon", "4.54609", "oz", "28.35", "lb", "453.59237")

MonsterEval(x) {
    form := ""
    w := ""
    if RegExMatch(x, "\$(b|h|x|)(\d*[eEgG]?)", &mt) {
        form := mt[1]
        w := mt[2]
    }
    x := RegExReplace(x, "\$(b|h|x|)(\d*[eEgG]?)", "", &monDummy, 1)
    Loop {
        if RegExMatch(x, "i)(.*)(0x[a-f\d]*)(.*)", &mt)
            x := mt[1] . Number(mt[2]) . mt[3]
        else
            break
    }
    Loop {
        if RegExMatch(x, "(.*)'([01]*)(.*)", &mt)
            x := mt[1] . FromBin(mt[2]) . mt[3]
        else
            break
    }
    x := RegExReplace(x, "(^|[^.\d])(\d+)(e|E)", "$1$2.$3")
    x := RegExReplace(x, "(\d*\.\d*|\d)([eE][+-]?\d+)", "‘$1$2’")
    x := StrReplace(x, "%", "\")
    x := StrReplace(x, "**", "@")
    x := StrReplace(x, "^", "@")
    x := StrReplace(x, "+", "±")
    x := RegExReplace(x, "(‘[^’]*)±", "$1+")
    x := StrReplace(x, "-", "¬")
    x := RegExReplace(x, "(‘[^’]*)¬", "$1-")
    y := MonsterEval1(x)
    if (!IsNumber(y))
        return y
    if (form = "b") {
        if (w != "")
            return ToBinW(Round(y), Integer(w))
        return ToBin(Round(y))
    }
    if (form = "h" || form = "x")
        return Format("{:X}", Round(y))
    prec := "6"
    typ := "G"
    if (w != "") {
        if RegExMatch(w, "^(\d*)([eEgG])$", &wmt) {
            if (wmt[1] != "")
                prec := wmt[1]
            if (wmt[2] = "e" || wmt[2] = "E")
                typ := "E"
        } else if RegExMatch(w, "^\d+$") {
            prec := w
            typ := "f"
        }
    }
    try {
        return Format("{:." . prec . typ . "}", y + 0.0)
    } catch {
        return String(y)
    }
}

MonsterEval1(x) {
    keys := ["gallon", "ounce", "pint", "inch", "foot", "mile", "lb", "oz", "pi", "e"]
    for k in keys {
        if (MONSTER_CONST.Has(k))
            x := RegExReplace(x, "(?i)(?<![\w.])" . k . "(?![\w(])", MONSTER_CONST[k])
    }
    x := RegExReplace(x, "([\)’.\w]\s+|[\)’])([a-z_A-Z]+)", "$1«$2»")
    x := RegExReplace(x, "\s+")
    x := RegExReplace(x, "([a-z_A-Z]\w*)\(", "'$1'(")
    ; 科学计数 '' 标记退役 + "1.e3" 归一 "1e3" (v2 Number 原生支持)
    x := StrReplace(x, "‘", "")
    x := StrReplace(x, "’", "")
    x := RegExReplace(x, "(\d)\.([eE])", "$1$2")
    prev := Chr(0)
    Loop {
        if (x = prev)
            break
        prev := x
        ; 最内层括号: 函数实参 ('f'(...)) 与普通分组统一归约
        if RegExMatch(x, "(.*)\(([^\(\)]*)\)(.*)", &mt) {
            if RegExMatch(mt[1], "^(.*)'([\w]+)'$", &mf) {
                v := MonsterEvalCall(mf[2], mt[2])
                if (!IsNumber(v))
                    return v
                rest := mt[3]
                if (SubStr(rest, 1, 1) = "!") {
                    nb := 0
                    while (SubStr(rest, nb + 1, 1) = "!")
                        nb++
                    if (nb > 0) {
                        Loop nb {
                            v := fac(v)
                            if (!IsNumber(v))
                                break
                        }
                    }
                    if (!IsNumber(v))
                        return v
                    rest := SubStr(rest, nb + 1)
                }
                x := mf[1] . v . rest
                continue
            }
            r := MonsterEvalOp(ReduceBang(mt[2]))
            if (!IsNumber(r))
                return r
            x := mt[1] . r . mt[3]
            continue
        }
        ; 数字阶乘 N! (后缀保留)
        newx := ReduceBang(x)
        if (newx != x) {
            x := newx
            continue
        }
    }
    if InStr(x, "错误")
        return x
    return MonsterEvalOp(x)
}

; 阶乘归约: N! / N!! (N 纯数字, 前导须为起点或运算符; 返回新串, 无匹配原样返回)
; 注意: 调用点在 MonsterEval1 (±/¬ 替换之后), 前导集合必须含替换后的 ±¬ (只写 +- 会漏 "+N!/-N!", 见 5!+A(3,3)*4+5+4! 解析失败)
ReduceBang(x) {
    if RegExMatch(x, "(.*?)(\d+(?:\.\d+)?)(!+)(.*)", &mt) {
        tail1 := mt[1]
        if (tail1 = "" || RegExMatch(SubStr(tail1, -1), "[+\-*/%\\^@(,±¬]")) {
            v := Number(mt[2])
            bangs := mt[3]
            Loop Parse, bangs {
                v := fac(v)
                if (!IsNumber(v))
                    break
            }
            if (!IsNumber(v))
                return v
            return tail1 . v . mt[4]
        }
    }
    return x
}

MonsterEvalCall(name, argsStr) {
    args := SplitTopArgs(argsStr)
    n := StrLower(name)
    if (n = "sin" || n = "cos" || n = "tan" || n = "asin" || n = "acos" || n = "atan" || n = "exp" || n = "log" || n = "ln" || n = "sqrt" || n = "abs" || n = "ceil" || n = "floor" || n = "round") {
        if (args.Length != 1)
            return "错误: 参数个数"
        a := EvNum(args[1])
        if (!IsNumber(a))
            return a
        if (n = "sin")
            return Sin(a)
        if (n = "cos")
            return Cos(a)
        if (n = "tan")
            return Tan(a)
        if (n = "asin")
            return ASin(a)
        if (n = "acos")
            return ACos(a)
        if (n = "atan")
            return ATan(a)
        if (n = "exp")
            return Exp(a)
        if (n = "log")
            return Log(a)
        if (n = "ln")
            return Ln(a)
        if (n = "sqrt")
            return Sqrt(a)
        if (n = "abs")
            return Abs(a)
        if (n = "ceil")
            return Ceil(a)
        if (n = "floor")
            return Floor(a)
        if (n = "round")
            return Round(a)
    }
    if (n = "sgn" || n = "fib" || n = "fac") {
        if (args.Length != 1)
            return "错误: 参数个数"
        a := EvNum(args[1])
        if (!IsNumber(a))
            return a
        if (n = "sgn")
            return Sgn(a)
        if (n = "fib")
            return Fib(Integer(a))
        return fac(a)
    }
    if (n = "min" || n = "max" || n = "gcd" || n = "choose" || n = "perm" || n = "comb" || n = "c") {
        if (args.Length != 2)
            return "错误: 参数个数"
        a := EvNum(args[1])
        if (!IsNumber(a))
            return a
        b := EvNum(args[2])
        if (!IsNumber(b))
            return b
        if (n = "min")
            return MIN(a, b)
        if (n = "max")
            return MAX(a, b)
        if (n = "gcd")
            return GCD(a, b)
        if (n = "choose" || n = "comb" || n = "c")
            return Choose(a, b)
        return Perm(a, b)
    }
    if (n = "a" || n = "p") {
        if (args.Length < 1 || args.Length > 2)
            return "错误: 参数个数"
        a := EvNum(args[1])
        if (!IsNumber(a))
            return a
        if (args.Length = 1)
            return Perm(a, a)
        b := EvNum(args[2])
        if (!IsNumber(b))
            return b
        return Perm(a, b)
    }
    return "错误: 未知函数 " . name
}

EvNum(s) {
    r := MonsterEvalOp(ReduceBang(s))
    if (!IsNumber(r))
        return r
    return r + 0
}

SplitTopArgs(s) {
    parts := []
    depth := 0
    cur := ""
    Loop Parse, s {
        ch := A_LoopField
        if (ch = "(")
            depth++
        else if (ch = ")")
            depth--
        if (ch = "," && depth = 0) {
            parts.Push(Trim(cur))
            cur := ""
        } else {
            cur .= ch
        }
    }
    parts.Push(Trim(cur))
    return parts
}

MonsterEvalOp(x) {
    if IsNumber(x)
        return x
    ; 开头符号串归一 (防 --5/---2 之类在正负分支原样重组永递归; 原版此处栈溢出)
    while (SubStr(x, 1, 2) = "~~")
        x := SubStr(x, 3)
    if RegExMatch(x, "^([¬±+\-]{2,})(.*)$", &smt) {
        neg := false
        Loop Parse, smt[1] {
            if (A_LoopField = "¬" || A_LoopField = "-")
                neg := !neg
        }
        x := (neg ? "¬" : "") . smt[2]
        if IsNumber(x)
            return x
    }
    if RegExMatch(x, "(.*)(\?|:)(.*)", &mt) {
        if (mt[2] = "?") {
            c := MonsterEvalOp(mt[1])
            if (!IsNumber(c))
                return c
            if (c)
                return MonsterEvalOp(mt[3])
            return ""
        } else {
            c := MonsterEvalOp(mt[1])
            if (!IsNumber(c)) {
                if (c = "")
                    return MonsterEvalOp(mt[3])
                return c
            }
            return c
        }
    }
    if RegExMatch(x, "(.*)\|\|(.*)", &mt) {
        a := MonsterEvalOp(mt[1])
        if (!IsNumber(a))
            return a
        if (a)
            return a
        return MonsterEvalOp(mt[2])
    }
    if RegExMatch(x, "(.*)&&(.*)", &mt) {
        a := MonsterEvalOp(mt[1])
        if (!IsNumber(a))
            return a
        if (!a)
            return a
        return MonsterEvalOp(mt[2])
    }
    if RegExMatch(x, "(.*)(?<![\<\>])(\<\>|=)(.*)", &mt) {
        a := MonsterEvalOp(mt[1])
        if (!IsNumber(a))
            return a
        b := MonsterEvalOp(mt[3])
        if (!IsNumber(b))
            return b
        if (mt[2] = "=")
            return (a = b) ? 1 : 0
        return (a != b) ? 1 : 0
    }
    if RegExMatch(x, "(.*)(?<![\<\>])(\<=?|\>=?)(?![\<\>])(.*)", &mt) {
        a := MonsterEvalOp(mt[1])
        if (!IsNumber(a))
            return a
        b := MonsterEvalOp(mt[3])
        if (!IsNumber(b))
            return b
        if (mt[2] = "<")
            return (a < b) ? 1 : 0
        if (mt[2] = ">")
            return (a > b) ? 1 : 0
        if (mt[2] = "<=")
            return (a <= b) ? 1 : 0
        return (a >= b) ? 1 : 0
    }
    if RegExMatch(x, "i)(.*)«(.*?)»(.*)", &mt) {
        op := StrLower(mt[2])
        if (op = "gcd" || op = "min" || op = "max" || op = "choose") {
            a := MonsterEvalOp(mt[1])
            if (!IsNumber(a))
                return a
            b := MonsterEvalOp(mt[3])
            if (!IsNumber(b))
                return b
            if (op = "gcd")
                return GCD(a, b)
            if (op = "min")
                return MIN(a, b)
            if (op = "max")
                return MAX(a, b)
            return Choose(a, b)
        }
    }
    if RegExMatch(x, "(.*[^!\~±¬\@\*/\\])(±|¬)(.*)", &mt) {
        a := MonsterEvalOp(mt[1])
        if (!IsNumber(a))
            return a
        b := MonsterEvalOp(mt[3])
        if (!IsNumber(b))
            return b
        if (mt[2] = "±")
            return a + b
        return a - b
    }
    if RegExMatch(x, "(.*)(\*|/|\\)(.*)", &mt) {
        a := MonsterEvalOp(mt[1])
        if (!IsNumber(a))
            return a
        b := MonsterEvalOp(mt[3])
        if (!IsNumber(b))
            return b
        if (mt[2] = "*")
            return a * b
        if (b = 0)
            return "错误: 除零"
        if (mt[2] = "/")
            return a / b
        return Mod(a, b)
    }
    if RegExMatch(x, "(.*)@(.*)", &mt) {
        a := MonsterEvalOp(mt[1])
        if (!IsNumber(a))
            return a
        b := MonsterEvalOp(mt[2])
        if (!IsNumber(b))
            return b
        return a ** b
    }
    if RegExMatch(x, "(.*)(!|±|¬|~|'(.*)')(.*)", &mt) {
        if (mt[2] = "!") {
            v := MonsterEvalOp(mt[4])
            if (!IsNumber(v))
                return v
            if (mt[1] = "")
                return (v = 0 ? 1 : 0)
            return MonsterEvalOp(mt[1] . (v = 0 ? 1 : 0))
        }
        if (mt[2] = "±") {
            v := MonsterEvalOp(mt[4])
            if (!IsNumber(v))
                return v
            if (mt[1] = "")
                return v
            return MonsterEvalOp(mt[1] . v)
        }
        if (mt[2] = "¬") {
            v := MonsterEvalOp(mt[4])
            if (!IsNumber(v))
                return v
            if (mt[1] = "")
                return -v
            return MonsterEvalOp(mt[1] . (-v))
        }
        if (mt[2] = "~") {
            v := MonsterEvalOp(mt[4])
            if (!IsNumber(v))
                return v
            if (mt[1] = "")
                return ~Integer(v)
            return MonsterEvalOp(mt[1] . (~Integer(v)))
        }
        parts := MonsterSplitCallArgs(mt[4])
        v := MonsterEvalCall(mt[3], parts[1])
        if (!IsNumber(v))
            return v
        return MonsterEvalOp(mt[1] . v . parts[2])
    }
    return "错误: 无法解析"
}

MonsterSplitCallArgs(y4) {
    if (SubStr(y4, 1, 1) != "(")
        return [y4, ""]
    depth := 0
    Loop Parse, y4 {
        if (A_LoopField = "(")
            depth++
        else if (A_LoopField = ")")
            depth--
        if (depth = 0) {
            inner := SubStr(y4, 2, A_Index - 2)
            rest := SubStr(y4, A_Index + 1)
            return [inner, rest]
        }
    }
    return [y4, ""]
}

ToBin(n) {
    if (n = "")
        return 0
    if (n = 0 || n = -1)
        return -n
    return ToBin(n >> 1) . (n & 1)
}

ToBinW(n, W := 8) {
    W := Integer(W)
    if (W <= 0)
        return "0"
    b := ""
    Loop W {
        b := (n & 1) . b
        n >>= 1
    }
    return b
}

FromBin(bits) {
    n := 0
    Loop Parse, bits
        n += n + A_LoopField
    return n - (SubStr(bits, 1, 1) << StrLen(bits))
}

Sgn(x) {
    return (x > 0) - (x < 0)
}

MIN(a, b) {
    if (a < b)
        return a
    return b
}

MAX(a, b) {
    if (a < b)
        return b
    return a
}

GCD(a, b) {
    if (!IsNumber(a) || !IsNumber(b))
        return "错误: 参数"
    a := Round(a)
    b := Round(b)
    if (b = 0)
        return Abs(a)
    return GCD(b, Mod(a, b))
}

Choose(n, k) {
    if (!IsNumber(n) || !IsNumber(k))
        return "错误: 参数"
    n := Round(n)
    k := Round(k)
    if (k < 0 || k > n || n < 0)
        return "错误: 组合定义域"
    if (k > n - k)
        k := n - k
    p := 1
    i := 0
    if (k > 0) {
        Loop k {
            p *= (n - i) / (k - i)
            i += 1
        }
    }
    return Round(p)
}

Fib(n) {
    if (!IsInteger(n))
        return "错误: fib 参数须为整数"
    a := 0
    b := 1
    cnt := Abs(n) - 1
    if (cnt > 0) {
        Loop cnt {
            c := b
            b += a
            a := c
        }
    }
    if (n = 0)
        return 0
    if (n > 0 || (n & 1))
        return b
    return -b
}

fac(n) {
    if (!IsNumber(n) || Mod(n, 1) != 0 || n < 0 || n > 170)
        return "错误: 阶乘定义域 (0-170 整数)"
    if (n < 2)
        return 1
    r := 1
    Loop n
        r *= A_Index
    return r
}

Perm(n, k) {
    if (!IsNumber(n) || !IsNumber(k))
        return "错误: 参数"
    n := Round(n)
    k := Round(k)
    if (k < 0 || k > n || n < 0 || n > 170)
        return "错误: 排列定义域"
    return Round(fac(n) / fac(n - k))
}

Comb(n, k) {
    return Choose(n, k)
}
