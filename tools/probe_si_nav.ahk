#Requires AutoHotkey v2.0
#Warn All, Off
; 回归: 搜索列表 Ctrl+J/K (ChangeCommand) 选中后, 回车必须执行选中行, 不能被
; SmartInput 的旧 ghost 全文抢走重搜 (根因: v2 程序设 Edit.Value 不触发 Change,
; ghost 状态不会自清; 实测 Ctrl+J 选 b 回车执行 a).
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_si_nav.ahk

#Include ..\Core\GUI.ahk
#Include ..\Core\SmartInput.ahk
#Include ..\Core\Hotkeys.Commands.ahk

global g_Fail := 0
Ck(name, cond, extra := "") {
    global g_Fail
    if (cond)
        FileAppend("PASS: " . name . "`n", "*")
    else {
        FileAppend("FAIL: " . name . (extra != "" ? " | got=[" . extra . "]" : "") . "`n", "*")
        g_Fail++
    }
}

TypeLabel(type) {
    return type
}

CfgGet(sec, key, def := "") {
    return def
}

global g_SearchCalls := []
SearchCommand(query := "", firstRun := false) {
    global g_SearchCalls
    g_SearchCalls.Push(query)
    return ""
}

global g_RunArg := ""
RunCommand(originCmd) {
    global g_RunArg
    g_RunArg := originCmd
}

; ---- 生产同形最小状态: 真 Edit + 列表 a..e ----
global g_SkinConf := Map("HideCol2", "0", "HideCol4IfEmpty", "1", "DisplayCol3MaxLength", "30"
    , "DisplayCol4MaxLength", "36", "ShowCurrentCommand", "1")
global g_UseDisplay := false
global g_RowActive := false
global g_FirstChar := 97
global g_DisplayRows := 15
global g_UseFallbackCommands := false
global g_MainGui := Gui("+ToolWindow", "SI Nav Probe")
global g_InputEdit := g_MainGui.Add("Edit", "w300")
global g_DisplayEdit := g_MainGui.Add("Edit", "w300 h200 ReadOnly -WantReturn")
global g_CurrentCommandList := ["file | C:\WiseCare365Portable.exe", "file | C:\WiseAutoShutdown.exe"
    , "file | C:\WiseCare365.exe", "file | C:\WiseTray.exe", "file | C:\WiseTurbo.exe"]
global g_CurrentLine := 1
global g_CurrentCommand := g_CurrentCommandList[1]
g_DisplayEdit.Value := "a>| WiseCare365Portable`nb | WiseAutoShutdown`nc | WiseCare365`nd | WiseTray`ne | WiseTurbo"
g_InputEdit.Value := "Wise"

; 模拟打字后 ghost 展开: 输入框被填成全文, 后缀选中 (SI_ShowGhost 的同形状态)
g_SI["ghostFull"] := "WiseCare365Portable"
g_SI["ghostShown"] := true
g_SI["expect"] := "WiseCare365Portable"
g_SI["expectOn"] := true

; ---- 1. Ctrl+J: 选到 b, 输入框回 "@b ", ghost 必须废弃 ----
NextCommand()
Ck("nav-selects-b", g_CurrentCommand = g_CurrentCommandList[2], g_CurrentCommand)
Ck("nav-input-at-b", g_InputEdit.Value = "@b ", g_InputEdit.Value)
Ck("nav-ghost-cleared", !g_SI.Get("ghostShown", false))

; ---- 2. 回车: 执行 b, 不得被旧 ghost 全文重搜顶回 a ----
RunCurrentCommand()
Ck("enter-runs-b", g_RunArg = g_CurrentCommandList[2], g_RunArg)
Ck("enter-no-ghost-search", g_SearchCalls.Length = 0, g_SearchCalls.Length)

; ---- 3. 兜底: 即便 ghost 状态残留, 文本脱节时接受必须 no-op ----
g_SI["ghostFull"] := "WiseCare365Portable"
g_SI["ghostShown"] := true
g_InputEdit.Value := "@c "
global g_RunArg := ""
Ck("stale-ghost-rejected", SI_AcceptGhost() = false)
Ck("stale-ghost-no-search", g_SearchCalls.Length = 0, g_SearchCalls.Length)
RunCurrentCommand()
Ck("enter-runs-current-after-stale", g_RunArg = g_CurrentCommandList[2], g_RunArg)

if (g_Fail > 0) {
    FileAppend("probe-si-nav FAIL: " . g_Fail . "`n", "*")
    ExitApp(1)
}
FileAppend("probe-si-nav-ok`n", "*")
ExitApp(0)
