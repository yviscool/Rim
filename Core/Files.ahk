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

    ; 幂等去重检查 (防止重复追加同名指令)
    for existing in g_Commands {
        if (existing = element)
            return
    }

    g_Commands.Push(element)

    cmdObj := Map()
    cmdObj["raw"] := element

    splitedElement := StrSplit(element, " | ")

    if (splitedElement[1] = "file") {
        SplitPath(splitedElement[2], &fileName, , , &fileNameNoExt)

        cmdObj["type"] := "file"
        cmdObj["typeLabel"] := g_SkinConf.Has("HideCol2") && g_SkinConf["HideCol2"] = "1" ? "" : TypeLabel("file")
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
    } else if (CmdLine_IsFourSeg(splitedElement)) {
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

; 类型标签映射 (经 TypeLabel 走语言包; 原先 Chr(0x..) 硬编码中文)
MapTypeLabel(type) {
    if (type = "file")
        return TypeLabel("file")
    else if (type = "function")
        return TypeLabel("function")
    else if (type = "cmd")
        return TypeLabel("cmd")
    else if (type = "url")
        return TypeLabel("url")
    else if (type = "run")
        return TypeLabel("run")
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

    ; 加载排名: 先收集按 frecency 排序, 待新鲜索引建成后再合并
    ; (已从配置/插件中删除的旧条目不再复活, 避免 calc/google 类遮挡重现)
    rankElements := []
    if (loadRank) {
        hl := RankHalfLife()
        scored := []
        for command, rank in g_AutoConf["Rank"] {
            if (StrLen(command) = 0)
                continue
            parsed := RankParseValue(rank)
            if (parsed["visits"] >= 1) {
                scored.Push(Map("key", command, "score", RankScoreOf(parsed["visits"], parsed["date"], hl)))
            } else {
                g_ExcludedCommands .= command "`n"
                g_ExcludedCommandsObj[command] := true
            }
        }
        ; 稳定降序 (插入排序, rank 条目通常几十个; 同分保持 ini 顺序)
        ordered := []
        for _, it in scored {
            pos := ordered.Length + 1
            Loop ordered.Length {
                if (it["score"] > ordered[A_Index]["score"]) {
                    pos := A_Index
                    break
                }
            }
            ordered.InsertAt(pos, it)
        }
        for _, it in ordered {
            ; Rank 键原样回放, 不做格式改写 (保证 ChangeRank 键稳定)
            rankElements.Push(it["key"])
        }
    }

    ; 加载配置中的命令 ([Commands] 现版; value 形如 type|cmd|desc, 统一成 "key | type | cmd | desc" 四段式)
    cmdSection := g_Conf.HasSection("Commands") ? g_Conf["Commands"] : Map()
    for key, value in cmdSection {
        if (value != "")
            AddCommand(key . " | " . RegExReplace(value, "\s*\|\s*", " | "))
        else
            AddCommand(key)
    }

    ; 加载插件命令: 全插件经 Hybrid RegisterCommands 直注 (无 legacy 分发)
    if (IsSet(RimPluginManager) && IsObject(RimPluginManager)) {
        RimPluginManager.RegisterAllCommands()
    }

    ; 加载语义指令 (RimCommand) 与工作空间指令到全局启动池
    if (IsSet(RimCommand) && IsObject(RimCommand)) {
        RimCommand.PopulateAllToLauncher()
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
        g_FallbackCommands.Push("function | AhkRun | " . T("cmd.fallback_ahkrun"))

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

    ; 加载控制面板函数 (仅 Conf 目录)
    cplFile := A_ScriptDir "\Conf\ControlPanelFunctions.txt"
    if (g_Conf.Get("Config", "LoadControlPanelFunctions", "0") = "1" && FileExist(cplFile))
        for _line in ReadFileLines(cplFile) {
            if (Trim(_line) != "")
                AddCommand(Trim(_line))
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

    ; 池审计 (只记不删): 不可执行形状 (连 RunCommand 都直接返回) 进 error.log, 另全量快照 Rim.pool.log 供取证;
    ; command 开头裸行 (如 "command | X" 无描述) 重点标出 —— 正常注册只产三段带 label 行
    try {
        _bad := 0
        _bareCmd := []
        _dump := ""
        for _el in g_Commands {
            _dump .= _el . "`n"
            _pp := StrSplit(_el, " | ")
            if (_pp.Length < 2) {
                _bad++
                continue
            }
            if (_pp[1] = "command" && _pp.Length < 3)
                _bareCmd.Push(_el)
        }
        try FileAppend(_dump, A_ScriptDir . "\Rim.pool.log")
        catch {
        }
        if (_bad > 0 || _bareCmd.Length > 0) {
            _msg := "POOL_AUDIT malformed=" . _bad . " bare-command=" . _bareCmd.Length . " total=" . g_Commands.Length
            for _, _b in _bareCmd
                _msg .= " [" . SubStr(_b, 1, 60) . "]"
            try RimLog("WARN", _msg)
            catch {
            }
        }
    } catch {
    }
}

; 注: v1 的 @() 在 v2 中是非法的函数名, 已无替代 (RegCmd 已删, 自定义函数走 [Commands] function|Fn|desc)

; 调整命令权重
; === Frecency (频次×时效): score = min(visits,25) * 0.5^(days/半衰期) ===
; 存储 [Rank] key = visits|YYYYMMDD (旧裸整数读作 visits|未知日期, 按今天计, 迁移无断层);
; 半衰期默认 14 天, [Config] RankHalfLife 可调; 精确桶永远优先, 此处只排非精确桶与加载合并
RankKeyOfElement(element) {
    splitedCmd := StrSplit(element, " | ")
    if (splitedCmd.Length >= 5)
        return splitedCmd[1] " | " splitedCmd[2] " | " splitedCmd[3] " | " splitedCmd[4]
    else if (splitedCmd.Length >= 4 && splitedCmd[1] = "function")
        return splitedCmd[1] " | " splitedCmd[2] " | " splitedCmd[3]
    return element
}

RankParseValue(val) {
    s := Trim(String(val))
    if (s = "")
        return Map("visits", 0, "date", "")
    if InStr(s, "|") {
        parts := StrSplit(s, "|")
        v := 0
        try {
            if IsInteger(Trim(parts[1]))
                v := Integer(Trim(parts[1]))
        } catch {
        }
        d := parts.Length >= 2 ? Trim(parts[2]) : ""
        return Map("visits", v, "date", d)
    }
    ; 旧裸整数 (首版 frecency 前写入): 次数保留, 日期按极旧计, 下次 ChangeRank 即转正新格式
    if IsInteger(s) {
        v := 0
        try v := Integer(s)
        catch {
        }
        return Map("visits", v, "date", "")
    }
    return Map("visits", 0, "date", "")
}

RankHalfLife() {
    hl := 14
    try {
        global g_Conf
        if (IsSet(g_Conf) && IsObject(g_Conf) && g_Conf.HasSection("Config")) {
            raw := Trim(g_Conf.Get("Config", "RankHalfLife", "14"))
            if (IsInteger(raw) && Integer(raw) > 0)
                hl := Integer(raw)
        }
    } catch {
    }
    return hl
}

RankScoreOf(visits, dateStr, halfLife := 14) {
    v := 0.0
    try v := visits + 0.0
    catch {
        return 0.0
    }
    if (v <= 0)
        return 0.0
    if (v > 25)
        v := 25.0
    ; 未知日期 (旧裸整数) 按极旧计: 权重≈0, 只靠 "用过" 压 "没用过" (merge/load 仍优先于零分池);
    ; 一旦再用即盖当天戳回血. 升级时会有一次重排, 之后全凭实力
    days := 36500
    if (dateStr != "") {
        days := 0
        try days := DateDiff(dateStr . "000000", A_Now, "Days")
        catch {
            days := 0
        }
        if (days < 0)
            days := 0
    }
    hl := 14.0
    try {
        hl := halfLife + 0.0
    } catch {
    }
    if (hl <= 0)
        hl := 14.0
    if (days > hl * 60)
        return 0.0
    w := 0.5 ** (days / hl)
    if (w <= 0)
        return 0.0
    return v * w
}

RankScoreOfElement(element) {
    key := RankKeyOfElement(element)
    val := "0"
    try {
        global g_AutoConf
        if (IsSet(g_AutoConf) && IsObject(g_AutoConf))
            val := g_AutoConf.GetValue("Rank", key, "0")
    } catch {
        return 0.0
    }
    parsed := RankParseValue(val)
    hl := 14
    try hl := RankHalfLife()
    catch {
    }
    return RankScoreOf(parsed["visits"], parsed["date"], hl)
}

ChangeRank(cmd, show := false, inc := 1) {
    global g_AutoConf, g_ExcludedCommands, g_ExcludedCommandsObj

    cmd := RankKeyOfElement(cmd)

    parsed := RankParseValue(g_AutoConf.GetValue("Rank", cmd, "0"))
    cmdRank := parsed["visits"] + inc
    if (cmdRank > 999)
        cmdRank := 999
    if (cmdRank < -99)
        cmdRank := -99
    today := SubStr(A_Now, 1, 8)

    if (cmdRank != 0 && cmd != "") {
        if (cmdRank < 0) {
            cmdRank := -1
            g_ExcludedCommands .= cmd "`n"
            g_ExcludedCommandsObj[cmd] := true
            try g_AutoConf.AddKey("Rank", cmd, "-1")
            catch {
            }
        } else {
            try g_AutoConf.AddKey("Rank", cmd, cmdRank . "|" . today)
            catch {
            }
        }
    } else {
        cmdRank := 0
    }

    ; 落盘节流: 权重只写内存会丢 (此前仅退出时 SaveAutoConf 才落盘, 崩溃即丢);
    ; 高频执行也不怕, 30 秒最多写一次小文件
    static lastRankSave := 0
    if (A_TickCount - lastRankSave > 30000) {
        lastRankSave := A_TickCount
        try g_AutoConf.Save()
        catch {
        }
    }

    if (show)
        ToolTip(T("rank.adjusted", cmd, cmdRank))
}
