#Requires AutoHotkey v2.0
#Warn All, Off

; 冒烟探针: Workspace Engine 与 Window Tiling 测试
#Include ..\Lib\EasyIni.ahk
#Include ..\Core\I18n.ahk
#Include ..\Core\Context.ahk
#Include ..\Core\Command.ahk
#Include ..\Core\Window.ahk
#Include ..\Core\Workspace.ahk
#Include ..\Core\Execution.ahk

Assert(cond, msg) {
    if (!cond) {
        FileAppend("FAIL: " . msg . "`n", "*")
        ExitApp(1)
    }
    FileAppend("PASS: " . msg . "`n", "*")
}

; 1. 初始化工作空间并验证内置配置
InitUniversalCommands()
InitWorkspaceCommands()

wsList := RimWorkspace.List()
Assert(wsList.Length >= 3, "workspace-list-count")

wsRim := RimWorkspace.Get("rim")
Assert(IsObject(wsRim), "workspace-get-rim")
Assert(wsRim.Editor == "code", "workspace-rim-editor")
Assert(wsRim.TC == true, "workspace-rim-tc")

wsDev := RimWorkspace.Get("dev")
Assert(IsObject(wsDev), "workspace-get-dev")

wsFiles := RimWorkspace.Get("files")
Assert(IsObject(wsFiles), "workspace-get-files")

; 2. 工作空间动态保存与重新读取
saved := RimWorkspace.Save("smoketest", "C:\SmokeTest", "code", "1", "1", "C:\SmokeTest\L", "C:\SmokeTest\R", "Test WS")
Assert(saved == true, "workspace-save-success")

wsTest := RimWorkspace.Get("smoketest")
Assert(IsObject(wsTest), "workspace-get-saved")
Assert(wsTest.Root == "C:\SmokeTest", "workspace-saved-root")
Assert(wsTest.TCLeft == "C:\SmokeTest\L", "workspace-saved-tc-left")
Assert(wsTest.TCRight == "C:\SmokeTest\R", "workspace-saved-tc-right")

deleted := RimWorkspace.Delete("smoketest")
Assert(deleted == true, "workspace-delete-success")
Assert(RimWorkspace.Get("smoketest") == "", "workspace-deleted-gone")

; 3. 语义指令与命令面板集成验证
Assert(RimCommand.Get("workspace.open") != "", "cmd-ws-open-registered")
Assert(RimCommand.Get("workspace.save") != "", "cmd-ws-save-registered")
Assert(RimCommand.Get("workspace.rim") != "", "cmd-ws-rim-registered")
Assert(RimCommand.Get("workspace.dev") != "", "cmd-ws-dev-registered")

wsMatches := RimCommand.Search("workspace")
Assert(wsMatches.Length >= 3, "search-workspace-multi")

; 4. Window Tiling 监视器工作区计算验证 (Win32 API)
try {
    guiProbe := Gui("+ToolWindow", "Rim_Tile_Probe")
    hwnd := guiProbe.Hwnd

    wa := RimWindow.GetWorkArea(hwnd)
    Assert(IsObject(wa), "window-workarea-map")
    Assert(wa["w"] > 0, "window-workarea-w-positive")
    Assert(wa["h"] > 0, "window-workarea-h-positive")

    ; 分屏与重排测试 (基于 Win32 MoveWindow)
    RimWindow.Tile(hwnd, "left")
    RimWindow.Tile(hwnd, "right")
    RimWindow.Tile(hwnd, "center")
    guiProbe.Destroy()
    Assert(true, "window-tile-executed")
} catch Any as e {
    FileAppend("TILE_ERR: " . e.Message . " @ line " . e.Line . "`n", "*")
    Assert(false, "window-tile-no-throw")
}

; 5. 指令面板中的窗口指令
Assert(RimCommand.Get("window.tile_left") != "", "cmd-win-tile-left")
Assert(RimCommand.Get("window.tile_right") != "", "cmd-win-tile-right")
Assert(RimCommand.Get("window.next_monitor") != "", "cmd-win-next-monitor")

winMatches := RimCommand.Search("tile")
Assert(winMatches.Length >= 2, "search-window-tile-multi")

FileAppend("smoke-workspace-ok`n", A_ScriptDir . "\..\smoke_workspace.out.txt")
ExitApp(0)
