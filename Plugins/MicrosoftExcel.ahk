#Requires AutoHotkey v2.0

; === MicrosoftExcel Plugin - Excel深度集成 ===
; 完整移植自 VimDesktop 的 MicrosoftExcel 插件
; 支持 COM 接口深度集成

class Plugin_MicrosoftExcel extends Plugin {
    name := "MicrosoftExcel"
    title := T("xl.plugin_title")
    excel := ""

    Setup() {
        ; 注册窗口
        RegisterWin("Excel", "XLMAIN", "EXCEL.EXE")

        ; 注册动作
        ; 基础导航
        RegisterAction("<XL_GoToFirstCell>", T("act.MicrosoftExcel.XL_GoToFirstCell"))
        RegisterAction("<XL_GoToLastCell>", T("act.MicrosoftExcel.XL_GoToLastCell"))
        RegisterAction("<XL_GoToFirstRow>", T("act.MicrosoftExcel.XL_GoToFirstRow"))
        RegisterAction("<XL_GoToLastRow>", T("act.MicrosoftExcel.XL_GoToLastRow"))
        RegisterAction("<XL_GoToFirstCol>", T("act.MicrosoftExcel.XL_GoToFirstCol"))
        RegisterAction("<XL_GoToLastCol>", T("act.MicrosoftExcel.XL_GoToLastCol"))
        RegisterAction("<XL_GoToNextSheet>", T("act.MicrosoftExcel.XL_GoToNextSheet"))
        RegisterAction("<XL_GoToPrevSheet>", T("act.MicrosoftExcel.XL_GoToPrevSheet"))
        RegisterAction("<XL_GoToSheet>", T("act.MicrosoftExcel.XL_GoToSheet"))
        RegisterAction("<XL_GoToNamedRange>", T("act.MicrosoftExcel.XL_GoToNamedRange"))

        ; 选择操作
        RegisterAction("<XL_SelectToFirst>", T("act.MicrosoftExcel.XL_SelectToFirst"))
        RegisterAction("<XL_SelectToLast>", T("act.MicrosoftExcel.XL_SelectToLast"))
        RegisterAction("<XL_SelectToFirstRow>", T("act.MicrosoftExcel.XL_SelectToFirstRow"))
        RegisterAction("<XL_SelectToLastRow>", T("act.MicrosoftExcel.XL_SelectToLastRow"))
        RegisterAction("<XL_SelectToFirstCol>", T("act.MicrosoftExcel.XL_SelectToFirstCol"))
        RegisterAction("<XL_SelectToLastCol>", T("act.MicrosoftExcel.XL_SelectToLastCol"))
        RegisterAction("<XL_SelectRow>", T("act.MicrosoftExcel.XL_SelectRow"))
        RegisterAction("<XL_SelectCol>", T("act.MicrosoftExcel.XL_SelectCol"))
        RegisterAction("<XL_SelectAll>", T("act.MicrosoftExcel.XL_SelectAll"))
        RegisterAction("<XL_SelectRegion>", T("act.MicrosoftExcel.XL_SelectRegion"))

        ; 格式化
        RegisterAction("<XL_Bold>", T("act.MicrosoftExcel.XL_Bold"))
        RegisterAction("<XL_Italic>", T("act.MicrosoftExcel.XL_Italic"))
        RegisterAction("<XL_Underline>", T("act.MicrosoftExcel.XL_Underline"))
        RegisterAction("<XL_Strikethrough>", T("act.MicrosoftExcel.XL_Strikethrough"))
        RegisterAction("<XL_FontColor>", T("act.MicrosoftExcel.XL_FontColor"))
        RegisterAction("<XL_BackgroundColor>", T("act.MicrosoftExcel.XL_BackgroundColor"))
        RegisterAction("<XL_Borders>", T("act.MicrosoftExcel.XL_Borders"))
        RegisterAction("<XL_FontSize>", T("act.MicrosoftExcel.XL_FontSize"))
        RegisterAction("<XL_FontName>", T("act.MicrosoftExcel.XL_FontName"))

        ; 工作表操作
        RegisterAction("<XL_NewSheet>", T("act.MicrosoftExcel.XL_NewSheet"))
        RegisterAction("<XL_DeleteSheet>", T("act.MicrosoftExcel.XL_DeleteSheet"))
        RegisterAction("<XL_RenameSheet>", T("act.MicrosoftExcel.XL_RenameSheet"))
        RegisterAction("<XL_MoveSheet>", T("act.MicrosoftExcel.XL_MoveSheet"))
        RegisterAction("<XL_CopySheet>", T("act.MicrosoftExcel.XL_CopySheet"))

        ; 单元格操作
        RegisterAction("<XL_MergeCells>", T("act.MicrosoftExcel.XL_MergeCells"))
        RegisterAction("<XL_UnmergeCells>", T("act.MicrosoftExcel.XL_UnmergeCells"))
        RegisterAction("<XL_InsertRow>", T("act.MicrosoftExcel.XL_InsertRow"))
        RegisterAction("<XL_InsertCol>", T("act.MicrosoftExcel.XL_InsertCol"))
        RegisterAction("<XL_DeleteRow>", T("act.MicrosoftExcel.XL_DeleteRow"))
        RegisterAction("<XL_DeleteCol>", T("act.MicrosoftExcel.XL_DeleteCol"))
        RegisterAction("<XL_ClearContents>", T("act.MicrosoftExcel.XL_ClearContents"))
        RegisterAction("<XL_ClearAll>", T("act.MicrosoftExcel.XL_ClearAll"))

        ; 文件操作
        RegisterAction("<XL_Save>", T("act.MicrosoftExcel.XL_Save"))
        RegisterAction("<XL_SaveAs>", T("act.MicrosoftExcel.XL_SaveAs"))
        RegisterAction("<XL_Print>", T("act.MicrosoftExcel.XL_Print"))
        RegisterAction("<XL_Preview>", T("act.MicrosoftExcel.XL_Preview"))
        RegisterAction("<XL_Undo>", T("act.MicrosoftExcel.XL_Undo"))
        RegisterAction("<XL_Redo>", T("act.MicrosoftExcel.XL_Redo"))

        ; 其他
        RegisterAction("<XL_AutoFilter>", T("act.MicrosoftExcel.XL_AutoFilter"))
        RegisterAction("<XL_Sort>", T("act.MicrosoftExcel.XL_Sort"))
        RegisterAction("<XL_FindReplace>", T("act.MicrosoftExcel.XL_FindReplace"))
        RegisterAction("<XL_GoTo>", T("act.MicrosoftExcel.XL_GoTo"))
        RegisterAction("<XL_SelectionInfo>", T("act.MicrosoftExcel.XL_SelectionInfo"))
        RegisterAction("<XL_FreezePanes>", T("act.MicrosoftExcel.XL_FreezePanes"))
        RegisterAction("<XL_Split>", T("act.MicrosoftExcel.XL_Split"))

        ; 映射热键
        ; 导航
        MapKey("gg", "<XL_GoToFirstCell>", "Excel", "normal")
        MapKey("G", "<XL_GoToLastCell>", "Excel", "normal")
        MapKey("grh", "<XL_GoToFirstRow>", "Excel", "normal")
        MapKey("gre", "<XL_GoToLastRow>", "Excel", "normal")
        MapKey("gch", "<XL_GoToFirstCol>", "Excel", "normal")
        MapKey("gce", "<XL_GoToLastCol>", "Excel", "normal")
        MapKey("gk", "<XL_GoToNextSheet>", "Excel", "normal")
        MapKey("gj", "<XL_GoToPrevSheet>", "Excel", "normal")
        MapKey("gh", "<XL_GoToSheet>", "Excel", "normal")
        MapKey("gl", "<XL_GoToNamedRange>", "Excel", "normal")

        ; 选择
        MapKey("sk", "<XL_SelectToFirst>", "Excel", "normal")
        MapKey("sj", "<XL_SelectToLast>", "Excel", "normal")
        MapKey("sh", "<XL_SelectToFirstRow>", "Excel", "normal")
        MapKey("sl", "<XL_SelectToLastRow>", "Excel", "normal")
        MapKey("sr", "<XL_SelectRow>", "Excel", "normal")
        MapKey("sc", "<XL_SelectCol>", "Excel", "normal")
        MapKey("sa", "<XL_SelectAll>", "Excel", "normal")
        MapKey("se", "<XL_SelectRegion>", "Excel", "normal")

        ; 格式化
        MapKey("fb", "<XL_Bold>", "Excel", "normal")
        MapKey("fi", "<XL_Italic>", "Excel", "normal")
        MapKey("fu", "<XL_Underline>", "Excel", "normal")
        MapKey("fs", "<XL_Strikethrough>", "Excel", "normal")
        MapKey("fc", "<XL_FontColor>", "Excel", "normal")
        MapKey("fbg", "<XL_BackgroundColor>", "Excel", "normal")
        MapKey("fbo", "<XL_Borders>", "Excel", "normal")
        MapKey("fS", "<XL_FontSize>", "Excel", "normal")
        MapKey("fN", "<XL_FontName>", "Excel", "normal")

        ; 工作表
        MapKey("wn", "<XL_NewSheet>", "Excel", "normal")
        MapKey("wd", "<XL_DeleteSheet>", "Excel", "normal")
        MapKey("wr", "<XL_RenameSheet>", "Excel", "normal")
        MapKey("wm", "<XL_MoveSheet>", "Excel", "normal")
        MapKey("wc", "<XL_CopySheet>", "Excel", "normal")

        ; 单元格操作
        MapKey("cm", "<XL_MergeCells>", "Excel", "normal")
        MapKey("cu", "<XL_UnmergeCells>", "Excel", "normal")
        MapKey("ci", "<XL_InsertRow>", "Excel", "normal")
        MapKey("cI", "<XL_InsertCol>", "Excel", "normal")
        MapKey("cd", "<XL_DeleteRow>", "Excel", "normal")
        MapKey("cD", "<XL_DeleteCol>", "Excel", "normal")
        MapKey("cc", "<XL_ClearContents>", "Excel", "normal")
        MapKey("ca", "<XL_ClearAll>", "Excel", "normal")

        ; 文件操作
        MapKey("<c-s>", "<XL_Save>", "Excel", "normal")
        MapKey("<c-S>", "<XL_SaveAs>", "Excel", "normal")
        MapKey("<c-p>", "<XL_Print>", "Excel", "normal")
        MapKey("<c-P>", "<XL_Preview>", "Excel", "normal")
        MapKey("<c-z>", "<XL_Undo>", "Excel", "normal")
        MapKey("<c-y>", "<XL_Redo>", "Excel", "normal")

        ; 其他
        MapKey("f", "<XL_AutoFilter>", "Excel", "normal")
        MapKey("S", "<XL_Sort>", "Excel", "normal")
        MapKey("/", "<XL_FindReplace>", "Excel", "normal")
        MapKey("<c-g>", "<XL_GoTo>", "Excel", "normal")
        MapKey("i", "<XL_SelectionInfo>", "Excel", "normal")
        MapKey("zF", "<XL_FreezePanes>", "Excel", "normal")
        MapKey("zS", "<XL_Split>", "Excel", "normal")

        ; 模式切换
        MapKey("<Esc>", "<Gen_NormalMode>", "Excel", "insert")
    }

    ; 获取 Excel COM 对象
    GetExcel() {
        try {
            if !IsObject(this.excel) {
                this.excel := ComObject("Excel.Application")
            }
            return this.excel
        }
        return ""
    }

    ; 获取当前工作簿
    GetWorkbook() {
        xl := this.GetExcel()
        if IsObject(xl)
            return xl.ActiveWorkbook
        return ""
    }

    ; 获取当前工作表
    GetWorksheet() {
        wb := this.GetWorkbook()
        if IsObject(wb)
            return wb.ActiveSheet
        return ""
    }

    ; 获取当前选区
    GetSelection() {
        xl := this.GetExcel()
        if IsObject(xl)
            return xl.Selection
        return ""
    }
}

; === Excel 动作函数 ===

; 导航
XL_GoToFirstCell() {
    Send "^{Home}"
}

XL_GoToLastCell() {
    Send "^{End}"
}

XL_GoToFirstRow() {
    Send "^{Home}"
}

XL_GoToLastRow() {
    Send "^{End}"
}

XL_GoToFirstCol() {
    Send "^{Home}"
}

XL_GoToLastCol() {
    Send "^{End}"
}

XL_GoToNextSheet() {
    Send "^{PgDn}"
}

XL_GoToPrevSheet() {
    Send "^{PgUp}"
}

XL_GoToSheet() {
    ; 使用 COM 接口
    try {
        xl := ComObject("Excel.Application")
        wb := xl.ActiveWorkbook
        sheets := []
        for sheet in wb.Sheets
            sheets.Push(sheet.Name)

        ; 显示选择对话框
        result := ""
        for idx, name in sheets
            result .= idx ": " name "`n"

        try {
            ibox := InputBox(result, T("xl.sheet_title"))
            choice := ibox.Value
        } catch {
            return
        }
        if (choice != "") {
            idx := Integer(choice)
            if (idx >= 1 && idx <= sheets.Length)
                wb.Sheets(idx).Activate()
        }
    }
}

XL_GoToNamedRange() {
    Send "^g"  ; 打开定位对话框
}

; 选择
XL_SelectToFirst() {
    Send "+^{Home}"
}

XL_SelectToLast() {
    Send "+^{End}"
}

XL_SelectToFirstRow() {
    Send "+^{Home}"
}

XL_SelectToLastRow() {
    Send "+^{End}"
}

XL_SelectToFirstCol() {
    Send "+^{Home}"
}

XL_SelectToLastCol() {
    Send "+^{End}"
}

XL_SelectRow() {
    Send "^{Space}"
}

XL_SelectCol() {
    Send "^{Space}"
}

XL_SelectAll() {
    Send "^a"
}

XL_SelectRegion() {
    Send "^*"
}

; 格式化
XL_Bold() {
    Send "^b"
}

XL_Italic() {
    Send "^i"
}

XL_Underline() {
    Send "^u"
}

XL_Strikethrough() {
    Send "^5"
}

XL_FontColor() {
    Send "!hfc"  ; 打开字体颜色选择
}

XL_BackgroundColor() {
    Send "!hcb"  ; 打开填充颜色选择
}

XL_Borders() {
    Send "^1"  ; 打开格式化对话框
}

XL_FontSize() {
    try {
        ibox := InputBox(T("xl.fontsize_prompt"), T("xl.fontsize_title"))
        size := ibox.Value
    } catch {
        return
    }
    if (size != "") {
        try {
            xl := ComObject("Excel.Application")
            xl.Selection.Font.Size := Integer(size)
        }
    }
}

XL_FontName() {
    try {
        ibox := InputBox(T("xl.fontname_prompt"), T("xl.fontname_title"))
        name := ibox.Value
    } catch {
        return
    }
    if (name != "") {
        try {
            xl := ComObject("Excel.Application")
            xl.Selection.Font.Name := name
        }
    }
}

; 工作表操作
XL_NewSheet() {
    Send "^{Shift}n"
}

XL_DeleteSheet() {
    Send "!hds"  ; 删除工作表
}

XL_RenameSheet() {
    Send "^{F2}"
}

XL_MoveSheet() {
    Send "!hmm"  ; 移动工作表
}

XL_CopySheet() {
    Send "!hmc"  ; 复制工作表
}

; 单元格操作
XL_MergeCells() {
    Send "^{Shift}&"
}

XL_UnmergeCells() {
    Send "!hmc"  ; 取消合并
}

XL_InsertRow() {
    Send "^+{+}"
}

XL_InsertCol() {
    Send "^+{+}"
}

XL_DeleteRow() {
    Send "^-{Down}"
}

XL_DeleteCol() {
    Send "^-{Right}"
}

XL_ClearContents() {
    Send "{Del}"
}

XL_ClearAll() {
    Send "^a"
    Send "{Del}"
}

; 文件操作
XL_Save() {
    Send "^s"
}

XL_SaveAs() {
    Send "{F12}"
}

XL_Print() {
    Send "^p"
}

XL_Preview() {
    Send "^{F2}"
}

XL_Undo() {
    Send "^z"
}

XL_Redo() {
    Send "^y"
}

; 其他
XL_AutoFilter() {
    Send "^{Shift}l"
}

XL_Sort() {
    Send "!ds"  ; 数据->排序
}

XL_FindReplace() {
    Send "^f"
}

XL_GoTo() {
    Send "^g"
}

XL_SelectionInfo() {
    try {
        xl := ComObject("Excel.Application")
        sel := xl.Selection

        info := T("xl.sel_info") . "`n"
        info .= T("xl.sel_address", sel.Address) . "`n"
        info .= T("xl.sel_rows", sel.Rows.Count) . "`n"
        info .= T("xl.sel_cols", sel.Columns.Count) . "`n"
        info .= T("xl.sel_value", sel.Value) . "`n"

        ToolTip(info)
        SetTimer () => ToolTip(), -3000
    }
}

XL_FreezePanes() {
    Send "!wf"  ; 冻结窗格
}

XL_Split() {
    Send "!ws"  ; 拆分窗口
}
