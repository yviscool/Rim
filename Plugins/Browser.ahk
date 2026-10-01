#Requires AutoHotkey v2.0
#Warn All, Off

; === Browser Plugin - 浏览器 Vim 模式 (Chrome / Edge / Firefox) ===
; 对标 VimDesktop General 插件的通用标签能力 + Surfingkeys 核心子集 (纯按键重放层):
;   滚动 j/k/h/l, 半页 d/u, 整页 <C-f>/<C-b>, 顶底 gg/G, 行首尾 0/$,
;   标签 t/x/X/J/K/gn/gp/g1..g0, 历史 H/L, 刷新 r/R, 地址栏 o, 查找 //n/N,
;   缩放 zi/zo/z0, 收藏 b, 历史 gh, 下载 gd, 插入 i/a, 回到 normal <Esc>.
; 做不到的 (需 DOM 注入, 留给 Surfingkeys/Vimium 扩展): f 链接提示、v 可视选择、
;   omnibar 模糊搜索. normal 模式下 f 未映射, 直接透传 (给扩展留键).
; 输入框保护: insert 模式除 <Esc>/<C-[> 外零映射 (逐字透传); normal 下在输入框里
;   打字前先按 i (与 VimDesktop General 一致); o// 动作自动切 insert.
; 默认模式 insert (cVim/Vimium 语义: 新窗新标签聚焦地址栏, 本来就要打字),
;   走通用 ini [Browser_*] default_mode, 插件内不硬编码 (可被翻转).
; 地址栏/查找条 Esc: insert 模式 <Esc> 经 Bw_NormalMode 原样 Send("{Escape}"),
;   查找条能正常关闭.

class BrowserPlugin extends RimPlugin {
    static Name => "Browser"
    static Title => "Browser Vim Mode"
    static Author => "Rim"
    static Description => "Chrome/Edge/Firefox Vim 按键 (滚动/标签/历史/查找)"
    static Version => "1.0.0"
    static ApiVersion => "1"
    static Capabilities => ["keymaps"]

    static RegisterKeymaps(engine) {
        Browser_Keymaps(engine)
    }
}

if (IsSet(RimPluginManager) && IsObject(RimPluginManager))
    RimPluginManager.Register(BrowserPlugin)

Browser_Keymaps(engine) {
    ; 建窗 (exe 优先匹配: Chrome/Edge 同类 Chrome_WidgetWin_1, 靠 exe 区分;
    ; VSCode 同类但 exe=Code.exe, 不会误命中)
    engine.SetWin("Browser_Chrome", "Chrome_WidgetWin_1", "chrome.exe")
    engine.SetWin("Browser_Edge", "Chrome_WidgetWin_1", "msedge.exe")
    engine.SetWin("Browser_Firefox", "MozillaWindowClass", "firefox.exe")
    for _, bwName in ["Browser_Chrome", "Browser_Edge", "Browser_Firefox"] {
        try engine.GetWin(bwName).SetTimeOut(800)
        try engine.GetWin(bwName).ShowInfo := false
        engine.SetBeforeActionDoForWin(bwName, Browser_Before)
    }

    ; ---- 动作注册 (注释经 T() 走语言包; 探针扫描此块保证动作↔函数一一对应) ----
    engine.SetAction("<Bw_Down>", T("act.Browser.Bw_Down"))
    engine.SetAction("<Bw_Up>", T("act.Browser.Bw_Up"))
    engine.SetAction("<Bw_Left>", T("act.Browser.Bw_Left"))
    engine.SetAction("<Bw_Right>", T("act.Browser.Bw_Right"))
    engine.SetAction("<Bw_HalfDown>", T("act.Browser.Bw_HalfDown"))
    engine.SetAction("<Bw_HalfUp>", T("act.Browser.Bw_HalfUp"))
    engine.SetAction("<Bw_PageDown>", T("act.Browser.Bw_PageDown"))
    engine.SetAction("<Bw_PageUp>", T("act.Browser.Bw_PageUp"))
    engine.SetAction("<Bw_Top>", T("act.Browser.Bw_Top"))
    engine.SetAction("<Bw_Bottom>", T("act.Browser.Bw_Bottom"))
    engine.SetAction("<Bw_Home>", T("act.Browser.Bw_Home"))
    engine.SetAction("<Bw_End>", T("act.Browser.Bw_End"))
    engine.SetAction("<Bw_NewTab>", T("act.Browser.Bw_NewTab"))
    engine.SetAction("<Bw_CloseTab>", T("act.Browser.Bw_CloseTab"))
    engine.SetAction("<Bw_RestoreTab>", T("act.Browser.Bw_RestoreTab"))
    engine.SetAction("<Bw_NextTab>", T("act.Browser.Bw_NextTab"))
    engine.SetAction("<Bw_PrevTab>", T("act.Browser.Bw_PrevTab"))
    engine.SetAction("<Bw_Tab1>", T("act.Browser.Bw_Tab1"))
    engine.SetAction("<Bw_Tab2>", T("act.Browser.Bw_Tab2"))
    engine.SetAction("<Bw_Tab3>", T("act.Browser.Bw_Tab3"))
    engine.SetAction("<Bw_Tab4>", T("act.Browser.Bw_Tab4"))
    engine.SetAction("<Bw_Tab5>", T("act.Browser.Bw_Tab5"))
    engine.SetAction("<Bw_Tab6>", T("act.Browser.Bw_Tab6"))
    engine.SetAction("<Bw_Tab7>", T("act.Browser.Bw_Tab7"))
    engine.SetAction("<Bw_Tab8>", T("act.Browser.Bw_Tab8"))
    engine.SetAction("<Bw_LastTab>", T("act.Browser.Bw_LastTab"))
    engine.SetAction("<Bw_Back>", T("act.Browser.Bw_Back"))
    engine.SetAction("<Bw_Forward>", T("act.Browser.Bw_Forward"))
    engine.SetAction("<Bw_Reload>", T("act.Browser.Bw_Reload"))
    engine.SetAction("<Bw_ForceReload>", T("act.Browser.Bw_ForceReload"))
    engine.SetAction("<Bw_AddrBar>", T("act.Browser.Bw_AddrBar"))
    engine.SetAction("<Bw_Find>", T("act.Browser.Bw_Find"))
    engine.SetAction("<Bw_FindNext>", T("act.Browser.Bw_FindNext"))
    engine.SetAction("<Bw_FindPrev>", T("act.Browser.Bw_FindPrev"))
    engine.SetAction("<Bw_ZoomIn>", T("act.Browser.Bw_ZoomIn"))
    engine.SetAction("<Bw_ZoomOut>", T("act.Browser.Bw_ZoomOut"))
    engine.SetAction("<Bw_ZoomReset>", T("act.Browser.Bw_ZoomReset"))
    engine.SetAction("<Bw_Bookmark>", T("act.Browser.Bw_Bookmark"))
    engine.SetAction("<Bw_History>", T("act.Browser.Bw_History"))
    engine.SetAction("<Bw_Downloads>", T("act.Browser.Bw_Downloads"))
    engine.SetAction("<Bw_InsertMode>", T("act.Browser.Bw_InsertMode"))
    engine.SetAction("<Bw_NormalMode>", T("act.Browser.Bw_NormalMode"))
    engine.SetAction("<Bw_Help>", T("act.Browser.Bw_Help"))

    for _, bwName in ["Browser_Chrome", "Browser_Edge", "Browser_Firefox"]
        Browser_BindWindow(engine, bwName)
}

Browser_BindWindow(engine, bwName) {
    m := "normal"
    ; 滚动
    engine.MapKey("j", "<Bw_Down>", bwName, m)
    engine.MapKey("k", "<Bw_Up>", bwName, m)
    engine.MapKey("h", "<Bw_Left>", bwName, m)
    engine.MapKey("l", "<Bw_Right>", bwName, m)
    engine.MapKey("d", "<Bw_HalfDown>", bwName, m)
    engine.MapKey("u", "<Bw_HalfUp>", bwName, m)
    engine.MapKey("<C-d>", "<Bw_HalfDown>", bwName, m)
    engine.MapKey("<C-u>", "<Bw_HalfUp>", bwName, m)
    engine.MapKey("<C-f>", "<Bw_PageDown>", bwName, m)
    engine.MapKey("<C-b>", "<Bw_PageUp>", bwName, m)
    engine.MapKey("gg", "<Bw_Top>", bwName, m)
    engine.MapKey("G", "<Bw_Bottom>", bwName, m)
    engine.MapKey("0", "<Bw_Home>", bwName, m)
    engine.MapKey("$", "<Bw_End>", bwName, m)
    ; 标签 (J/K 大写切标签, 小写 j/k 保持滚动, 与 Vimium 一致)
    engine.MapKey("t", "<Bw_NewTab>", bwName, m)
    engine.MapKey("x", "<Bw_CloseTab>", bwName, m)
    engine.MapKey("X", "<Bw_RestoreTab>", bwName, m)
    engine.MapKey("J", "<Bw_NextTab>", bwName, m)
    engine.MapKey("K", "<Bw_PrevTab>", bwName, m)
    engine.MapKey("gn", "<Bw_NextTab>", bwName, m)
    engine.MapKey("gp", "<Bw_PrevTab>", bwName, m)
    engine.MapKey("g1", "<Bw_Tab1>", bwName, m)
    engine.MapKey("g2", "<Bw_Tab2>", bwName, m)
    engine.MapKey("g3", "<Bw_Tab3>", bwName, m)
    engine.MapKey("g4", "<Bw_Tab4>", bwName, m)
    engine.MapKey("g5", "<Bw_Tab5>", bwName, m)
    engine.MapKey("g6", "<Bw_Tab6>", bwName, m)
    engine.MapKey("g7", "<Bw_Tab7>", bwName, m)
    engine.MapKey("g8", "<Bw_Tab8>", bwName, m)
    engine.MapKey("g0", "<Bw_LastTab>", bwName, m)
    ; 历史 / 刷新
    engine.MapKey("H", "<Bw_Back>", bwName, m)
    engine.MapKey("L", "<Bw_Forward>", bwName, m)
    engine.MapKey("r", "<Bw_Reload>", bwName, m)
    engine.MapKey("R", "<Bw_ForceReload>", bwName, m)
    ; 地址栏 / 查找 (动作内自动切 insert)
    engine.MapKey("o", "<Bw_AddrBar>", bwName, m)
    engine.MapKey("/", "<Bw_Find>", bwName, m)
    engine.MapKey("n", "<Bw_FindNext>", bwName, m)
    engine.MapKey("N", "<Bw_FindPrev>", bwName, m)
    ; 缩放 / 收藏 / 历史 / 下载
    engine.MapKey("zi", "<Bw_ZoomIn>", bwName, m)
    engine.MapKey("zo", "<Bw_ZoomOut>", bwName, m)
    engine.MapKey("z0", "<Bw_ZoomReset>", bwName, m)
    engine.MapKey("b", "<Bw_Bookmark>", bwName, m)
    engine.MapKey("gh", "<Bw_History>", bwName, m)
    engine.MapKey("gd", "<Bw_Downloads>", bwName, m)
    ; 模式切换 / 帮助
    engine.MapKey("i", "<Bw_InsertMode>", bwName, m)
    engine.MapKey("a", "<Bw_InsertMode>", bwName, m)
    engine.MapKey("?", "<Bw_Help>", bwName, m)
    ; 数字作 Count 前缀 (bare 0=行首, 见引擎数字分支; 其余数字累计数)
    engine.MapKey("1", "<Pass>", bwName, m)
    engine.MapKey("2", "<Pass>", bwName, m)
    engine.MapKey("3", "<Pass>", bwName, m)
    engine.MapKey("4", "<Pass>", bwName, m)
    engine.MapKey("5", "<Pass>", bwName, m)
    engine.MapKey("6", "<Pass>", bwName, m)
    engine.MapKey("7", "<Pass>", bwName, m)
    engine.MapKey("8", "<Pass>", bwName, m)
    engine.MapKey("9", "<Pass>", bwName, m)
    ; insert 模式: 只留出口, 其余全部透传 (输入框打字安全)
    engine.MapKey("<Esc>", "<Bw_NormalMode>", bwName, "insert")
    engine.MapKey("<C-[>", "<Bw_NormalMode>", bwName, "insert")
}

; 原生菜单/保存密码气泡弹出时透传 (v2 Xaml 菜单双认, 见 AGENTS 错误 21)
Browser_Before(actionName, bwWin) {
    try {
        if WinExist("ahk_class #32768") || WinExist("ahk_class Xaml_WindowedPopupClass")
            return true
    }
    return false
}

; 模式翻转 (只写引擎窗, __global__ 永不碰; 对齐 VimEditor_SetMode 语义)
Bw_SetMode(modeName) {
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

Bw_InsertMode() {
    Bw_SetMode("insert")
    ToolTip(T("ved.mode_insert"))
    SetTimer(() => ToolTip(), -600)
}

Bw_NormalMode() {
    Bw_SetMode("normal")
    Send("{Escape}")
    ToolTip(T("ved.mode_normal"))
    SetTimer(() => ToolTip(), -600)
}

; === 动作函数 (纯按键重放, 三家浏览器通用快捷键) ===
Bw_Down() {
    Send("{Down}")
}

Bw_Up() {
    Send("{Up}")
}

Bw_Left() {
    Send("{Left}")
}

Bw_Right() {
    Send("{Right}")
}

Bw_HalfDown() {
    Send("{Space}")
}

Bw_HalfUp() {
    Send("+{Space}")
}

Bw_PageDown() {
    Send("{PgDn}")
}

Bw_PageUp() {
    Send("{PgUp}")
}

Bw_Top() {
    Send("{Home}")
}

Bw_Bottom() {
    Send("{End}")
}

Bw_Home() {
    Send("{Home}")
}

Bw_End() {
    Send("{End}")
}

Bw_NewTab() {
    Send("^t")
    ; 新标签聚焦地址栏, 跟进 insert (无提示, 地址栏聚焦本身即反馈)
    Bw_SetMode("insert")
}

Bw_CloseTab() {
    Send("^w")
}

Bw_RestoreTab() {
    Send("^+t")
}

Bw_NextTab() {
    Send("^{Tab}")
}

Bw_PrevTab() {
    Send("^+{Tab}")
}

Bw_Tab1() {
    Send("^1")
}

Bw_Tab2() {
    Send("^2")
}

Bw_Tab3() {
    Send("^3")
}

Bw_Tab4() {
    Send("^4")
}

Bw_Tab5() {
    Send("^5")
}

Bw_Tab6() {
    Send("^6")
}

Bw_Tab7() {
    Send("^7")
}

Bw_Tab8() {
    Send("^8")
}

Bw_LastTab() {
    Send("^9")
}

Bw_Back() {
    Send("!{Left}")
}

Bw_Forward() {
    Send("!{Right}")
}

Bw_Reload() {
    Send("{F5}")
}

Bw_ForceReload() {
    Send("^{F5}")
}

Bw_AddrBar() {
    Send("^l")
    Bw_SetMode("insert")
}

Bw_Find() {
    Send("^f")
    Bw_SetMode("insert")
}

Bw_FindNext() {
    Send("{F3}")
}

Bw_FindPrev() {
    Send("+{F3}")
}

Bw_ZoomIn() {
    Send("^=")
}

Bw_ZoomOut() {
    Send("^-")
}

Bw_ZoomReset() {
    Send("^0")
}

Bw_Bookmark() {
    Send("^d")
}

Bw_History() {
    Send("^h")
}

Bw_Downloads() {
    Send("^j")
}

Bw_Help() {
    ToolTip("j/k/h/l 滚动  d/u 半页  <C-f>/<C-b> 整页  gg/G 顶底`n"
        . "t 新标签  x 关  X 恢复  J/K 下/上标签  g1..g0 跳标签`n"
        . "H/L 后退前进  r/R 刷新  o 地址栏  //n/N 查找`n"
        . "zi/zo/z0 缩放  b 收藏  gh 历史  gd 下载  i 输入  Esc 返回")
    SetTimer(() => ToolTip(), -4000)
}
