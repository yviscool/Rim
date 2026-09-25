#Requires AutoHotkey v2.0
#Warn All, Off

; === StrokePlus Plugin - 默认手势集 ===
; 以全局手势复用 Rim 既有动作体系 (<Gen_xxx>/<wm_xxx>/key|/run|...),
; 经 VIMD_CMD 统一派发, 无需重复实现功能.
; 真正的手势->动作映射在 Conf\rim.ini [Gestures] 中, 此处只做:
;   1) 若 ini 缺 [Gesture]/[Gestures] 则写入开箱默认值(不覆盖用户已有键)
;   2) 注册手势动作的 Action 说明(供 KeyHelp/帮助体系检索)
;   3) 提供几个手势专属小动作(前进/后退/上下页/音量)

RegisterPlugin_StrokePlus() {
    ; 幂等: vim 通道 + Rim.ahk 直调各一次，重复进入直接返回
    static registered := false
    if (registered)
        return
    registered := true
    global g_Conf, g_ConfFile
    ; 动作说明注册(与 General 插件风格一致, 经 ActionToFuncName 转函数调用)
    RegisterAction("<SP_Back>", T("act.StrokePlus.SP_Back"))
    RegisterAction("<SP_Forward>", T("act.StrokePlus.SP_Forward"))
    RegisterAction("<SP_Up>", T("act.StrokePlus.SP_Up"))
    RegisterAction("<SP_Down>", T("act.StrokePlus.SP_Down"))
    RegisterAction("<SP_Home>", T("act.StrokePlus.SP_Home"))
    RegisterAction("<SP_End>", T("act.StrokePlus.SP_End"))
    RegisterAction("<SP_VolUp>", T("act.StrokePlus.SP_VolUp"))
    RegisterAction("<SP_VolDown>", T("act.StrokePlus.SP_VolDown"))
    RegisterAction("<SP_Mute>", T("act.StrokePlus.SP_Mute"))
    RegisterAction("<SP_CloseTab>", T("act.StrokePlus.SP_CloseTab"))
    RegisterAction("<SP_ReopenTab>", T("act.StrokePlus.SP_ReopenTab"))
    RegisterAction("<SP_NewTab>", T("act.StrokePlus.SP_NewTab"))
    RegisterAction("<SP_Copy>", T("act.StrokePlus.SP_Copy"))
    RegisterAction("<SP_Paste>", T("act.StrokePlus.SP_Paste"))
    RegisterAction("<SP_Cut>", T("act.StrokePlus.SP_Cut"))
    RegisterAction("<SP_PlayPause>", T("act.StrokePlus.SP_PlayPause"))
    RegisterAction("<SP_Next>", T("act.StrokePlus.SP_Next"))
    RegisterAction("<SP_Prev>", T("act.StrokePlus.SP_Prev"))
    RegisterAction("<SP_TaskNext>", T("act.StrokePlus.SP_TaskNext"))
    RegisterAction("<SP_TaskPrev>", T("act.StrokePlus.SP_TaskPrev"))
    Register_GestureDefaults()
}

; ---- 缺键补默认(只增不改, 用户 ini 优先) ----
Register_GestureDefaults() {
    global g_Conf, g_ConfFile, g_GestureMap
    defaultsGesture := Map(
        "Enable", "1",
        "Trigger", "RButton",
        "Threshold", "6",
        "Segment", "6",
        "Poll", "10",
        "CancelDelay", "1500",
        "ShowOSD", "1",
        "NoMatch", "swallow",
        "IgnoreKey", "",
        "VolLatch", "1",
        "OnlyDefinedApps", "0",
        "Trail", "1",
        "TrailColor", "45ABFF",
        "TrailWidth", "5"
    )
    ; 原版 StrokesPlus 默认动作对齐:
    ; 单笔斜线: / Up(右上)=最大化 / Down(左下)=最小化 \ Up(左上)=Alt+F4 \ Down(右下)=Ctrl+W
    ;   Right-Down=打开 Chrome; U=复制 D=粘贴 U_D=刷新
    ; 方向链与形状样本共用手势名称，动作统一在 [Gestures] 或应用层绑定。
    defaultsGestures := Map(
        "L", "key|{Browser_Back}",
        "R", "key|{Browser_Forward}",
        "U", "key|^c",
        "D", "key|^v",
        "UR", "<wm_max>",
        "DL", "<wm_min>",
        "UL", "key|!{F4}",
        "DR", "key|^w",
        "UR_U", "<wm_max>",
        "DR_D", "<wm_min>",
        "UL_U", "key|!{F4}",
        "U_D", "key|{F5}",
        "U_D_U", "<Reload>",
        "D_R", "<SP_NewTab>",
        "D_L", "<SP_CloseTab>",
        "DL_D", "key|^w",
        "L_R", "key|#{Left}",
        "R_L", "key|#{Right}",
        "R_D", "run|D:\software\Chrome\App\Chrome.exe",
        "L_D", "run|explorer.exe",
        "L_U", "<SP_Home>",
        "D_L_D", "<SP_IgnoreNext>",
        "WheelUp", "<SP_TaskPrev>",
        "WheelDown", "<SP_TaskNext>",
        "CTRL+WheelUp", "<SP_VolUp>",
        "CTRL+WheelDown", "<SP_VolDown>"
    )
    changed := false
    append := ""
    hadGesture := false
    hadGestures := false
    try hadGesture := g_Conf.HasSection("Gesture")
    try hadGestures := g_Conf.HasSection("Gestures")
    if (!hadGesture)
        append .= "`r`n[Gesture]`r`n"
    for k, v in defaultsGesture {
        try {
            ; 注意: 空值是合法配置(如 IgnoreKey), 必须用 HasKey 判缺键, 不能用 Get(... )=""
            if (!g_Conf.HasKey("Gesture", k)) {
                g_Conf.AddKey("Gesture", k, v)
                append .= k "=" v "`r`n"
                changed := true
            }
        }
    }
    if (!hadGestures)
        append .= "`r`n[Gestures]`r`n"
    for k, v in defaultsGestures {
        try {
            if (!g_Conf.HasKey("Gestures", k)) {
                g_Conf.AddKey("Gestures", k, v)
                append .= k "=" v "`r`n"
                changed := true
            }
        }
    }
    if (changed) {
        ; 注意: 不得用 g_Conf.Save(), 它重写全文件会吃掉 ini 全部注释;
        ; 缺键只向文件尾追加, 重启后 EasyIni 照常解析(重复键后值覆盖, 值相同无害)
        try FileAppend(append, g_ConfFile, "UTF-8")
        catch {
        }
    }
    ; 同步进内存映射(ini 已有键由 GestureEngine.Init 载入, 这里只补新增)
    for k, v in defaultsGestures {
        nk := GestureRecognizer.NormalizeFull(k)
        try {
            if (!g_GestureMap.Has(nk))
                g_GestureMap[nk] := v
        }
    }
}

; === 手势专属动作实现 (名与 <> 内一致, 经 ActionToFuncName 调用) ===
SP_IgnoreNext() {
    GestureEngine.IgnoreNext()
}
SP_Back() {
    Send("!{Left}")
}

SP_Forward() {
    Send("!{Right}")
}

SP_Up() {
    Send("{PgUp}")
}

SP_Down() {
    Send("{PgDn}")
}

SP_Home() {
    Send("^{Home}")
}

SP_End() {
    Send("^{End}")
}

SP_VolUp() {
    Send("{Volume_Up}")
}

SP_VolDown() {
    Send("{Volume_Down}")
}

SP_Mute() {
    Send("{Volume_Mute}")
}

SP_CloseTab() {
    Send("^w")
}

SP_ReopenTab() {
    Send("^+t")
}

SP_NewTab() {
    Send("^t")
}

SP_Copy() {
    Send("^c")
}

SP_Cut() {
    Send("^x")
}

SP_Paste() {
    Send("^v")
}

SP_PlayPause() {
    Send("{Media_Play_Pause}")
}

SP_Next() {
    Send("{Media_Next}")
}

SP_Prev() {
    Send("{Media_Prev}")
}

; 按住触发键时滚轮前后切换任务栏窗口 (自维护窗口列表按 Z 序循环,
; 含最小化窗口自动还原 —— Alt+Esc 切不到最小化窗口, 故不用它)
SP_TaskNext() {
    SP_TaskSwitch(1)
}

SP_TaskPrev() {
    SP_TaskSwitch(-1)
}

SP_TaskSwitch(dir) {
    global g_Gesture
    static hwnds := []
    static idx := 0
    static lastTick := 0
    ; 1.5 秒内连滚沿用同一列表 (步进一格); 超时或列表空则重建
    if (hwnds.Length = 0 || A_TickCount - lastTick > 1500) {
        hwnds := SP_TaskWindows()
        idx := SP_TaskActiveIndex(hwnds)
    }
    lastTick := A_TickCount
    if (hwnds.Length = 0)
        return
    tried := 0
    while (tried < hwnds.Length && hwnds.Length > 0) {
        idx := Mod(idx + dir + hwnds.Length * 8, hwnds.Length)
        h := hwnds[idx + 1]
        if (SP_TaskActivate(h)) {
            showTip := true
            try showTip := g_Gesture["showOSD"]
            catch {
            }
            if (showTip) {
                try ToolTip(SP_TaskTitle(h))
                catch {
                }
                try SetTimer(SP_TaskHideTip, -800)
                catch {
                }
            }
            return
        }
        ; 窗口已关闭: 剔除; dir>0 时下轮恰好落在补位元素上, 故回退一格抵消步进
        hwnds.RemoveAt(idx + 1)
        if (dir > 0)
            idx := idx - 1
        tried++
    }
}

; 任务栏口径的顶层窗口: 有标题、可见、非托盘/桌面宿主、非子窗口、非 DWM 隐藏
SP_TaskWindows() {
    out := []
    for h in WinGetList() {
        try cls := WinGetClass("ahk_id " . h)
        catch {
            continue
        }
        if (cls = "Progman" || cls = "WorkerW" || cls = "Shell_TrayWnd"
            || cls = "Shell_SecondaryTrayWnd" || cls = "DV2ControlHost")
            continue
        try title := WinGetTitle("ahk_id " . h)
        catch {
            continue
        }
        if (Trim(title) = "")
            continue
        try style := WinGetStyle("ahk_id " . h)
        catch {
            continue
        }
        if (!(style & 0x10000000)) ; WS_VISIBLE (最小化窗口仍保留此位, 会被收录)
            continue
        try exStyle := WinGetExStyle("ahk_id " . h)
        catch {
            exStyle := 0
        }
        if ((exStyle & 0x80) && !(exStyle & 0x40000)) ; 工具窗口且无 APPWINDOW
            continue
        try hasOwner := DllCall("GetWindow", "Ptr", h, "UInt", 4, "Ptr")
        catch {
            hasOwner := 0
        }
        if (hasOwner && !(exStyle & 0x40000))
            continue
        if (SP_TaskCloaked(h))
            continue
        out.Push(h)
    }
    return out
}

SP_TaskCloaked(h) {
    try {
        buf := Buffer(4, 0)
        hr := DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", h, "UInt", 14, "Ptr", buf, "UInt", 4)
        if (hr = 0)
            return NumGet(buf, 0, "UInt") != 0
    }
    return false
}

SP_TaskActiveIndex(hwnds) {
    try active := WinGetID("A")
    catch {
        return 0
    }
    for i, h in hwnds {
        if (h = active)
            return i - 1
    }
    return 0
}

; 还原 (最小化则先 WinRestore, 否则只在任务栏闪) 并激活; 成功 true, 窗口已死 false
SP_TaskActivate(h) {
    w := "ahk_id " . h
    try {
        if (!WinExist(w))
            return false
    } catch {
        return false
    }
    try {
        if (WinGetMinMax(w) = -1)
            WinRestore(w)
    } catch {
    }
    try WinActivate(w)
    catch {
        return false
    }
    return true
}

SP_TaskTitle(h) {
    try title := WinGetTitle("ahk_id " . h)
    catch {
        title := ""
    }
    if (Trim(title) != "")
        return title
    try exe := WinGetProcessName("ahk_id " . h)
    catch {
        exe := ""
    }
    return exe != "" ? exe : "?"
}

SP_TaskHideTip(*) {
    try ToolTip()
    catch {
    }
}
