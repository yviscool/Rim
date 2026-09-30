#Requires AutoHotkey v2.0
#Warn All, Off

; === Config - 配置管理 (从 RunZ Core/Config.ahk 移植) ===

; 保存自动配置 (历史/输入文本)
; 双入口: SaveAutoConf() 只打脏标记 + 800ms 延迟批量写 (热路径);
; SaveAutoConfNow() 同步落盘 (退出/重启/重载前必须调它, 延迟写等不到 ExitApp).
; 落盘经 EasyIni.Save (tmp 写后原子改名), 无 Sleep 重试阻塞.
global g_AutoConfDirty := false
MarkAutoConfDirty() {
    global g_AutoConfDirty
    g_AutoConfDirty := true
    try SetTimer(SaveAutoConfDeferred, -800)
    catch Error as e {
        try RimTryLog("MarkAutoConfDirty", e)
        catch {
        }
    }
}

SaveAutoConfDeferred() {
    global g_AutoConfDirty
    if (!g_AutoConfDirty)
        return
    g_AutoConfDirty := false
    SaveAutoConfNow()
}

SaveAutoConf() {
    MarkAutoConfDirty()
}

SaveAutoConfNow() {
    global g_Conf, g_AutoConf, g_AutoConfFile, g_CurrentInput, g_HistoryCommands

    ; 防御: 启动早期/异常时序下 g_Conf 可能尚未赋值, 无配置可存直接返回
    ; (曾表现为每次启动后的 4 连 ERROR: WM_ACTIVATE→HideOrExit→SaveAutoConf×2)
    if (!IsSet(g_Conf) || !IsObject(g_Conf))
        return
    if (!IsSet(g_AutoConf) || !IsObject(g_AutoConf) || !IsSet(g_AutoConfFile) || g_AutoConfFile = "")
        return

    lastErr := ""
    try {
        if (CfgGet("Config", "SaveInputText", "0") = "1") {
            g_AutoConf.DeleteKey("Auto", "InputText")
            g_AutoConf.AddKey("Auto", "InputText", g_CurrentInput)
        }

        if (CfgGet("Config", "SaveHistory", "1") = "1") {
            g_AutoConf.DeleteSection("History")
            g_AutoConf.AddSection("History")
            for index, element in g_HistoryCommands {
                if (element != "")
                    g_AutoConf.AddKey("History", index, element)
            }
        }
    } catch Error as e {
        lastErr := e.Message
        try RimTryLog("SaveAutoConfNow.build", e)
        catch {
        }
    }
    if (lastErr != "") {
        global g_AutoConfLastError
        g_AutoConfLastError := lastErr
        return
    }
    ; 原子替换在 EasyIni.Save 内部 (tmp+改名); 单次写, 失败只记错不重试阻塞
    try {
        g_AutoConf.Save()
    } catch Error as e {
        global g_AutoConfLastError
        g_AutoConfLastError := e.Message
        try RimTryLog("SaveAutoConfNow.save", e, g_AutoConfFile)
        catch {
        }
        return
    }
    if (!FileExist(g_AutoConfFile)) {
        global g_AutoConfLastError
        g_AutoConfLastError := "save missing: " . g_AutoConfFile
        try RimLog("WARN", "auto conf save missing file, skip: " . g_AutoConfFile)
        catch {
        }
    }
}

; 加载历史命令
LoadHistoryCommands() {
    global g_Conf, g_AutoConf, g_HistoryCommands

    if (!IsSet(g_AutoConf) || !IsObject(g_AutoConf))
        return
    historySize := 100
    try historySize := Integer(CfgGet("Config", "HistorySize", "100"))
    catch Error as e {
        try RimTryLog("LoadHistoryCommands.size", e)
        catch {
        }
    }
    ; 缺失 History 节显式 Has 检查: 无节即空历史, 不得按缺失键抛错
    try {
        if (!HasMethod(g_AutoConf, "HasSection") || !g_AutoConf.HasSection("History"))
            return
    } catch {
        return
    }
    index := 0
    try {
        for key, value in g_AutoConf["History"] {
            if (StrLen(value) > 0) {
                g_HistoryCommands.Push(value)
                index++
                if (index = historySize)
                    return
            }
        }
    } catch Error as e {
        try RimTryLog("LoadHistoryCommands.read", e)
        catch {
        }
    }
}

; 更新 SendTo 快捷方式 (引号防空格路径, 删除防缺失)
UpdateSendTo(create := true, overwrite := false) {
    sendToDir := StrReplace(A_StartMenu, "\Start Menu", "\SendTo\")
    lnkFilePath := sendToDir . "Rim.lnk"

    if (!create) {
        try FileDelete(lnkFilePath)
        return
    }
    if (!overwrite && FileExist(lnkFilePath))
        return

    target := A_IsCompiled ? A_ScriptFullPath : A_AhkPath
    args := A_IsCompiled ? "" : '"' . A_ScriptFullPath . '"'
    icoPath := A_ScriptDir . "\Assets\Rim.ico"
    try {
        FileCreateShortcut(target, lnkFilePath, A_ScriptDir, args, "Rim", FileExist(icoPath) ? icoPath : "")
    }
}

; 更新启动快捷方式
UpdateStartupLnk(create := true, overwrite := false) {
    lnkFilePath := A_Startup "\Rim.lnk"
    if (!create) {
        try FileDelete(lnkFilePath)
        return
    }
    if (!FileExist(lnkFilePath) || overwrite) {
        target := A_IsCompiled ? A_ScriptFullPath : A_AhkPath
        args := A_IsCompiled ? "--hide" : '"' A_ScriptFullPath '" --hide'
        FileCreateShortcut(target, lnkFilePath
            , A_ScriptDir, args, "Rim", A_ScriptDir "\Assets\Rim.ico")
    }
}
