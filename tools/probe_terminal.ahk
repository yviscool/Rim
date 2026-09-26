#Requires AutoHotkey v2.0
#Warn All, Off

; 回归探针: 终端透传 (见 AGENTS.md 错误 31) + 全写修饰符转换
; 1) Terminal 窗匹配 CASCADIA 类且零映射 (数字/字母全部透传, 不进 Count)
; 2) <Ctrl-u> 等全写经归一化后仍转出 ^u (曾生成 $CTRL-U 非法热键刷屏)
#Include ..\Core\Plugin.ahk
#Include ..\Core\Engine.ahk
#Include ..\Plugins\Terminal.ahk

Assert(cond, msg) {
    if (!cond) {
        FileAppend("FAIL: " . msg . "`n", "*")
        ExitApp(1)
    }
    FileAppend("PASS: " . msg . "`n", "*")
}

engine := VimEngine()
Terminal_Keymaps(engine)

tw := engine.GetWin("Terminal")
Assert(IsObject(tw), "twin-exists")
Assert(tw.WinClass = "CASCADIA_HOSTING_WINDOW_CLASS", "twin-class")
Assert(!tw.modeList["normal"].keymapList.Has("3"), "twin-no-digit-map")
Assert(!tw.modeList["normal"].keymapList.Has("j"), "twin-no-letter-map")
Assert(!tw.KeyList.Has("3"), "twin-no-keylist")

; WT 在 CheckWin 类匹配轮次必须命中 Terminal (复刻 Engine.CheckWin 后半段)
hit := "__global__"
for name, win in engine.WinList {
    if (name = "__global__")
        continue
    if (win.WinClass != "" && "CASCADIA_HOSTING_WINDOW_CLASS" = win.WinClass) {
        hit := name
        break
    }
}
Assert(hit = "Terminal", "twin-hit")

; 全写修饰符 (归一化后全大写, 转换必须认)
Assert(engine.ConvertFromVim("<CTRL-U>") = "^U", "conv-ctrl-full")
Assert(engine.ConvertFromVim(NormalizeVimKey("<Ctrl-u>")) = "^U", "conv-ctrl-mixed")
Assert(engine.ConvertFromVim("<C-H>") = "^H", "conv-ctrl-short")
Assert(engine.ConvertFromVim("<ALT-X>") = "!X", "conv-alt-full")
Assert(engine.ConvertFromVim("<SHIFT-A>") = "+A", "conv-shift-full")
Assert(engine.ConvertFromVim("<WIN-D>") = "#D", "conv-win-full")
Assert(engine.ConvertFromVim("<LCTRL-C>") = "<^C", "conv-lctrl-full")
Assert(engine.ConvertFromVim("<RSHIFT-T>") = ">+T", "conv-rshift-full")

FileAppend("probe-terminal-ok`n", A_ScriptDir . "\..\probe_terminal.out.txt")
ExitApp(0)
