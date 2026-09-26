#Requires AutoHotkey v2.0

; === WinMerge Plugin - 文件比较工具集成 ===
; 完整移植自 VimDesktop 的 WinMerge 插件
; 支持 insert/normal 模式系统

class WinMergePlugin extends RimPlugin {
    static Name => "WinMerge"
    static Title => "WinMerge"
    static Description => "WinMerge 比较窗口 Vim 映射"

    static RegisterKeymaps(engine) {
        WinMerge_Keymaps(engine)
    }
}

if (IsSet(RimPluginManager) && IsObject(RimPluginManager))
    RimPluginManager.Register(WinMergePlugin)

WinMerge_Keymaps(engine) {
    engine.SetWin("WinMerge", "WinMergeWindowClassU", "WinMergeU.exe")

    ; 注册动作
    engine.SetAction("<WM_NextDiff>", T("act.WinMerge.WM_NextDiff"))
    engine.SetAction("<WM_PrevDiff>", T("act.WinMerge.WM_PrevDiff"))
    engine.SetAction("<WM_FirstDiff>", T("act.WinMerge.WM_FirstDiff"))
    engine.SetAction("<WM_LastDiff>", T("act.WinMerge.WM_LastDiff"))
    engine.SetAction("<WM_CopyToLeft>", T("act.WinMerge.WM_CopyToLeft"))
    engine.SetAction("<WM_CopyToRight>", T("act.WinMerge.WM_CopyToRight"))
    engine.SetAction("<WM_CopyToLeftContinue>", T("act.WinMerge.WM_CopyToLeftContinue"))
    engine.SetAction("<WM_CopyToRightContinue>", T("act.WinMerge.WM_CopyToRightContinue"))
    engine.SetAction("<WM_CopyAllToLeft>", T("act.WinMerge.WM_CopyAllToLeft"))
    engine.SetAction("<WM_CopyAllToRight>", T("act.WinMerge.WM_CopyAllToRight"))
    engine.SetAction("<WM_Search>", T("act.WinMerge.WM_Search"))
    engine.SetAction("<WM_Home>", T("act.WinMerge.WM_Home"))
    engine.SetAction("<WM_End>", T("act.WinMerge.WM_End"))
    engine.SetAction("<WM_Save>", T("act.WinMerge.WM_Save"))
    engine.SetAction("<WM_Refresh>", T("act.WinMerge.WM_Refresh"))
    engine.SetAction("<WM_Undo>", T("act.WinMerge.WM_Undo"))
    engine.SetAction("<WM_Redo>", T("act.WinMerge.WM_Redo"))
    engine.SetAction("<WM_NextFile>", T("act.WinMerge.WM_NextFile"))
    engine.SetAction("<WM_PrevFile>", T("act.WinMerge.WM_PrevFile"))

    ; insert 模式映射
    engine.MapKey("<enter>", "<enter>", "WinMerge", "insert")
    engine.MapKey("<bs>", "<bs>", "WinMerge", "insert")
    engine.MapKey("<tab>", "<tab>", "WinMerge", "insert")
    engine.MapKey("<space>", "<space>", "WinMerge", "insert")
    engine.MapKey("<del>", "<del>", "WinMerge", "insert")

    ; normal 模式映射
    ; 导航
    engine.MapKey("j", "<WM_NextDiff>", "WinMerge", "normal")
    engine.MapKey("k", "<WM_PrevDiff>", "WinMerge", "normal")
    engine.MapKey("gg", "<WM_FirstDiff>", "WinMerge", "normal")
    engine.MapKey("G", "<WM_LastDiff>", "WinMerge", "normal")
    engine.MapKey("w", "<WM_Home>", "WinMerge", "normal")
    engine.MapKey("e", "<WM_End>", "WinMerge", "normal")

    ; 复制操作
    engine.MapKey("h", "<WM_CopyToLeft>", "WinMerge", "normal")
    engine.MapKey("l", "<WM_CopyToRight>", "WinMerge", "normal")
    engine.MapKey("H", "<WM_CopyToLeftContinue>", "WinMerge", "normal")
    engine.MapKey("L", "<WM_CopyToRightContinue>", "WinMerge", "normal")
    engine.MapKey("<C-h>", "<WM_CopyAllToLeft>", "WinMerge", "normal")
    engine.MapKey("<C-l>", "<WM_CopyAllToRight>", "WinMerge", "normal")

    ; 搜索
    engine.MapKey("/", "<WM_Search>", "WinMerge", "normal")

    ; 文件操作
    engine.MapKey("<c-s>", "<WM_Save>", "WinMerge", "normal")
    engine.MapKey("R", "<WM_Refresh>", "WinMerge", "normal")
    engine.MapKey("u", "<WM_Undo>", "WinMerge", "normal")
    engine.MapKey("U", "<WM_Redo>", "WinMerge", "normal")

    ; 文件切换
    engine.MapKey("n", "<WM_NextFile>", "WinMerge", "normal")
    engine.MapKey("p", "<WM_PrevFile>", "WinMerge", "normal")

    ; 模式切换
    engine.MapKey("i", "<Gen_InsertMode>", "WinMerge", "normal")
    engine.MapKey("<Esc>", "<Gen_NormalMode>", "WinMerge", "insert")
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
