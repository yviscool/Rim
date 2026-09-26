#Requires AutoHotkey v2.0

; === TCCompare Plugin - TC内置文件比较工具 ===
; 完整移植自 VimDesktop 的 TCCompare 插件
; 支持 insert/normal 模式系统

class TCComparePlugin extends RimPlugin {
    static Name => "TCCompare"
    static Title => "TC Compare"
    static Description => "Total Commander 文件比较窗口 Vim 映射"

    static RegisterKeymaps(engine) {
        TCCompare_Keymaps(engine)
    }
}

if (IsSet(RimPluginManager) && IsObject(RimPluginManager))
    RimPluginManager.Register(TCComparePlugin)

TCCompare_Keymaps(engine) {
    engine.SetWin("TCCompare", "TConvertForm", "TOTALCMD.EXE")

    ; 注册动作
    engine.SetAction("<TCC_Edit>", T("act.TCCompare.TCC_Edit"))
    engine.SetAction("<TCC_Recompare>", T("act.TCCompare.TCC_Recompare"))
    engine.SetAction("<TCC_ToggleBinary>", T("act.TCCompare.TCC_ToggleBinary"))
    engine.SetAction("<TCC_ToggleEncoding>", T("act.TCCompare.TCC_ToggleEncoding"))
    engine.SetAction("<TCC_NextDiff>", T("act.TCCompare.TCC_NextDiff"))
    engine.SetAction("<TCC_PrevDiff>", T("act.TCCompare.TCC_PrevDiff"))
    engine.SetAction("<TCC_Home>", T("act.TCCompare.TCC_Home"))
    engine.SetAction("<TCC_End>", T("act.TCCompare.TCC_End"))
    engine.SetAction("<TCC_Search>", T("act.TCCompare.TCC_Search"))
    engine.SetAction("<TCC_CopyToLeft>", T("act.TCCompare.TCC_CopyToLeft"))
    engine.SetAction("<TCC_CopyToRight>", T("act.TCCompare.TCC_CopyToRight"))
    engine.SetAction("<TCC_Save>", T("act.TCCompare.TCC_Save"))
    engine.SetAction("<TCC_Refresh>", T("act.TCCompare.TCC_Refresh"))
    engine.SetAction("<TCC_Compare>", T("act.TCCompare.TCC_Compare"))
    engine.SetAction("<TCC_BinaryMode>", T("act.TCCompare.TCC_BinaryMode"))
    engine.SetAction("<TCC_ChangeCodepage>", T("act.TCCompare.TCC_ChangeCodepage"))

    ; insert 模式映射
    engine.MapKey("<enter>", "<enter>", "TCCompare", "insert")
    engine.MapKey("<bs>", "<bs>", "TCCompare", "insert")
    engine.MapKey("<tab>", "<tab>", "TCCompare", "insert")
    engine.MapKey("<space>", "<space>", "TCCompare", "insert")
    engine.MapKey("<del>", "<del>", "TCCompare", "insert")

    ; normal 模式映射
    ; 编辑操作
    engine.MapKey("m", "<TCC_Edit>", "TCCompare", "normal")
    engine.MapKey("c", "<TCC_Recompare>", "TCCompare", "normal")
    engine.MapKey("C", "<TCC_Compare>", "TCCompare", "normal")
    engine.MapKey("s", "<TCC_Save>", "TCCompare", "normal")

    ; 比较模式
    engine.MapKey("b", "<TCC_ToggleBinary>", "TCCompare", "normal")
    engine.MapKey("B", "<TCC_BinaryMode>", "TCCompare", "normal")
    engine.MapKey("-", "<TCC_ToggleEncoding>", "TCCompare", "normal")
    engine.MapKey("+", "<TCC_ChangeCodepage>", "TCCompare", "normal")

    ; 导航
    engine.MapKey("j", "<TCC_NextDiff>", "TCCompare", "normal")
    engine.MapKey("k", "<TCC_PrevDiff>", "TCCompare", "normal")
    engine.MapKey("gg", "<TCC_Home>", "TCCompare", "normal")
    engine.MapKey("G", "<TCC_End>", "TCCompare", "normal")
    engine.MapKey("/", "<TCC_Search>", "TCCompare", "normal")

    ; 复制操作
    engine.MapKey("<", "<TCC_CopyToLeft>", "TCCompare", "normal")
    engine.MapKey(">", "<TCC_CopyToRight>", "TCCompare", "normal")

    ; 刷新
    engine.MapKey("R", "<TCC_Refresh>", "TCCompare", "normal")

    ; 模式切换
    engine.MapKey("i", "<Gen_InsertMode>", "TCCompare", "normal")
    engine.MapKey("<Esc>", "<Gen_NormalMode>", "TCCompare", "insert")
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
        ibox := InputBox(T("tcc.codepage_prompt"), T("tcc.codepage_title"))
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
