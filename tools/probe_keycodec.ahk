#Requires AutoHotkey v2.0
#Warn All, Off
; 键编解码探针: 分发链唯一的纯逻辑 (Convert2VIM/ConvertFromVim/NormalizeVimKey),
; 此前零覆盖. 锁死: 字母/功能键/修饰键双向映射 + Send 形态必带花括号
; (裸 Send("Esc") 会打出三个字母, 见 KeyHandler 注释; $CTRL-U 非法刷屏前科).

T(key, *) => key

#Include ..\Core\Engine.ahk

fails := []
Check(name, cond) {
    global fails
    if (!cond)
        fails.Push(name)
}

; 大小写敏感相等 (AHK 的 = 不分大小写, 此处必须分: Send("^C")=Ctrl+Shift+C, 见文档)
SameCase(a, b) {
    return !(a !== b)
}

Main() {
    global fails
    e := VimEngine()
    ; AHK -> Vim (归一 canonical: 修饰+字母一律大写, 注册侧大小写无关故无碍)
    Check("2vim-letter", SameCase(e.Convert2VIM("o"), "o"))
    Check("2vim-upper", SameCase(e.Convert2VIM("G"), "<S-G>"))
    Check("2vim-f5", SameCase(e.Convert2VIM("F5"), "<F5>"))
    Check("2vim-esc", SameCase(e.Convert2VIM("Esc"), "<Esc>"))
    Check("2vim-bs", SameCase(e.Convert2VIM("BS"), "<BS>"))
    Check("2vim-tab", SameCase(e.Convert2VIM("Tab"), "<Tab>"))
    Check("2vim-ctrl", SameCase(e.Convert2VIM("^c"), "<C-C>"))
    Check("2vim-alt", SameCase(e.Convert2VIM("!f"), "<A-F>"))
    Check("2vim-shift", SameCase(e.Convert2VIM("+a"), "<S-A>"))
    Check("2vim-win", SameCase(e.Convert2VIM("#r"), "<W-R>"))
    ; Vim -> AHK (注册侧 canonical 同样大写)
    Check("from-ctrl", SameCase(e.ConvertFromVim("<C-C>"), "^C"))
    Check("from-alt", SameCase(e.ConvertFromVim("<A-F>"), "!F"))
    ; Vim -> Send 形态 (透传侧, 特殊键必须花括号; 修饰+字母必须小写,
    ; 否则 Send 视为 Shift: "^C"=Ctrl+Shift+C, 文档实锤)
    Check("send-esc", SameCase(e.ConvertFromVim("<Esc>", true), "{Esc}"))
    Check("send-tab", SameCase(e.ConvertFromVim("<Tab>", true), "{Tab}"))
    Check("send-letter", SameCase(e.ConvertFromVim("o", true), "o"))
    Check("send-ctrl", SameCase(e.ConvertFromVim("<C-C>", true), "^c"))
    Check("send-alt", SameCase(e.ConvertFromVim("<A-F>", true), "!f"))
    Check("send-win", SameCase(e.ConvertFromVim("<W-R>", true), "#r"))
    Check("send-shift", SameCase(e.ConvertFromVim("<S-G>", true), "+G"))
    Check("send-lctrl", SameCase(e.ConvertFromVim("<LC-X>", true), "<^x"))
    Check("send-bs", SameCase(e.ConvertFromVim("<BS>", true), "{BS}"))
    ; 归一化 (ini 小写与运行时大写归一)
    Check("norm-lower", NormalizeVimKey("<c-b>") = "<C-B>")
    Check("norm-multi", NormalizeVimKey("a<C-b>") = "a<C-B>")
    Check("norm-upper-single", NormalizeVimKey("G") = "<S-G>")
    ; 往返: 注册名 -> Send 名对同一键
    Check("rt-ctrl", e.ConvertFromVim(e.Convert2VIM("^c"), true) = "^c")
    out := A_ScriptDir . "\..\probe_keycodec.out.txt"
    try FileDelete(out)
    catch {
    }
    if (fails.Length > 0) {
        txt := "keycodec-FAIL:`n"
        for _, x in fails
            txt .= "  - " . x . "`n"
        FileAppend(txt, out, "UTF-8")
        ExitApp(1)
    }
    FileAppend("keycodec-ok`n", out, "UTF-8")
    ExitApp(0)
}

Main()
