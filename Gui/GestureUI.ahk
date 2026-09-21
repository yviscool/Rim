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
    mg := Gui(, "手势管理 - Rim")
    mg.SetFont("S10", "微软雅黑")
    tabs := mg.Add("Tab3", "w660 h430", ["手势", "字母模板", "黑名单", "设置"])

    ; ---- 手势页 ----
    tabs.UseTab(1)
    mg.Add("Text", "xm ym+30", "层:")
    filterDdl := mg.Add("DropDownList", "x+6 w180", ["全部"])
    filterDdl.OnEvent("Change", GestureMgr_OnFilter)
    mg.Add("Button", "x+10 w80", "录制新手势").OnEvent("Click", GestureMgr_OnRecordNew)
    mg.Add("Button", "x+6 w60", "新增").OnEvent("Click", GestureMgr_OnAdd)
    mg.Add("Button", "x+6 w60", "编辑").OnEvent("Click", GestureMgr_OnEdit)
    mg.Add("Button", "x+6 w60", "删除").OnEvent("Click", GestureMgr_OnDel)
    mg.Add("Button", "x+6 w80", "启用/禁用").OnEvent("Click", GestureMgr_OnToggle)
    mg.Add("Button", "x+6 w80", "禁用本层").OnEvent("Click", GestureMgr_OnLayerOff)
    lv := mg.Add("ListView", "xm y+8 w500 h300", ["层", "手势", "动作", "状态"])
    lv.ModifyCol(1, 90)
    lv.ModifyCol(2, 90)
    lv.ModifyCol(3, 250)
    lv.ModifyCol(4, 50)
    try lv.OnEvent("DoubleClick", GestureMgr_OnEdit)
    catch {
    }
    try lv.OnEvent("ItemFocus", GestureMgr_OnPreview)
    catch {
    }
    prevPic := mg.Add("Picture", "x+10 yp w120 h120 +Border +0xE")
    prevTx := mg.Add("Text", "xp y+4 w120 Center", "未选择")

    ; ---- 字母模板页 ----
    tabs.UseTab(2)
    mg.Add("Text", "xm ym+30 w640", "单笔字母/异形 (e/G/U/R/D/P/L/N/S/M/Z/B/J/h/X/3 及自录). 方向链优先命中, 未命中才走模板模糊匹配.")
    tplLv := mg.Add("ListView", "xm y+8 w500 h300", ["模板", "动作", "来源", "状态"])
    tplLv.ModifyCol(1, 60)
    tplLv.ModifyCol(2, 340)
    tplLv.ModifyCol(3, 60)
    tplLv.ModifyCol(4, 50)
    try tplLv.OnEvent("ItemFocus", GestureMgr_OnTplPreview)
    catch {
    }
    tplPic := mg.Add("Picture", "x+10 yp w120 h120 +Border +0xE")
    tplTx := mg.Add("Text", "xp y+4 w120 Center", "未选择")
    mg.Add("Button", "xm y+8 w110", "录制新模板").OnEvent("Click", GestureMgr_OnTplAdd)
    mg.Add("Button", "x+6 w110", "编辑动作").OnEvent("Click", GestureMgr_OnTplEdit)
    mg.Add("Button", "x+6 w90", "删除").OnEvent("Click", GestureMgr_OnTplDel)
    mg.Add("Button", "x+6 w80", "启用/禁用").OnEvent("Click", GestureMgr_OnTplToggle)
    mg.Add("Button", "x+6 w80", "追加样本").OnEvent("Click", GestureMgr_OnTplAppend)

    ; ---- 黑名单页 ----
    tabs.UseTab(3)
    mg.Add("Text", "xm ym+30 w640", "以下窗口禁用手势 (右键行为完全不变). 模式: exe/类名精确匹配(不分大小写), 或标题包含.")
    blLv := mg.Add("ListView", "xm y+8 w640 h300", ["屏蔽模式", "状态"])
    blLv.ModifyCol(1, 540)
    blLv.ModifyCol(2, 60)
    mg.Add("Button", "xm y+8 w90", "新增").OnEvent("Click", GestureMgr_OnBlAdd)
    mg.Add("Button", "x+6 w90", "删除").OnEvent("Click", GestureMgr_OnBlDel)
    mg.Add("Button", "x+6 w80", "启用/禁用").OnEvent("Click", GestureMgr_OnBlToggle)

    ; ---- 设置页 ----
    tabs.UseTab(4)
    cfgEnable := mg.Add("CheckBox", "xm ym+30", "启用手势")
    mg.Add("Text", "xm y+10", "触发键:")
    cfgTrigger := mg.Add("DropDownList", "x+6 w120", ["RButton", "MButton", "XButton1", "XButton2"])
    mg.Add("Text", "x+20", "未命中:")
    cfgNoMatch := mg.Add("DropDownList", "x+6 w120", ["swallow", "passthrough", "sound"])
    mg.Add("Text", "xm y+12", "进入手势距离:")
    cfgThreshold := mg.Add("Slider", "x+6 w180 Range10-60", 20)
    cfgThresholdTx := mg.Add("Text", "x+6 w40", "20")
    cfgThreshold.OnEvent("Change", (*) => GestureCfg_ShowVal("Threshold"))
    mg.Add("Text", "xm y+10", "方向采样步长:")
    cfgSegment := mg.Add("Slider", "x+6 w180 Range10-60", 30)
    cfgSegmentTx := mg.Add("Text", "x+6 w40", "30")
    cfgSegment.OnEvent("Change", (*) => GestureCfg_ShowVal("Segment"))
    mg.Add("Text", "xm y+10", "模板匹配阈值:")
    cfgTplTh := mg.Add("Slider", "x+6 w180 Range50-95", 75)
    cfgTplThTx := mg.Add("Text", "x+6 w40", "75")
    cfgTplTh.OnEvent("Change", (*) => GestureCfg_ShowVal("TplTh"))
    mg.Add("Text", "xm y+10", "轨迹线宽:")
    cfgTrailW := mg.Add("Slider", "x+6 w180 Range1-10", 5)
    cfgTrailWTx := mg.Add("Text", "x+6 w40", "5")
    cfgTrailW.OnEvent("Change", (*) => GestureCfg_ShowVal("TrailW"))
    mg.Add("Text", "xm y+10", "IgnoreKey (按住暂停, 空=关):")
    cfgIgnoreKey := mg.Add("Edit", "x+6 w100", "")
    cfgOSD := mg.Add("CheckBox", "xm y+12", "显示 OSD 提示")
    cfgTrail := mg.Add("CheckBox", "x+20", "显示轨迹线")
    cfgOnlyDef := mg.Add("CheckBox", "x+20", "仅限定应用")
    cfgTry := mg.Add("CheckBox", "xm y+10", "试笔模式 (只识别不执行)")
    cfgTry.OnEvent("Click", (*) => Gesture_SetTryMode(cfgTry.Value ? true : false))
    mg.Add("Button", "xm y+12 w110", "保存设置").OnEvent("Click", GestureCfg_OnSave)
    mg.Add("Text", "x+8 w200", "保存后即时生效 (触发键变更自动重绑).")
    mg.Add("Button", "xm y+10 w110", "导出手势包").OnEvent("Click", GesturePkg_OnExport)
    mg.Add("Button", "x+8 w110", "导入手势包").OnEvent("Click", GesturePkg_OnImport)
    try blLv.OnEvent("DoubleClick", GestureMgr_OnBlDel)
    catch {
    }

    tabs.UseTab()
    status := mg.Add("Text", "xm y+8 w640", "就绪. 动作语法: run|/key|/function|/<Action名>, 如 key|^t .")
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
            st := Gesture_ChainOff(row[1], row[2]) ? "禁用" : "启用"
            lv.Add("", row[1], row[2], row[3], st)
            count++
        }
        GestureMgr_SetStatus("共 " . count . " 条手势 (" . filter . "). 双击行可编辑.")
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
            blLv.Add("", pat, Gesture_BlOff(pat) ? "禁用" : "启用")
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
            st := Gesture_TplOff(row[1]) ? "禁用" : "启用"
            tplLv.Add("", row[1], row[2], row[3], st)
            count++
        }
        GestureMgr_SetStatus("共 " . count . " 个字母模板. 方向链优先, 模板只在链未命中时按阈值触发.")
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
        GestureMgr_SetStatus("先选中一个模板再编辑动作.")
        return
    }
    TplEditDialog(row[1], row[2])
}

GestureMgr_OnTplDel(*) {
    row := GestureMgr_SelectedTplRow()
    if (row = "") {
        GestureMgr_SetStatus("先选中一个模板再删除.")
        return
    }
    if (SubStr(row[3], 1, 2) = "内置") {
        GestureMgr_SetStatus("内置模板不可删除, 录制同名可覆盖.")
        return
    }    if (MsgBox("删除模板 [" . row[1] . "] 吗?", "确认删除", 36) != "Yes")
        return
    if (GestureStore_DelTemplate(row[1]))
        GestureMgr_SetStatus("已删除模板 [" . row[1] . "]")
    else
        GestureMgr_SetStatus("删除失败.")
    GestureMgr_RefreshTemplates()
}

; ---- 模板录制/编辑对话框: 名称+动作, 点录制后画一笔 ----
TplEditDialog(name, action) {
    global g_GestureMgr
    de := Gui(, name = "" ? "录制新模板" : "编辑模板动作")
    de.SetFont("S10", "微软雅黑")
    de.Add("Text", "xm ym", "模板名 (区分大小写, 如 e/G/3):")
    nameEdit := de.Add("Edit", "x+6 w120", name)
    if (name != "") {
        try nameEdit.Opt("+ReadOnly")
        catch {
        }
    }
    de.Add("Text", "xm y+10", "动作 (run|/key|/function|/<Action名>):")
    actionEdit := de.Add("Edit", "xm y+4 w490", action)
    de.Add("Button", "xm y+10 w110", "录制笔画").OnEvent("Click", TplDlg_OnRecord)
    saveBtn := de.Add("Button", "x+8 w100", "保存")
    de.Add("Button", "x+8 w100", "取消").OnEvent("Click", (*) => TplDlg_Close(false))
    hint := de.Add("Text", "xm y+8 w490", name = "" ? "填好名称动作后点 [录制笔画], 到任意窗口画一笔." : "改动作可直接保存; 重画点 [录制笔画].")
    tplDlgPic := de.Add("Picture", "xm y+6 w140 h110 +Border +0xE")
    tplDlgTx := de.Add("Text", "x+8 yp w300", "画一笔后此处显示形状")
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
        try dlg["hint"].Text := "先填模板名再录制."
        catch {
        }
        return
    }
    try dlg["hint"].Text := "录制中: 到任意窗口画一笔后松开 (Esc 取消)..."
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
        dlg["tx"].Text := "已录得笔画, 点保存写入."
        dlg["hint"].Text := "已录得笔画, 点保存写入."
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
        dlg["tx"].Text := "当前形状 (" . t.samples.Length . " 样本), 重画可替换."
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
        try dlg["hint"].Text := "模板名和动作都不能为空."
        catch {
        }
        return
    }
    if (InStr(nm, "=") || InStr(nm, "|") || InStr(nm, ":")) {
        try dlg["hint"].Text := "模板名不能含 = | : 字符."
        catch {
        }
        return
    }
    if (pts = "") {
        ; 只改动作: 沿用已有(内置/已存)样本
        t := Tpl_Get(nm)
        if (!IsObject(t)) {
            try dlg["hint"].Text := "新模板必须先 [录制笔画]."
            catch {
            }
            return
        }
        pts := Tpl_JoinSamples(t)
    }
    if (GestureStore_SetTemplate(nm, act, pts)) {
        GestureMgr_SetStatus("已保存模板 [" . nm . "] = " . act)
        TplDlg_Close(true)
    } else {
        try dlg["hint"].Text := "保存失败, 请检查 ini 写权限."
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
            info := "应用层 [" . f . "] 匹配:"
            if (app.exe != "")
                info .= " exe=" . app.exe
            if (app.cls != "")
                info .= " class=" . app.cls
            if (app.title != "")
                info .= " 标题含[" . app.title . "]"
            if (app.titleRx != "")
                info .= " 正则[" . app.titleRx . "]"
            if (app.noglobal)
                info .= " (禁用全局回退)"
            GestureMgr_SetStatus(info)
        }
    }
}

GestureMgr_SelectedGestureRow() {
    global g_GestureMgr
    try {
        lv := g_GestureMgr["lv"]
        row := lv.GetNext(0)
        if (row = 0)
            return ""
        return [lv.GetText(row, 1), lv.GetText(row, 2), lv.GetText(row, 3)]
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
    GestureEditDialog("new", "全局", "", "")
}

GestureMgr_OnRecordNew(*) {
    ; 先开空对话框并立即进入录制, 画完自动填入
    dlg := GestureEditDialog("new", "全局", "", "")
    if (IsObject(dlg))
        GestureDlg_ArmRecord(dlg)
}

GestureMgr_OnEdit(*) {
    row := GestureMgr_SelectedGestureRow()
    if (row = "") {
        GestureMgr_SetStatus("先选中一行再编辑.")
        return
    }
    GestureEditDialog("edit", row[1], row[2], row[3])
}

GestureMgr_OnDel(*) {
    row := GestureMgr_SelectedGestureRow()
    if (row = "") {
        GestureMgr_SetStatus("先选中一行再删除.")
        return
    }
    if (MsgBox("删除手势 [" . row[1] . "] " . row[2] . " 吗?", "确认删除", 36) != "Yes")
        return
    if (GestureStore_DelGesture(row[1], row[2]))
        GestureMgr_SetStatus("已删除 [" . row[1] . "] " . row[2])
    else
        GestureMgr_SetStatus("删除失败, 请检查 ini 写权限.")
    GestureMgr_RefreshFilter()
    GestureMgr_RefreshGestures()
}

GestureMgr_OnToggle(*) {
    row := GestureMgr_SelectedGestureRow()
    if (row = "") {
        GestureMgr_SetStatus("先选中一行再切换.")
        return
    }
    id := row[1] . ":" . row[2]
    off := !Gesture_ChainOff(row[1], row[2])
    if (GestureStore_SetDisabled(id, off))
        GestureMgr_SetStatus((off ? "已禁用 " : "已启用 ") . "[" . row[1] . "] " . row[2])
    else
        GestureMgr_SetStatus("切换失败.")
    GestureMgr_RefreshGestures()
}

GestureMgr_OnLayerOff(*) {
    f := GestureMgr_CurrentFilter()
    if (f = "全部" || f = "全局") {
        GestureMgr_SetStatus("按层过滤后才能整层禁用 (下拉选某一应用层).")
        return
    }
    id := "应用层:" . f
    off := !Gesture_LayerOff(f)
    if (GestureStore_SetDisabled(id, off))
        GestureMgr_SetStatus((off ? "已禁用整层 " : "已启用整层 ") . f)
    else
        GestureMgr_SetStatus("切换失败.")
    GestureMgr_RefreshGestures()
}

GestureMgr_OnTplToggle(*) {
    row := GestureMgr_SelectedTplRow()
    if (row = "") {
        GestureMgr_SetStatus("先选中一个模板再切换.")
        return
    }    id := "模板:" . row[1]
    off := !Gesture_TplOff(row[1])
    if (GestureStore_SetDisabled(id, off))
        GestureMgr_SetStatus((off ? "已禁用模板 " : "已启用模板 ") . row[1])
    else
        GestureMgr_SetStatus("切换失败.")
    GestureMgr_RefreshTemplates()
}

GestureMgr_OnTplAppend(*) {
    global g_TplMaxSamples
    row := GestureMgr_SelectedTplRow()
    if (row = "") {
        GestureMgr_SetStatus("先选中一个模板再追加样本.")
        return
    }
    t := Tpl_Get(row[1])
    if (!IsObject(t)) {
        GestureMgr_SetStatus("模板不存在.")
        return
    }
    maxS := 3
    try {
        if (g_TplMaxSamples + 0 > 0)
            maxS := g_TplMaxSamples + 0
    }
    if (t.samples.Length >= maxS) {
        GestureMgr_SetStatus("样本已满 (" . maxS . " 个), 删除重录可替换.")
        return
    }
    GestureMgr_SetStatus("追加样本: 给 [" . row[1] . "] 再画一笔 (已有 " . t.samples.Length . " 个)...")
    Gesture_ArmTplRecord((enc) => TplAppend_Save(row[1], enc))
}

TplAppend_Save(name, enc) {
    t := Tpl_Get(name)
    if (!IsObject(t)) {
        GestureMgr_SetStatus("模板不存在.")
        return
    }
    arr := []
    for _, samp in t.samples
        arr.Push(Tpl_Encode(samp))
    arr.Push(enc)
    if (GestureStore_SetTemplateSamples(name, t.action, arr))
        GestureMgr_SetStatus("已追加样本 [" . name . "], 现 " . arr.Length . " 个.")
    else
        GestureMgr_SetStatus("追加失败.")
    GestureMgr_RefreshTemplates()
}

GestureMgr_OnBlToggle(*) {
    global g_GestureMgr
    try {
        blLv := g_GestureMgr["blLv"]
        row := blLv.GetNext(0)
        if (row = 0) {
            GestureMgr_SetStatus("先选中一行再切换.")
            return
        }
        pat := blLv.GetText(row, 1)
        off := !Gesture_BlOff(pat)
        if (GestureStore_SetDisabled("黑名单:" . pat, off))
            GestureMgr_SetStatus((off ? "已禁用屏蔽 " : "已启用屏蔽 ") . pat)
        else
            GestureMgr_SetStatus("切换失败.")
        GestureMgr_RefreshBlacklist()
    } catch {
    }
}

GestureMgr_OnBlAdd(*) {
    res := InputBox("屏蔽模式 (exe/类名/标题片段), 如: GAME.EXE", "黑名单新增")
    if (res.Result != "OK")
        return
    pat := Trim(res.Value)
    if (pat = "")
        return
    if (GestureStore_AddBlacklist(pat))
        GestureMgr_SetStatus("已屏蔽: " . pat)
    else
        GestureMgr_SetStatus("新增失败.")
    GestureMgr_RefreshBlacklist()
}

GestureMgr_OnBlDel(*) {
    global g_GestureMgr
    try {
        blLv := g_GestureMgr["blLv"]
        row := blLv.GetNext(0)
        if (row = 0) {
            GestureMgr_SetStatus("先选中一行再删除.")
            return
        }
        pat := blLv.GetText(row, 1)
        if (GestureStore_DelBlacklist(pat))
            GestureMgr_SetStatus("已移除屏蔽: " . pat)
        else
            GestureMgr_SetStatus("删除失败.")
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
                GestureMgr_SetStatus("保存失败: " . k)
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
        GestureMgr_SetStatus("设置已保存并生效.")
    } catch {
        GestureMgr_SetStatus("保存失败.")
    }
}

GesturePkg_OnExport(*) {
    path := FileSelect("S", "", "导出手势包", "手势包 (*.ini)")
    if (path = "")
        return
    if (SubStr(path, -3) != ".ini")
        path .= ".ini"
    if (GesturePkg_Export(path))
        GestureMgr_SetStatus("已导出: " . path)
    else
        GestureMgr_SetStatus("导出失败.")
}

GesturePkg_OnImport(*) {
    path := FileSelect("", "", "导入手势包", "手势包 (*.ini)")
    if (path = "" || !FileExist(path))
        return
    ans := MsgBox("同名已存在项如何处理?`n是=覆盖全部, 否=跳过已存在", "导入手势包", "YNC")
    if (ans = "Cancel")
        return
    res := GesturePkg_Import(path, ans = "Yes")
    GestureMgr_SetStatus("导入完成: 新增 " . res[1] . " 跳过 " . res[2] . " 覆盖 " . res[3])
    GestureCfg_Load()
    GestureMgr_RefreshAll()
}

; ==================== 新增/编辑对话框 ====================
; 返回对话框 refs Map (供录制回调), 失败返回 ""
GestureEditDialog(mode, layer, gesture, action) {
    global g_GestureMgr
    try {
        if (IsObject(g_GestureMgr["editGui"])) {
            try g_GestureMgr["editGui"]["gui"].Destroy()
            catch {
            }
        }
    }
    de := Gui(, mode = "new" ? "新增手势" : "编辑手势")
    de.SetFont("S10", "微软雅黑")
    de.Add("Text", "xm ym", "层:")
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
    de.Add("Button", "x+8 w110", "新建应用层...").OnEvent("Click", GestureDlg_OnNewApp)
    de.Add("Text", "xm y+10", "手势 (R/L/U/D/UR/UL/DR/DL/_连接, 可加 Ctrl+/Alt+/Shift+ 前缀):")
    gestureEdit := de.Add("Edit", "xm y+4 w280", gesture)
    de.Add("Button", "x+8 w70", "录制").OnEvent("Click", GestureDlg_OnRecord)
    dlgPic := de.Add("Picture", "x+8 yp w100 h80 +Border +0xE")
    dlgTx := de.Add("Text", "xp y+2 w100 Center", "")
    gestureEdit.OnEvent("Change", (*) => GestureDlg_OnPreview())
    de.Add("Text", "xm y+10", "动作 (run|/key|/function|/<Action名>):")
    actionEdit := de.Add("Edit", "xm y+4 w490", action)
    de.Add("Text", "xm y+4 w490", "示例: key|^t 新建标签 | <SP_Back> 后退 | run|notepad.exe 记事本")
    saveBtn := de.Add("Button", "xm y+10 w100", "保存")
    de.Add("Button", "x+8 w100", "取消").OnEvent("Click", (*) => GestureDlg_Close(false))
    hint := de.Add("Text", "xm y+6 w490", mode = "new" ? "点 [录制] 后到任意窗口画一笔, 松开即填入." : "")
    saveBtn.OnEvent("Click", (*) => GestureDlg_OnSave(mode))

    dlg := Map("gui", de, "layers", layers, "layerDdl", layerDdl
        , "gestureEdit", gestureEdit, "actionEdit", actionEdit, "hint", hint, "mode", mode
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
    r1 := InputBox("应用层名称 (如 TotalCommander)", "新建应用层")
    if (r1.Result != "OK" || Trim(r1.Value) = "")
        return
    appName := Trim(r1.Value)
    if (InStr(appName, ":") || InStr(appName, "=") || InStr(appName, "|")) {
        MsgBox("应用层名称不能含 : = | 字符.", "新建应用层", 48)
        return
    }
    r2 := InputBox("匹配进程名 (如 TOTALCMD.EXE, 可空)", "新建应用层 - " . appName)
    if (r2.Result != "OK")
        return
    r3 := InputBox("匹配窗口类 (如 TTOTAL_CMD, 可空)", "新建应用层 - " . appName)
    if (r3.Result != "OK")
        return
    r4 := InputBox("匹配标题片段 (包含即命中, 可空)", "新建应用层 - " . appName)
    if (r4.Result != "OK")
        return
    r5 := InputBox("匹配标题正则 (如 (?i)chrome, 可空)", "新建应用层 - " . appName)
    if (r5.Result != "OK")
        return
    if (Trim(r2.Value) = "" && Trim(r3.Value) = "" && Trim(r4.Value) = "" && Trim(r5.Value) = "") {
        MsgBox("进程名/窗口类/标题片段/标题正则至少填一个.", "新建应用层", 48)
        return
    }
    noG := MsgBox("禁用全局手势回退 (仅用本层手势) 吗?", "新建应用层 - " . appName, 36)
    if (!GestureStore_SetAppMatch(appName, r2.Value, r3.Value, r4.Value, r5.Value, noG = "Yes" ? "1" : "0")) {
        MsgBox("写入失败, 请检查 ini 写权限.", "新建应用层", 16)
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
    try dlg["hint"].Text := "录制中: 到任意窗口按住右键画一笔后松开 (Esc 取消)..."
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
        dlg["hint"].Text := "已录得: " . g . " , 填写动作后保存."
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
    try {
        layer := dlg["layerDdl"].Text
        gesture := dlg["gestureEdit"].Text
        action := dlg["actionEdit"].Text
    } catch {
        return
    }
    if (Trim(gesture) = "" || Trim(action) = "") {
        try dlg["hint"].Text := "手势和动作都不能为空."
        catch {
        }
        return
    }
    gkey := Gesture_NormalizeFull(gesture)
    if (mode = "new" && Gesture_LayerHas(layer, gkey)) {
        if (MsgBox("[" . layer . "] 已有 " . gkey . " , 覆盖吗?", "手势已存在", 36) != "Yes")
            return
    }
    if (GestureStore_SetGesture(layer, gesture, action)) {
        GestureMgr_SetStatus("已保存 [" . layer . "] " . Gesture_Normalize(gesture) . " = " . Trim(action))
        GestureDlg_Close(true)
    } else {
        try dlg["hint"].Text := "保存失败, 请检查 ini 写权限."
        catch {
        }
    }
}
