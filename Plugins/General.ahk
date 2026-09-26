#Requires AutoHotkey v2.0

; === General Plugin - 通用Vim键位 ===
; 为所有窗口提供基础Vim操作

class GeneralPlugin extends RimPlugin {
    static Name => "General"
    static Title => "General Vim Fallback"
    static Description => "通用兜底窗口 Vim 映射"

    static RegisterKeymaps(engine) {
        General_Keymaps(engine)
    }

    static RegisterCommands() {
        RimCommand.Register("VimDiag", "VimDiag", MakeLegacyCmd("VimDiagCmd"), Map("Category", "Tool", "Description", T("cmd.General.VimDiag"), "Keywords", "VimDiag"))
    }
}

if (IsSet(RimPluginManager) && IsObject(RimPluginManager))
    RimPluginManager.Register(GeneralPlugin)

General_Keymaps(engine) {
    ; 注册窗口
    engine.SetWin("General", "", "")

    ; 注册动作
    engine.SetAction("<Gen_Toggle>", T("act.General.Gen_Toggle"))
    engine.SetAction("<Gen_InsertMode>", T("act.General.Gen_InsertMode"))
    engine.SetAction("<Gen_NormalMode>", T("act.General.Gen_NormalMode"))
    engine.SetAction("<down>", T("act.General.down"))
    engine.SetAction("<up>", T("act.General.up"))
    engine.SetAction("<left>", T("act.General.left"))
    engine.SetAction("<right>", T("act.General.right"))
    engine.SetAction("<enter>", T("act.General.enter"))
    engine.SetAction("<bs>", T("act.General.bs"))
    engine.SetAction("<tab>", T("act.General.tab"))
    engine.SetAction("<space>", T("act.General.space"))
    engine.SetAction("<home>", T("act.General.home"))
    engine.SetAction("<end>", T("act.General.end"))
    engine.SetAction("<pgup>", T("act.General.pgup"))
    engine.SetAction("<pgdn>", T("act.General.pgdn"))
    engine.SetAction("<del>", T("act.General.del"))
    engine.SetAction("<c-a>", T("act.General.c_a"))
    engine.SetAction("<c-c>", T("act.General.c_c"))
    engine.SetAction("<c-v>", T("act.General.c_v"))
    engine.SetAction("<c-x>", T("act.General.c_x"))
    engine.SetAction("<c-z>", T("act.General.c_z"))
    engine.SetAction("<c-y>", T("act.General.c_y"))
    engine.SetAction("<c-s>", T("act.General.c_s"))
    engine.SetAction("<c-f>", T("act.General.c_f"))
    engine.SetAction("<c-h>", T("act.General.c_h"))
    engine.SetAction("<c-w>", T("act.General.c_w"))

    ; 窗口管理动作
    engine.SetAction("<wm_left>", T("act.General.wm_left"))
    engine.SetAction("<wm_right>", T("act.General.wm_right"))
    engine.SetAction("<wm_up>", T("act.General.wm_up"))
    engine.SetAction("<wm_down>", T("act.General.wm_down"))
    engine.SetAction("<wm_max>", T("act.General.wm_max"))
    engine.SetAction("<wm_min>", T("act.General.wm_min"))
    engine.SetAction("<wm_restore>", T("act.General.wm_restore"))
    engine.SetAction("<wm_center>", T("act.General.wm_center"))
    engine.SetAction("<wm_full>", T("act.General.wm_full"))

    ; 标签页管理
    engine.SetAction("<Gen_NewTab>", T("act.General.Gen_NewTab"))
    engine.SetAction("<Gen_CloseTab>", T("act.General.Gen_CloseTab"))
    engine.SetAction("<Gen_NextTab>", T("act.General.Gen_NextTab"))
    engine.SetAction("<Gen_PrevTab>", T("act.General.Gen_PrevTab"))
    engine.SetAction("<Gen_Tab1>", T("act.General.Gen_Tab1"))
    engine.SetAction("<Gen_Tab2>", T("act.General.Gen_Tab2"))
    engine.SetAction("<Gen_Tab3>", T("act.General.Gen_Tab3"))
    engine.SetAction("<Gen_Tab4>", T("act.General.Gen_Tab4"))
    engine.SetAction("<Gen_Tab5>", T("act.General.Gen_Tab5"))
    engine.SetAction("<Gen_Tab6>", T("act.General.Gen_Tab6"))
    engine.SetAction("<Gen_Tab7>", T("act.General.Gen_Tab7"))
    engine.SetAction("<Gen_Tab8>", T("act.General.Gen_Tab8"))
    engine.SetAction("<Gen_Tab9>", T("act.General.Gen_Tab9"))
    engine.SetAction("<Gen_Tab0>", T("act.General.Gen_Tab0"))

    ; 鼠标操作
    engine.SetAction("<MouseUp>", T("act.General.MouseUp"))
    engine.SetAction("<MouseDown>", T("act.General.MouseDown"))
    engine.SetAction("<MouseLeft>", T("act.General.MouseLeft"))
    engine.SetAction("<MouseRight>", T("act.General.MouseRight"))
    engine.SetAction("<MouseClick>", T("act.General.MouseClick"))
    engine.SetAction("<MouseRightClick>", T("act.General.MouseRightClick"))
    engine.SetAction("<MouseDoubleClick>", T("act.General.MouseDoubleClick"))

    ; IME 切换
    engine.SetAction("<Gen_SwitchIME>", T("act.General.Gen_SwitchIME"))
    engine.SetAction("<Gen_EnglishIME>", T("act.General.Gen_EnglishIME"))

    ; 诊断命令已迁 RegisterCommands 直注 (VimDiag)

    ; 媒体动作
    engine.SetAction("<media_next>", T("act.General.media_next"))
    engine.SetAction("<media_prev>", T("act.General.media_prev"))
    engine.SetAction("<media_play>", T("act.General.media_play"))
    engine.SetAction("<media_stop>", T("act.General.media_stop"))

    ; 编辑器通用动作 (记事本类 ini 引用, 按键直达编辑器)
    engine.SetAction("<word>", T("act.General.word"))
    engine.SetAction("<wordb>", T("act.General.wordb"))
    engine.SetAction("<wordend>", T("act.General.wordend"))
    engine.SetAction("<deletedLine>", T("act.General.deletedLine"))
    engine.SetAction("<copyLine>", T("act.General.copyLine"))
    engine.SetAction("<paste>", T("act.General.c_v"))
    engine.SetAction("<undo>", T("act.General.c_z"))
    engine.SetAction("<redo>", T("act.General.c_y"))
    engine.SetAction("<deletechar>", T("act.General.deletechar"))
    engine.SetAction("<insertBefore>", T("act.General.insertBefore"))
    engine.SetAction("<insertAfter>", T("act.General.insertAfter"))
    engine.SetAction("<insertNewLine>", T("act.General.insertNewLine"))
    engine.SetAction("<insertLineStart>", T("act.General.insertLineStart"))
    engine.SetAction("<insertLineEnd>", T("act.General.insertLineEnd"))
    engine.SetAction("<insertLineAbove>", T("act.General.insertLineAbove"))
    engine.SetAction("<visualMode>", T("act.General.visualMode"))
    engine.SetAction("<search>", T("act.General.c_f"))
    engine.SetAction("<nextMatch>", T("act.General.nextMatch"))
    engine.SetAction("<prevMatch>", T("act.General.prevMatch"))

    ; 窗口控制
    engine.SetAction("<Gen_AlwaysOnTop>", T("act.General.Gen_AlwaysOnTop"))
    engine.SetAction("<Gen_CancelAlwaysOnTop>", T("act.General.Gen_CancelAlwaysOnTop"))
    engine.SetAction("<Gen_ToggleTitleBar>", T("act.General.Gen_ToggleTitleBar"))
    engine.SetAction("<Gen_Suspend>", T("act.General.Gen_Suspend"))
    engine.SetAction("<Reload>", T("act.General.Reload"))
    engine.SetAction("<Gen_ShowHelp>", T("act.General.Gen_ShowHelp"))
    engine.SetAction("<Gen_SearchInWeb>", T("act.General.Gen_SearchInWeb"))

    ; 设置 normal 模式映射
    engine.MapKey("j", "<down>", "General", "normal")
    engine.MapKey("k", "<up>", "General", "normal")
    engine.MapKey("h", "<left>", "General", "normal")
    engine.MapKey("l", "<right>", "General", "normal")
    engine.MapKey("i", "<Gen_InsertMode>", "General", "normal")
    engine.MapKey("<Esc>", "<Gen_NormalMode>", "General", "insert")

    ; 标签页管理
    engine.MapKey("t", "<Gen_NewTab>", "General", "normal")
    engine.MapKey("x", "<Gen_CloseTab>", "General", "normal")
    engine.MapKey("gn", "<Gen_NextTab>", "General", "normal")
    engine.MapKey("gp", "<Gen_PrevTab>", "General", "normal")
    engine.MapKey("g1", "<Gen_Tab1>", "General", "normal")
    engine.MapKey("g2", "<Gen_Tab2>", "General", "normal")
    engine.MapKey("g3", "<Gen_Tab3>", "General", "normal")
    engine.MapKey("g4", "<Gen_Tab4>", "General", "normal")
    engine.MapKey("g5", "<Gen_Tab5>", "General", "normal")
    engine.MapKey("g6", "<Gen_Tab6>", "General", "normal")
    engine.MapKey("g7", "<Gen_Tab7>", "General", "normal")
    engine.MapKey("g8", "<Gen_Tab8>", "General", "normal")
    engine.MapKey("g9", "<Gen_Tab9>", "General", "normal")
    engine.MapKey("g0", "<Gen_Tab0>", "General", "normal")

    ; 窗口管理
    engine.MapKey("zj", "<wm_down>", "General", "normal")
    engine.MapKey("zk", "<wm_up>", "General", "normal")
    engine.MapKey("zh", "<wm_left>", "General", "normal")
    engine.MapKey("zl", "<wm_right>", "General", "normal")
    engine.MapKey("zc", "<wm_center>", "General", "normal")
    engine.MapKey("zf", "<wm_full>", "General", "normal")
    engine.MapKey("zm", "<wm_max>", "General", "normal")
    engine.MapKey("zn", "<wm_min>", "General", "normal")
    engine.MapKey("zr", "<wm_restore>", "General", "normal")

    ; 鼠标操作 (默认不绑: General 窗无类名限制, 绑了就是全局钩子,
    ;  会吃掉浏览器/IDE 的 Ctrl+H/J/K/L; 原版亦只注册动作不绑键, 需用自行在 ini 里绑)
    ;   例: 在 [Notepad] 等窗口段加 <c-h>=<MouseLeft> 等, 或全局段按需绑定
    ;   MapKey("<c-j>", "<MouseDown>", "General", "normal")
    ;   MapKey("<c-k>", "<MouseUp>", "General", "normal")
    ;   MapKey("<c-h>", "<MouseLeft>", "General", "normal")
    ;   MapKey("<c-l>", "<MouseRight>", "General", "normal")

    ; 窗口控制
    engine.MapKey("za", "<Gen_AlwaysOnTop>", "General", "normal")
    engine.MapKey("zA", "<Gen_CancelAlwaysOnTop>", "General", "normal")
    engine.MapKey("zt", "<Gen_ToggleTitleBar>", "General", "normal")
    engine.MapKey("zs", "<Gen_Suspend>", "General", "normal")

    ; 系统操作
    engine.MapKey("<F5>", "<Reload>", "General", "normal")
    engine.MapKey("z/", "<Gen_ShowHelp>", "General", "normal")
    engine.MapKey("zw", "<Gen_SearchInWeb>", "General", "normal")

    ; 数字键传递 (同 TC 插件: 无对应函数, 直接透传, Count 逻辑在引擎层)
    engine.MapKey("0", "<Pass>", "General", "normal")
    engine.MapKey("1", "<Pass>", "General", "normal")
    engine.MapKey("2", "<Pass>", "General", "normal")
    engine.MapKey("3", "<Pass>", "General", "normal")
    engine.MapKey("4", "<Pass>", "General", "normal")
    engine.MapKey("5", "<Pass>", "General", "normal")
    engine.MapKey("6", "<Pass>", "General", "normal")
    engine.MapKey("7", "<Pass>", "General", "normal")
    engine.MapKey("8", "<Pass>", "General", "normal")
    engine.MapKey("9", "<Pass>", "General", "normal")

    ; IME 切换
    engine.MapKey("<c-\>", "<Gen_SwitchIME>", "General", "normal")
}

; === 基础动作函数 (模式切换作用于当前窗口, 非 __global__) ===
VimDiagCmd() {
    global g_VimEngine
    if IsObject(g_VimEngine)
        g_VimEngine.VimDiag()
}

CurVimWin() {
    global g_VimEngine
    if !IsObject(g_VimEngine)
        return ""
    try {
        name := g_VimEngine.CheckWin()
        w := g_VimEngine.GetWin(name)
        if IsObject(w)
            return w
    }
    return g_VimEngine.winGlobal
}

Gen_Toggle() {
    ; 切换模式：normal ↔ insert
    win := CurVimWin()
    if !IsObject(win)
        return

    if (win.currentMode = "normal") {
        win.currentMode := "insert"
        Log("Mode: insert")
    } else {
        win.currentMode := "normal"
        Log("Mode: normal")
    }
}

Gen_InsertMode() {
    ; 进入插入模式
    win := CurVimWin()
    if !IsObject(win)
        return

    win.currentMode := "insert"
    Log("Mode: insert")
}

Gen_NormalMode() {
    ; 返回正常模式
    win := CurVimWin()
    if !IsObject(win)
        return

    win.currentMode := "normal"
    Log("Mode: normal")
}

; === 编辑器通用动作 (按键直达, 适配记事本类) ===
word() {
    Send("^{Right}")
}

wordb() {
    Send("^{Left}")
}

wordend() {
    Send("^{Right}{Left}")
}

deletedLine() {
    Send("{Home}+{End}{Del}")
}

copyLine() {
    Send("{Home}+{End}^c")
}

paste() {
    Send("^v")
}

undo() {
    Send("^z")
}

redo() {
    Send("^y")
}

deletechar() {
    Send("{Del}")
}

insertBefore() {
    Gen_InsertMode()
}

insertAfter() {
    Send("{Right}")
    Gen_InsertMode()
}

insertNewLine() {
    Send("{End}{Enter}")
    Gen_InsertMode()
}

insertLineStart() {
    Send("{Home}")
    Gen_InsertMode()
}

insertLineEnd() {
    Send("{End}")
    Gen_InsertMode()
}

insertLineAbove() {
    Send("{Home}{Enter}{Up}")
    Gen_InsertMode()
}

visualMode() {
    Send("+{Right}")
}

search() {
    Send("^f")
}

nextMatch() {
    Send("{F3}")
}

prevMatch() {
    Send("+{F3}")
}

down() {
    Send "{Down}"
}

up() {
    Send "{Up}"
}

left() {
    Send "{Left}"
}

right() {
    Send "{Right}"
}

enter() {
    Send "{Enter}"
}

bs() {
    Send "{Backspace}"
}

tab() {
    Send "{Tab}"
}

space() {
    Send "{Space}"
}

home() {
    Send "{Home}"
}

end() {
    Send "{End}"
}

pgup() {
    Send "{PgUp}"
}

pgdn() {
    Send "{PgDn}"
}

del() {
    Send "{Del}"
}

; === 编辑操作 ===
c_a() {
    Send "^a"
}

c_c() {
    Send "^c"
}

c_v() {
    Send "^v"
}

c_x() {
    Send "^x"
}

c_z() {
    Send "^z"
}

c_y() {
    Send "^y"
}

c_s() {
    Send "^s"
}

c_f() {
    Send "^f"
}

c_h() {
    Send "^h"
}

c_w() {
    Send "^w"
}

; === 窗口管理函数 ===
wm_left() {
    spec := wm_Win()
    WinGetPos(&x, &y, &w, &h, spec)
    WinMove(x - 50, , , , spec)
}

wm_right() {
    spec := wm_Win()
    WinGetPos(&x, &y, &w, &h, spec)
    WinMove(x + 50, , , , spec)
}

wm_up() {
    spec := wm_Win()
    WinGetPos(&x, &y, &w, &h, spec)
    WinMove(, y - 50, , , spec)
}

wm_down() {
    spec := wm_Win()
    WinGetPos(&x, &y, &w, &h, spec)
    WinMove(, y + 50, , , spec)
}

; 手势目标窗口: 手势起点窗口有效即起点 (StrokesPlus gsx/gsy 对等),
; 键盘等其他入口无起点时回退 "A". 经 Gesture_ActionWin 统一.
wm_Win() {
    try {
        if (IsSet(GestureHook) && HasMethod(GestureHook, "ActionWin"))
            return GestureHook.ActionWin()
    }
    return "A"
}

wm_max() {
    spec := wm_Win()
    try {
        ; StrokesPlus acMaximizeOrRestoreWindow 对等:
        ; 已最大化时恢复, 普通/最小化时最大化. 每次按起点窗口判断,
        ; 不使用 static 状态, 避免多窗口之间互相串状态.
        if (WinGetMinMax(spec) = 1)
            WinRestore(spec)
        else
            WinMaximize(spec)
    } catch {
        try WinMaximize(spec)
        catch {
        }
    }
}

wm_min() {
    WinMinimize wm_Win()
}

wm_restore() {
    WinRestore wm_Win()
}

wm_center() {
    spec := wm_Win()
    WinGetPos(, , &w, &h, spec)
    x := (A_ScreenWidth - w) // 2
    y := (A_ScreenHeight - h) // 2
    WinMove(x, y, , , spec)
}

wm_full() {
    static isFull := false
    spec := wm_Win()
    if !isFull {
        WinGetPos(&x, &y, &w, &h, spec)
        WinMove(0, 0, A_ScreenWidth, A_ScreenHeight, spec)
        isFull := true
    } else {
        WinRestore spec
        isFull := false
    }
}

; === 媒体控制 ===
media_next() {
    Send "{Media_Next}"
}

media_prev() {
    Send "{Media_Prev}"
}

media_play() {
    Send "{Media_Play_Pause}"
}

media_stop() {
    Send "{Media_Stop}"
}

; === 标签页管理 ===
Gen_NewTab() {
    Send "^t"
}

Gen_CloseTab() {
    Send "^w"
}

Gen_NextTab() {
    Send "^{Tab}"
}

Gen_PrevTab() {
    Send "^+{Tab}"
}

Gen_Tab1() {
    Send "^1"
}

Gen_Tab2() {
    Send "^2"
}

Gen_Tab3() {
    Send "^3"
}

Gen_Tab4() {
    Send "^4"
}

Gen_Tab5() {
    Send "^5"
}

Gen_Tab6() {
    Send "^6"
}

Gen_Tab7() {
    Send "^7"
}

Gen_Tab8() {
    Send "^8"
}

Gen_Tab9() {
    Send "^9"
}

Gen_Tab0() {
    Send "^0"
}

; === 鼠标操作 ===
MouseUp() {
    MouseMove(0, -50, 0, "R")
}

MouseDown() {
    MouseMove(0, 50, 0, "R")
}

MouseLeft() {
    MouseMove(-50, 0, 0, "R")
}

MouseRight() {
    MouseMove(50, 0, 0, "R")
}

MouseClick() {
    Click
}

MouseRightClick() {
    Click "Right"
}

MouseDoubleClick() {
    Click "2"
}

; === IME 切换 ===
Gen_SwitchIME() {
    ; 切换输入法
    Send "^{Space}"
}

Gen_EnglishIME() {
    ; 切换到英文输入法
    ; 使用 Windows API
    try {
        hwnd := WinActive("A")
        ; 发送语言切换消息
        PostMessage 0x0050, 0, 0x04090409, , "ahk_id " hwnd  ; 英文 US
    }
}

; 对原版 <SwitchToEngIMEAndEsc> (custom ini <esc> 用): 先 Esc 再连切英文
SwitchToEngIMEAndEsc(*) {
    Send("{Esc}")
    SwitchToEngIME()
}

; === 窗口控制 ===
Gen_AlwaysOnTop() {
    WinSetAlwaysOnTop(1, "A")
}

Gen_CancelAlwaysOnTop() {
    WinSetAlwaysOnTop(0, "A")
}

Gen_ToggleTitleBar() {
    static hasBorder := true
    WinGetPos(, , &w, &h, "A")
    if hasBorder {
        WinMove(, , w, h + 30, "A")
        hasBorder := false
    } else {
        WinMove(, , w, h - 30, "A")
        hasBorder := true
    }
}

Gen_Suspend() {
    if ShowConfirm(T("gen.confirm_suspend"), T("gen.suspend_title")) {
        DllCall("PowrProf\SetSuspendState", "int", 0, "int", 0, "int", 0)
    }
}

; === 系统操作 ===
Reload() {
    ; 重新加载脚本
    Reload()
}

Gen_ShowHelp() {
    ; 显示帮助信息 (双语文本见 Lang/*.ini help.general)
    helpText := T("help.general")

    ToolTip(helpText)
    SetTimer () => ToolTip(), -5000
}

Gen_SearchInWeb() {
    ; 网络搜索剪贴板内容
    A_Clipboard := Trim(A_Clipboard)
    if (A_Clipboard = "") {
        ToolTip(T("gen.search_empty"))
        SetTimer () => ToolTip(), -2000
        return
    }

    ; 使用默认浏览器搜索
    searchUrl := "https://www.google.com/search?q=" UriEncode(A_Clipboard)
    Run(searchUrl)
    Log("Gen: Searched in web: " A_Clipboard)
}
