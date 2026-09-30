#Requires AutoHotkey v2.0

; === TCMatch 库 ===
; TCMatch 模糊匹配 (字符子序列匹配)

class TCMatch {
    static dllPath := ""
    static hModule := 0
    static enabled := false

    ; 初始化 TCMatch
    static Init(dllPath := "") {
        if (dllPath = "") {
            ; 从配置中读取 TCMatch 路径
            try {
                dllPath := g_Conf["Config"]["TCMatchPath"]
            }
        }

        this.dllPath := dllPath

        if (dllPath != "" && FileExist(dllPath)) {
            try {
                this.hModule := DllCall("LoadLibrary", "Str", dllPath, "Ptr")
                if (this.hModule)
                    this.enabled := true
            }
        }
    }

    ; 匹配函数 (主路: 内置; DLL 原生在 MatchDLL, 休眠保留)
    ; 实测 500x10: DLL 5437ms vs 内置 78ms, 结果逐条一致 —— 每击键全池扫描走 DLL 纯亏
    static Match(pattern, text) {
        if (pattern = "")
            return true
        if (text = "")
            return false

        return this.BuiltInMatch(StrLower(pattern), StrLower(text))
    }

    ; DLL 原生匹配 (休眠保留, 不删除: 需 hModule 已加载; 与内置逐条一致已探针验证)
    static MatchDLL(pattern, text) {
        if (pattern = "")
            return true
        if (text = "")
            return false

        pattern := StrLower(pattern)
        text := StrLower(text)

        if (this.enabled && this.hModule) {
            try {
                result := DllCall("tcmatch\Match", "Str", text, "Str", pattern, "Int")
                return result = 1
            }
        }

        return this.BuiltInMatch(pattern, text)
    }

    ; 内置匹配算法 (空 pattern/空文本守卫: v2 InStr 空 needle 直接抛错)
    static BuiltInMatch(pattern, text) {
        if (pattern = "")
            return true
        if (text = "")
            return false
        if InStr(text, pattern)
            return true

        pi := 1
        ti := 1
        while (pi <= StrLen(pattern) && ti <= StrLen(text)) {
            if (SubStr(pattern, pi, 1) = SubStr(text, ti, 1))
                pi++
            ti++
        }
        return (pi > StrLen(pattern))
    }
}

TCMatchInit(dllPath := "") {
    TCMatch.Init(dllPath)
    return TCMatch.enabled
}

; 模糊匹配入口 (内置引擎; 开关见 TCMatchPath 空/非空)
TCMatchTest(Haystack, Needle) {
    return TCMatch.Match(Needle, Haystack)
}
