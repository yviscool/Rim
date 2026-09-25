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
    mg.SetFont("s10", "Microsoft YaHei")
    tabs := mg.Add("Tab3", "x12 y10 w816 h484", [T("gesture.tab_gestures"), T("gesture.tab_tpl"), T("gesture.tab_blacklist"), T("gesture.tab_settings")])

    ; ---- 手势页 ----
    ; 注意: "全部"/"全局" 是层存储标识 (ini 键 + Core 过滤比较), 禁止翻译, 保持原文
    tabs.UseTab(1)
    mg.Add("Text", "x26 y52 Section", T("gesture.layer"))
    filterDdl := mg.Add("DropDownList", "x+6 w150", ["全部"])
    filterDdl.OnEvent("Change", GestureMgr_OnFilter)
    mg.Add("Button", "x+8 w76", T("gesture.btn_record_new")).OnEvent("Click", GestureMgr_OnRecordNew)
    mg.Add("Button", "x+6 w56", T("gesture.btn_add")).OnEvent("Click", GestureMgr_OnAdd)
    mg.Add("Button", "x+6 w56", T("gesture.btn_edit")).OnEvent("Click", GestureMgr_OnEdit)
    mg.Add("Button", "x+6 w56", T("gesture.btn_delete")).OnEvent("Click", GestureMgr_OnDel)
    mg.Add("Button", "x+6 w76", T("gesture.btn_toggle")).OnEvent("Click", GestureMgr_OnToggle)
    mg.Add("Button", "x+6 w76", T("gesture.btn_layer_off")).OnEvent("Click", GestureMgr_OnLayerOff)
    mg.Add("Text", "xs y+8 w60", T("gesture.filter_label"))
    geFilter := mg.Add("Edit", "x+6 w200 h25")
    geFilter.OnEvent("Change", GestureMgr_OnGeFilter)
    lv := mg.Add("ListView", "xs y+8 w620 h360", [T("gesture.col_layer"), T("gesture.col_gesture"), T("gesture.col_action"), T("gesture.col_desc"), T("gesture.col_status")])
    lv.ModifyCol(1, 70)
    lv.ModifyCol(2, 120)
    lv.ModifyCol(3, 210)
    lv.ModifyCol(4, 150)
    lv.ModifyCol(5, 50)
    try lv.OnEvent("DoubleClick", GestureMgr_OnEdit)
    catch {
    }
    try lv.OnEvent("ItemFocus", GestureMgr_OnPreview)
    catch {
    }
    prevBox := mg.Add("GroupBox", "x658 y113 w156 h230", T("gesture.preview_title"))
    prevPic := mg.Add("Picture", "x676 y143 w120 h120 +Border +0xE")
    prevTx := mg.Add("Text", "x664 y+8 w144 Center", T("gesture.no_selection"))

    ; ---- 字母模板页 ----
    tabs.UseTab(2)
    mg.Add("Text", "x26 y52 Section w620", T("gesture.tpl_note"))
    mg.Add("Text", "xs y+6 w60", T("gesture.filter_label"))
    tplFilter := mg.Add("Edit", "x+6 w200 h25")
    tplFilter.OnEvent("Change", GestureMgr_OnTplFilter)
    tplLv := mg.Add("ListView", "xs y+8 w620 h320", [T("gesture.col_tpl"), T("gesture.col_source"), T("gesture.col_status")])
    tplLv.ModifyCol(1, 80)
    tplLv.ModifyCol(2, 460)
    tplLv.ModifyCol(3, 60)
    try tplLv.OnEvent("ItemFocus", GestureMgr_OnTplPreview)
    catch {
    }
    ; 按钮行紧跟列表
    mg.Add("Button", "xs y+8 w100", T("gesture.btn_record_tpl")).OnEvent("Click", GestureMgr_OnTplAdd)
    mg.Add("Button", "x+6 w70", T("gesture.btn_edit")).OnEvent("Click", GestureMgr_OnTplEdit)
    mg.Add("Button", "x+6 w70", T("gesture.btn_delete")).OnEvent("Click", GestureMgr_OnTplDel)
    mg.Add("Button", "x+6 w70", T("gesture.btn_toggle")).OnEvent("Click", GestureMgr_OnTplToggle)
    mg.Add("Button", "x+6 w100", T("gesture.btn_append_sample")).OnEvent("Click", GestureMgr_OnTplAppend)
    mg.Add("Button", "x+6 w100", T("gesture.btn_delete_sample")).OnEvent("Click", GestureMgr_OnTplRemoveSample)
    ; 预览图保持右侧 GroupBox 卡片
    tplBox := mg.Add("GroupBox", "x658 y113 w156 h230", T("gesture.preview_title"))
    tplPic := mg.Add("Picture", "x676 y143 w120 h120 +Border +0xE")
    tplTx := mg.Add("Text", "x664 y+8 w144 Center", T("gesture.no_selection"))

    ; ---- 黑名单页 ----
    tabs.UseTab(3)
    mg.Add("Text", "x26 y52 Section w780", T("gesture.bl_note"))
    mg.Add("Text", "xs y+6 w60", T("gesture.filter_label"))
    blFilter := mg.Add("Edit", "x+6 w200 h25")
    blFilter.OnEvent("Change", GestureMgr_OnBlFilter)
    blLv := mg.Add("ListView", "xs y+8 w788 h320", [T("gesture.col_pattern"), T("gesture.col_status")])
    blLv.ModifyCol(1, 700)
    blLv.ModifyCol(2, 70)
    mg.Add("Button", "xs y+8 w90", T("gesture.btn_add")).OnEvent("Click", GestureMgr_OnBlAdd)
    mg.Add("Button", "x+6 w90", T("gesture.btn_delete")).OnEvent("Click", GestureMgr_OnBlDel)
    mg.Add("Button", "x+6 w80", T("gesture.btn_toggle")).OnEvent("Click", GestureMgr_OnBlToggle)

    ; ---- 设置页 ----
    tabs.UseTab(4)
    cfgEnable := mg.Add("CheckBox", "x26 y52 Section", T("gesture.set_enable"))
    mg.Add("Text", "xs y+8 w80", T("gesture.set_trigger"))
    cfgTrigger := mg.Add("DropDownList", "x+6 w160", [T("gesture.trig_rbutton"), T("gesture.trig_mbutton"), T("gesture.trig_xbutton1"), T("gesture.trig_xbutton2")])
    mg.Add("Text", "x+16 w90", T("gesture.set_nomatch"))
    cfgNoMatch := mg.Add("DropDownList", "x+6 w170", [T("gesture.nomatch_swallow"), T("gesture.nomatch_passthrough"), T("gesture.nomatch_sound")])
    mg.Add("Text", "x+8 yp+4 w250", T("gesture.set_nomatch_hint"))

    ; 参数滑块与输入框 (统一定宽 w110 对齐)
    mg.Add("Text", "xs y+8 w110", T("gesture.set_threshold"))
    cfgThreshold := mg.Add("Slider", "x+6 w150 Range2-60", 20)
    cfgThresholdTx := mg.Add("Text", "x+6 w30", "20")
    cfgThreshold.OnEvent("Change", (*) => GestureCfg_ShowVal("Threshold"))
    mg.Add("Text", "x+6 w470", T("gesture.set_threshold_hint"))

    mg.Add("Text", "xs y+6 w110", T("gesture.set_segment"))
    cfgSegment := mg.Add("Slider", "x+6 w150 Range2-60", 30)
    cfgSegmentTx := mg.Add("Text", "x+6 w30", "30")
    cfgSegment.OnEvent("Change", (*) => GestureCfg_ShowVal("Segment"))
    mg.Add("Text", "x+6 w470", T("gesture.set_segment_hint"))

    mg.Add("Text", "xs y+6 w110", T("gesture.set_cancel_delay"))
    cfgCancelDelay := mg.Add("Edit", "x+6 w70 Number", "1500")
    mg.Add("Text", "x+8 w580", T("gesture.set_cancel_delay_hint"))

    mg.Add("Text", "xs y+6 w110", T("gesture.set_tplth"))
    cfgTplTh := mg.Add("Slider", "x+6 w150 Range50-95", 75)
    cfgTplThTx := mg.Add("Text", "x+6 w30", "75")
    cfgTplTh.OnEvent("Change", (*) => GestureCfg_ShowVal("TplTh"))
    mg.Add("Text", "x+6 w470", T("gesture.set_tplth_hint"))

    mg.Add("Text", "xs y+6 w110", T("gesture.set_trailw"))
    cfgTrailW := mg.Add("Slider", "x+6 w150 Range1-10", 5)
    cfgTrailWTx := mg.Add("Text", "x+6 w30", "5")
    cfgTrailW.OnEvent("Change", (*) => GestureCfg_ShowVal("TrailW"))
    mg.Add("Text", "x+6 w470", T("gesture.set_trailw_hint"))

    mg.Add("Text", "xs y+6 w110", T("gesture.set_poll"))
    cfgPoll := mg.Add("Slider", "x+6 w150 Range5-50", 10)
    cfgPollTx := mg.Add("Text", "x+6 w30", "10")
    cfgPoll.OnEvent("Change", (*) => GestureCfg_ShowVal("Poll"))
    mg.Add("Text", "x+6 w470", T("gesture.set_poll_hint"))

    mg.Add("Text", "xs y+6 w110", T("gesture.set_trailcolor"))
    cfgTrailColor := mg.Add("Edit", "x+6 w90", "")
    mg.Add("Text", "x+8 w560", T("gesture.set_trailcolor_hint"))

    mg.Add("Text", "xs y+6 w110", T("gesture.set_ignorekey"))
    cfgIgnoreKey := mg.Add("Edit", "x+6 w90", "")
    mg.Add("Text", "x+8 w560", T("gesture.set_ignore_hint"))

    ; 选项复选框
    cfgOSD := mg.Add("CheckBox", "xs y+8", T("gesture.set_osd"))
    cfgTrail := mg.Add("CheckBox", "x+20", T("gesture.set_trail"))

    cfgOnlyDef := mg.Add("CheckBox", "xs y+6", T("gesture.set_onlydef"))
    mg.Add("Text", "x+8 yp+2 w550", T("gesture.set_onlydef_hint"))

    cfgVol := mg.Add("CheckBox", "xs y+6", T("gesture.set_vol"))
    mg.Add("Text", "x+8 yp+2 w550", T("gesture.set_vol_hint"))

    cfgTry := mg.Add("CheckBox", "xs y+6", T("gesture.set_try"))
    cfgTry.OnEvent("Click", (*) => GestureEngine.SetTryMode(cfgTry.Value ? true : false))

    ; 操作按钮行
    mg.Add("Button", "xs y+8 w100", T("gesture.btn_save_settings")).OnEvent("Click", GestureCfg_OnSave)
    mg.Add("Button", "x+8 w100", T("gesture.btn_export")).OnEvent("Click", GesturePkg_OnExport)
    mg.Add("Button", "x+8 w100", T("gesture.btn_import")).OnEvent("Click", GesturePkg_OnImport)
    mg.Add("Text", "x+10 yp+4 w400", T("gesture.save_hint"))
    try blLv.OnEvent("DoubleClick", GestureMgr_OnBlDel)
    catch {
    }

    tabs.UseTab()
    status := mg.Add("Text", "x16 y502 w808 h20", T("gesture.status_ready"))
    tabs.OnEvent("Change", GestureMgr_OnTabChange)
    mg.OnEvent("Close", (*) => mg.Hide())
    mg.OnEvent("Escape", (*) => mg.Hide())

    g_GestureMgr["gui"] := mg
    g_GestureMgr["tabs"] := tabs
    g_GestureMgr["filter"] := filterDdl
    g_GestureMgr["filterItems"] := ["全部"]
    g_GestureMgr["lv"] := lv
    g_GestureMgr["gefilter"] := geFilter
    g_GestureMgr["prevPic"] := prevPic
    g_GestureMgr["prevTx"] := prevTx
    g_GestureMgr["tplLv"] := tplLv
    g_GestureMgr["tplfilter"] := tplFilter
    g_GestureMgr["tplPic"] := tplPic
    g_GestureMgr["tplTx"] := tplTx
    g_GestureMgr["blLv"] := blLv
    g_GestureMgr["blfilter"] := blFilter
    g_GestureMgr["cfg"] := Map("enable", cfgEnable, "trigger", cfgTrigger, "noMatch", cfgNoMatch
        , "threshold", cfgThreshold, "thresholdTx", cfgThresholdTx
        , "segment", cfgSegment, "segmentTx", cfgSegmentTx
        , "cancelDelay", cfgCancelDelay
        , "tplTh", cfgTplTh, "tplThTx", cfgTplThTx
        , "trailW", cfgTrailW, "trailWTx", cfgTrailWTx
        , "poll", cfgPoll, "pollTx", cfgPollTx
        , "trailColor", cfgTrailColor
        , "ignoreKey", cfgIgnoreKey, "osd", cfgOSD, "trail", cfgTrail, "onlyDef", cfgOnlyDef
        , "vol", cfgVol, "tryBox", cfgTry)
    GestureCfg_Load()
    g_GestureMgr["status"] := status
    g_GestureMgr["editGui"] := ""

    GestureMgr_RefreshAll()
    mg.Show("w840 h530")
}

GestureMgr_SetStatus(txt) {
    global g_GestureMgr
    try g_GestureMgr["status"].Text := txt
    catch {
    }
}

GestureMgr_OnTabChange(tabCtrl, *) {
    switch tabCtrl.Value {
        case 1:
            GestureMgr_RefreshGestures()
        case 2:
            GestureMgr_RefreshTemplates()
        case 3:
            GestureMgr_RefreshBlacklist()
        case 4:
            GestureMgr_SetStatus(T("gesture.status_ready"))
    }
}

GestureMgr_RefreshAll() {
    GestureMgr_RefreshFilter()
    GestureMgr_RefreshTemplates()
    GestureMgr_RefreshBlacklist()
    GestureMgr_RefreshGestures()
}

GestureMgr_RefreshFilter() {
    global g_GestureMgr
    try {
        items := ["全部", "全局"]
        for i, n in GestureEngine.ListAppNames()
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
        needle := ""
        try needle := Trim(g_GestureMgr["gefilter"].Value)
        count := 0
        for i, row in GestureEngine.ListAll() {
            if (filter != "全部" && row[1] != filter)
                continue
            text := row[1] . " " . row[2] . " " . row[3]
            if (needle != "" && !InStr(text, needle))
                continue
            st := GestureEngine.ChainOff(row[1], row[2]) ? T("gesture.st_off") : T("gesture.st_on")
            d := Gesture_GetGestureDesc(row[1], row[2])
            if (d = "")
                d := GestureMgr_DescribeAction(row[3])
            lv.Add("", row[1], row[2], row[3], d, st)
            count++
        }
        if (count = 0 && needle = "")
            GestureMgr_SetStatus(T("gesture.empty_gestures"))
        else
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
        needle := ""
        try needle := Trim(g_GestureMgr["blfilter"].Value)
        n := 0
        for i, pat in GestureEngine.ListBlacklist() {
            if (needle != "" && !InStr(pat, needle))
                continue
            blLv.Add("", pat, GestureEngine.BlOff(pat) ? T("gesture.st_off") : T("gesture.st_on"))
            n++
        }
        if (n = 0 && needle = "")
            GestureMgr_SetStatus(T("gesture.empty_bl"))
    } catch {
    }
}

GestureMgr_OnBlFilter(*) {
    GestureMgr_RefreshBlacklist()
}

; ==================== 字母模板页 ====================
GestureMgr_RefreshTemplates() {
    global g_GestureMgr
    try {
        tplLv := g_GestureMgr["tplLv"]
        tplLv.Delete()
        needle := ""
        try needle := Trim(g_GestureMgr["tplfilter"].Value)
        count := 0
        for i, row in Tpl_List() {
            if (needle != "" && !InStr(row[1] . " " . row[3], needle))
                continue
            st := GestureEngine.TplOff(row[1]) ? T("gesture.st_off") : T("gesture.st_on")
            tplLv.Add("", row[1], row[3], st)
            count++
        }
        if (count = 0 && needle = "")
            GestureMgr_SetStatus(T("gesture.empty_tpl"))
        else
            GestureMgr_SetStatus(T("gesture.st_tpl_count", count))
    } catch {
    }
}

GestureMgr_OnTplFilter(*) {
    GestureMgr_RefreshTemplates()
}

GestureMgr_SelectedTplRow() {
    global g_GestureMgr
    try {
        tplLv := g_GestureMgr["tplLv"]
        row := tplLv.GetNext(0)
        if (row = 0)
            return ""
        return [tplLv.GetText(row, 1), tplLv.GetText(row, 2)]
    } catch {
        return ""
    }
}

GestureMgr_OnTplAdd(*) {
    TplEditDialog("")
}

GestureMgr_OnTplEdit(*) {
    row := GestureMgr_SelectedTplRow()
    if (row = "") {
        GestureMgr_SetStatus(T("gesture.st_tpl_pick_edit"))
        return
    }
    TplEditDialog(row[1])
}

GestureMgr_OnTplDel(*) {
    row := GestureMgr_SelectedTplRow()
    if (row = "") {
        GestureMgr_SetStatus(T("gesture.st_tpl_pick_del"))
        return
    }
    if (SubStr(row[2], 1, 2) = "内置") {
        GestureMgr_SetStatus(T("gesture.st_tpl_builtin"))
        return
    }
    if (MsgBox(T("gesture.confirm_del_tpl", row[1]), T("gesture.confirm_title"), 36) != "Yes")
        return
    if (GestureStore_DelTemplate(row[1]))
        GestureMgr_SetStatus(T("gesture.st_tpl_deleted", row[1]))
    else
        GestureMgr_SetStatus(T("gesture.st_del_failed"))
    GestureMgr_RefreshTemplates()
}

; ---- 模板录制/编辑对话框: 名称+动作, 点录制后画一笔 ----
TplEditDialog(name) {
    global g_GestureMgr
    de := Gui(, name = "" ? T("gesture.tpl_dlg_new") : T("gesture.tpl_dlg_edit"))
    de.SetFont("s10", "Microsoft YaHei")
    de.Add("Text", "xm ym", T("gesture.tpl_name_label"))
    nameEdit := de.Add("Edit", "x+6 w120", name)
    if (name != "") {
        try nameEdit.Opt("+ReadOnly")
        catch {
        }
    }
    de.Add("Button", "xm y+10 w110", T("gesture.btn_record_stroke")).OnEvent("Click", TplDlg_OnRecord)
    saveBtn := de.Add("Button", "x+8 w100", T("gesture.btn_save"))
    de.Add("Button", "x+8 w100", T("gesture.btn_cancel")).OnEvent("Click", (*) => TplDlg_Close(false))
    hint := de.Add("Text", "xm y+8 w490", name = "" ? T("gesture.tpl_hint_new") : T("gesture.tpl_hint_edit"))
    tplDlgPic := de.Add("Picture", "xm y+6 w140 h110 +Border +0xE")
    tplDlgTx := de.Add("Text", "x+8 yp w300", T("gesture.tpl_shape_hint"))
    saveBtn.OnEvent("Click", (*) => TplDlg_OnSave())
    dlg := Map("gui", de, "nameEdit", nameEdit
        , "pts", "", "pic", tplDlgPic, "tx", tplDlgTx, "hint", hint, "isNew", name = "")
    g_GestureMgr["tplDlg"] := dlg
    de.OnEvent("Close", (*) => TplDlg_Close(false))
    de.OnEvent("Escape", (*) => TplDlg_Close(false))
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
    if (GestureEngine.IsTplRecording())
        GestureEngine.CancelTplRecord()
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
    GestureEngine.ArmTplRecord((enc) => TplDlg_OnRecorded(enc))
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
    pts := ""
    try {
        nm := Trim(dlg["nameEdit"].Text)
        pts := Trim(dlg["pts"])
    } catch {
        return
    }
    if (nm = "") {
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
    if (GestureStore_SetTemplate(nm, pts) && GestureStore_SetDefinition(nm, "template")) {
        GestureMgr_SetStatus(T("gesture.tpl_saved", nm, ""))
        TplDlg_Close(true)
    } else {
        try dlg["hint"].Text := T("gesture.tpl_save_failed")
        catch {
        }
    }
}

GestureMgr_OnGeFilter(*) {
    GestureMgr_RefreshGestures()
}

GestureMgr_OnFilter(*) {
    GestureMgr_RefreshGestures()
    f := GestureMgr_CurrentFilter()
    if (f != "全部" && f != "全局") {
        app := GestureEngine.GetApp(f)
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
        if (GestureEngine.DefinitionMethod(GestureRecognizer.BindingName(key)) = "template") {
            g_GestureMgr["prevTx"].Text := GestureRecognizer.BindingName(key)
            GesturePreview_SetPic(g_GestureMgr["prevPic"], GesturePreview_Template(GestureRecognizer.BindingName(key), 120, 120))
            return
        }
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
    off := !GestureEngine.ChainOff(row[1], row[2])
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
    off := !GestureEngine.LayerOff(f)
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
    }
    id := "模板:" . row[1]
    off := !GestureEngine.TplOff(row[1])
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
    GestureEngine.ArmTplRecord((enc) => TplAppend_Save(row[1], enc))
}

TplAppend_Save(name, enc) {
    t := Tpl_Get(name)
    if (!IsObject(t)) {
        GestureMgr_SetStatus(T("gesture.st_tpl_missing"))
        return
    }
    arr := []
    for i, samp in t.samples {
        version := 2
        try version := t.versions[i]
        arr.Push((version = 1 ? "v1:" : "v2:") . Tpl_Encode(samp))
    }
    arr.Push(enc)
    if (GestureStore_SetTemplateSamples(name, arr))
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
        off := !GestureEngine.BlOff(pat)
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
        c["cancelDelay"].Value := "" . (GestureCfg_Val("cancelDelay") + 0)
        th := 75
        try {
            if (g_TplThreshold + 0 > 0)
                th := g_TplThreshold + 0
        }
        c["tplTh"].Value := th
        c["tplThTx"].Text := "" . th
        c["trailW"].Value := GestureCfg_Val("trailWidth") + 0
        c["trailWTx"].Text := "" . (GestureCfg_Val("trailWidth") + 0)
        c["poll"].Value := GestureCfg_Val("poll") + 0
        c["pollTx"].Text := "" . (GestureCfg_Val("poll") + 0)
        c["trailColor"].Text := GestureCfg_Val("trailColor")
        c["vol"].Value := GestureCfg_Val("volLatch") ? 1 : 0
        c["ignoreKey"].Text := GestureCfg_Val("ignoreKey")
        c["osd"].Value := GestureCfg_Val("showOSD") ? 1 : 0
        c["trail"].Value := GestureCfg_Val("trail") ? 1 : 0
        c["onlyDef"].Value := GestureCfg_Val("onlyDefined") ? 1 : 0
        c["tryBox"].Value := GestureEngine.IsTryMode() ? 1 : 0
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
        else if (which = "Poll")
            c["pollTx"].Text := "" . c["poll"].Value
    } catch {
    }
}

GestureCfg_OnSave(*) {
    global g_GestureMgr, g_Conf, g_ConfFile
    try {
        c := g_GestureMgr["cfg"]
        trigKeys := ["RButton", "MButton", "XButton1", "XButton2"]
        trigVal := (c["trigger"].Value >= 1 && c["trigger"].Value <= 4) ? trigKeys[c["trigger"].Value] : "RButton"
        nmKeys := ["swallow", "passthrough", "sound"]
        nmVal := (c["noMatch"].Value >= 1 && c["noMatch"].Value <= 3) ? nmKeys[c["noMatch"].Value] : "swallow"
        tc := Trim(c["trailColor"].Text)
        if (tc = "")
            tc := GestureCfg_Val("trailColor")
        vals := Map("Enable", c["enable"].Value ? "1" : "0"
            , "Trigger", trigVal
            , "NoMatch", nmVal
            , "Threshold", "" . c["threshold"].Value
            , "Segment", "" . c["segment"].Value
            , "CancelDelay", "" . Min(10000, Max(0, c["cancelDelay"].Value + 0))
            , "TemplateThreshold", "" . c["tplTh"].Value
            , "TrailWidth", "" . c["trailW"].Value
            , "Poll", "" . Min(50, Max(5, c["poll"].Value + 0))
            , "TrailColor", tc
            , "VolLatch", c["vol"].Value ? "1" : "0"
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
        GestureEngine.LoadConfig()
        try Tpl_LoadAll()
        catch {
        }
        GestureHook.Bind(g_Gesture["trigger"])
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
    de.SetFont("s10", "Microsoft YaHei")
    de.Add("Text", "xm ym", T("gesture.dlg_layer"))
    layers := ["全局"]
    for i, n in GestureEngine.ListAppNames()
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
    de.Add("Text", "xm y+8", T("gesture.recognizer_label"))
    methodDdl := de.Add("DropDownList", "x+8 w180", [T("gesture.recognizer_direction"), T("gesture.recognizer_template"), T("gesture.recognizer_auto")])
    method := GestureEngine.DefinitionMethod(GestureRecognizer.BindingName(gesture))
    methodDdl.Choose(method = "template" ? 2 : method = "auto" ? 3 : 1)
    de.Add("Button", "x+8 w110", T("gesture.btn_record_sample")).OnEvent("Click", GestureDlg_OnRecordSample)
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

    dlg := Map("gui", de, "layers", layers, "layerDdl", layerDdl, "methodDdl", methodDdl
        , "gestureEdit", gestureEdit, "actionEdit", actionEdit, "descEdit", descEdit
        , "hint", hint, "mode", mode, "origLayer", layer, "origGesture", gesture
        , "pic", dlgPic, "tx", dlgTx, "sample", "")
    g_GestureMgr["editGui"] := dlg
    de.OnEvent("Close", (*) => GestureDlg_Close(false))
    de.OnEvent("Escape", (*) => GestureDlg_Close(false))
    de.Show()
    try gestureEdit.Focus()
    catch {
    }
    GestureDlg_OnPreview()
    return dlg
}

GestureDlg_Close(saved) {
    global g_GestureMgr
    if (GestureEngine.IsRecording())
        GestureEngine.CancelRecord()
    if (GestureEngine.IsTplRecording())
        GestureEngine.CancelTplRecord()
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

; ---- 新应用层: 单对话框一次填完 (原先 5 连 InputBox + 1 确认框) ----
GestureDlg_OnNewApp(*) {
    global g_GestureMgr
    dlg := GestureDlg_CurrentDlg()
    if (dlg = "")
        return
    if (g_GestureMgr.Has("newapp")) {
        try {
            g_GestureMgr["newapp"]["gui"].Destroy()
        } catch {
        }
    }
    na := Gui("+Owner" dlg["gui"].Hwnd, T("gesture.layer_new_title"))
    na.SetFont("s10", "Microsoft YaHei")
    na.Add("Text", "x15 y15 w110", T("gesture.layer_name_label"))
    naName := na.Add("Edit", "x130 y12 w230 h25")
    na.Add("Text", "x15 y50 w110", T("gesture.layer_exe_label"))
    naExe := na.Add("Edit", "x130 y47 w230 h25")
    na.Add("Text", "x15 y85 w110", T("gesture.layer_cls_label"))
    naCls := na.Add("Edit", "x130 y82 w230 h25")
    na.Add("Text", "x15 y120 w110", T("gesture.layer_title_label"))
    naTitle := na.Add("Edit", "x130 y117 w230 h25")
    na.Add("Text", "x15 y155 w110", T("gesture.layer_rx_label"))
    naRx := na.Add("Edit", "x130 y152 w230 h25")
    naNoG := na.Add("CheckBox", "x15 y187 w345", T("gesture.layer_noglobal_check"))
    na.Add("Button", "x130 y215 w80 Default", T("gesture.dlg_ok")).OnEvent("Click", GestureDlg_OnNewAppOK)
    na.Add("Button", "x+10 w80", T("gesture.dlg_cancel")).OnEvent("Click", GestureDlg_OnNewAppCancel)
    g_GestureMgr["newapp"] := Map("gui", na, "name", naName, "exe", naExe, "cls", naCls
        , "title", naTitle, "rx", naRx, "nog", naNoG, "parent", dlg)
    na.OnEvent("Close", (*) => GestureDlg_OnNewAppCancel())
    na.OnEvent("Escape", (*) => GestureDlg_OnNewAppCancel())
    na.Show("w375 h260")
}

GestureDlg_OnNewAppCancel(*) {
    global g_GestureMgr
    try g_GestureMgr["newapp"]["gui"].Destroy()
    catch {
    }
    try g_GestureMgr.Delete("newapp")
    catch {
    }
}

GestureDlg_OnNewAppOK(*) {
    global g_GestureMgr
    na := ""
    try na := g_GestureMgr["newapp"]
    if (na = "")
        return
    appName := ""
    exe := ""
    cls := ""
    title := ""
    rx := ""
    nog := false
    try {
        appName := Trim(na["name"].Value)
        exe := Trim(na["exe"].Value)
        cls := Trim(na["cls"].Value)
        title := Trim(na["title"].Value)
        rx := Trim(na["rx"].Value)
        nog := na["nog"].Value ? true : false
    } catch {
        return
    }
    if (appName = "")
        return
    if (InStr(appName, ":") || InStr(appName, "=") || InStr(appName, "|")) {
        MsgBox(T("gesture.layer_badchar"), T("gesture.layer_new_title"), 48)
        return
    }
    if (exe = "" && cls = "" && title = "" && rx = "") {
        MsgBox(T("gesture.layer_need_one"), T("gesture.layer_new_title"), 48)
        return
    }
    if (!GestureStore_SetAppMatch(appName, exe, cls, title, rx, nog ? "1" : "0")) {
        MsgBox(T("gesture.layer_write_failed"), T("gesture.layer_new_title"), 16)
        return
    }
    try {
        parent := na["parent"]
        parent["layers"].Push(appName)
        parent["layerDdl"].Add([appName])
        parent["layerDdl"].Choose(parent["layers"].Length)
    } catch {
    }
    GestureDlg_OnNewAppCancel()
    GestureMgr_RefreshFilter()
}

; ---- 编辑框实时预览 ----
GestureDlg_OnPreview() {
    dlg := GestureDlg_CurrentDlg()
    if (dlg = "")
        return
    try {
        txt := dlg["gestureEdit"].Text
        if (GestureEngine.DefinitionMethod(GestureRecognizer.BindingName(txt)) = "template") {
            dlg["tx"].Text := GestureRecognizer.BindingName(txt)
            GesturePreview_SetPic(dlg["pic"], GesturePreview_Template(GestureRecognizer.BindingName(txt), 100, 80))
            return
        }
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

GestureMgr_OnTplRemoveSample(*) {
    row := GestureMgr_SelectedTplRow()
    if (row = "")
        return
    tmpl := Tpl_Get(row[1])
    if (!IsObject(tmpl) || tmpl.samples.Length < 2)
        return
    answer := InputBox(T("gesture.sample_index_prompt", tmpl.samples.Length),
        T("gesture.btn_delete_sample"), "w300 h120", "" . tmpl.samples.Length)
    if (answer.Result != "OK")
        return
    index := answer.Value + 0
    if (Tpl_RemoveSample(row[1], index))
        GestureMgr_RefreshTemplates()
}

GestureDlg_OnRecordSample(*) {
    dlg := GestureDlg_CurrentDlg()
    if (dlg = "")
        return
    name := GestureRecognizer.BindingName(dlg["gestureEdit"].Text)
    if (name = "") {
        dlg["hint"].Text := T("gesture.tpl_need_name")
        return
    }
    if GestureRecognizer.IsReservedDirectionName(name) {
        try dlg["hint"].Text := T("gesture.tpl_reserved_name")
        catch {
        }
        return
    }
    dlg["hint"].Text := T("gesture.tpl_recording")
    GestureEngine.ArmTplRecord((enc) => GestureDlg_OnSampleRecorded(enc))
}

GestureDlg_OnSampleRecorded(enc) {
    dlg := GestureDlg_CurrentDlg()
    if (dlg = "")
        return
    dlg["sample"] := enc
    try {
        if (dlg["methodDdl"].Value = 1)
            dlg["methodDdl"].Choose(2)
    } catch {
    }
    GesturePreview_SetPic(dlg["pic"], GesturePreview_Encoded(enc, 100, 80))
    dlg["hint"].Text := T("gesture.tpl_recorded")
}

; ---- 武装录制: 下一笔手势被截获并填入本对话框 ----
GestureDlg_ArmRecord(dlg) {
    try dlg["hint"].Text := T("gesture.recording_hint")
    catch {
    }
    GestureEngine.ArmRecord((g) => GestureDlg_OnRecorded(g))
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
    method := "direction"
    sample := ""
    try {
        layer := dlg["layerDdl"].Text
        gesture := dlg["gestureEdit"].Text
        action := dlg["actionEdit"].Text
        desc := dlg["descEdit"].Text
        method := ["direction", "template", "auto"][dlg["methodDdl"].Value]
        sample := dlg["sample"]
    } catch {
        return
    }
    if (Trim(gesture) = "" || Trim(action) = "") {
        try dlg["hint"].Text := T("gesture.dlg_empty")
        catch {
        }
        return
    }
    name := GestureRecognizer.BindingName(gesture)
    if ((method = "template" || method = "auto") && GestureRecognizer.IsReservedDirectionName(name)) {
        try dlg["hint"].Text := T("gesture.tpl_reserved_name")
        catch {
        }
        return
    }
    if ((method = "template" || method = "auto") && sample = "" && !IsObject(Tpl_Get(name))) {
        dlg["hint"].Text := T("gesture.tpl_need_record")
        return
    }
    gkey := GestureRecognizer.NormalizeFull(gesture)
    moved := mode = "edit" && (dlg["origLayer"] != layer
        || GestureRecognizer.NormalizeFull(dlg["origGesture"]) != gkey)
    if ((mode = "new" || moved) && GestureEngine.LayerHas(layer, gkey)) {
        if (MsgBox(T("gesture.confirm_overwrite", layer, gkey), T("gesture.overwrite_title"), 36) != "Yes")
            return
    }
    saved := GestureStore_SaveUnified(mode = "edit" ? dlg["origLayer"] : "",
        mode = "edit" ? dlg["origGesture"] : "", layer, gesture, action, desc, method, sample)
    if (saved) {
        GestureMgr_SetStatus(T("gesture.st_gesture_saved", layer, GestureRecognizer.Normalize(gesture), Trim(action)))
        GestureDlg_Close(true)
    } else {
        try dlg["hint"].Text := T("gesture.tpl_save_failed")
        catch {
        }
    }
}
