#Requires AutoHotkey v2.0

; === Explorer Plugin - Windows资源管理器增强 ===
; 完整移植自 VimDesktop 的 Explorer 插件
; 支持 COM 接口获取路径, insert/normal 模式系统

RegisterPlugin_Explorer() {
    ; 窗名与 ini [CabinetWClass] 对齐 (原 custom ini 即如此), 避免孤儿窗
    RegisterWin("CabinetWClass", "CabinetWClass", "explorer.exe")
    g_VimEngine.SetBeforeActionDoForWin("CabinetWClass", Explorer_ForceInsertMode)

    ; 注册动作
    RegisterAction("<Exp_Back>", "返回上级目录")
    RegisterAction("<Exp_Forward>", "前进")
    RegisterAction("<Exp_Up>", "上层目录")
    RegisterAction("<Exp_Refresh>", "刷新")
    RegisterAction("<Exp_Rename>", "重命名")
    RegisterAction("<Exp_Delete>", "删除")
    RegisterAction("<Exp_NewFolder>", "新建文件夹")
    RegisterAction("<Exp_ToggleView>", "切换视图")
    RegisterAction("<Exp_ToggleTree>", "切换目录树")
    RegisterAction("<Exp_CopyPath>", "复制路径")
    RegisterAction("<Exp_OpenInTC>", "用TC打开")
    RegisterAction("<Exp_OpenInTCX>", "用TC打开并关闭")
    RegisterAction("<Exp_OpenInTCNewTab>", "用TC新标签打开")
    RegisterAction("<Exp_GoHome>", "跳到主目录")
    RegisterAction("<Exp_GoEnd>", "跳到末尾")
    RegisterAction("<Exp_FocusTree>", "定位到目录树")
    RegisterAction("<Exp_FocusFiles>", "定位到文件栏")
    RegisterAction("<Exp_TreeBack>", "目录树返回")
    RegisterAction("<Exp_TreeForward>", "目录树前进")
    RegisterAction("<Exp_TreeUp>", "目录树上层")
    RegisterAction("<Exp_TreeDown>", "目录树下层")

    ; 设置 insert 模式映射 (所有键传递)
    MapKey("<enter>", "<enter>", "CabinetWClass", "insert")
    MapKey("<bs>", "<bs>", "CabinetWClass", "insert")
    MapKey("<tab>", "<tab>", "CabinetWClass", "insert")
    MapKey("<space>", "<space>", "CabinetWClass", "insert")
    MapKey("<del>", "<del>", "CabinetWClass", "insert")

    ; 设置 normal 模式映射
    ; 导航
    MapKey("h", "<Exp_Back>", "CabinetWClass", "normal")
    MapKey("l", "<Exp_Forward>", "CabinetWClass", "normal")
    MapKey("H", "<Exp_Up>", "CabinetWClass", "normal")
    MapKey("<C-h>", "<Exp_TreeBack>", "CabinetWClass", "normal")
    MapKey("<C-l>", "<Exp_TreeForward>", "CabinetWClass", "normal")
    MapKey("<C-j>", "<Exp_TreeDown>", "CabinetWClass", "normal")
    MapKey("<C-k>", "<Exp_TreeUp>", "CabinetWClass", "normal")

    ; 文件操作
    MapKey("r", "<Exp_Rename>", "CabinetWClass", "normal")
    MapKey("d", "<Exp_Delete>", "CabinetWClass", "normal")
    MapKey("n", "<Exp_NewFolder>", "CabinetWClass", "normal")
    MapKey("R", "<Exp_Refresh>", "CabinetWClass", "normal")

    ; 视图
    MapKey("t", "<Exp_ToggleView>", "CabinetWClass", "normal")
    MapKey("m", "<Exp_ToggleTree>", "CabinetWClass", "normal")
    MapKey("y", "<Exp_CopyPath>", "CabinetWClass", "normal")

    ; 跳转
    MapKey("gg", "<Exp_GoHome>", "CabinetWClass", "normal")
    MapKey("G", "<Exp_GoEnd>", "CabinetWClass", "normal")

    ; 焦点控制
    MapKey("<C-w>h", "<Exp_FocusTree>", "CabinetWClass", "normal")
    MapKey("<C-w>l", "<Exp_FocusFiles>", "CabinetWClass", "normal")

    ; TC 集成
    MapKey("<S-f>", "<Exp_OpenInTC>", "CabinetWClass", "normal")
    MapKey("<S-F>", "<Exp_OpenInTCX>", "CabinetWClass", "normal")
    MapKey("<C-t>", "<Exp_OpenInTCNewTab>", "CabinetWClass", "normal")

    ; 模式切换
    MapKey("i", "<Gen_InsertMode>", "CabinetWClass", "normal")
    MapKey("<Esc>", "<Gen_NormalMode>", "CabinetWClass", "insert")
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
        ToolTip("已复制路径: " path)
        SetTimer () => ToolTip(), -1500
    } else {
        ; 回退方案：从标题获取
        try {
            title := WinGetTitle("A")
            if RegExMatch(title, "^([^:]+:)", &match) {
                A_Clipboard := match[1]
                ToolTip("已复制路径: " match[1])
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
