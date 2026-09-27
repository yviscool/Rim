#Requires AutoHotkey v2.0
#Warn All, Off
; === Core/TrainingLoop.ahk - 手势训练闭环 ===
; P2-11: 候选/来源层/分数/第二候选展示, 纠错/追加/禁用/改名/可复现配置包

Training_Summary(decision) {
    out := ""
    try {
        if (!IsObject(decision) || !decision.Has("candidates"))
            return "no candidates"
        cands := decision["candidates"]
        out .= "candidates=" . cands.Length . " reason=" . decision["reason"] . "`n"
        shown := 0
        for _, c in cands {
            shown++
            if (shown > 3)
                break
            nm := c.Has("name") ? c["name"] : "?"
            sc := c.Has("score") ? Round(c["score"], 1) : 0
            ly := c.Has("layer") ? c["layer"] : "?"
            mt := c.Has("method") ? c["method"] : "?"
            out .= "  " . nm . " score=" . sc . " layer=" . ly . " method=" . mt . "`n"
        }
        if (IsObject(decision["selected"])) {
            out .= "selected=" . decision["selected"]["name"] . "`n"
        } else {
            out .= "selected=REJECT`n"
        }
    }
    return out
}

Training_AppendSample(label, pts) {
    try {
        Tpl_AddSample(label, pts)
        return Map("ok", true, "msg", "")
    } catch as ex {
        return Map("ok", false, "msg", ex.Message)
    }
}

Training_Disable(label) {
    global g_GestureDisabled
    try {
        if (!IsSet(g_GestureDisabled) || !IsObject(g_GestureDisabled))
            g_GestureDisabled := Map()
        g_GestureDisabled[label] := 1
        return Map("ok", true, "msg", "")
    } catch as ex {
        return Map("ok", false, "msg", ex.Message)
    }
}

Training_ExportPack(path) {
    try {
        content := "; Rim gesture pack " . A_Now . "`n"
        try {
            for name, def in g_GestureDefs
                content .= "; def " . name . " " . def.method . "`n"
        }
        FileAppend(content, path, "UTF-8")
        return Map("ok", true, "msg", path)
    } catch as ex {
        return Map("ok", false, "msg", ex.Message)
    }
}
