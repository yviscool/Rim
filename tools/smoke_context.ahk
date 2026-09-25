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

; 4. Provider 机制测试
testDir := "C:\TestFolder"
testFile := "C:\TestFolder\test.txt"
mockProvider(c) {
    c.CurrentDir := testDir
    c.SelectedFile := testFile
    c.SelectedFiles := [testFile]
}
RimContext.RegisterProvider("mockapp", mockProvider)
Assert(RimContext.Providers.Has("mockapp"), "provider-registered")

mockCtx := RimContext()
mockCtx.AppId := "mockapp"
RimContext.Providers["mockapp"](mockCtx)
Assert(mockCtx.CurrentDir == testDir, "provider-current-dir")
Assert(mockCtx.SelectedFile == testFile, "provider-selected-file")
Assert(mockCtx.SelectedFiles.Length == 1, "provider-selected-files-len")

; 5. 全局 Capture / GetActiveContext
activeCtx := GetActiveContext()
Assert(IsObject(activeCtx), "active-context-obj")

FileAppend("smoke-context-ok`n", A_ScriptDir . "\..\smoke_context.out.txt")
ExitApp(0)
