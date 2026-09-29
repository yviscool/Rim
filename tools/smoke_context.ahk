#Requires AutoHotkey v2.0
#Warn All, Off

; 冒烟探针: Context Engine 自动化测试
#Include ..\Core\Context.ahk

Assert(cond, msg) {
    if (!cond) {
        FileAppend("FAIL: " . msg . "`n", "*")
        ExitApp(1)
    }
    FileAppend("PASS: " . msg . "`n", "*")
}

; 1. 结构与默认值
ctx := RimContext()
Assert(IsObject(ctx), "context-obj-created")
Assert(ctx.Hwnd == 0, "default-hwnd-0")
Assert(ctx.AppId == "", "default-appid-empty")

; 2. AppId 映射逻辑
Assert(RimContext.ResolveAppId("explorer.exe", "CabinetWClass") == "explorer", "appid-explorer")
Assert(RimContext.ResolveAppId("totalcmd64.exe", "TTOTAL_CMD") == "totalcommander", "appid-tc")
Assert(RimContext.ResolveAppId("totalcmd.exe", "") == "totalcommander", "appid-tc32")
Assert(RimContext.ResolveAppId("Code.exe", "Chrome_WidgetWin_1") == "vscode", "appid-vscode")
Assert(RimContext.ResolveAppId("wt.exe", "CASCADIA_HOSTING_WINDOW_CLASS") == "terminal", "appid-terminal-wt")
Assert(RimContext.ResolveAppId("cmd.exe", "ConsoleWindowClass") == "terminal", "appid-terminal-con")
Assert(RimContext.ResolveAppId("chrome.exe", "") == "browser", "appid-browser")
Assert(RimContext.ResolveAppId("foobar.exe", "#32770") == "dialog", "appid-dialog")

; 3. 输入控件识别逻辑
Assert(RimContext.CheckIsInput("Edit", "Edit1", "Notepad") == true, "input-edit")
Assert(RimContext.CheckIsInput("RichEdit20W", "RichEdit1", "WordPad") == true, "input-richedit")
Assert(RimContext.CheckIsInput("Scintilla", "Scintilla1", "Notepad++") == true, "input-scintilla")
Assert(RimContext.CheckIsInput("DirectUIHWND", "DirectUIHWND1", "CabinetWClass") == true, "input-explorer-rename")
Assert(RimContext.CheckIsInput("Button", "Button1", "Notepad") == false, "non-input-button")
Assert(RimContext.CheckIsInput("SysListView32", "SysListView321", "CabinetWClass") == false, "non-input-listview")

; 4. Provider v1 协议: Map{capture, canHandle, capabilities}
testDir := "C:\TestFolder"
testFile := "C:\TestFolder\test.txt"
mockProvider(c) {
    c.CurrentDir := testDir
    c.SelectedFile := testFile
    c.SelectedFiles := [testFile]
}
mockCanHandle(c) {
    return c.Class = "CabinetWClass"
}
RimContext.RegisterProvider("mockapp", Map("capture", mockProvider, "canHandle", mockCanHandle,
    "capabilities", Map("current_directory", "mock", "selected_files", "multi")))
Assert(RimContext.Providers.Has("mockapp"), "provider-registered")
Assert(RimContext.CapabilitiesOf("mockapp")["selected_files"] = "multi", "provider-capabilities")
Assert(RimContext.CapabilitiesOf("nosuchapp").Count = 0, "provider-capabilities-miss")

mockCtx := RimContext()
mockCtx.AppId := "mockapp"
mockCtx.Class := "CabinetWClass"
Assert(RimContext.ApplyProvider(mockCtx) == true, "provider-applied")
Assert(mockCtx.CurrentDir == testDir, "provider-current-dir")
Assert(mockCtx.SelectedFile == testFile, "provider-selected-file")
Assert(mockCtx.SelectedFiles.Length == 1, "provider-selected-files-len")

; canHandle 为假跳过 (窗类不对不进 COM), 静默不炸
mockCtx2 := RimContext()
mockCtx2.AppId := "mockapp"
mockCtx2.Class := "Notepad"
Assert(RimContext.ApplyProvider(mockCtx2) == false, "provider-gated")
Assert(mockCtx2.CurrentDir == "", "provider-gated-norun")

; 未注册 AppId / 空 AppId 直接返回 false
mockCtx3 := RimContext()
mockCtx3.AppId := "nope"
Assert(RimContext.ApplyProvider(mockCtx3) == false, "provider-miss")

; 错形注册直接抛 (无旧裸函数形兼容)
threw := false
try RimContext.RegisterProvider("badapp", mockProvider)
catch {
    threw := true
}
Assert(threw == true, "provider-shape-enforced")

; 5. 全局 Capture / GetActiveContext
activeCtx := GetActiveContext()
Assert(IsObject(activeCtx), "active-context-obj")

FileAppend("smoke-context-ok`n", A_ScriptDir . "\..\smoke_context.out.txt")
ExitApp(0)
