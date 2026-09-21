#Requires AutoHotkey v2.0
#Warn All, Off

; === Files - 文件加载和索引 (从 RunZ Core/Files.ahk 移植) ===

; 生成搜索文件列表 (对齐原版: %dir% 动态解引用支持任意 A_ 变量)
GenerateSearchFileList() {
    global g_SearchFileList, g_Conf

    try FileDelete(g_SearchFileList)

    searchFileType := g_Conf.Get("Config", "SearchFileType", "*.exe | *.lnk")

    for dirIndex, dir in StrSplit(g_Conf.Get("Config", "SearchFileDir", ""), " | ") {
        dir := Trim(dir)
        if (dir = "")
            continue
        searchPath := ResolveSearchDir(dir)

        for extIndex, ext in StrSplit(searchFileType, " | ") {
            ext := Trim(ext)
            if (ext = "")
                continue
            loop files, searchPath "\" ext, "R" {
                if (g_Conf.Get("Config", "SearchFileExclude", "") != ""
                    && RegExMatch(A_LoopFileFullPath, g_Conf.Get("Config", "SearchFileExclude", "")))
                    continue
                FileAppend("file | " A_LoopFileFullPath "`n", g_SearchFileList)
            }
        }
    }
}

; 解析搜索目录: 支持常用 A_ 变量 + %VAR% 环境变量 (无动态解引用, 本构建加载安全)
ResolveSearchDir(dir) {
    dir := Trim(dir)
    ; A_xxx 内置变量 (显式表, 不用 %dir% 动态取值)
    if (SubStr(dir, 1, 2) = "A_") {
        if (dir = "A_ScriptDir")
            return A_ScriptDir
        else if (dir = "A_Temp")
            return A_Temp
        else if (dir = "A_Desktop")
            return A_Desktop
        else if (dir = "A_StartMenu")
            return A_StartMenu
        else if (dir = "A_Programs")
            return A_Programs
        else if (dir = "A_ProgramsCommon")
            return A_ProgramsCommon
        else if (dir = "A_StartMenuCommon")
            return A_StartMenuCommon
        else if (dir = "A_Startup")
            return A_Startup
        else if (dir = "A_AppData")
            return A_AppData
        else if (dir = "A_AppDataCommon")
            return A_AppDataCommon
        else if (dir = "A_DesktopCommon")
            return A_DesktopCommon
        else if (dir = "A_MyDocuments")
            return A_MyDocuments
        else if (dir = "A_WinDir")
            return A_WinDir
        else if (dir = "A_ProgramFiles")
            return A_ProgramFiles
        else
            return dir
    }
    ; %环境变量% 展开
    if (InStr(dir, "%"))
        dir := EnvGet(RegExReplace(dir, "^%([^%]+)%.*", "$1"))
    return dir
}

; 添加命令到全局列表
AddCommand(element) {
    global g_Commands, g_CommandObjects, g_SkinConf, g_Conf

    g_Commands.Push(element)

    cmdObj := Map()
    cmdObj["raw"] := element

    splitedElement := StrSplit(element, " | ")

    if (splitedElement[1] = "file") {
        SplitPath(splitedElement[2], &fileName, , , &fileNameNoExt)

        cmdObj["type"] := "file"
        cmdObj["typeLabel"] := g_SkinConf.Has("HideCol2") && g_SkinConf["HideCol2"] = "1" ? "" : Chr(0x6587) . Chr(0x4EF6) . " | "
        cmdObj["fileName"] := fileName
        cmdObj["fileNameNoExt"] := fileNameNoExt
        fileDir := ""
        try SplitPath(splitedElement[2], , &fileDir)
        cmdObj["fileDir"] := fileDir
        cmdObj["extra"] := splitedElement.Length >= 3 ? splitedElement[3] : ""

        ; 对齐原版: ShowFileExt=1 显示 fileName(带扩展名), 否则 fileNameNoExt; 绝不显示全路径
        showExt := false
        try showExt := (g_Conf.Get("Config", "ShowFileExt", "0") = "1")
        if (showExt)
            cmdObj["elementToShow"] := "file | " . fileName . (cmdObj["extra"] ? " | " . cmdObj["extra"] : "")
        else
            cmdObj["elementToShow"] := "file | " . fileNameNoExt . (cmdObj["extra"] ? " | " . cmdObj["extra"] : "")

        cmdObj["elementToSearch"] := fileNameNoExt
        if (cmdObj["extra"])
            cmdObj["elementToSearch"] .= " " . cmdObj["extra"]
        try {
            if (g_Conf.Get("Config", "SearchFullPath", "0") = "1")
                cmdObj["elementToSearch"] := StrReplace(cmdObj["fileDir"], "\", " ") . " " . cmdObj["elementToSearch"]
        }
    } else if (splitedElement.Length >= 4
        && (splitedElement[2] = "file" || splitedElement[2] = "function" || splitedElement[2] = "cmd" || splitedElement[2] = "url" || splitedElement[2] = "run")) {
        ; 四段式: key | type | cmd | desc (来自 [Commands] key=type|cmd|desc)
        cmdKey := splitedElement[1]
        cmdType := splitedElement[2]
        cmdCmd := splitedElement[3]
        extra := splitedElement[4]
        if (splitedElement.Length > 4) {
            Loop splitedElement.Length - 4
                extra .= " | " . splitedElement[4 + A_Index]
        }
        cmdObj["key"] := cmdKey
        cmdObj["type"] := cmdType
        cmdObj["typeLabel"] := (g_SkinConf.Has("HideCol2") && g_SkinConf["HideCol2"] = "1") ? "" : MapTypeLabel(cmdType)
        cmdObj["extra"] := extra

        ; 显示三段式: 类型 | 别名 | 描述 (与 Search 侧一致)
        cmdObj["elementToShow"] := cmdType . " | " . cmdKey
        if (extra)
            cmdObj["elementToShow"] .= " | " . extra

        ; key 必须进可搜索文本, 否则别名命令(如 settings)搜不到
        cmdObj["elementToSearch"] := cmdKey . " " . StrReplace(StrReplace(cmdCmd, "/", " "), "\", " ")
        if (extra)
            cmdObj["elementToSearch"] .= " " . extra
    } else {
        cmdObj["type"] := splitedElement[1]
        cmdObj["typeLabel"] := (g_SkinConf.Has("HideCol2") && g_SkinConf["HideCol2"] = "1") ? "" : MapTypeLabel(splitedElement[1])
        cmdObj["extra"] := splitedElement.Length >= 3 ? splitedElement[3] : ""

        cmdObj["elementToShow"] := splitedElement[1] . " | " . splitedElement[2]
        if (cmdObj["extra"])
            cmdObj["elementToShow"] .= " | " . cmdObj["extra"]

        cmdObj["elementToSearch"] := StrReplace(splitedElement[2], "/", " ")
        cmdObj["elementToSearch"] := StrReplace(cmdObj["elementToSearch"], "\", " ")
        if (cmdObj["extra"])
            cmdObj["elementToSearch"] .= " " . cmdObj["extra"]
    }

    g_CommandObjects.Push(cmdObj)
}

; 类型标签映射
MapTypeLabel(type) {
    if (type = "file")
        return Chr(0x6587) . Chr(0x4EF6) . " | "
    else if (type = "function")
        return Chr(0x529F) . Chr(0x80FD) . " | "
    else if (type = "cmd")
        return Chr(0x547D) . Chr(0x4EE4) . " | "
    else if (type = "url")
        return Chr(0x7F51) . Chr(0x5740) . " | "
    else if (type = "run")
        return Chr(0x8FD0) . Chr(0x884C) . " | "
    return ""
}

; 主加载器
LoadFiles(loadRank := true) {
    global g_Commands, g_CommandObjects, g_FallbackCommands, g_ExcludedCommands
    global g_ExcludedCommandsObj, g_AutoConf, g_Conf, g_Plugins, g_UserFileList
    global g_SearchFileList, g_SkinConf

    g_Commands := []
    g_CommandObjects := []
    g_FallbackCommands := []
    g_ExcludedCommands := ""
    g_ExcludedCommandsObj := Map()

    ; 加载排名: 先收集排序, 待新鲜索引建成后再合并
    ; (已从配置/插件中删除的旧条目不再复活, 避免 calc/google 类遮挡重现)
    rankElements := []
    if (loadRank) {
        rankString := ""
        for command, rank in g_AutoConf["Rank"] {
            if (StrLen(command) > 0) {
                ; v2 字符串与数字比较会抛错, 先判整 (原版 v1 自动转 0 进排除)
                if (IsInteger(rank) && rank >= 1)
                    rankString .= rank "`t" command "`n"
                else {
                    g_ExcludedCommands .= command "`n"
                    g_ExcludedCommandsObj[command] := true
                }
            }
        }

        if (rankString != "") {
            rankString := Sort(rankString, "R N")
            Loop Parse, rankString, "`n" {
                if (A_LoopField = "")
                    continue
                _parts := StrSplit(A_LoopField, "`t")
                if (_parts.Length < 2)
                    continue
                ; Rank 键原样回放, 不做格式改写 (保证 ChangeRank 键稳定)
                rankElements.Push(_parts[2])
            }
        }
    }

    ; 加载配置中的命令: 兼容 [Command](原版) 与 [Commands](现版)
    ; value 形如 type|cmd|desc, 统一成 "key | type | cmd | desc" 四段式
    cmdSection := g_Conf.HasSection("Commands") ? g_Conf["Commands"] : Map()
    if (g_Conf.HasSection("Command")) {
        for _k, _v in g_Conf["Command"]
            if !cmdSection.Has(_k)
                cmdSection[_k] := _v
    }
    for key, value in cmdSection {
        if (value != "")
            AddCommand(key . " | " . RegExReplace(value, "\s*\|\s*", " | "))
        else
            AddCommand(key)
    }

    ; 加载插件: 直调 RegisterPlugin_X (本构建无 IsFunc; 缺失走 OnError 网记日志继续)
    ; Vim 系插件走引擎注册, 不在这里重复跑 (漏网会在引擎创建前撞墙, 见 StrokePlus)
    vimOnly := Map("General", 1, "Explorer", 1, "TCCompare", 1, "WinMerge", 1
        , "BeyondCompare4", 1, "Foobar2000", 1, "TCDialog", 1, "TotalCommander", 1
        , "MicrosoftExcel", 1, "VimEditor", 1, "VimEditorAdapters", 1, "StrokePlus", 1
        , "VimDConfig", 1)
    for index, element in g_Plugins {
        if (vimOnly.Has(element))
            continue
        funcName := "RegisterPlugin_" element
        %funcName%()
    }

    ; 加载回退命令: 全部收录 (原版按顺序, 第一项为回车默认)
    ; 不做 IsFunc/IsLabel 过滤 — 别名在 RunCommand 时再解析, 保证无结果时总有显示
    g_FallbackCommands := []
    if (g_Conf.HasSection("FallbackCommand")) {
        for key, value in g_Conf["FallbackCommand"] {
            ; key 即 "function | Xxx | desc" (裸键行 value=""), value 非空时为 "key=..." 形式则拼接
            fb := (value != "") ? (key " | " value) : key
            if (Trim(fb) != "")
                g_FallbackCommands.Push(fb)
        }
    }
    if (g_FallbackCommands.Length = 0)
        g_FallbackCommands.Push("function | AhkRun | Run with Ahk Run()")

    ; 加载用户自动函数 (文件存在即调, 缺失走 OnError 网; 本构建无 IsFunc)
    if FileExist(A_ScriptDir "\Conf\UserFunctionsAuto.txt") {
        userFunctionLabel := "UserFunctionsAuto"
        %userFunctionLabel%()
    }

    ; 加载用户文件列表 (UTF-8 显式读, 防 Loop read 吞行)
    if FileExist(g_UserFileList)
        for _line in ReadFileLines(g_UserFileList) {
            if (Trim(_line) != "")
                AddCommand(_line)
        }

    ; 加载搜索文件列表
    if FileExist(g_SearchFileList)
        for _line in ReadFileLines(g_SearchFileList) {
            if (Trim(_line) != "")
                AddCommand(_line)
        }

    ; 加载控制面板函数
    if (g_Conf.Get("Config", "LoadControlPanelFunctions", "0") = "1" && FileExist(A_ScriptDir "\Core\ControlPanelFunctions.txt"))
        for _line in ReadFileLines(A_ScriptDir "\Core\ControlPanelFunctions.txt") {
            if (Trim(_line) != "")
                AddCommand(_line)
        }

    ; 合并排名: 仅仍存在于新鲜索引的键参与置顶, 僵尸键跳过 (下次 Ctrl+R 清理)
    if (rankElements.Length > 0) {
        freshSet := Map()
        for _el in g_Commands
            freshSet[_el] := true
        ranked := []
        for _re in rankElements {
            if (freshSet.Has(_re)) {
                ranked.Push(_re)
                freshSet.Delete(_re)
            }
        }
        if (ranked.Length > 0) {
            rest := []
            for _el in g_Commands {
                if (freshSet.Has(_el))
                    rest.Push(_el)
            }
            g_Commands := []
            g_CommandObjects := []
            for _el in ranked
                AddCommand(_el)
            for _el in rest
                AddCommand(_el)
        }
    }
}

; 注册函数命令的辅助函数 (RunZ 的 @ 函数, v2双兼容; 本构建无 IsFunc, 直接收录)
RegCmd(label, info, fallback := false, key := "") {
    AddCommand("function | " . label . " | " . info)
    if (key != "") {
        try BindKey(key, MakeCb(label))
    }
    if (fallback) {
        global g_FallbackCommands
        g_FallbackCommands.Push("function | " . label . " | " . info)
    }
}

; 注: v1 的 @() 在 v2 中是非法的函数名, 已由 RegCmd() 替代
; 老式 UserFunctionsAuto.txt 如含 "@(...)" 调用, 请批量替换为 "RegCmd(...)"

; 调整命令权重
ChangeRank(cmd, show := false, inc := 1) {
    global g_AutoConf, g_ExcludedCommands, g_ExcludedCommandsObj

    splitedCmd := StrSplit(cmd, " | ")
    if (splitedCmd.Length >= 5)
        cmd := splitedCmd[1] " | " splitedCmd[2] " | " splitedCmd[3] " | " splitedCmd[4]
    else if (splitedCmd.Length >= 4 && splitedCmd[1] = "function")
        cmd := splitedCmd[1] " | " splitedCmd[2] " | " splitedCmd[3]

    cmdRank := g_AutoConf.GetValue("Rank", cmd)
    if cmdRank is integer {
        g_AutoConf.DeleteKey("Rank", cmd)
        cmdRank += inc
    } else {
        cmdRank := inc
    }

    if (cmdRank != 0 && cmd != "") {
        if (cmdRank < 0) {
            cmdRank := -1
            g_ExcludedCommands .= cmd "`n"
            g_ExcludedCommandsObj[cmd] := true
        }
        g_AutoConf.AddKey("Rank", cmd, cmdRank)
    } else {
        cmdRank := 0
    }

    if (show)
        ToolTip("Rank of " cmd " adjusted to " cmdRank)
}
