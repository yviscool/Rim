#Requires AutoHotkey v2.0
#Warn All, Off

; 不变量探针 (配对): __global__ (用户 [global] 节通道) 必须仍能注册全局钩子, 防矫枉过正.
; 判定: Hotkey Off 不抛错即钩子存在过. 注意 Off 不去常驻 (见 AGENTS.md 错误 33),
; 故本文件末尾必须显式 ExitApp, 与 probe_nohook 的"自然退出"判定相反.
#Include ..\Core\Engine.ahk

Assert(cond, msg) {
    if (!cond) {
        FileAppend("FAIL: " . msg . "`n", "*")
        ExitApp(1)
    }
    FileAppend("PASS: " . msg . "`n", "*")
}

engine := VimEngine()
engine.SetAction("<Pass>", "pass")
engine.MapGlobal("y", "<Pass>")

ok := false
try {
    Hotkey("$y", "Off")
    ok := true
} catch {
    ok := false
}
Assert(ok, "global-hook-registered")

FileAppend("probe-global-hook-ok`n", A_ScriptDir . "\..\probe_global_hook.out.txt")
ExitApp(0)
