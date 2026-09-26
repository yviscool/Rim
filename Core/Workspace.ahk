#Requires AutoHotkey v2.0
#Warn All, Off

; === Core/Workspace.ahk - Rim 工作空间引擎 (Workspace Engine) ===
; 一键编排与恢复整套工作要素 (编辑器 + 终端 + TC/Explorer 路径 + 浏览器文档)
; 告别手动重复打开多窗口、cd 目录、摆放界面的机械劳动

class RimWorkspaceItem {
    Name := ""
    Title := ""
    Root := ""
    Editor := "code"      ; "code", "notepad", 或空
    Terminal := true      ; 是否在根目录开启终端
    TC := true            ; 是否在 TC 中打开对应面板
    TCLeft := ""          ; TC 左栏路径 (留空取 Root)
    TCRight := ""         ; TC 右栏路径 (留空取 Root)
    Explorer := false     ; 是否在资源管理器中打开
    Urls := []            ; 关联打开的网页/文档
    Description := ""     ; 说明文本
}

class RimWorkspace {
    static Workspaces := Map()

    static GetConfigFile() {
        SplitPath(A_LineFile, , &dir)
        SplitPath(dir, , &rootDir)
        return rootDir . "\Conf\workspaces.ini"
    }

    static GetRootDir() {
        SplitPath(A_LineFile, , &dir)
        SplitPath(dir, , &rootDir)
        return rootDir
    }

    ; 初始化工作空间系统并加载配置
    static Init() {
        RimWorkspace.Workspaces := Map()
        cfgFile := RimWorkspace.GetConfigFile()
        appRoot := RimWorkspace.GetRootDir()

        ; 若无配置文件，创建基础默认配置
        if (!FileExist(cfgFile)) {
            defaultIni := (
                "[Workspace:rim]`n"
                . "title=Rim Core Dev`n"
                . "root=" . appRoot . "`n"
                . "editor=code`n"
                . "terminal=1`n"
                . "tc=1`n"
                . "tc_left=" . appRoot . "\Core`n"
                . "tc_right=" . appRoot . "\Plugins`n"
                . "desc=" . T("ws.desc_rim") . "`n`n"
                . "[Workspace:dev]`n"
                . "title=General Development`n"
                . "root=C:\`n"
                . "editor=code`n"
                . "terminal=1`n"
                . "tc=1`n"
                . "desc=" . T("ws.desc_dev") . "`n`n"
                . "[Workspace:files]`n"
                . "title=File Management`n"
                . "tc=1`n"
                . "tc_left=C:\`n"
                . "tc_right=D:\`n"
                . "desc=" . T("ws.desc_files") . "`n"
            )
            try FileAppend(defaultIni, cfgFile, "UTF-8")
        }

        ; 解析 Conf/workspaces.ini
        try {
            iniObj := EasyIni(cfgFile)
            for secName, sec in iniObj.GetSections() {
                if (SubStr(secName, 1, 10) = "Workspace:") {
                    wsName := SubStr(secName, 11)
                    item := RimWorkspaceItem()
                    item.Name := wsName
                    item.Title := iniObj.Get(secName, "title", wsName)
                    item.Root := iniObj.Get(secName, "root", "")
                    item.Editor := iniObj.Get(secName, "editor", "code")
                    item.Terminal := iniObj.Get(secName, "terminal", "1") = "1"
                    item.TC := iniObj.Get(secName, "tc", "1") = "1"
                    item.TCLeft := iniObj.Get(secName, "tc_left", "")
                    item.TCRight := iniObj.Get(secName, "tc_right", "")
                    item.Explorer := iniObj.Get(secName, "explorer", "0") = "1"
                    item.Description := iniObj.Get(secName, "desc", "")

                    urlsStr := iniObj.Get(secName, "urls", "")
                    if (urlsStr != "") {
                        for u in StrSplit(urlsStr, "|") {
                            trimmed := Trim(u)
                            if (trimmed != "")
                                item.Urls.Push(trimmed)
                        }
                    }

                    RimWorkspace.Workspaces[StrLower(wsName)] := item

                    ; 注册为一级语义指令，供 Palette 与快捷键秒级唤醒
                    try {
                        RimCommand.Register("workspace." . wsName, item.Title, (*) => RimWorkspace.Open(wsName), Map(
                            "Category", "Workspace",
                            "Description", item.Description != "" ? item.Description : T("ws.fallback_desc", item.Title),
                            "Keywords", "ws workspace " . wsName
                        ))
                    } catch {
                    }
                }
            }
        } catch {
        }
    }

    ; 获取工作空间
    static Get(name) {
        key := StrLower(Trim(name))
        if RimWorkspace.Workspaces.Has(key)
            return RimWorkspace.Workspaces[key]
        return ""
    }

    ; 列出所有工作空间
    static List() {
        list := []
        for name, ws in RimWorkspace.Workspaces
            list.Push(ws)
        return list
    }

    ; 激活 / 恢复工作空间 (支持空间名或目标文件夹路径)
    static Open(target) {
        target := Trim(target)
        if (target = "")
            return

        ws := RimWorkspace.Get(target)
        root := ""

        if (IsObject(ws)) {
            root := ws.Root != "" ? ws.Root : A_ScriptDir
        } else if (DirExist(target)) {
            ; 传入的是已有文件夹路径 -> 自动构建即时 Project 空间
            root := target
            ws := RimWorkspaceItem()
            ws.Name := "adhoc"
            ws.Title := target
            ws.Root := target
            ws.Editor := "code"
            ws.Terminal := true
            ws.TC := true
        } else {
            ToolTip("Workspace not found: " . target)
            SetTimer(() => ToolTip(), -1500)
            return
        }

        ; 1. 启动/激活编辑器
        if (ws.Editor != "" && root != "") {
            try {
                if (ws.Editor = "code")
                    Run('code "' . root . '"')
                else
                    Run(ws.Editor . ' "' . root . '"')
            } catch {
            }
        }

        ; 2. 启动/激活终端并定位到 Root 目录
        if (ws.Terminal && root != "") {
            try {
                Run('wt.exe -d "' . root . '"')
            } catch {
                try {
                    Run('powershell.exe -NoExit', root)
                } catch {
                    Run(A_ComSpec, root)
                }
            }
        }

        ; 3. Total Commander 双栏联动
        if (ws.TC) {
            leftPath := ws.TCLeft != "" ? ws.TCLeft : root
            rightPath := ws.TCRight != "" ? ws.TCRight : root
            tcPath := ""
            try {
                global g_Conf
                if (IsObject(g_Conf) && g_Conf.HasSection("Config"))
                    tcPath := g_Conf.Get("Config", "TCPath", "")
            }
            if (tcPath != "" && FileExist(tcPath)) {
                args := '/O /A /T'
                if (leftPath != "")
                    args .= ' /L="' . leftPath . '"'
                if (rightPath != "")
                    args .= ' /R="' . rightPath . '"'
                try Run(tcPath . ' ' . args)
            } else if (ws.Explorer && root != "") {
                try Run('explorer "' . root . '"')
            }
        } else if (ws.Explorer && root != "") {
            try Run('explorer "' . root . '"')
        }

        ; 4. 打开关联网页/文档
        if (IsObject(ws.Urls)) {
            for u in ws.Urls {
                try Run(u)
            }
        }

        ToolTip("Workspace Loaded: " . ws.Title)
        SetTimer(() => ToolTip(), -1500)
    }

    ; 保存工作空间至 Conf/workspaces.ini
    static Save(name, root := "", editor := "code", terminal := "1", tc := "1", tcLeft := "", tcRight := "", desc := "") {
        name := Trim(name)
        if (name = "")
            return false

        secName := "Workspace:" . name
        try {
            iniObj := EasyIni(RimWorkspace.GetConfigFile())
            iniObj.AddSection(secName)
            iniObj.Set(secName, "title", name)
            if (root != "")
                iniObj.Set(secName, "root", root)
            iniObj.Set(secName, "editor", editor)
            iniObj.Set(secName, "terminal", terminal)
            iniObj.Set(secName, "tc", tc)
            if (tcLeft != "")
                iniObj.Set(secName, "tc_left", tcLeft)
            if (tcRight != "")
                iniObj.Set(secName, "tc_right", tcRight)
            if (desc != "")
                iniObj.Set(secName, "desc", desc)
            iniObj.Save()
            RimWorkspace.Init()
            return true
        } catch {
            return false
        }
    }

    ; 删除工作空间
    static Delete(name) {
        name := Trim(name)
        if (name = "")
            return false

        secName := "Workspace:" . name
        try {
            iniObj := EasyIni(RimWorkspace.GetConfigFile())
            if (iniObj.HasSection(secName)) {
                iniObj.DeleteSection(secName)
                iniObj.Save()
                RimWorkspace.Init()
                return true
            }
        } catch {
        }
        return false
    }

    ; 从当前运行环境捕获快照
    static CaptureCurrent(name) {
        ctx := GetActiveContext()
        root := ctx.CurrentDir != "" ? ctx.CurrentDir : (ctx.SelectedFile != "" ? ctx.SelectedFile : A_ScriptDir)
        return RimWorkspace.Save(name, root, "code", "1", "1", root, root, "Captured Workspace: " . name)
    }
}

; === 指令注册与调度初始化 ===
InitWorkspaceCommands() {
    RimWorkspace.Init()

    RimCommand.Register("workspace.open", T("cmdtitle.workspace.open"), (arg := "") => RimWorkspace.Open(arg), Map(
        "Category", "Workspace",
        "Description", T("cmd.workspace.open"),
        "Keywords", "workspace open ws switch restore"
    ))

    RimCommand.Register("workspace.save", T("cmdtitle.workspace.save"), (arg := "") => RimWorkspace.CaptureCurrent(arg != "" ? arg : "snapshot"), Map(
        "Category", "Workspace",
        "Description", T("cmd.workspace.save"),
        "Keywords", "workspace save snapshot"
    ))

    ; 窗口布局指令挂载
    RimCommand.Register("window.tile_left", T("cmdtitle.window.tile_left"), (*) => RimWindow.Tile("A", "left"), Map(
        "Category", "Window",
        "Description", T("cmd.workspace.tile_left"),
        "Keywords", "window tile left half"
    ))

    RimCommand.Register("window.tile_right", T("cmdtitle.window.tile_right"), (*) => RimWindow.Tile("A", "right"), Map(
        "Category", "Window",
        "Description", T("cmd.workspace.tile_right"),
        "Keywords", "window tile right half"
    ))

    RimCommand.Register("window.tile_top", T("cmdtitle.window.tile_top"), (*) => RimWindow.Tile("A", "top"), Map(
        "Category", "Window",
        "Description", T("cmd.workspace.tile_top"),
        "Keywords", "window tile top half"
    ))

    RimCommand.Register("window.tile_bottom", T("cmdtitle.window.tile_bottom"), (*) => RimWindow.Tile("A", "bottom"), Map(
        "Category", "Window",
        "Description", T("cmd.workspace.tile_bottom"),
        "Keywords", "window tile bottom half"
    ))

    RimCommand.Register("window.next_monitor", T("cmdtitle.window.next_monitor"), (*) => RimWindow.MoveToNextMonitor("A"), Map(
        "Category", "Window",
        "Description", T("cmd.workspace.next_monitor"),
        "Keywords", "window monitor screen next display"
    ))
}
