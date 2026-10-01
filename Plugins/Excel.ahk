#Requires AutoHotkey v2.0
#Warn All, Off

; === Excel Plugin - 表格 Vim 模式 (复刻 VimDesktop MicrosoftExcel 按键层) ===
; 对标 VimDesktop plugins/MicrosoftExcel (2000+ 行) 的按键行为, COM 层按 Rim 注释重写:
;   能用原生热键平替的一律热键化 (gt/gT=Ctrl+PgDn/PgUp 切表, sr/sc=Shift+Space/Ctrl+Space,
;   Fj/Fl=Ctrl+D/R 填充), 深 COM (自动筛选/颜色/合并/定位) 本期不做.
; 安全设计 (与 VimDesktop 差异, 故意的):
;   Excel 里未映射的裸键会直接写进单元格 (!!), 故挂 PreKeyFilter: normal 下未映射的
;   单字符一律吞掉 (数字放行给 Count, 组合中放行). 想打字按 i (F2 进编辑).
;   ZZ=保存并关闭 (复刻), ZQ=只发 Alt+F4 (无 COM 静默弃存, 对话框让用户自己点).
;   or/oc/Or/Oc 右键菜单序列假设中文界面 (与原版一致), 英文界面下不用这四个键.
; BeforeActionDo: 公式栏/单元格编辑中 (EXCEL6*) 全透传, 但 Esc/C-[ 必须执行
;   (否则困在编辑态切不回 normal); 原生菜单弹出透传.
; 窗口: XLMAIN / EXCEL.EXE.

class ExcelPlugin extends RimPlugin {
    static Name => "Excel"
    static Title => "Excel Vim Mode"
    static Author => "Rim"
    static Description => "Excel 表格 Vim 按键 (移动/选择/复制/查找/工作表)"
    static Version => "1.0.0"
    static ApiVersion => "1"
    static Capabilities => ["keymaps"]

    static RegisterKeymaps(engine) {
        Excel_Keymaps(engine)
    }
}

if (IsSet(RimPluginManager) && IsObject(RimPluginManager))
    RimPluginManager.Register(ExcelPlugin)

Excel_Keymaps(engine) {
    engine.SetWin("Excel", "XLMAIN", "EXCEL.EXE")
    try engine.GetWin("Excel").SetTimeOut(800)
    try engine.GetWin("Excel").ShowInfo := false
    engine.SetBeforeActionDoForWin("Excel", Xl_Before)
    try engine.GetWin("Excel").PreKeyFilterFunc := Xl_PreFilter

    engine.SetAction("<Xl_Left>", T("act.Excel.Xl_Left"))
    engine.SetAction("<Xl_Right>", T("act.Excel.Xl_Right"))
    engine.SetAction("<Xl_Up>", T("act.Excel.Xl_Up"))
    engine.SetAction("<Xl_Down>", T("act.Excel.Xl_Down"))
    engine.SetAction("<Xl_SelLeft>", T("act.Excel.Xl_SelLeft"))
    engine.SetAction("<Xl_SelRight>", T("act.Excel.Xl_SelRight"))
    engine.SetAction("<Xl_SelUp>", T("act.Excel.Xl_SelUp"))
    engine.SetAction("<Xl_SelDown>", T("act.Excel.Xl_SelDown"))
    engine.SetAction("<Xl_EdgeUp>", T("act.Excel.Xl_EdgeUp"))
    engine.SetAction("<Xl_EdgeDown>", T("act.Excel.Xl_EdgeDown"))
    engine.SetAction("<Xl_EdgeLeft>", T("act.Excel.Xl_EdgeLeft"))
    engine.SetAction("<Xl_EdgeRight>", T("act.Excel.Xl_EdgeRight"))
    engine.SetAction("<Xl_Top>", T("act.Excel.Xl_Top"))
    engine.SetAction("<Xl_Bottom>", T("act.Excel.Xl_Bottom"))
    engine.SetAction("<Xl_Home>", T("act.Excel.Xl_Home"))
    engine.SetAction("<Xl_RowEnd>", T("act.Excel.Xl_RowEnd"))
    engine.SetAction("<Xl_PageDown>", T("act.Excel.Xl_PageDown"))
    engine.SetAction("<Xl_PageUp>", T("act.Excel.Xl_PageUp"))
    engine.SetAction("<Xl_Undo>", T("act.Excel.Xl_Undo"))
    engine.SetAction("<Xl_Redo>", T("act.Excel.Xl_Redo"))
    engine.SetAction("<Xl_InsertMode>", T("act.Excel.Xl_InsertMode"))
    engine.SetAction("<Xl_Append>", T("act.Excel.Xl_Append"))
    engine.SetAction("<Xl_AltMode>", T("act.Excel.Xl_AltMode"))
    engine.SetAction("<Xl_NormalMode>", T("act.Excel.Xl_NormalMode"))
    engine.SetAction("<Xl_SaveExit>", T("act.Excel.Xl_SaveExit"))
    engine.SetAction("<Xl_CloseAsk>", T("act.Excel.Xl_CloseAsk"))
    engine.SetAction("<Xl_Cut>", T("act.Excel.Xl_Cut"))
    engine.SetAction("<Xl_Clear>", T("act.Excel.Xl_Clear"))
    engine.SetAction("<Xl_Copy>", T("act.Excel.Xl_Copy"))
    engine.SetAction("<Xl_CopyRow>", T("act.Excel.Xl_CopyRow"))
    engine.SetAction("<Xl_CopyCol>", T("act.Excel.Xl_CopyCol"))
    engine.SetAction("<Xl_Paste>", T("act.Excel.Xl_Paste"))
    engine.SetAction("<Xl_PasteSpecial>", T("act.Excel.Xl_PasteSpecial"))
    engine.SetAction("<Xl_CopyFromLeft>", T("act.Excel.Xl_CopyFromLeft"))
    engine.SetAction("<Xl_CopyFromRight>", T("act.Excel.Xl_CopyFromRight"))
    engine.SetAction("<Xl_CopyFromUp>", T("act.Excel.Xl_CopyFromUp"))
    engine.SetAction("<Xl_CopyFromDown>", T("act.Excel.Xl_CopyFromDown"))
    engine.SetAction("<Xl_FillDown>", T("act.Excel.Xl_FillDown"))
    engine.SetAction("<Xl_FillRight>", T("act.Excel.Xl_FillRight"))
    engine.SetAction("<Xl_Replace>", T("act.Excel.Xl_Replace"))
    engine.SetAction("<Xl_Find>", T("act.Excel.Xl_Find"))
    engine.SetAction("<Xl_GoTo>", T("act.Excel.Xl_GoTo"))
    engine.SetAction("<Xl_NextSheet>", T("act.Excel.Xl_NextSheet"))
    engine.SetAction("<Xl_PrevSheet>", T("act.Excel.Xl_PrevSheet"))
    engine.SetAction("<Xl_InsRowAbove>", T("act.Excel.Xl_InsRowAbove"))
    engine.SetAction("<Xl_InsRowBelow>", T("act.Excel.Xl_InsRowBelow"))
    engine.SetAction("<Xl_InsColLeft>", T("act.Excel.Xl_InsColLeft"))
    engine.SetAction("<Xl_InsColRight>", T("act.Excel.Xl_InsColRight"))
    engine.SetAction("<Xl_SelRow>", T("act.Excel.Xl_SelRow"))
    engine.SetAction("<Xl_SelCol>", T("act.Excel.Xl_SelCol"))
    engine.SetAction("<Xl_SelAll>", T("act.Excel.Xl_SelAll"))
    engine.SetAction("<Xl_Help>", T("act.Excel.Xl_Help"))

    wn := "Excel"
    m := "normal"
    ; 移动 / 选择
    engine.MapKey("h", "<Xl_Left>", wn, m)
    engine.MapKey("l", "<Xl_Right>", wn, m)
    engine.MapKey("k", "<Xl_Up>", wn, m)
    engine.MapKey("j", "<Xl_Down>", wn, m)
    engine.MapKey("H", "<Xl_SelLeft>", wn, m)
    engine.MapKey("L", "<Xl_SelRight>", wn, m)
    engine.MapKey("K", "<Xl_SelUp>", wn, m)
    engine.MapKey("J", "<Xl_SelDown>", wn, m)
    engine.MapKey("gg", "<Xl_Top>", wn, m)
    engine.MapKey("G", "<Xl_Bottom>", wn, m)
    engine.MapKey("0", "<Xl_Home>", wn, m)
    engine.MapKey("$", "<Xl_RowEnd>", wn, m)
    ; 区域边缘 (gk 与 sk 同义, 对齐原版两套前缀)
    engine.MapKey("gk", "<Xl_EdgeUp>", wn, m)
    engine.MapKey("gj", "<Xl_EdgeDown>", wn, m)
    engine.MapKey("gh", "<Xl_EdgeLeft>", wn, m)
    engine.MapKey("gl", "<Xl_EdgeRight>", wn, m)
    engine.MapKey("sk", "<Xl_EdgeUp>", wn, m)
    engine.MapKey("sj", "<Xl_EdgeDown>", wn, m)
    engine.MapKey("sh", "<Xl_EdgeLeft>", wn, m)
    engine.MapKey("sl", "<Xl_EdgeRight>", wn, m)
    engine.MapKey("sr", "<Xl_SelRow>", wn, m)
    engine.MapKey("sc", "<Xl_SelCol>", wn, m)
    engine.MapKey("sa", "<Xl_SelAll>", wn, m)
    ; 翻页 (d 只做 dd 前缀, 对齐原版, 裸 d 超时静默; u 留给撤销)
    engine.MapKey("<C-d>", "<Xl_PageDown>", wn, m)
    engine.MapKey("<C-u>", "<Xl_PageUp>", wn, m)
    engine.MapKey("<space>", "<Xl_PageDown>", wn, m)
    engine.MapKey("<S-space>", "<Xl_PageUp>", wn, m)
    ; 撤销 / 模式
    engine.MapKey("u", "<Xl_Undo>", wn, m)
    engine.MapKey("<C-r>", "<Xl_Redo>", wn, m)
    engine.MapKey("i", "<Xl_InsertMode>", wn, m)
    engine.MapKey("a", "<Xl_Append>", wn, m)
    engine.MapKey("I", "<Xl_AltMode>", wn, m)
    engine.MapKey("<Esc>", "<Xl_NormalMode>", wn, m)
    engine.MapKey("?", "<Xl_Help>", wn, m)
    ; 保存退出
    engine.MapKey("ZZ", "<Xl_SaveExit>", wn, m)
    engine.MapKey("ZQ", "<Xl_CloseAsk>", wn, m)
    ; 剪贴板
    engine.MapKey("x", "<Xl_Cut>", wn, m)
    engine.MapKey("dd", "<Xl_Clear>", wn, m)
    engine.MapKey("D", "<Xl_Clear>", wn, m)
    engine.MapKey("yy", "<Xl_Copy>", wn, m)
    engine.MapKey("Y", "<Xl_Copy>", wn, m)
    engine.MapKey("yr", "<Xl_CopyRow>", wn, m)
    engine.MapKey("yc", "<Xl_CopyCol>", wn, m)
    engine.MapKey("p", "<Xl_Paste>", wn, m)
    engine.MapKey("P", "<Xl_PasteSpecial>", wn, m)
    engine.MapKey("yh", "<Xl_CopyFromLeft>", wn, m)
    engine.MapKey("yl", "<Xl_CopyFromRight>", wn, m)
    engine.MapKey("yk", "<Xl_CopyFromUp>", wn, m)
    engine.MapKey("yj", "<Xl_CopyFromDown>", wn, m)
    engine.MapKey("Fj", "<Xl_FillDown>", wn, m)
    engine.MapKey("Fl", "<Xl_FillRight>", wn, m)
    ; 查找替换 / 跳转
    engine.MapKey("rr", "<Xl_Replace>", wn, m)
    engine.MapKey("R", "<Xl_Replace>", wn, m)
    engine.MapKey("/", "<Xl_Find>", wn, m)
    engine.MapKey("go", "<Xl_GoTo>", wn, m)
    ; 工作表 (原生热键, 免 COM)
    engine.MapKey("gt", "<Xl_NextSheet>", wn, m)
    engine.MapKey("gT", "<Xl_PrevSheet>", wn, m)
    ; 插行列 (中文界面右键菜单序列, 与原版一致)
    engine.MapKey("or", "<Xl_InsRowAbove>", wn, m)
    engine.MapKey("Or", "<Xl_InsRowBelow>", wn, m)
    engine.MapKey("oc", "<Xl_InsColLeft>", wn, m)
    engine.MapKey("Oc", "<Xl_InsColRight>", wn, m)
    ; 数字作 Count 前缀
    for _, digit in ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
        engine.MapKey(digit, "<Pass>", wn, m)
    ; insert 模式: 只留出口
    engine.MapKey("<Esc>", "<Xl_NormalMode>", wn, "insert")
    engine.MapKey("<C-[>", "<Xl_NormalMode>", wn, "insert")
}

; 公式栏/单元格编辑中全透传 (EXCEL6* 系; 原版 MicrosoftExcel_BeforeActionDo 同条件),
; 但切回 normal 的动作必须执行 (否则困在编辑态); 原生菜单弹出透传
Xl_Before(actionName, xlWin) {
    if (actionName = "<Xl_NormalMode>")
        return false
    try {
        if WinExist("ahk_class #32768") || WinExist("ahk_class Xaml_WindowedPopupClass")
            return true
    }
    try {
        if InStr(FocusedClassNN("A"), "EXCEL6")
            return true
    }
    return false
}

; normal 下未映射单字符吞掉 (防写进单元格): 数字/组合中/已映射放行,
; 大写归一形 <S-X> 同理
Xl_PreFilter(vimKey, xlWin) {
    try {
        if IsObject(xlWin) {
            ; 只在 normal 下吞键: insert 本意就是打字, 永不拦截
            if (xlWin.currentMode != "normal")
                return false
            if (xlWin.KeyTemp != "")
                return false
        }
    }
    if RegExMatch(vimKey, "^\d$")
        return false
    try {
        if IsObject(xlWin) {
            if xlWin.KeyList.Has(vimKey)
                return false
            modeObj := xlWin.modeList.Has(xlWin.currentMode) ? xlWin.modeList[xlWin.currentMode] : ""
            if IsObject(modeObj) {
                if modeObj.keymapList.Has(vimKey) || modeObj.keymoreList.Has(vimKey)
                    return false
            }
        }
    }
    if (StrLen(vimKey) = 1 || RegExMatch(vimKey, "^<S-[A-Za-z]>$"))
        return true
    return false
}

Xl_SetMode(modeName) {
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

Xl_InsertMode() {
    Send("{F2}")
    Xl_SetMode("insert")
    ToolTip(T("ved.mode_insert"))
    SetTimer(() => ToolTip(), -600)
}

Xl_Append() {
    Send("{F2}")
    Send("{End}")
    Xl_SetMode("insert")
    ToolTip(T("ved.mode_insert"))
    SetTimer(() => ToolTip(), -600)
}

Xl_AltMode() {
    Xl_SetMode("insert")
    Send("{Alt}")
}

Xl_NormalMode() {
    Xl_SetMode("normal")
    Send("{Escape}")
    ToolTip(T("ved.mode_normal"))
    SetTimer(() => ToolTip(), -600)
}

; === 动作函数 (纯按键重放; or/oc 类中文菜单序列与原版一致) ===
Xl_Left() {
    Send("{Left}")
}

Xl_Right() {
    Send("{Right}")
}

Xl_Up() {
    Send("{Up}")
}

Xl_Down() {
    Send("{Down}")
}

Xl_SelLeft() {
    Send("+{Left}")
}

Xl_SelRight() {
    Send("+{Right}")
}

Xl_SelUp() {
    Send("+{Up}")
}

Xl_SelDown() {
    Send("+{Down}")
}

Xl_EdgeUp() {
    Send("^{Up}")
}

Xl_EdgeDown() {
    Send("^{Down}")
}

Xl_EdgeLeft() {
    Send("^{Left}")
}

Xl_EdgeRight() {
    Send("^{Right}")
}

Xl_Top() {
    Send("^{Home}")
}

Xl_Bottom() {
    Send("^{End}")
}

Xl_Home() {
    Send("{Home}")
}

Xl_RowEnd() {
    Send("^{Right}")
}

Xl_PageDown() {
    Send("{PgDn}")
}

Xl_PageUp() {
    Send("{PgUp}")
}

Xl_Undo() {
    Send("^z")
}

Xl_Redo() {
    Send("^y")
}

Xl_SaveExit() {
    Send("^s")
    Send("!{F4}")
}

Xl_CloseAsk() {
    Send("!{F4}")
}

Xl_Cut() {
    Send("^x")
}

Xl_Clear() {
    Send("{Del}")
}

Xl_Copy() {
    Send("^c")
}

Xl_CopyRow() {
    Send("+{Space}")
    Send("^c")
}

Xl_CopyCol() {
    Send("^{Space}")
    Send("^c")
}

Xl_Paste() {
    Send("^v")
}

Xl_PasteSpecial() {
    Send("^!v")
}

Xl_CopyFromLeft() {
    Send("{Left}")
    Send("^c")
    Send("{Right}")
    Send("^v")
}

Xl_CopyFromRight() {
    Send("{Right}")
    Send("^c")
    Send("{Left}")
    Send("^v")
}

Xl_CopyFromUp() {
    Send("{Up}")
    Send("^c")
    Send("{Down}")
    Send("^v")
}

Xl_CopyFromDown() {
    Send("{Down}")
    Send("^c")
    Send("{Up}")
    Send("^v")
}

Xl_FillDown() {
    Send("^d")
}

Xl_FillRight() {
    Send("^r")
}

Xl_Replace() {
    Send("^h")
    Xl_SetMode("insert")
}

Xl_Find() {
    Send("^f")
    Xl_SetMode("insert")
}

Xl_GoTo() {
    Send("{F5}")
    Xl_SetMode("insert")
}

Xl_NextSheet() {
    Send("^{PgDn}")
}

Xl_PrevSheet() {
    Send("^{PgUp}")
}

Xl_InsRowAbove() {
    Send("{AppsKey}")
    Send("i")
    Send("{Enter}")
    Sleep(5)
    Send("r")
    Send("{Enter}")
}

Xl_InsRowBelow() {
    Send("{Down}")
    Send("{AppsKey}")
    Send("i")
    Send("{Enter}")
    Sleep(5)
    Send("r")
    Send("{Enter}")
}

Xl_InsColLeft() {
    Send("{AppsKey}")
    Send("i")
    Send("{Enter}")
    Sleep(5)
    Send("c")
    Send("{Enter}")
}

Xl_InsColRight() {
    Send("{Right}")
    Send("{AppsKey}")
    Send("i")
    Send("{Enter}")
    Sleep(5)
    Send("c")
    Send("{Enter}")
}

Xl_SelRow() {
    Send("+{Space}")
}

Xl_SelCol() {
    Send("^{Space}")
}

Xl_SelAll() {
    Send("^a")
}

Xl_Help() {
    ToolTip("h/j/k/l 移动  H/J/K/L 选择  gg/G 首尾`n"
        . "C-d/u·space 翻页  u 撤销  i/F2 编辑`n"
        . "x 剪切  dd 清除  yy 复制  p 粘贴`n"
        . "yr/yc 整行列复制  Fj/Fl 填充`n"
        . "//R 查找替换  go 跳转  gt/gT 切表`n"
        . "or/oc 插行列(中文界面)  ZZ 存关")
    SetTimer(() => ToolTip(), -4000)
}
