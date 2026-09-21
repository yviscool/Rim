#Requires AutoHotkey v2.0
#Warn All, Off

; === GestureIni - 保注释 ini 定向读写 ===
; EasyIni.Save() 会重写全文件并吃掉所有注释, 手势管理器的增删改必须走这里:
; 按行定位 section/key, 只动目标行, 其余字节(含注释/空行/换行风格)原样保留.
; 写回编码固定 UTF-8-RAW (无 BOM, 与 rim.ini 现状一致).

; ---- 读全文 (UTF-8, 剥 BOM, 失败返回 "") ----
GestureIni_ReadText(path) {
    try {
        content := FileRead(path, "UTF-8")
    } catch {
        return ""
    }
    if (SubStr(content, 1, 1) = Chr(0xFEFF))
        content := SubStr(content, 2)
    return content
}

; ---- 探换行风格 ----
GestureIni_DetectEol(text) {
    if InStr(text, "`r`n")
        return "`r`n"
    return "`n"
}

; ---- 写全文 (UTF-8-RAW, 无 BOM) ----
GestureIni_WriteText(path, text) {
    try {
        f := FileOpen(path, "w", "UTF-8-RAW")
        f.Write(text)
        f.Close()
        return true
    } catch {
        return false
    }
}

; ---- 定位 section 头行号 (trim 后全等 "[section]"), 无返回 0 ----
GestureIni_FindSection(lines, section) {
    want := "[" . section . "]"
    for i, ln in lines {
        if (Trim(ln) = want)
            return i
    }
    return 0
}

; ---- 下一个 section 头行号 (无返回 lines.Length + 1) ----
GestureIni_NextSection(lines, from) {
    i := from + 1
    while (i <= lines.Length) {
        t := Trim(lines[i])
        if (SubStr(t, 1, 1) = "[" && SubStr(t, -1) = "]")
            return i
        i++
    }
    return lines.Length + 1
}

; ---- 在 [from, to) 内找 key 行 (默认不分大小写, 模板名需严格), 无返回 0 ----
GestureIni_FindKey(lines, from, to, key, caseSense := false) {
    i := from
    while (i < to) {
        t := Trim(lines[i])
        if (t != "" && SubStr(t, 1, 1) != ";") {
            pos := InStr(t, "=")
            if (pos > 0) {
                kk := Trim(SubStr(t, 1, pos - 1))
                hit := caseSense ? (kk = key) : (StrLower(kk) = StrLower(key))
                if (hit)
                    return i
            }
        }
        i++
    }
    return 0
}

; ---- upsert: 有则改该行, 无则插入到 section 尾, 无 section 则尾部追加 ----
GestureIni_Upsert(path, section, key, value, caseSense := false) {
    text := GestureIni_ReadText(path)
    if (text = "" && !FileExist(path))
        return false
    eol := GestureIni_DetectEol(text)
    lines := StrSplit(text, "`n", "`r")
    h := GestureIni_FindSection(lines, section)
    if (h = 0) {
        if (lines.Length > 0 && Trim(lines[lines.Length]) != "")
            lines.Push("")
        lines.Push("[" . section . "]")
        lines.Push(key . "=" . value)
    } else {
        nx := GestureIni_NextSection(lines, h)
        k := GestureIni_FindKey(lines, h + 1, nx, key, caseSense)
        if (k > 0)
            lines[k] := key . "=" . value
        else
            lines.InsertAt(nx, key . "=" . value)
    }
    out := ""
    for i, ln in lines
        out .= (i > 1 ? eol : "") . ln
    return GestureIni_WriteText(path, out)
}

; ---- 删除 key 行, 返回是否删到 ----
GestureIni_Delete(path, section, key, caseSense := false) {
    text := GestureIni_ReadText(path)
    if (text = "")
        return false
    eol := GestureIni_DetectEol(text)
    lines := StrSplit(text, "`n", "`r")
    h := GestureIni_FindSection(lines, section)
    if (h = 0)
        return false
    nx := GestureIni_NextSection(lines, h)
    k := GestureIni_FindKey(lines, h + 1, nx, key, caseSense)
    if (k = 0)
        return false
    lines.RemoveAt(k)
    out := ""
    for i, ln in lines
        out .= (i > 1 ? eol : "") . ln
    return GestureIni_WriteText(path, out) ? true : false
}

; ---- 裸行追加 (黑名单模式用): section 内无全等 trim 行才加 ----
GestureIni_AppendBare(path, section, line) {
    line := Trim(line)
    if (line = "")
        return false
    text := GestureIni_ReadText(path)
    if (text = "" && !FileExist(path))
        return false
    eol := GestureIni_DetectEol(text)
    lines := StrSplit(text, "`n", "`r")
    h := GestureIni_FindSection(lines, section)
    if (h = 0) {
        if (lines.Length > 0 && Trim(lines[lines.Length]) != "")
            lines.Push("")
        lines.Push("[" . section . "]")
        lines.Push(line)
    } else {
        nx := GestureIni_NextSection(lines, h)
        i := h + 1
        while (i < nx) {
            if (Trim(lines[i]) = line) {
                return true  ; 已存在, 视为成功
            }
            i++
        }
        lines.InsertAt(nx, line)
    }
    out := ""
    for i, ln in lines
        out .= (i > 1 ? eol : "") . ln
    return GestureIni_WriteText(path, out)
}

; ---- 裸行删除, 返回是否删到 ----
GestureIni_DeleteBare(path, section, line) {
    line := Trim(line)
    text := GestureIni_ReadText(path)
    if (text = "")
        return false
    eol := GestureIni_DetectEol(text)
    lines := StrSplit(text, "`n", "`r")
    h := GestureIni_FindSection(lines, section)
    if (h = 0)
        return false
    nx := GestureIni_NextSection(lines, h)
    i := h + 1
    while (i < nx) {
        if (Trim(lines[i]) = line) {
            lines.RemoveAt(i)
            out := ""
            for j, ln in lines
                out .= (j > 1 ? eol : "") . ln
            return GestureIni_WriteText(path, out) ? true : false
        }
        i++
    }
    return false
}

; ==================== 手势包 (导出/导入, 跨机备份分享) ====================
GesturePkg_Sections() {
    return Map("Gesture", 1, "Gestures", 1, "GestureBlacklist", 1
        , "GestureTemplates", 1, "GestureDisabled", 1)
}

GesturePkg_IsPkgSection(name) {
    global g_GestureAppPrefix
    if (name = "" || SubStr(name, 1, 1) = ";")
        return false
    try {
        if (GesturePkg_Sections().Has(name))
            return true
    }
    try {
        if (SubStr(name, 1, StrLen(g_GestureAppPrefix)) = g_GestureAppPrefix)
            return true
    }
    return false
}

; ---- 导出: 返回 true/false ----
GesturePkg_Export(path) {
    global g_Conf
    if (Trim(path) = "" || !IsObject(g_Conf))
        return false
    try {
        out := StrReplace(T("gesture.pkg_header"), "`n", "`r`n")
        for sectionName, section in g_Conf.GetSections() {
            if (!GesturePkg_IsPkgSection(sectionName))
                continue
            out .= "[" . sectionName . "]`r`n"
            for _k, _v in section {
                if (Trim(_k) = "")
                    continue
                out .= (_v != "") ? (_k . "=" . _v . "`r`n") : (_k . "`r`n")
            }
            out .= "`r`n"
        }
        f := FileOpen(path, "w", "UTF-8")
        f.Write(out)
        f.Close()
        return true
    } catch {
        return false
    }
}

; ---- 导入: overwrite=1 覆盖同名, 否则跳过. 返回 [新增, 跳过, 覆盖] ----
GesturePkg_Import(path, overwrite := false) {
    global g_Conf, g_ConfFile
    added := 0
    skipped := 0
    over := 0
    if (!FileExist(path))
        return [added, skipped, over]
    try {
        pkg := EasyIni(path)
    } catch {
        return [added, skipped, over]
    }
    try {
        for sectionName, section in pkg.GetSections() {
            if (!GesturePkg_IsPkgSection(sectionName))
                continue
            for _k, _v in section {
                _k := Trim(_k)
                if (_k = "" || SubStr(_k, 1, 1) = ";")
                    continue
                has := false
                try has := g_Conf.HasKey(sectionName, _k)
                catch {
                    has := false
                }
                if (has && !overwrite) {
                    skipped++
                    continue
                }
                if (!GestureIni_Upsert(g_ConfFile, sectionName, _k, _v)) {
                    skipped++
                    continue
                }
                try g_Conf.Set(sectionName, GestureConf_KeyExact(sectionName, _k), _v)
                catch {
                }
                if (has)
                    over++
                else
                    added++
            }
        }
    }
    Gesture_ReloadLayers()
    try Tpl_LoadAll()
    catch {
    }
    return [added, skipped, over]
}

; ==================== 存储层 (文件 + 内存 + 重载, 管理器统一走这里) ====================
; ---- 内存键精确匹配 (Map 区分大小写, ini 手写键大小写不定) ----
GestureConf_KeyExact(section, key) {
    global g_Conf
    try {
        if (g_Conf.HasSection(section)) {
            for _k in g_Conf[section] {
                if (StrLower(_k) = StrLower(key))
                    return _k
            }
        }
    }
    return key
}

GestureStore_LayerSection(layer) {
    global g_GestureAppPrefix
    if (layer = "" || layer = "全局")
        return "Gestures"
    return g_GestureAppPrefix . layer
}

GestureStore_SetGesture(layer, gesture, action) {
    global g_Conf, g_ConfFile
    gesture := Gesture_Normalize(gesture)
    action := Trim(action)
    if (gesture = "" || action = "")
        return false
    sec := GestureStore_LayerSection(layer)
    if (!GestureIni_Upsert(g_ConfFile, sec, gesture, action))
        return false
    try g_Conf.Set(sec, GestureConf_KeyExact(sec, gesture), action)
    catch {
    }
    Gesture_ReloadLayers()
    return true
}

GestureStore_DelGesture(layer, gesture) {
    global g_Conf, g_ConfFile
    gesture := Gesture_Normalize(gesture)
    sec := GestureStore_LayerSection(layer)
    if (!GestureIni_Delete(g_ConfFile, sec, gesture))
        return false
    try g_Conf.DeleteKey(sec, GestureConf_KeyExact(sec, gesture))
    catch {
    }
    Gesture_ReloadLayers()
    return true
}

GestureStore_SetAppMatch(appName, exe, cls, title := "", titleRx := "", noglobal := "") {
    global g_Conf, g_ConfFile, g_GestureAppPrefix
    appName := Trim(appName)
    if (appName = "")
        return false
    sec := g_GestureAppPrefix . appName
    pairs := Map("set_file", Trim(exe), "set_class", Trim(cls)
        , "set_title", Trim(title), "set_title_regex", Trim(titleRx))
    for _k, _v in pairs {
        if (_v = "")
            continue
        if (!GestureIni_Upsert(g_ConfFile, sec, _k, _v))
            return false
        try g_Conf.Set(sec, _k, _v)
        catch {
        }
    }
    if (noglobal != "") {
        nv := (noglobal = "1" || noglobal = 1) ? "1" : "0"
        if (!GestureIni_Upsert(g_ConfFile, sec, "noglobal", nv))
            return false
        try g_Conf.Set(sec, "noglobal", nv)
        catch {
        }
    }
    Gesture_ReloadLayers()
    return true
}

; ---- 模板保存: name=action|||x1,y1 x2,y2 ... (同名覆盖=重录) ----
GestureStore_SetTemplate(name, action, points) {
    return GestureStore_SetTemplateSamples(name, action, [points])
}

; ---- 模板多样本保存: samples 为点串数组, 以 |||| 连接 ----
GestureStore_SetTemplateSamples(name, action, samples) {
    global g_Conf, g_ConfFile
    name := Trim(name)
    action := Trim(action)
    if (name = "" || action = "" || !IsObject(samples) || samples.Length = 0)
        return false
    if InStr(name, "=") || InStr(name, "|") || InStr(name, ":")
        return false
    joined := ""
    i := 1
    for _, sp in samples {
        sp := Trim(sp)
        if (sp = "")
            continue
        joined .= (i > 1 ? "||||" : "") . sp
        i++
    }
    if (joined = "")
        return false
    val := action . "|||" . joined
    if (!GestureIni_Upsert(g_ConfFile, "GestureTemplates", name, val, true))
        return false
    try g_Conf.Set("GestureTemplates", name, val)
    catch {
    }
    try Tpl_LoadAll()
    catch {
    }
    Gesture_ReloadLayers()
    return true
}

GestureStore_DelTemplate(name) {
    global g_Conf, g_ConfFile
    name := Trim(name)
    if (name = "")
        return false
    if (!GestureIni_Delete(g_ConfFile, "GestureTemplates", name, true))
        return false
    try g_Conf.DeleteKey("GestureTemplates", name)
    catch {
    }
    try Tpl_LoadAll()
    catch {
    }
    Gesture_ReloadLayers()
    return true
}

; ---- 禁用开关: off=1 写入 [GestureDisabled] 裸行, off=0 删除 ----
GestureStore_SetDisabled(id, off) {
    global g_Conf, g_ConfFile
    id := Trim(id)
    if (id = "" || SubStr(id, 1, 1) = ";")
        return false
    ok := false
    if (off)
        ok := GestureIni_AppendBare(g_ConfFile, "GestureDisabled", id)
    else
        ok := GestureIni_DeleteBare(g_ConfFile, "GestureDisabled", id)
    if (!ok && !off) {
        ok := true  ; 本就不存在视为成功
    }
    if (!ok)
        return false
    try {
        if !g_Conf.HasSection("GestureDisabled")
            g_Conf.AddSection("GestureDisabled")
        if (off)
            g_Conf.AddKey("GestureDisabled", id, "")
        else
            g_Conf.DeleteKey("GestureDisabled", id)
    } catch {
    }
    Gesture_ReloadLayers()
    return true
}

GestureStore_AddBlacklist(pattern) {
    global g_Conf, g_ConfFile
    pattern := Trim(pattern)
    if (pattern = "")
        return false
    if (!GestureIni_AppendBare(g_ConfFile, "GestureBlacklist", pattern))
        return false
    try {
        if !g_Conf.HasSection("GestureBlacklist")
            g_Conf.AddSection("GestureBlacklist")
        g_Conf.AddKey("GestureBlacklist", pattern, "")
    } catch {
    }
    Gesture_ReloadLayers()
    return true
}

GestureStore_DelBlacklist(pattern) {
    global g_Conf, g_ConfFile
    pattern := Trim(pattern)
    if (!GestureIni_DeleteBare(g_ConfFile, "GestureBlacklist", pattern))
        return false
    try g_Conf.DeleteKey("GestureBlacklist", pattern)
    catch {
    }
    Gesture_ReloadLayers()
    return true
}
