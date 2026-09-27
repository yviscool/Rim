#Requires AutoHotkey v2.0
#Warn All, Off
#Include ..\Core\Engine.ahk

eng := VimEngine()
expected := Map("<c-u>", "^U", "<CTRL-U>", "^U", "<lctrl-r>", "<^R", "<S-F>", "+F", "<Enter>", "Enter")
for _, raw in ["<c-u>", "<CTRL-U>", "<lctrl-r>", "<S-F>", "<Enter>"] {
    n := NormalizeVimKey(raw)
    a := eng.ConvertFromVim(n)
    s := eng.ConvertFromVim(n, true)
    if (a != expected[raw])
        ExitApp(1)
    FileAppend(raw . "|" . n . "|" . a . "|" . s . "`n", "*")
    try {
        Hotkey("$" . a, (*) => 0, "On")
        Hotkey("$" . a, "Off")
    } catch
        ExitApp(2)
}
FileAppend("probe-vim-hotkeys-ok`n", A_ScriptDir . "\..\probe_vim_hotkeys.out.txt")
ExitApp(0)
