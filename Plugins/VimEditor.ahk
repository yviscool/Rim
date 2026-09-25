; VimEditor.ahk - Vim编辑器插件
; 为不支持vim的编辑器注入vim编辑功能
; AHK v2注意: 函数名不区分大小写, 所有大写键用Key后缀

; 统一插件入口 (Legacy vim 通道经此调用; 直接调 VimEditorPlugin.Register() 等效)
RegisterPlugin_VimEditor() {
    VimEditorPlugin.Register()
}

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

    ; 值: 需翻译的存 i18n key (消费点经 T() 解析), 英文直通的保持原文
    ; (static 初始化早于 I18nBoot, 此处禁止直接调 T())
    static EditorWindows := Map(
        "Notepad", "ved.ed_notepad",
        "Typora", "Typora",
        "SublimeText", "Sublime",
        " mintty", "Git Bash",
        "ConsoleWindowClass", "ved.ed_console",
        "PuTTY", "PuTTY",
        "Code", "VSCode",
        "EditorPane", "ved.ed_editor",
        "Scintilla", "Scintilla",
        "TMemo", "TMemo",
        "RichEditD2DPT", "RichEdit",
        "Notepad++", "Notepad++",
        "ThunderRT6TextBox", "ved.ed_vb"
    )

    static actions := Map()

    __New() {
        this.InitActions()
        this.InitBindings()
    }

    InitActions() {
        this.RegisterAction("VimEditor_InsertMode", T("act.VimEditor.VimEditor_InsertMode"))
        this.RegisterAction("VimEditor_NormalMode", T("act.VimEditor.VimEditor_NormalMode"))
        this.RegisterAction("VimEditor_VisualMode", T("act.VimEditor.VimEditor_VisualMode"))
        this.RegisterAction("VimEditor_VisualLineMode", T("act.VimEditor.VimEditor_VisualLineMode"))
        this.RegisterAction("VimEditor_Toggle", T("act.VimEditor.VimEditor_Toggle"))

        this.RegisterAction("VimEditor_h", T("act.VimEditor.VimEditor_h"))
        this.RegisterAction("VimEditor_j", T("act.VimEditor.VimEditor_j"))
        this.RegisterAction("VimEditor_k", T("act.VimEditor.VimEditor_k"))
        this.RegisterAction("VimEditor_l", T("act.VimEditor.VimEditor_l"))
        this.RegisterAction("VimEditor_w", T("act.VimEditor.VimEditor_w"))
        this.RegisterAction("VimEditor_WKey", T("act.VimEditor.VimEditor_WKey"))
        this.RegisterAction("VimEditor_b", T("act.VimEditor.VimEditor_b"))
        this.RegisterAction("VimEditor_BKey", T("act.VimEditor.VimEditor_BKey"))
        this.RegisterAction("VimEditor_e", T("act.VimEditor.VimEditor_e"))
        this.RegisterAction("VimEditor_EKey", T("act.VimEditor.VimEditor_EKey"))
        this.RegisterAction("VimEditor_0", T("act.VimEditor.VimEditor_0"))
        this.RegisterAction("VimEditor_Caret", T("act.VimEditor.VimEditor_Caret"))
        this.RegisterAction("VimEditor_Dollar", T("act.VimEditor.VimEditor_Dollar"))
        this.RegisterAction("VimEditor_Go", T("act.VimEditor.VimEditor_Go"))
        this.RegisterAction("VimEditor_GKey", T("act.VimEditor.VimEditor_GKey"))
        this.RegisterAction("VimEditor_HKey", T("act.VimEditor.VimEditor_HKey"))
        this.RegisterAction("VimEditor_MKey", T("act.VimEditor.VimEditor_MKey"))
        this.RegisterAction("VimEditor_LKey", T("act.VimEditor.VimEditor_LKey"))
        this.RegisterAction("VimEditor_CtrlU", T("act.VimEditor.VimEditor_CtrlU"))
        this.RegisterAction("VimEditor_CtrlD", T("act.VimEditor.VimEditor_CtrlD"))
        this.RegisterAction("VimEditor_CtrlB", T("act.VimEditor.VimEditor_CtrlB"))
        this.RegisterAction("VimEditor_CtrlF", T("act.VimEditor.VimEditor_CtrlF"))

        this.RegisterAction("VimEditor_f", T("act.VimEditor.VimEditor_f"))
        this.RegisterAction("VimEditor_FKey", T("act.VimEditor.VimEditor_FKey"))
        this.RegisterAction("VimEditor_t", T("act.VimEditor.VimEditor_t"))
        this.RegisterAction("VimEditor_TKey", T("act.VimEditor.VimEditor_TKey"))
        this.RegisterAction("VimEditor_semicolon", T("act.VimEditor.VimEditor_semicolon"))

        this.RegisterAction("VimEditor_i", T("act.VimEditor.VimEditor_i"))
        this.RegisterAction("VimEditor_a", T("act.VimEditor.VimEditor_a"))
        this.RegisterAction("VimEditor_o", T("act.VimEditor.VimEditor_o"))
        this.RegisterAction("VimEditor_IKey", T("act.VimEditor.VimEditor_IKey"))
        this.RegisterAction("VimEditor_AKey", T("act.VimEditor.VimEditor_AKey"))
        this.RegisterAction("VimEditor_OKey", T("act.VimEditor.VimEditor_OKey"))

        this.RegisterAction("VimEditor_x", T("act.VimEditor.VimEditor_x"))
        this.RegisterAction("VimEditor_XKey", T("act.VimEditor.VimEditor_XKey"))
        this.RegisterAction("VimEditor_r", T("act.VimEditor.VimEditor_r"))
        this.RegisterAction("VimEditor_dd", T("act.VimEditor.VimEditor_dd"))
        this.RegisterAction("VimEditor_DKey", T("act.VimEditor.VimEditor_DKey"))
        this.RegisterAction("VimEditor_CKey", T("act.VimEditor.VimEditor_CKey"))
        this.RegisterAction("VimEditor_cc", T("act.VimEditor.VimEditor_cc"))
        this.RegisterAction("VimEditor_s", T("act.VimEditor.VimEditor_s"))
        this.RegisterAction("VimEditor_SKey", T("act.VimEditor.VimEditor_SKey"))
        this.RegisterAction("VimEditor_yy", T("act.VimEditor.VimEditor_yy"))
        this.RegisterAction("VimEditor_y", T("act.VimEditor.VimEditor_y"))
        this.RegisterAction("VimEditor_YKey", T("act.VimEditor.VimEditor_YKey"))
        this.RegisterAction("VimEditor_p", T("act.VimEditor.VimEditor_p"))
        this.RegisterAction("VimEditor_PKey", T("act.VimEditor.VimEditor_PKey"))
        this.RegisterAction("VimEditor_u", T("act.VimEditor.VimEditor_u"))
        this.RegisterAction("VimEditor_CtrlR", T("act.VimEditor.VimEditor_CtrlR"))
        this.RegisterAction("VimEditor_JKey", T("act.VimEditor.VimEditor_JKey"))
        this.RegisterAction("VimEditor_gJ", T("act.VimEditor.VimEditor_gJ"))
        this.RegisterAction("VimEditor_tilde", T("act.VimEditor.VimEditor_tilde"))
        this.RegisterAction("VimEditor_dot", T("act.VimEditor.VimEditor_dot"))

        this.RegisterAction("VimEditor_diw", T("act.VimEditor.VimEditor_diw"))
        this.RegisterAction("VimEditor_daw", T("act.VimEditor.VimEditor_daw"))
        this.RegisterAction("VimEditor_ciw", T("act.VimEditor.VimEditor_ciw"))
        this.RegisterAction("VimEditor_caw", T("act.VimEditor.VimEditor_caw"))
        this.RegisterAction("VimEditor_yiw", T("act.VimEditor.VimEditor_yiw"))
        this.RegisterAction("VimEditor_yaw", T("act.VimEditor.VimEditor_yaw"))
        this.RegisterAction("VimEditor_dib", T("act.VimEditor.VimEditor_dib"))
        this.RegisterAction("VimEditor_dab", T("act.VimEditor.VimEditor_dab"))
        this.RegisterAction("VimEditor_cib", T("act.VimEditor.VimEditor_cib"))
        this.RegisterAction("VimEditor_cab", T("act.VimEditor.VimEditor_cab"))
        this.RegisterAction("VimEditor_diq", T("act.VimEditor.VimEditor_diq"))
        this.RegisterAction("VimEditor_diqq", T("act.VimEditor.VimEditor_diqq"))
        this.RegisterAction("VimEditor_ciq", T("act.VimEditor.VimEditor_ciq"))
        this.RegisterAction("VimEditor_ciqq", T("act.VimEditor.VimEditor_ciqq"))
        this.RegisterAction("VimEditor_yiq", T("act.VimEditor.VimEditor_yiq"))
        this.RegisterAction("VimEditor_yiqq", T("act.VimEditor.VimEditor_yiqq"))
        this.RegisterAction("VimEditor_dia", T("act.VimEditor.VimEditor_dia"))
        this.RegisterAction("VimEditor_cia", T("act.VimEditor.VimEditor_cia"))

        this.RegisterAction("VimEditor_slash", T("act.VimEditor.VimEditor_slash"))
        this.RegisterAction("VimEditor_question", T("act.VimEditor.VimEditor_question"))
        this.RegisterAction("VimEditor_n", T("act.VimEditor.VimEditor_n"))
        this.RegisterAction("VimEditor_NKey", T("act.VimEditor.VimEditor_NKey"))
        this.RegisterAction("VimEditor_star", T("act.VimEditor.VimEditor_star"))
        this.RegisterAction("VimEditor_hash", T("act.VimEditor.VimEditor_hash"))
        this.RegisterAction("VimEditor_percent", T("act.VimEditor.VimEditor_percent"))

        this.RegisterAction("VimEditor_VisualDelete", T("act.VimEditor.VimEditor_VisualDelete"))
        this.RegisterAction("VimEditor_VisualCopy", T("act.VimEditor.VimEditor_VisualCopy"))
        this.RegisterAction("VimEditor_VisualPaste", T("act.VimEditor.VimEditor_VisualPaste"))
        this.RegisterAction("VimEditor_VisualU", T("act.VimEditor.VimEditor_VisualU"))
        this.RegisterAction("VimEditor_VisualU2", T("act.VimEditor.VimEditor_VisualU2"))
        this.RegisterAction("VimEditor_VisualIndent", T("act.VimEditor.VimEditor_VisualIndent"))
        this.RegisterAction("VimEditor_VisualOutdent", T("act.VimEditor.VimEditor_VisualOutdent"))
        this.RegisterAction("VimEditor_gg", T("act.VimEditor.VimEditor_gg"))
        this.RegisterAction("VimEditor_gw", T("act.VimEditor.VimEditor_gw"))

        this.RegisterAction("VimEditor_1", T("act.VimEditor.VimEditor_1"))
        this.RegisterAction("VimEditor_2", T("act.VimEditor.VimEditor_2"))
        this.RegisterAction("VimEditor_3", T("act.VimEditor.VimEditor_3"))
        this.RegisterAction("VimEditor_4", T("act.VimEditor.VimEditor_4"))
        this.RegisterAction("VimEditor_5", T("act.VimEditor.VimEditor_5"))
        this.RegisterAction("VimEditor_6", T("act.VimEditor.VimEditor_6"))
        this.RegisterAction("VimEditor_7", T("act.VimEditor.VimEditor_7"))
        this.RegisterAction("VimEditor_8", T("act.VimEditor.VimEditor_8"))
        this.RegisterAction("VimEditor_9", T("act.VimEditor.VimEditor_9"))
        this.RegisterAction("VimEditor_q", T("act.VimEditor.VimEditor_q"))
        this.RegisterAction("VimEditor_at", T("act.VimEditor.VimEditor_at"))
    }

    RegisterAction(name, comment := "") {
        try Rim.vim.SetAction(name, comment)
    }

    InitBindings() {
        SetTimer(() => this.DoBind(), -100)
    }

    DoBind() {
        engine := Rim.vim
        for winClass, _ in VimEditorPlugin.EditorWindows
            this.BindWindow(engine, winClass)
        this.BindWindow(engine, "VimEditor_Global")
    }

    BindWindow(engine, wn) {
        m := VimEditorPlugin.MODE_NORMAL
        ; 窗口注册 (ini 未配的编辑器类在此建窗; 已有窗口则复用, 类名一致无覆盖风险)
        engine.SetWin(wn, wn, "")
        ; 历史调用形如 MapKey(wn, mode, key, action)，经局部闭包转正为引擎顺序 (key, action, wn, mode)
        mk := (w, mo, k, a) => engine.MapKey(k, a, w, mo)

        ; 模式切换
        mk(wn, m, "i", "VimEditor_InsertMode")
        mk(wn, m, "a", "VimEditor_a")
        mk(wn, m, "o", "VimEditor_o")
        mk(wn, m, "I", "VimEditor_IKey")
        mk(wn, m, "A", "VimEditor_AKey")
        mk(wn, m, "O", "VimEditor_OKey")
        mk(wn, m, "s", "VimEditor_s")
        mk(wn, m, "S", "VimEditor_SKey")

        ; 光标移动
        mk(wn, m, "h", "VimEditor_h")
        mk(wn, m, "j", "VimEditor_j")
        mk(wn, m, "k", "VimEditor_k")
        mk(wn, m, "l", "VimEditor_l")
        mk(wn, m, "w", "VimEditor_w")
        mk(wn, m, "W", "VimEditor_WKey")
        mk(wn, m, "b", "VimEditor_b")
        mk(wn, m, "B", "VimEditor_BKey")
        mk(wn, m, "e", "VimEditor_e")
        mk(wn, m, "E", "VimEditor_EKey")
        mk(wn, m, "0", "VimEditor_0")
        mk(wn, m, "^", "VimEditor_Caret")
        mk(wn, m, "$", "VimEditor_Dollar")
        mk(wn, m, "gg", "VimEditor_Go")
        mk(wn, m, "G", "VimEditor_GKey")
        mk(wn, m, "H", "VimEditor_HKey")
        mk(wn, m, "M", "VimEditor_MKey")
        mk(wn, m, "L", "VimEditor_LKey")
        mk(wn, m, "<Ctrl-u>", "VimEditor_CtrlU")
        mk(wn, m, "<Ctrl-d>", "VimEditor_CtrlD")
        mk(wn, m, "<Ctrl-b>", "VimEditor_CtrlB")
        mk(wn, m, "<Ctrl-f>", "VimEditor_CtrlF")

        ; 查找移动
        mk(wn, m, "f", "VimEditor_f")
        mk(wn, m, "F", "VimEditor_FKey")
        mk(wn, m, "t", "VimEditor_t")
        mk(wn, m, "T", "VimEditor_TKey")
        mk(wn, m, ";", "VimEditor_semicolon")

        ; 编辑操作
        mk(wn, m, "x", "VimEditor_x")
        mk(wn, m, "X", "VimEditor_XKey")
        mk(wn, m, "r", "VimEditor_r")
        mk(wn, m, "dd", "VimEditor_dd")
        mk(wn, m, "D", "VimEditor_DKey")
        mk(wn, m, "C", "VimEditor_CKey")
        mk(wn, m, "cc", "VimEditor_cc")
        mk(wn, m, "yy", "VimEditor_yy")
        mk(wn, m, "Y", "VimEditor_YKey")
        mk(wn, m, "p", "VimEditor_p")
        mk(wn, m, "P", "VimEditor_PKey")
        mk(wn, m, "u", "VimEditor_u")
        mk(wn, m, "<Ctrl-r>", "VimEditor_CtrlR")
        mk(wn, m, "J", "VimEditor_JKey")
        mk(wn, m, "gJ", "VimEditor_gJ")
        mk(wn, m, "~", "VimEditor_tilde")
        mk(wn, m, ".", "VimEditor_dot")

        ; 文本对象
        mk(wn, m, "diw", "VimEditor_diw")
        mk(wn, m, "daw", "VimEditor_daw")
        mk(wn, m, "ciw", "VimEditor_ciw")
        mk(wn, m, "caw", "VimEditor_caw")
        mk(wn, m, "yiw", "VimEditor_yiw")
        mk(wn, m, "yaw", "VimEditor_yaw")
        mk(wn, m, "dib", "VimEditor_dib")
        mk(wn, m, "dab", "VimEditor_dab")
        mk(wn, m, "cib", "VimEditor_cib")
        mk(wn, m, "cab", "VimEditor_cab")
        mk(wn, m, "di`"", "VimEditor_diq")
        mk(wn, m, "ci`"", "VimEditor_ciq")
        mk(wn, m, "yi`"", "VimEditor_yiq")
        mk(wn, m, "di'", "VimEditor_diqq")
        mk(wn, m, "ci'", "VimEditor_ciqq")
        mk(wn, m, "yi'", "VimEditor_yiqq")

        ; 查找替换
        mk(wn, m, "/", "VimEditor_slash")
        mk(wn, m, "?", "VimEditor_question")
        mk(wn, m, "n", "VimEditor_n")
        mk(wn, m, "N", "VimEditor_NKey")
        mk(wn, m, "*", "VimEditor_star")
        mk(wn, m, "#", "VimEditor_hash")
        mk(wn, m, "%", "VimEditor_percent")

        ; 宏
        mk(wn, m, "q", "VimEditor_q")
        mk(wn, m, "@", "VimEditor_at")

        ; 可视模式
        mk(wn, m, "v", "VimEditor_VisualMode")
        mk(wn, m, "V", "VimEditor_VisualLineMode")

        ; 数字前缀
        mk(wn, m, "1", "VimEditor_1")
        mk(wn, m, "2", "VimEditor_2")
        mk(wn, m, "3", "VimEditor_3")
        mk(wn, m, "4", "VimEditor_4")
        mk(wn, m, "5", "VimEditor_5")
        mk(wn, m, "6", "VimEditor_6")
        mk(wn, m, "7", "VimEditor_7")
        mk(wn, m, "8", "VimEditor_8")
        mk(wn, m, "9", "VimEditor_9")

        ; Insert/Visual模式Esc
        mk(wn, VimEditorPlugin.MODE_INSERT, "<Esc>", "VimEditor_NormalMode")
        mk(wn, VimEditorPlugin.MODE_VISUAL, "<Esc>", "VimEditor_NormalMode")
        mk(wn, VimEditorPlugin.MODE_VISUAL_LINE, "<Esc>", "VimEditor_NormalMode")
    }

    static Register() {
        VimEditorPlugin()
        ; 注册期日志: 探针线束未含 Utils.ahk 时 Log 不存在, try 吞掉 (运行时正常写日志)
        try Log("VimEditor: 插件已注册 - v" VimEditorPlugin.version " - " VimEditorPlugin.EditorWindows.Count " 种编辑器")
    }
}

; ====================================================================
; 动作实现 - 模式切换
; ====================================================================
VimEditor_InsertMode() {
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_INSERT
    ToolTip(T("ved.mode_insert"))
    SetTimer () => ToolTip(), -600
}

VimEditor_NormalMode() {
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_NORMAL
    if WinActive("ahk_class #32770")
        Send "{Escape}"
    Send "{Escape}"
    ToolTip(T("ved.mode_normal"))
    SetTimer () => ToolTip(), -600
}

VimEditor_VisualMode() {
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_VISUAL
    Send "{Shift down}{Right}{Shift up}"
    ToolTip(T("ved.mode_visual"))
    SetTimer () => ToolTip(), -600
}

VimEditor_VisualLineMode() {
    VimEditorPlugin.currentMode := VimEditorPlugin.MODE_VISUAL_LINE
    Send "{Home}+{End}"
    ToolTip(T("ved.mode_vline"))
    SetTimer () => ToolTip(), -600
}

VimEditor_Toggle() {
    VimEditorPlugin.vimEnabled := !VimEditorPlugin.vimEnabled
    if (VimEditorPlugin.vimEnabled) {
        wc := ""
        try wc := WinGetClass("A")
        if (wc != "") {
            engine := Rim.vim
            engine.CopyWin("VimEditor_Global", wc)
            engine.SetWin(wc, wc, "")
            engine.SetMode("normal", wc)
            ; Map 值是 i18n key 或英文直通原文, 经 T() 统一解析
            ; (audit 视 ved.ed_* 为间接引用, 属已知白名单, 见 T(变量) 调用)
            n := VimEditorPlugin.EditorWindows.Has(wc) ? T(VimEditorPlugin.EditorWindows[wc]) : wc
            ToolTip(T("ved.enabled", n))
        } else {
            ToolTip(T("ved.not_editor"))
        }
    } else {
        ToolTip(T("ved.disabled"))
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
    ToolTip(T("ved.yanked_line"))
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
        ToolTip(T("ved.macro_done"))
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
            ToolTip(T("ved.macro_rec", mk))
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
