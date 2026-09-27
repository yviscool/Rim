#Requires AutoHotkey v2.0
#Warn All, Off

; === VimCfg_TabsMisc - 配置中心页: 动作/帮助/备份/历史/冲突断言 ===
; 入口见 VimConfigUI.ahk, 加载顺序见 Rim.ahk
; ==================== 动作页 (替代托盘 插件P: 按插件浏览动作, 双击定位源码) ====================
VimCfg_BuildActionsTab(g) {
    global g_VimCfg
    g.Add("GroupBox", "x10 y40 w860 h400", T("cfg.actions_title"))
    g.Add("Text", "x25 y70 w60", T("cfg.actions_plugin"))
    ddl := g.Add("DropDownList", "x90 y67 w200", [])
    g.Add("Text", "x310 y70 w60", T("cfg.actions_filter"))
    ed := g.Add("Edit", "x370 y67 w200 h25")
    lv := g.Add("ListView", "x20 y100 w840 h330 grid", [T("cfg.actions_col_action"), T("cfg.actions_col_desc")])
    lv.ModifyCol(1, 280)
    lv.ModifyCol(2, 540)
    g_VimCfg["ac_ddl"] := ddl
    g_VimCfg["ac_ed"] := ed
    g_VimCfg["ac_lv"] := lv
    g_VimCfg["ac_lines"] := []
    g_VimCfg["ac_file"] := ""
    names := []
    try names := VimDConfig_PluginNames()
    for n in names {
        try ddl.Add([n])
    }
    ddl.OnEvent("Change", VimCfg_AcPick)
    ed.OnEvent("Change", VimCfg_AcFilter)
    lv.OnEvent("DoubleClick", VimCfg_AcGoto)
    if (names.Length > 0) {
        try ddl.Choose(1)
        VimCfg_AcPick(ddl)
    }
}

; 动作浏览器取词: 正则从插件源码抠出的 T("key") 字面量 key (恒为 act./cmd. 静态键);
; 动态审计会将其列为 dynamic, 但值域封闭 (源码字面量), T() 缺键回落 key 本身, 永不抛错
VimCfg_TrKey(key) {
    if (key = "")
        return ""
    return T(key)
}

VimCfg_AcPick(*) {
    global g_VimCfg
    name := ""
    try name := g_VimCfg["ac_ddl"].Text
    if (name = "")
        return
    file := A_ScriptDir "\Plugins\" name ".ahk"
    g_VimCfg["ac_file"] := file
    lines := []
    if FileExist(file) {
        for _line in ReadFileLines(file) {
            if RegExMatch(_line, 'RegisterAction\("([^"]+)"(?:\s*,\s*(?:"([^"]*)"|T\("([^"]+)"\)))?', &mm) {
                desc := mm[2]
                if (desc = "" && mm[3] != "")
                    desc := VimCfg_TrKey(mm[3])
                lines.Push(Map("action", mm[1], "desc", desc))
            } else if RegExMatch(_line, '(?:Host\s*\(\s*"RegisterCommand"\s*,\s*|RegisterCommand\s*\(\s*)"([^"]+)"\s*,\s*"([^"]+)"(?:\s*,\s*"[^"]*")?(?:\s*,\s*(?:"([^"]*)"|T\("([^"]+)"\)))?', &mc) {
                desc := mc[3]
                if (desc = "" && mc[4] != "")
                    desc := VimCfg_TrKey(mc[4])
                lines.Push(Map("action", mc[1] " [" mc[2] "]", "desc", desc))
            } else if RegExMatch(_line, 'RimCommand\.Register\("([^"]+)"\s*,\s*"([^"]+)"\s*,\s*MakeLegacyCmd\("([^"]+)"[^)]*T\("([^"]+)"\)', &mr) {
                lines.Push(Map("action", mr[3], "desc", VimCfg_TrKey(mr[4])))
            }
        }
    }
    g_VimCfg["ac_lines"] := lines
    try g_VimCfg["ac_ed"].Value := ""
    VimCfg_AcFilter()
}

VimCfg_AcFilter(*) {
    global g_VimCfg
    if !g_VimCfg.Has("ac_lv")
        return
    lv := g_VimCfg["ac_lv"]
    needle := ""
    try needle := Trim(g_VimCfg["ac_ed"].Value)
    try lv.Delete()
    for item in g_VimCfg["ac_lines"] {
        text := item["action"] " " item["desc"]
        if (needle = "" || InStr(text, needle)) {
            try lv.Add("", item["action"], item["desc"])
        }
    }
}

VimCfg_AcGoto(*) {
    global g_VimCfg
    lv := g_VimCfg["ac_lv"]
    row := 0
    try row := lv.GetNext(0, "F")
    if (row < 1)
        return
    action := ""
    try action := lv.GetText(row, 1)
    if (action = "")
        return
    action := RegExReplace(action, " \[.*\]$", "")
    try VimDConfig_SearchFileForEdit(action, "", false, g_VimCfg["ac_file"])
}

; ==================== 帮助页 (替代托盘 热键K) ====================
VimCfg_BuildHelpTab(g) {
    global g_BuildTag, g_VimCfg
    txt := ""
    try txt := KeyHelpText()
    catch {
        txt := ""
    }
    tag := "?"
    try tag := g_BuildTag
    catch {
    }
    txt .= "`n" . T("cfg.help_build", tag)
    g.Add("GroupBox", "x10 y40 w860 h320", T("cfg.help_title"))
    ed := g.Add("Edit", "x20 y65 w840 h285 ReadOnly -VScroll")
    try ed.Value := txt
    ; 备份与回滚: 每次保存自动备份 (Conf/backup, 滚动 5 份)
    g.Add("GroupBox", "x10 y365 w860 h115", T("cfg.backup_title"))
    lbb := g.Add("ListBox", "x20 y385 w640 R4", [])
    g.Add("Button", "x670 y385 w85", T("cfg.backup_restore")).OnEvent("Click", VimCfg_BackupRestore)
    g.Add("Button", "x765 y385 w85", T("cfg.history")).OnEvent("Click", VimCfg_HistoryShow)
    g_VimCfg["backuplb"] := lbb
    VimCfg_BackupReload()
}

VimCfg_BackupReload() {
    global g_VimCfg
    if (!g_VimCfg.Has("backuplb"))
        return
    lbb := g_VimCfg["backuplb"]
    try lbb.Delete()
    names := []
    try {
        Loop Files, A_ScriptDir "\Conf\backup\rim_*.ini" {
            names.Push(A_LoopFileName)
        }
    }
    if (names.Length = 0) {
        try lbb.Add([T("cfg.backup_none")])
        return
    }
    ; 倒序 (新在前; 时间戳文件名正序即时序)
    i := names.Length
    while (i >= 1) {
        try lbb.Add([names[i]])
        i--
    }
}

VimCfg_BackupRestore(*) {
    global g_VimCfg
    if (!g_VimCfg.Has("backuplb"))
        return
    lbb := g_VimCfg["backuplb"]
    sel := ""
    try sel := lbb.Text
    if (sel = "" || sel = T("cfg.backup_none"))
        return
    src := A_ScriptDir "\Conf\backup\" . sel
    if (!FileExist(src))
        return
    if (MsgBox(sel, T("cfg.backup_restore"), "YesNo") != "Yes")
        return
    try FileCopy(src, A_ScriptDir "\Conf\rim.ini", 1)
    catch as e {
        MsgBox(T("cfg.save_failed", e.Message), T("cfg.title"), 16)
        return
    }
    VimCfg_MarkReopen()
    MsgBox(T("cfg.backup_done"), T("cfg.title"))
    RestartRunZ()
}

; ==================== 变更历史 (Conf/config-history.log, 单行一单) ====================
; 行格式: stamp 结果 n=N | [sec] key: old → new | ... (单项截断 120 字, 单单截断 20 项)
; 轮转: 超 200KB 只留后 500 行
VimCfg_LogHistory(dirty, undo, result, needRestart, note := "", logPath := "") {
    parts := []
    shown := 0
    for sk, d in dirty {
        shown++
        if (shown > 20) {
            parts.Push("...")
            break
        }
        pos := InStr(sk, Chr(1))
        sec := SubStr(sk, 1, pos - 1)
        old := ""
        for step in undo {
            if (step["sec"] = sec && step["key"] = d["key"]) {
                old := step["had"] ? step["val"] : "(new)"
                break
            }
        }
        newVal := d["del"] ? "(delete)" : d["val"]
        seg := "[" sec "] " . d["key"] . ": " . old . " → " . newVal
        if (StrLen(seg) > 120)
            seg := SubStr(seg, 1, 120) . "..."
        ; 日志单行: 值内换行拍平
        seg := StrReplace(StrReplace(seg, "`r", " "), "`n", " ")
        parts.Push(seg)
    }
    line := FormatTime(, "yyyyMMddHHmmss") . " " . result . " n=" . dirty.Count
    if (needRestart.Length > 0)
        line .= " needRestart=" . needRestart.Length
    if (note != "")
        line .= " note=" . StrReplace(StrReplace(note, "`r", " "), "`n", " ")
    for seg in parts
        line .= " | " . seg
    if (logPath = "")
        logPath := A_ScriptDir "\Conf\config-history.log"
    try FileAppend(line . "`r`n", logPath, "UTF-8")
    catch {
        return
    }
    try {
        if (FileGetSize(logPath) > 204800) {
            content := FileRead(logPath, "UTF-8")
            lines := StrSplit(StrReplace(content, "`r", ""), "`n")
            tail := []
            i := lines.Length
            while (i >= 1 && tail.Length < 500) {
                if (Trim(lines[i]) != "")
                    tail.InsertAt(1, lines[i])
                i--
            }
            out := ""
            for tailLine in tail
                out .= tailLine . "`r`n"
            f := FileOpen(logPath, "w", "UTF-8")
            f.Write(out)
            f.Close()
        }
    } catch {
    }
}

VimCfg_HistoryShow(*) {
    global g_VimCfg
    if (g_VimCfg.Has("hisGui")) {
        try g_VimCfg["hisGui"].Destroy()
        catch {
        }
    }
    hg := Gui("+Owner" g_VimCfg["gui"].Hwnd, T("cfg.history_title"))
    hg.SetFont("s10", "Microsoft YaHei")
    lv := hg.Add("ListView", "x10 y10 w660 h260 grid", [T("cfg.history_col_time"), T("cfg.history_col_result"), T("cfg.history_col_summary")])
    lv.ModifyCol(1, 130)
    lv.ModifyCol(2, 90)
    lv.ModifyCol(3, 430)
    rows := VimCfg_HistoryRead()
    if (rows.Length = 0)
        lv.Add("", "", "", T("cfg.history_empty"))
    for row in rows
        lv.Add("", row["stamp"], row["result"], row["summary"])
    hg.Add("Button", "x430 y280 w120 Default", T("cfg.history_revert")).OnEvent("Click", VimCfg_HistoryRevert)
    hg.Add("Button", "x560 y280 w110", T("cfg.dlg_cancel")).OnEvent("Click", VimCfg_HistoryClose)
    g_VimCfg["hisGui"] := hg
    g_VimCfg["hisLv"] := lv
    g_VimCfg["hisRows"] := rows
    hg.Show("w680 h320")
}

VimCfg_HistoryRead() {
    rows := []
    logPath := A_ScriptDir "\Conf\config-history.log"
    if (!FileExist(logPath))
        return rows
    content := ""
    try content := FileRead(logPath, "UTF-8")
    catch {
        return rows
    }
    for rawLine in StrSplit(StrReplace(content, "`r", ""), "`n") {
        line := Trim(rawLine)
        if (line = "")
            continue
        if RegExMatch(line, "^(\d{14}) (\w+) n=\d+(.*)$", &mm)
            rows.Push(Map("stamp", mm[1], "result", mm[2], "summary", Trim(mm[3]), "raw", line))
    }
    ; 倒序 (新在前)
    out := []
    i := rows.Length
    while (i >= 1) {
        out.Push(rows[i])
        i--
    }
    return out
}

VimCfg_HistoryClose(*) {
    global g_VimCfg
    try g_VimCfg["hisGui"].Destroy()
    catch {
    }
    g_VimCfg.Delete("hisGui")
}

; 回到此处: 取该单旧值组装 reverse dirty, 走标准预览→事务管线
VimCfg_HistoryRevert(*) {
    global g_VimCfg
    if (!g_VimCfg.Has("hisLv") || !g_VimCfg.Has("hisRows"))
        return
    lv := g_VimCfg["hisLv"]
    row := 0
    try row := lv.GetNext(0, "F")
    if (row < 1)
        return
    if (row > g_VimCfg["hisRows"].Length)
        return
    entry := g_VimCfg["hisRows"][row]
    dirty := Map()
    for seg in StrSplit(entry["raw"], "|") {
        seg := Trim(seg)
        if RegExMatch(seg, "^\[(.+)\] ([^:]+): (.*) → (.*)$", &mm) {
            sec := mm[1]
            key := Trim(mm[2])
            old := mm[3]
            if (old = "(new)")
                dirty[sec . Chr(1) . key] := Map("key", key, "val", "", "del", true)
            else
                dirty[sec . Chr(1) . key] := Map("key", key, "val", old, "del", false)
        }
    }
    if (dirty.Count = 0)
        return
    for sk, d in dirty
        g_VimCfg["dirty"][sk] := d
    VimCfg_RefreshWarnBar()
    VimCfg_HistoryClose()
    VimCfg_PreviewSave(dirty)
}

; ==================== 冲突断言引擎 (纯读, 可单测; 只说不拦) ====================
; 返回数组, 每项 {level: "warn"/"info", text: "..."}
VimCfg_EffGui(key, def := "") {
    global g_Conf
    if !IsObject(g_Conf)
        return def
    skin := g_Conf.Get("Gui", "Skin", "")
    if (skin != "") {
        sp := A_ScriptDir "\Conf\Skins\" skin ".ini"
        if FileExist(sp) {
            try {
                sv := EasyIni(sp).Get("Gui", key, "")
                if (sv != "")
                    return sv
            }
        }
    }
    return g_Conf.Get("Gui", key, def)
}

VimCfg_CheckConflicts() {
    global g_Conf, g_CfgSchema, g_VimEngine
    out := []
    if !IsObject(g_Conf)
        return out
    G := g_Conf
    ; 1. 插件关但窗口节还在 = 门控丢失, 输入框被劫持
    pairs := [["TotalCommander", "TTOTAL_CMD"], ["Explorer", "CabinetWClass"]]
    for pr in pairs {
        if (G.Get("Plugins", pr[1], "1") = "0" && G.HasSection(pr[2]) && G.GetSection(pr[2]).Count > 0)
            out.Push(Map("level", "warn", "text", T("cfg.warn_plugin_off", pr[1], pr[2])))
    }
    ; 2. 无托盘 + 后台运行 = 丢应用 (皮肤覆盖纳入)
    if (VimCfg_EffGui("ShowTrayIcon", "1") = "0" && G.Get("Config", "RunInBackground", "1") = "1")
        out.Push(Map("level", "warn", "text", T("cfg.warn_tray")))
    ; 3. 单击执行 + 鼠标移动改选中 = 必误触
    if (G.Get("Config", "ClickToRun", "1") = "1" && G.Get("Config", "ChangeCommandOnMouseMove", "0") = "1")
        out.Push(Map("level", "warn", "text", T("cfg.warn_click")))
    ; 4/5/6. 知情类
    if (G.Get("TotalCommander_Config", "AsOpenFileDialog", "0") = "1")
        out.Push(Map("level", "info", "text", T("cfg.info_tcdlg")))
    if (G.Get("Config", "SwitchToEngIME", "0") = "1")
        out.Push(Map("level", "info", "text", T("cfg.info_ime")))
    if (G.Get("Config", "ExitIfInactivate", "1") = "1" && G.Get("Config", "RunInBackground", "1") != "1")
        out.Push(Map("level", "info", "text", T("cfg.info_exitblur")))
    ; 7. 另一个 RunZ 窗口 (原版或重复启动)
    try {
        if (hw := WinExist("RunZ    ")) {
            pid := 0
            try pid := WinGetPID("ahk_id " hw)
            if (pid != 0 && pid != DllCall("GetCurrentProcessId", "UInt"))
                out.Push(Map("level", "warn", "text", T("cfg.warn_duprunz", pid)))
        }
    }
    ; 8. schema int/slider 越界 (ini 手改/旧版本残留, 存得进但行为异常)
    try {
        if (IsSet(g_CfgSchema)) {
            for spec in g_CfgSchema {
                if (spec["type"] != "int" && spec["type"] != "slider")
                    continue
                cur := G.Get(spec["sec"], spec["key"], "")
                if (cur = "")
                    continue
                if (CfgValidate(spec["sec"], spec["key"], cur) != "")
                    out.Push(Map("level", "warn", "text", T("cfg.warn_int_range", spec["sec"], spec["key"], spec["min"], spec["max"])))
            }
        }
    }
    ; 9. 未知段 (无 set_class/set_file 且非已知结构段): 启动编译静默跳过, 配了也白配
    try {
        knownSecs := Map("Config", 1, "SmartInput", 1, "Gui", 1, "exclude", 1, "GlobalHotkey", 1, "Hotkey", 1
            , "Plugins", 1, "StatsBall", 1, "Gesture", 1, "GestureDefinitions", 1, "Gestures", 1
            , "GestureBlacklist", 1, "GestureTemplates", 1, "GestureDisabled", 1, "GestureDesc", 1
            , "FallbackCommand", 1, "TotalCommander_Config", 1, "Commands", 1, "Auto", 1, "Rank", 1, "History", 1)
        for secName, _sec in G.GetSections() {
            if (knownSecs.Has(secName) || SubStr(secName, 1, 12) = "GestureApp:")
                continue
            if (G.Get(secName, "set_class", "") = "" && G.Get(secName, "set_file", "") = "")
                out.Push(Map("level", "warn", "text", T("cfg.warn_unknown_sec", secName)))
        }
    }
    ; 10. 未注册动作 (引擎 keymap 全扫, 截断 10 条; 自定义后注册的不在此列)
    try {
        if (IsSet(g_VimEngine) && IsObject(g_VimEngine)) {
            shown := 0
            for _wname, win in g_VimEngine.WinList {
                if (!IsObject(win) || !win.modeList.Has("normal"))
                    continue
                for _mname, modeObj in win.modeList {
                    if (!IsObject(modeObj))
                        continue
                    for mapKey, act in modeObj.keymapList {
                        if (!g_VimEngine.IsValidAction(act)) {
                            out.Push(Map("level", "warn", "text", T("cfg.warn_bad_action", mapKey, act)))
                            shown++
                            if (shown >= 10)
                                break
                        }
                    }
                    if (shown >= 10)
                        break
                }
                if (shown >= 10)
                    break
            }
        }
    }
    return out
}

VimCfg_RefreshWarnBar() {
    global g_VimCfg
    if !g_VimCfg.Has("warnbar")
        return
    list := VimCfg_CheckConflicts()
    txt := ""
    try {
        if (g_VimCfg.Has("dirty") && g_VimCfg["dirty"].Count > 0)
            txt .= T("cfg.unsaved_n", g_VimCfg["dirty"].Count) "`n"
        if (g_VimCfg.Has("specErr") && g_VimCfg["specErr"].Count > 0) {
            first := ""
            for _sk, msg in g_VimCfg["specErr"] {
                first := msg
                break
            }
            txt .= T("cfg.spec_invalid", g_VimCfg["specErr"].Count) ": " . first . "`n"
        }
    } catch {
    }
    for w in list
        txt .= (w["level"] = "warn" ? "⚠ " : "ℹ ") w["text"] "`n"
    if (txt = "")
        txt := T("cfg.warn_ok")
    try g_VimCfg["warnbar"].Value := RTrim(txt, "`n")
}
