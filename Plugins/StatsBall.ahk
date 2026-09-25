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

; ---------- 注册 (仅注册命令, 不建窗; 幂等: 命令+vim双通道各调一次) ----------
RegisterPlugin_StatsBall() {
    static registered := false
    if (registered)
        return
    registered := true
    RegisterCommand("StatsBall", "function", "StatsBall_Toggle", T("cmd.StatsBall.StatsBall"))
    RegisterCommand("StatsBallBoost", "function", "StatsBall_Boost", T("cmd.StatsBall.Boost"))
}

; ---------- 配置读取 (带默认值, 防 Map 缺键报错) ----------
StatsBall_Cfg(key, def) {
    try {
        global g_Conf
        if (IsObject(g_Conf) && g_Conf.HasSection("StatsBall")) {
            v := g_Conf.Get("StatsBall", key, "")
            if (v != "")
                return v
        }
    } catch {
    }
    return def
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
        this.interval := Integer(StatsBall_Cfg("RefreshMs", "1000"))
        if (this.interval < 500)
            this.interval := 500
        if (this.interval > 5000)
            this.interval := 5000
        this.opacity := Integer(StatsBall_Cfg("Opacity", "255"))
        if (this.opacity < 80)
            this.opacity := 80
        if (this.opacity > 255)
            this.opacity := 255
        this.snapEdge := StatsBall_Cfg("SnapEdge", "0") = "1"
        this.threshold := Integer(StatsBall_Cfg("AlertThreshold", "85"))
        this.topMost := StatsBall_Cfg("TopMost", "1") = "1"
        this.lockPos := StatsBall_Cfg("LockPos", "0") = "1"
        ; 挂件几何: 三段横条默认 156x40 (等比对齐原版)
        this.ww := Integer(StatsBall_Cfg("StripW", "156"))
        if (this.ww < 120)
            this.ww := 120
        if (this.ww > 480)
            this.ww := 480
        this.hh := Integer(StatsBall_Cfg("StripH", "40"))
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
        this.topText := ""
        this.downX := 0
        this.downY := 0
        this.downWX := 0
        this.downWY := 0
        this.dragging := false
        this.downTick := 0
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
        ; 悬停追踪 (与拖拽无关, downTick=0 照走); 按住左键时不触发
        try {
            over := this.HitBall()
            if (over && !this.hoverBoost && !this.dragging && !GetKeyState("LButton", "P"))
                this.SetHover(true)
            else if (!over && this.hoverBoost)
                this.SetHover(false)
        } catch {
        }
        if (this.downTick = 0 || this.lockPos)
            return
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
        if (wasDrag) {
            this.SnapAndSave()
            return
        }
        ; 纯点击(在球上抬起)=一键加速; 面板走双击/右键菜单/托盘命令
        try {
            MouseGetPos(&mx2, &my2, &mw2)
            if (mw2 = this.ballHwnd)
                this.QuickBoost()
        } catch {
        }
    }

    OnLDbl(wParam, lParam, msg, hwnd) {
        if (!this.visible)
            return
        if (!this.HitBall())
            return
        try this.OpenPanel()
        try this.DoBoost()
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
                this.x := sx
                this.y := sy
            } catch {
            }
        }
        s := ""
        try s := StatsBall_Sample()
        catch {
            return
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
        ; 面板贴球放置 (按实时矩形): 优先球左侧, 空间不够放右侧, 双向钳制
        try {
            sw := SysGet(78)
            sh := SysGet(79)
            pw := 384
            ph := 302
            br := this.BallRect()
            px := br.x - pw - 12
            if (px < 8)
                px := br.x + br.w + 12
            if (px + pw > sw - 8)
                px := sw - pw - 8
            py := br.y + br.h - ph
            if (py < 8)
                py := 8
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
        this.panelG.SetFont("s10 cBlack", "Segoe UI")
        this.panelStatus := this.panelG.AddText("x12 y10 w360 h24", T("statsball.loading"))
        this.panelCpu := this.panelG.AddText("x12 y38 w360 h40", "")
        this.panelMem := this.panelG.AddText("x12 y82 w360 h40", "")
        this.panelNet := this.panelG.AddText("x12 y126 w360 h40", "")
        this.panelTop := this.panelG.AddText("x12 y170 w360 h80", "")
        this.boostBtn := this.panelG.AddButton("x12 y258 w170 h32", T("statsball.boost_now"))
        this.boostBtn.OnEvent("Click", this.DoBoost.Bind(this))
        this.closeBtn := this.panelG.AddButton("x202 y258 w170 h32", T("statsball.close"))
        this.closeBtn.OnEvent("Click", this.ClosePanel.Bind(this))
        this.panelG.OnEvent("Close", this.ClosePanel.Bind(this))
        this.panelG.Show("w384 h302 Hide")
        this.panelHwnd := this.panelG.Hwnd
    }

    RefreshPanel(s) {
        if (!this.panelG || !this.panelOpen)
            return
        lv := StatsBall_Level(s.memPct)
        lvTxt := lv = 2 ? T("statsball.level_hot") : (lv = 1 ? T("statsball.level_warm") : T("statsball.level_cool"))
        try this.panelStatus.Value := T("statsball.status_fmt", Integer(s.memPct), lvTxt
            , StatsBall_FormatGB(s.availGB), StatsBall_FormatGB(s.totalGB))
        try this.panelCpu.Value := "CPU " . Integer(s.cpu) . "%`n" . StatsBall_Spark(this.histCpu)
        try this.panelMem.Value := "MEM " . Integer(s.memPct) . "%`n" . StatsBall_Spark(this.histMem)
        try this.panelNet.Value := "↓" . StatsBall_FormatRate(s.dn) . "  ↑" . StatsBall_FormatRate(s.up) . "`n" . StatsBall_Spark(this.histNet)
        ; Top 进程是高成本快照, 面板打开后每 5 秒刷新一次.
        if (this.topText = "" || A_TickCount - this.lastTopTick >= 5000) {
            try {
                rows := StatsBall_TopProcs(3)
                t := ""
                for _, r in rows
                    t .= r.exe . "  " . Round(r.ws / 1048576) . "MB`n"
                this.topText := (t = "") ? T("statsball.top_empty") : t
                this.lastTopTick := A_TickCount
            } catch {
            }
        }
        try this.panelTop.Value := T("statsball.top_title") . "`n" . this.topText
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
