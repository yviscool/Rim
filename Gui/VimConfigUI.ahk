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
    g.Add("Button", "x+10 w110", T("cfg.undo")).OnEvent("Click", VimCfg_UndoLast)
    g.Add("Button", "x+10 w100", T("cfg.profile")).OnEvent("Click", VimCfg_ProfileShow)
    g.Add("Text", "x+14 yp+6 w330", T("cfg.save_hint"))
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
