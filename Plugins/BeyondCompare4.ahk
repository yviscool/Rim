#Requires AutoHotkey v2.0

; === BeyondCompare4 Plugin ===
; 完整移植自 VimDesktop 的 BeyondCompare4 插件
; 支持 insert/normal 模式系统

class BeyondCompare4Plugin extends RimPlugin {
    static Name => "BeyondCompare4"
    static Title => "Beyond Compare 4"
    static Description => "BC4 比较窗口 Vim 映射"

    static RegisterKeymaps(engine) {
        BeyondCompare4_Keymaps(engine)
    }
}

if (IsSet(RimPluginManager) && IsObject(RimPluginManager))
    RimPluginManager.Register(BeyondCompare4Plugin)

BeyondCompare4_Keymaps(engine) {
    engine.SetWin("BeyondCompare4", "TConvertForm", "BCompare.exe")

    ; 注册动作
    engine.SetAction("<BC4_NextDiff>", T("act.BeyondCompare4.BC4_NextDiff"))
    engine.SetAction("<BC4_PrevDiff>", T("act.BeyondCompare4.BC4_PrevDiff"))
    engine.SetAction("<BC4_NextDiffLine>", T("act.BeyondCompare4.BC4_NextDiffLine"))
    engine.SetAction("<BC4_PrevDiffLine>", T("act.BeyondCompare4.BC4_PrevDiffLine"))
    engine.SetAction("<BC4_CopyToLeft>", T("act.BeyondCompare4.BC4_CopyToLeft"))
    engine.SetAction("<BC4_CopyToRight>", T("act.BeyondCompare4.BC4_CopyToRight"))
    engine.SetAction("<BC4_CopyToLeftContinue>", T("act.BeyondCompare4.BC4_CopyToLeftContinue"))
    engine.SetAction("<BC4_CopyToRightContinue>", T("act.BeyondCompare4.BC4_CopyToRightContinue"))
    engine.SetAction("<BC4_Search>", T("act.BeyondCompare4.BC4_Search"))
    engine.SetAction("<BC4_Home>", T("act.BeyondCompare4.BC4_Home"))
    engine.SetAction("<BC4_End>", T("act.BeyondCompare4.BC4_End"))
    engine.SetAction("<BC4_Save>", T("act.BeyondCompare4.BC4_Save"))
    engine.SetAction("<BC4_Refresh>", T("act.BeyondCompare4.BC4_Refresh"))
    engine.SetAction("<BC4_Compare>", T("act.BeyondCompare4.BC4_Compare"))
    engine.SetAction("<BC4_NextSection>", T("act.BeyondCompare4.BC4_NextSection"))
    engine.SetAction("<BC4_PrevSection>", T("act.BeyondCompare4.BC4_PrevSection"))

    ; insert 模式映射
    engine.MapKey("<enter>", "<enter>", "BeyondCompare4", "insert")
    engine.MapKey("<bs>", "<bs>", "BeyondCompare4", "insert")
    engine.MapKey("<tab>", "<tab>", "BeyondCompare4", "insert")
    engine.MapKey("<space>", "<space>", "BeyondCompare4", "insert")
    engine.MapKey("<del>", "<del>", "BeyondCompare4", "insert")

    ; normal 模式映射
    ; 导航
    engine.MapKey("j", "<BC4_NextDiff>", "BeyondCompare4", "normal")
    engine.MapKey("k", "<BC4_PrevDiff>", "BeyondCompare4", "normal")
    engine.MapKey("J", "<BC4_NextDiffLine>", "BeyondCompare4", "normal")
    engine.MapKey("K", "<BC4_PrevDiffLine>", "BeyondCompare4", "normal")
    engine.MapKey("n", "<BC4_NextSection>", "BeyondCompare4", "normal")
    engine.MapKey("p", "<BC4_PrevSection>", "BeyondCompare4", "normal")
    engine.MapKey("gg", "<BC4_Home>", "BeyondCompare4", "normal")
    engine.MapKey("G", "<BC4_End>", "BeyondCompare4", "normal")

    ; 复制操作
    engine.MapKey("h", "<BC4_CopyToLeft>", "BeyondCompare4", "normal")
    engine.MapKey("l", "<BC4_CopyToRight>", "BeyondCompare4", "normal")
    engine.MapKey("H", "<BC4_CopyToLeftContinue>", "BeyondCompare4", "normal")
    engine.MapKey("L", "<BC4_CopyToRightContinue>", "BeyondCompare4", "normal")

    ; 搜索
    engine.MapKey("/", "<BC4_Search>", "BeyondCompare4", "normal")

    ; 文件操作
    engine.MapKey("<c-s>", "<BC4_Save>", "BeyondCompare4", "normal")
    engine.MapKey("R", "<BC4_Refresh>", "BeyondCompare4", "normal")
    engine.MapKey("C", "<BC4_Compare>", "BeyondCompare4", "normal")

    ; 模式切换
    engine.MapKey("i", "<Gen_InsertMode>", "BeyondCompare4", "normal")
    engine.MapKey("<Esc>", "<Gen_NormalMode>", "BeyondCompare4", "insert")
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
