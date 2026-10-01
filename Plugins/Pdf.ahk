#Requires AutoHotkey v2.0
#Warn All, Off

; === Pdf Plugin - PDF 阅读 Vim 模式 ===
; SumatraPDF (SUMATRA_PDF_FRAME/SumatraPDF.exe) + 福昕 (类名多变, 按 exe 匹配:
; FoxitReader.exe 新老两代名): j/k/h/l 滚动, d/u 翻页, C-d/C-u 大翻页,
; gg/G 首尾, //n/N 查找, zi/zo/z0 缩放 (best-effort, 无效则无事发生).
; 安全: 查找条 Edit 聚焦时全透传, 但切回 normal 必须执行; 原生菜单透传.

class PdfPlugin extends RimPlugin {
    static Name => "Pdf"
    static Title => "PDF Vim Mode"
    static Author => "Rim"
    static Description => "SumatraPDF/福昕 Vim 阅读按键"
    static Version => "1.0.0"
    static ApiVersion => "1"
    static Capabilities => ["keymaps"]

    static RegisterKeymaps(engine) {
        Pdf_Keymaps(engine)
    }
}

if (IsSet(RimPluginManager) && IsObject(RimPluginManager))
    RimPluginManager.Register(PdfPlugin)

Pdf_Keymaps(engine) {
    engine.SetWin("Pdf_Sumatra", "SUMATRA_PDF_FRAME", "SumatraPDF.exe")
    engine.SetWin("Pdf_Foxit", "", "FoxitReader.exe")
    engine.SetWin("Pdf_FoxitNew", "", "FoxitPDFReader.exe")
    for _, pdfName in ["Pdf_Sumatra", "Pdf_Foxit", "Pdf_FoxitNew"] {
        try engine.GetWin(pdfName).SetTimeOut(800)
        try engine.GetWin(pdfName).ShowInfo := false
        engine.SetBeforeActionDoForWin(pdfName, Pdf_Before)
    }

    engine.SetAction("<Pdf_Down>", T("act.Pdf.Pdf_Down"))
    engine.SetAction("<Pdf_Up>", T("act.Pdf.Pdf_Up"))
    engine.SetAction("<Pdf_Left>", T("act.Pdf.Pdf_Left"))
    engine.SetAction("<Pdf_Right>", T("act.Pdf.Pdf_Right"))
    engine.SetAction("<Pdf_PageDown>", T("act.Pdf.Pdf_PageDown"))
    engine.SetAction("<Pdf_PageUp>", T("act.Pdf.Pdf_PageUp"))
    engine.SetAction("<Pdf_BigDown>", T("act.Pdf.Pdf_BigDown"))
    engine.SetAction("<Pdf_BigUp>", T("act.Pdf.Pdf_BigUp"))
    engine.SetAction("<Pdf_Top>", T("act.Pdf.Pdf_Top"))
    engine.SetAction("<Pdf_Bottom>", T("act.Pdf.Pdf_Bottom"))
    engine.SetAction("<Pdf_Home>", T("act.Pdf.Pdf_Home"))
    engine.SetAction("<Pdf_End>", T("act.Pdf.Pdf_End"))
    engine.SetAction("<Pdf_Find>", T("act.Pdf.Pdf_Find"))
    engine.SetAction("<Pdf_FindNext>", T("act.Pdf.Pdf_FindNext"))
    engine.SetAction("<Pdf_FindPrev>", T("act.Pdf.Pdf_FindPrev"))
    engine.SetAction("<Pdf_ZoomIn>", T("act.Pdf.Pdf_ZoomIn"))
    engine.SetAction("<Pdf_ZoomOut>", T("act.Pdf.Pdf_ZoomOut"))
    engine.SetAction("<Pdf_ZoomReset>", T("act.Pdf.Pdf_ZoomReset"))
    engine.SetAction("<Pdf_NormalMode>", T("act.Pdf.Pdf_NormalMode"))
    engine.SetAction("<Pdf_Help>", T("act.Pdf.Pdf_Help"))

    for _, pdfName in ["Pdf_Sumatra", "Pdf_Foxit", "Pdf_FoxitNew"]
        Pdf_BindWindow(engine, pdfName)
}

Pdf_BindWindow(engine, pdfName) {
    m := "normal"
    engine.MapKey("j", "<Pdf_Down>", pdfName, m)
    engine.MapKey("k", "<Pdf_Up>", pdfName, m)
    engine.MapKey("h", "<Pdf_Left>", pdfName, m)
    engine.MapKey("l", "<Pdf_Right>", pdfName, m)
    engine.MapKey("d", "<Pdf_PageDown>", pdfName, m)
    engine.MapKey("u", "<Pdf_PageUp>", pdfName, m)
    engine.MapKey("<C-d>", "<Pdf_BigDown>", pdfName, m)
    engine.MapKey("<C-u>", "<Pdf_BigUp>", pdfName, m)
    engine.MapKey("gg", "<Pdf_Top>", pdfName, m)
    engine.MapKey("G", "<Pdf_Bottom>", pdfName, m)
    engine.MapKey("0", "<Pdf_Home>", pdfName, m)
    engine.MapKey("$", "<Pdf_End>", pdfName, m)
    engine.MapKey("/", "<Pdf_Find>", pdfName, m)
    engine.MapKey("n", "<Pdf_FindNext>", pdfName, m)
    engine.MapKey("N", "<Pdf_FindPrev>", pdfName, m)
    engine.MapKey("zi", "<Pdf_ZoomIn>", pdfName, m)
    engine.MapKey("zo", "<Pdf_ZoomOut>", pdfName, m)
    engine.MapKey("z0", "<Pdf_ZoomReset>", pdfName, m)
    engine.MapKey("<Esc>", "<Pdf_NormalMode>", pdfName, m)
    engine.MapKey("?", "<Pdf_Help>", pdfName, m)
    for _, digit in ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
        engine.MapKey(digit, "<Pass>", pdfName, m)
    engine.MapKey("<Esc>", "<Pdf_NormalMode>", pdfName, "insert")
    engine.MapKey("<C-[>", "<Pdf_NormalMode>", pdfName, "insert")
}

; 查找条 (Edit 系) 聚焦时透传, 但切回 normal 必须执行; 原生菜单透传
Pdf_Before(actionName, pdfWin) {
    if (actionName = "<Pdf_NormalMode>")
        return false
    try {
        if WinExist("ahk_class #32768") || WinExist("ahk_class Xaml_WindowedPopupClass")
            return true
    }
    try {
        if InStr(FocusedClassNN("A"), "Edit")
            return true
    }
    return false
}

Pdf_SetMode(modeName) {
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

Pdf_NormalMode() {
    Pdf_SetMode("normal")
    Send("{Escape}")
    ToolTip(T("ved.mode_normal"))
    SetTimer(() => ToolTip(), -600)
}

Pdf_Down() {
    Send("{Down}")
}

Pdf_Up() {
    Send("{Up}")
}

Pdf_Left() {
    Send("{Left}")
}

Pdf_Right() {
    Send("{Right}")
}

Pdf_PageDown() {
    Send("{Space}")
}

Pdf_PageUp() {
    Send("+{Space}")
}

Pdf_BigDown() {
    Send("{PgDn}")
}

Pdf_BigUp() {
    Send("{PgUp}")
}

Pdf_Top() {
    Send("{Home}")
}

Pdf_Bottom() {
    Send("{End}")
}

Pdf_Home() {
    Send("{Home}")
}

Pdf_End() {
    Send("{End}")
}

Pdf_Find() {
    Send("^f")
    Pdf_SetMode("insert")
}

Pdf_FindNext() {
    Send("{F3}")
}

Pdf_FindPrev() {
    Send("+{F3}")
}

Pdf_ZoomIn() {
    Send("^=")
}

Pdf_ZoomOut() {
    Send("^-")
}

Pdf_ZoomReset() {
    Send("^0")
}

Pdf_Help() {
    ToolTip("j/k/h/l 滚  d/u 页  C-d/u 大翻`n"
        . "gg/G 首尾  //n/N 查找  zi/zo 缩放")
    SetTimer(() => ToolTip(), -4000)
}
