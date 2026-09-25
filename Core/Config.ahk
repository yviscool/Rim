#Requires AutoHotkey v2.0
#Warn All, Off

; === Config - 配置管理 (从 RunZ Core/Config.ahk 移植) ===

; 保存自动配置 (历史/输入文本)
SaveAutoConf() {
    global g_Conf, g_AutoConf, g_AutoConfFile, g_CurrentInput, g_HistoryCommands

    ; 防御: 启动早期/异常时序下 g_Conf 可能尚未赋值, 无配置可存直接返回
    ; (曾表现为每次启动后的 4 连 ERROR: WM_ACTIVATE→HideOrExit→SaveAutoConf×2)
    if (!IsSet(g_Conf) || !IsObject(g_Conf))
        return

    if (g_Conf["Config"]["SaveInputText"] = "1") {
        g_AutoConf.DeleteKey("Auto", "InputText")
        g_AutoConf.AddKey("Auto", "InputText", g_CurrentInput)
    }

    if (g_Conf["Config"]["SaveHistory"] = "1") {
        g_AutoConf.DeleteSection("History")
        g_AutoConf.AddSection("History")
        for index, element in g_HistoryCommands {
            if (element != "")
                g_AutoConf.AddKey("History", index, element)
        }
    }

    ; 有界重试: 磁盘/杀软锁定时最多等 300ms, 绝不无限 MsgBox 卡死重启链
    tries := 0
    Loop {
        tries++
        try g_AutoConf.Save()
        catch {
        }
        if (FileExist(g_AutoConfFile))
            break
        if (tries >= 3) {
            try FileAppend(A_Now . " WARN: auto conf save failed after 3 tries, skip`n", A_ScriptDir . "\Rim.error.log")
            catch {
            }
            break
        }
        Sleep(100)
    }
}

; 加载历史命令
LoadHistoryCommands() {
    global g_Conf, g_AutoConf, g_HistoryCommands

    historySize := g_Conf["Config"]["HistorySize"] + 0
    index := 0
    for key, value in g_AutoConf["History"] {
        if (StrLen(value) > 0) {
            g_HistoryCommands.Push(value)
            index++
            if (index = historySize)
                return
        }
    }
}

; 更新 SendTo 快捷方式 (引号防空格路径, 删除防缺失)
UpdateSendTo(create := true, overwrite := false) {
    sendToDir := StrReplace(A_StartMenu, "\Start Menu", "\SendTo\")
    lnkFilePath := sendToDir . "Rim.lnk"
    oldLnk := sendToDir . "RunZ.lnk"
    try FileDelete(oldLnk)

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
