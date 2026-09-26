#Requires AutoHotkey v2.0

; === Explorer Plugin - Windows资源管理器增强 ===
; 完整移植自 VimDesktop 的 Explorer 插件
; 支持 COM 接口获取路径, insert/normal 模式系统

class ExplorerPlugin extends RimPlugin {
    static Name => "Explorer"
    static Title => "Windows Explorer Enhancement"
    static Description => "Windows 资源管理器增强 (Vim 模式、路径提取、TC联动)"

    static RegisterContext() {
        try RimContext.RegisterProvider("explorer", Explorer_ContextProvider)
    }

    static RegisterCommands() {
        try {
            RimCommand.Register("explorer.open_tc", T("cmdtitle.explorer.open_tc"), (*) => Exp_OpenInTC(), Map(
                "Category", "File",
                "Description", "在 Total Commander 中打开当前资源管理器路径",
                "ContextFilter", (ctx) => ctx.AppId = "explorer"
            ))
            RimCommand.Register("explorer.copy_path", T("cmdtitle.explorer.copy_path"), (*) => Exp_CopyPath(), Map(
                "Category", "File",
                "Description", "复制当前资源管理器中的文件夹路径",
                "ContextFilter", (ctx) => ctx.AppId = "explorer"
            ))
        }
    }

    static RegisterGestures() {
        if (!IsSet(GestureRegistry) || !IsObject(GestureRegistry))
            return
        GestureRegistry.Register("U", (*) => Send("!{Up}"), "ahk_class CabinetWClass", {
            description: "Explorer: 返回上层目录",
            pluginName: "Explorer"
        })
        GestureRegistry.Register("L", (*) => Send("!{Left}"), "ahk_class CabinetWClass", {
            description: "Explorer: 后退",
            pluginName: "Explorer"
        })
        GestureRegistry.Register("R", (*) => Send("!{Right}"), "ahk_class CabinetWClass", {
            description: "Explorer: 前进",
            pluginName: "Explorer"
        })
    }

    static RegisterKeymaps(engine) {
        Explorer_Keymaps(engine)
    }
}

if (IsSet(RimPluginManager) && IsObject(RimPluginManager))
    RimPluginManager.Register(ExplorerPlugin)

Explorer_Keymaps(engine) {
    ; 窗名与 ini [CabinetWClass] 对齐 (原 custom ini 即如此), 避免孤儿窗
    engine.SetWin("CabinetWClass", "CabinetWClass", "explorer.exe")
    g_VimEngine.SetBeforeActionDoForWin("CabinetWClass", Explorer_ForceInsertMode)

    ; 注册动作
    engine.SetAction("<Exp_Back>", T("act.Explorer.Exp_Back"))
    engine.SetAction("<Exp_Forward>", T("act.Explorer.Exp_Forward"))
    engine.SetAction("<Exp_Up>", T("act.Explorer.Exp_Up"))
    engine.SetAction("<Exp_Refresh>", T("act.Explorer.Exp_Refresh"))
    engine.SetAction("<Exp_Rename>", T("act.Explorer.Exp_Rename"))
    engine.SetAction("<Exp_Delete>", T("act.Explorer.Exp_Delete"))
    engine.SetAction("<Exp_NewFolder>", T("act.Explorer.Exp_NewFolder"))
    engine.SetAction("<Exp_ToggleView>", T("act.Explorer.Exp_ToggleView"))
    engine.SetAction("<Exp_ToggleTree>", T("act.Explorer.Exp_ToggleTree"))
    engine.SetAction("<Exp_CopyPath>", T("act.Explorer.Exp_CopyPath"))
    engine.SetAction("<Exp_OpenInTC>", T("act.Explorer.Exp_OpenInTC"))
    engine.SetAction("<Exp_OpenInTCX>", T("act.Explorer.Exp_OpenInTCX"))
    engine.SetAction("<Exp_OpenInTCNewTab>", T("act.Explorer.Exp_OpenInTCNewTab"))
    engine.SetAction("<Exp_GoHome>", T("act.Explorer.Exp_GoHome"))
    engine.SetAction("<Exp_GoEnd>", T("act.Explorer.Exp_GoEnd"))
    engine.SetAction("<Exp_FocusTree>", T("act.Explorer.Exp_FocusTree"))
    engine.SetAction("<Exp_FocusFiles>", T("act.Explorer.Exp_FocusFiles"))
    engine.SetAction("<Exp_TreeBack>", T("act.Explorer.Exp_TreeBack"))
    engine.SetAction("<Exp_TreeForward>", T("act.Explorer.Exp_TreeForward"))
    engine.SetAction("<Exp_TreeUp>", T("act.Explorer.Exp_TreeUp"))
    engine.SetAction("<Exp_TreeDown>", T("act.Explorer.Exp_TreeDown"))

    ; 设置 insert 模式映射 (所有键传递)
    engine.MapKey("<enter>", "<enter>", "CabinetWClass", "insert")
    engine.MapKey("<bs>", "<bs>", "CabinetWClass", "insert")
    engine.MapKey("<tab>", "<tab>", "CabinetWClass", "insert")
    engine.MapKey("<space>", "<space>", "CabinetWClass", "insert")
    engine.MapKey("<del>", "<del>", "CabinetWClass", "insert")

    ; 设置 normal 模式映射
    ; 导航
    engine.MapKey("h", "<Exp_Back>", "CabinetWClass", "normal")
    engine.MapKey("l", "<Exp_Forward>", "CabinetWClass", "normal")
    engine.MapKey("H", "<Exp_Up>", "CabinetWClass", "normal")
    engine.MapKey("<C-h>", "<Exp_TreeBack>", "CabinetWClass", "normal")
    engine.MapKey("<C-l>", "<Exp_TreeForward>", "CabinetWClass", "normal")
    engine.MapKey("<C-j>", "<Exp_TreeDown>", "CabinetWClass", "normal")
    engine.MapKey("<C-k>", "<Exp_TreeUp>", "CabinetWClass", "normal")

    ; 文件操作
    engine.MapKey("r", "<Exp_Rename>", "CabinetWClass", "normal")
    engine.MapKey("d", "<Exp_Delete>", "CabinetWClass", "normal")
    engine.MapKey("n", "<Exp_NewFolder>", "CabinetWClass", "normal")
    engine.MapKey("R", "<Exp_Refresh>", "CabinetWClass", "normal")

    ; 视图
    engine.MapKey("t", "<Exp_ToggleView>", "CabinetWClass", "normal")
    engine.MapKey("m", "<Exp_ToggleTree>", "CabinetWClass", "normal")
    engine.MapKey("y", "<Exp_CopyPath>", "CabinetWClass", "normal")

    ; 跳转
    engine.MapKey("gg", "<Exp_GoHome>", "CabinetWClass", "normal")
    engine.MapKey("G", "<Exp_GoEnd>", "CabinetWClass", "normal")

    ; 焦点控制
    engine.MapKey("<C-w>h", "<Exp_FocusTree>", "CabinetWClass", "normal")
    engine.MapKey("<C-w>l", "<Exp_FocusFiles>", "CabinetWClass", "normal")

    ; TC 集成
    engine.MapKey("<S-f>", "<Exp_OpenInTC>", "CabinetWClass", "normal")
    engine.MapKey("<S-F>", "<Exp_OpenInTCX>", "CabinetWClass", "normal")
    engine.MapKey("<C-t>", "<Exp_OpenInTCNewTab>", "CabinetWClass", "normal")

    ; 模式切换
    engine.MapKey("i", "<Gen_InsertMode>", "CabinetWClass", "normal")
    engine.MapKey("<Esc>", "<Gen_NormalMode>", "CabinetWClass", "insert")

    ; 注册上下文提供者
    try {
        RimContext.RegisterProvider("explorer", Explorer_ContextProvider)
    }
}

; 输入框/树/菜单内透传原键 (对齐原版 Explorer_ForceInsertMode)
Explorer_ForceInsertMode(actionName, win) {
    try {
        focused := FocusedClassNN("A")
        if (focused = "Edit1" || focused = "DirectUIHWND1" || focused = "SysTreeView321")
            return true
    }
    try {
        if WinExist("ahk_class #32768")
            return true
    }
    return false
}

; === 辅助函数 ===

; 获取当前 Explorer 路径 (COM 接口)
Explorer_GetPath() {
    try {
        hwnd := WinActive("A")
        for window in ComObject("Shell.Application").Windows {
            if (window.hwnd = hwnd) {
                return window.Document.Folder.Self.Path
            }
        }
    }
    return ""
}

; 获取当前 Explorer 窗口对象
Explorer_GetWindow() {
    try {
        hwnd := WinActive("A")
        for window in ComObject("Shell.Application").Windows {
            if (window.hwnd = hwnd) {
                return window
            }
        }
    }
    return ""
}

; 获取当前 Explorer 选中文件列表
Explorer_GetSelectedFiles() {
    results := []
    try {
        hwnd := WinActive("A")
        for window in ComObject("Shell.Application").Windows {
            if (window.hwnd = hwnd) {
                for item in window.Document.SelectedItems()
                    results.Push(item.Path)
                break
            }
        }
    }
    return results
}

; 获取当前选中的单个文件 (取首个)
Explorer_GetSelectedFile() {
    files := Explorer_GetSelectedFiles()
    return files.Length > 0 ? files[1] : ""
}

; Explorer 上下文提供者
Explorer_ContextProvider(ctx) {
    p := Explorer_GetPath()
    if (p != "")
        ctx.CurrentDir := p
    sel := Explorer_GetSelectedFiles()
    if (sel.Length > 0) {
        ctx.SelectedFiles := sel
        ctx.SelectedFile := sel[1]
    }
}

; === 动作函数 ===

Exp_Back() {
    Send "{Alt}{Left}"
}

Exp_Forward() {
    Send "{Alt}{Right}"
}

Exp_Up() {
    Send "{Alt}{Up}"
}

Exp_Refresh() {
    Send "{F5}"
}

Exp_Rename() {
    Send "{F2}"
}

Exp_Delete() {
    Send "{Del}"
}

Exp_NewFolder() {
    Send "^{Shift}n"
}

Exp_ToggleView() {
    ; 循环切换视图: 大图标/详细信息/列表/小图标
    static views := ["{F6}", "^{Shift}6", "^{Shift}5", "^{Shift}4"]
    static idx := 2
    idx := Mod(idx, views.Length) + 1
    Send views[idx]
}

Exp_ToggleTree() {
    Send "!{Shift}d"  ; 切换导航窗格
}

Exp_CopyPath() {
    ; 使用 COM 接口复制路径
    path := Explorer_GetPath()
    if (path != "") {
        A_Clipboard := path
        ToolTip(T("exp.copied_path", path))
        SetTimer () => ToolTip(), -1500
    } else {
        ; 回退方案：从标题获取
        try {
            title := WinGetTitle("A")
            if RegExMatch(title, "^([^:]+:)", &match) {
                A_Clipboard := match[1]
                ToolTip(T("exp.copied_path", match[1]))
                SetTimer () => ToolTip(), -1500
            }
        }
    }
}

; TC 路径: 插件全局 > 配置文件
Exp_TCPath() {
    global TCPath
    if (TCPath != "")
        return TCPath
    try {
        global g_Conf
        return g_Conf.Get("Config", "TCPath", "")
    }
    return ""
}

Exp_OpenInTC() {
    ; 用TC打开当前目录
    path := Explorer_GetPath()
    if (path = "") {
        try {
            title := WinGetTitle("A")
            if RegExMatch(title, "^([^:]+:)", &match)
                path := match[1]
        }
    }

    _tc := Exp_TCPath()
    if (path != "" && _tc != "")
        Run('"' _tc '" /O /A /L="' path '"')
}

Exp_OpenInTCX() {
    ; 用TC打开并关闭当前窗口
    path := Explorer_GetPath()
    if (path = "")
        return

    _tc := Exp_TCPath()
    if (_tc != "") {
        Run('"' _tc '" /O /A /L="' path '"')
        Sleep(500)
        WinClose("A")
    }
}

Exp_OpenInTCNewTab() {
    ; 用TC新标签打开
    path := Explorer_GetPath()
    if (path = "")
        return

    _tc := Exp_TCPath()
    if (_tc != "")
        Run('"' _tc '" /O /A /T /L="' path '"')
}

Exp_GoHome() {
    ; 跳到第一个文件
    Send "{Home}"
}

Exp_GoEnd() {
    ; 跳到最后一个文件
    Send "{End}"
}

Exp_FocusTree() {
    ; 定位到目录树
    try {
        ControlFocus("SysTreeView321", "A")
    }
}

Exp_FocusFiles() {
    ; 定位到文件栏
    try {
        ControlFocus("DirectUIHWND3", "A")
    }
}

Exp_TreeBack() {
    ; 目录树返回
    ControlFocus("SysTreeView321", "A")
    Send "{Left}"
}

Exp_TreeForward() {
    ; 目录树前进
    ControlFocus("SysTreeView321", "A")
    Send "{Right}"
}

Exp_TreeUp() {
    ; 目录树上层
    ControlFocus("SysTreeView321", "A")
    Send "{Up}"
}

Exp_TreeDown() {
    ; 目录树下层
    ControlFocus("SysTreeView321", "A")
    Send "{Down}"
}
