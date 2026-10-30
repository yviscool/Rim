#Requires AutoHotkey v2.0
#Warn All, Off

; === Core/Window.ahk - Rim 窗口管理与分屏系统 (Window & Tiling System) ===
; 多显示器工作区感知 (基于 Win32 MonitorFromWindow + rcWork 标定, 避开任务栏)

class RimWindow {
    ; 获取窗口所在的监视器工作区 (基于 Win32 MONITORINFO: cbSize=40, rcWork@20)
    static GetWorkArea(hwnd) {
        hMon := DllCall("MonitorFromWindow", "Ptr", hwnd, "UInt", 2, "Ptr") ; MONITOR_DEFAULTTONEAREST = 2
        if (!hMon)
            return Map("x", 0, "y", 0, "w", SysGet(78), "h", SysGet(79), "hMon", 0)

        mi := Buffer(40, 0)
        NumPut("UInt", 40, mi, 0)
        if (!DllCall("GetMonitorInfoW", "Ptr", hMon, "Ptr", mi))
            return Map("x", 0, "y", 0, "w", SysGet(78), "h", SysGet(79), "hMon", hMon)

        rcLeft := NumGet(mi, 20, "Int")
        rcTop := NumGet(mi, 24, "Int")
        rcRight := NumGet(mi, 28, "Int")
        rcBottom := NumGet(mi, 32, "Int")
        return Map("x", rcLeft, "y", rcTop, "w", rcRight - rcLeft, "h", rcBottom - rcTop, "hMon", hMon)
    }

    ; 前台全屏检测 (StatsBall 等桌面挂件用): 返回 Map 或 ""
    ; 只认"前台"这一路; 同进程窗口/shell/被 DWM 隐藏的窗口一律不算.
    static ForegroundFullscreen() {
        hwnd := DllCall("GetForegroundWindow", "Ptr")
        if (!hwnd)
            return ""
        try {
            if (WinGetPID("ahk_id " . hwnd) = ProcessExist())
                return ""
        } catch {
        }
        return RimWindow.ClassifyFullscreen(hwnd)
    }

    ; 判断指定窗口是否全屏 (不要求它是前台): 供前台检测与探针复用
    ; useQuns 只控制是否顺带查询系统通知状态 (诊断用, 不参与判定)
    static ClassifyFullscreen(hwnd, useQuns := true) {
        if (!hwnd)
            return ""
        cls := ""
        try cls := WinGetClass("ahk_id " . hwnd)
        if (cls = "Progman" || cls = "WorkerW"
            || cls = "Shell_TrayWnd" || cls = "Shell_SecondaryTrayWnd")
            return ""
        ; DWM 隐藏 (UWP 后台 / 其他虚拟桌面)
        cloaked := Buffer(4, 0)
        if (DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", 14
            , "Ptr", cloaked, "UInt", 4) = 0 && NumGet(cloaked, 0, "UInt") != 0)
            return ""
        ; 通知状态只做诊断记录, 不参与判定: QUNS 是全局状态, 无法归属到具体屏幕,
        ; 拿它判定会在"游戏在左屏、用户点右屏"时误藏右屏雷达 (双屏要求按屏独立)
        ; 2=BUSY 3=D3D_FULL_SCREEN 4=PRESENTATION
        quns := 0
        if (useQuns) {
            if (DllCall("shell32\SHQueryUserNotificationState", "Int*", &quns) != 0)
                quns := 0
        }
        rect := Buffer(16, 0)
        if (!DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rect))
            return ""
        wx := NumGet(rect, 0, "Int"), wy := NumGet(rect, 4, "Int")
        wr := NumGet(rect, 8, "Int"), wb := NumGet(rect, 12, "Int")
        hMon := DllCall("MonitorFromWindow", "Ptr", hwnd, "UInt", 2, "Ptr")
        mi := Buffer(40, 0)
        NumPut("UInt", 40, mi, 0)
        if (!DllCall("GetMonitorInfoW", "Ptr", hMon, "Ptr", mi))
            return ""
        ml := NumGet(mi, 4, "Int"), mt := NumGet(mi, 8, "Int")
        mr := NumGet(mi, 12, "Int"), mb := NumGet(mi, 16, "Int")
        ; 带标题栏且最大化的普通窗口只盖工作区, 不算全屏
        style := 0
        try style := WinGetStyle("ahk_id " . hwnd)
        hasCaption := (style & 0x00C00000) = 0x00C00000
        if (hasCaption && DllCall("IsZoomed", "Ptr", hwnd))
            return ""
        if (!RimWindow.RectCoversMonitor(wx, wy, wr, wb, ml, mt, mr, mb, 4))
            return ""
        return Map("hwnd", hwnd, "mon", hMon, "l", ml, "t", mt, "r", mr, "b", mb
            , "quns", quns, "reason", "geometry")
    }

    ; 纯几何: 窗口矩形是否覆盖整个监视器 (rcMonitor, 非 rcWork)
    static RectCoversMonitor(l, t, r, b, ml, mt, mr, mb, tol := 4) {
        return (l <= ml + tol && t <= mt + tol && r >= mr - tol && b >= mb - tol)
    }

    ; 将窗口铺排到工作区特定位置: "left", "right", "top", "bottom", "center", "max"
    static Tile(target := "A", pos := "left") {
        if (IsInteger(target))
            target := "ahk_id " . target
        else if (target = "")
            target := "A"

        prevDHW := A_DetectHiddenWindows
        DetectHiddenWindows(true)
        hwnd := WinExist(target)
        if (!hwnd) {
            DetectHiddenWindows(prevDHW)
            return
        }

        try {
            if (DllCall("IsZoomed", "Ptr", hwnd))
                DllCall("ShowWindow", "Ptr", hwnd, "Int", 9) ; SW_RESTORE = 9
        } catch {
        }

        wa := RimWindow.GetWorkArea(hwnd)
        x := wa["x"], y := wa["y"], w := wa["w"], h := wa["h"]

        try {
            switch pos {
                case "left":
                    DllCall("MoveWindow", "Ptr", hwnd, "Int", x, "Int", y, "Int", w // 2, "Int", h, "Int", 1)
                case "right":
                    DllCall("MoveWindow", "Ptr", hwnd, "Int", x + (w // 2), "Int", y, "Int", w - (w // 2), "Int", h, "Int", 1)
                case "top":
                    DllCall("MoveWindow", "Ptr", hwnd, "Int", x, "Int", y, "Int", w, "Int", h // 2, "Int", 1)
                case "bottom":
                    DllCall("MoveWindow", "Ptr", hwnd, "Int", x, "Int", y + (h // 2), "Int", w, "Int", h - (h // 2), "Int", 1)
                case "center":
                    curW := 0, curH := 0
                    try WinGetPos(, , &curW, &curH, "ahk_id " . hwnd)
                    useW := (curW > 0 && curW < w) ? curW : (w * 3) // 4
                    useH := (curH > 0 && curH < h) ? curH : (h * 3) // 4
                    newX := x + (w - useW) // 2
                    newY := y + (h - useH) // 2
                    DllCall("MoveWindow", "Ptr", hwnd, "Int", newX, "Int", newY, "Int", useW, "Int", useH, "Int", 1)
                case "max":
                    DllCall("ShowWindow", "Ptr", hwnd, "Int", 3) ; SW_MAXIMIZE = 3
            }
        } catch {
        }
        DetectHiddenWindows(prevDHW)
    }

    ; 跨显示器抛掷: 将活动窗口移动至下一个物理监视器
    static MoveToNextMonitor(target := "A") {
        if (IsInteger(target))
            target := "ahk_id " . target
        else if (target = "")
            target := "A"

        prevDHW := A_DetectHiddenWindows
        DetectHiddenWindows(true)
        hwnd := WinExist(target)
        if (!hwnd) {
            DetectHiddenWindows(prevDHW)
            return
        }

        curWa := RimWindow.GetWorkArea(hwnd)
        curX := 0, curY := 0, curW := 0, curH := 0
        try WinGetPos(&curX, &curY, &curW, &curH, "ahk_id " . hwnd)

        monCount := SysGet(80) ; SM_CMONITORS
        if (monCount <= 1) {
            ; 单显示器下快捷对调左右半屏
            if (curX < curWa["x"] + curWa["w"] // 4)
                RimWindow.Tile(hwnd, "right")
            else
                RimWindow.Tile(hwnd, "left")
            DetectHiddenWindows(prevDHW)
            return
        }

        ; 多监视器时按相对比例映射到下一个监视器
        relX := (curX - curWa["x"]) / (curWa["w"] > 0 ? curWa["w"] : 1)
        relY := (curY - curWa["y"]) / (curWa["h"] > 0 ? curWa["h"] : 1)

        probeX := curWa["x"] + curWa["w"] + 50
        hNextMon := DllCall("MonitorFromPoint", "Int64", (curWa["y"] << 32) | (probeX & 0xFFFFFFFF), "UInt", 0, "Ptr")
        if (!hNextMon || hNextMon == curWa["hMon"]) {
            probeX := curWa["x"] - 50
            hNextMon := DllCall("MonitorFromPoint", "Int64", (curWa["y"] << 32) | (probeX & 0xFFFFFFFF), "UInt", 2, "Ptr")
        }

        if (hNextMon) {
            mi := Buffer(40, 0)
            NumPut("UInt", 40, mi, 0)
            if (DllCall("GetMonitorInfoW", "Ptr", hNextMon, "Ptr", mi)) {
                nextL := NumGet(mi, 20, "Int")
                nextT := NumGet(mi, 24, "Int")
                nextW := NumGet(mi, 28, "Int") - nextL
                nextH := NumGet(mi, 32, "Int") - nextT
                targetX := nextL + Integer(relX * nextW)
                targetY := nextT + Integer(relY * nextH)
                useW := curW > 0 ? curW : nextW // 2
                useH := curH > 0 ? curH : nextH // 2
                DllCall("MoveWindow", "Ptr", hwnd, "Int", targetX, "Int", targetY, "Int", useW, "Int", useH, "Int", 1)
            }
        }
        DetectHiddenWindows(prevDHW)
    }
}
