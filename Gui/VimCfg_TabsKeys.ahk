#Requires AutoHotkey v2.0
#Warn All, Off

; === VimCfg_TabsKeys - 配置中心页: 按键/键值/插件/TC ===
; 入口见 VimConfigUI.ahk, 加载顺序见 Rim.ahk
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
; key 行: 手打 + 捕获按钮 (InputHook 抓一次真实按键, 经引擎归一);
; action 行: ComboBox (注册表动作可选、手打兼容); mode 行: ComboBox (normal/insert/search + 手打兼容)
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
    dek := d.Add("Edit", "x85 y12 w170 h25", item["key"])
    d.Add("Button", "x265 y12 w90", T("cfg.dlg_capture")).OnEvent("Click", VimCfg_KeyCapture)
    d.Add("Text", "x15 y50 w60", T("cfg.dlg_action"))
    dea := d.Add("ComboBox", "x85 y47 w270 h25", VimCfg_ActionNames())
    try dea.Text := item["action"]
    catch {
    }
    dem := ""
    y := 82
    if (withMode) {
        d.Add("Text", "x15 y85 w60", T("cfg.dlg_mode"))
        curMode := g_VimCfg.Has("kmode") ? g_VimCfg["kmode"] : "normal"
        dem := d.Add("ComboBox", "x85 y82 w270 h25", ["normal", "insert", "search"])
        try dem.Text := curMode
        catch {
        }
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
    d.Show("w370 h" (y + 45))
}

; 动作候选: 引擎 ActionList (+ 中文注释) 并 RimCommand 注册 id, 排序截断 500
VimCfg_ActionNames() {
    global g_VimEngine
    names := []
    seen := Map()
    try {
        if (IsSet(g_VimEngine) && IsObject(g_VimEngine)) {
            for actName, _act in g_VimEngine.ActionList {
                if (!seen.Has(actName)) {
                    seen[actName] := true
                    names.Push(actName)
                }
            }
        }
    }
    try {
        for cmdId, _cmd in RimCommand.Registry {
            if (!seen.Has(cmdId)) {
                seen[cmdId] := true
                names.Push(cmdId)
            }
        }
    }
    ; 简单插入排序 (量小, 避免引入依赖)
    i := 2
    while (i <= names.Length) {
        entry := names[i]
        j := i - 1
        while (j >= 1 && names[j] > entry) {
            names[j + 1] := names[j]
            j--
        }
        names[j + 1] := entry
        i++
    }
    if (names.Length > 500)
        names := VimCfg_Slice(names, 500)
    return names
}

VimCfg_Slice(arr, cap) {
    out := []
    for v in arr {
        out.Push(v)
        if (out.Length >= cap)
            break
    }
    return out
}

; 按键捕获: InputHook 抓一次真实按键 (+ 修饰键状态), 经引擎归一成 vim 串回填
VimCfg_KeyCapture(*) {
    global g_VimCfg, g_VimEngine
    if (!g_VimCfg.Has("dlgKey"))
        return
    dek := g_VimCfg["dlgKey"]
    oldText := ""
    try oldText := dek.Text
    try dek.Text := T("cfg.capture_prompt")
    try {
        ih := InputHook("M L1 T5")
        ih.Start()
        ih.Wait()
        if (ih.EndReason = "Timeout" || ih.EndKey = "Escape") {
            dek.Text := oldText
            ToolTip(T("cfg.capture_timeout"))
            SetTimer(RemoveToolTip, -1200)
            return
        }
        mods := ""
        if GetKeyState("Ctrl", "P")
            mods .= "^"
        if GetKeyState("Alt", "P")
            mods .= "!"
        if GetKeyState("Shift", "P")
            mods .= "+"
        ahkKey := mods . ih.EndKey
        vimKey := ahkKey
        try {
            if (IsSet(g_VimEngine) && IsObject(g_VimEngine))
                vimKey := NormalizeVimKey(g_VimEngine.Convert2VIM(ahkKey))
        }
        dek.Text := vimKey
    } catch {
        try dek.Text := oldText
    }
}

VimCfg_KeyDialogCancel(*) {
    global g_VimCfg
    try g_VimCfg["dlg"].Destroy()
    g_VimCfg.Delete("dlg")
}

VimCfg_KeyDialogOK(*) {
    global g_VimCfg, g_VimEngine
    key := ""
    action := ""
    try key := Trim(g_VimCfg["dlgKey"].Text)
    try action := Trim(g_VimCfg["dlgAct"].Text)
    if (key = "" || action = "") {
        MsgBox(T("cfg.dlg_empty"), T("cfg.title"), 16)
        return
    }
    if (InStr(key, " ") || InStr(key, "`t")) {
        MsgBox(T("cfg.val_pattern", key, "no-spaces"), T("cfg.title"), 16)
        return
    }
    if (g_VimCfg["dlgWithMode"]) {
        wname := g_VimCfg["kwin"]
        mode := "normal"
        try mode := Trim(g_VimCfg["dlgMode"].Text)
        if (mode = "")
            mode := "normal"
        ; 重复与合法性: 只说不拦 (覆盖本就是 ini 语义; 自定义动作可能后注册)
        try {
            if (IsSet(g_VimEngine) && IsObject(g_VimEngine)) {
                win := g_VimEngine.GetWin(wname)
                if (IsObject(win) && win.modeList.Has(mode)) {
                    modeObj := win.modeList[mode]
                    if (modeObj.keymapList.Has(key)) {
                        oldAct := modeObj.keymapList[key]
                        if (MsgBox(T("cfg.dup_key", key, oldAct), T("cfg.title"), "YesNo") != "Yes")
                            return
                    }
                }
                if (!g_VimEngine.IsValidAction(action)) {
                    if (MsgBox(T("cfg.bad_action", action), T("cfg.title"), "YesNo") != "Yes")
                        return
                }
            }
        }
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
            on := CfgGet("Plugins", pname, "1") != "0"
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
    RestartRim()
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
    tcPath := CfgGet("TotalCommander_Config", "TCPath", "")
    if (tcPath = "")
        tcPath := CfgGet("Config", "TCPath", "")
    try g_VimCfg["tc_path"].Value := tcPath
    try g_VimCfg["tc_ini"].Value := CfgGet("TotalCommander_Config", "TCINI", "")
    try g_VimCfg["tc_savemark"].Value := CfgGet("TotalCommander_Config", "SaveMark", "1") = "1" ? 1 : 0
    try g_VimCfg["tc_iconsize"].Value := CfgGet("TotalCommander_Config", "MenuIconSize", "20")
    try g_VimCfg["tc_asdlg"].Value := CfgGet("TotalCommander_Config", "AsOpenFileDialog", "0") = "1" ? 1 : 0
    try g_VimCfg["tc_exclude"].Value := CfgGet("TotalCommander_Config", "OpenFileDialogExclude", "")
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
    if (CfgGet(sec, key, "") != val)
        VimCfg_MarkDirty(sec, key, val)
}

VimCfg_CollectTCTab() {
    global g_VimCfg, g_Conf
    if !g_VimCfg.Has("tc_path") || !IsObject(g_Conf)
        return
    ; 路径框允许清空 (PutDirty 相等即 no-op, 空串正常落盘删键不断)
    VimCfg_PutDirty("TotalCommander_Config", "TCPath", Trim(g_VimCfg["tc_path"].Value))
    VimCfg_PutDirty("TotalCommander_Config", "TCINI", Trim(g_VimCfg["tc_ini"].Value))
    VimCfg_PutDirty("TotalCommander_Config", "SaveMark", g_VimCfg["tc_savemark"].Value ? "1" : "0")
    VimCfg_PutDirty("TotalCommander_Config", "MenuIconSize", Trim(g_VimCfg["tc_iconsize"].Value))
    VimCfg_PutDirty("TotalCommander_Config", "AsOpenFileDialog", g_VimCfg["tc_asdlg"].Value ? "1" : "0")
    VimCfg_PutDirty("TotalCommander_Config", "OpenFileDialogExclude", Trim(g_VimCfg["tc_exclude"].Value))
}

