#Requires AutoHotkey v2.0

; === WinMerge Plugin - 文件比较工具集成 ===
; 完整移植自 VimDesktop 的 WinMerge 插件
; 支持 insert/normal 模式系统

RegisterPlugin_WinMerge() {
    RegisterWin("WinMerge", "WinMergeWindowClassU", "WinMergeU.exe")

    ; 注册动作
    RegisterAction("<WM_NextDiff>", "下一处不同")
    RegisterAction("<WM_PrevDiff>", "上一处不同")
    RegisterAction("<WM_FirstDiff>", "第一处不同")
    RegisterAction("<WM_LastDiff>", "最后一处不同")
    RegisterAction("<WM_CopyToLeft>", "复制到左侧")
    RegisterAction("<WM_CopyToRight>", "复制到右侧")
    RegisterAction("<WM_CopyToLeftContinue>", "复制到左侧并继续")
    RegisterAction("<WM_CopyToRightContinue>", "复制到右侧并继续")
    RegisterAction("<WM_CopyAllToLeft>", "全部复制到左侧")
    RegisterAction("<WM_CopyAllToRight>", "全部复制到右侧")
    RegisterAction("<WM_Search>", "搜索")
    RegisterAction("<WM_Home>", "跳到开头")
    RegisterAction("<WM_End>", "跳到结尾")
    RegisterAction("<WM_Save>", "保存")
    RegisterAction("<WM_Refresh>", "刷新")
    RegisterAction("<WM_Undo>", "撤销")
    RegisterAction("<WM_Redo>", "重做")
    RegisterAction("<WM_NextFile>", "下一个文件")
    RegisterAction("<WM_PrevFile>", "上一个文件")

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
