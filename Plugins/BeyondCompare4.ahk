#Requires AutoHotkey v2.0

; === BeyondCompare4 Plugin ===
; 完整移植自 VimDesktop 的 BeyondCompare4 插件
; 支持 insert/normal 模式系统

RegisterPlugin_BeyondCompare4() {
    RegisterWin("BeyondCompare4", "TConvertForm", "BCompare.exe")

    ; 注册动作
    RegisterAction("<BC4_NextDiff>", T("act.BeyondCompare4.BC4_NextDiff"))
    RegisterAction("<BC4_PrevDiff>", T("act.BeyondCompare4.BC4_PrevDiff"))
    RegisterAction("<BC4_NextDiffLine>", T("act.BeyondCompare4.BC4_NextDiffLine"))
    RegisterAction("<BC4_PrevDiffLine>", T("act.BeyondCompare4.BC4_PrevDiffLine"))
    RegisterAction("<BC4_CopyToLeft>", T("act.BeyondCompare4.BC4_CopyToLeft"))
    RegisterAction("<BC4_CopyToRight>", T("act.BeyondCompare4.BC4_CopyToRight"))
    RegisterAction("<BC4_CopyToLeftContinue>", T("act.BeyondCompare4.BC4_CopyToLeftContinue"))
    RegisterAction("<BC4_CopyToRightContinue>", T("act.BeyondCompare4.BC4_CopyToRightContinue"))
    RegisterAction("<BC4_Search>", T("act.BeyondCompare4.BC4_Search"))
    RegisterAction("<BC4_Home>", T("act.BeyondCompare4.BC4_Home"))
    RegisterAction("<BC4_End>", T("act.BeyondCompare4.BC4_End"))
    RegisterAction("<BC4_Save>", T("act.BeyondCompare4.BC4_Save"))
    RegisterAction("<BC4_Refresh>", T("act.BeyondCompare4.BC4_Refresh"))
    RegisterAction("<BC4_Compare>", T("act.BeyondCompare4.BC4_Compare"))
    RegisterAction("<BC4_NextSection>", T("act.BeyondCompare4.BC4_NextSection"))
    RegisterAction("<BC4_PrevSection>", T("act.BeyondCompare4.BC4_PrevSection"))

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
