#Requires AutoHotkey v2.0
#Warn All, Off

; === Core/Gesture/Hook.ahk - 低级钩子与零冻结状态保护机 (Zero-Freeze Hook & Capture Guard) ===
; 负责触发键捕获、高频轮询防卡死、单键点击无损重放与输入旁路分发。
; 核心原则:
; 1. 零冻结: 钩子事件回调必须立即返回 (1ms 内)，严禁任何阻塞或网络/磁盘同步调用，防止 Windows 卸载 WH_MOUSE_LL。
; 2. 状态原子化: 按下快照上下文，松开自动清理，短点无损重放。

GestureHook_PollTimer(*) {
    GestureHook.OnPoll()
}

class GestureHook {
    static fnDown := ObjBindMethod(GestureHook, "OnDown")
    static fnUp := ObjBindMethod(GestureHook, "OnUp")
    static fnPoll := GestureHook_PollTimer
    static fnWheelUp := ObjBindMethod(GestureHook, "OnWheelUp")
    static fnWheelDown := ObjBindMethod(GestureHook, "OnWheelDown")
    static fnWheelLeft := ObjBindMethod(GestureHook, "OnWheelLeft")
    static fnWheelRight := ObjBindMethod(GestureHook, "OnWheelRight")
    static fnLeftDown := ObjBindMethod(GestureHook, "OnLeftDown")
    static fnLeftUp := ObjBindMethod(GestureHook, "OnLeftUp")

    ; ---- 触发键绑定 ----
    static Bind(trigger) {
        global g_Gesture
        old := g_Gesture.Has("boundTrigger") ? g_Gesture["boundTrigger"] : ""
        if (old != "" && old != trigger) {
            try Hotkey("$" . old, "Off")
            catch {
            }
            try Hotkey("$" . old . " Up", "Off")
            catch {
            }
        }
        try {
            Hotkey("$" . trigger, GestureHook.fnDown, "On")
            Hotkey("$" . trigger . " Up", GestureHook.fnUp, "On")
            g_Gesture["boundTrigger"] := trigger
            g_Gesture["trigger"] := trigger
        } catch as e {
            return false
        }

        ; 滚轮手势绑定
        try Hotkey("WheelUp", GestureHook.fnWheelUp, "On")
        catch {
        }
        try Hotkey("WheelDown", GestureHook.fnWheelDown, "On")
        catch {
        }
        try Hotkey("WheelLeft", GestureHook.fnWheelLeft, "On")
        catch {
        }
        try Hotkey("WheelRight", GestureHook.fnWheelRight, "On")
        catch {
        }
        return true
    }

    static Unbind() {
        global g_Gesture
        trig := g_Gesture.Has("boundTrigger") ? g_Gesture["boundTrigger"] : ""
        if (trig != "") {
            try Hotkey("$" . trig, "Off")
            catch {
            }
            try Hotkey("$" . trig . " Up", "Off")
            catch {
            }
            g_Gesture["boundTrigger"] := ""
        }
    }

    static ActionWin() {
        global g_Gesture
        try {
            if (g_Gesture["startHwnd"] + 0 && IsObject(g_Gesture["startContext"]))
                return "ahk_id " . (g_Gesture["startHwnd"] + 0)
        }
        return "A"
    }

    static StartIds(&exe, &cls, &title, &ownerCls := "", &ctrlCls := "", &ctrlTitle := "") {
        global g_Gesture
        try {
            ctx := g_Gesture["startContext"]
            if IsObject(ctx) {
                exe := ctx.exe, cls := ctx.cls, title := ctx.title
                ownerCls := ctx.ownerCls, ctrlCls := ctx.ctrlCls, ctrlTitle := ctx.ctrlTitle
                return
            }
        }
        exe := "", cls := "", title := "", ownerCls := "", ctrlCls := "", ctrlTitle := ""
        try exe := WinGetProcessName("A")
        try cls := WinGetClass("A")
        try title := WinGetTitle("A")
    }

    ; ---- 触发键按下: 快速记录起点，进入采样 ----
    static OnDown(*) {
        global g_Gesture
        CoordMode("Mouse", "Screen")
        if (g_Gesture["down"])
            return

        trig := g_Gesture["trigger"]
        MouseGetPos(&sx, &sy)
        ctx := GestureHook.CaptureWindowContext(sx, sy)

        ; 旁路判定 (黑名单、忽略键、自身窗口等)
        if (!g_Gesture["enable"] || GestureHook.IsBypass(true, ctx)) {
            g_Gesture["forwardDown"] := 1
            try Send("{" . trig . " Down}")
            catch {
            }
            return
        }

        g_Gesture["startContext"] := ctx
        g_Gesture["startHwnd"] := ctx.rootHwnd
        g_Gesture["down"] := 1
        g_Gesture["gesturing"] := 0
        g_Gesture["cancelled"] := 0
        g_Gesture["leftCombo"] := 0
        g_Gesture["volMode"] := 0
        g_Gesture["volUsed"] := 0
        g_Gesture["forwardDown"] := 0
        g_Gesture["comboUntil"] := 0
        g_Gesture["startX"] := sx
        g_Gesture["startY"] := sy
        g_Gesture["downTick"] := A_TickCount
        g_Gesture["lastMoveTick"] := A_TickCount
        g_Gesture["points"] := [{x: sx, y: sy}]
        g_Gesture["dirs"] := []
        g_Gesture["gesture"] := ""
        try g_Gesture["downMods"] := GestureRecognizer.ActiveMods()
        catch {
            g_Gesture["downMods"] := ""
        }

        pollInterval := g_Gesture["poll"] > 0 ? g_Gesture["poll"] : 10
        SetTimer(GestureHook_PollTimer, pollInterval)
        ; 右键会话内吞掉左键单击: 点一下左键即锁存音量模式 (R 仍按住时滚轮调音量),
        ; 避免这次左键点透到下层窗口. 会话结束 (R 松开) 时解绑. VolLatch=0 时不启用.
        if (g_Gesture["volLatch"])
            GestureHook.ArmLeftSwallow()
    }

    ; ---- 左键吞掉 (仅右键会话内有效) ----
    static ArmLeftSwallow() {
        try Hotkey("$LButton", GestureHook.fnLeftDown, "On")
        catch {
        }
        try Hotkey("$LButton Up", GestureHook.fnLeftUp, "On")
        catch {
        }
    }

    static DisarmLeftSwallow() {
        try Hotkey("$LButton", "Off")
        catch {
        }
        try Hotkey("$LButton Up", "Off")
        catch {
        }
    }

    ; 右键按住时点一下左键: 锁存音量模式, 本次单击不透传
    static OnLeftDown(*) {
        global g_Gesture
        if (!g_Gesture["down"] || !g_Gesture["volLatch"])
            return
        g_Gesture["leftCombo"] := 1
        if (!g_Gesture["volMode"]) {
            g_Gesture["volMode"] := 1
            ; 进音量模式: 藏掉已画一半的轨迹, 后续轮询不再刷手势 OSD/轨迹, 免得互盖
            try GestureTrail_Hide()
            catch {
            }
            if (g_Gesture["showOSD"]) {
                try ToolTip(T("gesture.vol_ready"))
                catch {
                }
            }
        }
        ; 吞掉: 不做任何透传, 等待 OnLeftUp / 滚轮 / 右键松开
    }

    static OnLeftUp(*) {
        global g_Gesture
        ; 会话内吞掉与 OnLeftDown 配对的松开, 会话外不拦截 (热键已解绑, 正常走不到)
        if (!g_Gesture["down"])
            return
    }

    ; ---- 采样轮询 (防卡死与轨迹跟进) ----
    static OnPoll() {
        global g_Gesture
        if (!g_Gesture["down"])
            return

        CoordMode("Mouse", "Screen")
        ; Esc 取消手势
        try {
            if GetKeyState("Esc", "P") {
                g_Gesture["cancelled"] := 1
                g_Gesture["gesturing"] := 0
                g_Gesture["dirs"] := []
                g_Gesture["gesture"] := ""
                try GestureTrail_Hide()
                catch {
                }
                if (g_Gesture["showOSD"])
                    ToolTip(T("gesture.cancelled"))
                return
            }
        }

        ; 左键组合键监听 (热键吞掉为主, 这里是兜底: 热键漏绑时也能锁存)
        try {
            if GetKeyState("LButton", "P") {
                g_Gesture["leftCombo"] := 1
                if (!g_Gesture["volMode"] && g_Gesture["volLatch"]) {
                    g_Gesture["volMode"] := 1
                    try GestureTrail_Hide()
                    catch {
                    }
                    if (g_Gesture["showOSD"]) {
                        try ToolTip(T("gesture.vol_ready"))
                        catch {
                        }
                    }
                }
            }
        }

        MouseGetPos(&mx, &my)
        pts := g_Gesture["points"]
        last := pts[pts.Length]
        dx0 := mx - last.x
        dy0 := my - last.y

        if (dx0 * dx0 + dy0 * dy0 >= 16) {
            g_Gesture["lastMoveTick"] := A_TickCount
        } else if (g_Gesture["cancelDelay"] > 0 && !g_Gesture["recording"]
            && !g_Gesture["tplRecording"] && !g_Gesture["tryMode"]
            && A_TickCount - g_Gesture["lastMoveTick"] >= g_Gesture["cancelDelay"]
            && !GestureEngine.ComboActive() && !g_Gesture["volMode"]) {
            ; volMode 会话永不回落: 调音量时手难免静止超 CancelDelay,
            ; 一旦 BeginRelay 就会弹出原生右键菜单, 与音量手势打架
            GestureHook.BeginRelay()
            return
        }

        if (dx0 * dx0 + dy0 * dy0 < 16) {
            GestureEngine.PollComboArm()
            return
        }

        pts.Push({x: mx, y: my})
        sx := g_Gesture["startX"]
        sy := g_Gesture["startY"]
        ddx := mx - sx
        ddy := my - sy

        if (!g_Gesture["gesturing"]) {
            if (ddx * ddx + ddy * ddy < g_Gesture["threshold"] * g_Gesture["threshold"])
                return
            g_Gesture["gesturing"] := 1
            g_Gesture["points"] := [{x: sx, y: sy}, {x: mx, y: my}]
            GestureEngine.Recognize()
            g_Gesture["trailX"] := mx
            g_Gesture["trailY"] := my
            if (!g_Gesture["volMode"]) {
                try {
                    GestureTrail_Show()
                    GestureTrail_Line(sx, sy, mx, my)
                } catch {
                }
                if (g_Gesture["showOSD"])
                    GestureEngine.OSD()
            }
            return
        }

        if (!g_Gesture["volMode"]) {
            try GestureTrail_Line(g_Gesture["trailX"], g_Gesture["trailY"], mx, my)
            catch {
            }
        }
        g_Gesture["trailX"] := mx
        g_Gesture["trailY"] := my
        GestureEngine.Recognize()
        if (!g_Gesture["volMode"])
            GestureEngine.PollComboArm()
        if (g_Gesture["showOSD"] && !g_Gesture["volMode"])
            GestureEngine.OSD()
    }

    ; ---- 触发键松开: 结算手势、短点点击重放 ----
    static OnUp(*) {
        global g_Gesture
        CoordMode("Mouse", "Screen")
        try SetTimer(GestureHook_PollTimer, 0)
        catch {
        }
        try {
            GestureHook.OnUpCore()
        } finally {
            GestureHook.ClearStartContext()
        }
    }

    static OnUpCore() {
        global g_Gesture
        trig := g_Gesture["trigger"]
        if (!g_Gesture["down"]) {
            if (g_Gesture["forwardDown"]) {
                try Send("{" . trig . " Up}")
                catch {
                }
                g_Gesture["forwardDown"] := 0
            }
            return
        }

        MouseGetPos(&endX, &endY)
        pts := g_Gesture["points"]
        last := pts[pts.Length]
        dx := endX - last.x, dy := endY - last.y
        if (dx * dx + dy * dy >= 16) {
            pts.Push({x: endX, y: endY})
            sx := g_Gesture["startX"], sy := g_Gesture["startY"]
            if ((endX - sx) ** 2 + (endY - sy) ** 2 >= g_Gesture["threshold"] ** 2)
                g_Gesture["gesturing"] := 1
            if (g_Gesture["gesturing"])
                GestureEngine.Recognize()
        }

        g_Gesture["down"] := 0
        wasGesturing := g_Gesture["gesturing"]
        wasCancelled := g_Gesture["cancelled"]
        gesture := g_Gesture["gesture"]
        leftCombo := g_Gesture["leftCombo"]
        g_Gesture["gesturing"] := 0
        g_Gesture["cancelled"] := 0
        g_Gesture["leftCombo"] := 0

        try ToolTip()
        catch {
        }
        try GestureTrail_Hide()
        catch {
        }

        ; 音量会话 (右键按住期间点过左键且滚过轮): 吞掉, 不回放右键也不派发笔画.
        ; 若只点了左键但没滚轮 (volUsed=0), 则走原逻辑 (L/R+左键切窗口 / 短点回放).
        if (g_Gesture["volUsed"]) {
            g_Gesture["volMode"] := 0
            g_Gesture["volUsed"] := 0
            GestureHook.DisarmLeftSwallow()
            return
        }
        GestureHook.DisarmLeftSwallow()

        if (wasGesturing && !wasCancelled) {
            ; 委托给引擎处理分发
            GestureEngine.DispatchComplete(gesture, pts, leftCombo)
            return
        }

        if (wasCancelled)
            return

        ; 短点: 无位移，重放一次完整原生点击，保留普通右键/中键行为
        GestureHook.SendTriggerClick(trig)
    }

    ; ---- 单击原生重放 ----
    static ClickName(trigger) {
        if (trigger = "MButton")
            return "Middle"
        if (trigger = "XButton1")
            return "X1"
        if (trigger = "XButton2")
            return "X2"
        return "Right"
    }

    static SendTriggerClick(trigger) {
        button := GestureHook.ClickName(trigger)
        try Click(button)
        catch {
            try Send("{" . trigger . "}")
            catch {
            }
        }
    }

    ; ---- 滚轮转发分发 ----
    static OnWheelUp(*) {
        GestureHook.Wheel("WheelUp")
    }
    static OnWheelDown(*) {
        GestureHook.Wheel("WheelDown")
    }
    static OnWheelLeft(*) {
        GestureHook.Wheel("WheelLeft")
    }
    static OnWheelRight(*) {
        GestureHook.Wheel("WheelRight")
    }

    static Wheel(which) {
        GestureEngine.HandleWheel(which)
    }

    ; ---- 轨迹中途旁路转交 (Relay) ----
    static RelayStroke(release := true) {
        global g_Gesture
        CoordMode("Mouse", "Screen")
        pts := g_Gesture["points"]
        if (pts.Length = 0)
            return false
        MouseGetPos(&endX, &endY)
        last := pts[pts.Length]
        if (last.x != endX || last.y != endY)
            pts.Push({x: endX, y: endY})
        trig := g_Gesture["trigger"]
        if (pts.Length < 2 || (pts.Length = 2 && pts[1].x = pts[2].x && pts[1].y = pts[2].y)) {
            if (release)
                GestureHook.SendTriggerClick(trig)
            else {
                try SendEvent("{" . trig . " Down}")
                catch {
                    return false
                }
            }
            return true
        }

        pressed := false
        try {
            Critical("On")
            SetMouseDelay(-1)
            MouseMove(pts[1].x, pts[1].y, 0)
            SendEvent("{" . trig . " Down}")
            pressed := true
            step := Max(1, Ceil((pts.Length - 1) / 200))
            i := 2
            while (i < pts.Length) {
                MouseMove(pts[i].x, pts[i].y, 0)
                i += step
            }
            MouseMove(endX, endY, 0)
            if (release) {
                SendEvent("{" . trig . " Up}")
                pressed := false
            }
            return true
        } catch {
            if (pressed)
                try SendEvent("{" . trig . " Up}")
            return false
        } finally {
            Critical("Off")
        }
    }

    static BeginRelay() {
        global g_Gesture
        try SetTimer(GestureHook_PollTimer, 0)
        catch {
        }
        try GestureTrail_Hide()
        catch {
        }
        try ToolTip()
        catch {
        }
        if (GestureHook.RelayStroke(false)) {
            g_Gesture["down"] := 0
            g_Gesture["gesturing"] := 0
            g_Gesture["forwardDown"] := 1
            GestureHook.ClearStartContext()
        }
    }

    static ClearStartContext() {
        global g_Gesture
        g_Gesture["startHwnd"] := 0
        g_Gesture["startContext"] := ""
        g_Gesture["downMods"] := ""
        g_Gesture["leftCombo"] := 0
        g_Gesture["volMode"] := 0
        g_Gesture["volUsed"] := 0
        g_Gesture["comboUntil"] := 0
        g_Gesture["comboKind"] := ""
        GestureHook.DisarmLeftSwallow()
    }

    ; ---- 窗口上下文捕获 ----
    static CaptureWindowContext(x, y) {
        hit := GestureHook.HwndFromPoint(x, y)
        root := 0
        if (hit) {
            try root := DllCall("GetAncestor", "Ptr", hit, "UInt", 2, "Ptr")
        }
        if (!root)
            root := hit
        ctx := {hitHwnd: hit, rootHwnd: root, exe: "", cls: "", title: "",
            ownerCls: "", ctrlCls: "", ctrlTitle: ""}
        if (!hit)
            return ctx

        try ctx.exe := WinGetProcessName("ahk_id " . root)
        ctx.cls := GestureHook.WindowClass(root)
        ctx.title := GestureHook.WindowText(root)
        ctx.ctrlCls := GestureHook.WindowClass(hit)
        ctx.ctrlTitle := GestureHook.WindowText(hit)

        classes := []
        seen := Map()
        parent := hit
        Loop 16 {
            try parent := DllCall("GetParent", "Ptr", parent, "Ptr")
            catch {
                break
            }
            if (!parent)
                break
            GestureHook.AddContextClass(&classes, &seen, parent)
        }
        owner := root
        Loop 8 {
            try owner := DllCall("GetWindow", "Ptr", owner, "UInt", 4, "Ptr")
            catch {
                break
            }
            if (!owner)
                break
            GestureHook.AddContextClass(&classes, &seen, owner)
        }
        for i, ownerClass in classes
            ctx.ownerCls .= (i > 1 ? "|" : "") . ownerClass
        return ctx
    }

    static HwndFromPoint(x, y) {
        try {
            pt := Buffer(8, 0)
            NumPut("Int", x, pt, 0)
            NumPut("Int", y, pt, 4)
            hwnd := DllCall("WindowFromPoint", "Int64", NumGet(pt, 0, "Int64"), "Ptr")
            return hwnd + 0
        } catch {
            return 0
        }
    }

    static WindowClass(hwnd) {
        if (!hwnd)
            return ""
        try return WinGetClass("ahk_id " . hwnd)
        catch {
            return ""
        }
    }

    static WindowText(hwnd) {
        if (!hwnd)
            return ""
        try {
            textBuf := Buffer(2048, 0)
            DllCall("GetWindowTextW", "Ptr", hwnd, "Ptr", textBuf, "Int", 1024, "Int")
            return StrGet(textBuf, "UTF-16")
        } catch {
            return ""
        }
    }

    static AddContextClass(&classes, &seen, hwnd) {
        cls := GestureHook.WindowClass(hwnd)
        key := StrLower(cls)
        if (cls != "" && !seen.Has(key)) {
            seen[key] := 1
            classes.Push(cls)
        }
    }

    ; ---- 旁路检测 ----
    static IsBypass(consumeNext := true, ctx := "") {
        global g_WindowName, g_Gesture
        try {
            if (IsSet(g_WindowName) && g_WindowName != "" && WinActive(g_WindowName))
                return true
        }
        if (g_Gesture["ignoreNext"]) {
            if (consumeNext)
                g_Gesture["ignoreNext"] := 0
            return true
        }
        try {
            if (g_Gesture["ignoreKey"] != "" && GetKeyState(g_Gesture["ignoreKey"], "P"))
                return true
        }
        if IsObject(ctx) {
            exe := ctx.exe
            cls := ctx.cls
            title := ctx.title
            ownerCls := ctx.ownerCls
            ctrlCls := ctx.ctrlCls
            ctrlTitle := ctx.ctrlTitle
        } else {
            exe := "", cls := "", title := "", ownerCls := "", ctrlCls := "", ctrlTitle := ""
            try exe := WinGetProcessName("A")
            try cls := WinGetClass("A")
            try title := WinGetTitle("A")
        }
        if (GestureEngine.IsBlacklisted(exe, cls, title))
            return true
        if (g_Gesture["onlyDefined"]) {
            app := GestureEngine.MatchApp(exe, cls, title, ownerCls, ctrlCls, ctrlTitle)
            if (!IsObject(app))
                return true
        }
        return false
    }
}
