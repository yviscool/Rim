#Requires AutoHotkey v2.0
#Warn All, Off

; === I18n - 国际化内核 (key-based, 2026 主流实践的 AHK 落地) ===
; 设计:
;   - 语言包: Lang/<bcp47>.ini, [Strings] 段, key=value, UTF-8
;   - 第一语言: zh-CN, en (全量); 其余 (ja/de/fr/es/...) 占位, 缺键自动回落英文
;   - T(key, args*) 查当前语言 → 回落英文 → 回落 key 本身 (永不抛错, 永不报空)
;   - 占位符: {1} {2} ... (ICU-lite, 跨语言可调序; audit 脚本校验各语言占位一致)
;   - 语言决议: [Config] Language = auto/zh-CN/en/... ; auto 跟 A_Language, 未知回落 zh-CN
; 注意:
;   - g_WindowName ("RunZ    ") 是窗口匹配哨兵, 禁止翻译, 禁止进语言包
;   - 本文件零依赖 (不走 EasyIni/Common), 保证启动最早阶段可用 (I18nBoot)

global g_I18nLang := "zh-CN"
global g_I18nStrings := Map()
global g_I18nFallback := Map()

; ---- 启动最早阶段调用 (g_Conf 尚未加载, 只按 OS 语言) ----
I18nBoot() {
    global g_I18nLang, g_I18nStrings, g_I18nFallback
    g_I18nFallback := I18nLoadLangFile("en")
    osLang := I18nOsLang()
    g_I18nLang := osLang
    if (osLang = "en")
        g_I18nStrings := g_I18nFallback
    else
        g_I18nStrings := I18nLoadLangFile(osLang)
    if (g_I18nStrings.Count = 0)
        g_I18nStrings := I18nLoadLangFile("zh-CN")
    if (g_I18nStrings.Count > 0)
        g_I18nLang := I18nLoadedLang()
}

; ---- g_Conf 加载后调用 (尊重 [Config] Language) ----
I18nInit() {
    global g_I18nLang, g_I18nStrings, g_I18nFallback, g_Conf
    if (g_I18nFallback.Count = 0)
        g_I18nFallback := I18nLoadLangFile("en")
    want := ""
    try want := Trim(g_Conf.Get("Config", "Language", "auto"))
    if (want = "")
        want := "auto"
    if (want = "auto")
        want := I18nOsLang()
    I18nSetLang(want, false)
}

; ---- 切换语言 (save=true 时写回 rim.ini, 返回实际生效的语言) ----
I18nSetLang(lang, save := true) {
    global g_I18nLang, g_I18nStrings, g_I18nFallback, g_Conf
    lang := Trim(lang)
    if (lang = "" || lang = "auto")
        lang := I18nOsLang()
    m := I18nLoadLangFile(lang)
    if (m.Count = 0 && lang != "en")
        m := I18nLoadLangFile("en")
    if (m.Count = 0 && lang != "zh-CN")
        m := I18nLoadLangFile("zh-CN")
    if (m.Count = 0)
        return g_I18nLang
    g_I18nStrings := m
    g_I18nLang := I18nLoadedLang(lang)
    if (save) {
        try g_Conf.Set("Config", "Language", g_I18nLang)
    }
    return g_I18nLang
}

I18nLoadedLang(fallback := "") {
    global g_I18nLastLoaded
    try {
        if (g_I18nLastLoaded != "")
            return g_I18nLastLoaded
    } catch {
    }
    return fallback != "" ? fallback : "zh-CN"
}

; ---- 当前生效语言 ----
I18nGetLang() {
    global g_I18nLang
    return g_I18nLang
}

; ---- 可用语言列表 (按 Lang/*.ini 扫描, 排序: zh-CN, en 优先) ----
I18nAvailable() {
    langs := []
    try {
        Loop Files, A_ScriptDir "\Lang\*.ini" {
            SplitPath(A_LoopFileName, , , , &stem)
            if (stem != "")
                langs.Push(stem)
        }
    }
    ordered := []
    for want in ["zh-CN", "en"] {
        for l in langs {
            if (l = want) {
                ordered.Push(l)
                break
            }
        }
    }
    for l in langs {
        dup := false
        for o in ordered {
            if (o = l) {
                dup := true
                break
            }
        }
        if (!dup)
            ordered.Push(l)
    }
    return ordered
}

; ---- 下拉框显示名: "中文 (zh-CN)" ----
I18nDisplayName(lang) {
    names := Map("zh-CN", "中文", "en", "English", "ja", "日本語", "de", "Deutsch"
        , "fr", "Français", "es", "Español", "ko", "한국어", "ru", "Русский")
    if (names.Has(lang))
        return names[lang] . " (" . lang . ")"
    return lang
}

; ---- OS 语言 → bcp47 (中文系 → zh-CN, 其余有包用包, 无包回落 en) ----
I18nOsLang() {
    code := ""
    try code := A_Language
    code := Trim(code)
    if (code = "")
        return "zh-CN"
    lc := StrLower(code)
    ; 中文系 LCID/名称全收敛到 zh-CN (0804 简中 / 0c04 繁中香港 / 1404 繁中澳门 / 1004 新加坡等)
    if (lc = "0804" || lc = "1004" || lc = "0c04" || lc = "1404" || lc = "7c04" || lc = "0404"
        || SubStr(lc, 1, 2) = "zh" || InStr(lc, "chinese"))
        return "zh-CN"
    if (lc = "0409" || lc = "0809" || SubStr(lc, 1, 2) = "en")
        return "en"
    ; 有语言包就用 (ja/de/fr/...), 否则回落 en (占位包缺键时 T() 再逐键回落英文)
    candidates := [code, lc, SubStr(lc, 1, 2)]
    for c in candidates {
        if (c != "" && FileExist(A_ScriptDir . "\Lang\" . c . ".ini"))
            return c
    }
    return "en"
}

; ---- 读一个语言包为 Map (key → value; 失败返回空 Map, 永不抛错) ----
I18nLoadLangFile(lang) {
    global g_I18nLastLoaded
    m := Map()
    path := A_ScriptDir . "\Lang\" . lang . ".ini"
    if (!FileExist(path))
        return m
    content := ""
    try content := FileRead(path, "UTF-8")
    catch {
        return m
    }
    if (SubStr(content, 1, 1) = Chr(0xFEFF))
        content := SubStr(content, 2)
    inStrings := false
    seenAny := false
    Loop Parse, content, "`n", "`r" {
        line := Trim(A_LoopField)
        if (line = "")
            continue
        if (SubStr(line, 1, 1) = ";" || SubStr(line, 1, 1) = "#")
            continue
        if (SubStr(line, 1, 1) = "[" && SubStr(line, -1) = "]") {
            sec := Trim(SubStr(line, 2, StrLen(line) - 2))
            inStrings := (sec = "Strings")
            continue
        }
        if (!inStrings)
            continue
        if RegExMatch(line, "^([^=]+)=(.*)$", &_m) {
            k := Trim(_m[1])
            v := Trim(_m[2])
            ; 转义: \n 换行, \t 制表, \\ 反斜杠 (翻译文件书写惯例, 与代码 "`n 区分)
            v := StrReplace(v, "\\", Chr(1))
            v := StrReplace(v, "\n", "`n")
            v := StrReplace(v, "\t", "`t")
            v := StrReplace(v, Chr(1), "\")
            if (k != "") {
                m[k] := v
                seenAny := true
            }
        }
    }
    if (seenAny)
        g_I18nLastLoaded := lang
    return m
}

; ---- 翻译主入口: T("tray.show") / T("msg.hello_user", name) ----
T(key, args*) {
    global g_I18nStrings, g_I18nFallback
    s := ""
    try {
        if (g_I18nStrings.Has(key))
            s := g_I18nStrings[key]
        else if (g_I18nFallback.Has(key))
            s := g_I18nFallback[key]
    }
    if (s = "")
        s := key
    for i, a in args {
        ph := "{" . i . "}"
        s := StrReplace(s, ph, String(a))
    }
    return s
}
