#Requires AutoHotkey v2.0

; === BeyondCompare4 Plugin ===
; 完整移植自 VimDesktop 的 BeyondCompare4 插件
; 支持 insert/normal 模式系统

RegisterPlugin_BeyondCompare4() {
    RegisterWin("BeyondCompare4", "TConvertForm", "BCompare.exe")

    ; 注册动作
    RegisterAction("<BC4_NextDiff>", "下一处不同")
    RegisterAction("<BC4_PrevDiff>", "上一处不同")
    RegisterAction("<BC4_NextDiffLine>", "下一处行级不同")
    RegisterAction("<BC4_PrevDiffLine>", "上一处行级不同")
    RegisterAction("<BC4_CopyToLeft>", "复制到左侧")
    RegisterAction("<BC4_CopyToRight>", "复制到右侧")
    RegisterAction("<BC4_CopyToLeftContinue>", "复制到左侧并继续")
    RegisterAction("<BC4_CopyToRightContinue>", "复制到右侧并继续")
    RegisterAction("<BC4_Search>", "搜索")
    RegisterAction("<BC4_Home>", "跳到开头")
    RegisterAction("<BC4_End>", "跳到结尾")
    RegisterAction("<BC4_Save>", "保存")
    RegisterAction("<BC4_Refresh>", "刷新比较")
    RegisterAction("<BC4_Compare>", "开始比较")
    RegisterAction("<BC4_NextSection>", "下一个差异段")
    RegisterAction("<BC4_PrevSection>", "上一个差异段")

    ; insert 模式映射
    MapKey("<enter>", "<enter>", "BeyondCompare4", "insert")
    MapKey("<bs>", "<bs>", "BeyondCompare4", "insert")
    MapKey("<tab>", "<tab>", "BeyondCompare4", "insert")
    MapKey("<space>", "<space>", "BeyondCompare4", "insert")
    MapKey("<del>", "<del>", "BeyondCompare4", "insert")

    ; normal 模式映射
    ; 导航
    MapKey("j", "<BC4_NextDiff>", "BeyondCompare4", "normal")
    MapKey("k", "<BC4_PrevDiff>", "BeyondCompare4", "normal")
    MapKey("J", "<BC4_NextDiffLine>", "BeyondCompare4", "normal")
    MapKey("K", "<BC4_PrevDiffLine>", "BeyondCompare4", "normal")
    MapKey("n", "<BC4_NextSection>", "BeyondCompare4", "normal")
    MapKey("p", "<BC4_PrevSection>", "BeyondCompare4", "normal")
    MapKey("gg", "<BC4_Home>", "BeyondCompare4", "normal")
    MapKey("G", "<BC4_End>", "BeyondCompare4", "normal")

    ; 复制操作
    MapKey("h", "<BC4_CopyToLeft>", "BeyondCompare4", "normal")
    MapKey("l", "<BC4_CopyToRight>", "BeyondCompare4", "normal")
    MapKey("H", "<BC4_CopyToLeftContinue>", "BeyondCompare4", "normal")
    MapKey("L", "<BC4_CopyToRightContinue>", "BeyondCompare4", "normal")

    ; 搜索
    MapKey("/", "<BC4_Search>", "BeyondCompare4", "normal")

    ; 文件操作
    MapKey("<c-s>", "<BC4_Save>", "BeyondCompare4", "normal")
    MapKey("R", "<BC4_Refresh>", "BeyondCompare4", "normal")
    MapKey("C", "<BC4_Compare>", "BeyondCompare4", "normal")

    ; 模式切换
    MapKey("i", "<Gen_InsertMode>", "BeyondCompare4", "normal")
    MapKey("<Esc>", "<Gen_NormalMode>", "BeyondCompare4", "insert")
}

; === 动作函数 ===

BC4_NextDiff() {
    Send "{Down}{Down}{Down}{Down}{Down}{Down}{Down}{Down}{Down}{Down}{F4}"
}

BC4_PrevDiff() {
    Send "{Up}{Up}{Up}{Up}{Up}{Up}{Up}{Up}{Up}{Up}{Shift}{F4}"
}

BC4_NextDiffLine() {
    Send "!{Down}"
}

BC4_PrevDiffLine() {
    Send "!{Up}"
}

BC4_NextSection() {
    Send "{Down}{Down}{Down}{Down}{Down}{Down}{Down}{Down}{Down}{Down}{F4}"
}

BC4_PrevSection() {
    Send "{Up}{Up}{Up}{Up}{Up}{Up}{Up}{Up}{Up}{Up}{Shift}{F4}"
}

BC4_CopyToLeft() {
    Send "!{Left}"
}

BC4_CopyToRight() {
    Send "!{Right}"
}

BC4_CopyToLeftContinue() {
    Send "!{Left}"
    Sleep 100
    Send "{Down}"
}

BC4_CopyToRightContinue() {
    Send "!{Right}"
    Sleep 100
    Send "{Down}"
}

BC4_Search() {
    Send "^f"
}

BC4_Home() {
    Send "^{Home}"
}

BC4_End() {
    Send "^{End}"
}

BC4_Save() {
    Send "^s"
}

BC4_Refresh() {
    Send "{F5}"
}

BC4_Compare() {
    Send "^c"
}
