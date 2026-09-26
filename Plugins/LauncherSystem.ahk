#Requires AutoHotkey v2.0
#Warn All, Off

; === LauncherSystem Plugin - 系统管理功能 ===
; Faithful port of RunZ Plugins/System.ahk (v1) to AutoHotkey v2.
; Every v1 Label: is now a same-named function; GoSub -> direct call.
; Results go through DisplayResult; confirmations use MsgBox gates (as original).

class LauncherSystemPlugin extends RimPlugin {
    static Name => "LauncherSystem"
    static Title => "System Management Utilities"
    static Description => "系统管理功能 (剪贴板、音量、进程管理、电源与关机)"

    static RegisterCommands() {
    ; --- Original commands (names preserved from v1 @() registrations,直注 RimCommand, 无别名表) ---
    RimCommand.Register("Clip", "Clip", MakeLegacyCmd("Clip"), Map("Category", "System", "Description", T("cmd.LauncherSystem.Clip"), "Keywords", "Clip clipboard"))
    RimCommand.Register("ClearClipboardFormat", "ClearClipboardFormat", MakeLegacyCmd("ClearClipboardFormat"), Map("Category", "System", "Description", T("cmd.LauncherSystem.ClearClipboardFormat"), "Keywords", "ClearClipboardFormat"))
    RimCommand.Register("EmptyRecycle", "EmptyRecycle", MakeLegacyCmd("EmptyRecycle"), Map("Category", "System", "Description", T("cmd.LauncherSystem.EmptyRecycle"), "Keywords", "EmptyRecycle emptytrash"))
    RimCommand.Register("Logoff", "Logoff", MakeLegacyCmd("Logoff"), Map("Category", "System", "Description", T("cmd.LauncherSystem.Logoff"), "Keywords", "Logoff"))
    RimCommand.Register("RestartMachine", "RestartMachine", MakeLegacyCmd("RestartMachine"), Map("Category", "System", "Description", T("cmd.LauncherSystem.RestartMachine"), "Keywords", "RestartMachine restart"))
    RimCommand.Register("ShutdownMachine", "ShutdownMachine", MakeLegacyCmd("ShutdownMachine"), Map("Category", "System", "Description", T("cmd.LauncherSystem.ShutdownMachine"), "Keywords", "ShutdownMachine shutdown"))
    RimCommand.Register("SuspendMachine", "SuspendMachine", MakeLegacyCmd("SuspendMachine"), Map("Category", "System", "Description", T("cmd.LauncherSystem.SuspendMachine"), "Keywords", "SuspendMachine suspend sleep"))
    RimCommand.Register("HibernateMachine", "HibernateMachine", MakeLegacyCmd("HibernateMachine"), Map("Category", "System", "Description", T("cmd.LauncherSystem.HibernateMachine"), "Keywords", "HibernateMachine hibernate"))
    RimCommand.Register("TurnMonitorOff", "TurnMonitorOff", MakeLegacyCmd("TurnMonitorOff"), Map("Category", "System", "Description", T("cmd.LauncherSystem.TurnMonitorOff"), "Keywords", "TurnMonitorOff monitoroff"))
    RimCommand.Register("ListProcess", "ListProcess", MakeLegacyCmd("ListProcess"), Map("Category", "System", "Description", T("cmd.LauncherSystem.ListProcess"), "Keywords", "ListProcess processlist"))
    RimCommand.Register("DiskSpace", "DiskSpace", MakeLegacyCmd("DiskSpace"), Map("Category", "System", "Description", T("cmd.LauncherSystem.DiskSpace"), "Keywords", "DiskSpace"))
    RimCommand.Register("IncreaseVolume", "IncreaseVolume", MakeLegacyCmd("IncreaseVolume"), Map("Category", "System", "Description", T("cmd.LauncherSystem.IncreaseVolume"), "Keywords", "IncreaseVolume volumeup"))
    RimCommand.Register("DecreaseVolume", "DecreaseVolume", MakeLegacyCmd("DecreaseVolume"), Map("Category", "System", "Description", T("cmd.LauncherSystem.DecreaseVolume"), "Keywords", "DecreaseVolume volumedown"))
    RimCommand.Register("SystemState", "SystemState", MakeLegacyCmd("SystemState"), Map("Category", "System", "Description", T("cmd.LauncherSystem.SystemState"), "Keywords", "SystemState top"))
    RimCommand.Register("KillProcess", "KillProcess", MakeLegacyCmd("KillProcess"), Map("Category", "System", "Description", T("cmd.LauncherSystem.KillProcess"), "Keywords", "KillProcess"))
    RimCommand.Register("SendToClip", "SendToClip", MakeLegacyCmd("SendToClip"), Map("Category", "System", "Description", T("cmd.LauncherSystem.SendToClip"), "Keywords", "SendToClip"))
    RimCommand.Register("ListWindow", "ListWindow", MakeLegacyCmd("ListWindow"), Map("Category", "System", "Description", T("cmd.LauncherSystem.ListWindow"), "Keywords", "ListWindow"))
    RimCommand.Register("ActivateWindow", "ActivateWindow", MakeLegacyCmd("ActivateWindow"), Map("Category", "System", "Description", T("cmd.LauncherSystem.ActivateWindow"), "Keywords", "ActivateWindow"))
    RimCommand.Register("ListRunningService", "ListRunningService", MakeLegacyCmd("ListRunningService"), Map("Category", "System", "Description", T("cmd.LauncherSystem.ListRunningService"), "Keywords", "ListRunningService"))
    RimCommand.Register("ListAllService", "ListAllService", MakeLegacyCmd("ListAllService"), Map("Category", "System", "Description", T("cmd.LauncherSystem.ListAllService"), "Keywords", "ListAllService"))
    RimCommand.Register("ShowService", "ShowService", MakeLegacyCmd("ShowService"), Map("Category", "System", "Description", T("cmd.LauncherSystem.ShowService"), "Keywords", "ShowService"))
    RimCommand.Register("ShowProcess", "ShowProcess", MakeLegacyCmd("ShowProcess"), Map("Category", "System", "Description", T("cmd.LauncherSystem.ShowProcess"), "Keywords", "ShowProcess"))

    ; --- 旧 Backward-compat 别名已删 (Clipboard/EmptyTrash/Shutdown/Restart/Suspend/Hibernate/MonitorOff/Top/VolumeUp/VolumeDown/ProcessList/Sleep/CancelTimer), 关键词并入主体 ---

    ; --- Pure gain (kept): lock screen + mute toggle ---
    RimCommand.Register("Lock", "Lock", MakeLegacyCmd("LockScreen"), Map("Category", "System", "Description", T("cmd.LauncherSystem.Lock"), "Keywords", "Lock"))
    RimCommand.Register("VolumeMute", "VolumeMute", MakeLegacyCmd("VolumeMute"), Map("Category", "System", "Description", T("cmd.LauncherSystem.VolumeMute"), "Keywords", "VolumeMute"))

    ; --- 定时关机/重启 (单例: Windows 同一时间只允许一个 pending shutdown) ---
    RimCommand.Register("ShutdownTimer", "ShutdownTimer", MakeLegacyCmd("ShutdownTimer"), Map("Category", "System", "Description", T("cmd.LauncherSystem.ShutdownTimer"), "Keywords", "ShutdownTimer"))
    RimCommand.Register("RestartTimer", "RestartTimer", MakeLegacyCmd("RestartTimer"), Map("Category", "System", "Description", T("cmd.LauncherSystem.RestartTimer"), "Keywords", "RestartTimer"))
    RimCommand.Register("CancelShutdown", "CancelShutdown", MakeLegacyCmd("CancelShutdown"), Map("Category", "System", "Description", T("cmd.LauncherSystem.CancelShutdown"), "Keywords", "CancelShutdown canceltimer"))

    ; --- Invented cmd/file shortcuts (GUI 程序必须用 file，直接 Run；用 cmd 会走 `cmd /C xxx & pause` 多弹一个终端) ---
    ; 注意: control 已由 Core\ControlPanelFunctions.txt 提供 `file | control`，此处不再重复注册，避免和 `cmd | control` 冲突
    RegisterCommand("DeviceManager", "file", "devmgmt.msc", T("cmd.LauncherSystem.DeviceManager"))
    RegisterCommand("TaskManager", "file", "taskmgr", T("cmd.LauncherSystem.TaskManager"))
    RegisterCommand("SystemInfo", "file", "msinfo32", T("cmd.LauncherSystem.SystemInfo"))
    RegisterCommand("RegEdit", "file", "regedit", T("cmd.LauncherSystem.RegEdit"))
    RegisterCommand("Cmd", "file", "cmd", T("cmd.LauncherSystem.Cmd"))
    RegisterCommand("PowerShell", "file", "powershell", "PowerShell")
    RegisterCommand("Notepad", "file", "notepad", T("cmd.LauncherSystem.Notepad"))
    RegisterCommand("Paint", "file", "mspaint", T("cmd.LauncherSystem.Paint"))
    RegisterCommand("WordPad", "file", "write", T("cmd.LauncherSystem.WordPad"))
    RegisterCommand("Magnifier", "file", "magnify", T("cmd.LauncherSystem.Magnifier"))
    RegisterCommand("OnScreenKeyboard", "file", "osk", T("cmd.LauncherSystem.OnScreenKeyboard"))
    RegisterCommand("SnippingTool", "file", "snippingtool", T("cmd.LauncherSystem.SnippingTool"))
    RegisterCommand("ResourceMonitor", "file", "resmon", T("cmd.LauncherSystem.ResourceMonitor"))
    RegisterCommand("PerformanceMonitor", "file", "perfmon", T("cmd.LauncherSystem.PerformanceMonitor"))
    RegisterCommand("EventViewer", "file", "eventvwr", T("cmd.LauncherSystem.EventViewer"))
    RegisterCommand("Services", "file", "services.msc", T("cmd.LauncherSystem.Services"))
    RegisterCommand("DiskManagement", "file", "diskmgmt.msc", T("cmd.LauncherSystem.DiskManagement"))
    RegisterCommand("ComputerManagement", "file", "compmgmt.msc", T("cmd.LauncherSystem.ComputerManagement"))
    RegisterCommand("LocalGroupPolicy", "file", "gpedit.msc", T("cmd.LauncherSystem.LocalGroupPolicy"))
    RegisterCommand("CertificateManager", "file", "certmgr.msc", T("cmd.LauncherSystem.CertificateManager"))
    RegisterCommand("DirectX", "file", "dxdiag", T("cmd.LauncherSystem.DirectX"))
    RegisterCommand("WindowsUpdate", "file", "wuapp", T("cmd.LauncherSystem.WindowsUpdate"))
    RegisterCommand("Firewall", "file", "firewall.cpl", T("cmd.LauncherSystem.Firewall"))
    RegisterCommand("NetworkConnections", "file", "ncpa.cpl", T("cmd.LauncherSystem.NetworkConnections"))
    RegisterCommand("Sound", "file", "mmsys.cpl", T("cmd.LauncherSystem.Sound"))
    RegisterCommand("Display", "file", "desk.cpl", T("cmd.LauncherSystem.Display"))
    RegisterCommand("System", "file", "sysdm.cpl", T("cmd.LauncherSystem.System"))
    RegisterCommand("Programs", "file", "appwiz.cpl", T("cmd.LauncherSystem.Programs"))
    RegisterCommand("PowerOptions", "file", "powercfg.cpl", T("cmd.LauncherSystem.PowerOptions"))
    RegisterCommand("DateAndTime", "file", "timedate.cpl", T("cmd.LauncherSystem.DateAndTime"))
    RegisterCommand("RegionAndLanguage", "file", "intl.cpl", T("cmd.LauncherSystem.RegionAndLanguage"))
    RegisterCommand("Mouse", "file", "main.cpl", T("cmd.LauncherSystem.Mouse"))
    RegisterCommand("Keyboard", "file", "control keyboard", T("cmd.LauncherSystem.Keyboard"))
    RegisterCommand("Fonts", "file", "control fonts", T("cmd.LauncherSystem.Fonts"))
    RegisterCommand("AdministrativeTools", "file", "control admintools", T("cmd.LauncherSystem.AdministrativeTools"))
}

}

if (IsSet(RimPluginManager) && IsObject(RimPluginManager))
    RimPluginManager.Register(LauncherSystemPlugin)



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
    global g_Arg
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
    DisplayResult(FilterResult(AlignText(result), g_Arg))
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
    global g_Arg
    args := StrSplit(g_Arg, " ")
    for _, argument in args {
        argument := Trim(argument)
        if (argument = "")
            continue
        ProcessClose(argument)
    }

    DisplayResult(T("sys.killed", g_Arg))
}

SendToClip() {
    global g_Arg
    A_Clipboard := g_Arg
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
    global g_Arg, FullPipeArg
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
        for _, argument in StrSplit(g_Arg, " ") {
            argument := Trim(argument)
            if (argument = "")
                continue
            WinActivate("ahk_exe " . argument)
        }
    }
}

ListAllService() {
    global g_Arg
    result := ""
    for service in ComObjGet("winmgmts:").ExecQuery("select * from Win32_Service") {
        result .= "* | " . T("sys.row_service") . " | " . service.Name . " | " . service.DisplayName . "`n"
    }
    result := Sort(result)

    SetCommandFilter("CountNumber|ShowService")
    DisplayResult(FilterResult(AlignText(result), g_Arg))
    TurnOnResultFilter()
}

ListRunningService() {
    global g_Arg
    result := ""
    for service in ComObjGet("winmgmts:").ExecQuery("select * from Win32_Service") {
        if (service.Started != 0) {
            result .= "* | " . T("sys.row_service") . " | " . service.Name . " | " . service.DisplayName . "`n"
        }
    }
    result := Sort(result)

    SetCommandFilter("CountNumber|ShowService")
    DisplayResult(FilterResult(AlignText(result), g_Arg))
    TurnOnResultFilter()
}

ShowService() {
    global g_Arg
    result := ""
    parts := StrSplit(Trim(g_Arg), " ")
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
    global g_Arg
    result := ""
    parts := StrSplit(Trim(g_Arg), " ")
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

; === 定时关机/重启 (单例倒计时) ===
; 参数只读 g_Arg (不读剪切板/InputBox, 防误设):
;   空            → 查状态
;   cancel/off/取消 → 取消
;   纯数字        → 分钟 (30 = 30分钟, 最常用)
;   数字+s/m/h    → 秒/分/时, 可组合 (90s / 45m / 2h / 1h30m)
;   中文单位      → 30分钟 / 2小时 / 半小时
;   HH:MM         → 今天/明天最近的该时刻 (22:30)
; 机制: ≤600秒走 shutdown.exe /t (系统级, Rim退出不丢, 自带toast);
;       >600秒走 schtasks 一次性任务 (分钟精度, 同样系统级).
; 显示: 右下角迷你窗每秒更新 + 取消按钮; 无参调用查状态.

global g_ShutdownTimerKind := ""
global g_ShutdownTimerTarget := 0
global g_ShutdownTimerGui := ""
global g_ShutdownTimerText := ""
global g_ShutdownTimerCancel := ""
global g_ShutdownTimerDeadline := ""
global g_ShutdownTimerShadows := []

ShutdownTimer() {
    global g_Arg
    ShutdownTimer_Impl("shutdown", Trim(g_Arg))
}

RestartTimer() {
    global g_Arg
    ShutdownTimer_Impl("restart", Trim(g_Arg))
}

CancelShutdown(*) {
    ShutdownTimer_CancelSilent()
    ShutdownTimer_ClearState()
    DisplayResult(T("sys.timer_cancelled"))
}

ShutdownTimer_Impl(kind, input) {
    parsed := ShutdownTimer_Parse(input)
    if (parsed = -3) {
        ShutdownTimer_Status()
        return
    }
    if (parsed = -2) {
        CancelShutdown()
        return
    }
    if (parsed < 0) {
        DisplayResult(T("sys.timer_invalid", input) . "`n" . T("sys.timer_usage"))
        return
    }
    ShutdownTimer_Set(kind, parsed)
}

; 返回: >=0 秒数; -1 非法; -2 取消; -3 查状态
ShutdownTimer_Parse(input) {
    s := Trim(input)
    if (s = "")
        return -3
    low := StrLower(s)
    if (low = "cancel" || low = "off" || low = "c" || low = "stop" || s = "取消")
        return -2
    if (low = "status" || s = "状态")
        return -3
    if (s = "半小时")
        return 1800
    if (s = "半分钟")
        return 30
    ; HH:MM 时刻 (已过则算明天, 30秒内也算明天防立即触发)
    if RegExMatch(s, "^(\d{1,2}):(\d{2})$", &mt) {
        hh := mt[1] + 0
        mm := mt[2] + 0
        if (hh > 23 || mm > 59)
            return -1
        todayStamp := SubStr(A_Now, 1, 8) . Format("{:02}{:02}00", hh, mm)
        delta := DateDiff(todayStamp, A_Now, "Seconds")
        if (delta <= 30)
            delta += 86400
        if (delta > 604800)
            return -1
        return delta
    }
    ; 中文单位归一 (先长后短, 防 "分钟" 被 "分" 切半)
    t := StrReplace(s, " ", "")
    t := StrReplace(t, "小时", "h")
    t := StrReplace(t, "分钟", "m")
    t := StrReplace(t, "时", "h")
    t := StrReplace(t, "分", "m")
    t := StrReplace(t, "钟", "")
    t := StrReplace(t, "秒", "s")
    t := StrLower(t)
    if (InStr(t, "半"))
        return -1
    ; 纯数字 = 分钟 (最人性化的默认)
    if RegExMatch(t, "^\d+$") {
        total := t + 0
        total := total * 60
        return ShutdownTimer_Clamp(total)
    }
    ; 组合: 1h30m / 90s / 2h / 45m (必须全带单位, "1h30" 非法)
    if RegExMatch(t, "^((\d+(?:\.\d+)?)h)?((\d+(?:\.\d+)?)m)?((\d+(?:\.\d+)?)s)?$", &mt) {
        if (mt[0] = "")
            return -1
        total := 0
        if (mt[2] != "")
            total += mt[2] * 3600
        if (mt[4] != "")
            total += mt[4] * 60
        if (mt[6] != "")
            total += mt[6]
        return ShutdownTimer_Clamp(Round(total))
    }
    return -1
}

ShutdownTimer_Clamp(total) {
    if (total < 30 || total > 604800)
        return -1
    return total
}

ShutdownTimer_Set(kind, seconds) {
    global g_ShutdownTimerKind, g_ShutdownTimerTarget, g_ShutdownTimerDeadline
    ; 单例: Windows 不允许两个 pending, 先静默清旧的
    hadOld := (g_ShutdownTimerKind != "" && g_ShutdownTimerTarget > 0)
    ShutdownTimer_CancelSilent()
    target := A_TickCount + seconds * 1000
    if (seconds <= 600) {
        flag := (kind = "restart") ? "/r" : "/s"
        code := 1
        try code := RunWait("shutdown " . flag . " /t " . seconds, , "Hide")
        catch {
            code := 1
        }
        if (code != 0) {
            ; 旧系统计时残留 (如 Rim 重启前设的) 占着 1190, /a 后重试一次
            try RunWait("shutdown /a", , "Hide")
            catch {
            }
            try code := RunWait("shutdown " . flag . " /t " . seconds, , "Hide")
            catch {
                code := 1
            }
        }
        if (code != 0) {
            DisplayResult(T("sys.timer_set_fail", code))
            return
        }
        mech := T("sys.timer_mech_sys")
    } else {
        ; schtasks (分钟精度; 实测结论, 见 schtasks /create /?):
        ;   当天 → ONCE 不带 /SD (/ST 取未来分钟, 必为将来时刻);
        ;   跨天 → DAILY + /SD=X + /ED=X+1天 + /Z, 跑完自删
        ;   (/SD 禁用于 ONCE; /ED 不能等于 /SD 当天零点会越界; /Z 强制要求 EndBoundary)
        aimStamp := DateAdd(A_Now, seconds, "Seconds")
        st := FormatTime(aimStamp, "HH:mm")
        tr := (kind = "restart") ? "shutdown /r" : "shutdown /s"
        if (SubStr(aimStamp, 1, 8) = SubStr(A_Now, 1, 8)) {
            cmd := 'schtasks /create /tn "RimShutdownTimer" /sc once /st ' . st . ' /tr "' . tr . '" /f'
        } else {
            sd := FormatTime(aimStamp, "yyyy/MM/dd")
            ed := FormatTime(DateAdd(aimStamp, 1, "Days"), "yyyy/MM/dd")
            cmd := 'schtasks /create /tn "RimShutdownTimer" /sc daily /sd ' . sd . ' /ed ' . ed . ' /st ' . st . ' /tr "' . tr . '" /f /z'
        }
        ret := ShutdownTimer_SchCreate(cmd)
        if (ret[1] != 0) {
            DisplayResult(T("sys.timer_set_fail", ret[1]) . "`n" . ret[2])
            return
        }
        mech := T("sys.timer_mech_task")
    }
    g_ShutdownTimerKind := kind
    g_ShutdownTimerTarget := target
    clock := FormatTime(DateAdd(A_Now, seconds, "Seconds"), "HH:mm:ss")
    kindLabel := T(kind = "restart" ? "sys.timer_kind_restart" : "sys.timer_kind_shutdown")
    g_ShutdownTimerDeadline := clock . " " . kindLabel
    ShutdownTimer_ShowCountdown()
    msg := T("sys.timer_set", kindLabel, mech)
    msg .= "`n" . AlignText(ShutdownTimer_Report(seconds, clock))
    if (hadOld)
        msg .= "`n" . T("sys.timer_replaced")
    DisplayResult(msg)
}

; 三行表格回显 (走 AlignText 对齐): 剩余 / 执行时刻 / 取消方式
ShutdownTimer_Report(remain, clock) {
    rows := "* | " . T("sys.timer_row_left") . " | " . ShutdownTimer_Fmt(remain)
    rows .= "`n* | " . T("sys.timer_row_at") . " | " . clock
    rows .= "`n* | " . T("sys.timer_row_cancel") . " | " . T("sys.timer_cancel_how")
    return rows
}

ShutdownTimer_Status() {
    global g_ShutdownTimerKind, g_ShutdownTimerTarget
    if (g_ShutdownTimerKind = "" || g_ShutdownTimerTarget <= 0) {
        DisplayResult(T("sys.timer_none") . "`n" . T("sys.timer_usage"))
        return
    }
    remain := Round((g_ShutdownTimerTarget - A_TickCount) / 1000)
    if (remain <= 0) {
        ShutdownTimer_ClearState()
        DisplayResult(T("sys.timer_none") . "`n" . T("sys.timer_usage"))
        return
    }
    clock := FormatTime(DateAdd(A_Now, remain, "Seconds"), "HH:mm:ss")
    kindLabel := T(g_ShutdownTimerKind = "restart" ? "sys.timer_kind_restart" : "sys.timer_kind_shutdown")
    DisplayResult(T("sys.timer_status_head", kindLabel) . "`n" . AlignText(ShutdownTimer_Report(remain, clock)))
}

; 静默双清 (不碰内存状态以外的东西, 失败全吞)
ShutdownTimer_CancelSilent() {
    try RunWait("shutdown /a", , "Hide")
    catch {
    }
    try RunWait('schtasks /delete /tn "RimShutdownTimer" /f', , "Hide")
    catch {
    }
}

; 只清内存状态 + 停 tick + 关迷你窗 (不碰系统计时)
ShutdownTimer_ClearState() {
    global g_ShutdownTimerKind, g_ShutdownTimerTarget, g_ShutdownTimerDeadline
    g_ShutdownTimerKind := ""
    g_ShutdownTimerTarget := 0
    g_ShutdownTimerDeadline := ""
    ShutdownTimer_HideGui()
}

; 只停 tick + 关迷你窗 (保留 kind/target, 供 ShowCountdown 复用旧状态)
ShutdownTimer_HideGui() {
    global g_ShutdownTimerGui, g_ShutdownTimerText, g_ShutdownTimerCancel, g_ShutdownTimerShadows
    g_ShutdownTimerShadows := []
    try SetTimer(ShutdownTimer_Tick, 0)
    catch {
    }
    try OnMessage(0x201, ShutdownTimer_DragStep, 0)
    catch {
    }
    try {
        if (IsObject(g_ShutdownTimerGui))
            g_ShutdownTimerGui.Destroy()
    } catch {
    }
    g_ShutdownTimerGui := ""
    g_ShutdownTimerText := ""
    g_ShutdownTimerCancel := ""
}

; PNG 风: 底色纯黑 + TransColor 抠掉背景, 只剩文字像素;
; 三行: 大数字倒计时 / 截止时刻小字 / "✕ 取消"文字链. 顶部居中.
; 每行套阴影字 (描边 202020: 纯黑会被 TransColor 抠掉, 不能用),
; 背景抠掉后文字直接浮在桌面内容上, 无描边浅色字在浅壁纸下不可读.
ShutdownTimer_ShowCountdown() {
    global g_ShutdownTimerGui, g_ShutdownTimerText, g_ShutdownTimerCancel, g_ShutdownTimerDeadline
    ShutdownTimer_HideGui()
    cntGui := Gui("+AlwaysOnTop +ToolWindow -Caption", "RimShutdownTimer")
    cntGui.BackColor := "000000"
    g_ShutdownTimerText := ShutdownTimer_ShadowLabel(cntGui, 2, "", "S26 Bold", "FFFFFF", true)
    ShutdownTimer_ShadowLabel(cntGui, 50, g_ShutdownTimerDeadline, "S11", "DDDDDD")
    g_ShutdownTimerCancel := ShutdownTimer_ShadowLabel(cntGui, 72, "✕ " . T("sys.timer_cancel_btn"), "S11", "BBBBBB")
    g_ShutdownTimerCancel.OnEvent("Click", ShutdownTimer_GuiCancel)
    left := 0
    top := 0
    right := A_ScreenWidth
    bottom := A_ScreenHeight
    try MonitorGetWorkArea(1, &left, &top, &right, &bottom)
    catch {
    }
    cntGui.Show("x" . ((left + right - 220) // 2) . " y" . (top + 12) . " w220 h104 NoActivate")
    ; 注意: TransColor 与 WinSetTransparent 互斥, 此处只要前者
    try WinSetTransColor("000000", "ahk_id " . cntGui.Hwnd)
    catch {
    }
    g_ShutdownTimerGui := cntGui
    ; 拖动: -Caption 窗靠 WM_NCLBUTTONDOWN(HTCAPTION) 进系统移动循环;
    ; 进程级 0x201 只认自家数字文本 ("✕ 取消"排除, 否则 Click 被移动循环吞掉),
    ; 迷你窗关闭时卸载, 与 StatsBall 的 0x201 监听共存 (各认各的 Hwnd)
    try OnMessage(0x201, ShutdownTimer_DragStep)
    catch {
    }
    ShutdownTimer_Tick()
    SetTimer(ShutdownTimer_Tick, 1000)
}

ShutdownTimer_DragStep(wParam, lParam, msg, hwnd) {
    global g_ShutdownTimerGui, g_ShutdownTimerCancel
    try {
        if (!IsObject(g_ShutdownTimerGui))
            return
        ghwnd := g_ShutdownTimerGui.Hwnd
        ; 只拖数字文本: "✕ 取消" 按下即进移动循环会吞掉它的 Click, 必须排除
        if (IsObject(g_ShutdownTimerCancel) && hwnd = g_ShutdownTimerCancel.Hwnd)
            return
        if (WinGetClass("ahk_id " . hwnd) != "Static")
            return
        ctrl := GuiCtrlFromHwnd(hwnd)
        if (!IsObject(ctrl) || ctrl.Gui.Hwnd != ghwnd)
            return
        PostMessage(0xA1, 2, , , "ahk_id " . ghwnd)
    } catch {
    }
}

; 阴影字: 先铺 8 向 202020 描边打底, 主字最后放 (最上层);
; track=true 时描边进 g_ShutdownTimerShadows, Tick 里跟主字一起刷.
; 注意坐标全用绝对值: 选项串里 "x-1" 会被当成相对定位, 故基准 x10 宽 200 写死.
ShutdownTimer_ShadowLabel(cntGui, y, text, fontOpts, mainColor, track := false) {
    global g_ShutdownTimerShadows
    if (track)
        g_ShutdownTimerShadows := []
    cntGui.SetFont("c202020 " . fontOpts, "微软雅黑")
    for off in [[9, 1], [11, 1], [9, 3], [11, 3], [9, 2], [11, 2], [10, 1], [10, 3]] {
        c := cntGui.Add("Text", "x" . off[1] . " y" . (y + off[2]) . " w200 Center BackgroundTrans", text)
        if (track)
            g_ShutdownTimerShadows.Push(c)
    }
    cntGui.SetFont("c" . mainColor . " " . fontOpts, "微软雅黑")
    return cntGui.Add("Text", "x10 y" . (y + 2) . " w200 Center BackgroundTrans", text)
}

ShutdownTimer_Tick(*) {
    global g_ShutdownTimerText, g_ShutdownTimerShadows, g_ShutdownTimerTarget
    remain := 0
    if (g_ShutdownTimerTarget > 0)
        remain := Round((g_ShutdownTimerTarget - A_TickCount) / 1000)
    if (remain <= 0) {
        ; 到点系统接管 (shutdown.exe/schtasks 执行), 只收迷你窗
        ShutdownTimer_ClearState()
        return
    }
    ; 主字 + 描边一起刷 (取消/截止行是静态的, 建窗一次写死)
    val := ShutdownTimer_Fmt(remain)
    try {
        if (IsObject(g_ShutdownTimerText))
            g_ShutdownTimerText.Value := val
        for sh in g_ShutdownTimerShadows {
            if (IsObject(sh))
                sh.Value := val
        }
    } catch {
    }
}

ShutdownTimer_GuiCancel(*) {
    CancelShutdown()
}

; 跑 schtasks 类命令并拿回合并输出 (返回 [exitCode, output])
; 经 bat 中转: schtasks 报错走 stderr, 直接 RunWait 拿不到文本;
; 且 /TR 值自带引号, 拼进 cmd /C 行内引号 fragile, 放 bat 里最稳.
; (bat 全 ASCII, 默认 ANSI 写读即可, 与系统编码一致)
ShutdownTimer_SchCreate(cmd) {
    batFile := A_Temp . "\RimSchTask.bat"
    tmpOut := A_Temp . "\RimSchTask.log"
    try FileDelete(batFile)
    catch {
    }
    try FileDelete(tmpOut)
    catch {
    }
    try FileAppend("@echo off`r`n" . cmd . "`r`n", batFile)
    catch {
        return [1, ""]
    }
    code := 1
    try code := RunWait(A_ComSpec . ' /C "' . batFile . ' > "' . tmpOut . '" 2>&1"', , "Hide")
    catch {
        code := 1
    }
    out := ""
    try out := Trim(FileRead(tmpOut))
    catch {
    }
    try FileDelete(batFile)
    catch {
    }
    try FileDelete(tmpOut)
    catch {
    }
    return [code, out]
}

ShutdownTimer_Fmt(totalSeconds) {
    hh := Floor(totalSeconds / 3600)
    mm := Floor(Mod(totalSeconds, 3600) / 60)
    ss := Mod(totalSeconds, 60)
    if (hh > 0)
        return Format("{:02}:{:02}:{:02}", hh, mm, ss)
    return Format("{:02}:{:02}", mm, ss)
}
