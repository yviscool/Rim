#Requires AutoHotkey v2.0
#Warn All, Off

; === VimConfigUI - 配置中心 (托盘 配置C) ===
; 设计语言对齐 Gui/GestureUI.ahk: Tab3 + YaHei s10 + ListView/Edit + 新增/编辑/删除/保存
; 保存走 VimCfg_WriteIni 逐行写回 (保留注释/空行/顺序; EasyIni.Save 会洗掉全文件注释, 禁用)
; 保存后由 WatchUserFileList (3s) 自动重载, 无需重启按钮

global g_VimCfg := Map()

; ==================== 入口 ====================
VimConfig_Show(*) {
    global g_VimCfg
    if (g_VimCfg.Has("gui")) {
        try {
            g_VimCfg["gui"].Show()
            return
        } catch {
        }
        g_VimCfg.Clear()
    }
    g := Gui("+Resize", T("cfg.title"))
    g.SetFont("s10", "Microsoft YaHei")
    g_VimCfg["gui"] := g
    g_VimCfg["dirty"] := Map()
    tabs := g.Add("Tab3", "w880 h470", [T("cfg.tab_keys"), T("cfg.tab_globalhotkey"), T("cfg.tab_plugins"), T("cfg.tab_tc"), T("cfg.tab_launcher"), T("cfg.tab_statsball"), T("cfg.tab_actions"), T("cfg.tab_help")])
    g_VimCfg["tabs"] := tabs

    tabs.UseTab(1)
    VimCfg_BuildKeysTab(g)
    tabs.UseTab(2)
    VimCfg_BuildKvTab(g, "GlobalHotkey", "gh")
    tabs.UseTab(3)
    VimCfg_BuildPluginTab(g)
    tabs.UseTab(4)
    VimCfg_BuildTCTab(g)
    tabs.UseTab(5)
    VimCfg_BuildLauncherTab(g)
    tabs.UseTab(6)
    VimCfg_BuildStatsBallTab(g)
    tabs.UseTab(7)
    VimCfg_BuildActionsTab(g)
    tabs.UseTab(8)
    VimCfg_BuildHelpTab(g)
    tabs.UseTab()

    ; 按钮行/警告条用固定 Y (不用 y+10 相对锚点: 锚点是最后建的帮助页尾控件,
    ; 页内容一溢出就会盖住按钮; 固定坐标后任何页都够不着)
    g.Add("Button", "x10 y488 w110", T("cfg.save")).OnEvent("Click", VimCfg_OnSave)
    g.Add("Button", "x+10 w130", T("cfg.open_in_editor")).OnEvent("Click", VimCfg_OnTextEdit)
    g.Add("Text", "x+14 yp+6 w560", T("cfg.save_hint"))
    wb := g.Add("Edit", "x10 y522 w880 h40 ReadOnly -VScroll +BackgroundFFFFE0")
    g_VimCfg["warnbar"] := wb
    g.OnEvent("Close", VimCfg_OnClose)
    g.OnEvent("Escape", VimCfg_OnClose)
    g.Show("w900 h610")
    VimCfg_KeyWinRefresh()
    VimCfg_RefreshWarnBar()
}

VimCfg_OnClose(*) {
    global g_VimCfg
    ; 关窗时还有未保存的更改: 问一下, 否则 toggles/勾选静默丢失
    ; (Clear 会连 dirty 一起清掉)
    try {
        if (g_VimCfg.Has("dirty") && g_VimCfg["dirty"].Count > 0) {
            ans := MsgBox(T("cfg.unsaved_prompt"), T("cfg.unsaved_title"), "YesNoCancel")
            if (ans = "Cancel")
                return
            if (ans = "Yes") {
                VimCfg_OnSave()
                if (g_VimCfg.Has("dirty") && g_VimCfg["dirty"].Count > 0)
                    return
            }
        }
    } catch {
    }
    ; 必须真销毁窗体: 只 Clear 会漏一个活窗口在屏幕上堆叠,
    ; 后开的窗与其像素级重叠, 用户点到哪层全看运气 ("怎么点都没反应"的主谋之一)
    try {
        if (g_VimCfg.Has("gui")) {
            try g_VimCfg["gui"].Hide()
            catch {
            }
            try g_VimCfg["gui"].Destroy()
            catch {
            }
        }
    } catch {
    }
    g_VimCfg.Clear()
}

VimCfg_OnTextEdit(*) {
    try {
        VimCfg_OnTextEditInner()
    } catch as e {
        VimCfg_ShowErr("OnTextEdit", e)
        try MsgBox(T("cfg.save_failed", e.Message), T("cfg.title"), 16)
        catch {
        }
    }
}

VimCfg_OnTextEditInner(*) {
    EditConfig()
}

; 事件处理器兜底上报: 全局 OnError 会吞掉处理器里的异常 ("点了没反应"),
; 这里记 VIMCFG-ERR 日志并在警告条露出原文, 把静默失败变可见.
; (pick 类高频处理器只写警告条不弹窗; 保存/打开走 MsgBox 强提醒)

; ==================== 保存层 (纯函数, 可单测) ====================
; final: Map, key = sec Chr(1) key, value = {val: "...", del: true/false}
VimCfg_WriteIni(path, final) {
    lines := ReadFileLines(path)
    out := []
    cur := ""
    seen := Map()
    done := Map()
    for line in lines {
        if RegExMatch(line, "^\s*\[(.+)\]\s*$", &m) {
            ; 段尾: 把本段新增键追到段末
            if (cur != "") {
                for sk, d in final {
                    pos := InStr(sk, Chr(1))
                    if (SubStr(sk, 1, pos - 1) = cur && !done.Has(sk) && !d["del"])
                        out.Push(d["key"] "=" d["val"]), done[sk] := true
                }
            }
            cur := Trim(m[1])
            seen[cur] := true
            out.Push(line)
            continue
        }
        if (cur != "" && !RegExMatch(line, "^\s*[;#]")) {
            if RegExMatch(line, "^([^=]+)=(.*)$", &k) {
                kk := Trim(k[1])
                sk := cur . Chr(1) . kk
                if (final.Has(sk) && !done.Has(sk)) {
                    done[sk] := true
                    d := final[sk]
                    if (!d["del"])
                        out.Push(d["key"] "=" d["val"])
                    continue
                }
            }
        }
        out.Push(line)
    }
    if (cur != "") {
        for sk, d in final {
            pos := InStr(sk, Chr(1))
            if (SubStr(sk, 1, pos - 1) = cur && !done.Has(sk) && !d["del"])
                out.Push(d["key"] "=" d["val"]), done[sk] := true
        }
    }
    ; 全新段追到文件尾
    for sk, d in final {
        if (done.Has(sk) || d["del"])
            continue
        pos := InStr(sk, Chr(1))
        sec := SubStr(sk, 1, pos - 1)
        if (!seen.Has(sec)) {
            seen[sec] := true
            out.Push("")
            out.Push("[" sec "]")
        }
        out.Push(d["key"] "=" d["val"])
        done[sk] := true
    }
    content := ""
    for ln in out
        content .= ln "`r`n"
    f := FileOpen(path, "w", "UTF-8-RAW")
    f.Write(content)
    f.Close()
}

VimCfg_MarkDirty(sec, key, val := "", del := false) {
    global g_VimCfg
    g_VimCfg["dirty"][sec . Chr(1) . key] := Map("key", key, "val", val, "del", del)
}

VimCfg_LogErr(fn, e) {
    try {
        extra := ""
        try extra := e.Extra
        catch {
        }
        line := ""
        try line := e.Line
        catch {
        }
        FileAppend(A_Now . " VIMCFG-ERR " . fn . ": " . e.Message . " @line=" . line . " extra=" . extra . "`n", A_ScriptDir . "\Rim.error.log")
    } catch {
    }
}

VimCfg_ShowErr(fn, e) {
    VimCfg_LogErr(fn, e)
    global g_VimCfg
    try {
        if (g_VimCfg.Has("warnbar")) {
            cur := ""
            try cur := g_VimCfg["warnbar"].Value
            catch {
            }
            g_VimCfg["warnbar"].Value := cur . "`n✖ " . T("cfg.handler_failed", fn, e.Message)
        }
    } catch {
    }
}

VimCfg_OnSave(*) {
    try {
        VimCfg_OnSaveInner()
    } catch as e {
        VimCfg_ShowErr("OnSave", e)
        try MsgBox(T("cfg.save_failed", e.Message), T("cfg.title"), 16)
        catch {
        }
    }
}

VimCfg_OnSaveInner(*) {
    global g_VimCfg, g_Conf, g_AutoConf
    VimCfg_CollectLauncherTab()
    VimCfg_CollectStatsBallTab()
    VimCfg_CollectTCTab()
    VimCfg_CollectPluginTab()
    VimCfg_RefreshWarnBar()
    dirty := g_VimCfg["dirty"]
    if (dirty.Count = 0) {
        ToolTip(T("cfg.no_change"))
        SetTimer(RemoveToolTip, -1200)
        return
    }
    path := A_ScriptDir "\Conf\rim.ini"
    try {
        VimCfg_WriteIni(path, dirty)
    } catch as e {
        MsgBox(T("cfg.save_failed", e.Message), T("cfg.title"), 16)
        return
    }
    ; 同步内存 (新段自动建; 删键同步删), 顺带记下语言是否变了
    newLang := ""
    try {
        for sk, d in dirty {
            pos := InStr(sk, Chr(1))
            sec := SubStr(sk, 1, pos - 1)
            if (d["del"])
                g_Conf.DeleteKey(sec, d["key"])
            else
                g_Conf.Set(sec, d["key"], d["val"])
            if (sec = "Config" && d["key"] = "Language" && !d["del"])
                newLang := d["val"]
        }
    }
    ; 保存必触发 3s 后的全重启 (WatchUserFileList), 配置窗会被杀:
    ; 立旗为证, 新进程起来后自动把配置窗找回来 (所见即所得, 不用怀疑人生)
    try {
        if (IsObject(g_AutoConf)) {
            try g_AutoConf.Set("UI", "ReopenConfig", "1")
            catch {
            }
            try g_AutoConf.Save()
            catch {
            }
        }
    } catch {
    }
    g_VimCfg["dirty"] := Map()
    if (newLang != "") {
        ; 语言切换: 托盘即时重建, 问是否重启使全部界面生效
        try {
            if (I18nApplyTray(newLang)) {
                if (MsgBox(T("cfg.lang_restart_prompt"), T("cfg.lang_restart_title"), "YesNo") = "Yes") {
                    RestartRunZ()
                    return
                }
                ToolTip(T("cfg.lang_applied"))
                SetTimer(RemoveToolTip, -2000)
                return
            }
        } catch {
        }
    }
    ToolTip(T("cfg.saved"))
    SetTimer(RemoveToolTip, -1500)
}

; ==================== 按键页 ====================
VimCfg_BuildKeysTab(g) {
    global g_VimCfg
    g.Add("GroupBox", "x10 y40 w210 h300", T("cfg.keys_window"))
    lbw := g.Add("ListBox", "x20 y65 w190 R13", [])
    g.Add("GroupBox", "x10 y350 w210 h80", T("cfg.keys_mode"))
    lbm := g.Add("ListBox", "x20 y375 w190 R3", [])
    g.Add("GroupBox", "x10 y440 w210 h40", T("cfg.keys_filter"))
    ed := g.Add("Edit", "x20 y450 w190 h25")
    g.Add("GroupBox", "x230 y40 w650 h425", T("cfg.keys_mapping"))
    lv := g.Add("ListView", "x240 y65 w630 h370 grid", [T("cfg.keys_col_key"), T("cfg.keys_col_action"), T("cfg.keys_col_desc")])
    lv.ModifyCol(1, 110)
    lv.ModifyCol(2, 230)
    lv.ModifyCol(3, 271)
    g.Add("Button", "x240 y445 w70", T("cfg.keys_add")).OnEvent("Click", VimCfg_KeyAdd)
    g.Add("Button", "x+10 w70", T("cfg.keys_edit")).OnEvent("Click", VimCfg_KeyEdit)
    g.Add("Button", "x+10 w70", T("cfg.keys_delete")).OnEvent("Click", VimCfg_KeyDel)
    g_VimCfg["kw"] := lbw
    g_VimCfg["km"] := lbm
    g_VimCfg["ke"] := ed
    g_VimCfg["kl"] := lv
    g_VimCfg["krows"] := []
    lbw.OnEvent("Change", VimCfg_KeyWinPick)
    lbm.OnEvent("Change", VimCfg_KeyModePick)
    ed.OnEvent("Change", VimCfg_KeyFilter)
    lv.OnEvent("DoubleClick", VimCfg_KeyDblEdit)
}

VimCfg_EngineWins() {
    global g_VimEngine
    wins := []
    ; IsSet 兜底: 引擎未初始化时 IsObject 会抛"未赋值", 对话框砸脸且中断刷新
    if (IsSet(g_VimEngine) && IsObject(g_VimEngine)) {
        for wname, wobj in g_VimEngine.WinList {
            if (wname = "__global__")
                continue
            wins.Push(wname)
        }
    }
    return wins
}

VimCfg_KeyWinRefresh() {
    global g_VimCfg
    if !g_VimCfg.Has("kw")
        return
    lbw := g_VimCfg["kw"]
    try lbw.Delete()
    for w in VimCfg_EngineWins() {
        try lbw.Add([w])
    }
    if (VimCfg_EngineWins().Length > 0) {
        try lbw.Choose(1)
        VimCfg_KeyWinPick(lbw)
    }
}

VimCfg_KeyWinPick(*) {
    try {
        VimCfg_KeyWinPickInner()
    } catch as e {
        VimCfg_ShowErr("KeyWinPick", e)
    }
}

VimCfg_KeyWinPickInner(*) {
    global g_VimCfg, g_VimEngine
    lbw := g_VimCfg["kw"]
    wname := ""
    try wname := lbw.Text
    g_VimCfg["kwin"] := wname
    g_VimCfg["kmode"] := ""
    lbm := g_VimCfg["km"]
    try lbm.Delete()
    ; 模式按字母序枚举恒为 [insert, normal, ...], 首项 insert 各窗样板相同会显" frozen";
    ; 默认切 normal (各窗动作差异页), 找不到才回落首项
    pickIdx := 1
    mi := 0
    if (wname != "" && IsSet(g_VimEngine) && IsObject(g_VimEngine)) {
        w := g_VimEngine.GetWin(wname)
        if IsObject(w) {
            for mname, mobj in w.modeList {
                try lbm.Add([mname])
                mi++
                if (mname = "normal")
                    pickIdx := mi
            }
        }
    }
    g_VimCfg["krows"] := []
    VimCfg_KeyFilter()
    ; 默认选中 normal (回落首个模式)
    try {
        lbm.Choose(pickIdx)
        VimCfg_KeyModePick(lbm)
    }
}

VimCfg_KeyModePick(*) {
    try {
        VimCfg_KeyModePickInner()
    } catch as e {
        VimCfg_ShowErr("KeyModePick", e)
    }
}

VimCfg_KeyModePickInner(*) {
    global g_VimCfg, g_VimEngine
    lbm := g_VimCfg["km"]
    mname := ""
    try mname := lbm.Text
    g_VimCfg["kmode"] := mname
    rows := []
    wname := g_VimCfg.Has("kwin") ? g_VimCfg["kwin"] : ""
    if (wname != "" && mname != "" && IsSet(g_VimEngine) && IsObject(g_VimEngine)) {
        w := g_VimEngine.GetWin(wname)
        if IsObject(w) && w.modeList.Has(mname) {
            modeObj := w.modeList[mname]
            for key, action in modeObj.keymapList {
                desc := action
                if (g_VimEngine.ActionList.Has(action)) {
                    c := g_VimEngine.ActionList[action].Comment
                    if (c != "")
                        desc := c
                }
                dispKey := RegExReplace(key, "<S-(.*)>", "$1")
                rows.Push(Map("key", dispKey, "rawkey", key, "action", action, "desc", desc))
            }
        }
    }
    g_VimCfg["krows"] := rows
    try g_VimCfg["ke"].Value := ""
    VimCfg_KeyFilter()
}

VimCfg_KeyFilter(*) {
    global g_VimCfg
    if !g_VimCfg.Has("kl")
        return
    lv := g_VimCfg["kl"]
    needle := ""
    try needle := Trim(g_VimCfg["ke"].Value)
    try lv.Delete()
    for item in g_VimCfg["krows"] {
        text := item["key"] " " item["action"] " " item["desc"]
        if (needle = "" || InStr(text, needle)) {
            try lv.Add("", item["key"], item["action"], item["desc"])
        }
    }
}

VimCfg_KeySelected() {
    global g_VimCfg
    lv := g_VimCfg["kl"]
    row := 0
    try row := lv.GetNext(0, "F")
    if (row < 1)
        return ""
    key := ""
    try key := lv.GetText(row, 1)
    for item in g_VimCfg["krows"] {
        if (item["key"] = key)
            return item
    }
    return ""
}

VimCfg_KeyAdd(*) {
    VimCfg_KeyDialog(true, Map("key", "", "rawkey", "", "action", "", "desc", ""))
}

VimCfg_KeyEdit(*) {
    item := VimCfg_KeySelected()
    if (item = "")
        return
    VimCfg_KeyDialog(false, item)
}

VimCfg_KeyDblEdit(*) {
    item := VimCfg_KeySelected()
    if (item = "")
        return
    VimCfg_KeyDialog(false, item)
}

VimCfg_KeyDel(*) {
    global g_VimCfg, g_Conf
    item := VimCfg_KeySelected()
    if (item = "")
        return
    wname := g_VimCfg["kwin"]
    if (MsgBox(T("cfg.keys_del_confirm", item["key"]), T("cfg.title"), "YesNo") != "Yes")
        return
    VimCfg_MarkDirty(wname, item["rawkey"], "", true)
    ToolTip(T("cfg.keys_marked_deleted"))
    SetTimer(RemoveToolTip, -1200)
}

; 通用键值对话框 (按键页: 带模式行; 热键页: 隐藏模式行)
VimCfg_KeyDialog(isNew, item, withMode := true) {
    global g_VimCfg
    if (g_VimCfg.Has("dlg")) {
        try {
            g_VimCfg["dlg"].Destroy()
        } catch {
        }
    }
    d := Gui("+Owner" g_VimCfg["gui"].Hwnd, isNew ? T("cfg.dlg_add_mapping") : T("cfg.dlg_edit_mapping"))
    d.SetFont("s10", "Microsoft YaHei")
    d.Add("Text", "x15 y15 w60", T("cfg.dlg_key"))
    dek := d.Add("Edit", "x85 y12 w250 h25", item["key"])
    d.Add("Text", "x15 y50 w60", T("cfg.dlg_action"))
    dea := d.Add("Edit", "x85 y47 w250 h25", item["action"])
    dem := ""
    y := 82
    if (withMode) {
        d.Add("Text", "x15 y85 w60", T("cfg.dlg_mode"))
        dem := d.Add("Edit", "x85 y82 w250 h25", g_VimCfg.Has("kmode") ? g_VimCfg["kmode"] : "normal")
        y := 117
    }
    d.Add("Button", "x85 y" y " w80 Default", T("cfg.dlg_ok")).OnEvent("Click", VimCfg_KeyDialogOK)
    d.Add("Button", "x+10 w80", T("cfg.dlg_cancel")).OnEvent("Click", VimCfg_KeyDialogCancel)
    g_VimCfg["dlg"] := d
    g_VimCfg["dlgNew"] := isNew
    g_VimCfg["dlgKey"] := dek
    g_VimCfg["dlgAct"] := dea
    g_VimCfg["dlgMode"] := dem
    g_VimCfg["dlgItem"] := item
    g_VimCfg["dlgWithMode"] := withMode
    d.Show("w350 h" (y + 45))
}

VimCfg_KeyDialogCancel(*) {
    global g_VimCfg
    try g_VimCfg["dlg"].Destroy()
    g_VimCfg.Delete("dlg")
}

VimCfg_KeyDialogOK(*) {
    global g_VimCfg
    key := Trim(g_VimCfg["dlgKey"].Value)
    action := Trim(g_VimCfg["dlgAct"].Value)
    if (key = "" || action = "") {
        MsgBox(T("cfg.dlg_empty"), T("cfg.title"), 16)
        return
    }
    if (g_VimCfg["dlgWithMode"]) {
        wname := g_VimCfg["kwin"]
        mode := Trim(g_VimCfg["dlgMode"].Value)
        if (mode = "")
            mode := "normal"
        if (mode != "normal")
            action .= "[=" mode "]"
        VimCfg_MarkDirty(wname, key, action)
    } else {
        sec := g_VimCfg["kvsec"]
        VimCfg_MarkDirty(sec, key, action)
        VimCfg_KvReload(sec)
    }
    try g_VimCfg["dlg"].Destroy()
    g_VimCfg.Delete("dlg")
    ToolTip(T("cfg.dlg_staged"))
    SetTimer(RemoveToolTip, -1200)
}

; ==================== 键值对页 (全局热键 / Hotkey) ====================
VimCfg_BuildKvTab(g, sec, tag) {
    global g_VimCfg
    g.Add("GroupBox", "x10 y40 w860 h400", (sec = "GlobalHotkey" ? T("cfg.kv_global_title") : T("cfg.kv_hotkey_title")))
    lv := g.Add("ListView", "x20 y65 w840 h330 grid", [T("cfg.kv_col_hotkey"), T("cfg.kv_col_action")])
    lv.ModifyCol(1, 220)
    lv.ModifyCol(2, 600)
    g.Add("Button", "x20 y410 w70", T("cfg.kv_add")).OnEvent("Click", VimCfg_KvAdd)
    g.Add("Button", "x+10 w70", T("cfg.kv_edit")).OnEvent("Click", VimCfg_KvEdit)
    g.Add("Button", "x+10 w70", T("cfg.kv_delete")).OnEvent("Click", VimCfg_KvDel)
    g.Add("Text", "x560 y414 w60", T("cfg.kv_filter"))
    kved := g.Add("Edit", "x625 y410 w235 h25")
    kved.OnEvent("Change", VimCfg_KvFilter)
    g_VimCfg["kv_" tag] := lv
    g_VimCfg["kvrows_" tag] := []
    g_VimCfg["kvfilter_" tag] := kved
    lv.OnEvent("DoubleClick", VimCfg_KvDblEdit)
    VimCfg_KvReload(sec)
}

VimCfg_KvFilter(*) {
    VimCfg_KvReload()
}

VimCfg_KvTag() {
    global g_VimCfg
    tabs := g_VimCfg["tabs"]
    idx := 0
    try idx := tabs.Value
    return idx = 2 ? "gh" : "hh"
}

VimCfg_KvSec(tag := "") {
    if (tag = "")
        tag := VimCfg_KvTag()
    return tag = "gh" ? "GlobalHotkey" : "Hotkey"
}

VimCfg_KvReload(sec := "") {
    global g_VimCfg, g_Conf
    if (sec = "")
        sec := VimCfg_KvSec()
    tag := sec = "GlobalHotkey" ? "gh" : "hh"
    if !g_VimCfg.Has("kv_" tag)
        return
    lv := g_VimCfg["kv_" tag]
    rows := []
    if IsObject(g_Conf) {
        for k, v in g_Conf.GetSection(sec)
            rows.Push(Map("key", k, "action", v))
    }
    ; 叠加未保存的脏数据 (先收集删除, 再统一过滤, 避免遍历中修改)
    delKeys := Map()
    for sk, d in g_VimCfg["dirty"] {
        pos := InStr(sk, Chr(1))
        if (SubStr(sk, 1, pos - 1) != sec)
            continue
        if (d["del"]) {
            delKeys[d["key"]] := true
            continue
        }
        found := false
        for r in rows {
            if (r["key"] = d["key"]) {
                r["action"] := d["val"]
                found := true
                break
            }
        }
        if (!found)
            rows.Push(Map("key", d["key"], "action", d["val"]))
    }
    kept := []
    for r in rows {
        if (!delKeys.Has(r["key"]))
            kept.Push(r)
    }
    rows := kept
    g_VimCfg["kvrows_" tag] := rows
    needle := ""
    try needle := Trim(g_VimCfg["kvfilter_" tag].Value)
    try lv.Delete()
    for r in rows {
        if (needle = "" || InStr(r["key"] " " r["action"], needle)) {
            try lv.Add("", r["key"], r["action"])
        }
    }
}

VimCfg_KvSelected() {
    tag := VimCfg_KvTag()
    global g_VimCfg
    lv := g_VimCfg["kv_" tag]
    row := 0
    try row := lv.GetNext(0, "F")
    if (row < 1)
        return ""
    key := ""
    try key := lv.GetText(row, 1)
    for r in g_VimCfg["kvrows_" tag] {
        if (r["key"] = key)
            return r
    }
    return ""
}

VimCfg_KvAdd(*) {
    global g_VimCfg
    g_VimCfg["kvsec"] := VimCfg_KvSec()
    VimCfg_KeyDialog(true, Map("key", "", "rawkey", "", "action", "", "desc", ""), false)
}

VimCfg_KvEdit(*) {
    global g_VimCfg
    r := VimCfg_KvSelected()
    if (r = "")
        return
    g_VimCfg["kvsec"] := VimCfg_KvSec()
    VimCfg_KeyDialog(false, Map("key", r["key"], "rawkey", r["key"], "action", r["action"], "desc", ""), false)
}

VimCfg_KvDblEdit(*) {
    VimCfg_KvEdit()
}

VimCfg_KvDel(*) {
    global g_VimCfg
    r := VimCfg_KvSelected()
    if (r = "")
        return
    if (MsgBox(T("cfg.kv_del_confirm", r["key"]), T("cfg.title"), "YesNo") != "Yes")
        return
    VimCfg_MarkDirty(VimCfg_KvSec(), r["key"], "", true)
    VimCfg_KvReload(VimCfg_KvSec())
}

; ==================== 插件页 ====================
VimCfg_BuildPluginTab(g) {
    global g_VimCfg
    g.Add("GroupBox", "x10 y40 w860 h400", T("cfg.plugin_title"))
    lv := g.Add("ListView", "x20 y65 w840 h330 grid", [T("cfg.plugin_col_name"), T("cfg.plugin_col_status")])
    lv.ModifyCol(1, 300)
    lv.ModifyCol(2, 520)
    g.Add("Button", "x20 y410 w110", T("cfg.plugin_toggle")).OnEvent("Click", VimCfg_PluginToggle)
    g.Add("Button", "x+10 w110", T("cfg.plugin_restart")).OnEvent("Click", VimCfg_PluginRestart)
    g.Add("Text", "x560 y414 w60", T("cfg.plugin_filter"))
    pluged := g.Add("Edit", "x625 y410 w235 h25")
    pluged.OnEvent("Change", VimCfg_PluginFilter)
    g_VimCfg["plug"] := lv
    g_VimCfg["plugrows"] := []
    g_VimCfg["plugfilter"] := pluged
    lv.OnEvent("DoubleClick", VimCfg_PluginToggle)
    VimCfg_PluginReload()
}

VimCfg_PluginFilter(*) {
    VimCfg_PluginReload()
}

VimCfg_PluginReload() {
    global g_VimCfg, g_Conf
    if !g_VimCfg.Has("plug")
        return
    lv := g_VimCfg["plug"]
    rows := []
    if IsObject(g_Conf) {
        seen := Map()
        Loop Files, A_ScriptDir "\Plugins\*.ahk" {
            SplitPath(A_LoopFileName, , , , &pname)
            if (pname = "" || seen.Has(pname))
                continue
            seen[pname] := true
            on := g_Conf.Get("Plugins", pname, "1") != "0"
            rows.Push(Map("key", pname, "on", on))
        }
        for k, v in g_Conf.GetSection("Plugins") {
            if (!seen.Has(k)) {
                seen[k] := true
                rows.Push(Map("key", k, "on", v != "0"))
            }
        }
    }
    for sk, d in g_VimCfg["dirty"] {
        pos := InStr(sk, Chr(1))
        if (SubStr(sk, 1, pos - 1) != "Plugins")
            continue
        for r in rows {
            if (r["key"] = d["key"]) {
                if (!d["del"])
                    r["on"] := d["val"] != "0"
                break
            }
        }
    }
    g_VimCfg["plugrows"] := rows
    needle := ""
    try needle := Trim(g_VimCfg["plugfilter"].Value)
    try lv.Delete()
    for r in rows {
        if (needle = "" || InStr(r["key"], needle)) {
            try lv.Add("", r["key"], r["on"] ? T("cfg.plugin_on") : T("cfg.plugin_off"))
        }
    }
}

VimCfg_PluginToggle(*) {
    global g_VimCfg
    lv := g_VimCfg["plug"]
    row := 0
    try row := lv.GetNext(0, "F")
    if (row < 1)
        return
    key := ""
    try key := lv.GetText(row, 1)
    for r in g_VimCfg["plugrows"] {
        if (r["key"] = key) {
            r["on"] := !r["on"]
            VimCfg_MarkDirty("Plugins", key, r["on"] ? "1" : "0")
            break
        }
    }
    VimCfg_PluginReload()
    VimCfg_RefreshWarnBar()
}

VimCfg_PluginRestart(*) {
    RestartRunZ()
}

VimCfg_CollectPluginTab() {
    ; 插件页实时写入 dirty, 无需收集
}

; ==================== TC 设置页 ====================
VimCfg_BuildTCTab(g) {
    global g_VimCfg
    g.Add("GroupBox", "x10 y40 w860 h400", T("cfg.tc_title"))
    g.Add("Text", "x25 y75 w110", T("cfg.tc_path"))
    ed1 := g.Add("Edit", "x140 y72 w560 h25")
    g.Add("Button", "x+10 w80", T("cfg.tc_browse")).OnEvent("Click", VimCfg_TCBrowsePath)
    g.Add("Text", "x25 y115 w110", T("cfg.tc_ini"))
    ed2 := g.Add("Edit", "x140 y112 w560 h25")
    g.Add("Button", "x+10 w80", T("cfg.tc_browse")).OnEvent("Click", VimCfg_TCBrowseIni)
    cb1 := g.Add("CheckBox", "x25 y155", T("cfg.tc_savemark"))
    g.Add("Text", "x25 y190 w110", T("cfg.tc_iconsize"))
    ed3 := g.Add("Edit", "x140 y187 w80 h25")
    cb2 := g.Add("CheckBox", "x25 y225", T("cfg.tc_asdlg"))
    g.Add("Text", "x25 y260 w150", T("cfg.tc_exclude"))
    ed4 := g.Add("Edit", "x25 y285 w675 h25")
    g.Add("Text", "x25 y330 w675", T("cfg.tc_note"))
    g_VimCfg["tc_path"] := ed1
    g_VimCfg["tc_ini"] := ed2
    g_VimCfg["tc_savemark"] := cb1
    g_VimCfg["tc_iconsize"] := ed3
    g_VimCfg["tc_asdlg"] := cb2
    g_VimCfg["tc_exclude"] := ed4
    VimCfg_TCLoad()
}

VimCfg_TCLoad() {
    global g_VimCfg, g_Conf
    if !g_VimCfg.Has("tc_path") || !IsObject(g_Conf)
        return
    tcPath := g_Conf.Get("TotalCommander_Config", "TCPath", "")
    if (tcPath = "")
        tcPath := g_Conf.Get("Config", "TCPath", "")
    try g_VimCfg["tc_path"].Value := tcPath
    try g_VimCfg["tc_ini"].Value := g_Conf.Get("TotalCommander_Config", "TCINI", "")
    try g_VimCfg["tc_savemark"].Value := g_Conf.Get("TotalCommander_Config", "SaveMark", "1") = "1" ? 1 : 0
    try g_VimCfg["tc_iconsize"].Value := g_Conf.Get("TotalCommander_Config", "MenuIconSize", "20")
    try g_VimCfg["tc_asdlg"].Value := g_Conf.Get("TotalCommander_Config", "AsOpenFileDialog", "0") = "1" ? 1 : 0
    try g_VimCfg["tc_exclude"].Value := g_Conf.Get("TotalCommander_Config", "OpenFileDialogExclude", "")
}

VimCfg_TCBrowsePath(*) {
    global g_VimCfg
    try {
        p := FileSelect(3, , T("cfg.tc_pick_exe"), T("cfg.tc_pick_exe_filter"))
        if (p != "")
            g_VimCfg["tc_path"].Value := p
    }
}

VimCfg_TCBrowseIni(*) {
    global g_VimCfg
    try {
        p := FileSelect(3, , T("cfg.tc_pick_ini"), T("cfg.tc_pick_ini_filter"))
        if (p != "")
            g_VimCfg["tc_ini"].Value := p
    }
}

VimCfg_PutDirty(sec, key, val) {
    global g_Conf
    if (g_Conf.Get(sec, key, "") != val)
        VimCfg_MarkDirty(sec, key, val)
}

VimCfg_CollectTCTab() {
    global g_VimCfg, g_Conf
    if !g_VimCfg.Has("tc_path") || !IsObject(g_Conf)
        return
    p := Trim(g_VimCfg["tc_path"].Value)
    if (p != "") {
        VimCfg_PutDirty("TotalCommander_Config", "TCPath", p)
        VimCfg_PutDirty("Config", "TCPath", p)
    }
    VimCfg_PutDirty("TotalCommander_Config", "TCINI", Trim(g_VimCfg["tc_ini"].Value))
    VimCfg_PutDirty("TotalCommander_Config", "SaveMark", g_VimCfg["tc_savemark"].Value ? "1" : "0")
    VimCfg_PutDirty("TotalCommander_Config", "MenuIconSize", Trim(g_VimCfg["tc_iconsize"].Value))
    VimCfg_PutDirty("TotalCommander_Config", "AsOpenFileDialog", g_VimCfg["tc_asdlg"].Value ? "1" : "0")
    VimCfg_PutDirty("TotalCommander_Config", "OpenFileDialogExclude", Trim(g_VimCfg["tc_exclude"].Value))
}

; ==================== 启动器页 ====================
VimCfg_LauncherSpecs() {
    return [
        Map("sec", "Config", "key", "SearchFileDir", "label", T("cfg.opt_searchdir"), "type", "text"),
        Map("sec", "Config", "key", "SearchFileType", "label", T("cfg.opt_searchtype"), "type", "text"),
        Map("sec", "Config", "key", "SearchFileExclude", "label", T("cfg.opt_exclude"), "type", "text"),
        Map("sec", "Config", "key", "TCMatchPath", "label", T("cfg.opt_tcmatch"), "type", "text"),
        Map("sec", "Config", "key", "Language", "label", T("cfg.opt_language"), "type", "lang"),
        Map("sec", "Config", "key", "RunInBackground", "label", T("cfg.opt_bg"), "type", "bool"),
        Map("sec", "Config", "key", "ExitIfInactivate", "label", T("cfg.opt_exitblur"), "type", "bool"),
        Map("sec", "Config", "key", "WindowAlwaysOnTop", "label", T("cfg.opt_topmost"), "type", "bool"),
        Map("sec", "Config", "key", "SaveHistory", "label", T("cfg.opt_history"), "type", "bool"),
        Map("sec", "Config", "key", "HistorySize", "label", T("cfg.opt_historysize"), "type", "int"),
        Map("sec", "Config", "key", "AutoRank", "label", T("cfg.opt_autorank"), "type", "bool"),
        Map("sec", "Config", "key", "ClickToRun", "label", T("cfg.opt_clicktorun"), "type", "bool"),
        Map("sec", "Config", "key", "KeepInputText", "label", T("cfg.opt_keepinput"), "type", "bool"),
        Map("sec", "Config", "key", "RunOnce", "label", T("cfg.opt_runonce"), "type", "bool"),
        Map("sec", "Config", "key", "RunIfOnlyOne", "label", T("cfg.opt_runifone"), "type", "bool"),
        Map("sec", "Config", "key", "SwitchToEngIME", "label", T("cfg.opt_engime"), "type", "bool"),
        Map("sec", "Config", "key", "DebugMode", "label", T("cfg.opt_debug"), "type", "bool"),
        Map("sec", "Gui", "key", "Skin", "label", T("cfg.opt_skin"), "type", "skin"),
        Map("sec", "Gui", "key", "HideTitle", "label", T("cfg.opt_hidetitle"), "type", "bool"),
        Map("sec", "Gui", "key", "ShowTrayIcon", "label", T("cfg.opt_tray"), "type", "bool"),
        Map("sec", "Gui", "key", "ShowCurrentCommand", "label", T("cfg.opt_showcmd"), "type", "bool"),
        Map("sec", "Gui", "key", "DisplayRows", "label", T("cfg.opt_rows"), "type", "int"),
        Map("sec", "Gui", "key", "WidgetWidth", "label", T("cfg.opt_width"), "type", "int"),
        Map("sec", "Gui", "key", "FontName", "label", T("cfg.opt_font"), "type", "text"),
        Map("sec", "Gui", "key", "FontSize", "label", T("cfg.opt_fontsize"), "type", "int"),
        Map("sec", "Gui", "key", "FontColor", "label", T("cfg.opt_fontcolor"), "type", "text"),
        Map("sec", "Gui", "key", "BackgroundColor", "label", T("cfg.opt_bgcolor"), "type", "text"),
        Map("sec", "Gui", "key", "EditColor", "label", T("cfg.opt_editcolor"), "type", "text")
    ]
}

; ==================== 雷达页 (独立 tab: 启动器页 35 项已爆框, 雷达 9 项搬出来) ====================
VimCfg_StatsBallSpecs() {
    return [
        Map("sec", "StatsBall", "key", "Enable", "label", T("cfg.opt_statsball_enable"), "type", "bool"),
        Map("sec", "StatsBall", "key", "RefreshMs", "label", T("cfg.opt_statsball_refresh"), "type", "slider", "min", 500, "max", 5000),
        Map("sec", "StatsBall", "key", "StripW", "label", T("cfg.opt_statsball_stripw"), "type", "slider", "min", 120, "max", 480),
        Map("sec", "StatsBall", "key", "StripH", "label", T("cfg.opt_statsball_striph"), "type", "slider", "min", 32, "max", 80),
        Map("sec", "StatsBall", "key", "Opacity", "label", T("cfg.opt_statsball_opacity"), "type", "slider", "min", 80, "max", 255),
        Map("sec", "StatsBall", "key", "TopMost", "label", T("cfg.opt_statsball_topmost"), "type", "bool"),
        Map("sec", "StatsBall", "key", "LockPos", "label", T("cfg.opt_statsball_lock"), "type", "bool"),
        Map("sec", "StatsBall", "key", "SnapEdge", "label", T("cfg.opt_statsball_snap"), "type", "bool"),
        Map("sec", "StatsBall", "key", "AlertThreshold", "label", T("cfg.opt_statsball_alert"), "type", "slider", "min", 50, "max", 100)
    ]
}

VimCfg_BuildStatsBallTab(g) {
    VimCfg_BuildSpecsTab(g, T("cfg.statsball_title"), VimCfg_StatsBallSpecs(), "sbspecs")
}

VimCfg_CollectStatsBallTab() {
    VimCfg_CollectSpecsTab("sbspecs")
}

; 通用 specs 双列表 (启动器/雷达共用; storeKey = g_VimCfg 存储键)
; rowH 行距: 启动器 28 项用 26 压进框, 雷达 12 项用默认 32
VimCfg_BuildSpecsTab(g, title, specs, storeKey, rowH := 32) {
    global g_VimCfg, g_Conf
    g.Add("GroupBox", "x10 y40 w860 h400", title)
    x := 25
    y := 70
    col := 0
    for i, sp in specs {
        if (col = 0)
            x := 25
        else
            x := 450
        cur := ""
        if IsObject(g_Conf)
            cur := g_Conf.Get(sp["sec"], sp["key"], "")
        if (sp["type"] = "bool") {
            ctl := g.Add("CheckBox", "x" x " y" y " w400", sp["label"])
            try ctl.Value := cur = "1" ? 1 : 0
        } else if (sp["type"] = "lang") {
            g.Add("Text", "x" x " y" y + 3 " w120", sp["label"])
            names := []
            curName := ""
            for l in I18nAvailable() {
                dn := I18nDisplayName(l)
                names.Push(dn)
                if (l = cur || (cur = "auto" && l = I18nGetLang()))
                    curName := dn
            }
            if (curName = "" && names.Length > 0)
                curName := names[1]
            ctl := g.Add("DropDownList", "x" x + 130 " y" y " w270", names)
            try ctl.Text := curName
        } else if (sp["type"] = "skin") {
            g.Add("Text", "x" x " y" y + 3 " w120", sp["label"])
            names := [cur]
            Loop Files, A_ScriptDir "\Conf\Skins\*.ini" {
                SplitPath(A_LoopFileName, , , , &sn)
                if (sn != "" && sn != cur)
                    names.Push(sn)
            }
            ctl := g.Add("DropDownList", "x" x + 130 " y" y " w270", names)
            try ctl.Choose(1)
        } else if (sp["type"] = "choice") {
            g.Add("Text", "x" x " y" y + 3 " w150", sp["label"])
            opts := sp.Has("options") ? sp["options"] : []
            ctl := g.Add("DropDownList", "x" x + 160 " y" y " w240", opts)
            try {
                curStr := String(cur)
                picked := false
                for i, o in opts {
                    if (String(o) = curStr) {
                        ctl.Choose(i)
                        picked := true
                        break
                    }
                }
                if (!picked && opts.Length > 0)
                    ctl.Choose(1)
            }
        } else if (sp["type"] = "slider") {
            g.Add("Text", "x" x " y" y + 3 " w150", sp["label"])
            lo := sp.Has("min") ? sp["min"] : 0
            hi := sp.Has("max") ? sp["max"] : 100
            ctl := g.Add("Slider", "x" x + 160 " y" y " w190 h25 Range" lo "-" hi, Integer(cur ? cur : lo))
            buddy := g.Add("Text", "x" x + 355 " y" y + 3 " w45", String(ctl.Value))
            ctl.OnEvent("Change", VimCfg_SliderSync(ctl, buddy))
            sp["buddy"] := buddy
        } else {
            g.Add("Text", "x" x " y" y + 3 " w150", sp["label"])
            ctl := g.Add("Edit", "x" x + 160 " y" y " w240 h25")
            try ctl.Value := cur
        }
        sp["ctl"] := ctl
        ; 用户改动即记 dirty (插件页早已如此): 勾选立刻进未保存计数,
        ; 改回去自动销账; 关窗确认与保存都依赖它. lang/skin 走保存时特殊逻辑, 不绑
        ; 注意 v2 CheckBox 没有 Change 事件 (只有 Click), 绑错直接抛错
        if (sp["type"] = "bool")
            ctl.OnEvent("Click", VimCfg_SpecChangeBind(sp))
        else if (sp["type"] = "choice" || sp["type"] = "slider" || sp["type"] = "text" || sp["type"] = "int")
            ctl.OnEvent("Change", VimCfg_SpecChangeBind(sp))
        if (col = 1) {
            y += rowH
            col := 0
        } else {
            col := 1
        }
    }
    g_VimCfg[storeKey] := specs
}

VimCfg_BuildLauncherTab(g) {
    VimCfg_BuildSpecsTab(g, T("cfg.launcher_title"), VimCfg_LauncherSpecs(), "lspecs", 26)
}

; 滑块数值联动工厂 (每次调用自带局部量, 避开循环闭包共享变量坑)
VimCfg_SliderSync(ctl, buddy) {
    return (*) => (buddy.Text := ctl.Value)
}

; specs 改动事件工厂 (同上, 闭包捕获当轮 sp)
VimCfg_SpecChangeBind(sp) {
    return (*) => VimCfg_SpecChanged(sp)
}

; specs 控件用户改动即记 dirty, 改回原值自动销账, 警告条实时计数
VimCfg_SpecChanged(sp) {
    global g_VimCfg, g_Conf
    if (!IsObject(g_Conf) || !g_VimCfg.Has("dirty"))
        return
    ctl := sp["ctl"]
    val := ""
    try {
        if (sp["type"] = "bool")
            val := ctl.Value ? "1" : "0"
        else if (sp["type"] = "choice")
            val := ctl.Text
        else if (sp["type"] = "slider")
            val := String(Integer(ctl.Value))
        else
            val := Trim(ctl.Value)
    } catch {
        return
    }
    sk := sp["sec"] . Chr(1) . sp["key"]
    if (g_Conf.Get(sp["sec"], sp["key"], "") != val)
        VimCfg_MarkDirty(sp["sec"], sp["key"], val)
    else if (g_VimCfg["dirty"].Has(sk))
        g_VimCfg["dirty"].Delete(sk)
    VimCfg_RefreshWarnBar()
}

VimCfg_CollectSpecsTab(storeKey) {
    global g_VimCfg, g_Conf
    if !g_VimCfg.Has(storeKey) || !IsObject(g_Conf)
        return
    for sp in g_VimCfg[storeKey] {
        ctl := sp["ctl"]
        val := ""
        if (sp["type"] = "bool") {
            val := ctl.Value ? "1" : "0"
        } else if (sp["type"] = "lang") {
            sel := ""
            try sel := ctl.Text
            for l in I18nAvailable() {
                if (I18nDisplayName(l) = sel) {
                    val := l
                    break
                }
            }
            ; auto 保持: ini 里是 auto 且用户没换选项时不误写成具体语言
            if (g_Conf.Get(sp["sec"], sp["key"], "") = "auto") {
                curDn := ""
                for l in I18nAvailable() {
                    if (l = I18nGetLang())
                        curDn := I18nDisplayName(l)
                }
                try {
                    if (ctl.Text = curDn)
                        val := "auto"
                } catch {
                }
            }
            if (val = "")
                val := g_Conf.Get(sp["sec"], sp["key"], "auto")
        } else if (sp["type"] = "skin") {
            try val := ctl.Text
        } else if (sp["type"] = "choice") {
            try val := ctl.Text
        } else if (sp["type"] = "slider") {
            try val := String(Integer(ctl.Value))
        } else {
            try val := Trim(ctl.Value)
        }
        if (g_Conf.Get(sp["sec"], sp["key"], "") != val)
            VimCfg_MarkDirty(sp["sec"], sp["key"], val)
    }
}

VimCfg_CollectLauncherTab() {
    VimCfg_CollectSpecsTab("lspecs")
}

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
    global g_BuildTag
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
    g.Add("GroupBox", "x10 y40 w860 h400", T("cfg.help_title"))
    ed := g.Add("Edit", "x20 y65 w840 h365 ReadOnly -VScroll")
    try ed.Value := txt
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
    global g_Conf
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
    } catch {
    }
    for w in list
        txt .= (w["level"] = "warn" ? "⚠ " : "ℹ ") w["text"] "`n"
    if (txt = "")
        txt := T("cfg.warn_ok")
    try g_VimCfg["warnbar"].Value := RTrim(txt, "`n")
}
