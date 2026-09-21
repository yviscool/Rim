; VimEditorAdapters.ahk - 编辑器特殊适配
; 针对不同编辑器的特殊处理逻辑

; ====================================================================
; Typora 适配
; ====================================================================
class TyporaAdapter {
    static name := "Typora"

    ; Typora 特殊处理:
    ; 1. Typora使用自己的渲染引擎，标准Ctrl+Left/Right可能不工作
    ; 2. 需要使用TypeScript原生快捷键
    ; 3. 部分操作需要等待渲染完成

    static wordMoveLeft() {
        ; Typora: 使用Alt+Left移动单词
        Send "{Alt down}{Left}{Alt up}"
    }

    static wordMoveRight() {
        Send "{Alt down}{Right}{Alt up}"
    }

    static selectLine() {
        ; Typora选中当前行
        Send "{Home}+{End}"
    }

    static deleteLine() {
        Send "{Home}+{End}{Delete}"
    }

    static duplicateLine() {
        ; Typora复制行
        Send "{Home}+{End}"
        Sleep 50
        Send "^c"
        Sleep 50
        Send "{End}{Enter}"
        Sleep 50
        Send "^v"
    }

    static moveLineUp() {
        ; Typora上移行 (无原生支持，用剪贴板模拟)
        Send "{Home}+{End}"
        Sleep 30
        Send "^x"
        Sleep 30
        Send "{Up}{Home}"
        Sleep 30
        Send "^v"
        Sleep 30
        Send "{Up}{End}"
    }

    static moveLineDown() {
        Send "{Home}+{End}"
        Sleep 30
        Send "^x"
        Sleep 30
        Send "{Down}{End}{Enter}"
        Sleep 30
        Send "^v"
    }

    static commentLine() {
        ; Typora注释行
        Send "^+8"
    }

    static toggleBold() {
        Send "^b"
    }

    static toggleItalic() {
        Send "^i"
    }

    static toggleStrikethrough() {
        Send "^+x"
    }

    static insertLink() {
        Send "^k"
    }

    static insertImage() {
        Send "^+i"
    }

    static toggleCodeBlock() {
        Send "^+{Backtick}"
    }

    static toggleTable() {
        Send "^t"
    }
}

; ====================================================================
; Notepad 适配
; ====================================================================
class NotepadAdapter {
    static name := "Notepad"

    ; Notepad 特殊处理:
    ; 1. 标准Windows文本控件
    ; 2. Ctrl+Left/Right可以移动单词
    ; 3. 没有行号显示

    static wordMoveLeft() {
        Send "{Ctrl down}{Left}{Ctrl up}"
    }

    static wordMoveRight() {
        Send "{Ctrl down}{Right}{Ctrl up}"
    }

    static selectLine() {
        Send "{Home}+{End}"
    }

    static deleteLine() {
        Send "{Home}+{End}{Delete}"
    }

    static duplicateLine() {
        Send "{Home}+{End}"
        Sleep 50
        Send "^c"
        Sleep 50
        Send "{End}{Enter}"
        Sleep 50
        Send "^v"
    }

    static moveLineUp() {
        Send "{Home}+{End}"
        Sleep 30
        Send "^x"
        Sleep 30
        Send "{Up}{Home}"
        Sleep 30
        Send "^v"
    }

    static moveLineDown() {
        Send "{Home}+{End}"
        Sleep 30
        Send "^x"
        Sleep 30
        Send "{Down}{End}{Enter}"
        Sleep 30
        Send "^v"
    }
}

; ====================================================================
; Sublime Text 适配
; ====================================================================
class SublimeAdapter {
    static name := "SublimeText"

    ; Sublime 特殊处理:
    ; 1. 多光标支持
    ; 2. 增量选择
    ; 3. 快速跳转

    static wordMoveLeft() {
        Send "{Ctrl down}{Left}{Ctrl up}"
    }

    static wordMoveRight() {
        Send "{Ctrl down}{Right}{Ctrl up}"
    }

    static selectLine() {
        Send "{Home}+{End}"
    }

    static deleteLine() {
        Send "{Ctrl down}{Shift down}{k}{Ctrl up}{Shift up}"
    }

    static duplicateLine() {
        Send "{Ctrl down}{Shift down}{d}{Ctrl up}{Shift up}"
    }

    static moveLineUp() {
        Send "{Ctrl down}{Shift down}{Up}{Ctrl up}{Shift up}"
    }

    static moveLineDown() {
        Send "{Ctrl down}{Shift down}{Down}{Ctrl up}{Shift up}"
    }

    static commentLine() {
        Send "{Ctrl down}{/}{Ctrl up}"
    }

    static toggleMultipleSelection() {
        Send "{Ctrl down}{d}{Ctrl up}"
    }

    static selectAllOccurrences() {
        Send "{Ctrl down}{Alt down}{d}{Alt up}{Ctrl up}"
    }
}

; ====================================================================
; VSCode 适配
; ====================================================================
class VSCodeAdapter {
    static name := "Code"

    ; VSCode 特殊处理:
    ; 1. 内置终端
    ; 2. 多光标
    ; 3. 命令面板

    static wordMoveLeft() {
        Send "{Ctrl down}{Left}{Ctrl up}"
    }

    static wordMoveRight() {
        Send "{Ctrl down}{Right}{Ctrl up}"
    }

    static selectLine() {
        Send "{Home}+{End}"
    }

    static deleteLine() {
        Send "{Ctrl down}{Shift down}{k}{Ctrl up}{Shift up}"
    }

    static duplicateLine() {
        Send "{Ctrl down}{Shift down}{d}{Ctrl up}{Shift up}"
    }

    static moveLineUp() {
        Send "{Alt down}{Up}{Alt up}"
    }

    static moveLineDown() {
        Send "{Alt down}{Down}{Alt up}"
    }

    static commentLine() {
        Send "{Ctrl down}{/}{Ctrl up}"
    }

    static toggleTerminal() {
        Send "{Ctrl down}{`}{Ctrl up}"
    }

    static commandPalette() {
        Send "{Ctrl down}{Shift down}{p}{Ctrl up}{Shift up}"
    }

    static quickOpen() {
        Send "{Ctrl down}{p}{Ctrl up}"
    }
}

; ====================================================================
; Notepad++ 适配
; ====================================================================
class NotepadPlusPlusAdapter {
    static name := "Notepad++"

    ; Notepad++ 特殊处理:
    ; 1. Scintilla编辑器
    ; 2. 丰富的快捷键
    ; 3. 正则表达式支持

    static wordMoveLeft() {
        Send "{Ctrl down}{Left}{Ctrl up}"
    }

    static wordMoveRight() {
        Send "{Ctrl down}{Right}{Ctrl up}"
    }

    static selectLine() {
        Send "{Home}+{End}"
    }

    static deleteLine() {
        Send "{Ctrl down}{l}{Ctrl up}"
    }

    static duplicateLine() {
        Send "{Ctrl down}{d}{Ctrl up}"
    }

    static moveLineUp() {
        Send "{Ctrl down}{Alt down}{Up}{Ctrl up}{Alt up}"
    }

    static moveLineDown() {
        Send "{Ctrl down}{Alt down}{Down}{Ctrl up}{Alt up}"
    }

    static commentLine() {
        Send "{Ctrl down}{q}{Ctrl up}"
    }

    static toggleCase() {
        Send "{Ctrl down}{u}{Ctrl up}"
    }

    static upperCase() {
        Send "{Ctrl down}{Shift down}{u}{Ctrl up}{Shift up}"
    }

    static lowerCase() {
        Send "{Ctrl down}{u}{Ctrl up}"
    }
}

; ====================================================================
; 命令行适配
; ====================================================================
class ConsoleAdapter {
    static name := "ConsoleWindowClass"

    ; 命令行特殊处理:
    ; 1. 没有鼠标选择
    ; 2. 简单的光标移动
    ; 3. Tab补全

    static wordMoveLeft() {
        Send "{Ctrl down}{Left}{Ctrl up}"
    }

    static wordMoveRight() {
        Send "{Ctrl down}{Right}{Ctrl up}"
    }

    static selectLine() {
        Send "{Home}+{End}"
    }

    static deleteLine() {
        ; 命令行: 清除当前输入
        Send "^c"
    }

    static clearScreen() {
        Send "cls{Enter}"
    }

    static tabComplete() {
        Send "{Tab}"
    }
}

; ====================================================================
; 编辑器适配器工厂
; ====================================================================
class EditorAdapterFactory {
    static adapters := Map(
        "Notepad", NotepadAdapter,
        "Typora", TyporaAdapter,
        "SublimeText", SublimeAdapter,
        "Code", VSCodeAdapter,
        "Notepad++", NotepadPlusPlusAdapter,
        "ConsoleWindowClass", ConsoleAdapter
    )

    static GetAdapter(winClass) {
        if this.adapters.Has(winClass)
            return this.adapters[winClass]
        return ""
    }

    static GetAdapterByName(name) {
        for winClass, adapter in this.adapters {
            if (adapter.name = name)
                return adapter
        }
        return ""
    }

    static ListAdapters() {
        result := ""
        for winClass, adapter in this.adapters {
            result .= winClass " -> " adapter.name "`n"
        }
        return result
    }
}
