#Requires AutoHotkey v2.0
#Warn All, Off

; === Tray - 托盘菜单构建 (可重复调用, 供语言实时切换) ===
; 构建后悬停提示带构建号与语言 (可观测性); 试笔复选态按引擎现状恢复.
; 注意: 回调函数 (ActivateRunZ/ShowGestureManager/...) 由主程序提供,
; 本文件只引用名, 不定义 (独立加载探针需自行打桩).

BuildTrayMenu() {
    global g_Conf, g_SkinConf, g_BuildTag
    if ((g_SkinConf.Has("ShowTrayIcon") ? g_SkinConf["ShowTrayIcon"] : "1") != "1")
        return false
    A_TrayMenu.Delete()
    if (g_Conf.Get("Config", "RunInBackground", "1") = "1") {
        A_TrayMenu.Add(T("tray.show"), ActivateRunZ)
        A_TrayMenu.Default := T("tray.show")
        A_TrayMenu.ClickCount := 1
    }
    A_TrayMenu.Add(T("tray.gesture"), ShowGestureManager)
    A_TrayMenu.Add(T("tray.config"), VimConfig_Show)
    A_TrayMenu.Add()
    A_TrayMenu.Add(T("tray.suspend"), ToggleSuspend)
    A_TrayMenu.Add(T("tray.restart"), RestartRunZ)
    A_TrayMenu.Add(T("tray.exit"), ExitRunZ)
    ; 试笔复选态恢复 (重建会丢勾选)
    try {
        if (Gesture_IsTryMode())
            A_TrayMenu.ToggleCheck(T("gesture.tray_try"))
    } catch {
    }
    try A_IconTip := "Rim " . g_BuildTag . " (" . I18nGetLang() . ")"
    catch {
    }
    return true
}

; ---- 语言切换后即时应用到托盘 (配置中心保存成功后调用) ----
; 返回 true 表示托盘已按新语言重建
I18nApplyTray(lang) {
    I18nSetLang(lang, false)
    return BuildTrayMenu()
}
