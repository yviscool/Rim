#Requires AutoHotkey v2.0
#Warn All, Off
; 对话框输入保护探针: Typora 导出 PDF (#32770 另存为) 文件名框里按 o/i 被 vim 吞掉.
; 根因: KeyHandler 只看窗口匹配 (Typora.exe 命中映射), 从不看焦点控件.
; 修法: Engine.ahk DialogShouldPassthrough + KeyHandler 首行守卫 (现取类名, 不吃 50ms 缓存).

T(key, *) => key

#Include ..\Core\Engine.ahk
#Include ..\Core\Context.ahk

fails := []
Check(name, cond) {
    global fails
    if (!cond)
        fails.Push(name)
}

Main() {
    global fails
    ; 文件名框 (Edit / Edit1) 必须透传
    Check("edit", DialogShouldPassthrough("#32770", "Edit", "Edit1"))
    Check("edit-noname", DialogShouldPassthrough("#32770", "Edit", ""))
    ; 组合框/类型下拉 (#32770 专属放宽)
    Check("combo", DialogShouldPassthrough("#32770", "ComboBox", "ComboBox1"))
    Check("comboex", DialogShouldPassthrough("#32770", "ComboBoxEx32", ""))
    ; 非输入控件: 不透传 (窗内映射保留, 如按钮区)
    Check("button", !DialogShouldPassthrough("#32770", "Button", "Button1"))
    Check("list", !DialogShouldPassthrough("#32770", "SysListView32", "SysListView321"))
    Check("empty", !DialogShouldPassthrough("#32770", "", ""))
    ; 非对话框窗: 一律不管 (Notepad 主窗 vim 照常工作, 核心用例不受影响)
    Check("notepad", !DialogShouldPassthrough("Notepad", "Edit", "Edit1"))
    Check("cabinet", !DialogShouldPassthrough("CabinetWClass", "Edit", "Edit1"))
    Check("blank-class", !DialogShouldPassthrough("", "Edit", "Edit1"))
    ; 真 CheckIsInput 路径 (Context 已包含, 非兜底): 对话框 Edit 必须为真
    Check("real-ctx", RimContext.CheckIsInput("Edit", "Edit1", "#32770"))
    ; 接线静态断言: KeyHandler 内守卫存在, 且在该函数 CheckWin 之前
    src := FileRead(A_ScriptDir . "\..\Core\Engine.ahk", "UTF-8")
    khPos := InStr(src, "KeyHandler(thisHotkey)")
    kh := InStr(src, "DialogShouldPassthrough(_dlgCls, _cc, _nn)", false, khPos)
    cw := InStr(src, "winName := this.CheckWin()", false, kh)
    Check("wire-call", khPos > 0 && kh > 0 && cw > 0 && kh < cw)
    Check("wire-func", InStr(src, "DialogShouldPassthrough(winClass, ctrlClass, ctrlNN)") > 0)
    out := A_ScriptDir . "\..\probe_dialog_input.out.txt"
    try FileDelete(out)
    catch {
    }
    if (fails.Length > 0) {
        txt := "dialog-input-FAIL:`n"
        for _, x in fails
            txt .= "  - " . x . "`n"
        FileAppend(txt, out, "UTF-8")
        ExitApp(1)
    }
    FileAppend("dialog-input-ok`n", out, "UTF-8")
    ExitApp(0)
}

Main()
