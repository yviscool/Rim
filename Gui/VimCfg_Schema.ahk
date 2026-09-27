#Requires AutoHotkey v2.0
#Warn All, Off

; === VimCfg_Schema - 配置中心 schema 表单引擎 (生成/构建/收集/校验联动) ===
; 中央表见 Core/ConfigSchema.ahk; 入口见 VimConfigUI.ahk
; ==================== 启动器页 ====================
; specs 声明式表单: 以 g_CfgSchema 中央表为准生成 (label/help 走 i18n),
; 运行侧默认值收敛到 CfgGet；此处只剩分组, 不再手写类型/min/max
VimCfg_SpecsFor(secs) {
    global g_CfgSchema
    out := []
    for spec in g_CfgSchema {
        keep := false
        for want in secs {
            if (spec["sec"] = want) {
                keep := true
                break
            }
        }
        if (!keep)
            continue
        item := Map("sec", spec["sec"], "key", spec["key"], "type", spec["type"]
            , "label", T(spec["label"]), "scope", CfgScope(spec["sec"], spec["key"]))
        if (spec.Has("min"))
            item["min"] := spec["min"]
        if (spec.Has("max"))
            item["max"] := spec["max"]
        if (spec.Has("options"))
            item["options"] := spec["options"]
        if (spec.Has("help"))
            item["help"] := T(spec["help"])
        out.Push(item)
    }
    return out
}

VimCfg_LauncherSpecs() {
    return VimCfg_SpecsFor(["Config", "Gui"])
}

; ==================== 雷达页 (独立 tab: 启动器页 35 项已爆框, 雷达 9 项搬出来) ====================
VimCfg_StatsBallSpecs() {
    return VimCfg_SpecsFor(["StatsBall"])
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
        ; 聚焦即在警告条露出该项 help (失焦由下次 RefreshWarnBar 恢复); 绑不上不拦
        try ctl.OnEvent("Focus", VimCfg_SpecHelpBind(sp))
        catch {
        }
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

; specs 帮助: 聚焦控件即在警告条露出该项 help
VimCfg_SpecHelpBind(sp) {
    return (*) => VimCfg_ShowHelp(sp)
}

VimCfg_ShowHelp(sp) {
    global g_VimCfg
    if (!sp.Has("help") || !g_VimCfg.Has("warnbar"))
        return
    try g_VimCfg["warnbar"].Value := "ℹ " . sp["help"]
    catch {
    }
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
    ; 实时校验: 非法值照常记 dirty (可改回销账), 但进 specErr 拦保存
    errmsg := CfgValidate(sp["sec"], sp["key"], val)
    if (errmsg != "") {
        if (!g_VimCfg.Has("specErr"))
            g_VimCfg["specErr"] := Map()
        g_VimCfg["specErr"][sk] := errmsg
    } else if (g_VimCfg.Has("specErr") && g_VimCfg["specErr"].Has(sk))
        g_VimCfg["specErr"].Delete(sk)
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

