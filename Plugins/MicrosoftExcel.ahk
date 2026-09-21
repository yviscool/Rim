#Requires AutoHotkey v2.0

; === MicrosoftExcel Plugin - Excel深度集成 ===
; 完整移植自 VimDesktop 的 MicrosoftExcel 插件
; 支持 COM 接口深度集成

class Plugin_MicrosoftExcel extends Plugin {
    name := "MicrosoftExcel"
    title := "Excel深度集成"
    excel := ""

    Setup() {
        ; 注册窗口
        RegisterWin("Excel", "XLMAIN", "EXCEL.EXE")

        ; 注册动作
        ; 基础导航
        RegisterAction("<XL_GoToFirstCell>", "跳转到首个单元格")
        RegisterAction("<XL_GoToLastCell>", "跳转到最后一个单元格")
        RegisterAction("<XL_GoToFirstRow>", "跳转到第一行")
        RegisterAction("<XL_GoToLastRow>", "跳转到最后一行")
        RegisterAction("<XL_GoToFirstCol>", "跳转到第一列")
        RegisterAction("<XL_GoToLastCol>", "跳转到最后一列")
        RegisterAction("<XL_GoToNextSheet>", "下一个工作表")
        RegisterAction("<XL_GoToPrevSheet>", "上一个工作表")
        RegisterAction("<XL_GoToSheet>", "跳转到指定工作表")
        RegisterAction("<XL_GoToNamedRange>", "跳转到命名区域")

        ; 选择操作
        RegisterAction("<XL_SelectToFirst>", "选择到首个单元格")
        RegisterAction("<XL_SelectToLast>", "选择到最后一个单元格")
        RegisterAction("<XL_SelectToFirstRow>", "选择到第一行")
        RegisterAction("<XL_SelectToLastRow>", "选择到最后一行")
        RegisterAction("<XL_SelectToFirstCol>", "选择到第一列")
        RegisterAction("<XL_SelectToLastCol>", "选择到最后一列")
        RegisterAction("<XL_SelectRow>", "选择整行")
        RegisterAction("<XL_SelectCol>", "选择整列")
        RegisterAction("<XL_SelectAll>", "选择全部")
        RegisterAction("<XL_SelectRegion>", "选择当前区域")

        ; 格式化
        RegisterAction("<XL_Bold>", "加粗")
        RegisterAction("<XL_Italic>", "斜体")
        RegisterAction("<XL_Underline>", "下划线")
        RegisterAction("<XL_Strikethrough>", "删除线")
        RegisterAction("<XL_FontColor>", "字体颜色")
        RegisterAction("<XL_BackgroundColor>", "背景颜色")
        RegisterAction("<XL_Borders>", "边框")
        RegisterAction("<XL_FontSize>", "字体大小")
        RegisterAction("<XL_FontName>", "字体名称")

        ; 工作表操作
        RegisterAction("<XL_NewSheet>", "新建工作表")
        RegisterAction("<XL_DeleteSheet>", "删除工作表")
        RegisterAction("<XL_RenameSheet>", "重命名工作表")
        RegisterAction("<XL_MoveSheet>", "移动工作表")
        RegisterAction("<XL_CopySheet>", "复制工作表")

        ; 单元格操作
        RegisterAction("<XL_MergeCells>", "合并单元格")
        RegisterAction("<XL_UnmergeCells>", "取消合并")
        RegisterAction("<XL_InsertRow>", "插入行")
        RegisterAction("<XL_InsertCol>", "插入列")
        RegisterAction("<XL_DeleteRow>", "删除行")
        RegisterAction("<XL_DeleteCol>", "删除列")
        RegisterAction("<XL_ClearContents>", "清除内容")
        RegisterAction("<XL_ClearAll>", "清除全部")

        ; 文件操作
        RegisterAction("<XL_Save>", "保存")
        RegisterAction("<XL_SaveAs>", "另存为")
        RegisterAction("<XL_Print>", "打印")
        RegisterAction("<XL_Preview>", "打印预览")
        RegisterAction("<XL_Undo>", "撤销")
        RegisterAction("<XL_Redo>", "重做")

        ; 其他
        RegisterAction("<XL_AutoFilter>", "自动筛选")
        RegisterAction("<XL_Sort>", "排序")
        RegisterAction("<XL_FindReplace>", "查找替换")
        RegisterAction("<XL_GoTo>", "定位")
        RegisterAction("<XL_SelectionInfo>", "选区信息")
        RegisterAction("<XL_FreezePanes>", "冻结窗格")
        RegisterAction("<XL_Split>", "拆分窗口")

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
            ibox := InputBox(result, "选择工作表")
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
        ibox := InputBox("输入字体大小:", "字体大小")
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
        ibox := InputBox("输入字体名称:", "字体名称")
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

        info := "选区信息:`n"
        info .= "地址: " sel.Address "`n"
        info .= "行数: " sel.Rows.Count "`n"
        info .= "列数: " sel.Columns.Count "`n"
        info .= "值: " sel.Value "`n"

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
