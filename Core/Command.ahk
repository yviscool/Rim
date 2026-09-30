#Requires AutoHotkey v2.0
#Warn All, Off

; === Core/Command.ahk - Rim 语义指令注册表 (Command Registry) ===
; 统一管理系统级/应用级语义指令，连接 Context Engine 与 Execution Engine
; 供 Launcher (Command Palette)、鼠标手势、Vim 模式、全局热键共同调用

class RimCommand {
    Id := ""            ; 唯一标识符，如 "file.copy_path", "window.close"
    Title := ""         ; 显示名称，如 "Copy Path" 或 i18n key
    Category := ""      ; 分类: "File", "Window", "System", "Navigation", "Tool"
    Description := ""   ; 详细功能说明
    Action := ""        ; 动作: 可为闭包、函数名、或动作字符串协议
    ContextFilter := "" ; 上下文过滤函数: filter(ctx) 返回 true/false
    Keywords := ""      ; 搜索增强关键词，如 "cp path folder"
    Args := ""          ; 参数规格: [{name, required?, help?}] 数组, 无参命令留空.
                        ; 只有调用方 (RunCommand 校验门, Usage 命令) 才读它, 不写就当全可选.
    Kind := ""          ; 行种类: command(注册) / file / url / run / cmd / function(收编行)
    Target := ""        ; 执行目标: 注册=id; 收编=原 content/path
    Name := ""          ; 显示名: 注册=id; 收编=别名/文件名/键

    ; 静态注册表: Id -> RimCommand 对象 (唯一真相源; 分类即 Category 字段, 按需过滤)
    static Registry := Map()
    ; 序列号: 每次真实增删 +1, 搜索缓存 (SearchRow/空查询) 靠它失效
    static Seq := 0

    __New(id, title, action, options := "") {
        this.Id := id
        this.Title := title
        this.Action := action
        this.Args := []
        this.Kind := "command"
        this.Target := id
        this.Name := id

        if (IsObject(options)) {
            if (options.Has("Category"))
                this.Category := options["Category"]
            if (options.Has("Description"))
                this.Description := options["Description"]
            if (options.Has("ContextFilter"))
                this.ContextFilter := options["ContextFilter"]
            if (options.Has("Keywords"))
                this.Keywords := options["Keywords"]
            if (options.Has("Args") && IsObject(options["Args"]))
                this.Args := options["Args"]
            if (options.Has("Kind") && Trim(String(options["Kind"])) != "")
                this.Kind := StrLower(Trim(String(options["Kind"])))
            if (options.Has("Target"))
                this.Target := String(options["Target"])
            if (options.Has("Name") && Trim(String(options["Name"])) != "")
                this.Name := String(options["Name"])
        }
        if (this.Category = "")
            this.Category := "General"
        if (this.Target = "")
            this.Target := this.Id
        if (this.Name = "")
            this.Name := this.Id
    }

    ; 注册指令 (幂等; Registry 是唯一真相源, 不再写字符串池)
    static Register(id, title, action, options := "") {
        cmd := RimCommand(id, title, action, options)
        cmd.Kind := "command"
        cmd.Target := id
        cmd.Name := id
        RimCommand.Registry[id] := cmd
        RimCommand.Seq++

        return cmd
    }

    ; 收编行清理 (LoadFiles 重建语义: 只清 Category=Ingested 的收编行,
    ; 插件直注/通用指令 (真实分类) 保留; 有删除才 bump Seq. 返回清理数)
    static ClearIngested() {
        n := 0
        dead := []
        for id, cmd in RimCommand.Registry {
            cat := ""
            try cat := String(cmd.Category)
            catch {
            }
            if (cat = "Ingested")
                dead.Push(id)
        }
        for _, goneId in dead {
            try RimCommand.Registry.Delete(goneId)
            catch {
            }
            n++
        }
        if (n > 0)
            RimCommand.Seq++
        return n
    }

    ; 池行 label 装配 (展示列 Name — Desc 的右半部分):
    ; title 与 id 相同 (短名直注) 时只留描述, 不拼 "名 - 描述" 叠床架屋
    static MakeLabel(title, id, desc) {
        label := ""
        if (title != "" && title != id)
            label := title
        if (desc != "")
            label := label != "" ? label . " - " . desc : desc
        if (label = "")
            label := id
        return label
    }

    ; 池行收编进 Registry (LoadFiles 建池后统一调一次;
    ; 已注册 id 直接跳过 (首注胜), 保证插件直注优先于 rank/回退复刻行).
    ; id 规则: 四段 key|type|cmd|desc → key; 三段 command|X|D → X;
    ; 三段/两段 type|content[|desc] → type:content; 裸 key → key.
    static IngestRow(line) {
        line := Trim(String(line))
        if (line = "")
            return ""
        parts := StrSplit(line, " | ")
        id := ""
        kind := ""
        target := ""
        name := ""
        desc := ""
        action := ""
        if (parts.Length >= 4 && CmdLine_IsFourSeg(parts)) {
            id := Trim(parts[1])
            kind := StrLower(Trim(parts[2]))
            target := Trim(parts[3])
            desc := Trim(parts[4])
            i := 5
            while (i <= parts.Length) {
                desc .= " | " . Trim(parts[i])
                i++
            }
            name := id
            action := kind . "|" . target
        } else if (parts.Length >= 2 && IsActionRowKind(parts[1])) {
            kind := StrLower(Trim(parts[1]))
            target := Trim(parts[2])
            desc := parts.Length >= 3 ? Trim(parts[3]) : ""
            i := 4
            while (i <= parts.Length) {
                desc .= " | " . Trim(parts[i])
                i++
            }
            if (kind = "command") {
                id := target
                name := target
            } else if (kind = "file") {
                id := "file:" . target
                name := target
                try {
                    SplitPath(target, , , , &noext)
                    if (noext != "")
                        name := noext
                } catch {
                }
            } else {
                ; url/run/cmd: 名优先用注册别名 (Google) 而非整串 content —— 别名是行的一等公民,
                ; 显示/冻结/精确命中全对名, 否则 "Google koa.js" 全链对着 URL (契约 3)
                id := kind . ":" . target
                name := target
                try {
                    if (IsSet(CmdAliasOf)) {
                        al := CmdAliasOf(target)
                        if (al != "")
                            name := al
                    }
                } catch {
                }
            }
            action := kind . "|" . target
        } else {
            id := Trim(parts[1])
            kind := "command"
            target := id
            name := id
            action := ""
        }
        if (id = "")
            return ""
        if (RimCommand.Registry.Has(id))
            return id
        cmd := RimCommand(id, name, action, Map("Category", "Ingested", "Description", desc
            , "Kind", kind, "Target", target, "Name", name))
        RimCommand.Registry[id] := cmd
        RimCommand.Seq++
        return id
    }

    ; 状态行: 任意行 → 原版底部输入框 remainder 形.
    ; file 行取完整路径 ([+ 描述]); 其余取 名[ | 描述] (4 段 origin 形为 类型|目标|描述).
    ; 未注册/旧池形退化为旧 SubStr 逻辑 (首个 " | " 之后全文). 永不抛错.
    static StatusOf(line) {
        try {
            rec := HistSplit(String(line))
            parts := StrSplit(rec["el"], " | ")
            if (parts.Length >= 2 && StrLower(Trim(parts[1])) = "command") {
                cmd := RimCommand.Get(Trim(parts[2]))
                if (IsObject(cmd)) {
                    kind := StrLower(String(cmd.Kind))
                    target := String(cmd.Target)
                    if (kind = "file") {
                        desc := ""
                        try desc := String(cmd.Description)
                        catch {
                        }
                        return desc != "" ? target . " | " . desc : target
                    }
                    name := String(cmd.Name)
                    desc := ""
                    try {
                        if (kind = "command")
                            desc := RimCommand.MakeLabel(cmd.Title, cmd.Id, cmd.Description)
                        else
                            desc := String(cmd.Description)
                    } catch {
                    }
                    if (kind = "command" || target = "" || target = cmd.Id)
                        return desc != "" ? name . " | " . desc : name
                    return desc != "" ? kind . " | " . target . " | " . desc : kind . " | " . target
                }
            }
            pos := InStr(rec["el"], " | ")
            if (pos > 0)
                return SubStr(rec["el"], pos + 3)
        } catch {
        }
        return String(line)
    }

    ; 展示行: "command|<id>" (+历史参数栏) 经 Registry 解出 show 串;
    ; 未注册/非命令形一律原文透传 (回退行旧池形照旧显示, 调用方做类型本地化). 永不抛错.
    static ShowOf(line) {
        try {
            rec := HistSplit(line)
            parts := StrSplit(rec["el"], " | ")
            if (parts.Length >= 2 && StrLower(Trim(parts[1])) = "command") {
                cmd := RimCommand.Get(Trim(parts[2]))
                if (IsObject(cmd)) {
                    showExt := false
                    try showExt := CfgGet("Config", "ShowFileExt", "0") = "1"
                    catch {
                    }
                    return RimCommand.SearchRow(cmd, showExt)["show"]
                }
            }
        } catch {
        }
        return String(line)
    }

    ; 单一推导点: Registry 对象 → {id, kind, name, show, search, targetKey, rankKey}.
    ; 与旧 Search.ahk 三分支 / 已删 AddCommand 推导逐字一致, 显示串不变, GUI 零改动.
    ; show 永远 "kind | 名 | 描述" (command 行描述取 label 形, 与旧池行一致);
    ; search 永远 "名 目标词 描述 [别名]" (file 行恒用无扩展名, 别名只找非 command 行).
    static SearchRow(cmd, showExt := false, searchFull := false) {
        ; 行推导缓存: 纯函数 (输入=id/kind/name/target/desc/alias + 开关), 按开关+Seq 键缓存;
        ; 旧 Seq 键在下次命中时顺手清理, 单对象最多驻留 2 代
        rowCacheKey := (showExt ? "1" : "0") . (searchFull ? "1" : "0") . ":" . String(RimCommand.Seq)
        try {
            if (IsObject(cmd._rowCache) && cmd._rowCache.Has(rowCacheKey))
                return cmd._rowCache[rowCacheKey]
        } catch {
        }
        id := cmd.Id
        kind := cmd.Kind != "" ? StrLower(cmd.Kind) : "command"
        name := cmd.Name != "" ? cmd.Name : id
        target := cmd.Target != "" ? cmd.Target : id
        desc := ""
        try desc := cmd.Description != "" ? cmd.Description : ""
        catch {
        }
        if (kind = "command") {
            try desc := RimCommand.MakeLabel(cmd.Title, id, cmd.Description)
            catch {
            }
        }
        disp := name
        searchBase := name
        if (kind = "file") {
            fn := target
            noext := target
            fileDir := ""
            try {
                SplitPath(target, &fn, &fileDir, , &noext)
            } catch {
            }
            if (fn = "")
                fn := target
            if (noext = "")
                noext := fn
            disp := showExt ? fn : noext
            searchBase := noext
            if (searchFull && fileDir != "")
                searchBase := StrReplace(fileDir, "\", " ") . " " . searchBase
        } else if (name != target) {
            ; 四段收编行: 键必须进搜索 (旧 "key cmd desc" 文法)
            searchBase := name . " " . StrReplace(StrReplace(target, "/", " "), "\", " ")
        } else if (kind = "command") {
            searchBase := name
        } else {
            ; 三段收编行: 只搜 content 词 (旧文法无名可加, Name 即 Target)
            searchBase := StrReplace(StrReplace(target, "/", " "), "\", " ")
        }
        show := kind . " | " . disp
        if (desc != "")
            show .= " | " . desc
        search := searchBase
        if (desc != "")
            search .= " " . desc
        if (kind != "command") {
            try {
                if (IsSet(CmdAliasOf)) {
                    aliasExtra := CmdAliasOf(target)
                    if (aliasExtra != "" && !InStr(search, aliasExtra, false))
                        search .= " " . aliasExtra
                }
            } catch {
            }
        }
        row := Map("id", id, "kind", kind, "name", name, "desc", desc, "show", show
            , "search", search, "targetKey", kind . "|" . target, "rankKey", "command | " . id)
        try {
            if (!IsObject(cmd._rowCache))
                cmd._rowCache := Map()
            cmd._rowCache[rowCacheKey] := row
            if (cmd._rowCache.Count > 2) {
                pruneKeys := []
                for ck in cmd._rowCache {
                    if (ck != rowCacheKey)
                        pruneKeys.Push(ck)
                }
                for _, pk in pruneKeys
                    cmd._rowCache.Delete(pk)
            }
        } catch {
        }
        return row
    }

    ; 获取指令
    static Get(id) {
        if RimCommand.Registry.Has(id)
            return RimCommand.Registry[id]
        return ""
    }

    ; 执行指令
    static Execute(id, arg := "") {
        cmd := RimCommand.Get(id)
        if (!cmd) {
            ; 若未显式注册为 RimCommand，尝试直接转交 ExecuteAction
            ExecuteAction(id, arg)
            return
        }

        ; 如果有上下文过滤器，先校验当前上下文是否满足要求
        if (IsObject(cmd.ContextFilter)) {
            ctx := GetActiveContext()
            pass := false
            try {
                pass := cmd.ContextFilter(ctx)
            } catch {
                try {
                    pass := cmd.ContextFilter()
                } catch {
                    pass := false
                }
            }
            if (!pass)
                return
        }

        ; 执行动作
        act := cmd.Action
        if (IsObject(act)) {
            try {
                act(arg)
                return
            } catch {
                act()
                return
            }
        } else if (Type(act) = "String" && act != "") {
            ExecuteAction(act, arg)
        }
    }

    ; 参数规格查询: 未注册/未声明一律返回空数组 (调用方按全可选处理, 零行为变化)
    static ArgSpec(id) {
        try {
            cmd := RimCommand.Get(id)
            if (IsObject(cmd) && IsObject(cmd.Args))
                return cmd.Args
        } catch {
        }
        return []
    }

    ; 用法行: "id <必填> [可选] — 描述" (+逐参 help). 未注册返回 "".
    static Usage(id) {
        cmd := RimCommand.Get(id)
        if (!IsObject(cmd))
            return ""
        line := id
        try {
            for _, spec in cmd.Args {
                if (!IsObject(spec) || !spec.Has("name"))
                    continue
                req := false
                try req := !!spec.Get("required", false)
                catch {
                }
                line .= req ? " <" . spec["name"] . ">" : " [" . spec["name"] . "]"
            }
        } catch {
        }
        if (cmd.Description != "")
            line .= " — " . cmd.Description
        try {
            for _, spec in cmd.Args {
                if (IsObject(spec) && spec.Has("name") && spec.Has("help") && Trim(String(spec["help"])) != "")
                    line .= "`n  " . spec["name"] . ": " . spec["help"]
            }
        } catch {
        }
        return line
    }

    ; 参数校验门 (供 RunCommand): 返回 ""=放行; 否则返回用法行 (调用方展示并跳过执行/历史).
    ; 只有 required 声明缺失才拦; 自弹输入框的命令 (CmdRun/AhkRun/TranslateWord) 不要声明 required.
    static CheckArgs(id, arg) {
        try {
            for _, spec in RimCommand.ArgSpec(id) {
                if (!IsObject(spec) || !spec.Has("name"))
                    continue
                req := false
                try req := !!spec.Get("required", false)
                catch {
                }
                if (req && Trim(String(arg)) = "")
                    return RimCommand.Usage(id)
            }
        } catch {
        }
        return ""
    }

    ; 注: 通用搜索走 SearchCollectMatches (Core/Search.ahk, 唯一真相源);
    ; 本类不再自带 Search (上下文过滤在 Execute 期做, 见 Execute())
}

; 旧池行首段类型词 (三段/两段行的 kind 位; command 含现代注册行)
IsActionRowKind(s) {
    w := StrLower(Trim(String(s)))
    return w = "file" || w = "function" || w = "cmd" || w = "url" || w = "run" || w = "command"
}

; === 命令行值对象 (CommandLine Value Object) ===
; "key | type | cmd | desc" 管道协议唯一解析点 (此前散落在 Execution/Search/Files/Hotkeys 手写 StrSplit+下标)
;   四段式 "key | type | cmd | desc" (type ∈ file/function/cmd/url/run, 来自 [Commands])
;   三段式 "type | cmd | desc" (插件/文件列表/回退命令)
;   两段式 "file | path" (文件列表)
;   历史重放行: fresh 行尾再拼 " | g_Arg" (四段式→5 段, 三段式→4 段)
CmdLine_IsFourSeg(parts) {
    return parts.Length >= 4
        && (parts[2] = "file" || parts[2] = "function" || parts[2] = "cmd" || parts[2] = "url" || parts[2] = "run")
}

CmdLine_Parse(line) {
    parts := StrSplit(line, " | ")
    out := Map("raw", line, "parts", parts, "len", parts.Length
        , "key", "", "type", "", "cmd", "", "desc", "", "isFour", false)
    if (parts.Length < 2)
        return out
    if (CmdLine_IsFourSeg(parts)) {
        out["isFour"] := true
        out["key"] := parts[1]
        out["type"] := parts[2]
        out["cmd"] := parts[3]
        d := parts[4]
        if (parts.Length > 4) {
            Loop parts.Length - 4
                d .= " | " . parts[4 + A_Index]
        }
        out["desc"] := d
    } else {
        out["type"] := parts[1]
        out["cmd"] := parts[2]
        if (parts.Length >= 3)
            out["desc"] := parts[3]
    }
    return out
}

; ==================== 数据行注册 (url/file/run/cmd 行: 别名 + Registry 收编) ====================
class LauncherCompat {
    static AddCommand(name, type, content, description := "") {
        global g_CommandAlias
        if (type = "function") {
            throw Error("AddCommand function-type removed; use RimCommand.Register + MakeLegacyCmd directly: " . name)
        } else {
            element := type " | " content
            if (description != "")
                element .= " | " description
            ; 别名保留: 进池丢名导致 ghost/冻结/精确命中全对 content (如整串 URL),
            ; 名字叫不回来 ("Goo" Tab 不出 "Google"). 首胜, 不覆盖.
            try {
                if (IsSet(g_CommandAlias) && IsObject(g_CommandAlias)) {
                    key := Trim(content)
                    if (key != "" && Trim(name) != "" && !g_CommandAlias.Has(key))
                        g_CommandAlias[key] := Trim(name)
                }
            }
            ; 收编进 Registry (与 LoadFiles 末 IngestRow 同规则, id 一致不分叉; 首注胜)
            try {
                id := RimCommand.IngestRow(element)
                if (id != "" && RimCommand.Registry.Has(id) && Trim(name) != "") {
                    ent := RimCommand.Registry[id]
                    try {
                        if (ent.Keywords = "")
                            ent.Keywords := Trim(name)
                    } catch {
                    }
                }
            } catch {
            }
        }
    }
}

; 别名查询: content → 注册名 (无则 ""). 探针未建表时回 "" 永不抛错
CmdAliasOf(content) {
    try {
        global g_CommandAlias
        if (IsSet(g_CommandAlias) && IsObject(g_CommandAlias)) {
            key := Trim(String(content))
            if (g_CommandAlias.Has(key))
                return g_CommandAlias[key]
        }
    }
    return ""
}

; === 通用指令实现函数 (Universal Command Implementations) ===

; --- File 指令集 ---
Cmd_FileCopyPath(arg := "") {
    ctx := GetActiveContext()
    target := ctx.SelectedFile != "" ? ctx.SelectedFile : ctx.CurrentDir
    if (target != "") {
        A_Clipboard := target
        ToolTip("Copied Path: " . target)
        SetTimer(() => ToolTip(), -1500)
    } else {
        ToolTip("No active path or file")
        SetTimer(() => ToolTip(), -1500)
    }
}

Cmd_FileCopyName(arg := "") {
    ctx := GetActiveContext()
    target := ctx.SelectedFile != "" ? ctx.SelectedFile : ctx.CurrentDir
    if (target != "") {
        SplitPath(target, &name)
        A_Clipboard := name
        ToolTip("Copied Name: " . name)
        SetTimer(() => ToolTip(), -1500)
    }
}

Cmd_FileOpenDir(arg := "") {
    ctx := GetActiveContext()
    target := ctx.CurrentDir != "" ? ctx.CurrentDir : (ctx.SelectedFile != "" ? ctx.SelectedFile : "")
    if (target != "") {
        if (DirExist(target))
            Run('explorer "' target '"')
        else if (FileExist(target)) {
            SplitPath(target, , &dir)
            Run('explorer "' dir '"')
        }
    }
}

Cmd_FileOpenTerminal(arg := "") {
    ctx := GetActiveContext()
    dir := ctx.CurrentDir != "" ? ctx.CurrentDir : A_MyDocuments
    ; 优先 Windows Terminal, 其次 PowerShell, 兜底 CMD
    try {
        Run('wt.exe -d "' dir '"')
        return
    }
    try {
        Run('powershell.exe -NoExit', dir)
        return
    }
    Run(A_ComSpec, dir)
}

Cmd_FileOpenInTC(arg := "") {
    ctx := GetActiveContext()
    target := ctx.CurrentDir != "" ? ctx.CurrentDir : ctx.SelectedFile
    if (target = "")
        return
    tc := ""
    try {
        tc := TC_EffPath()
    }
    if (tc != "" && FileExist(tc))
        Run(tc ' /O /A /T /L="' target '"')
    else
        OpenPath(target)
}

Cmd_FileOpenInExplorer(arg := "") {
    ctx := GetActiveContext()
    target := ctx.CurrentDir != "" ? ctx.CurrentDir : ctx.SelectedFile
    if (target != "")
        Run('explorer "' target '"')
}

; --- Window 指令集 ---
Cmd_WindowClose(*) {
    try WinClose("A")
}

Cmd_WindowMaximize(*) {
    try WinMaximize("A")
}

Cmd_WindowMinimize(*) {
    try WinMinimize("A")
}

Cmd_WindowToggleTop(*) {
    try {
        WinSetAlwaysOnTop(-1, "A")
        isTop := WinGetExStyle("A") & 0x8
        ToolTip(isTop ? "Window: Always On Top" : "Window: Normal")
        SetTimer(() => ToolTip(), -1200)
    }
}

Cmd_WindowCenter(*) {
    try {
        hwnd := WinExist("A")
        if (!hwnd)
            return
        WinGetPos(, , &w, &h, "ahk_id " hwnd)
        screenW := SysGet(78)
        screenH := SysGet(79)
        newX := (screenW - w) / 2
        newY := (screenH - h) / 2
        WinMove(newX, newY, , , "ahk_id " hwnd)
    }
}

; --- System 指令集 ---
Cmd_SystemReload(*) {
    RestartRim()
}

Cmd_SystemEditConfig(*) {
    EditConfig()
}

Cmd_SystemEditAutoConfig(*) {
    EditAutoConfig()
}

Cmd_SystemLock(*) {
    DllCall("LockWorkStation")
}

Cmd_SystemSleep(*) {
    DllCall("PowrProf\SetSuspendState", "Int", 0, "Int", 0, "Int", 0)
}

; === 初始化内置通用指令 (Universal Commands Initialization) ===
InitUniversalCommands() {
    RimCommand.Register("file.copy_path", T("cmdtitle.file.copy_path"), Cmd_FileCopyPath, Map("Category", "File", "Description", T("cmd.universal.copy_path"), "Keywords", "copy path fpath"))
    RimCommand.Register("file.copy_name", T("cmdtitle.file.copy_name"), Cmd_FileCopyName, Map("Category", "File", "Description", T("cmd.universal.copy_name"), "Keywords", "copy filename name"))
    RimCommand.Register("file.open_dir", T("cmdtitle.file.open_dir"), Cmd_FileOpenDir, Map("Category", "File", "Description", T("cmd.universal.open_dir"), "Keywords", "open folder dir explorer"))
    RimCommand.Register("file.open_terminal", T("cmdtitle.file.open_terminal"), Cmd_FileOpenTerminal, Map("Category", "File", "Description", T("cmd.universal.open_terminal"), "Keywords", "terminal cmd powershell wt bash"))
    RimCommand.Register("file.open_in_tc", T("cmdtitle.file.open_in_tc"), Cmd_FileOpenInTC, Map("Category", "File", "Description", T("cmd.universal.open_in_tc"), "Keywords", "tc totalcommander goto"))
    RimCommand.Register("file.open_in_explorer", T("cmdtitle.file.open_in_explorer"), Cmd_FileOpenInExplorer, Map("Category", "File", "Description", T("cmd.universal.open_in_explorer"), "Keywords", "explorer folder"))

    RimCommand.Register("window.close", T("cmdtitle.window.close"), Cmd_WindowClose, Map("Category", "Window", "Description", T("cmd.universal.window_close"), "Keywords", "close exit quit window"))
    RimCommand.Register("window.maximize", T("cmdtitle.window.maximize"), Cmd_WindowMaximize, Map("Category", "Window", "Description", T("cmd.universal.window_maximize"), "Keywords", "maximize window zoom"))
    RimCommand.Register("window.minimize", T("cmdtitle.window.minimize"), Cmd_WindowMinimize, Map("Category", "Window", "Description", T("cmd.universal.window_minimize"), "Keywords", "minimize hide window"))
    RimCommand.Register("window.toggle_top", T("cmdtitle.window.toggle_top"), Cmd_WindowToggleTop, Map("Category", "Window", "Description", T("cmd.universal.window_toggle_top"), "Keywords", "top pin alwaysontop"))
    RimCommand.Register("window.center", T("cmdtitle.window.center"), Cmd_WindowCenter, Map("Category", "Window", "Description", T("cmd.universal.window_center"), "Keywords", "center move window"))

    RimCommand.Register("system.reload_rim", T("cmdtitle.system.reload_rim"), Cmd_SystemReload, Map("Category", "System", "Description", T("cmd.universal.reload_rim"), "Keywords", "reload restart rim"))
    RimCommand.Register("system.edit_config", T("cmdtitle.system.edit_config"), Cmd_SystemEditConfig, Map("Category", "System", "Description", T("cmd.universal.edit_config"), "Keywords", "config setting ini edit"))
    RimCommand.Register("system.edit_auto_config", T("cmdtitle.system.edit_auto_config"), Cmd_SystemEditAutoConfig, Map("Category", "System", "Description", T("cmd.universal.edit_auto_config"), "Keywords", "auto config ini"))
    RimCommand.Register("system.lock", T("cmdtitle.system.lock"), Cmd_SystemLock, Map("Category", "System", "Description", T("cmd.universal.lock"), "Keywords", "lock workstation screen"))
    RimCommand.Register("system.sleep", T("cmdtitle.system.sleep"), Cmd_SystemSleep, Map("Category", "System", "Description", T("cmd.universal.sleep"), "Keywords", "sleep suspend standby"))
}
