#Requires AutoHotkey v2.0

; === Kanji Plugin - 简繁体转换 ===
; 移植自 RunZ 的 Kanji 插件 (查 Lib\Kanji\Kanji.txt 字表, 非桩)
; Hybrid: Modern 壳 (命令通道) + 旧 RegisterPlugin_Kanji() 体

class KanjiPlugin extends RimPlugin {
    static Name => "Kanji"
    static Title => "Kanji Converter"
    static Description => "简繁体转换"

    static RegisterCommands() {
        RegisterPlugin_Kanji()
    }
}

if (IsSet(RimPluginManager) && IsObject(RimPluginManager))
    RimPluginManager.Register(KanjiPlugin)

RegisterPlugin_Kanji() {
    RegisterCommand("Kanji2S", "function", "KanjiToSimple", T("cmd.Kanji.Kanji2S"))
    RegisterCommand("Kanji2T", "function", "KanjiToTraditional", T("cmd.Kanji.Kanji2T"))
    ; 原版别名
    RegisterCommand("T2S", "function", "KanjiToSimple", T("cmd.Kanji.Kanji2S"))
    RegisterCommand("S2T", "function", "KanjiToTraditional", T("cmd.Kanji.Kanji2T"))
}

KanjiPipeInput(prompt, title) {
    global g_Arg
    if (Trim(g_Arg) != "")
        return Trim(g_Arg)
    clip := A_Clipboard
    if (clip != "")
        return clip
    return InputBox(prompt, title).Value
}

; 原版语义: 转换后写回剪切板 + DisplayResult
KanjiToSimple() {
    text := KanjiPipeInput(T("kanji.prompt_trad"), T("kanji.title_trad"))
    if (text = "")
        return
    result := Kanji_Convert(text, false)
    A_Clipboard := result
    DisplayResult(result)
}

KanjiToTraditional() {
    text := KanjiPipeInput(T("kanji.prompt_simp"), T("kanji.title_simp"))
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
