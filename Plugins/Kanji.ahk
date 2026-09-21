#Requires AutoHotkey v2.0

; === Kanji Plugin - 简繁体转换 ===
; 移植自 RunZ 的 Kanji 插件 (查 Lib\Kanji\Kanji.txt 字表, 非桩)

RegisterPlugin_Kanji() {
    RegisterCommand("Kanji2S", "function", "KanjiToSimple", "繁体转简体")
    RegisterCommand("Kanji2T", "function", "KanjiToTraditional", "简体转繁体")
    ; 原版别名
    RegisterCommand("T2S", "function", "KanjiToSimple", "繁体转简体")
    RegisterCommand("S2T", "function", "KanjiToTraditional", "简体转繁体")
}

KanjiPipeInput(prompt, title) {
    global Arg
    if (Trim(Arg) != "")
        return Trim(Arg)
    clip := A_Clipboard
    if (clip != "")
        return clip
    return InputBox(prompt, title).Value
}

; 原版语义: 转换后写回剪切板 + DisplayResult
KanjiToSimple() {
    text := KanjiPipeInput("输入繁体文本:", "繁转简")
    if (text = "")
        return
    result := Kanji_Convert(text, false)
    A_Clipboard := result
    DisplayResult(result)
}

KanjiToTraditional() {
    text := KanjiPipeInput("输入简体文本:", "简转繁")
    if (text = "")
        return
    result := Kanji_Convert(text, true)
    A_Clipboard := result
    DisplayResult(result)
}

; s2t=true 简→繁, false 繁→简 (对齐原版 Kanji(s,r))
Kanji_Convert(s, s2t := false) {
    static s2tMap := Map(), t2sMap := Map(), loaded := false
    if (!loaded) {
        loaded := true
        try {
            raw := FileRead(A_ScriptDir "\Lib\Kanji\Kanji.txt", "UTF-8")
            for field in StrSplit(Trim(raw), " ") {
                field := Trim(field)
                if (StrLen(field) < 2)
                    continue
                a := SubStr(field, 1, 1)
                b := SubStr(field, 2)
                s2tMap[a] := b
                t2sMap[b] := a
            }
        }
    }
    n := s2t ? s2tMap : t2sMap
    out := ""
    Loop Parse, s {
        out .= n.Has(A_LoopField) ? n[A_LoopField] : A_LoopField
    }
    return out
}
