#Requires AutoHotkey v2.0
#Warn All, Off

; === Everything Plugin - 文件搜索 Vim 模式 ===
; voidtools Everything (结果列表导航): j/k 上下, gg/G 首尾, Enter 原生打开,
; i// 聚焦搜索框并进 insert, Esc 回 normal (+透传 Esc, 原生清搜索).
; 安全: 搜索框/重命名框 (Edit 系控件) 聚焦时全透传, 但切回 normal 的动作必须执行
;   (否则困在 insert); 打字天然直达搜索, normal 下未映射字母透传即快搜, 不吞键.
; 窗口: EVERYTHING / Everything.exe.

class EverythingPlugin extends RimPlugin {
    static Name => "Everything"
    static Title => "Everything Vim Mode"
    static Author => "Rim"
    static Description => "Everything 搜索结果 Vim 导航"
    static Version => "1.0.0"
    static ApiVersion => "1"
    static Capabilities => ["keymaps"]

    static RegisterKeymaps(engine) {
        Everything_Keymaps(engine)
    }
}

if (IsSet(RimPluginManager) && IsObject(RimPluginManager))
    RimPluginManager.Register(EverythingPlugin)

Everything_Keymaps(engine) {
    engine.SetWin("Everything", "EVERYTHING", "Everything.exe")
    try engine.GetWin("Everything").SetTimeOut(800)
    try engine.GetWin("Everything").ShowInfo := false
    engine.SetBeforeActionDoForWin("Everything", Ev_Before)

    engine.SetAction("<Ev_Down>", T("act.Everything.Ev_Down"))
    engine.SetAction("<Ev_Up>", T("act.Everything.Ev_Up"))
    engine.SetAction("<Ev_Top>", T("act.Everything.Ev_Top"))
    engine.SetAction("<Ev_Bottom>", T("act.Everything.Ev_Bottom"))
    engine.SetAction("<Ev_SearchFocus>", T("act.Everything.Ev_SearchFocus"))
    engine.SetAction("<Ev_NormalMode>", T("act.Everything.Ev_NormalMode"))
    engine.SetAction("<Ev_Help>", T("act.Everything.Ev_Help"))

    wn := "Everything"
    m := "normal"
    engine.MapKey("j", "<Ev_Down>", wn, m)
    engine.MapKey("k", "<Ev_Up>", wn, m)
    engine.MapKey("gg", "<Ev_Top>", wn, m)
    engine.MapKey("G", "<Ev_Bottom>", wn, m)
    engine.MapKey("0", "<Ev_Top>", wn, m)
    engine.MapKey("i", "<Ev_SearchFocus>", wn, m)
    engine.MapKey("/", "<Ev_SearchFocus>", wn, m)
    engine.MapKey("<Esc>", "<Ev_NormalMode>", wn, m)
    engine.MapKey("<C-[>", "<Ev_NormalMode>", wn, m)
    engine.MapKey("?", "<Ev_Help>", wn, m)
    for _, digit in ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
        engine.MapKey(digit, "<Pass>", wn, m)
    ; insert 模式: 只留出口 (搜索框聚焦时由 Ev_Before 透传, 畅打无阻)
    engine.MapKey("<Esc>", "<Ev_NormalMode>", wn, "insert")
    engine.MapKey("<C-[>", "<Ev_NormalMode>", wn, "insert")
}

; 搜索框/重命名框 (Edit 系) 聚焦时透传, 但切回 normal 必须执行
Ev_Before(actionName, evWin) {
    if (actionName = "<Ev_NormalMode>")
        return false
    try {
        if WinExist("ahk_class #32768") || WinExist("ahk_class Xaml_WindowedPopupClass")
            return true
    }
    try {
        if InStr(FocusedClassNN("A"), "Edit")
            return true
    }
    return false
}

Ev_SetMode(modeName) {
    try {
        global g_VimEngine
        if IsObject(g_VimEngine) {
            hitName := g_VimEngine.CheckWin()
            if (hitName != "" && hitName != "__global__") {
                hitWin := g_VimEngine.GetWin(hitName)
                if IsObject(hitWin)
                    hitWin.currentMode := modeName
            }
        }
    }
}

Ev_Down() {
    Send("{Down}")
}

Ev_Up() {
    Send("{Up}")
}

Ev_Top() {
    Send("{Home}")
}

Ev_Bottom() {
    Send("{End}")
}

Ev_SearchFocus() {
    focused := false
    try {
        ControlFocus("Edit1", "A")
        focused := true
    }
    if (!focused) {
        try Send("+{Tab}")
        catch {
        }
    }
    Ev_SetMode("insert")
    ToolTip(T("ved.mode_insert"))
    SetTimer(() => ToolTip(), -600)
}

Ev_NormalMode() {
    Ev_SetMode("normal")
    Send("{Escape}")
    ToolTip(T("ved.mode_normal"))
    SetTimer(() => ToolTip(), -600)
}

Ev_Help() {
    ToolTip("j/k 上下  gg/G 首尾  Enter 打开`n"
        . "i// 搜框  Esc 普通  Win+W 总开关")
    SetTimer(() => ToolTip(), -4000)
}
