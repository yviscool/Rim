#Requires AutoHotkey v2.0

; === TCMatch 库 ===
; 兼容 RunZ 的 TCMatch 模糊匹配功能

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

    ; 匹配函数
    static Match(pattern, text) {
        if (pattern = "")
            return true
        if (text = "")
            return false

        pattern := StrLower(pattern)
        text := StrLower(text)

        ; DLL 匹配
        if (this.enabled && this.hModule) {
            try {
                result := DllCall("tcmatch\Match", "Str", text, "Str", pattern, "Int")
                return result = 1
            }
        }

        ; 内置匹配
        return this.BuiltInMatch(pattern, text)
    }

    ; 内置匹配算法
    static BuiltInMatch(pattern, text) {
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

; RunZ 兼容的 TCMatchOn 函数
TCMatchOn(dllPath := "") {
    TCMatch.Init(dllPath)
    return TCMatch.enabled
}

; RunZ 兼容的 TCMatch 函数
TCMatchFunc(Haystack, Needle) {
    return TCMatch.Match(Needle, Haystack)
}
