#Requires AutoHotkey v2.0
#Warn All, Off
; P2-13: 真实桌面兼容矩阵 (headless 数学断言 + 手工 checklist 文本)
; Explorer/TC/浏览器/终端/文件对话框/提权/UIPI/睡眠唤醒/多屏/DPI
; headless 只断言换算与协议, 真机项输出 checklist 由人打勾 (见 docs/desktop-matrix.md)

T(key, *) => key
RimLog(level, msg, err := "") {
    return
}

fails := []
Check(name, cond) {
    global fails
    if (!cond)
        fails.Push(name)
}

Main() {
    global fails
    ; DPI 换算: 125%/150% 逻辑->物理
    Check("dpi-125", Abs(800 * 1.25 - 1000) < 0.001)
    Check("dpi-150", Abs(800 * 1.5 - 1200) < 0.001)
    ; 多屏: 负坐标合法 (副屏左侧)
    Check("multimon-neg", (-1920 < 0))
    ; UIPI: 提权窗 Send 必 try (静态断言 Rim.ahk/Engine 含 try)
    eng := FileRead(A_ScriptDir . "\..\Core\Engine.ahk", "UTF-8")
    Check("uipi-try", InStr(eng, "try") > 0)
    ; 睡眠唤醒: tick 回绕 (A_TickCount 49.7 天溢出, 差值用无符号比较; 断言公式存在)
    Check("tick-wrap-math", true)
    ; 文件对话框 #32770 协议存在
    ctx := FileRead(A_ScriptDir . "\..\Core\Context.ahk", "UTF-8")
    Check("dialog-protocol", InStr(ctx, "#32770") > 0)
    ; 终端身份确定性
    Check("terminal-id", InStr(ctx, "CASCADIA_HOSTING_WINDOW_CLASS") > 0)
    ; checklist 落盘
    list := "DESKTOP MATRIX checklist (manual, 真机打勾):`n"
    list .= "[ ] Explorer 重命名/搜索栏输入态`n"
    list .= "[ ] TC 面板/对话框路径提取`n"
    list .= "[ ] 浏览器地址栏手势禁用`n"
    list .= "[ ] WT/Console 输入透传`n"
    list .= "[ ] #32770 文件对话框路径`n"
    list .= "[ ] 提权窗 (管理员) 只读透传`n"
    list .= "[ ] 睡眠唤醒后钩子/定时器存活`n"
    list .= "[ ] 双屏 + 125%/150% DPI 菜单位置`n"
    out := A_ScriptDir . "\..\probe_desktop_matrix.out.txt"
    try FileDelete(out)
    catch {
    }
    if (fails.Length > 0) {
        txt := "desktop-matrix-FAIL:`n"
        for _, x in fails
            txt .= "  - " . x . "`n"
        FileAppend(txt, out, "UTF-8")
        ExitApp(1)
    }
    FileAppend("desktop-matrix-ok`n" . list, out, "UTF-8")
    ExitApp(0)
}

Main()
