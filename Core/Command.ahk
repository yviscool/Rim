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
        try {
            desc := cmd.Description
            label := (title != id ? title : id)
            if (desc != "")
                label .= " - " . desc
            if (IsSet(AddCommand))
                AddCommand(id . " | command | " . id . " | " . label)
        } catch {
        }

        return cmd
    }

    ; 将所有已注册指令同步注入全局 Launcher 列表
    static PopulateAllToLauncher() {
        for id, cmd in RimCommand.Registry {
            try {
                desc := cmd.Description
                label := (cmd.Title != id ? cmd.Title : id)
                if (desc != "")
                    label .= " - " . desc
                if (IsSet(AddCommand))
                    AddCommand(id . " | command | " . id . " | " . label)
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
    RimCommand.Register("file.copy_path", "Copy Path", Cmd_FileCopyPath, Map("Category", "File", "Description", "复制当前文件或目录路径", "Keywords", "copy path fpath"))
    RimCommand.Register("file.copy_name", "Copy File Name", Cmd_FileCopyName, Map("Category", "File", "Description", "复制当前文件名", "Keywords", "copy filename name"))
    RimCommand.Register("file.open_dir", "Open Directory", Cmd_FileOpenDir, Map("Category", "File", "Description", "在资源管理器中打开当前目录", "Keywords", "open folder dir explorer"))
    RimCommand.Register("file.open_terminal", "Open Terminal Here", Cmd_FileOpenTerminal, Map("Category", "File", "Description", "在当前路径打开终端 (Windows Terminal / PowerShell)", "Keywords", "terminal cmd powershell wt bash"))
    RimCommand.Register("file.open_in_tc", "Open in Total Commander", Cmd_FileOpenInTC, Map("Category", "File", "Description", "在 Total Commander 中打开当前路径", "Keywords", "tc totalcommander goto"))
    RimCommand.Register("file.open_in_explorer", "Open in Explorer", Cmd_FileOpenInExplorer, Map("Category", "File", "Description", "在 Explorer 中打开当前路径", "Keywords", "explorer folder"))

    RimCommand.Register("window.close", "Close Window", Cmd_WindowClose, Map("Category", "Window", "Description", "关闭当前活动窗口", "Keywords", "close exit quit window"))
    RimCommand.Register("window.maximize", "Maximize Window", Cmd_WindowMaximize, Map("Category", "Window", "Description", "最大化当前活动窗口", "Keywords", "maximize window zoom"))
    RimCommand.Register("window.minimize", "Minimize Window", Cmd_WindowMinimize, Map("Category", "Window", "Description", "最小化当前活动窗口", "Keywords", "minimize hide window"))
    RimCommand.Register("window.toggle_top", "Toggle Always on Top", Cmd_WindowToggleTop, Map("Category", "Window", "Description", "切换当前窗口置顶状态", "Keywords", "top pin alwaysontop"))
    RimCommand.Register("window.center", "Center Window", Cmd_WindowCenter, Map("Category", "Window", "Description", "将当前窗口移动至屏幕中央", "Keywords", "center move window"))

    RimCommand.Register("system.reload_rim", "Restart Rim", Cmd_SystemReload, Map("Category", "System", "Description", "重启 Rim 进程", "Keywords", "reload restart rim runz"))
    RimCommand.Register("system.edit_config", "Edit Configuration", Cmd_SystemEditConfig, Map("Category", "System", "Description", "编辑主配置文件 (rim.ini)", "Keywords", "config setting ini edit"))
    RimCommand.Register("system.edit_auto_config", "Edit Auto Configuration", Cmd_SystemEditAutoConfig, Map("Category", "System", "Description", "编辑自动配置文件 (rim.auto.ini)", "Keywords", "auto config ini"))
    RimCommand.Register("system.lock", "Lock Workstation", Cmd_SystemLock, Map("Category", "System", "Description", "锁定 Windows 工作站", "Keywords", "lock workstation screen"))
    RimCommand.Register("system.sleep", "Sleep", Cmd_SystemSleep, Map("Category", "System", "Description", "系统进入睡眠模式", "Keywords", "sleep suspend standby"))
}
