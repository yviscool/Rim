#Requires AutoHotkey v2.0

; === TCCompare Plugin - TC内置文件比较工具 ===
; 完整移植自 VimDesktop 的 TCCompare 插件
; 支持 insert/normal 模式系统

RegisterPlugin_TCCompare() {
    RegisterWin("TCCompare", "TConvertForm", "TOTALCMD.EXE")

    ; 注册动作
    RegisterAction("<TCC_Edit>", "进入编辑模式")
    RegisterAction("<TCC_Recompare>", "重新比较")
    RegisterAction("<TCC_ToggleBinary>", "切换二进制比较")
    RegisterAction("<TCC_ToggleEncoding>", "切换编码")
    RegisterAction("<TCC_NextDiff>", "下一处不同")
    RegisterAction("<TCC_PrevDiff>", "上一处不同")
    RegisterAction("<TCC_Home>", "跳到开头")
    RegisterAction("<TCC_End>", "跳到结尾")
    RegisterAction("<TCC_Search>", "搜索")
    RegisterAction("<TCC_CopyToLeft>", "复制到左侧")
    RegisterAction("<TCC_CopyToRight>", "复制到右侧")
    RegisterAction("<TCC_Save>", "保存")
    RegisterAction("<TCC_Refresh>", "刷新比较")
    RegisterAction("<TCC_Compare>", "开始比较")
    RegisterAction("<TCC_BinaryMode>", "二进制模式")
    RegisterAction("<TCC_ChangeCodepage>", "切换代码页")

    ; insert 模式映射
    MapKey("<enter>", "<enter>", "TCCompare", "insert")
    MapKey("<bs>", "<bs>", "TCCompare", "insert")
    MapKey("<tab>", "<tab>", "TCCompare", "insert")
    MapKey("<space>", "<space>", "TCCompare", "insert")
    MapKey("<del>", "<del>", "TCCompare", "insert")

    ; normal 模式映射
    ; 编辑操作
    MapKey("m", "<TCC_Edit>", "TCCompare", "normal")
    MapKey("c", "<TCC_Recompare>", "TCCompare", "normal")
    MapKey("C", "<TCC_Compare>", "TCCompare", "normal")
    MapKey("s", "<TCC_Save>", "TCCompare", "normal")

    ; 比较模式
    MapKey("b", "<TCC_ToggleBinary>", "TCCompare", "normal")
    MapKey("B", "<TCC_BinaryMode>", "TCCompare", "normal")
    MapKey("-", "<TCC_ToggleEncoding>", "TCCompare", "normal")
    MapKey("+", "<TCC_ChangeCodepage>", "TCCompare", "normal")

    ; 导航
    MapKey("j", "<TCC_NextDiff>", "TCCompare", "normal")
    MapKey("k", "<TCC_PrevDiff>", "TCCompare", "normal")
    MapKey("gg", "<TCC_Home>", "TCCompare", "normal")
    MapKey("G", "<TCC_End>", "TCCompare", "normal")
    MapKey("/", "<TCC_Search>", "TCCompare", "normal")

    ; 复制操作
    MapKey("<", "<TCC_CopyToLeft>", "TCCompare", "normal")
    MapKey(">", "<TCC_CopyToRight>", "TCCompare", "normal")

    ; 刷新
    MapKey("R", "<TCC_Refresh>", "TCCompare", "normal")

    ; 模式切换
    MapKey("i", "<Gen_InsertMode>", "TCCompare", "normal")
    MapKey("<Esc>", "<Gen_NormalMode>", "TCCompare", "insert")
}

; === 动作函数 ===

TCC_Edit() {
    Send "e"
}

TCC_Recompare() {
    Send "c"
}

TCC_Compare() {
    Send "c"
}

TCC_ToggleBinary() {
    Send "b"
}

TCC_BinaryMode() {
    Send "b"
}

TCC_ToggleEncoding() {
    Send "-"
}

TCC_ChangeCodepage() {
    try {
        ibox := InputBox("输入代码页:`n65001 - UTF-8`n936 - 简体中文`n950 - 繁体中文", "切换代码页")
        codepage := ibox.Value
    } catch {
        return
    }
    if (codepage != "") {
        ; 通过菜单切换代码页
        Send "!{F3}"  ; 打开文件菜单
        Sleep 100
        Send "{Up}{Up}{Up}{Enter}"  ; 选择编码
    }
}

TCC_NextDiff() {
    ; 使用 Alt+N 跳转到下一个差异
    Send "!n"
}

TCC_PrevDiff() {
    ; 使用 Alt+P 跳转到上一个差异
    Send "!p"
}

TCC_Home() {
    Send "^{Home}"
}

TCC_End() {
    Send "^{End}"
}

TCC_Search() {
    Send "^f"
}

TCC_CopyToLeft() {
    ; 使用 Alt+Shift+< 复制到左侧
    Send "!+{,}"
}

TCC_CopyToRight() {
    ; 使用 Alt+Shift+> 复制到右侧
    Send "!+{.}"
}

TCC_Save() {
    Send "^s"
}

TCC_Refresh() {
    Send "{F5}"
}
