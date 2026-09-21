; VimEditor.ahk - Vim编辑器插件
; 为不支持vim的编辑器注入vim编辑功能
; AHK v2注意: 函数名不区分大小写, 所有大写键用Key后缀

class VimEditorPlugin {
    static Name := "VimEditor"
    static enabled := true
    static version := "2.0.0"

    static MODE_NORMAL := "normal"
    static MODE_INSERT := "insert"
    static MODE_VISUAL := "visual"
    static MODE_VISUAL_LINE := "visual_line"
    static MODE_COMMAND := "command"

    static currentMode := "normal"
    static vimEnabled := false
    static repeatCount := 0
    static pendingKey := ""
    static registerBuffer := ""
    static registerIsLine := false
    static lastSearch := ""
    static lastSearchDir := 1
    static yankBuffer := ""
    static yankIsLine := false
    static undoBuffer := []
    static redoBuffer := []
    static macroRecording := false
    static macroKey := ""
    static macros := Map()
    static marks := Map()
    static lastCommand := ""
    static lastCommandArgs := ""

    static EditorWindows := Map(
        "Notepad", "记事本",
        "Typora", "Typora",
        "SublimeText", "Sublime",
        " mintty", "Git Bash",
        "ConsoleWindowClass", "命令提示符",
        "PuTTY", "PuTTY",
        "Code", "VSCode",
        "EditorPane", "编辑器",
        "Scintilla", "Scintilla",
        "TMemo", "TMemo",
        "RichEditD2DPT", "RichEdit",
        "Notepad++", "Notepad++",
        "ThunderRT6TextBox", "VB编辑器"
    )

    static actions := Map()

    __New() {
        this.InitActions()
        this.InitBindings()
    }

    InitActions() {
        this.RegisterAction("VimEditor_InsertMode", "进入插入模式")
        this.RegisterAction("VimEditor_NormalMode", "进入普通模式")
        this.RegisterAction("VimEditor_VisualMode", "进入可视模式")
        this.RegisterAction("VimEditor_VisualLineMode", "进入行可视模式")
        this.RegisterAction("VimEditor_Toggle", "启用/禁用Vim编辑")

        this.RegisterAction("VimEditor_h", "左移(h)")
        this.RegisterAction("VimEditor_j", "下移(j)")
        this.RegisterAction("VimEditor_k", "上移(k)")
        this.RegisterAction("VimEditor_l", "右移(l)")
        this.RegisterAction("VimEditor_w", "下个词首(w)")
        this.RegisterAction("VimEditor_WKey", "下个空白词首(W)")
        this.RegisterAction("VimEditor_b", "词首(b)")
        this.RegisterAction("VimEditor_BKey", "空白词首(B)")
        this.RegisterAction("VimEditor_e", "词尾(e)")
        this.RegisterAction("VimEditor_EKey", "空白词尾(E)")
        this.RegisterAction("VimEditor_0", "行首(0)")
        this.RegisterAction("VimEditor_Caret", "非空行首(^)")
        this.RegisterAction("VimEditor_Dollar", "行尾($)")
        this.RegisterAction("VimEditor_Go", "文件首行(gg)")
        this.RegisterAction("VimEditor_GKey", "文件尾行(G)")
        this.RegisterAction("VimEditor_HKey", "屏幕顶部(H)")
        this.RegisterAction("VimEditor_MKey", "屏幕中部(M)")
        this.RegisterAction("VimEditor_LKey", "屏幕底部(L)")
        this.RegisterAction("VimEditor_CtrlU", "上翻半页(Ctrl+U)")
        this.RegisterAction("VimEditor_CtrlD", "下翻半页(Ctrl+D)")
        this.RegisterAction("VimEditor_CtrlB", "上翻一页(Ctrl+B)")
        this.RegisterAction("VimEditor_CtrlF", "下翻一页(Ctrl+F)")

        this.RegisterAction("VimEditor_f", "向右查找字符(f)")
        this.RegisterAction("VimEditor_FKey", "向左查找字符(F)")
        this.RegisterAction("VimEditor_t", "向右到字符前(t)")
        this.RegisterAction("VimEditor_TKey", "向左到字符前(T)")
        this.RegisterAction("VimEditor_semicolon", "重复f/F/t/T(;)")

        this.RegisterAction("VimEditor_i", "光标前插入(i)")
        this.RegisterAction("VimEditor_a", "光标后插入(a)")
        this.RegisterAction("VimEditor_o", "下方新建行(o)")
        this.RegisterAction("VimEditor_IKey", "行首插入(I)")
        this.RegisterAction("VimEditor_AKey", "行尾插入(A)")
        this.RegisterAction("VimEditor_OKey", "上方新建行(O)")

        this.RegisterAction("VimEditor_x", "删除光标下字符(x)")
        this.RegisterAction("VimEditor_XKey", "删除光标前字符(X)")
        this.RegisterAction("VimEditor_r", "替换字符(r)")
        this.RegisterAction("VimEditor_dd", "删除整行(dd)")
        this.RegisterAction("VimEditor_DKey", "删除至行尾(D)")
        this.RegisterAction("VimEditor_CKey", "修改至行尾(C)")
        this.RegisterAction("VimEditor_cc", "修改整行(cc)")
        this.RegisterAction("VimEditor_s", "删除字符并插入(s)")
        this.RegisterAction("VimEditor_SKey", "修改整行(S)")
        this.RegisterAction("VimEditor_yy", "复制整行(yy)")
        this.RegisterAction("VimEditor_y", "复制(y)")
        this.RegisterAction("VimEditor_YKey", "复制整行(Y)")
        this.RegisterAction("VimEditor_p", "粘贴(p)")
        this.RegisterAction("VimEditor_PKey", "前粘贴(P)")
        this.RegisterAction("VimEditor_u", "撤销(u)")
        this.RegisterAction("VimEditor_CtrlR", "重做(Ctrl+R)")
        this.RegisterAction("VimEditor_JKey", "合并行(J)")
        this.RegisterAction("VimEditor_gJ", "合并行保留空格(gJ)")
        this.RegisterAction("VimEditor_tilde", "大小写切换(~)")
        this.RegisterAction("VimEditor_dot", "重复操作(.)")

        this.RegisterAction("VimEditor_diw", "删除单词(diw)")
        this.RegisterAction("VimEditor_daw", "删除含空格单词(daw)")
        this.RegisterAction("VimEditor_ciw", "修改单词(ciw)")
        this.RegisterAction("VimEditor_caw", "修改含空格单词(caw)")
        this.RegisterAction("VimEditor_yiw", "复制单词(yiw)")
        this.RegisterAction("VimEditor_yaw", "复制含空格单词(yaw)")
        this.RegisterAction("VimEditor_dib", "删除括号内(dib)")
        this.RegisterAction("VimEditor_dab", "删除含括号(dab)")
        this.RegisterAction("VimEditor_cib", "修改括号内(cib)")
        this.RegisterAction("VimEditor_cab", "修改含括号(cab)")
        this.RegisterAction("VimEditor_diq", '删除双引号内(di")')
        this.RegisterAction("VimEditor_diqq", "删除单引号内(di')")
        this.RegisterAction("VimEditor_ciq", '修改双引号内(ci")')
        this.RegisterAction("VimEditor_ciqq", "修改单引号内(ci')")
        this.RegisterAction("VimEditor_yiq", '复制双引号内(yi")')
        this.RegisterAction("VimEditor_yiqq", "复制单引号内(yi')")
        this.RegisterAction("VimEditor_dia", "删除尖括号内(dia)")
        this.RegisterAction("VimEditor_cia", "修改尖括号内(cia)")

        this.RegisterAction("VimEditor_slash", "向下搜索(/)")
        this.RegisterAction("VimEditor_question", "向上搜索(?)")
        this.RegisterAction("VimEditor_n", "下一个匹配(n)")
        this.RegisterAction("VimEditor_NKey", "上一个匹配(N)")
        this.RegisterAction("VimEditor_star", "搜索光标下单词(*)")
        this.RegisterAction("VimEditor_hash", "向上搜索光标下单词(#)")
        this.RegisterAction("VimEditor_percent", "跳转匹配括号(%)")

        this.RegisterAction("VimEditor_VisualDelete", "删除选区")
        this.RegisterAction("VimEditor_VisualCopy", "复制选区")
        this.RegisterAction("VimEditor_VisualPaste", "粘贴替换选区")
        this.RegisterAction("VimEditor_VisualU", "转小写")
        this.RegisterAction("VimEditor_VisualU2", "转大写")
        this.RegisterAction("VimEditor_VisualIndent", "右缩进")
        this.RegisterAction("VimEditor_VisualOutdent", "左缩进")
        this.RegisterAction("VimEditor_gg", "跳转首行(gg)")
        this.RegisterAction("VimEditor_gw", "自动换行(gw)")

        this.RegisterAction("VimEditor_1", "数字1")
        this.RegisterAction("VimEditor_2", "数字2")
        this.RegisterAction("VimEditor_3", "数字3")
        this.RegisterAction("VimEditor_4", "数字4/行尾($)")
        this.RegisterAction("VimEditor_5", "数字5")
        this.RegisterAction("VimEditor_6", "数字6/非空行首(^)")
        this.RegisterAction("VimEditor_7", "数字7")
        this.RegisterAction("VimEditor_8", "数字8")
        this.RegisterAction("VimEditor_9", "数字9")
        this.RegisterAction("VimEditor_q", "录制宏(q)")
        this.RegisterAction("VimEditor_at", "执行宏(@)")
    }

    RegisterAction(name, comment := "") {
        try Rim.engine.SetAction(name, comment)
    }

    InitBindings() {
        SetTimer(() => this.DoBind(), -100)
    }

    DoBind() {
        engine := Rim.engine
        for winClass, _ in this.EditorWindows
            this.BindWindow(engine, winClass)
        this.BindWindow(engine, "VimEditor_Global")
    }

    BindWindow(engine, wn) {
        m := this.MODE_NORMAL

        ; 模式切换
        engine.MapKey(wn, m, "i", "VimEditor_InsertMode")
        engine.MapKey(wn, m, "a", "VimEditor_a")
        engine.MapKey(wn, m, "o", "VimEditor_o")
        engine.MapKey(wn, m, "I", "VimEditor_IKey")
        engine.MapKey(wn, m, "A", "VimEditor_AKey")
        engine.MapKey(wn, m, "O", "VimEditor_OKey")
        engine.MapKey(wn, m, "s", "VimEditor_s")
        engine.MapKey(wn, m, "S", "VimEditor_SKey")

        ; 光标移动
        engine.MapKey(wn, m, "h", "VimEditor_h")
        engine.MapKey(wn, m, "j", "VimEditor_j")
        engine.MapKey(wn, m, "k", "VimEditor_k")
        engine.MapKey(wn, m, "l", "VimEditor_l")
        engine.MapKey(wn, m, "w", "VimEditor_w")
        engine.MapKey(wn, m, "W", "VimEditor_WKey")
        engine.MapKey(wn, m, "b", "VimEditor_b")
        engine.MapKey(wn, m, "B", "VimEditor_BKey")
        engine.MapKey(wn, m, "e", "VimEditor_e")
        engine.MapKey(wn, m, "E", "VimEditor_EKey")
        engine.MapKey(wn, m, "0", "VimEditor_0")
        engine.MapKey(wn, m, "^", "VimEditor_Caret")
        engine.MapKey(wn, m, "$", "VimEditor_Dollar")
        engine.MapKey(wn, m, "gg", "VimEditor_Go")
        engine.MapKey(wn, m, "G", "VimEditor_GKey")
        engine.MapKey(wn, m, "H", "VimEditor_HKey")
        engine.MapKey(wn, m, "M", "VimEditor_MKey")
        engine.MapKey(wn, m, "L", "VimEditor_LKey")
        engine.MapKey(wn, m, "<Ctrl-u>", "VimEditor_CtrlU")
        engine.MapKey(wn, m, "<Ctrl-d>", "VimEditor_CtrlD")
        engine.MapKey(wn, m, "<Ctrl-b>", "VimEditor_CtrlB")
        engine.MapKey(wn, m, "<Ctrl-f>", "VimEditor_CtrlF")

        ; 查找移动
        engine.MapKey(wn, m, "f", "VimEditor_f")
        engine.MapKey(wn, m, "F", "VimEditor_FKey")
        engine.MapKey(wn, m, "t", "VimEditor_t")
        engine.MapKey(wn, m, "T", "VimEditor_TKey")
        engine.MapKey(wn, m, ";", "VimEditor_semicolon")

        ; 编辑操作
        engine.MapKey(wn, m, "x", "VimEditor_x")
        engine.MapKey(wn, m, "X", "VimEditor_XKey")
        engine.MapKey(wn, m, "r", "VimEditor_r")
        engine.MapKey(wn, m, "dd", "VimEditor_dd")
        engine.MapKey(wn, m, "D", "VimEditor_DKey")
        engine.MapKey(wn, m, "C", "VimEditor_CKey")
        engine.MapKey(wn, m, "cc", "VimEditor_cc")
        engine.MapKey(wn, m, "yy", "VimEditor_yy")
        engine.MapKey(wn, m, "Y", "VimEditor_YKey")
        engine.MapKey(wn, m, "p", "VimEditor_p")
        engine.MapKey(wn, m, "P", "VimEditor_PKey")
        engine.MapKey(wn, m, "u", "VimEditor_u")
        engine.MapKey(wn, m, "<Ctrl-r>", "VimEditor_CtrlR")
        engine.MapKey(wn, m, "J", "VimEditor_JKey")
        engine.MapKey(wn, m, "gJ", "VimEditor_gJ")
        engine.MapKey(wn, m, "~", "VimEditor_tilde")
        engine.MapKey(wn, m, ".", "VimEditor_dot")

        ; 文本对象
        engine.MapKey(wn, m, "diw", "VimEditor_diw")
        engine.MapKey(wn, m, "daw", "VimEditor_daw")
        engine.MapKey(wn, m, "ciw", "VimEditor_ciw")
        engine.MapKey(wn, m, "caw", "VimEditor_caw")
        engine.MapKey(wn, m, "yiw", "VimEditor_yiw")
        engine.MapKey(wn, m, "yaw", "VimEditor_yaw")
        engine.MapKey(wn, m, "dib", "VimEditor_dib")
        engine.MapKey(wn, m, "dab", "VimEditor_dab")
        engine.MapKey(wn, m, "cib", "VimEditor_cib")
        engine.MapKey(wn, m, "cab", "VimEditor_cab")
        engine.MapKey(wn, m, "di`"", "VimEditor_diq")
        engine.MapKey(wn, m, "ci`"", "VimEditor_ciq")
        engine.MapKey(wn, m, "yi`"", "VimEditor_yiq")
        engine.MapKey(wn, m, "di'", "VimEditor_diqq")
        engine.MapKey(wn, m, "ci'", "VimEditor_ciqq")
        engine.MapKey(wn, m, "yi'", "VimEditor_yiqq")

        ; 查找替换
        engine.MapKey(wn, m, "/", "VimEditor_slash")
        engine.MapKey(wn, m, "?", "VimEditor_question")
        engine.MapKey(wn, m, "n", "VimEditor_n")
        engine.MapKey(wn, m, "N", "VimEditor_NKey")
        engine.MapKey(wn, m, "*", "VimEditor_star")
        engine.MapKey(wn, m, "#", "VimEditor_hash")
        engine.MapKey(wn, m, "%", "VimEditor_percent")

        ; 宏
        engine.MapKey(wn, m, "q", "VimEditor_q")
        engine.MapKey(wn, m, "@", "VimEditor_at")

        ; 可视模式
        engine.MapKey(wn, m, "v", "VimEditor_VisualMode")
        engine.MapKey(wn, m, "V", "VimEditor_VisualLineMode")

        ; 数字前缀
        engine.MapKey(wn, m, "1", "VimEditor_1")
        engine.MapKey(wn, m, "2", "VimEditor_2")
        engine.MapKey(wn, m, "3", "VimEditor_3")
        engine.MapKey(wn, m, "4", "VimEditor_4")
        engine.MapKey(wn, m, "5", "VimEditor_5")
        engine.MapKey(wn, m, "6", "VimEditor_6")
        engine.MapKey(wn, m, "7", "VimEditor_7")
        engine.MapKey(wn, m, "8", "VimEditor_8")
        engine.MapKey(wn, m, "9", "VimEditor_9")

        ; Insert/Visual模式Esc
        engine.MapKey(wn, this.MODE_INSERT, "<Esc>", "VimEditor_NormalMode")
        engine.MapKey(wn, this.MODE_VISUAL, "<Esc>", "VimEditor_NormalMode")
        engine.MapKey(wn, this.MODE_VISUAL_LINE, "<Esc>", "VimEditor_NormalMode")
    }

    static Register() {
        VimEditorPlugin()
        Log("VimEditor: 插件已注册 - v" VimEditorPlugin.version " - " VimEditorPlugin.EditorWindows.Count " 种编辑器")
    }
}

; ====================================================================
; 动作实现 - 模式切换
; ====================================================================
VimEditor_InsertMode() {
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_INSERT
    ToolTip("Insert模式")
    SetTimer () => ToolTip(), -600
}

VimEditor_NormalMode() {
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_NORMAL
    if WinActive("ahk_class #32770")
        Send "{Escape}"
    Send "{Escape}"
    ToolTip("Normal模式")
    SetTimer () => ToolTip(), -600
}

VimEditor_VisualMode() {
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_VISUAL
    Send "{Shift down}{Right}{Shift up}"
    ToolTip("Visual模式")
    SetTimer () => ToolTip(), -600
}

VimEditor_VisualLineMode() {
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_VISUAL_LINE
    Send "{Home}+{End}"
    ToolTip("Visual Line模式")
    SetTimer () => ToolTip(), -600
}

VimEditor_Toggle() {
    VimEditorPlugin.vimEnabled := !VimEditorPlugin.vimEnabled
    if (VimEditorPlugin.vimEnabled) {
        wc := ""
        try wc := WinGetClass("A")
        if (wc != "") {
            engine := Rim.engine
            engine.Copy("VimEditor_Global", wc, wc, "")
            engine.SetMode("normal", wc)
            n := VimEditorPlugin.EditorWindows.Has(wc) ? VimEditorPlugin.EditorWindows[wc] : wc
            ToolTip("Vim模式已启用 - " n)
        } else {
            ToolTip("当前窗口不是支持的编辑器")
        }
    } else {
        ToolTip("Vim模式已禁用")
    }
    SetTimer () => ToolTip(), -1500
}

; ====================================================================
; 光标移动 (小写)
; ====================================================================
VimEditor_h() {
    Send "{Left}"
}
VimEditor_j() {
    Send "{Down}"
}
VimEditor_k() {
    Send "{Up}"
}
VimEditor_l() {
    Send "{Right}"
}
VimEditor_w() {
    Send "{Ctrl down}{Right}{Ctrl up}"
}
VimEditor_b() {
    Send "{Ctrl down}{Left}{Ctrl up}"
}

VimEditor_e() {
    Send "{End}"
    Sleep 20
    Send "{Ctrl down}{Right}{Ctrl up}"
}

VimEditor_0() {
    Send "{Home}"
}

VimEditor_4() {  ; $ 行尾 或 数字4
    if (VimEditorPlugin.repeatCount > 0)
        VimEditorPlugin.repeatCount := VimEditorPlugin.repeatCount * 10 + 4
    else
        Send "{End}"
}

VimEditor_6() {  ; ^ 非空行首 或 数字6
    if (VimEditorPlugin.repeatCount > 0)
        VimEditorPlugin.repeatCount := VimEditorPlugin.repeatCount * 10 + 6
    else
        Send "{Home}"
}

VimEditor_Go() {
    Send "{Ctrl down}{Home}{Ctrl up}"
}

; ====================================================================
; 光标移动 (大写 - Key后缀避免冲突)
; ====================================================================
VimEditor_WKey() {
    Send "{Ctrl down}{Right}{Ctrl up}"
}
VimEditor_BKey() {
    Send "{Ctrl down}{Left}{Ctrl up}"
}
VimEditor_EKey() {
    Send "{End}"
    Sleep 20
    Send "{Ctrl down}{Right}{Ctrl up}"
}
VimEditor_GKey() {
    Send "{Ctrl down}{End}{Ctrl up}"
}
VimEditor_HKey() {
    Send "{Home}"
}
VimEditor_MKey() {
    WinGetPos(&wx, &wy, &ww, &wh)
    MouseMove(ww // 2, wh // 2, 0)
}
VimEditor_LKey() {
    Send "{End}"
}

; ====================================================================
; 翻页
; ====================================================================
VimEditor_CtrlU() {
    Send "{PgUp}"
}
VimEditor_CtrlD() {
    Send "{PgDn}"
}
VimEditor_CtrlB() {
    Send "{PgUp}"
}
VimEditor_CtrlF() {
    Send "{PgDn}"
}

; ====================================================================
; 查找移动
; ====================================================================
VimEditor_f() {
    ch := ""
    ih := InputHook("L1 T5", "{Escape}")
    ih.Start()
    ih.Wait()
    ch := ih.EndReason = "EndKey" ? "" : ih.Input
    if (ch != "")
        Send "{Right}"
}
VimEditor_FKey() {
    ch := ""
    ih := InputHook("L1 T5", "{Escape}")
    ih.Start()
    ih.Wait()
    ch := ih.EndReason = "EndKey" ? "" : ih.Input
    if (ch != "")
        Send "{Left}"
}
VimEditor_t() {
    ch := ""
    ih := InputHook("L1 T5", "{Escape}")
    ih.Start()
    ih.Wait()
    ch := ih.EndReason = "EndKey" ? "" : ih.Input
    if (ch != "")
        Send "{Right}"
}
VimEditor_TKey() {
    ch := ""
    ih := InputHook("L1 T5", "{Escape}")
    ih.Start()
    ih.Wait()
    ch := ih.EndReason = "EndKey" ? "" : ih.Input
    if (ch != "")
        Send "{Left}"
}
VimEditor_semicolon() {
}

; ====================================================================
; 插入模式进入 (小写)
; ====================================================================
VimEditor_a() {
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_INSERT
    Send "{Right}"
}
VimEditor_i() {
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_INSERT
}
VimEditor_o() {
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_INSERT
    Send "{Home}{Enter}{Up}"
}
VimEditor_s() {
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_INSERT
    Send "{Delete}"
}

; ====================================================================
; 插入模式进入 (大写 - Key后缀)
; ====================================================================
VimEditor_IKey() {
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_INSERT
    Send "{Home}"
}
VimEditor_AKey() {
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_INSERT
    Send "{End}"
}
VimEditor_OKey() {
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_INSERT
    Send "{Home}{Enter}{Up}"
}
VimEditor_SKey() {
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_INSERT
    Send "{Home}+{End}{Delete}"
}

; ====================================================================
; 编辑操作 (小写)
; ====================================================================
VimEditor_x() {
    Send "{Delete}"
}
VimEditor_r() {
    c := ""
    ih := InputHook("L1 T3", "{Escape}")
    ih.Start()
    ih.Wait()
    c := ih.EndReason = "EndKey" ? "" : ih.Input
    if (c != "")
        Send("{Delete}" c)
}
VimEditor_dd() {
    VimEditorPlugin.yankIsLine := true
    Send "{Home}+{End}{Delete}"
}
VimEditor_cc() {
    VimEditorPlugin.yankIsLine := true
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_INSERT
    Send "{Home}+{End}{Delete}"
}
VimEditor_yy() {
    Send "{Home}+{End}"
    Sleep 30
    VimEditorPlugin.yankBuffer := A_Clipboard
    VimEditorPlugin.yankIsLine := true
    Send "{Left}"
    ToolTip("已复制1行")
    SetTimer () => ToolTip(), -600
}
VimEditor_p() {
    if (VimEditorPlugin.yankIsLine) {
        Send "{End}{Enter}"
        Sleep 30
        Send "^v"
    } else {
        Send "{Right}"
        Sleep 30
        Send "^v"
    }
}
VimEditor_u() {
    Send "^z"
}
VimEditor_tilde() {
    Send "+{Right}"
    Sleep 30
    Send "^x"
}
VimEditor_dot() {
}

; ====================================================================
; 编辑操作 (大写 - Key后缀)
; ====================================================================
VimEditor_XKey() {
    Send "{Backspace}"
}
VimEditor_DKey() {
    VimEditorPlugin.yankIsLine := false
    Send "+{End}{Delete}"
}
VimEditor_CKey() {
    VimEditorPlugin.yankIsLine := false
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_INSERT
    Send "+{End}{Delete}"
}
VimEditor_YKey() {
    VimEditor_yy()
}
VimEditor_PKey() {
    if (VimEditorPlugin.yankIsLine) {
        Send "{Home}{Enter}{Up}"
        Sleep 30
        Send "^v"
    } else {
        Sleep 30
        Send "^v"
    }
}
VimEditor_CtrlR() {
    Send "^y"
}
VimEditor_JKey() {
    Send "{End}{Delete}{Space}"
}
VimEditor_gJ() {
    Send "{End}{Delete}"
}

; ====================================================================
; 文本对象 (word)
; ====================================================================
VimEditor_diw() {
    Send "{Ctrl down}{Left}{Ctrl up}"
    Sleep 30
    Send "{Shift down}{Ctrl down}{Right}{Ctrl up}{Shift up}{Delete}"
}
VimEditor_daw() {
    VimEditor_diw()
}
VimEditor_ciw() {
    VimEditor_diw()
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_INSERT
}
VimEditor_caw() {
    VimEditor_daw()
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_INSERT
}
VimEditor_yiw() {
    Send "{Ctrl down}{Left}{Ctrl up}"
    Sleep 30
    Send "{Shift down}{Ctrl down}{Right}{Ctrl up}{Shift up}"
    Sleep 30
    VimEditorPlugin.yankBuffer := A_Clipboard
    VimEditorPlugin.yankIsLine := false
    Send "{Left}"
}
VimEditor_yaw() {
    VimEditor_yiw()
}

; ====================================================================
; 文本对象 (brackets)
; ====================================================================
VimEditor_dib() {
    Send "{Shift down}{Home}{Shift up}{Delete}"
}
VimEditor_dab() {
    VimEditor_dib()
}
VimEditor_cib() {
    VimEditor_dib()
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_INSERT
}
VimEditor_cab() {
    VimEditor_dab()
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_INSERT
}

; ====================================================================
; 文本对象 (quotes)
; ====================================================================
VimEditor_diq() {
    Send "{Shift down}{Home}{Shift up}{Delete}"
}
VimEditor_ciq() {
    VimEditor_diq()
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_INSERT
}
VimEditor_yiq() {
    Send "{Shift down}{Home}{Shift up}"
    Sleep 30
    VimEditorPlugin.yankBuffer := A_Clipboard
    VimEditorPlugin.yankIsLine := false
}
VimEditor_diqq() {
    VimEditor_diq()
}
VimEditor_ciqq() {
    VimEditor_diq()
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_INSERT
}
VimEditor_yiqq() {
    VimEditor_yiq()
}
VimEditor_dia() {
    VimEditor_dib()
}
VimEditor_cia() {
    VimEditor_cib()
}

; ====================================================================
; 查找替换
; ====================================================================
VimEditor_slash() {
    Send "^f"
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_COMMAND
}
VimEditor_question() {
    Send "^f"
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_COMMAND
}
VimEditor_n() {
    Send "{F3}"
}
VimEditor_NKey() {
    Send "+{F3}"
}

VimEditor_star() {
    Send "{Ctrl down}{Right}{Ctrl up}"
    Sleep 30
    Send "^c"
    Sleep 30
    word := A_Clipboard
    if (word != "") {
        Send "^f"
        Sleep 100
        Send word
        Sleep 50
        Send "{Enter}{Escape}"
    }
}
VimEditor_hash() {
    VimEditor_star()
}
VimEditor_percent() {
}

; ====================================================================
; 可视模式操作
; ====================================================================
VimEditor_VisualDelete() {
    Send "{Delete}"
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_NORMAL
}
VimEditor_VisualCopy() {
    Send "^c"
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_NORMAL
}
VimEditor_VisualPaste() {
    Send "^v"
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_NORMAL
}
VimEditor_VisualU() {
    Send "^x"
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_NORMAL
}
VimEditor_VisualU2() {
    Send "^u"
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_NORMAL
}
VimEditor_VisualIndent() {
    Send "{Tab}"
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_NORMAL
}
VimEditor_VisualOutdent() {
    Send "+{Tab}"
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_NORMAL
}

; ====================================================================
; 宏
; ====================================================================
VimEditor_q() {
    if (VimEditorPlugin.macroRecording) {
        VimEditorPlugin.macroRecording := false
        ToolTip("宏录制结束")
        SetTimer () => ToolTip(), -600
    } else {
        mk := ""
        ih := InputHook("L1 T3", "{Escape}")
        ih.Start()
        ih.Wait()
        mk := ih.EndReason = "EndKey" ? "" : ih.Input
        if (mk != "") {
            VimEditorPlugin.macroRecording := true
            VimEditorPlugin.macroKey := mk
            ToolTip("录制宏: " mk)
            SetTimer () => ToolTip(), -600
        }
    }
}
VimEditor_at() {
    mk := ""
    ih := InputHook("L1 T3", "{Escape}")
    ih.Start()
    ih.Wait()
    mk := ih.EndReason = "EndKey" ? "" : ih.Input
}

; ====================================================================
; 杂项/数字
; ====================================================================
VimEditor_gw() {
}
VimEditor_1() {
    VimEditorPlugin.repeatCount := VimEditorPlugin.repeatCount * 10 + 1
}
VimEditor_2() {
    VimEditorPlugin.repeatCount := VimEditorPlugin.repeatCount * 10 + 2
}
VimEditor_3() {
    VimEditorPlugin.repeatCount := VimEditorPlugin.repeatCount * 10 + 3
}
VimEditor_5() {
    VimEditorPlugin.repeatCount := VimEditorPlugin.repeatCount * 10 + 5
}
VimEditor_7() {
    VimEditorPlugin.repeatCount := VimEditorPlugin.repeatCount * 10 + 7
}
VimEditor_8() {
    VimEditorPlugin.repeatCount := VimEditorPlugin.repeatCount * 10 + 8
}
VimEditor_9() {
    VimEditorPlugin.repeatCount := VimEditorPlugin.repeatCount * 10 + 9
}

GetActiveEditorClass() {
    wc := ""
    try wc := WinGetClass("A")
    return wc
}
