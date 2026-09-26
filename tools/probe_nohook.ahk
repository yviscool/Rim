#Requires AutoHotkey v2.0
#Warn All, Off

; 不变量探针: 无类+无文件的非 __global__ 窗 MapKey 必须零钩子 (见 AGENTS.md 错误 31)
; 判定原理: 零钩子/零定时器/零 GUI 的脚本走完顶层即自然退出 —— 本文件故意不用 ExitApp.
; 若守卫失效错注册了全局钩子, 进程常驻 hang, CI 侧按超时判失败.
#Include ..\Core\Engine.ahk

Assert(cond, msg) {
    if (!cond) {
        FileAppend("FAIL: " . msg . "`n", "*")
        ExitApp(1)
    }
    FileAppend("PASS: " . msg . "`n", "*")
}

engine := VimEngine()
engine.SetWin("General", "", "")
engine.SetAction("<Pass>", "pass")
engine.SetAction("<down>", "down")
engine.SetAction("<Gen_Tab3>", "tab3")
engine.MapKey("3", "<Pass>", "General", "normal")
engine.MapKey("j", "<down>", "General", "normal")
engine.MapKey("g3", "<Gen_Tab3>", "General", "normal")

; 映射作为数据必须保留 (按键浏览/注释/ini 引用), 只是不得产生钩子
Assert(engine.GetWin("General").modeList["normal"].keymapList.Has("3"), "general-keeps-data-3")
Assert(engine.GetWin("General").KeyList.Has("j"), "general-keeps-keylist-j")

FileAppend("probe-nohook-ok`n", A_ScriptDir . "\..\probe_nohook.out.txt")
; 故意无 ExitApp: 自然退出=零钩子=通过; 常驻 hang=失败.
