#Requires AutoHotkey v2.0
#Warn All, Off

; === Files - 文件加载和索引 (从 RunZ Core/Files.ahk 移植) ===

; 生成搜索文件列表 (对齐原版: %dir% 动态解引用支持任意 A_ 变量)
; 性能: 配置预取一次 (循环内零 CfgGet) + 全量攒批一次落盘 (数千文件不再逐行 open/close)
GenerateSearchFileList() {
    global g_SearchFileList, g_Conf

    searchFileType := CfgGet("Config", "SearchFileType", "*.exe | *.lnk")
    searchDirs := StrSplit(CfgGet("Config", "SearchFileDir", ""), " | ")
    excludePat := CfgGet("Config", "SearchFileExclude", "")
    hasExclude := Trim(excludePat) != ""

    out := ""
    for dirIndex, dir in searchDirs {
        dir := Trim(dir)
        if (dir = "")
            continue
        searchPath := ResolveSearchDir(dir)

        for extIndex, ext in StrSplit(searchFileType, " | ") {
            ext := Trim(ext)
            if (ext = "")
                continue
            loop files, searchPath "\" ext, "R" {
                if (hasExclude && RegExMatch(A_LoopFileFullPath, excludePat))
                    continue
                out .= "file | " A_LoopFileFullPath "`n"
            }
        }
    }
    try FileDelete(g_SearchFileList)
    catch {
    }
    if (out != "") {
        try {
            FileAppend(out, g_SearchFileList)
            return
        }
    } else {
        ; 空结果仍需清空旧索引 (否则删光文件后 Reindex 留下僵尸行)
        return
    }
    ; 回落: 批写失败 (磁盘/杀软锁) 逐行重试
    Loop Parse, out, "`n", "`r" {
        if (Trim(A_LoopField) != "") {
            try FileAppend(A_LoopField "`n", g_SearchFileList)
            catch {
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

; 收编行进 Registry (池已死: 唯一入口, 返回 id; 首注胜, 重复收编覆盖幂等)
AddCommand(element) {
    try {
        if (IsSet(RimCommand) && IsObject(RimCommand))
            return RimCommand.IngestRow(element)
    } catch {
    }
    return ""
}

; 主加载器 (Registry 是唯一真相源: 各源经 AddCommand 收编, 排序由搜索期 frecency 实时算)
LoadFiles(loadRank := true) {
    global g_FallbackCommands
    global g_ExcludedCommandsObj, g_AutoConf, g_Conf, g_Plugins, g_UserFileList
    global g_SearchFileList, g_SkinConf

    g_FallbackCommands := []
    g_ExcludedCommandsObj := Map()

    ; 重建语义: 先清收编行 (删文件/删命令后不留僵尸 Registry, 搜索全表不膨胀);
    ; 直注命令 (插件/通用/工作区, 真实分类) 不受影响, 缺失行下轮收编补回
    try {
        if (IsSet(RimCommand) && IsObject(RimCommand))
            RimCommand.ClearIngested()
    } catch {
    }
    ; rank 纪元 +1: frecency 缓存与空查询缓存靠它失效
    try {
        global g_RankEpoch
        if (!IsSet(g_RankEpoch) || g_RankEpoch = "")
            g_RankEpoch := 0
        g_RankEpoch++
    } catch {
    }

    ; 排除表: 权重为负的 Rank 键不再参与搜索 (键已是 rankKey 形 "command|<id>")
    if (loadRank) {
        for command, rank in g_AutoConf["Rank"] {
            if (StrLen(command) = 0)
                continue
            parsed := RankParseValue(rank)
            if (parsed["visits"] < 1) {
                g_ExcludedCommandsObj[command] := true
            }
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

    ; 加载插件命令: 全插件经 RegisterCommands 直注 Registry
    if (IsSet(RimPluginManager) && IsObject(RimPluginManager)) {
        RimPluginManager.RegisterAllCommands()
    }

    ; 加载回退命令: 全部收录 (原版按顺序, 第一项为回车默认; 不进 Registry, 无结果时才显示)
    ; 不做 IsFunc/IsLabel 过滤 — 别名在 RunCommand 时再解析, 保证无结果时总有显示
    g_FallbackCommands := []
    if (g_Conf.HasSection("FallbackCommand")) {
        for key, value in g_Conf["FallbackCommand"] {
            fb := FallbackJoin(key, value)
            if (Trim(fb) != "")
                g_FallbackCommands.Push(fb)
        }
    }
    if (g_FallbackCommands.Length = 0)
        g_FallbackCommands.Push("function | AhkRun | " . T("cmd.fallback_ahkrun"))

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
    if (CfgGet("Config", "LoadControlPanelFunctions", "0") = "1" && FileExist(cplFile))
        for _line in ReadFileLines(cplFile) {
            if (Trim(_line) != "")
                AddCommand(Trim(_line))
        }

    ; 注册表审计 (只记不删): 动作不可达条目进 error.log; 正常零字节, 不写快照
    try {
        _dead := []
        if (IsSet(RimCommand) && IsObject(RimCommand)) {
            for _id, _cmd in RimCommand.Registry {
                try {
                    _act := String(_cmd.Action)
                    _k := StrLower(String(_cmd.Kind))
                    if (_act = "" && _k != "file" && _k != "url" && _k != "run" && _k != "cmd")
                        _dead.Push(_id)
                } catch {
                }
            }
        }
        if (_dead.Length > 0) {
            _msg := "POOL_AUDIT dead-action=" . _dead.Length
            for _, _b in _dead
                _msg .= " [" . SubStr(_b, 1, 60) . "]"
            try RimLog("WARN", _msg)
            catch {
            }
        }
    } catch {
    }
}

; 注: v1 的 @() 在 v2 中是非法的函数名, 已无替代 (RegCmd 已删, 自定义函数走 [Commands] function|Fn|desc)

; 回退行拼接: EasyIni 按首个 "=" 切分, URL 查询串 (?q=/ ?wd=) 会把裸行
; "url | https://..?wd={query} | desc" 切成 key/value; 用 "=" 拼回去是原行
; 才认定裸行, 否则沿用旧 "key | value" 拼接. 永不抛错.
FallbackJoin(key, value) {
    if (value = "")
        return key
    raw := key "=" value
    try {
        if (RegExMatch(raw, "^(function|url|run|cmd|command|file) \| "))
            return raw
    }
    return key " | " value
}

; 调整命令权重
; === Frecency (频次×时效): score = min(visits,25) * 0.5^(days/半衰期) ===
; 存储 [Rank] key = visits|YYYYMMDD, 唯一格式 (未上线, 无历史格式);
; 半衰期默认 14 天, [Config] RankHalfLife 可调; 精确桶永远优先, 此处只排非精确桶与加载合并
RankKeyOfElement(element) {
    ; 规范记录先剥参数栏: 参数边界与类型无关, 此处之后只见干净元素, 永不分流
    rec := HistSplit(element)
    if (rec["has"])
        return rec["el"]
    return element
}

; 唯一两种格式: "-1" (排除) / "visits|YYYYMMDD"; 其余一律零分
RankParseValue(val) {
    s := Trim(String(val))
    if (s = "")
        return Map("visits", 0, "date", "")
    if (s = "-1")
        return Map("visits", -1, "date", "")
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
    return Map("visits", 0, "date", "")
}

RankHalfLife() {
    hl := 14
    try {
        global g_Conf
        if (IsSet(g_Conf) && IsObject(g_Conf) && g_Conf.HasSection("Config")) {
            raw := Trim(CfgGet("Config", "RankHalfLife", "14"))
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
    ; 无日期 (从未 stamp): 按极旧计, 权重≈0, 只靠 "用过" 压 "没用过";
    ; 一旦再用即盖当天戳回血
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

; frecency 缓存: 同纪元同半衰期内按 rankKey 记分; ChangeRank/LoadFiles 碰纪元即整清.
; 上限 5000 条 (超限整清, 防池膨胀期常驻); 探针无 g_RankEpoch 时纪元恒 0, 行为一致
RankScoreOfElement(element) {
    key := RankKeyOfElement(element)
    epoch := 0
    try {
        global g_RankEpoch
        if (IsSet(g_RankEpoch) && g_RankEpoch != "")
            epoch := g_RankEpoch + 0
    } catch {
    }
    static scoreCache := Map()
    static cacheEpoch := -1
    if (cacheEpoch != epoch) {
        scoreCache := Map()
        cacheEpoch := epoch
    }
    hl := 14
    try hl := RankHalfLife()
    catch {
    }
    try {
        if (scoreCache.Has(key)) {
            hit := scoreCache[key]
            if (IsObject(hit) && hit.Get("hl", -1) = hl)
                return hit["score"]
        }
    } catch {
    }
    val := "0"
    try {
        global g_AutoConf
        if (IsSet(g_AutoConf) && IsObject(g_AutoConf))
            val := g_AutoConf.Get("Rank", key, "0")
    } catch {
        return 0.0
    }
    parsed := RankParseValue(val)
    sc := RankScoreOf(parsed["visits"], parsed["date"], hl)
    try {
        if (scoreCache.Count > 5000)
            scoreCache := Map()
        scoreCache[key] := Map("score", sc, "hl", hl)
    } catch {
    }
    return sc
}

ChangeRank(cmd, show := false, inc := 1) {
    global g_AutoConf, g_ExcludedCommandsObj

    cmd := RankKeyOfElement(cmd)

    parsed := RankParseValue(g_AutoConf.Get("Rank", cmd, "0"))
    cmdRank := parsed["visits"] + inc
    if (cmdRank > 999)
        cmdRank := 999
    if (cmdRank < -99)
        cmdRank := -99
    today := SubStr(A_Now, 1, 8)

    if (cmdRank != 0 && cmd != "") {
        if (cmdRank < 0) {
            cmdRank := -1
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

    ; Rank 上限 (键数超 600 即淘汰到 500, 与纪元同 bump; 执行级低频)
    try RankPrune()
    catch {
    }

    ; rank 写内存即碰纪元 (frecency/空查询缓存失效; 执行级低频, 击键零影响)
    try {
        global g_RankEpoch
        if (!IsSet(g_RankEpoch) || g_RankEpoch = "")
            g_RankEpoch := 0
        g_RankEpoch++
    } catch {
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

; Rank 剪枝: [Rank] 只增不减会无界膨胀 (LoadFiles 全量迭代 + Save 全量重写).
; 超 600 键即按 visits 升序淘汰到 500; 排除项 (visits<1, 隐藏命令) 永不淘汰;
; 同 visits 按日期升序 (空日期最旧). 返回删除数
RankPrune(cap := 500) {
    global g_AutoConf
    try {
        if (!IsSet(g_AutoConf) || !IsObject(g_AutoConf) || !g_AutoConf.HasSection("Rank"))
            return 0
        rankMap := g_AutoConf["Rank"]
        total := 0
        try total := rankMap.Count
        catch {
            for _k in rankMap
                total++
        }
        if (total <= cap + 100)
            return 0
        buckets := Map()
        for key, val in rankMap {
            parsed := RankParseValue(val)
            v := parsed["visits"]
            if (v < 1 || v > 999)
                continue
            if (!buckets.Has(v))
                buckets[v] := []
            buckets[v].Push(Map("key", key, "date", parsed["date"]))
        }
        need := total - cap
        removed := 0
        v := 1
        while (need > 0 && v <= 999) {
            if (buckets.Has(v)) {
                arr := buckets[v]
                ; 桶内按日期升序 (空日期最旧); 桶通常很小, 插入排序足够
                i := 2
                while (i <= arr.Length) {
                    cur := arr[i]
                    curD := cur["date"] = "" ? "00000000" : cur["date"]
                    j := i - 1
                    while (j >= 1) {
                        pd := arr[j]["date"] = "" ? "00000000" : arr[j]["date"]
                        if (pd <= curD)
                            break
                        arr[j + 1] := arr[j]
                        j--
                    }
                    arr[j + 1] := cur
                    i++
                }
                for _, it in arr {
                    if (need <= 0)
                        break
                    try g_AutoConf.DeleteKey("Rank", it["key"])
                    catch {
                    }
                    need--
                    removed++
                }
            }
            v++
        }
        return removed
    } catch {
    }
    return 0
}
