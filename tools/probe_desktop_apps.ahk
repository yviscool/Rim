#Requires AutoHotkey v2.0
#Warn All, Off

; 回归探针: 效率三窗 (Excel / Everything / Pdf)
; 1) 窗口注册 (类+exe; 福昕类名多变, 按 exe 匹配)
; 2) 核心映射抽查 + insert 出口
; 3) 动作↔函数一一对应 (三文件源码扫描)
; 4) Before 守卫 headless 默认透传否决 (=false, 无菜单无焦点时)
; 5) Excel PreKeyFilter: 未映射单字符吞 / 数字+组合+已映射放行
T(key, *) => key

#Include ..\Core\Plugin.ahk
#Include ..\Core\Engine.ahk
#Include ..\Plugins\Excel.ahk
#Include ..\Plugins\Everything.ahk
#Include ..\Plugins\Pdf.ahk

Assert(cond, msg) {
    if (!cond) {
        FileAppend("FAIL: " . msg . "`n", "*")
        ExitApp(1)
    }
    FileAppend("PASS: " . msg . "`n", "*")
}

engine := VimEngine()
Excel_Keymaps(engine)
Everything_Keymaps(engine)
Pdf_Keymaps(engine)

; --- 1) 窗口注册 ---
xlWin := engine.GetWin("Excel")
Assert(IsObject(xlWin), "xl-exists")
Assert(xlWin.WinClass = "XLMAIN" && xlWin.WinFile = "EXCEL.EXE", "xl-id")
evWin := engine.GetWin("Everything")
Assert(IsObject(evWin), "ev-exists")
Assert(evWin.WinClass = "EVERYTHING" && evWin.WinFile = "Everything.exe", "ev-id")
sumWin := engine.GetWin("Pdf_Sumatra")
foxWin := engine.GetWin("Pdf_Foxit")
foxNewWin := engine.GetWin("Pdf_FoxitNew")
Assert(IsObject(sumWin) && IsObject(foxWin) && IsObject(foxNewWin), "pdf-exists")
Assert(sumWin.WinClass = "SUMATRA_PDF_FRAME" && sumWin.WinFile = "SumatraPDF.exe", "pdf-sumatra-id")
Assert(foxWin.WinFile = "FoxitReader.exe" && foxNewWin.WinFile = "FoxitPDFReader.exe", "pdf-foxit-id")

; --- 2) 映射抽查 ---
xlNormal := xlWin.modeList["normal"].keymapList
XlMap(raw) => xlNormal.Has(NormalizeVimKey(raw)) ? xlNormal[NormalizeVimKey(raw)] : "<MISSING>"
Assert(XlMap("h") = "<Xl_Left>" && XlMap("j") = "<Xl_Down>", "xl-move")
Assert(XlMap("H") = "<Xl_SelLeft>" && XlMap("J") = "<Xl_SelDown>", "xl-sel")
Assert(XlMap("gg") = "<Xl_Top>" && XlMap("G") = "<Xl_Bottom>", "xl-topbottom")
Assert(XlMap("0") = "<Xl_Home>" && XlMap("$") = "<Xl_RowEnd>", "xl-homeend")
Assert(XlMap("u") = "<Xl_Undo>" && XlMap("<C-r>") = "<Xl_Redo>", "xl-undo")
Assert(XlMap("i") = "<Xl_InsertMode>" && XlMap("a") = "<Xl_Append>", "xl-edit")
Assert(XlMap("ZZ") = "<Xl_SaveExit>" && XlMap("ZQ") = "<Xl_CloseAsk>", "xl-saveexit")
Assert(XlMap("dd") = "<Xl_Clear>" && XlMap("yy") = "<Xl_Copy>", "xl-ddyy")
Assert(XlMap("sr") = "<Xl_SelRow>" && XlMap("sc") = "<Xl_SelCol>", "xl-selrowcol")
Assert(XlMap("gt") = "<Xl_NextSheet>" && XlMap("gT") = "<Xl_PrevSheet>", "xl-sheet")
Assert(XlMap("or") = "<Xl_InsRowAbove>" && XlMap("oc") = "<Xl_InsColLeft>", "xl-insrc")
Assert(XlMap("Fj") = "<Xl_FillDown>" && XlMap("Fl") = "<Xl_FillRight>", "xl-fill")
Assert(XlMap("/") = "<Xl_Find>" && XlMap("go") = "<Xl_GoTo>", "xl-findgoto")
Assert(XlMap("1") = "<Pass>", "xl-count")
Assert(xlWin.modeList["insert"].keymapList[NormalizeVimKey("<Esc>")] = "<Xl_NormalMode>", "xl-insert-esc")

evNormal := evWin.modeList["normal"].keymapList
EvMap(raw) => evNormal.Has(NormalizeVimKey(raw)) ? evNormal[NormalizeVimKey(raw)] : "<MISSING>"
Assert(EvMap("j") = "<Ev_Down>" && EvMap("k") = "<Ev_Up>", "ev-jk")
Assert(EvMap("gg") = "<Ev_Top>" && EvMap("G") = "<Ev_Bottom>", "ev-topbottom")
Assert(EvMap("i") = "<Ev_SearchFocus>" && EvMap("/") = "<Ev_SearchFocus>", "ev-search")
Assert(EvMap("<Esc>") = "<Ev_NormalMode>", "ev-esc")

pdfNormal := sumWin.modeList["normal"].keymapList
PdfMap(raw) => pdfNormal.Has(NormalizeVimKey(raw)) ? pdfNormal[NormalizeVimKey(raw)] : "<MISSING>"
Assert(PdfMap("j") = "<Pdf_Down>" && PdfMap("d") = "<Pdf_PageDown>", "pdf-scroll")
Assert(PdfMap("gg") = "<Pdf_Top>" && PdfMap("n") = "<Pdf_FindNext>", "pdf-topfind")
Assert(PdfMap("zi") = "<Pdf_ZoomIn>", "pdf-zoom")
Assert(foxWin.modeList["normal"].keymapList["j"] = "<Pdf_Down>", "pdf-foxit-parity")
Assert(!foxNewWin.modeList["normal"].keymapList.Has("t"), "pdf-foxitnew-unmapped-t")
Assert(sumWin.modeList["insert"].keymapList[NormalizeVimKey("<C-[>")] = "<Pdf_NormalMode>", "pdf-insert-ctrl")

; --- 3) 动作↔函数 wiring (三文件) ---
WireCheck(path, prefix) {
    content := FileRead(path, "UTF-8")
    content := StrReplace(content, "`r`n", "`n")
    registered := Map()
    pos := 1
    while (pos := RegExMatch(content, 'engine\.SetAction\("(<[A-Za-z0-9_]+>)"', &m, pos)) {
        registered[m[1]] := true
        pos += StrLen(m[0])
    }
    n := 0
    for actName in registered {
        fn := StrReplace(StrReplace(actName, "<", ""), ">", "")
        if (SubStr(fn, 1, StrLen(prefix)) != prefix) {
            FileAppend("FAIL: " . prefix . "-prefix " . actName . "`n", "*")
            ExitApp(1)
        }
        if (!RegExMatch(content, "m)^" . fn . "\(\) \{")) {
            FileAppend("FAIL: " . prefix . "-nofunc " . actName . "`n", "*")
            ExitApp(1)
        }
        n++
    }
    pos := 1
    while (pos := RegExMatch(content, 'engine\.MapKey\(.+?, "(<[A-Za-z0-9_]+>)"', &k, pos)) {
        if (k[1] != "<Pass>" && k[1] != "<>" && !registered.Has(k[1])) {
            FileAppend("FAIL: " . prefix . "-unreg " . k[1] . "`n", "*")
            ExitApp(1)
        }
        pos += StrLen(k[0])
    }
    FileAppend("PASS: " . prefix . "-wired=" . n . "`n", "*")
}
WireCheck(A_ScriptDir . "\..\Plugins\Excel.ahk", "Xl_")
WireCheck(A_ScriptDir . "\..\Plugins\Everything.ahk", "Ev_")
WireCheck(A_ScriptDir . "\..\Plugins\Pdf.ahk", "Pdf_")

; --- 4) Before 守卫 headless 默认 (=false) + NormalMode 白名单源码 ---
Assert(Xl_Before("<Xl_Down>", xlWin) = false, "xl-before-default")
Assert(Ev_Before("<Ev_Down>", evWin) = false, "ev-before-default")
Assert(Pdf_Before("<Pdf_Down>", sumWin) = false, "pdf-before-default")
for _, spec in [["Excel", "Xl"], ["Everything", "Ev"], ["Pdf", "Pdf"]] {
    content := FileRead(A_ScriptDir . "\..\Plugins\" . spec[1] . ".ahk", "UTF-8")
    content := StrReplace(content, "`r`n", "`n")
    Assert(InStr(content, 'if (actionName = "<' . spec[2] . '_NormalMode>")`n        return false') > 0, spec[2] . "-before-whitelist")
}

; --- 5) Excel PreKeyFilter (真引擎窗对象) ---
Assert(IsObject(xlWin.PreKeyFilterFunc), "xl-prefilter-mounted")
Assert(Xl_PreFilter("e", xlWin) = true, "xl-swallow-letter")
Assert(Xl_PreFilter("<S-E>", xlWin) = true, "xl-swallow-shiftletter")
Assert(Xl_PreFilter(";", xlWin) = true, "xl-swallow-punct")
Assert(Xl_PreFilter("j", xlWin) = false, "xl-keep-mapped")
Assert(Xl_PreFilter("1", xlWin) = false, "xl-keep-digit")
Assert(Xl_PreFilter("g", xlWin) = false, "xl-keep-prefix")
xlWin.KeyTemp := "g"
Assert(Xl_PreFilter("r", xlWin) = false, "xl-keep-combo")
xlWin.KeyTemp := ""
Assert(Xl_PreFilter("<F2>", xlWin) = false, "xl-keep-fkey")
xlWin.currentMode := "insert"
Assert(Xl_PreFilter("e", xlWin) = false, "xl-insert-types")
xlWin.currentMode := "normal"

try FileDelete(A_ScriptDir . "\..\probe_desktop_apps.out.txt")
FileAppend("probe-desktop-apps-ok`n", A_ScriptDir . "\..\probe_desktop_apps.out.txt")
ExitApp(0)
