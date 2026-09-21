#Requires AutoHotkey v2.0
#Warn All, Off

; === GestureUI - 手势管理界面 (录入/自定义/增删改查) ===
; 托盘 "手势 &G" 进入. 改动经 GestureStore_* 直写 ini(保注释)并即时生效, 无需重启.
; 录制流程: 点 [录制] -> 到任意窗口按住触发键画一笔松开 -> 手势串自动填入.

global g_GestureMgr := Map()

ShowGestureManager(*) {
    global g_GestureMgr
    try {
        if (g_GestureMgr.Has("gui") && IsObject(g_GestureMgr["gui"])) {
            g_GestureMgr["gui"].Show()
            GestureMgr_RefreshAll()
            return
        }
    }
    mg := Gui(, T("gesture.title"))
    mg.SetFont("S10", "微软雅黑")
    tabs := mg.Add("Tab3", "w800 h430", [T("gesture.tab_gestures"), T("gesture.tab_tpl"), T("gesture.tab_blacklist"), T("gesture.tab_settings")])

    ; ---- 手势页 ----
    ; 注意: "全部"/"全局" 是层存储标识 (ini 键 + Core 过滤比较), 禁止翻译, 保持原文
    tabs.UseTab(1)
    mg.Add("Text", "xm ym+30", T("gesture.layer"))
    filterDdl := mg.Add("DropDownList", "x+6 w180", ["全部"])
    filterDdl.OnEvent("Change", GestureMgr_OnFilter)
    mg.Add("Button", "x+10 w80", T("gesture.btn_record_new")).OnEvent("Click", GestureMgr_OnRecordNew)
    mg.Add("Button", "x+6 w60", T("gesture.btn_add")).OnEvent("Click", GestureMgr_OnAdd)
    mg.Add("Button", "x+6 w60", T("gesture.btn_edit")).OnEvent("Click", GestureMgr_OnEdit)
    mg.Add("Button", "x+6 w60", T("gesture.btn_delete")).OnEvent("Click", GestureMgr_OnDel)
    mg.Add("Button", "x+6 w80", T("gesture.btn_toggle")).OnEvent("Click", GestureMgr_OnToggle)
    mg.Add("Button", "x+6 w80", T("gesture.btn_layer_off")).OnEvent("Click", GestureMgr_OnLayerOff)
    lv := mg.Add("ListView", "xm y+8 w640 h300", [T("gesture.col_layer"), T("gesture.col_gesture"), T("gesture.col_action"), T("gesture.col_desc"), T("gesture.col_status")])
    lv.ModifyCol(1, 90)
    lv.ModifyCol(2, 90)
    lv.ModifyCol(3, 230)
    lv.ModifyCol(4, 140)
    lv.ModifyCol(5, 50)
    try lv.OnEvent("DoubleClick", GestureMgr_OnEdit)
    catch {
    }
    try lv.OnEvent("ItemFocus", GestureMgr_OnPreview)
    catch {
    }
    prevPic := mg.Add("Picture", "x+10 yp w120 h120 +Border +0xE")
    prevTx := mg.Add("Text", "xp y+4 w120 Center", T("gesture.no_selection"))

    ; ---- 字母模板页 ----
    tabs.UseTab(2)
    mg.Add("Text", "xm ym+30 w640", T("gesture.tpl_note"))
    tplLv := mg.Add("ListView", "xm y+8 w640 h300", [T("gesture.col_tpl"), T("gesture.col_action"), T("gesture.col_source"), T("gesture.col_status")])
    tplLv.ModifyCol(1, 60)
    tplLv.ModifyCol(2, 480)
    tplLv.ModifyCol(3, 60)
    tplLv.ModifyCol(4, 50)
    try tplLv.OnEvent("ItemFocus", GestureMgr_OnTplPreview)
    catch {
    }
    ; 按钮行紧跟列表 (原先跟在右侧预览小图后面, 会落进列表中间; 预改前布局即如此, 非 i18n 引入)
    mg.Add("Button", "xm y+8 w110", T("gesture.btn_record_tpl")).OnEvent("Click", GestureMgr_OnTplAdd)
    mg.Add("Button", "x+6 w110", T("gesture.btn_edit_action")).OnEvent("Click", GestureMgr_OnTplEdit)
    mg.Add("Button", "x+6 w90", T("gesture.btn_delete")).OnEvent("Click", GestureMgr_OnTplDel)
    mg.Add("Button", "x+6 w80", T("gesture.btn_toggle")).OnEvent("Click", GestureMgr_OnTplToggle)
    mg.Add("Button", "x+6 w80", T("gesture.btn_append_sample")).OnEvent("Click", GestureMgr_OnTplAppend)
    ; 预览图保持右上: 相对列表定位 (显式拼接, 禁止隐式串联)
    tplLv.GetPos(&tplX, &tplY)
    tplPic := mg.Add("Picture", "x" . (tplX + 650) . " y" . tplY . " w120 h120 +Border +0xE")
    tplTx := mg.Add("Text", "x" . (tplX + 650) . " y" . (tplY + 124) . " w120 Center", T("gesture.no_selection"))

    ; ---- 黑名单页 ----
    tabs.UseTab(3)
    mg.Add("Text", "xm ym+30 w780", T("gesture.bl_note"))
    blLv := mg.Add("ListView", "xm y+8 w780 h300", [T("gesture.col_pattern"), T("gesture.col_status")])
    blLv.ModifyCol(1, 680)
    blLv.ModifyCol(2, 60)
    mg.Add("Button", "xm y+8 w90", T("gesture.btn_add")).OnEvent("Click", GestureMgr_OnBlAdd)
    mg.Add("Button", "x+6 w90", T("gesture.btn_delete")).OnEvent("Click", GestureMgr_OnBlDel)
    mg.Add("Button", "x+6 w80", T("gesture.btn_toggle")).OnEvent("Click", GestureMgr_OnBlToggle)

    ; ---- 设置页 ----
    tabs.UseTab(4)
    cfgEnable := mg.Add("CheckBox", "xm ym+30", T("gesture.set_enable"))
    mg.Add("Text", "xm y+10", T("gesture.set_trigger"))
    cfgTrigger := mg.Add("DropDownList", "x+6 w120", ["RButton", "MButton", "XButton1", "XButton2"])
    mg.Add("Text", "x+20", T("gesture.set_nomatch"))
    cfgNoMatch := mg.Add("DropDownList", "x+6 w120", ["swallow", "passthrough", "sound"])
    mg.Add("Text", "xm y+12", T("gesture.set_threshold"))
    cfgThreshold := mg.Add("Slider", "x+6 w180 Range10-60", 20)
    cfgThresholdTx := mg.Add("Text", "x+6 w40", "20")
    cfgThreshold.OnEvent("Change", (*) => GestureCfg_ShowVal("Threshold"))
    mg.Add("Text", "xm y+10", T("gesture.set_segment"))
    cfgSegment := mg.Add("Slider", "x+6 w180 Range10-60", 30)
    cfgSegmentTx := mg.Add("Text", "x+6 w40", "30")
    cfgSegment.OnEvent("Change", (*) => GestureCfg_ShowVal("Segment"))
    mg.Add("Text", "xm y+10", T("gesture.set_tplth"))
    cfgTplTh := mg.Add("Slider", "x+6 w180 Range50-95", 75)
    cfgTplThTx := mg.Add("Text", "x+6 w40", "75")
    cfgTplTh.OnEvent("Change", (*) => GestureCfg_ShowVal("TplTh"))
    mg.Add("Text", "xm y+10", T("gesture.set_trailw"))
    cfgTrailW := mg.Add("Slider", "x+6 w180 Range1-10", 5)
    cfgTrailWTx := mg.Add("Text", "x+6 w40", "5")
    cfgTrailW.OnEvent("Change", (*) => GestureCfg_ShowVal("TrailW"))
    mg.Add("Text", "xm y+10", T("gesture.set_ignorekey"))
    cfgIgnoreKey := mg.Add("Edit", "x+6 w100", "")
    cfgOSD := mg.Add("CheckBox", "xm y+12", T("gesture.set_osd"))
    cfgTrail := mg.Add("CheckBox", "x+20", T("gesture.set_trail"))
    cfgOnlyDef := mg.Add("CheckBox", "x+20", T("gesture.set_onlydef"))
    cfgTry := mg.Add("CheckBox", "xm y+10", T("gesture.set_try"))
    cfgTry.OnEvent("Click", (*) => Gesture_SetTryMode(cfgTry.Value ? true : false))
    mg.Add("Button", "xm y+12 w110", T("gesture.btn_save_settings")).OnEvent("Click", GestureCfg_OnSave)
    mg.Add("Text", "x+8 w200", T("gesture.save_hint"))
    mg.Add("Button", "xm y+10 w110", T("gesture.btn_export")).OnEvent("Click", GesturePkg_OnExport)
    mg.Add("Button", "x+8 w110", T("gesture.btn_import")).OnEvent("Click", GesturePkg_OnImport)
    try blLv.OnEvent("DoubleClick", GestureMgr_OnBlDel)
    catch {
    }

    tabs.UseTab()
    status := mg.Add("Text", "xm y+8 w780", T("gesture.status_ready"))
    mg.OnEvent("Close", (*) => mg.Hide())

    g_GestureMgr["gui"] := mg
    g_GestureMgr["tabs"] := tabs
    g_GestureMgr["filter"] := filterDdl
    g_GestureMgr["filterItems"] := ["全部"]
    g_GestureMgr["lv"] := lv
    g_GestureMgr["prevPic"] := prevPic
    g_GestureMgr["prevTx"] := prevTx
    g_GestureMgr["tplLv"] := tplLv
    g_GestureMgr["tplPic"] := tplPic
    g_GestureMgr["tplTx"] := tplTx
    g_GestureMgr["blLv"] := blLv
    g_GestureMgr["cfg"] := Map("enable", cfgEnable, "trigger", cfgTrigger, "noMatch", cfgNoMatch
        , "threshold", cfgThreshold, "thresholdTx", cfgThresholdTx
        , "segment", cfgSegment, "segmentTx", cfgSegmentTx
        , "tplTh", cfgTplTh, "tplThTx", cfgTplThTx
        , "trailW", cfgTrailW, "trailWTx", cfgTrailWTx
        , "ignoreKey", cfgIgnoreKey, "osd", cfgOSD, "trail", cfgTrail, "onlyDef", cfgOnlyDef
        , "tryBox", cfgTry)
    GestureCfg_Load()
    g_GestureMgr["status"] := status
    g_GestureMgr["editGui"] := ""

    GestureMgr_RefreshAll()
    mg.Show()
}

GestureMgr_SetStatus(txt) {
    global g_GestureMgr
    try g_GestureMgr["status"].Text := txt
    catch {
    }
}

GestureMgr_RefreshAll() {
    GestureMgr_RefreshFilter()
    GestureMgr_RefreshGestures()
    GestureMgr_RefreshTemplates()
    GestureMgr_RefreshBlacklist()
}

GestureMgr_RefreshFilter() {
    global g_GestureMgr
    try {
        items := ["全部", "全局"]
        for i, n in Gesture_ListAppNames()
            items.Push(n)
        g_GestureMgr["filterItems"] := items
        ddl := g_GestureMgr["filter"]
        ddl.Delete()
        ddl.Add(items)
        ddl.Choose(1)
    } catch {
    }
}

GestureMgr_CurrentFilter() {
    global g_GestureMgr
    try {
        return g_GestureMgr["filter"].Text
    } catch {
        return "全部"
    }
}

GestureMgr_RefreshGestures() {
    global g_GestureMgr
    try {
        lv := g_GestureMgr["lv"]
        lv.Delete()
        filter := GestureMgr_CurrentFilter()
        count := 0
        for i, row in Gesture_ListAll() {
            if (filter != "全部" && row[1] != filter)
                continue
            st := Gesture_ChainOff(row[1], row[2]) ? T("gesture.st_off") : T("gesture.st_on")
            d := Gesture_GetGestureDesc(row[1], row[2])
            if (d = "")
                d := GestureMgr_DescribeAction(row[3])
            lv.Add("", row[1], row[2], row[3], d, st)
            count++
        }
        GestureMgr_SetStatus(T("gesture.st_gesture_count", count, filter))
        ; 无选中时自动预览第一行, 避免预览框空着
        try {
            if (lv.GetNext(0) = 0 && count > 0) {
                lv.Modify(1, "Select Focus")
                GestureMgr_OnPreview()
            }
        } catch {
        }
    } catch {
    }
}

GestureMgr_RefreshBlacklist() {
    global g_GestureMgr
    try {
        blLv := g_GestureMgr["blLv"]
        blLv.Delete()
        for i, pat in Gesture_ListBlacklist()
            blLv.Add("", pat, Gesture_BlOff(pat) ? T("gesture.st_off") : T("gesture.st_on"))
    } catch {
    }
}

; ==================== 字母模板页 ====================
GestureMgr_RefreshTemplates() {
    global g_GestureMgr
    try {
        tplLv := g_GestureMgr["tplLv"]
        tplLv.Delete()
        count := 0
        for i, row in Tpl_List() {
            st := Gesture_TplOff(row[1]) ? T("gesture.st_off") : T("gesture.st_on")
            tplLv.Add("", row[1], row[2], row[3], st)
            count++
        }
        GestureMgr_SetStatus(T("gesture.st_tpl_count", count))
    } catch {
    }
}

GestureMgr_SelectedTplRow() {
    global g_GestureMgr
    try {
        tplLv := g_GestureMgr["tplLv"]
        row := tplLv.GetNext(0)
        if (row = 0)
            return ""
        return [tplLv.GetText(row, 1), tplLv.GetText(row, 2), tplLv.GetText(row, 3)]
    } catch {
        return ""
    }
}

GestureMgr_OnTplAdd(*) {
    TplEditDialog("", "")
}

GestureMgr_OnTplEdit(*) {
    row := GestureMgr_SelectedTplRow()
    if (row = "") {
        GestureMgr_SetStatus(T("gesture.st_tpl_pick_edit"))
        return
    }
    TplEditDialog(row[1], row[2])
}

GestureMgr_OnTplDel(*) {
    row := GestureMgr_SelectedTplRow()
    if (row = "") {
        GestureMgr_SetStatus(T("gesture.st_tpl_pick_del"))
        return
    }
    if (SubStr(row[3], 1, 2) = "内置") {
        GestureMgr_SetStatus(T("gesture.st_tpl_builtin"))
        return
    }    if (MsgBox(T("gesture.confirm_del_tpl", row[1]), T("gesture.confirm_title"), 36) != "Yes")
        return
    if (GestureStore_DelTemplate(row[1]))
        GestureMgr_SetStatus(T("gesture.st_tpl_deleted", row[1]))
    else
        GestureMgr_SetStatus(T("gesture.st_del_failed"))
    GestureMgr_RefreshTemplates()
}

; ---- 模板录制/编辑对话框: 名称+动作, 点录制后画一笔 ----
TplEditDialog(name, action) {
    global g_GestureMgr
    de := Gui(, name = "" ? T("gesture.tpl_dlg_new") : T("gesture.tpl_dlg_edit"))
    de.SetFont("S10", "微软雅黑")
    de.Add("Text", "xm ym", T("gesture.tpl_name_label"))
    nameEdit := de.Add("Edit", "x+6 w120", name)
    if (name != "") {
        try nameEdit.Opt("+ReadOnly")
        catch {
        }
    }
    de.Add("Text", "xm y+10", T("gesture.tpl_action_label"))
    actionEdit := de.Add("Edit", "xm y+4 w490", action)
    de.Add("Button", "xm y+10 w110", T("gesture.btn_record_stroke")).OnEvent("Click", TplDlg_OnRecord)
    saveBtn := de.Add("Button", "x+8 w100", T("gesture.btn_save"))
    de.Add("Button", "x+8 w100", T("gesture.btn_cancel")).OnEvent("Click", (*) => TplDlg_Close(false))
    hint := de.Add("Text", "xm y+8 w490", name = "" ? T("gesture.tpl_hint_new") : T("gesture.tpl_hint_edit"))
    tplDlgPic := de.Add("Picture", "xm y+6 w140 h110 +Border +0xE")
    tplDlgTx := de.Add("Text", "x+8 yp w300", T("gesture.tpl_shape_hint"))
    saveBtn.OnEvent("Click", (*) => TplDlg_OnSave())
    dlg := Map("gui", de, "nameEdit", nameEdit, "actionEdit", actionEdit
        , "pts", "", "pic", tplDlgPic, "tx", tplDlgTx, "hint", hint, "isNew", name = "")
    g_GestureMgr["tplDlg"] := dlg
    de.OnEvent("Close", (*) => TplDlg_Close(false))
    de.Show()
    if (name != "")
        TplDlg_ShowCurrent(name)
    return dlg
}

TplDlg_Current() {
    global g_GestureMgr
    try {
        if (g_GestureMgr.Has("tplDlg") && IsObject(g_GestureMgr["tplDlg"]))
            return g_GestureMgr["tplDlg"]
    }
    return ""
}

TplDlg_Close(saved) {
    global g_GestureMgr
    if (Gesture_IsTplRecording())
        Gesture_CancelTplRecord()
    try {
        if (g_GestureMgr.Has("tplDlg") && IsObject(g_GestureMgr["tplDlg"])) {
            g_GestureMgr["tplDlg"]["gui"].Destroy()
            g_GestureMgr["tplDlg"] := ""
        }
    }
    if (saved)
        GestureMgr_RefreshTemplates()
}

TplDlg_OnRecord(*) {
    dlg := TplDlg_Current()
    if (dlg = "")
        return
    nm := ""
    try nm := Trim(dlg["nameEdit"].Text)
    catch {
    }
    if (nm = "") {
        try dlg["hint"].Text := T("gesture.tpl_need_name")
        catch {
        }
        return
    }
    try dlg["hint"].Text := T("gesture.tpl_recording")
    catch {
    }
    Gesture_ArmTplRecord((enc) => TplDlg_OnRecorded(enc))
}

TplDlg_OnRecorded(enc) {
    dlg := TplDlg_Current()
    if (dlg = "")
        return
    try {
        dlg["pts"] := enc
        GesturePreview_SetPic(dlg["pic"], GesturePreview_Encoded(enc, 140, 110))
        dlg["tx"].Text := T("gesture.tpl_recorded")
        dlg["hint"].Text := T("gesture.tpl_recorded")
    } catch {
    }
}

; ---- 编辑既有模板: 显示当前形状 ----
TplDlg_ShowCurrent(name) {
    dlg := TplDlg_Current()
    if (dlg = "")
        return
    try {
        t := Tpl_Get(name)
        if (!IsObject(t) || t.samples.Length = 0)
            return
        dlg["pts"] := Tpl_JoinSamples(t)
        GesturePreview_SetPic(dlg["pic"], GesturePreview_Template(name, 140, 110))
        dlg["tx"].Text := T("gesture.tpl_current", t.samples.Length)
    } catch {
    }
}

TplDlg_OnSave() {
    dlg := TplDlg_Current()
    if (dlg = "")
        return
    nm := ""
    act := ""
    pts := ""
    try {
        nm := Trim(dlg["nameEdit"].Text)
        act := Trim(dlg["actionEdit"].Text)
        pts := Trim(dlg["pts"])
    } catch {
        return
    }
    if (nm = "" || act = "") {
        try dlg["hint"].Text := T("gesture.tpl_empty")
        catch {
        }
        return
    }
    if (InStr(nm, "=") || InStr(nm, "|") || InStr(nm, ":")) {
        try dlg["hint"].Text := T("gesture.tpl_badchar")
        catch {
        }
        return
    }
    if (pts = "") {
        ; 只改动作: 沿用已有(内置/已存)样本
        t := Tpl_Get(nm)
        if (!IsObject(t)) {
            try dlg["hint"].Text := T("gesture.tpl_need_record")
            catch {
            }
            return
        }
        pts := Tpl_JoinSamples(t)
    }
    if (GestureStore_SetTemplate(nm, act, pts)) {
        GestureMgr_SetStatus(T("gesture.tpl_saved", nm, act))
        TplDlg_Close(true)
    } else {
        try dlg["hint"].Text := T("gesture.tpl_save_failed")
        catch {
        }
    }
}

GestureMgr_OnFilter(*) {
    GestureMgr_RefreshGestures()
    f := GestureMgr_CurrentFilter()
    if (f != "全部" && f != "全局") {
        app := Gesture_GetApp(f)
        if (IsObject(app)) {
            info := T("gesture.app_match", f)
            if (app.exe != "")
                info .= " exe=" . app.exe
            if (app.cls != "")
                info .= " class=" . app.cls
            if (app.title != "")
                info .= " " . T("gesture.app_title_contains", app.title)
            if (app.titleRx != "")
                info .= " " . T("gesture.app_title_rx", app.titleRx)
            if (app.noglobal)
                info .= " " . T("gesture.app_no_global")
            GestureMgr_SetStatus(info)
        }
    }
}

; 由动作串派生精准含义 (无用户自定义时列表显示; 与存储无关, 跟语言走)
; 优先级: ①引擎已注册动作的注释 (P2 精翻, 最准) ②常见按键语义表 ③动作类型原文
; 前缀与 Rim.ahk VIMD_CMD 派发一致: run|/key|/dir|/tccmd|/wshkey|/function|
GestureMgr_DescribeAction(action) {
    global g_VimEngine
    action := Trim(action)
    ; ① <动作名>: 取引擎注释
    if (SubStr(action, 1, 1) = "<" && SubStr(action, -1) = ">") {
        try {
            if (IsObject(g_VimEngine) && g_VimEngine.ActionList.Has(action)) {
                c := Trim(g_VimEngine.ActionList[action].Comment)
                if (c != "")
                    return c
            }
        } catch {
        }
        return SubStr(action, 2, StrLen(action) - 2)
    }
    ; ② 按键: 语义表优先
    if (SubStr(action, 1, 4) = "key|") {
        m := GestureMgr_KeyMeaning(Trim(SubStr(action, 5)))
        if (m != "")
            return m
        return T("gesture.desc_key", Trim(SubStr(action, 5)))
    }
    if (SubStr(action, 1, 7) = "wshkey|") {
        m := GestureMgr_KeyMeaning(Trim(SubStr(action, 8)))
        if (m != "")
            return m
        return T("gesture.desc_key", Trim(SubStr(action, 8)))
    }
    if (SubStr(action, 1, 4) = "run|")
        return T("gesture.desc_run", SubStr(action, 5))
    if (SubStr(action, 1, 9) = "function|")
        return T("gesture.desc_function", SubStr(action, 10))
    if (SubStr(action, 1, 4) = "dir|")
        return T("gesture.desc_dir", SubStr(action, 5))
    if (SubStr(action, 1, 6) = "tccmd|")
        return T("gesture.desc_tccmd", SubStr(action, 7))
    return action
}

; 常见按键语义表 (按键名大小写不敏感; 未命中返回 "")
GestureMgr_KeyMeaning(k) {
    k := StrUpper(Trim(k))
    if (k = "^C")
        return T("gesture.mean_copy")
    if (k = "^V")
        return T("gesture.mean_paste")
    if (k = "^X")
        return T("gesture.mean_cut")
    if (k = "^Z")
        return T("gesture.mean_undo")
    if (k = "^Y")
        return T("gesture.mean_redo")
    if (k = "^A")
        return T("gesture.mean_selectall")
    if (k = "^S")
        return T("gesture.mean_save")
    if (k = "^F")
        return T("gesture.mean_find")
    if (k = "{BROWSER_BACK}")
        return T("gesture.mean_back")
    if (k = "{BROWSER_FORWARD}")
        return T("gesture.mean_forward")
    if (k = "{ENTER}")
        return T("gesture.mean_enter")
    if (k = "{ESCAPE}" || k = "{ESC}")
        return T("gesture.mean_esc")
    if (k = "{TAB}")
        return T("gesture.mean_tab")
    if (k = "{DELETE}" || k = "{DEL}")
        return T("gesture.mean_del")
    if (k = "{BACKSPACE}" || k = "{BS}")
        return T("gesture.mean_bs")
    if (k = "{HOME}")
        return T("gesture.mean_home")
    if (k = "{END}")
        return T("gesture.mean_end")
    if (k = "{PGUP}")
        return T("gesture.mean_pgup")
    if (k = "{PGDN}")
        return T("gesture.mean_pgdn")
    if (k = "{MEDIA_PLAY_PAUSE}")
        return T("gesture.mean_playpause")
    if (k = "{MEDIA_NEXT}")
        return T("gesture.mean_next")
    if (k = "{MEDIA_PREV}")
        return T("gesture.mean_prev")
    if (k = "{MEDIA_STOP}")
        return T("gesture.mean_stop")
    if (k = "{VOLUME_UP}")
        return T("gesture.mean_volup")
    if (k = "{VOLUME_DOWN}")
        return T("gesture.mean_voldn")
    if (k = "{VOLUME_MUTE}")
        return T("gesture.mean_mute")
    return ""
}

GestureMgr_SelectedGestureRow() {
    global g_GestureMgr
    try {
        lv := g_GestureMgr["lv"]
        row := lv.GetNext(0)
        if (row = 0)
            return ""
        ; 第 4 元为存储的说明 (非派生值, 免得打开编辑框就把派生文本固化下来)
        d := ""
        try d := Gesture_GetGestureDesc(lv.GetText(row, 1), lv.GetText(row, 2))
        catch {
        }
        return [lv.GetText(row, 1), lv.GetText(row, 2), lv.GetText(row, 3), d]
    } catch {
        return ""
    }
}

; ---- 选中行预览线条 ----
GestureMgr_OnPreview(*) {
    global g_GestureMgr
    try {
        lv := g_GestureMgr["lv"]
        row := lv.GetNext(0, "Focused")
        if (row = 0)
            row := lv.GetNext(0)
        if (row = 0)
            return
        GestureMgr_ShowChain(lv.GetText(row, 2))
    } catch {
    }
}

GestureMgr_ShowChain(key) {
    global g_GestureMgr
    try {
        info := GesturePreview_ChainInfo(key)
        g_GestureMgr["prevTx"].Text := info[2] = "" ? key : info[2]
        if (info[1])
            GesturePreview_SetPic(g_GestureMgr["prevPic"], GesturePreview_Chain(key, 120, 120))
        else
            GesturePreview_SetPic(g_GestureMgr["prevPic"], 0)
    } catch {
    }
}

GestureMgr_OnTplPreview(*) {
    global g_GestureMgr
    try {
        tplLv := g_GestureMgr["tplLv"]
        row := tplLv.GetNext(0, "Focused")
        if (row = 0)
            row := tplLv.GetNext(0)
        if (row = 0)
            return
        nm := tplLv.GetText(row, 1)
        g_GestureMgr["tplTx"].Text := nm
        GesturePreview_SetPic(g_GestureMgr["tplPic"], GesturePreview_Template(nm, 120, 120))
    } catch {
    }
}

GestureMgr_OnAdd(*) {
    GestureEditDialog("new", "全局", "", "", "")
}

GestureMgr_OnRecordNew(*) {
    ; 先开空对话框并立即进入录制, 画完自动填入
    dlg := GestureEditDialog("new", "全局", "", "", "")
    if (IsObject(dlg))
        GestureDlg_ArmRecord(dlg)
}

GestureMgr_OnEdit(*) {
    row := GestureMgr_SelectedGestureRow()
    if (row = "") {
        GestureMgr_SetStatus(T("gesture.st_pick_edit"))
        return
    }
    GestureEditDialog("edit", row[1], row[2], row[3], row[4])
}

GestureMgr_OnDel(*) {
    row := GestureMgr_SelectedGestureRow()
    if (row = "") {
        GestureMgr_SetStatus(T("gesture.st_pick_del"))
        return
    }
    if (MsgBox(T("gesture.confirm_del_gesture", row[1], row[2]), T("gesture.confirm_title"), 36) != "Yes")
        return
    if (GestureStore_DelGesture(row[1], row[2]))
        GestureMgr_SetStatus(T("gesture.st_gesture_deleted", row[1], row[2]))
    else
        GestureMgr_SetStatus(T("gesture.st_write_failed"))
    GestureMgr_RefreshFilter()
    GestureMgr_RefreshGestures()
}

GestureMgr_OnToggle(*) {
    row := GestureMgr_SelectedGestureRow()
    if (row = "") {
        GestureMgr_SetStatus(T("gesture.st_pick_toggle"))
        return
    }
    id := row[1] . ":" . row[2]
    off := !Gesture_ChainOff(row[1], row[2])
    if (GestureStore_SetDisabled(id, off))
        GestureMgr_SetStatus(T("gesture.st_row_toggled", off ? T("gesture.st_off") : T("gesture.st_on"), row[1], row[2]))
    else
        GestureMgr_SetStatus(T("gesture.st_toggle_failed"))
    GestureMgr_RefreshGestures()
}

GestureMgr_OnLayerOff(*) {
    f := GestureMgr_CurrentFilter()
    if (f = "全部" || f = "全局") {
        GestureMgr_SetStatus(T("gesture.st_layer_filter_hint"))
        return
    }
    id := "应用层:" . f
    off := !Gesture_LayerOff(f)
    if (GestureStore_SetDisabled(id, off))
        GestureMgr_SetStatus(off ? T("gesture.st_layer_off", f) : T("gesture.st_layer_on", f))
    else
        GestureMgr_SetStatus(T("gesture.st_toggle_failed"))
    GestureMgr_RefreshGestures()
}

GestureMgr_OnTplToggle(*) {
    row := GestureMgr_SelectedTplRow()
    if (row = "") {
        GestureMgr_SetStatus(T("gesture.st_tpl_pick_toggle"))
        return
    }    id := "模板:" . row[1]
    off := !Gesture_TplOff(row[1])
    if (GestureStore_SetDisabled(id, off))
        GestureMgr_SetStatus(off ? T("gesture.st_tpl_off", row[1]) : T("gesture.st_tpl_on", row[1]))
    else
        GestureMgr_SetStatus(T("gesture.st_toggle_failed"))
    GestureMgr_RefreshTemplates()
}

GestureMgr_OnTplAppend(*) {
    global g_TplMaxSamples
    row := GestureMgr_SelectedTplRow()
    if (row = "") {
        GestureMgr_SetStatus(T("gesture.st_tpl_pick_append"))
        return
    }
    t := Tpl_Get(row[1])
    if (!IsObject(t)) {
        GestureMgr_SetStatus(T("gesture.st_tpl_missing"))
        return
    }
    maxS := 3
    try {
        if (g_TplMaxSamples + 0 > 0)
            maxS := g_TplMaxSamples + 0
    }
    if (t.samples.Length >= maxS) {
        GestureMgr_SetStatus(T("gesture.st_samples_full", maxS))
        return
    }
    GestureMgr_SetStatus(T("gesture.st_appending", row[1], t.samples.Length))
    Gesture_ArmTplRecord((enc) => TplAppend_Save(row[1], enc))
}

TplAppend_Save(name, enc) {
    t := Tpl_Get(name)
    if (!IsObject(t)) {
        GestureMgr_SetStatus(T("gesture.st_tpl_missing"))
        return
    }
    arr := []
    for _, samp in t.samples
        arr.Push(Tpl_Encode(samp))
    arr.Push(enc)
    if (GestureStore_SetTemplateSamples(name, t.action, arr))
        GestureMgr_SetStatus(T("gesture.st_samples_added", name, arr.Length))
    else
        GestureMgr_SetStatus(T("gesture.st_append_failed"))
    GestureMgr_RefreshTemplates()
}

GestureMgr_OnBlToggle(*) {
    global g_GestureMgr
    try {
        blLv := g_GestureMgr["blLv"]
        row := blLv.GetNext(0)
        if (row = 0) {
            GestureMgr_SetStatus(T("gesture.st_bl_pick_toggle"))
            return
        }
        pat := blLv.GetText(row, 1)
        off := !Gesture_BlOff(pat)
        if (GestureStore_SetDisabled("黑名单:" . pat, off))
            GestureMgr_SetStatus(off ? T("gesture.st_bl_off", pat) : T("gesture.st_bl_on", pat))
        else
            GestureMgr_SetStatus(T("gesture.st_toggle_failed"))
        GestureMgr_RefreshBlacklist()
    } catch {
    }
}

GestureMgr_OnBlAdd(*) {
    res := InputBox(T("gesture.bl_add_prompt"), T("gesture.bl_add_title"))
    if (res.Result != "OK")
        return
    pat := Trim(res.Value)
    if (pat = "")
        return
    if (GestureStore_AddBlacklist(pat))
        GestureMgr_SetStatus(T("gesture.st_blocked", pat))
    else
        GestureMgr_SetStatus(T("gesture.st_add_failed"))
    GestureMgr_RefreshBlacklist()
}

GestureMgr_OnBlDel(*) {
    global g_GestureMgr
    try {
        blLv := g_GestureMgr["blLv"]
        row := blLv.GetNext(0)
        if (row = 0) {
            GestureMgr_SetStatus(T("gesture.st_pick_del"))
            return
        }
        pat := blLv.GetText(row, 1)
        if (GestureStore_DelBlacklist(pat))
            GestureMgr_SetStatus(T("gesture.st_unblocked", pat))
        else
            GestureMgr_SetStatus(T("gesture.st_del_failed"))
        GestureMgr_RefreshBlacklist()
    } catch {
    }
}

; ==================== 设置页 ====================
GestureCfg_Val(name) {
    global g_GestureMgr, g_Gesture
    try {
        return g_Gesture[name]
    } catch {
        return ""
    }
}

GestureCfg_Load() {
    global g_GestureMgr, g_TplThreshold
    try {
        c := g_GestureMgr["cfg"]
        c["enable"].Value := GestureCfg_Val("enable") ? 1 : 0
        trigs := Map("RButton", 1, "MButton", 2, "XButton1", 3, "XButton2", 4)
        ti := trigs.Has(GestureCfg_Val("trigger")) ? trigs[GestureCfg_Val("trigger")] : 1
        c["trigger"].Choose(ti)
        nms := Map("swallow", 1, "passthrough", 2, "sound", 3)
        ni := nms.Has(GestureCfg_Val("noMatch")) ? nms[GestureCfg_Val("noMatch")] : 1
        c["noMatch"].Choose(ni)
        c["threshold"].Value := GestureCfg_Val("threshold") + 0
        c["thresholdTx"].Text := "" . (GestureCfg_Val("threshold") + 0)
        c["segment"].Value := GestureCfg_Val("segment") + 0
        c["segmentTx"].Text := "" . (GestureCfg_Val("segment") + 0)
        th := 75
        try {
            if (g_TplThreshold + 0 > 0)
                th := g_TplThreshold + 0
        }
        c["tplTh"].Value := th
        c["tplThTx"].Text := "" . th
        c["trailW"].Value := GestureCfg_Val("trailWidth") + 0
        c["trailWTx"].Text := "" . (GestureCfg_Val("trailWidth") + 0)
        c["ignoreKey"].Text := GestureCfg_Val("ignoreKey")
        c["osd"].Value := GestureCfg_Val("showOSD") ? 1 : 0
        c["trail"].Value := GestureCfg_Val("trail") ? 1 : 0
        c["onlyDef"].Value := GestureCfg_Val("onlyDefined") ? 1 : 0
        c["tryBox"].Value := Gesture_IsTryMode() ? 1 : 0
    } catch {
    }
}

GestureCfg_ShowVal(which) {
    global g_GestureMgr
    try {
        c := g_GestureMgr["cfg"]
        if (which = "Threshold")
            c["thresholdTx"].Text := "" . c["threshold"].Value
        else if (which = "Segment")
            c["segmentTx"].Text := "" . c["segment"].Value
        else if (which = "TplTh")
            c["tplThTx"].Text := "" . c["tplTh"].Value
        else if (which = "TrailW")
            c["trailWTx"].Text := "" . c["trailW"].Value
    } catch {
    }
}

GestureCfg_OnSave(*) {
    global g_GestureMgr, g_Conf, g_ConfFile
    try {
        c := g_GestureMgr["cfg"]
        vals := Map("Enable", c["enable"].Value ? "1" : "0"
            , "Trigger", c["trigger"].Text
            , "NoMatch", c["noMatch"].Text
            , "Threshold", "" . c["threshold"].Value
            , "Segment", "" . c["segment"].Value
            , "TemplateThreshold", "" . c["tplTh"].Value
            , "TrailWidth", "" . c["trailW"].Value
            , "IgnoreKey", Trim(c["ignoreKey"].Text)
            , "ShowOSD", c["osd"].Value ? "1" : "0"
            , "Trail", c["trail"].Value ? "1" : "0"
            , "OnlyDefinedApps", c["onlyDef"].Value ? "1" : "0")
        for k, v in vals {
            if (!GestureIni_Upsert(g_ConfFile, "Gesture", k, v)) {
                GestureMgr_SetStatus(T("gesture.cfg_save_failed", k))
                return
            }
            try g_Conf.Set("Gesture", k, v)
            catch {
            }
        }
        Gesture_LoadConfig()
        try Tpl_LoadAll()
        catch {
        }
        Gesture_BindTrigger()
        GestureMgr_SetStatus(T("gesture.cfg_saved"))
    } catch {
        GestureMgr_SetStatus(T("gesture.tpl_save_failed"))
    }
}

GesturePkg_OnExport(*) {
    path := FileSelect("S", "", T("gesture.export_title"), T("gesture.pkg_filter"))
    if (path = "")
        return
    if (SubStr(path, -3) != ".ini")
        path .= ".ini"
    if (GesturePkg_Export(path))
        GestureMgr_SetStatus(T("gesture.st_exported", path))
    else
        GestureMgr_SetStatus(T("gesture.st_export_failed"))
}

GesturePkg_OnImport(*) {
    path := FileSelect("", "", T("gesture.import_title"), T("gesture.pkg_filter"))
    if (path = "" || !FileExist(path))
        return
    ans := MsgBox(T("gesture.import_confirm"), T("gesture.import_title"), "YNC")
    if (ans = "Cancel")
        return
    res := GesturePkg_Import(path, ans = "Yes")
    GestureMgr_SetStatus(T("gesture.st_imported", res[1], res[2], res[3]))
    GestureCfg_Load()
    GestureMgr_RefreshAll()
}

; ==================== 新增/编辑对话框 ====================
; 返回对话框 refs Map (供录制回调), 失败返回 ""
; desc: 作用说明 (UI 展示, 存 [GestureDesc], 可空)
GestureEditDialog(mode, layer, gesture, action, desc := "") {
    global g_GestureMgr
    try {
        if (IsObject(g_GestureMgr["editGui"])) {
            try g_GestureMgr["editGui"]["gui"].Destroy()
            catch {
            }
        }
    }
    de := Gui(, mode = "new" ? T("gesture.dlg_new") : T("gesture.dlg_edit"))
    de.SetFont("S10", "微软雅黑")
    de.Add("Text", "xm ym", T("gesture.dlg_layer"))
    layers := ["全局"]
    for i, n in Gesture_ListAppNames()
        layers.Push(n)
    layerDdl := de.Add("DropDownList", "x+6 w180", layers)
    selIdx := 1
    for i, n in layers {
        if (n = layer) {
            selIdx := i
            break
        }
    }
    try layerDdl.Choose(selIdx)
    catch {
    }
    de.Add("Button", "x+8 w110", T("gesture.btn_new_layer")).OnEvent("Click", GestureDlg_OnNewApp)
    de.Add("Text", "xm y+10", T("gesture.dlg_gesture_label"))
    gestureEdit := de.Add("Edit", "xm y+4 w280", gesture)
    de.Add("Button", "x+8 w70", T("gesture.btn_record")).OnEvent("Click", GestureDlg_OnRecord)
    dlgPic := de.Add("Picture", "x+8 yp w100 h80 +Border +0xE")
    dlgTx := de.Add("Text", "xp y+2 w100 Center", "")
    gestureEdit.OnEvent("Change", (*) => GestureDlg_OnPreview())
    de.Add("Text", "xm y+10", T("gesture.tpl_action_label"))
    actionEdit := de.Add("Edit", "xm y+4 w490", action)
    de.Add("Text", "xm y+4 w490", T("gesture.dlg_example"))
    de.Add("Text", "xm y+10", T("gesture.dlg_desc_label"))
    descEdit := de.Add("Edit", "xm y+4 w490", desc)
    saveBtn := de.Add("Button", "xm y+10 w100", T("gesture.btn_save"))
    de.Add("Button", "x+8 w100", T("gesture.btn_cancel")).OnEvent("Click", (*) => GestureDlg_Close(false))
    hint := de.Add("Text", "xm y+6 w490", mode = "new" ? T("gesture.dlg_hint_new") : "")
    saveBtn.OnEvent("Click", (*) => GestureDlg_OnSave(mode))

    dlg := Map("gui", de, "layers", layers, "layerDdl", layerDdl
        , "gestureEdit", gestureEdit, "actionEdit", actionEdit, "descEdit", descEdit
        , "hint", hint, "mode", mode, "origLayer", layer, "origGesture", gesture
        , "pic", dlgPic, "tx", dlgTx)
    g_GestureMgr["editGui"] := dlg
    de.OnEvent("Close", (*) => GestureDlg_Close(false))
    de.Show()
    try gestureEdit.Focus()
    catch {
    }
    GestureDlg_OnPreview()
    return dlg
}

GestureDlg_Close(saved) {
    global g_GestureMgr
    if (Gesture_IsRecording())
        Gesture_CancelRecord()
    try {
        if (g_GestureMgr.Has("editGui") && IsObject(g_GestureMgr["editGui"])) {
            g_GestureMgr["editGui"]["gui"].Destroy()
            g_GestureMgr["editGui"] := ""
        }
    }
    if (saved) {
        GestureMgr_RefreshFilter()
        GestureMgr_RefreshGestures()
    }
}

GestureDlg_CurrentDlg() {
    global g_GestureMgr
    try {
        if (g_GestureMgr.Has("editGui") && IsObject(g_GestureMgr["editGui"]))
            return g_GestureMgr["editGui"]
    }
    return ""
}

GestureDlg_OnNewApp(*) {
    dlg := GestureDlg_CurrentDlg()
    if (dlg = "")
        return
    r1 := InputBox(T("gesture.layer_name_prompt"), T("gesture.layer_new_title"))
    if (r1.Result != "OK" || Trim(r1.Value) = "")
        return
    appName := Trim(r1.Value)
    if (InStr(appName, ":") || InStr(appName, "=") || InStr(appName, "|")) {
        MsgBox(T("gesture.layer_badchar"), T("gesture.layer_new_title"), 48)
        return
    }
    r2 := InputBox(T("gesture.layer_exe_prompt"), T("gesture.layer_title_with", appName))
    if (r2.Result != "OK")
        return
    r3 := InputBox(T("gesture.layer_cls_prompt"), T("gesture.layer_title_with", appName))
    if (r3.Result != "OK")
        return
    r4 := InputBox(T("gesture.layer_title_prompt"), T("gesture.layer_title_with", appName))
    if (r4.Result != "OK")
        return
    r5 := InputBox(T("gesture.layer_rx_prompt"), T("gesture.layer_title_with", appName))
    if (r5.Result != "OK")
        return
    if (Trim(r2.Value) = "" && Trim(r3.Value) = "" && Trim(r4.Value) = "" && Trim(r5.Value) = "") {
        MsgBox(T("gesture.layer_need_one"), T("gesture.layer_new_title"), 48)
        return
    }
    noG := MsgBox(T("gesture.layer_noglobal"), T("gesture.layer_title_with", appName), 36)
    if (!GestureStore_SetAppMatch(appName, r2.Value, r3.Value, r4.Value, r5.Value, noG = "Yes" ? "1" : "0")) {
        MsgBox(T("gesture.layer_write_failed"), T("gesture.layer_new_title"), 16)
        return
    }
    try {
        dlg["layers"].Push(appName)
        dlg["layerDdl"].Add([appName])
        dlg["layerDdl"].Choose(dlg["layers"].Length)
    } catch {
    }
    GestureMgr_RefreshFilter()
}

; ---- 编辑框实时预览 ----
GestureDlg_OnPreview() {
    dlg := GestureDlg_Current()
    if (dlg = "")
        return
    try {
        txt := dlg["gestureEdit"].Text
        info := GesturePreview_ChainInfo(txt)
        dlg["tx"].Text := info[2]
        if (info[1])
            GesturePreview_SetPic(dlg["pic"], GesturePreview_Chain(txt, 100, 80))
        else
            GesturePreview_SetPic(dlg["pic"], 0)
    } catch {
    }
}

GestureDlg_OnRecord(*) {
    dlg := GestureDlg_CurrentDlg()
    if (dlg = "")
        return
    GestureDlg_ArmRecord(dlg)
}

; ---- 武装录制: 下一笔手势被截获并填入本对话框 ----
GestureDlg_ArmRecord(dlg) {
    try dlg["hint"].Text := T("gesture.recording_hint")
    catch {
    }
    Gesture_ArmRecord((g) => GestureDlg_OnRecorded(g))
}

GestureDlg_OnRecorded(g) {
    dlg := GestureDlg_CurrentDlg()
    if (dlg = "")
        return
    try {
        dlg["gestureEdit"].Text := g
        dlg["hint"].Text := T("gesture.recorded_hint", g)
        GestureDlg_OnPreview()
        dlg["actionEdit"].Focus()
    } catch {
    }
}

GestureDlg_OnSave(mode) {
    dlg := GestureDlg_CurrentDlg()
    if (dlg = "")
        return
    layer := "全局"
    gesture := ""
    action := ""
    desc := ""
    try {
        layer := dlg["layerDdl"].Text
        gesture := dlg["gestureEdit"].Text
        action := dlg["actionEdit"].Text
        desc := dlg["descEdit"].Text
    } catch {
        return
    }
    if (Trim(gesture) = "" || Trim(action) = "") {
        try dlg["hint"].Text := T("gesture.dlg_empty")
        catch {
        }
        return
    }
    gkey := Gesture_NormalizeFull(gesture)
    if (mode = "new" && Gesture_LayerHas(layer, gkey)) {
        if (MsgBox(T("gesture.confirm_overwrite", layer, gkey), T("gesture.overwrite_title"), 36) != "Yes")
            return
    }
    if (GestureStore_SetGesture(layer, gesture, action)) {
        ; 存作用说明; 编辑时若改了层/手势, 老键的说明同步清掉防孤儿
        try {
            if (mode = "edit" && dlg.Has("origLayer")
                && (dlg["origLayer"] != layer || Gesture_Normalize(dlg["origGesture"]) != Gesture_Normalize(gesture)))
                GestureStore_DelGestureDesc(dlg["origLayer"], dlg["origGesture"])
        } catch {
        }
        GestureStore_SetGestureDesc(layer, gesture, desc)
        GestureMgr_SetStatus(T("gesture.st_gesture_saved", layer, Gesture_Normalize(gesture), Trim(action)))
        GestureDlg_Close(true)
    } else {
        try dlg["hint"].Text := T("gesture.tpl_save_failed")
        catch {
        }
    }
}
