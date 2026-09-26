#Requires AutoHotkey v2.0

; === Terminal Plugin - Windows Terminal / 控制台透传 ===
; WT 主窗口类 CASCADIA_HOSTING_WINDOW_CLASS 稳定 (正式版/Preview 共用),
; exe 名随版本变化 (WindowsTerminal.exe / WindowsTerminalPreview.exe) 故只按类匹配.
; 终端永远是输入态: 本窗故意零映射, 未映射键走引擎透传分支 (Engine.ahk KeyHandler).
; 双保险: 分发不变量保证无类窗 (General) 不注册全局钩子, 未接管程序原生输入
; 零经过 Rim; 本窗提供 WT 的确定性身份 (诊断/VimDConfig 可见) 与 Win+W 合并目标.
; (老 conhost 走 ini [ConsoleWindowClass] 空映射, 同理透传; 这里补上 WT 即可)
; 如需在终端里用 Vim 键: 在终端聚焦时按 Win+W (绑定合并进本窗, 按窗独立, 再按一次关闭).

class TerminalPlugin extends RimPlugin {
    static Name => "Terminal"
    static Title => "Terminal Passthrough"
    static Description => "Windows Terminal 按键透传 (数字/字母直达, 不进 Vim 分发)"

    static RegisterKeymaps(engine) {
        Terminal_Keymaps(engine)
    }
}

if (IsSet(RimPluginManager) && IsObject(RimPluginManager))
    RimPluginManager.Register(TerminalPlugin)

Terminal_Keymaps(engine) {
    ; 建窗即匹配, 不 MapKey 即透传 (MapKey 会进 KeyList 反而触发 Count 吞键, 故一个都不绑)
    engine.SetWin("Terminal", "CASCADIA_HOSTING_WINDOW_CLASS", "")
    try engine.GetWin("Terminal").SetTimeOut(800)
    try engine.GetWin("Terminal").ShowInfo := false
}
