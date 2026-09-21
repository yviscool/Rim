#Requires AutoHotkey v2.0
#Warn All, Off

; === LauncherSystem Plugin - 系统管理功能 ===
; Faithful port of RunZ Plugins/System.ahk (v1) to AutoHotkey v2.
; Every v1 Label: is now a same-named function; GoSub -> direct call.
; Results go through DisplayResult; confirmations use MsgBox gates (as original).

RegisterPlugin_LauncherSystem() {
    ; --- Original commands (names preserved from v1 @() registrations) ---
    RegisterCommand("Clip", "function", "Clip", "显示剪切板内容")
    RegisterCommand("ClearClipboardFormat", "function", "ClearClipboardFormat", "清除剪切板中文字的格式")
    RegisterCommand("EmptyRecycle", "function", "EmptyRecycle", "清空回收站")
    RegisterCommand("Logoff", "function", "Logoff", "注销 登出")
    RegisterCommand("RestartMachine", "function", "RestartMachine", "重启")
    RegisterCommand("ShutdownMachine", "function", "ShutdownMachine", "关机")
    RegisterCommand("SuspendMachine", "function", "SuspendMachine", "挂起 睡眠 待机")
    RegisterCommand("HibernateMachine", "function", "HibernateMachine", "休眠")
    RegisterCommand("TurnMonitorOff", "function", "TurnMonitorOff", "关闭显示器")
    RegisterCommand("ListProcess", "function", "ListProcess", "列出进程 ps")
    RegisterCommand("DiskSpace", "function", "DiskSpace", "查看磁盘空间 df")
    RegisterCommand("IncreaseVolume", "function", "IncreaseVolume", "提高音量")
    RegisterCommand("DecreaseVolume", "function", "DecreaseVolume", "降低音量")
    RegisterCommand("SystemState", "function", "SystemState", "系统状态 top")
    RegisterCommand("KillProcess", "function", "KillProcess", "杀死进程")
    RegisterCommand("SendToClip", "function", "SendToClip", "发送到剪切板")
    RegisterCommand("ListWindow", "function", "ListWindow", "窗口列表")
    RegisterCommand("ActivateWindow", "function", "ActivateWindow", "激活窗口")
    RegisterCommand("ListRunningService", "function", "ListRunningService", "列出运行的服务")
    RegisterCommand("ListAllService", "function", "ListAllService", "列出所有的服务")
    RegisterCommand("ShowService", "function", "ShowService", "显示服务详情")
    RegisterCommand("ShowProcess", "function", "ShowProcess", "显示进程详情")

    ; --- Backward-compat aliases (point at the same original funcs) ---
    RegisterCommand("Clipboard", "function", "Clip", "剪切板")
    RegisterCommand("EmptyTrash", "function", "EmptyRecycle", "清空回收站")
    RegisterCommand("Shutdown", "function", "ShutdownMachine", "关机")
    RegisterCommand("Restart", "function", "RestartMachine", "重启")
    RegisterCommand("Suspend", "function", "SuspendMachine", "挂起")
    RegisterCommand("Hibernate", "function", "HibernateMachine", "休眠")
    RegisterCommand("MonitorOff", "function", "TurnMonitorOff", "关闭显示器")
    RegisterCommand("Top", "function", "SystemState", "系统状态")
    RegisterCommand("VolumeUp", "function", "IncreaseVolume", "音量增加")
    RegisterCommand("VolumeDown", "function", "DecreaseVolume", "音量减少")
    RegisterCommand("ProcessList", "function", "ListProcess", "进程列表")
    RegisterCommand("Sleep", "function", "SuspendMachine", "挂起")

    ; --- Pure gain (kept): lock screen + mute toggle ---
    RegisterCommand("Lock", "function", "LockScreen", "锁屏")
    RegisterCommand("VolumeMute", "function", "VolumeMute", "静音")

    ; --- Invented cmd/file shortcuts (kept, all runnable via Run) ---
    RegisterCommand("ControlPanel", "cmd", "control", "控制面板")
    RegisterCommand("DeviceManager", "cmd", "devmgmt.msc", "设备管理器")
    RegisterCommand("TaskManager", "cmd", "taskmgr", "任务管理器")
    RegisterCommand("SystemInfo", "cmd", "msinfo32", "系统信息")
    RegisterCommand("RegEdit", "cmd", "regedit", "注册表编辑器")
    RegisterCommand("Cmd", "cmd", "cmd", "命令提示符")
    RegisterCommand("PowerShell", "cmd", "powershell", "PowerShell")
    RegisterCommand("Notepad", "file", "notepad", "记事本")
    RegisterCommand("Paint", "file", "mspaint", "画图")
    RegisterCommand("WordPad", "file", "write", "写字板")
    RegisterCommand("Magnifier", "file", "magnify", "放大镜")
    RegisterCommand("OnScreenKeyboard", "file", "osk", "屏幕键盘")
    RegisterCommand("SnippingTool", "file", "snippingtool", "截图工具")
    RegisterCommand("ResourceMonitor", "cmd", "resmon", "资源监视器")
    RegisterCommand("PerformanceMonitor", "cmd", "perfmon", "性能监视器")
    RegisterCommand("EventViewer", "cmd", "eventvwr", "事件查看器")
    RegisterCommand("Services", "cmd", "services.msc", "服务")
    RegisterCommand("DiskManagement", "cmd", "diskmgmt.msc", "磁盘管理")
    RegisterCommand("ComputerManagement", "cmd", "compmgmt.msc", "计算机管理")
    RegisterCommand("LocalGroupPolicy", "cmd", "gpedit.msc", "本地组策略")
    RegisterCommand("CertificateManager", "cmd", "certmgr.msc", "证书管理")
    RegisterCommand("DirectX", "cmd", "dxdiag", "DirectX诊断工具")
    RegisterCommand("WindowsUpdate", "cmd", "wuapp", "Windows更新")
    RegisterCommand("Firewall", "cmd", "firewall.cpl", "Windows防火墙")
    RegisterCommand("NetworkConnections", "cmd", "ncpa.cpl", "网络连接")
    RegisterCommand("Sound", "cmd", "mmsys.cpl", "声音设置")
    RegisterCommand("Display", "cmd", "desk.cpl", "显示设置")
    RegisterCommand("System", "cmd", "sysdm.cpl", "系统属性")
    RegisterCommand("Programs", "cmd", "appwiz.cpl", "程序和功能")
    RegisterCommand("PowerOptions", "cmd", "powercfg.cpl", "电源选项")
    RegisterCommand("DateAndTime", "cmd", "timedate.cpl", "日期和时间")
    RegisterCommand("RegionAndLanguage", "cmd", "intl.cpl", "区域和语言")
    RegisterCommand("Mouse", "cmd", "main.cpl", "鼠标属性")
    RegisterCommand("Keyboard", "cmd", "control keyboard", "键盘属性")
    RegisterCommand("Fonts", "cmd", "fonts", "字体")
    RegisterCommand("AdministrativeTools", "cmd", "control admintools", "管理工具")
}

; === Original behavior (same names as v1 labels) ===

Clip() {
    ActivateRunZ()
    DisplayResult("剪切板内容长度 " . StrLen(A_Clipboard) . " ：`n`n" . A_Clipboard)
}

ClearClipboardFormat() {
    A_Clipboard := A_Clipboard
}

Logoff() {
    if (MsgBox("将要注销，是否执行？", , 4) = "Yes") {
        Shutdown(0)
    }
}

ShutdownMachine() {
    if (MsgBox("将要关机，是否执行？", , 4) = "Yes") {
        Shutdown(1)
    }
}

RestartMachine() {
    if (MsgBox("将要重启机器，是否执行？", , 4) = "Yes") {
        Shutdown(2)
    }
}

HibernateMachine() {
    if (MsgBox("将要休眠，是否执行？", , 4) = "Yes") {
        ; 参数 #1: 使用 1 代替 0 来进行休眠而不是挂起。
        ; 参数 #2: 使用 1 代替 0 来立即挂起而不询问每个应用程序以获得许可。
        ; 参数 #3: 使用 1 而不是 0 来禁止所有的唤醒事件。
        DllCall("PowrProf\SetSuspendState", "int", 1, "int", 0, "int", 0)
    }
}

SuspendMachine() {
    if (MsgBox("将要待机，是否执行？", , 4) = "Yes") {
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
    Text := "回收站中共有 " . Items.Count . " 项 （取消可以管理回收站文件）：`n`n"

    Lines := 0
    for F in Items {
        if (Lines >= 30) {
            Text .= "……`n"
            break
        }

        Lines += 1

        Text .= F.Name . " （" . (F.IsFolder == 0 ? F.Size . " 字节）" : "目录）") . "`n"
    }

    if (Lines == 0) {
        DisplayResult("回收站是空的，将自动关闭")
        return
    }

    choice := MsgBox(Text . "`n将要清空回收站，是否执行？", "清空回收站", 3)

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
        result .= "* | 进程 | " . process.Name . " | " . cmd . "`n"
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
        result .= "* | " . drive . " | 总共: " . capGB . " G  可用: " . freeGB . " G | 已用：" . usedGB . "  卷标: " . label . "`n"
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
    result := "* | 状态 | 运行时间 | " . Round(A_TickCount / 1000 / 3600, 3) . " 小时`n"
    result .= "* | 状态 | CPU 占用 | " . CPULoad() . "% `n"
    result .= "* | 状态 | 内存占用 | " . Round(100 * (GMSEx[2] - GMSEx[3]) / GMSEx[2], 2) . "% `n"
    result .= "* | 状态 | 进程总数 | " . GetProcessCount() . "`n"
    result .= "* | 状态 | 内存总量 | " . Round(GMSEx[2] / 1024**2, 2) . "MB `n"
    result .= "* | 状态 | 可用内存 | " . Round(GMSEx[3] / 1024**2, 2) . "MB `n"
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

    DisplayResult("已尝试杀死 " . Arg . " 进程")
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
        result .= "* | 窗口 | " . name . " | " . title . "`n"
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
        result .= "* | 服务 | " . service.Name . " | " . service.DisplayName . "`n"
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
            result .= "* | 服务 | " . service.Name . " | " . service.DisplayName . "`n"
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
        result .= "* | 服务 | 名称 | " . service.Name . "`n"
        result .= "* | 服务 | 描述 | " . service.Description . "`n"
        result .= "* | 服务 | 是否在运行 | " . service.Started . "`n"
        result .= "* | 服务 | 路径 | " . service.PathName . "`n"
        result .= "* | 服务 | 进程 ID | " . service.ProcessId . "`n"
        result .= "* | 服务 | 类型 | " . service.ServiceType . "`n"
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
        result .= "* | 服务 | 名称 | " . process.Name . "`n"
        result .= "* | 服务 | 描述 | " . process.Description . "`n"
        result .= "* | 服务 | 命令行 | " . process.CommandLine . "`n"
        result .= "* | 服务 | 启动时间 | " . process.CreationDate . "`n"
        result .= "* | 服务 | ID | " . process.ProcessId . "`n"
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
