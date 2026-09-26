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

    ; 静态注册表: Id -> RimCommand 对象
    static Registry := Map()
    ; 分类列表: Category -> [RimCommand, ...]
    static Categories := Map()

    __New(id, title, action, options := "") {
        this.Id := id
        this.Title := title
        this.Action := action

        if (IsObject(options)) {
            if (options.Has("Category"))
                this.Category := options["Category"]
            if (options.Has("Description"))
                this.Description := options["Description"]
            if (options.Has("ContextFilter"))
                this.ContextFilter := options["ContextFilter"]
            if (options.Has("Keywords"))
                this.Keywords := options["Keywords"]
        }
        if (this.Category = "")
            this.Category := "General"
    }

    ; 注册指令 (幂等)
    static Register(id, title, action, options := "") {
        cmd := RimCommand(id, title, action, options)
        RimCommand.Registry[id] := cmd

        cat := cmd.Category
        ; 幂等更新分类列表 (移除旧同名项)
        for existingCat, list in RimCommand.Categories {
            i := 1
            while (i <= list.Length) {
                if (list[i].Id = id) {
                    list.RemoveAt(i)
                    break
                }
                i++
            }
        }
        if (!RimCommand.Categories.Has(cat))
            RimCommand.Categories[cat] := []
        RimCommand.Categories[cat].Push(cmd)

        ; 同时同步注入 Launcher 命令池，使命令面板直接可搜
        ; 池行用三段式 "command | id | label" (四段式 "id | command | id | label" 会被解析器
        ; 误判 key=id/type=command 而跑不通, 见 RunCommand; 显示侧取 type|cmd|desc, 执行走 command|id)
        try {
            if (IsSet(AddCommand))
                AddCommand(CmdLine_Format("command", id, RimCommand.MakeLabel(title, id, cmd.Description)))
        } catch {
        }

        return cmd
    }

    ; 池行 label 装配 (单点, Register 与 Populate 共用, 防两处改一只):
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

    ; 将所有已注册指令同步注入全局 Launcher 列表 (三段式, 见 Register 注释)
    static PopulateAllToLauncher() {
        for id, cmd in RimCommand.Registry {
            try {
                if (IsSet(AddCommand))
                    AddCommand(CmdLine_Format("command", id, RimCommand.MakeLabel(cmd.Title, id, cmd.Description)))
            } catch {
            }
        }
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

    ; 搜索匹配指令
    static Search(query, limit := 10) {
        results := []
        query := Trim(StrLower(query))
        if (query = "")
            return results

        ctx := GetActiveContext()
        for id, cmd in RimCommand.Registry {
            ; 检查上下文可用性
            if (IsObject(cmd.ContextFilter)) {
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
                    continue
            }

            idLow := StrLower(cmd.Id)
            titleLow := StrLower(cmd.Title)
            descLow := StrLower(cmd.Description)
            kwLow := StrLower(cmd.Keywords)

            if (InStr(idLow, query) || InStr(titleLow, query) || InStr(kwLow, query) || InStr(descLow, query))
                results.Push(cmd)

            if (results.Length >= limit)
                break
        }
        return results
    }
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

CmdLine_Format(type, cmd, desc := "", key := "") {
    if (key != "")
        return key " | " type " | " cmd " | " desc
    if (desc != "")
        return type " | " cmd " | " desc
    return type " | " cmd
}

; ==================== 命令池写入 (非 function 型直写池行; function 型调用方已清零, 误调即抛错) ====================
class LauncherCompat {
    static AddCommand(name, type, content, description := "") {
        global g_Commands
        if (type = "function") {
            throw Error("RegisterCommand function-type retired; use RimCommand.Register + MakeLegacyCmd directly: " . name)
        } else {
            element := type " | " content
            if (description != "")
                element .= " | " description
            g_Commands.Push(element)
        }
    }
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
        global g_Conf
        if (IsObject(g_Conf) && g_Conf.HasSection("Config"))
            tc := g_Conf.Get("Config", "TCPath", "")
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
    RestartRunZ()
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

    RimCommand.Register("system.reload_rim", T("cmdtitle.system.reload_rim"), Cmd_SystemReload, Map("Category", "System", "Description", T("cmd.universal.reload_rim"), "Keywords", "reload restart rim runz"))
    RimCommand.Register("system.edit_config", T("cmdtitle.system.edit_config"), Cmd_SystemEditConfig, Map("Category", "System", "Description", T("cmd.universal.edit_config"), "Keywords", "config setting ini edit"))
    RimCommand.Register("system.edit_auto_config", T("cmdtitle.system.edit_auto_config"), Cmd_SystemEditAutoConfig, Map("Category", "System", "Description", T("cmd.universal.edit_auto_config"), "Keywords", "auto config ini"))
    RimCommand.Register("system.lock", T("cmdtitle.system.lock"), Cmd_SystemLock, Map("Category", "System", "Description", T("cmd.universal.lock"), "Keywords", "lock workstation screen"))
    RimCommand.Register("system.sleep", T("cmdtitle.system.sleep"), Cmd_SystemSleep, Map("Category", "System", "Description", T("cmd.universal.sleep"), "Keywords", "sleep suspend standby"))
}
