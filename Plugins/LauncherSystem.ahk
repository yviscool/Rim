#Requires AutoHotkey v2.0
#Warn All, Off

; === LauncherSystem Plugin - 系统管理功能 ===
; Faithful port of RunZ Plugins/System.ahk (v1) to AutoHotkey v2.
; Every v1 Label: is now a same-named function; GoSub -> direct call.
; Results go through DisplayResult; confirmations use MsgBox gates (as original).

RegisterPlugin_LauncherSystem() {
    ; --- Original commands (names preserved from v1 @() registrations) ---
    RegisterCommand("Clip", "function", "Clip", T("cmd.LauncherSystem.Clip"))
    RegisterCommand("ClearClipboardFormat", "function", "ClearClipboardFormat", T("cmd.LauncherSystem.ClearClipboardFormat"))
    RegisterCommand("EmptyRecycle", "function", "EmptyRecycle", T("cmd.LauncherSystem.EmptyRecycle"))
    RegisterCommand("Logoff", "function", "Logoff", T("cmd.LauncherSystem.Logoff"))
    RegisterCommand("RestartMachine", "function", "RestartMachine", T("cmd.LauncherSystem.RestartMachine"))
    RegisterCommand("ShutdownMachine", "function", "ShutdownMachine", T("cmd.LauncherSystem.ShutdownMachine"))
    RegisterCommand("SuspendMachine", "function", "SuspendMachine", T("cmd.LauncherSystem.SuspendMachine"))
    RegisterCommand("HibernateMachine", "function", "HibernateMachine", T("cmd.LauncherSystem.HibernateMachine"))
    RegisterCommand("TurnMonitorOff", "function", "TurnMonitorOff", T("cmd.LauncherSystem.TurnMonitorOff"))
    RegisterCommand("ListProcess", "function", "ListProcess", T("cmd.LauncherSystem.ListProcess"))
    RegisterCommand("DiskSpace", "function", "DiskSpace", T("cmd.LauncherSystem.DiskSpace"))
    RegisterCommand("IncreaseVolume", "function", "IncreaseVolume", T("cmd.LauncherSystem.IncreaseVolume"))
    RegisterCommand("DecreaseVolume", "function", "DecreaseVolume", T("cmd.LauncherSystem.DecreaseVolume"))
    RegisterCommand("SystemState", "function", "SystemState", T("cmd.LauncherSystem.SystemState"))
    RegisterCommand("KillProcess", "function", "KillProcess", T("cmd.LauncherSystem.KillProcess"))
    RegisterCommand("SendToClip", "function", "SendToClip", T("cmd.LauncherSystem.SendToClip"))
    RegisterCommand("ListWindow", "function", "ListWindow", T("cmd.LauncherSystem.ListWindow"))
    RegisterCommand("ActivateWindow", "function", "ActivateWindow", T("cmd.LauncherSystem.ActivateWindow"))
    RegisterCommand("ListRunningService", "function", "ListRunningService", T("cmd.LauncherSystem.ListRunningService"))
    RegisterCommand("ListAllService", "function", "ListAllService", T("cmd.LauncherSystem.ListAllService"))
    RegisterCommand("ShowService", "function", "ShowService", T("cmd.LauncherSystem.ShowService"))
    RegisterCommand("ShowProcess", "function", "ShowProcess", T("cmd.LauncherSystem.ShowProcess"))

    ; --- Backward-compat aliases (point at the same original funcs) ---
    RegisterCommand("Clipboard", "function", "Clip", T("cmd.LauncherSystem.Clipboard"))
    RegisterCommand("EmptyTrash", "function", "EmptyRecycle", T("cmd.LauncherSystem.EmptyRecycle"))
    RegisterCommand("Shutdown", "function", "ShutdownMachine", T("cmd.LauncherSystem.ShutdownMachine"))
    RegisterCommand("Restart", "function", "RestartMachine", T("cmd.LauncherSystem.RestartMachine"))
    RegisterCommand("Suspend", "function", "SuspendMachine", T("cmd.LauncherSystem.Suspend"))
    RegisterCommand("Hibernate", "function", "HibernateMachine", T("cmd.LauncherSystem.HibernateMachine"))
    RegisterCommand("MonitorOff", "function", "TurnMonitorOff", T("cmd.LauncherSystem.TurnMonitorOff"))
    RegisterCommand("Top", "function", "SystemState", T("cmd.LauncherSystem.Top"))
    RegisterCommand("VolumeUp", "function", "IncreaseVolume", T("cmd.LauncherSystem.VolumeUp"))
    RegisterCommand("VolumeDown", "function", "DecreaseVolume", T("cmd.LauncherSystem.VolumeDown"))
    RegisterCommand("ProcessList", "function", "ListProcess", T("cmd.LauncherSystem.ProcessList"))
    RegisterCommand("Sleep", "function", "SuspendMachine", T("cmd.LauncherSystem.Suspend"))

    ; --- Pure gain (kept): lock screen + mute toggle ---
    RegisterCommand("Lock", "function", "LockScreen", T("cmd.LauncherSystem.Lock"))
    RegisterCommand("VolumeMute", "function", "VolumeMute", T("cmd.LauncherSystem.VolumeMute"))

    ; --- Invented cmd/file shortcuts (kept, all runnable via Run) ---
    RegisterCommand("ControlPanel", "cmd", "control", T("cmd.LauncherSystem.ControlPanel"))
    RegisterCommand("DeviceManager", "cmd", "devmgmt.msc", T("cmd.LauncherSystem.DeviceManager"))
    RegisterCommand("TaskManager", "cmd", "taskmgr", T("cmd.LauncherSystem.TaskManager"))
    RegisterCommand("SystemInfo", "cmd", "msinfo32", T("cmd.LauncherSystem.SystemInfo"))
    RegisterCommand("RegEdit", "cmd", "regedit", T("cmd.LauncherSystem.RegEdit"))
    RegisterCommand("Cmd", "cmd", "cmd", T("cmd.LauncherSystem.Cmd"))
    RegisterCommand("PowerShell", "cmd", "powershell", "PowerShell")
    RegisterCommand("Notepad", "file", "notepad", T("cmd.LauncherSystem.Notepad"))
    RegisterCommand("Paint", "file", "mspaint", T("cmd.LauncherSystem.Paint"))
    RegisterCommand("WordPad", "file", "write", T("cmd.LauncherSystem.WordPad"))
    RegisterCommand("Magnifier", "file", "magnify", T("cmd.LauncherSystem.Magnifier"))
    RegisterCommand("OnScreenKeyboard", "file", "osk", T("cmd.LauncherSystem.OnScreenKeyboard"))
    RegisterCommand("SnippingTool", "file", "snippingtool", T("cmd.LauncherSystem.SnippingTool"))
    RegisterCommand("ResourceMonitor", "cmd", "resmon", T("cmd.LauncherSystem.ResourceMonitor"))
    RegisterCommand("PerformanceMonitor", "cmd", "perfmon", T("cmd.LauncherSystem.PerformanceMonitor"))
    RegisterCommand("EventViewer", "cmd", "eventvwr", T("cmd.LauncherSystem.EventViewer"))
    RegisterCommand("Services", "cmd", "services.msc", T("cmd.LauncherSystem.Services"))
    RegisterCommand("DiskManagement", "cmd", "diskmgmt.msc", T("cmd.LauncherSystem.DiskManagement"))
    RegisterCommand("ComputerManagement", "cmd", "compmgmt.msc", T("cmd.LauncherSystem.ComputerManagement"))
    RegisterCommand("LocalGroupPolicy", "cmd", "gpedit.msc", T("cmd.LauncherSystem.LocalGroupPolicy"))
    RegisterCommand("CertificateManager", "cmd", "certmgr.msc", T("cmd.LauncherSystem.CertificateManager"))
    RegisterCommand("DirectX", "cmd", "dxdiag", T("cmd.LauncherSystem.DirectX"))
    RegisterCommand("WindowsUpdate", "cmd", "wuapp", T("cmd.LauncherSystem.WindowsUpdate"))
    RegisterCommand("Firewall", "cmd", "firewall.cpl", T("cmd.LauncherSystem.Firewall"))
    RegisterCommand("NetworkConnections", "cmd", "ncpa.cpl", T("cmd.LauncherSystem.NetworkConnections"))
    RegisterCommand("Sound", "cmd", "mmsys.cpl", T("cmd.LauncherSystem.Sound"))
    RegisterCommand("Display", "cmd", "desk.cpl", T("cmd.LauncherSystem.Display"))
    RegisterCommand("System", "cmd", "sysdm.cpl", T("cmd.LauncherSystem.System"))
    RegisterCommand("Programs", "cmd", "appwiz.cpl", T("cmd.LauncherSystem.Programs"))
    RegisterCommand("PowerOptions", "cmd", "powercfg.cpl", T("cmd.LauncherSystem.PowerOptions"))
    RegisterCommand("DateAndTime", "cmd", "timedate.cpl", T("cmd.LauncherSystem.DateAndTime"))
    RegisterCommand("RegionAndLanguage", "cmd", "intl.cpl", T("cmd.LauncherSystem.RegionAndLanguage"))
    RegisterCommand("Mouse", "cmd", "main.cpl", T("cmd.LauncherSystem.Mouse"))
    RegisterCommand("Keyboard", "cmd", "control keyboard", T("cmd.LauncherSystem.Keyboard"))
    RegisterCommand("Fonts", "cmd", "fonts", T("cmd.LauncherSystem.Fonts"))
    RegisterCommand("AdministrativeTools", "cmd", "control admintools", T("cmd.LauncherSystem.AdministrativeTools"))
}

; === Original behavior (same names as v1 labels) ===

Clip() {
    ActivateRunZ()
    DisplayResult(T("sys.clip_len", StrLen(A_Clipboard)) . "`n`n" . A_Clipboard)
}

ClearClipboardFormat() {
    A_Clipboard := A_Clipboard
}

Logoff() {
    if (MsgBox(T("sys.confirm_logoff"), , 4) = "Yes") {
        Shutdown(0)
    }
}

ShutdownMachine() {
    if (MsgBox(T("sys.confirm_shutdown"), , 4) = "Yes") {
        Shutdown(1)
    }
}

RestartMachine() {
    if (MsgBox(T("sys.confirm_restart"), , 4) = "Yes") {
        Shutdown(2)
    }
}

HibernateMachine() {
    if (MsgBox(T("sys.confirm_hibernate"), , 4) = "Yes") {
        ; 参数 #1: 使用 1 代替 0 来进行休眠而不是挂起。
        ; 参数 #2: 使用 1 代替 0 来立即挂起而不询问每个应用程序以获得许可。
        ; 参数 #3: 使用 1 而不是 0 来禁止所有的唤醒事件。
        DllCall("PowrProf\SetSuspendState", "int", 1, "int", 0, "int", 0)
    }
}

SuspendMachine() {
    if (MsgBox(T("sys.confirm_suspend"), , 4) = "Yes") {
        DllCall("PowrProf\SetSuspendState", "int", 0, "int", 0, "int", 0)
    }
}

TurnMonitorOff() {
    ; 关闭显示器:
    Sleep(200)
    SendMessage(0x112, 0xF170, 2, , "Program Manager")
    ; 0x112 is WM_SYSCOMMAND, 0xF170 is SC_MONITORPOWER.
    ; 对上面命令的注释: 使用 -1 代替 2 来打开显示器.
    ; 使用 1 代替 2 来激活显示器的节能模式.
}

EmptyRecycle() {
    Items := ComObjCreate("Shell.Application").Namespace(10).Items()
    Text := T("sys.recycle_count", Items.Count) . "`n`n"

    Lines := 0
    for F in Items {
        if (Lines >= 30) {
            Text .= "……`n"
            break
        }

        Lines += 1

        Text .= F.Name . (F.IsFolder == 0 ? T("sys.recycle_size_paren", F.Size) : T("sys.recycle_dir_paren")) . "`n"
    }

    if (Lines == 0) {
        DisplayResult(T("sys.recycle_empty"))
        return
    }

    choice := MsgBox(Text . "`n" . T("sys.recycle_confirm"), T("sys.recycle_title"), 3)

    if (choice = "Yes") {
        FileRecycleEmpty()
        return
    }

    if (choice = "Cancel") {
        Run('explorer.exe ::{645ff040-5081-101b-9f08-00aa002f954e}')
    }
}

ListProcess() {
    global Arg
    result := ""

    for process in ComObjGet("winmgmts:").ExecQuery("select * from Win32_Process") {
        cmd := ""
        try {
            cmd := process.CommandLine
        } catch {
            cmd := ""
        }
        result .= "* | " . T("sys.row_process") . " | " . process.Name . " | " . cmd . "`n"
    }
    result := Sort(result)

    SetCommandFilter("KillProcess|ShowProcess|CountNumber")
    DisplayResult(FilterResult(AlignText(result), Arg))
    TurnOnResultFilter()
}

DiskSpace() {
    result := ""

    driveList := DriveGetList()
    Loop Parse, driveList {
        drive := A_LoopField . ":"
        label := DriveGetLabel(drive)
        cap := DriveGetCapacity(drive)
        free := DriveGetSpaceFree(drive)
        used := cap - free
        capGB := Round(cap / 1024, 2)
        freeGB := Round(free / 1024, 2)
        usedGB := Round(used / 1024, 2)
        result .= "* | " . drive . " | " . T("sys.row_disk", capGB, freeGB) . " | " . T("sys.disk_used", usedGB, label) . "`n"
    }

    DisplayResult(AlignText(result))
}

IncreaseVolume() {
    SoundSetVolume("+5")
}

DecreaseVolume() {
    SoundSetVolume("-5")
}

SystemState() {
    if (!SetExecInterval(1)) {
        return
    }

    GMSEx := GlobalMemoryStatusEx()
    result := "* | " . T("sys.row_state") . " | " . T("sys.uptime") . " | " . Round(A_TickCount / 1000 / 3600, 3) . " " . T("sys.hours") . "`n"
    result .= "* | " . T("sys.row_state") . " | " . T("sys.cpu") . " | " . CPULoad() . "% `n"
    result .= "* | " . T("sys.row_state") . " | " . T("sys.mem") . " | " . Round(100 * (GMSEx[2] - GMSEx[3]) / GMSEx[2], 2) . "% `n"
    result .= "* | " . T("sys.row_state") . " | " . T("sys.procs") . " | " . GetProcessCount() . "`n"
    result .= "* | " . T("sys.row_state") . " | " . T("sys.mem_total") . " | " . Round(GMSEx[2] / 1024**2, 2) . "MB `n"
    result .= "* | " . T("sys.row_state") . " | " . T("sys.mem_free") . " | " . Round(GMSEx[3] / 1024**2, 2) . "MB `n"
    DisplayResult(AlignText(result))
}

KillProcess() {
    global Arg
    args := StrSplit(Arg, " ")
    for _, argument in args {
        argument := Trim(argument)
        if (argument = "")
            continue
        ProcessClose(argument)
    }

    DisplayResult(T("sys.killed", Arg))
}

SendToClip() {
    global Arg
    A_Clipboard := Arg
    Clip()
}

ListWindow() {
    result := ""

    ids := WinGetList(, , , "Program Manager")
    for thisId in ids {
        title := WinGetTitle("ahk_id " . thisId)
        name := WinGetProcessName("ahk_id " . thisId)
        if (title = "") {
            continue
        }
        result .= "* | " . T("sys.row_window") . " | " . name . " | " . title . "`n"
    }

    SetCommandFilter("ActivateWindow|KillProcess")
    DisplayResult(AlignText(result))
    TurnOnResultFilter()
}

ActivateWindow() {
    global Arg, FullPipeArg
    DisplayResult()
    ClearInput()

    if (FullPipeArg != "") {
        Loop Parse, FullPipeArg, "`n", "`r" {
            if (A_LoopField = "") {
                return
            }
            splitedLine := StrSplit(A_LoopField, " | ")
            if (splitedLine.Length < 4)
                continue
            WinActivate(Trim(splitedLine[4]))
        }
    } else {
        for _, argument in StrSplit(Arg, " ") {
            argument := Trim(argument)
            if (argument = "")
                continue
            WinActivate("ahk_exe " . argument)
        }
    }
}

ListAllService() {
    global Arg
    result := ""
    for service in ComObjGet("winmgmts:").ExecQuery("select * from Win32_Service") {
        result .= "* | " . T("sys.row_service") . " | " . service.Name . " | " . service.DisplayName . "`n"
    }
    result := Sort(result)

    SetCommandFilter("CountNumber|ShowService")
    DisplayResult(FilterResult(AlignText(result), Arg))
    TurnOnResultFilter()
}

ListRunningService() {
    global Arg
    result := ""
    for service in ComObjGet("winmgmts:").ExecQuery("select * from Win32_Service") {
        if (service.Started != 0) {
            result .= "* | " . T("sys.row_service") . " | " . service.Name . " | " . service.DisplayName . "`n"
        }
    }
    result := Sort(result)

    SetCommandFilter("CountNumber|ShowService")
    DisplayResult(FilterResult(AlignText(result), Arg))
    TurnOnResultFilter()
}

ShowService() {
    global Arg
    result := ""
    parts := StrSplit(Trim(Arg), " ")
    first := parts.Length >= 1 ? parts[1] : ""
    ; 暂时只支持一个，选得多了查起来太慢
    for service in ComObjGet("winmgmts:").ExecQuery("select * from Win32_Service where Name = '" . first . "'") {
        ; https://msdn.microsoft.com/en-us/library/windows/desktop/aa394418%28v=vs.85%29.aspx
        result .= "* | " . T("sys.row_service") . " | " . T("sys.svc_name") . " | " . service.Name . "`n"
        result .= "* | " . T("sys.row_service") . " | " . T("sys.svc_desc") . " | " . service.Description . "`n"
        result .= "* | " . T("sys.row_service") . " | " . T("sys.svc_running") . " | " . service.Started . "`n"
        result .= "* | " . T("sys.row_service") . " | " . T("sys.svc_path") . " | " . service.PathName . "`n"
        result .= "* | " . T("sys.row_service") . " | " . T("sys.svc_pid") . " | " . service.ProcessId . "`n"
        result .= "* | " . T("sys.row_service") . " | " . T("sys.svc_type") . " | " . service.ServiceType . "`n"
        break
    }

    DisplayResult(AlignText(result))
}

ShowProcess() {
    global Arg
    result := ""
    parts := StrSplit(Trim(Arg), " ")
    first := parts.Length >= 1 ? parts[1] : ""
    ; 暂时只支持一个，选得多了查起来太慢
    for process in ComObjGet("winmgmts:").ExecQuery("select * from Win32_Process where Name = '" . first . "'") {
        ; https://msdn.microsoft.com/en-us/library/windows/desktop/aa394372%28v=vs.85%29.aspx
        result .= "* | " . T("sys.row_service") . " | " . T("sys.svc_name") . " | " . process.Name . "`n"
        result .= "* | " . T("sys.row_service") . " | " . T("sys.svc_desc") . " | " . process.Description . "`n"
        result .= "* | " . T("sys.row_service") . " | " . T("sys.proc_cmd") . " | " . process.CommandLine . "`n"
        result .= "* | " . T("sys.row_service") . " | " . T("sys.proc_start") . " | " . process.CreationDate . "`n"
        result .= "* | " . T("sys.row_service") . " | " . T("sys.proc_id") . " | " . process.ProcessId . "`n"
        break
    }

    DisplayResult(AlignText(result))
}

; === Kept gain: lock + mute ===

LockScreen() {
    DllCall("LockWorkStation")
}

VolumeMute() {
    SoundSetMute(-1)
}
