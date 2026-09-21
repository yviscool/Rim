#Requires AutoHotkey v2.0

; === WinMerge Plugin - 文件比较工具集成 ===
; 完整移植自 VimDesktop 的 WinMerge 插件
; 支持 insert/normal 模式系统

RegisterPlugin_WinMerge() {
    RegisterWin("WinMerge", "WinMergeWindowClassU", "WinMergeU.exe")

    ; 注册动作
    RegisterAction("<WM_NextDiff>", T("act.WinMerge.WM_NextDiff"))
    RegisterAction("<WM_PrevDiff>", T("act.WinMerge.WM_PrevDiff"))
    RegisterAction("<WM_FirstDiff>", T("act.WinMerge.WM_FirstDiff"))
    RegisterAction("<WM_LastDiff>", T("act.WinMerge.WM_LastDiff"))
    RegisterAction("<WM_CopyToLeft>", T("act.WinMerge.WM_CopyToLeft"))
    RegisterAction("<WM_CopyToRight>", T("act.WinMerge.WM_CopyToRight"))
    RegisterAction("<WM_CopyToLeftContinue>", T("act.WinMerge.WM_CopyToLeftContinue"))
    RegisterAction("<WM_CopyToRightContinue>", T("act.WinMerge.WM_CopyToRightContinue"))
    RegisterAction("<WM_CopyAllToLeft>", T("act.WinMerge.WM_CopyAllToLeft"))
    RegisterAction("<WM_CopyAllToRight>", T("act.WinMerge.WM_CopyAllToRight"))
    RegisterAction("<WM_Search>", T("act.WinMerge.WM_Search"))
    RegisterAction("<WM_Home>", T("act.WinMerge.WM_Home"))
    RegisterAction("<WM_End>", T("act.WinMerge.WM_End"))
    RegisterAction("<WM_Save>", T("act.WinMerge.WM_Save"))
    RegisterAction("<WM_Refresh>", T("act.WinMerge.WM_Refresh"))
    RegisterAction("<WM_Undo>", T("act.WinMerge.WM_Undo"))
    RegisterAction("<WM_Redo>", T("act.WinMerge.WM_Redo"))
    RegisterAction("<WM_NextFile>", T("act.WinMerge.WM_NextFile"))
    RegisterAction("<WM_PrevFile>", T("act.WinMerge.WM_PrevFile"))

    ; insert 模式映射
    MapKey("<enter>", "<enter>", "WinMerge", "insert")
    MapKey("<bs>", "<bs>", "WinMerge", "insert")
    MapKey("<tab>", "<tab>", "WinMerge", "insert")
    MapKey("<space>", "<space>", "WinMerge", "insert")
    MapKey("<del>", "<del>", "WinMerge", "insert")

    ; normal 模式映射
    ; 导航
    MapKey("j", "<WM_NextDiff>", "WinMerge", "normal")
    MapKey("k", "<WM_PrevDiff>", "WinMerge", "normal")
    MapKey("gg", "<WM_FirstDiff>", "WinMerge", "normal")
    MapKey("G", "<WM_LastDiff>", "WinMerge", "normal")
    MapKey("w", "<WM_Home>", "WinMerge", "normal")
    MapKey("e", "<WM_End>", "WinMerge", "normal")

    ; 复制操作
    MapKey("h", "<WM_CopyToLeft>", "WinMerge", "normal")
    MapKey("l", "<WM_CopyToRight>", "WinMerge", "normal")
    MapKey("H", "<WM_CopyToLeftContinue>", "WinMerge", "normal")
    MapKey("L", "<WM_CopyToRightContinue>", "WinMerge", "normal")
    MapKey("<C-h>", "<WM_CopyAllToLeft>", "WinMerge", "normal")
    MapKey("<C-l>", "<WM_CopyAllToRight>", "WinMerge", "normal")

    ; 搜索
    MapKey("/", "<WM_Search>", "WinMerge", "normal")

    ; 文件操作
    MapKey("<c-s>", "<WM_Save>", "WinMerge", "normal")
    MapKey("R", "<WM_Refresh>", "WinMerge", "normal")
    MapKey("u", "<WM_Undo>", "WinMerge", "normal")
    MapKey("U", "<WM_Redo>", "WinMerge", "normal")

    ; 文件切换
    MapKey("n", "<WM_NextFile>", "WinMerge", "normal")
    MapKey("p", "<WM_PrevFile>", "WinMerge", "normal")

    ; 模式切换
    MapKey("i", "<Gen_InsertMode>", "WinMerge", "normal")
    MapKey("<Esc>", "<Gen_NormalMode>", "WinMerge", "insert")
}

; === 动作函数 ===

WM_NextDiff() {
    Send "!{Down}"
}

WM_PrevDiff() {
    Send "!{Up}"
}

WM_FirstDiff() {
    Send "!{Home}"
}

WM_LastDiff() {
    Send "!{End}"
}

WM_CopyToLeft() {
    Send "!{Left}"
}

WM_CopyToRight() {
    Send "!{Right}"
}

WM_CopyToLeftContinue() {
    Send "!{Left}"
    Sleep 100
    Send "{Down}"
}

WM_CopyToRightContinue() {
    Send "!{Right}"
    Sleep 100
    Send "{Down}"
}

WM_CopyAllToLeft() {
    Send "^!{Left}"
}

WM_CopyAllToRight() {
    Send "^!{Right}"
}

WM_Search() {
    Send "^f"
}

WM_Home() {
    Send "^{Home}"
}

WM_End() {
    Send "^{End}"
}

WM_Save() {
    Send "^s"
}

WM_Refresh() {
    Send "{F5}"
}

WM_Undo() {
    Send "^z"
}

WM_Redo() {
    Send "^y"
}

WM_NextFile() {
    Send "^{Tab}"
}

WM_PrevFile() {
    Send "^+{Tab}"
}
