#Requires AutoHotkey v2.0
#Warn All, Off
; 输入守卫探针 (P0):
;  P0-2 自家进程守卫: [global] 字母映射劫配置中心/手势UI编辑框 → 活跃 exe 是自身则透传
;  P0-1 IME 组字守卫: 组字中全透传 (提交/取消原生语义), 结束自动恢复.
; headless 盲区 (探针注): 无 IME 时 ImeComposing 恒假, 真机中文组字需手工验.

T(key, *) => key

#Include ..\Core\Engine.ahk

fails := []
Check(name, cond) {
    global fails
    if (!cond)
        fails.Push(name)
}

Main() {
    global fails
    mine := A_IsCompiled ? A_ScriptFullPath : A_AhkPath
    Check("self-true", IsSelfProcessPath(mine))
    Check("self-other", !IsSelfProcessPath("C:\Windows\explorer.exe"))
    Check("self-empty", !IsSelfProcessPath(""))
    Check("ime-false-headless", ImeComposing() = false)
    src := FileRead(A_ScriptDir . "\..\Core\Engine.ahk", "UTF-8")
    khPos := InStr(src, "KeyHandler(thisHotkey)")
    s1 := InStr(src, "IsSelfProcessPath(_selfPath)", false, khPos)
    s2 := InStr(src, "ImeComposing()", false, khPos)
    cw := InStr(src, "winName := this.CheckWin()", false, khPos)
    Check("wire-self", s1 > 0 && cw > 0 && s1 < cw)
    Check("wire-ime", s2 > s1 && s2 < cw)
    ; SwitchToEngIME 开关门 + 英文模式语义 (headless 只做静态断言, 真机手工验):
    ; GUI 初始化必须与 Hotkeys 一致用 = "1" (旧 != "" 把 "0" 也当真, 每次启动强制切布局);
    ; 实现首选关 IME (ImmSetOpenStatus) 而非换布局 (LoadKeyboardLayout 硬编码 KLID 在 Win10/11 缺布局即停美式键盘)
    guiSrc := FileRead(A_ScriptDir . "\..\Core\GUI.ahk", "UTF-8")
    Check("ime-gate", InStr(guiSrc, 'CfgGet("Config", "SwitchToEngIME", "0") = "1"') > 0 && !InStr(guiSrc, 'SwitchToEngIME", "0") != ""'))
    comSrc := FileRead(A_ScriptDir . "\..\Core\Common.ahk", "UTF-8")
    fnPos := InStr(comSrc, "SwitchToEngIME() {")
    immPos := InStr(comSrc, "ImmSetOpenStatus", false, fnPos)
    retPos := InStr(comSrc, "`n                return", false, fnPos)
    layPos := InStr(comSrc, "SwitchIME(0x", false, fnPos)
    Check("ime-imm-first", fnPos > 0 && immPos > fnPos && retPos > immPos && layPos > retPos)
    out := A_ScriptDir . "\..\probe_input_guards.out.txt"
    try FileDelete(out)
    catch {
    }
    if (fails.Length > 0) {
        txt := "input-guards-FAIL:`n"
        for _, x in fails
            txt .= "  - " . x . "`n"
        FileAppend(txt, out, "UTF-8")
        ExitApp(1)
    }
    FileAppend("input-guards-ok`n", out, "UTF-8")
    ExitApp(0)
}

Main()
