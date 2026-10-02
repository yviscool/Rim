#Requires AutoHotkey v2.0
#Warn All, Off

; === StatsBall 插件 - 桌面三段雷达 (CPU / 内存 / 网速横条) ===
; 架构: 采样层(零WMI) + 条Gui(拖拽/贴边/三色) + 悬停闪电 + 加速面板
; 性能: 单一定时器 + 脏检查 + 定长 hist(60) + 面板按需取Top进程
; 注意: 注册期不建 Gui (冒烟探针 headless), 一律懒创建
; 子模块: StatsBall.Sample / StatsBall.Render (纯函数); 对象 StatsBallObj 留本文件

#Include StatsBall.Sample.ahk
#Include StatsBall.Render.ahk

global g_StatsBall := ""

; ---------- 注册 (Hybrid: 命令经 RegisterCommands 直注, 不建窗; 幂等由 Registry 保证) ----------
class StatsBallPlugin extends RimPlugin {
    static Name => "StatsBall"
    static Title => "Desktop Radar"
    static Description => "桌面三段雷达 (CPU/内存/网速)"

    static RegisterCommands() {
        RimCommand.Register("StatsBall", "StatsBall", MakeLegacyCmd("StatsBall_Toggle"), Map("Category", "Tool", "Description", T("cmd.StatsBall.StatsBall"), "Keywords", "StatsBall"))
        RimCommand.Register("StatsBallBoost", "StatsBallBoost", MakeLegacyCmd("StatsBall_Boost"), Map("Category", "Tool", "Description", T("cmd.StatsBall.Boost"), "Keywords", "StatsBallBoost"))
    }

    ; 热应用订阅 ([StatsBall] 段 live 档; 回调只做读配置→改对象, 禁阻塞)
    static Init() {
        for _, sbKey in ["Enable", "RefreshMs", "StripW", "StripH", "Opacity", "TopMost", "LockPos", "SnapEdge", "AlertThreshold"] {
            try CfgSubscribe("StatsBall", sbKey, (*) => StatsBall_ApplyConfig())
        }
    }
}

if (IsSet(RimPluginManager) && IsObject(RimPluginManager))
    RimPluginManager.Register(StatsBallPlugin)

; ---------- 配置读取 (schema 中央表优先, 缺表回落手写默认; 防 Map 缺键报错) ----------
StatsBall_Cfg(key, def) {
    try {
        if (IsSet(g_CfgSchema))
            return CfgGet("StatsBall", key, def)
    } catch {
    }
    try {
        v := CfgGet("StatsBall", key, "")
        if (v != "")
            return v
    } catch {
    }
    return def
}

; 手改垃圾值永不炸构造: 非数字回落默认 (后钳制不变)
StatsBall_IntCfg(key, def) {
    try {
        v := StatsBall_Cfg(key, "")
        if (v != "" && IsInteger(v))
            return Integer(v)
    } catch {
    }
    return def
}

; ---------- 热应用: 重读 [StatsBall] → 活对象 (配置中心 live 档回调) ----------
StatsBall_ApplyConfig(*) {
    global g_StatsBall
    enable := false
    try enable := StatsBall_Cfg("Enable", "1") = "1"
    if (!IsSet(g_StatsBall) || !IsObject(g_StatsBall)) {
        if (enable) {
            try StatsBall_Toggle()
        }
        return
    }
    if (!enable) {
        try g_StatsBall.Hide()
        return
    }
    try {
        g_StatsBall.interval := Integer(StatsBall_Cfg("RefreshMs", "1000"))
        if (g_StatsBall.interval < 500)
            g_StatsBall.interval := 500
        if (g_StatsBall.interval > 5000)
            g_StatsBall.interval := 5000
        g_StatsBall.opacity := Integer(StatsBall_Cfg("Opacity", "255"))
        if (g_StatsBall.opacity < 80)
            g_StatsBall.opacity := 80
        if (g_StatsBall.opacity > 255)
            g_StatsBall.opacity := 255
        g_StatsBall.snapEdge := StatsBall_Cfg("SnapEdge", "0") = "1"
        g_StatsBall.threshold := Integer(StatsBall_Cfg("AlertThreshold", "85"))
        g_StatsBall.topMost := StatsBall_Cfg("TopMost", "1") = "1"
        g_StatsBall.lockPos := StatsBall_Cfg("LockPos", "0") = "1"
        g_StatsBall.ww := Integer(StatsBall_Cfg("StripW", "156"))
        if (g_StatsBall.ww < 120)
            g_StatsBall.ww := 120
        if (g_StatsBall.ww > 480)
            g_StatsBall.ww := 480
        g_StatsBall.hh := Integer(StatsBall_Cfg("StripH", "40"))
        if (g_StatsBall.hh < 32)
            g_StatsBall.hh := 32
        if (g_StatsBall.hh > 80)
            g_StatsBall.hh := 80
        g_StatsBall.ClampPos()
        if (g_StatsBall.visible) {
            try SetTimer(g_StatsBall.timerFn, g_StatsBall.interval)
            try g_StatsBall.g.Show("x" . g_StatsBall.x . " y" . g_StatsBall.y . " NoActivate")
            try WinSetAlwaysOnTop(g_StatsBall.topMost ? true : false, "ahk_id " . g_StatsBall.ballHwnd)
            try g_StatsBall.Tick()
        }
    }
}

; ---------- 入口 ----------
StatsBall_Toggle(*) {
    global g_StatsBall
    if (!IsSet(g_StatsBall) || !IsObject(g_StatsBall)) {
        if (StatsBall_Cfg("Enable", "1") = "0") {
            try ToolTip(T("statsball.disabled"))
            try SetTimer(RemoveToolTip, -1200)
            return
        }
        g_StatsBall := StatsBallObj()
        g_StatsBall.Show()
    } else if (!g_StatsBall.visible) {
        g_StatsBall.Show()
    } else {
        ; 命令/托盘再点 = 开面板 (球体单击=一键加速, 面板走这里/双击/右键菜单);
        ; 隐藏只走右键菜单, 避免"我点了一下球就没了"的误报
        g_StatsBall.OpenPanel()
    }
}

; 启动自恢复: 新进程起来后把球找回来 (配置保存/手动重启都会走新进程)
StatsBall_AutoShow() {
    try {
        if (StatsBall_Cfg("Enable", "1") != "1")
            return
        if (!VimPluginOn("StatsBall"))
            return
        StatsBall_Toggle()
    } catch {
    }
}

StatsBall_ShowPanel(*) {
    global g_StatsBall
    if (!IsSet(g_StatsBall) || !IsObject(g_StatsBall)) {
        g_StatsBall := StatsBallObj()
        g_StatsBall.Show()
    } else if (!g_StatsBall.visible) {
        g_StatsBall.Show()
    }
    g_StatsBall.OpenPanel()
}

StatsBall_Boost(*) {
    global g_StatsBall
    if (!IsSet(g_StatsBall) || !IsObject(g_StatsBall)) {
        g_StatsBall := StatsBallObj()
        g_StatsBall.Show()
    }
    g_StatsBall.OpenPanel()
    g_StatsBall.DoBoost()
}

; ============================================================
; 三段雷达对象 (CPU / 内存 / 网速横条, 纯自绘)
; ============================================================
class StatsBallObj {
    __New() {
        this.interval := StatsBall_IntCfg("RefreshMs", 1000)
        if (this.interval < 500)
            this.interval := 500
        if (this.interval > 5000)
            this.interval := 5000
        this.opacity := StatsBall_IntCfg("Opacity", 255)
        if (this.opacity < 80)
            this.opacity := 80
        if (this.opacity > 255)
            this.opacity := 255
        this.snapEdge := StatsBall_Cfg("SnapEdge", "0") = "1"
        this.threshold := StatsBall_IntCfg("AlertThreshold", 85)
        this.topMost := StatsBall_Cfg("TopMost", "1") = "1"
        this.lockPos := StatsBall_Cfg("LockPos", "0") = "1"
        ; 挂件几何: 三段横条默认 156x40 (等比对齐原版)
        this.ww := StatsBall_IntCfg("StripW", 156)
        if (this.ww < 120)
            this.ww := 120
        if (this.ww > 480)
            this.ww := 480
        this.hh := StatsBall_IntCfg("StripH", 40)
        if (this.hh < 32)
            this.hh := 32
        if (this.hh > 80)
            this.hh := 80
        ; 位置: 优先读存档, 否则右下角
        this.x := ""
        this.y := ""
        try {
            global g_AutoConf
            if (IsObject(g_AutoConf)) {
                sx := g_AutoConf.Get("StatsBall", "BallX", "")
                sy := g_AutoConf.Get("StatsBall", "BallY", "")
                if (sx != "" && sy != "") {
                    this.x := Integer(sx)
                    this.y := Integer(sy)
                }
            }
        } catch {
        }
        if (this.x = "" || this.y = "") {
            ; 默认停靠: 主屏右下角任务栏上方 12px (对齐 360 悬浮球落点, 不压托盘时钟)
            try {
                sw := SysGet(78)
                sh := SysGet(79)
                taskH := 48
                try {
                    WinGetPos(, , , &th, "ahk_class Shell_TrayWnd")
                    if (th > 0 && th < sh // 3)
                        taskH := th
                } catch {
                }
                this.x := sw - this.ww - 12
                this.y := sh - taskH - this.hh - 12
            } catch {
                this.x := 100
                this.y := 100
            }
        }
        this.ClampPos()
        this.visible := false
        this.g := ""
        this.ballHwnd := 0
        this.fancy := false
        this.panelG := ""
        this.toastG := ""
        this.toastShown := false
        this.panelOpen := false
        this.histCpu := []
        this.histMem := []
        this.histNet := []
        this.lastKey := ""
        this.lastAlertTick := 0
        this.lastTopTick := 0
        this.lastFullTick := 0
        this.topText := ""
        this.downX := 0
        this.downY := 0
        this.downWX := 0
        this.downWY := 0
        this.dragging := false
        this.downTick := 0
        this.lastHoverTick := 0
        this.msgInstalled := false
        this.hoverBoost := false
        this.renderFails := 0
        this.tickCount := 0
        this.lastSavedX := ""
        this.lastSavedY := ""
        this.timerFn := this.Tick.Bind(this)
        this.lastSample := {cpu: 0, memPct: 0, availGB: 0, totalGB: 0, up: 0, dn: 0}
    }

    Show() {
        if (!this.g)
            this.CreateWidget()
        this.ClampPos()
        this.visible := true
        try this.g.Show("x" . this.x . " y" . this.y . " NoActivate")
        ; 注意: 分层窗 (+E0x80000) 透明度走 UpdateLayeredWindow 的 blend,
        ; 此处调 WinSetTransparent 会把窗变全透明 (消失主因之一), 已删除
        try WinSetAlwaysOnTop(this.topMost ? true : false, "ahk_id " . this.ballHwnd)
        catch {
        }
        this.InstallMsg()
        try SetTimer(this.timerFn, this.interval)
        this.Tick()
    }

    Hide() {
        this.visible := false
        this.downTick := 0
        this.dragging := false
        this.hoverBoost := false
        try ToolTip()
        catch {
        }
        try DllCall("User32.dll\ReleaseCapture")
        catch {
        }
        try SetTimer(this.timerFn, 0)
        try {
            WinGetPos(&hx, &hy, , , "ahk_id " . this.ballHwnd)
            this.x := hx
            this.y := hy
        } catch {
        }
        try this.SavePos()
        catch {
        }
        try this.g.Hide()
        this.ClosePanel()
    }

    Toggle(*) {
        if (this.visible)
            this.Hide()
        else
            this.Show()
    }

    Destroy(*) {
        try SetTimer(this.timerFn, 0)
        this.downTick := 0
        this.dragging := false
        this.hoverBoost := false
        try ToolTip()
        catch {
        }
        try DllCall("User32.dll\ReleaseCapture")
        catch {
        }
        try this.SavePos()
        catch {
        }
        this.RemoveMsg()
        try {
            if (this.g)
                this.g.Destroy()
        } catch {
        }
        try {
            if (this.panelG)
                this.panelG.Destroy()
        } catch {
        }
        try {
            if (this.toastG)
                this.toastG.Destroy()
        } catch {
        }
        this.g := ""
        this.panelG := ""
        this.toastG := ""
        this.panelOpen := false
        global g_StatsBall
        g_StatsBall := ""
    }

    CreateWidget() {
        ; 三段模式: 全自绘, 无原生控件
        this.g := Gui("+ToolWindow -Caption +AlwaysOnTop +E0x80000", "StatsBall")
        this.g.BackColor := "1B5E33"
        this.ballHwnd := this.g.Hwnd
        this.g.OnEvent("ContextMenu", this.OnMenu.Bind(this))
        this.g.OnEvent("Close", this.Hide.Bind(this))
        this.g.Show("x" . this.x . " y" . this.y . " w" . this.ww . " h" . this.hh . " NoActivate")
        ; GDI+ 自绘 (layered 真透明+抗锯齿)
        this.fancy := false
        try {
            if (this.RenderFrame())
                this.fancy := true
        } catch {
        }
    }

    ; 画一帧三段横条, 返回是否成功 (悬停时叠加闪电)
    RenderFrame() {
        return StatsBall_RenderStrip(this.ballHwnd, this.lastSample, this.ww, this.hh, this.opacity, this.hoverBoost)
    }

    ; 窗口重建 (自愈用): 只拆球窗, 悬停/面板/土司不动, 位置保持
    RecreateWidget() {
        this.downTick := 0
        this.dragging := false
        try DllCall("User32.dll\ReleaseCapture")
        catch {
        }
        try {
            if (this.g)
                this.g.Destroy()
        } catch {
        }
        this.g := ""
        this.ballHwnd := 0
        this.fancy := false
        this.CreateWidget()
        try this.g.Show("x" . this.x . " y" . this.y . " NoActivate")
        try WinSetAlwaysOnTop(this.topMost ? true : false, "ahk_id " . this.ballHwnd)
        catch {
        }
        this.InstallMsg()
        ; 重建后立刻画一帧, 失败则纯色兜底, 绝不留透明空窗
        rendered := false
        try rendered := this.RenderFrame()
        catch {
            rendered := false
        }
        if (!rendered) {
            try {
                if (StatsBall_FallbackStrip(this.ballHwnd, this.ww, this.hh, this.opacity))
                    rendered := true
            } catch {
            }
        }
        this.fancy := rendered ? true : false
    }

    ; 位置存盘 (拖尾/隐藏/销毁/定期调用)
    SavePos() {
        if (this.x = "" || this.y = "")
            return
        if (this.x = this.lastSavedX && this.y = this.lastSavedY)
            return
        try {
            global g_AutoConf
            if (IsObject(g_AutoConf)) {
                try g_AutoConf.Set("StatsBall", "BallX", String(this.x))
                catch {
                }
                try g_AutoConf.Set("StatsBall", "BallY", String(this.y))
                catch {
                }
                try g_AutoConf.Save()
                catch {
                }
                this.lastSavedX := this.x
                this.lastSavedY := this.y
            }
        } catch {
        }
    }


    ; 全局鼠标消息仅球可见时安装, 按 Hwnd 过滤, 不影响其他窗口
    ; 注意 0x200 常驻: 无按下时首行即返回, 开销可忽略
    InstallMsg() {
        if (this.msgInstalled)
            return
        try {
            OnMessage(0x200, this.OnMMove.Bind(this))
            OnMessage(0x201, this.OnLDown.Bind(this))
            OnMessage(0x202, this.OnLUp.Bind(this))
            OnMessage(0x203, this.OnLDbl.Bind(this))
            OnMessage(0x0138, this.OnCtlColor.Bind(this))
            this.boostFn := this.BoostLater.Bind(this)
            this.msgInstalled := true
        } catch {
        }
    }

    RemoveMsg() {
        ; AHK 未提供按对象解绑,  visibility=false 时靠 Hwnd 过滤直接返回
    }

    HitBall() {
        try {
            MouseGetPos(&mx, &my, &mw)
            if (mw != this.ballHwnd)
                return false
            return true
        } catch {
            return false
        }
    }

    OnLDown(wParam, lParam, msg, hwnd) {
        if (!this.visible || !this.g)
            return
        if (!this.HitBall())
            return
        try {
            MouseGetPos(&mx, &my)
            this.downX := mx
            this.downY := my
            this.downWX := this.x
            this.downWY := this.y
            this.dragging := false
            ; 锁定位置时不记拖拽起点位移 (downTick 照记, 供纯点击开面板用)
            this.downTick := A_TickCount
        } catch {
        }
    }

    ; 悬停开关: 进→内存格盖白闪电+原生小黄条文字提示, 出→还原;
    ; 窗体尺寸不变, 不伸黑条
    SetHover(on) {
        on := on ? true : false
        if (on = this.hoverBoost)
            return
        this.hoverBoost := on
        if (!this.g || !this.visible)
            return
        try {
            if (on)
                ToolTip(T("statsball.hover_hint"))
            else
                ToolTip()
        } catch {
        }
        try this.RenderFrame()
        catch {
        }
    }

    ; 按住拖拽即时跟随 (原生消息速率, 不走 1s Tick):
    ; 首超 6px 即 SetCapture, cursor 出窗照样收得到 0x200/0x202,
    ; 松手位置=落点, 不会再被甩在 1 秒前的路径上
    OnMMove(wParam, lParam, msg, hwnd) {
        if (!this.visible || !this.g)
            return
        ; 非拖拽态只做悬停追踪, 且 200ms 节流 (此前每条 0x200 都进 HitBall/MouseGetPos)
        if (this.downTick = 0 || this.lockPos) {
            now := A_TickCount
            if (now - this.lastHoverTick < 200)
                return
            this.lastHoverTick := now
            ; 悬停追踪 (与拖拽无关, downTick=0 照走); 按住左键时不触发
            try {
                over := this.HitBall()
                if (over && !this.hoverBoost && !this.dragging && !GetKeyState("LButton", "P"))
                    this.SetHover(true)
                else if (!over && this.hoverBoost)
                    this.SetHover(false)
            } catch {
            }
            return
        }
        try {
            if (!GetKeyState("LButton", "P"))
                return
            MouseGetPos(&mx, &my)
            dx := mx - this.downX
            dy := my - this.downY
            adx := dx < 0 ? -dx : dx
            ady := dy < 0 ? -dy : dy
            if (!this.dragging && adx + ady < 6)
                return
            if (!this.dragging) {
                this.dragging := true
                try ToolTip()
                catch {
                }
                try DllCall("User32.dll\SetCapture", "Ptr", this.ballHwnd)
                catch {
                }
            }
            this.x := this.downWX + dx
            this.y := this.downWY + dy
            try this.g.Show("x" . this.x . " y" . this.y . " NoActivate")
        } catch {
        }
    }

    OnLUp(wParam, lParam, msg, hwnd) {
        ; 只释放自己持有的 capture: OnMessage 是线程级的, 每次左键松开都会进这里;
        ; 无条件 ReleaseCapture 会掐断别家按钮正在进行的按下流程
        ; (按下在按钮上、松开瞬间 capture 被抢 → WM_CAPTURECHANGED 取消按压 →
        ; BN_CLICKED 永不产生; 列表是按下即选中所以不受影响 —— 配置中心全员按钮
        ; 失灵、唯独列表正常的主谋; 2026-09 实测锤实)
        if (this.dragging) {
            try DllCall("User32.dll\ReleaseCapture")
            catch {
            }
        }
        if (!this.visible || !this.g || this.downTick = 0)
            return
        wasDrag := this.dragging
        try {
            MouseGetPos(&mx, &my)
            dx := mx - this.downX
            if (dx < 0)
                dx := -dx
            dy := my - this.downY
            if (dy < 0)
                dy := -dy
            if (dx + dy > 6)
                wasDrag := true
        } catch {
        }
        this.downTick := 0
        this.dragging := false
        ; 锁定时远距离松手: 立刻弹回记录位 (不等 Tick; 点击加速不受影响)
        if (wasDrag && this.lockPos) {
            try this.g.Show("x" . this.x . " y" . this.y . " NoActivate")
            catch {
            }
            return
        }
        if (wasDrag) {
            this.SnapAndSave()
            return
        }
        ; 纯点击(在球上抬起)=一键加速; 面板走双击/右键菜单/托盘命令
        ; 双击会先走一次 LUp, 延迟到双击判定窗口之后再加速, 双击开面板即取消
        try {
            MouseGetPos(&mx2, &my2, &mw2)
            if (mw2 = this.ballHwnd)
                SetTimer(this.boostFn, -DllCall("User32.dll\GetDoubleClickTime", "UInt"))
        } catch {
        }
    }

    BoostLater(*) {
        try this.QuickBoost()
    }

    OnLDbl(wParam, lParam, msg, hwnd) {
        if (!this.visible)
            return
        if (!this.HitBall())
            return
        try SetTimer(this.boostFn, 0)
        try this.OpenPanel()
    }

    ; 兜底 (平时跟随走 OnMMove 即时消息, 这里只处理异常态):
    ; LUp 丢失 (capture 被系统抢走等) 导致 downTick 卡死时, 在此结算/取消,
    ; 避免下次点击行为错乱; 锁定位置时同样要清僵尸态 (点击开面板不受影响)
    PollDrag() {
        if (this.downTick = 0 || !this.visible)
            return
        try {
            if (!GetKeyState("LButton", "P")) {
                if (this.dragging) {
                    this.downTick := 0
                    this.dragging := false
                    try DllCall("User32.dll\ReleaseCapture")
                    catch {
                    }
                    this.SnapAndSave()
                } else {
                    this.downTick := 0
                }
                return
            }
            if (this.lockPos)
                return
            MouseGetPos(&mx, &my)
            dx := mx - this.downX
            dy := my - this.downY
            adx := dx < 0 ? -dx : dx
            ady := dy < 0 ? -dy : dy
            if (!this.dragging && adx + ady < 6)
                return
            this.dragging := true
            nx := this.downWX + dx
            ny := this.downWY + dy
            this.x := nx
            this.y := ny
            try this.g.Show("x" . nx . " y" . ny . " NoActivate")
        } catch {
        }
    }

    SnapAndSave() {
        ; 锁定时不贴边不位移, 但仍存盘 (否则默认位置永远写不进去, 重启即丢)
        if (!this.lockPos && this.snapEdge) {
            try {
                mr := StatsBall_MonRect(this.x + this.ww // 2, this.y + this.hh // 2)
                if (this.x + this.ww // 2 >= (mr.l + mr.r) // 2)
                    this.x := mr.r - this.ww - 8
                else
                    this.x := mr.l + 8
                try this.g.Show("x" . this.x . " y" . this.y . " NoActivate")
            } catch {
            }
        }
        this.ClampPos()
        try this.g.Show("x" . this.x . " y" . this.y . " NoActivate")
        catch {
        }
        try this.SavePos()
        catch {
        }
    }

    OnMenu(*) {
        try {
            mm := Menu()
            try mm.Add(T("statsball.menu.panel"), this.OpenPanel.Bind(this))
            try mm.Add(T("statsball.menu.boost"), this.DoBoost.Bind(this))
            try mm.Add()
            try mm.Add(T("statsball.menu.hide"), this.Hide.Bind(this))
            try mm.Add(T("statsball.menu.exit"), this.Destroy.Bind(this))
            mm.Show()
        } catch {
        }
    }

    Tick() {
        if (!this.visible)
            return
        this.tickCount++
        ; 窗口被外部销毁 (资源管理器重启/显示切换): 直接重建, 不等 renderFails
        try {
            if (this.ballHwnd && !WinExist("ahk_id " . this.ballHwnd)) {
                try this.RecreateWidget()
                catch {
                }
                return
            }
        } catch {
        }
        try this.PollDrag()
        catch {
        }
        ; 悬停兜底 (0x200 可能漏消息/窗口建在静止 cursor 下, 靠 Tick 进出)
        try {
            if (!this.hoverBoost && !this.dragging && this.downTick = 0 && this.HitBall()) {
                try {
                    if (!GetKeyState("LButton", "P"))
                        this.SetHover(true)
                } catch {
                }
            } else if (this.hoverBoost && !this.dragging && !this.HitBall()) {
                this.SetHover(false)
            }
        } catch {
        }
        ; 缓存坐标按实时窗口校准 (拖拽/系统移动后不错位, 存盘也准)
        ; 拖拽中不回写, 否则 PollDrag 刚设的 x/y 被旧 WinGetPos 覆盖而抖动
        if (!this.dragging) {
            try {
                WinGetPos(&sx, &sy, , , "ahk_id " . this.ballHwnd)
                if (this.lockPos && (sx != this.x || sy != this.y)) {
                    ; 锁定时强制回位: 拖拽结算/系统/外部旁路挪窗, 下一 tick 弹回;
                    ; 未锁定走原校准 (缓存<=实时, 存盘准)
                    ; TEMP-DIAG3: 回位即记 (定案即删, 看谁在挪窗)
                    try FileAppend(A_Now . " SB-SNAPBACK from=" . sx . "," . sy . " to=" . this.x . "," . this.y . "`n", A_ScriptDir . "\Rim.error.log")
                    catch {
                    }
                    try this.g.Show("x" . this.x . " y" . this.y . " NoActivate")
                    catch {
                    }
                } else {
                    this.x := sx
                    this.y := sy
                }
            } catch {
            }
        }
        ; 分层采样: CPU/内存全量 1s 一次, 网速走 250ms 快车道并入, 渲染与面板读合并快照.
        ; TopProcs 永不进此路径 (仅 RefreshPanel 内面板打开 + 5s 节流).
        s := this.lastSample
        try {
            if (this.lastFullTick = 0 || A_TickCount - this.lastFullTick >= 1000) {
                s := StatsBall_Sample()
                this.lastFullTick := A_TickCount
            }
        } catch {
            return
        }
        if (!IsObject(s))
            return
        try {
            n := StatsBall_SampleNet()
            if (IsObject(n))
                s := StatsBall_MergeSample(s, n)
        } catch {
        }
        this.lastSample := s
        ; hist 定长 60
        try {
            this.histCpu.Push(Integer(s.cpu))
            this.histMem.Push(Integer(s.memPct))
            nv := 0
            try nv := Integer(Min(100, s.dn / 104857.6))
            this.histNet.Push(nv)
            while (this.histCpu.Length > 60)
                this.histCpu.RemoveAt(1)
            while (this.histMem.Length > 60)
                this.histMem.RemoveAt(1)
            while (this.histNet.Length > 60)
                this.histNet.RemoveAt(1)
        } catch {
        }
        ; 脏检查: 变化<1% 且网速<1KB/s 跳过重绘; 每 30 tick 强制刷一帧,
        ; 保分层位图不因 DWM/锁屏失效而变透明空窗
        key := Integer(s.memPct) . "/" . Integer(s.cpu) . "/" . Integer(s.dn / 1024) . "/" . Integer(s.up / 1024)
        forceTick := (Mod(this.tickCount, 30) = 0)
        if (forceTick || key != this.lastKey) {
            this.lastKey := key
            rendered := false
            try {
                rendered := this.RenderFrame()
            } catch {
                rendered := false
            }
            ; 无原生控件兜底: 自绘失败先上纯色帧, 绝不留透明空窗
            if (!rendered) {
                try {
                    if (StatsBall_FallbackStrip(this.ballHwnd, this.ww, this.hh, this.opacity))
                        rendered := true
                } catch {
                }
            }
            if (rendered) {
                this.renderFails := 0
            } else {
                this.renderFails++
                ; 自绘连续失败 3 次 (DWM 切换/桌面锁定等导致 ULW 异常): 重建窗口自愈,
                ; 避免横条变透明空窗"看起来消失了"
                if (this.renderFails >= 3) {
                    this.renderFails := 0
                    try this.RecreateWidget()
                    catch {
                    }
                }
            }
            this.fancy := rendered ? true : false
        }
        ; 面板刷新
        try {
            if (this.panelOpen && this.panelG)
                this.RefreshPanel(s)
        } catch {
        }
        ; 告警防抖 60s (自绘土司, 不再用系统 TrayTip)
        try {
            if (Integer(s.memPct) >= this.threshold && A_TickCount - this.lastAlertTick > 60000) {
                this.lastAlertTick := A_TickCount
                try this.ShowToast(T("statsball.alert_title"), T("statsball.alert_text", Integer(s.memPct)))
            }
        } catch {
        }
        ; 位置定期存盘 (每 10 tick, 变化才写): 崩溃/重启也不丢, 锁定时同样生效
        try {
            if (Mod(this.tickCount, 10) = 0 && !this.dragging)
                this.SavePos()
        } catch {
        }
    }

    ; 所在显示器工作区 (多屏: 按挂件中心落在哪块屏算哪块, 不再全按主屏,
    ; 否则拖到副屏会被钳制/贴边弹回主屏, 看着像"自动乱跑")
    ; 注意 w/h 用 ww/hh, BallRect 在窗口销毁后回落缓存
    ClampPos() {
        try {
            mr := StatsBall_MonRect(this.x + this.ww // 2, this.y + this.hh // 2)
            grab := 48
            if (this.x > mr.r - grab)
                this.x := mr.r - grab
            if (this.x < mr.l + grab - this.ww)
                this.x := mr.l + grab - this.ww
            if (this.y > mr.b - grab)
                this.y := mr.b - grab
            if (this.y < mr.t)
                this.y := mr.t
        } catch {
        }
    }

    ; 雷达实时矩形 (面板跟随以它为准, 不信缓存 x/y, 杜绝拖拽后错位)
    BallRect() {
        try {
            WinGetPos(&bx, &by, &bw, &bh, "ahk_id " . this.ballHwnd)
            if (bw > 0 && bh > 0)
                return {x: bx, y: by, w: bw, h: bh}
        } catch {
        }
        return {x: this.x, y: this.y, w: this.ww, h: this.hh}
    }

    ; 自绘土司 (圆角深色, 替代系统 TrayTip): 任务栏上方右侧, 2.5s 自关
    ShowToast(title, text) {
        try {
            if (!this.toastG) {
                this.toastG := Gui("+ToolWindow -Caption +AlwaysOnTop", "StatsBallToast")
                this.toastG.BackColor := "232323"
                this.toastG.SetFont("s10 cWhite Bold", "Segoe UI")
                this.toastTitle := this.toastG.AddText("x14 y8 w292 h22", "")
                this.toastG.SetFont("s9 cD8D8D8 Norm", "Segoe UI")
                this.toastText := this.toastG.AddText("x14 y32 w292 h24", "")
                this.toastShown := false
                this.toastFn := this.HideToast.Bind(this)
            }
            this.toastTitle.Value := title
            this.toastText.Value := text
            tw := 320
            th := 64
            try {
                sw := SysGet(78)
                sh := SysGet(79)
                taskH := 48
                try {
                    WinGetPos(, , , &tbh, "ahk_class Shell_TrayWnd")
                    if (tbh > 0 && tbh < sh // 3)
                        taskH := tbh
                } catch {
                }
                tx := sw - tw - 12
                ty := sh - taskH - th - 12
            } catch {
                tx := this.x - 260
                ty := this.y - 80
            }
            if (!this.toastShown) {
                this.toastG.Show("x" . tx . " y" . ty . " w" . tw . " h" . th . " NoActivate")
                try WinSetRegion("0-0 w" . tw . " h" . th . " r10-10", "ahk_id " . this.toastG.Hwnd)
                this.toastShown := true
            } else {
                this.toastG.Show("x" . tx . " y" . ty . " NoActivate")
            }
            try SetTimer(this.toastFn, -2500)
        } catch {
        }
    }

    HideToast(*) {
        this.toastShown := false
        try {
            if (this.toastG)
                this.toastG.Hide()
        } catch {
        }
    }

    ; ---------- 加速面板 ----------
    OpenPanel(*) {
        if (!this.panelG)
            this.CreatePanel()
        this.panelOpen := true
        try this.panelG.Show("NoActivate")
        ; 面板贴球放置 (按实时矩形): 默认在雷达球正上方居中, 上方空间不够则放下方, 双向钳制
        try {
            sw := SysGet(78)
            sh := SysGet(79)
            pw := 300
            ph := 440
            br := this.BallRect()
            px := br.x + (br.w - pw) // 2
            if (px < 8)
                px := 8
            if (px + pw > sw - 8)
                px := sw - 8 - pw
            py := br.y - ph - 32
            if (py < 8)
                py := br.y + br.h + 12
            if (py + ph > sh - 48)
                py := sh - 48 - ph
            this.panelG.Show("x" . px . " y" . py . " NoActivate")
        } catch {
        }
        try {
            WinActivate("ahk_id " . this.panelHwnd)
        } catch {
        }
        try this.RefreshPanel(this.lastSample)
        catch {
        }
    }

    ClosePanel(*) {
        this.panelOpen := false
        try {
            if (this.panelG)
                this.panelG.Hide()
        } catch {
        }
    }

    CreatePanel() {
        this.panelG := Gui("+ToolWindow +AlwaysOnTop", T("statsball.panel_title"))
        this.panelG.BackColor := "FFFFFF"
        this.panelG.SetFont("s10 c333333", "Segoe UI")
        this.panelStatus := this.panelG.AddText("x20 y16 w260 h24", T("statsball.loading"))
        ; 进程列表 (任务管理器风格: 进程 | CPU | 内存, 单元格蓝底深浅按占比)
        ; 表头用 Button 做可点排序开关 (Text 不支持 Click)
        this.sortKey := "ws"
        this.sortDir := -1    ; -1=降序(大在前), +1=升序
        this.hNameBtn := this.panelG.AddButton("x20 y48 w100 h24", "进程")
        this.hCpuBtn := this.panelG.AddButton("x125 y48 w60 h24", "CPU")
        this.hMemBtn := this.panelG.AddButton("x195 y48 w80 h24", "内存")
        this.hNameBtn.OnEvent("Click", (*) => this.ToggleSort("name"))
        this.hCpuBtn.OnEvent("Click", (*) => this.ToggleSort("cpu"))
        this.hMemBtn.OnEvent("Click", (*) => this.ToggleSort("ws"))
        this.procNames := []
        this.procCpus := []
        this.procMems := []
        this.cellBg := Map()    ; 控件 hwnd -> 颜色字符串 (WM_CTLCOLORSTATIC 上色)
        this.cellBrush := Map() ; 颜色字符串 -> HBRUSH
        rowY := 76
        loop 10 {
            lbl := this.panelG.AddText("x20 y" . rowY . " w100 h26", "")
            cpu := this.panelG.AddText("x125 y" . rowY . " w60 h26 Right", "")
            mem := this.panelG.AddText("x195 y" . rowY . " w80 h26 Right", "")
            this.procNames.Push(lbl)
            this.procCpus.Push(cpu)
            this.procMems.Push(mem)
            rowY += 30
        }
        this.boostBtn := this.panelG.AddButton("x20 y392 w128 h30", T("statsball.boost_now"))
        this.boostBtn.OnEvent("Click", this.DoBoost.Bind(this))
        this.closeBtn := this.panelG.AddButton("x152 y392 w128 h30", T("statsball.close"))
        this.closeBtn.OnEvent("Click", this.ClosePanel.Bind(this))
        this.panelG.OnEvent("Close", this.ClosePanel.Bind(this))
        this.panelG.Show("w300 h440 Hide")
        this.panelHwnd := this.panelG.Hwnd
    }

    ToggleSort(key) {
        if (this.sortKey = key)
            this.sortDir := -this.sortDir
        else {
            this.sortKey := key
            this.sortDir := (key = "name") ? 1 : -1
        }
        this.UpdateSortHeaders()
        try this.RefreshPanel(this.lastSample)
    }

    UpdateSortHeaders() {
        marks := ["name", "cpu", "ws"]
        btns := [this.hNameBtn, this.hCpuBtn, this.hMemBtn]
        base := ["进程", "CPU", "内存"]
        loop 3 {
            if (this.sortKey = marks[A_Index]) {
                try btns[A_Index].Text := base[A_Index] . (this.sortDir = 1 ? " ↑" : " ↓")
            } else {
                try btns[A_Index].Text := base[A_Index]
            }
        }
    }

    OnCtlColor(wParam, lParam, msg, hwnd) {
        try {
            hCtl := lParam
            if (this.cellBg.Has(hCtl)) {
                c := this.cellBg[hCtl]
                if (!this.cellBrush.Has(c)) {
                    rgb := Integer("0x" . SubStr(c, 5, 2) . SubStr(c, 3, 2) . SubStr(c, 1, 2))  ; RRGGBB -> 0xBBGGRR
                    this.cellBrush[c] := DllCall("Gdi32.dll\CreateSolidBrush", "UInt", rgb, "Ptr")
                }
                return this.cellBrush[c]
            }
        } catch {
        }
    }

    SetCellBg(ctrl, rgbHex) {
        try {
            this.cellBg[ctrl.Hwnd] := rgbHex
            DllCall("User32.dll\InvalidateRect", "Ptr", ctrl.Hwnd, "Ptr", 0, "Int", 1)
        } catch {
        }
    }

    RefreshPanel(s) {
        if (!this.panelG || !this.panelOpen)
            return
        try this.panelStatus.Value := T("statsball.panel_title")
        ; Top 进程是高成本快照, 面板打开后每秒刷新一次 (动态变化).
        if (this.topText = "" || A_TickCount - this.lastTopTick >= 1000) {
            try {
                rows := StatsBall_TopProcs(10, this.sortKey, this.sortDir)
                maxWs := 0
                maxCpu := 0
                for _, r in rows {
                    if (r.ws > maxWs)
                        maxWs := r.ws
                    if (r.cpu > maxCpu)
                        maxCpu := r.cpu
                }
                idx := 0
                for _, r in rows {
                    idx++
                    try this.procNames[idx].Value := r.exe
                    try this.procCpus[idx].Value := Round(r.cpu, 1) . " %"
                    mb := Round(r.ws / 1048576)
                    try this.procMems[idx].Value := mb . " MB"
                    ; 任务管理器式蓝底深浅 (占比越大底色越深)
                    fMem := (maxWs > 0) ? r.ws / maxWs : 0
                    fCpu := (maxCpu > 0) ? r.cpu / maxCpu : 0
                    shM := Round(245 - fMem * 120)
                    shC := Round(245 - fCpu * 120)
                    this.SetCellBg(this.procMems[idx], Format("{:02X}{:02X}{:02X}", shM - 30, shM - 5, 255))
                    this.SetCellBg(this.procCpus[idx], Format("{:02X}{:02X}{:02X}", shC - 30, shC - 5, 255))
                }
                loop 10 - idx {
                    try this.procNames[idx + A_Index].Value := ""
                    try this.procCpus[idx + A_Index].Value := ""
                    this.SetCellBg(this.procCpus[idx + A_Index], "FFFFFF")
                    try this.procMems[idx + A_Index].Value := ""
                    this.SetCellBg(this.procMems[idx + A_Index], "FFFFFF")
                }
                this.topText := rows.Length
                this.lastTopTick := A_TickCount
            } catch {
            }
        }
    }

    ; 加速结果文案 (DoBoost 面板与 QuickBoost 土司共用)
    BoostMsg(r) {
        msg := T("statsball.boost_optimal", r.afterGB)
        try {
            if (r.freedMB > 0) {
                msg := T("statsball.boost_done", r.freedMB, r.afterGB)
                try {
                    if (r.standbyMB > 0)
                        msg .= " · " . T("statsball.boost_standby", r.standbyMB)
                } catch {
                }
            }
        }
        return msg
    }

    DoBoost(*) {
        if (!this.panelG)
            this.CreatePanel()
        this.panelOpen := true
        try this.panelG.Show()
        try this.boostBtn.Text := T("statsball.boosting")
        try this.boostBtn.Opt("+Disabled")
        r := ""
        try r := StatsBall_DoBoost()
        catch {
        }
        try this.boostBtn.Opt("-Disabled")
        try this.boostBtn.Text := T("statsball.boost_now")
        if (IsObject(r)) {
            try {
                msg := this.BoostMsg(r)
                this.panelStatus.Value := msg
                this.ShowToast(T("statsball.panel_title"), msg)
            }
        }
        try this.RefreshPanel(StatsBall_Sample())
        catch {
        }
    }

    ; 单击雷达: 静默加速, 不弹面板不弹土司 (结果进面板, 面板开着才刷新;
    ; 面板走双击/右键菜单/托盘命令)
    QuickBoost(*) {
        r := ""
        try r := StatsBall_DoBoost()
        catch {
            return
        }
        if (!IsObject(r))
            return
        try {
            if (this.panelOpen && this.panelG) {
                this.panelStatus.Value := this.BoostMsg(r)
                this.RefreshPanel(StatsBall_Sample())
            }
        } catch {
        }
    }
}
