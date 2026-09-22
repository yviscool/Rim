#Requires AutoHotkey v2.0
#Warn All, Off

; === StatsBall 插件 - 桌面三段雷达 (CPU / 内存 / 网速横条) ===
; 架构: 采样层(零WMI) + 条Gui(拖拽/贴边/三色) + 悬停闪电 + 加速面板
; 性能: 单一定时器 + 脏检查 + 定长 hist(60) + 面板按需取Top进程
; 注意: 注册期不建 Gui (冒烟探针 headless), 一律懒创建

global g_StatsBall := ""

; ---------- 注册 (仅注册命令, 不建窗) ----------
RegisterPlugin_StatsBall() {
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
; 采样层
; ============================================================
StatsBall_Sample() {
    static cache := {cpu: 0, memPct: 0, availGB: 0, totalGB: 0, up: 0, dn: 0}
    cpu := 0
    try cpu := CPULoad()
    catch {
        cpu := cache.cpu
    }
    memPct := cache.memPct
    availGB := cache.availGB
    totalGB := cache.totalGB
    try {
        st := GlobalMemoryStatusEx()
        if (IsObject(st)) {
            total := st[2]
            avail := st[3]
            if (total > 0) {
                memPct := Round(100 * (total - avail) / total)
                availGB := Round(avail / 1073741824, 1)
                totalGB := Round(total / 1073741824, 1)
            }
        }
    } catch {
    }
    net := {up: cache.up, dn: cache.dn}
    try net := StatsBall_NetRate()
    catch {
    }
    cache := {cpu: cpu, memPct: memPct, availGB: availGB, totalGB: totalGB, up: net.up, dn: net.dn}
    return cache
}

StatsBall_Level(memPct) {
    m := Integer(memPct)
    if (m >= 85)
        return 2
    if (m >= 60)
        return 1
    return 0
}

StatsBall_FormatRate(bps) {
    b := Float(bps)
    if (b >= 1048576)
        return Format("{:.1f} MB/s", b / 1048576)
    if (b >= 1024)
        return Format("{:.1f} KB/s", b / 1024)
    return Format("{:.0f} B/s", b)
}

StatsBall_FormatGB(gb) {
    return Format("{:.1f}G", Float(gb))
}

; 火花线: hist(0-100) -> ▁▂▃▄▅▆▇█
StatsBall_Spark(hist) {
    blocks := ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
    out := ""
    for _, v in hist {
        vv := Integer(v)
        if (vv < 0)
            vv := 0
        if (vv > 100)
            vv := 100
        idx := (vv * 8) // 101 + 1
        if (idx < 1)
            idx := 1
        if (idx > 8)
            idx := 8
        out .= blocks[idx]
    }
    return out
}

; GetIfTable2 聚合物理口速率 (调用方 try 包裹; 首 tick 返回 0)
; 偏移经 Python+ctypes 按 MSVC 对齐实测标定 (2026-09, 31 口本机双向激励):
; tableOff=8(NumEntries 后 4 字节对齐填充), rowSize=1352, Type@1128,
; OperStatus@1112+44=1156(1=up), InOctets@1208, OutOctets@1280
; (旧值 @1312 实测恒零, 系 OutDiscards/Errors 区 —— 上行永远 0 的根因;
;  定量 ping+下载激励下 @1280/+14064 与包计数 @1288/+108 同步涨, 自洽;
;  @1256/@1320 为单播镜像, 求和时靠 (rx,tx) 去重消除)
; 注意: 虚拟层叠口 (QoS/WFP/虚拟交换机) 会镜像同一物理计数器, 先按 (rx,tx)
; 去重, 再按 Luid 逐口跟踪求差分, 否则网速 ×N; 回环口 (Type=24) 排除;
; 速率>10Gbps 视为计数器异常回 0 (最后兜底, 集合突变毛刺已由逐口跟踪消除)
StatsBall_NetRate() {
    ; 逐口 Luid 跟踪: 只统计新老快照都存在的口子, 新口/消失口不贡献差分
    ; (WiFi 重连/休眠唤醒/VPN 插拔时接口集合突变, 聚合求和会把新口的累计值
    ;  一次算进 1s 差分 —— 949M 这类野值的根因)
    static prev := Map(), prevTick := 0
    rowSize := 1352
    tableOff := 8
    typeOff := 1128
    operOff := 1156
    inOff := 1208
    outOff := 1280
    pTable := 0
    hr := DllCall("iphlpapi\GetIfTable2", "Ptr*", &pTable, "UInt")
    if (hr != 0 || !pTable)
        return {up: 0, dn: 0}
    cur := Map()
    try {
        num := NumGet(pTable, 0, "UInt")
        seen := Map()
        i := 0
        while (i < num) {
            base := pTable + tableOff + i * rowSize
            i++
            try {
                if (NumGet(base, operOff, "UInt") != 1)
                    continue
                if (NumGet(base, typeOff, "UInt") = 24)
                    continue
                r := NumGet(base, inOff, "UInt64")
                t := NumGet(base, outOff, "UInt64")
                k := String(r) . "|" . String(t)
                if (seen.Has(k))
                    continue
                seen[k] := true
                ; Luid@0 跨快照稳定, 同一网卡去重镜像后只留一条
                cur[NumGet(base, 0, "UInt64")] := [r, t]
            } catch {
            }
        }
    } finally {
        DllCall("iphlpapi\FreeMibTable", "Ptr", pTable)
    }
    now := A_TickCount
    if (prevTick = 0 || prev.Count = 0) {
        prev := cur
        prevTick := now
        return {up: 0, dn: 0}
    }
    dt := (now - prevTick) / 1000.0
    if (dt <= 0)
        return {up: 0, dn: 0}
    dRx := 0
    dTx := 0
    for luid, ct in cur {
        if (prev.Has(luid)) {
            ; 单口计数器回绕/清零: 该口本轮贡献 0, 基线照常更新
            dr := ct[1] - prev[luid][1]
            dt2 := ct[2] - prev[luid][2]
            if (dr > 0)
                dRx += dr
            if (dt2 > 0)
                dTx += dt2
        }
    }
    prev := cur
    prevTick := now
    if (dRx / dt > 1250000000 || dTx / dt > 1250000000)
        return {up: 0, dn: 0}
    return {up: dTx / dt, dn: dRx / dt}
}

; Top-N 内存进程 (Toolhelp 快照, 无 WMI; 仅面板打开时调用)
; PROCESSENTRY32W 实测布局 (ctypes+内核双验证, 2026-09): cbSize=568
; (pcPriClassBase 占 8 字节!), pid@8, exe@40+4=44; cb 不对即 A_LastError=24
StatsBall_TopProcs(n := 3) {
    out := []
    try {
        hSnap := DllCall("kernel32\CreateToolhelp32Snapshot", "UInt", 0x2, "UInt", 0, "Ptr")
        if (hSnap = -1)
            return out
        try {
            pe := Buffer(568, 0)
            NumPut("UInt", 568, pe, 0)
            ok := DllCall("kernel32\Process32FirstW", "Ptr", hSnap, "Ptr", pe)
            rows := []
            while (ok) {
                pid := NumGet(pe, 8, "UInt")
                exe := StrGet(pe.Ptr + 44, 260)
                ws := 0
                try {
                    hProc := DllCall("kernel32\OpenProcess", "UInt", 0x1000, "Int", 0, "UInt", pid, "Ptr")
                    if (hProc) {
                        try {
                            pmc := Buffer(72, 0)
                            NumPut("UInt", 72, pmc, 0)
                            if (DllCall("psapi\GetProcessMemoryInfo", "Ptr", hProc, "Ptr", pmc, "UInt", 72))
                                ws := NumGet(pmc, 8, "Ptr")
                        } finally {
                            DllCall("kernel32\CloseHandle", "Ptr", hProc)
                        }
                    }
                } catch {
                }
                if (exe != "" && ws > 0)
                    rows.Push({exe: exe, ws: ws, pid: pid})
                ok := DllCall("kernel32\Process32NextW", "Ptr", hSnap, "Ptr", pe)
            }
            rowslen := rows.Length
            Loop rowslen {
                bi := A_Index
                Loop rowslen - A_Index {
                    j := A_Index
                    if (rows[j].ws < rows[j + 1].ws) {
                        tmp := rows[j]
                        rows[j] := rows[j + 1]
                        rows[j + 1] := tmp
                    }
                }
                _ := bi
            }
            k := 0
            for _, r in rows {
                k++
                if (k > n)
                    break
                out.Push(r)
            }
        } finally {
            DllCall("kernel32\CloseHandle", "Ptr", hSnap)
        }
    } catch {
    }
    return out
}

; 给当前进程启用指定特权 (如 SeProfileSingleProcessPrivilege), 供 standby purge 用
; 非提权运行时 AdjustTokenPrivileges 报 1300, 直接回 false, 调用方走 trim 兜底
StatsBall_EnablePrivilege(privName) {
    hTok := 0
    try {
        hProc := DllCall("kernel32\GetCurrentProcess", "Ptr")
        if (!DllCall("advapi32\OpenProcessToken", "Ptr", hProc, "UInt", 0x28, "Ptr*", &hTok))
            return false
        luid := Buffer(8, 0)
        if (!DllCall("advapi32\LookupPrivilegeValueW", "Ptr", 0, "WStr", privName, "Ptr", luid))
            return false
        tp := Buffer(16, 0)
        NumPut("UInt", 1, tp, 0)
        NumPut("Int64", NumGet(luid, 0, "Int64"), tp, 4)
        NumPut("UInt", 2, tp, 12)
        if (!DllCall("advapi32\AdjustTokenPrivileges", "Ptr", hTok, "Int", 0, "Ptr", tp, "UInt", 0, "Ptr", 0, "Ptr", 0))
            return false
        return DllCall("kernel32\GetLastError", "UInt") = 0
    } catch {
        return false
    } finally {
        try {
            if (hTok)
                DllCall("kernel32\CloseHandle", "Ptr", hTok)
        } catch {
        }
    }
}

; 待机缓存 MB (NtQuerySystemInformation class 80; StandbyPageCount@40 新老结构体同偏移,
; 先按 184 字节 (Win10+) 查, 失败回落 112 (Win7); 页按 4K 算)
StatsBall_StandbyMB() {
    try {
        buf := Buffer(184, 0)
        retlen := 0
        st := DllCall("ntdll\NtQuerySystemInformation", "Int", 80, "Ptr", buf, "UInt", 184, "UInt*", &retlen)
        if (st != 0) {
            buf2 := Buffer(112, 0)
            st := DllCall("ntdll\NtQuerySystemInformation", "Int", 80, "Ptr", buf2, "UInt", 112, "UInt*", &retlen)
            if (st != 0)
                return 0
            buf := buf2
        }
        pages := NumGet(buf, 40, "UInt64")
        return pages * 4096 // 1048576
    } catch {
        return 0
    }
}

; 清待机缓存 (RAMMap/Mem Reduct 同机制: MemoryPurgeStandbyList=4; 要提权,
; 普通权限回 false, 不抛错)
StatsBall_PurgeStandby() {
    try {
        if (!StatsBall_EnablePrivilege("SeProfileSingleProcessPrivilege"))
            return false
        cmd := Buffer(4, 0)
        NumPut("UInt", 4, cmd, 0)
        return DllCall("ntdll\NtSetSystemInformation", "Int", 80, "Ptr", cmd, "UInt", 4) = 0
    } catch {
        return false
    }
}

; 选择性 trim: 只动工作集 >= minWS 的用户进程, 跳过 Idle/System(pid<=4) 与自身
; 返回实际 trim 的进程数 (全量 trim 是安慰剂且易引发缺页颠簸, 2026 不这么干)
StatsBall_TrimBigWorkingSets(minWS) {
    trimmed := 0
    try {
        selfPid := DllCall("kernel32\GetCurrentProcessId", "UInt")
        hSnap := DllCall("kernel32\CreateToolhelp32Snapshot", "UInt", 0x2, "UInt", 0, "Ptr")
        if (hSnap = -1)
            return 0
        try {
            pe := Buffer(568, 0)
            NumPut("UInt", 568, pe, 0)
            ok := DllCall("kernel32\Process32FirstW", "Ptr", hSnap, "Ptr", pe)
            while (ok) {
                pid := NumGet(pe, 8, "UInt")
                if (pid > 4 && pid != selfPid) {
                    try {
                        hProc := DllCall("kernel32\OpenProcess", "UInt", 0x1400, "Int", 0, "UInt", pid, "Ptr")
                        if (hProc) {
                            try {
                                pmc := Buffer(72, 0)
                                NumPut("UInt", 72, pmc, 0)
                                ws := 0
                                if (DllCall("psapi\GetProcessMemoryInfo", "Ptr", hProc, "Ptr", pmc, "UInt", 72))
                                    ws := NumGet(pmc, 8, "Ptr")
                                if (ws >= minWS) {
                                    DllCall("psapi\EmptyWorkingSet", "Ptr", hProc)
                                    trimmed++
                                }
                            } finally {
                                DllCall("kernel32\CloseHandle", "Ptr", hProc)
                            }
                        }
                    } catch {
                    }
                }
                ok := DllCall("kernel32\Process32NextW", "Ptr", hSnap, "Ptr", pe)
            }
        } finally {
            DllCall("kernel32\CloseHandle", "Ptr", hSnap)
        }
    } catch {
    }
    return trimmed
}

; 一键加速 (2026 最佳实践, 只报真实数):
; 1) 待机缓存 >=100MB 才 purge (小打小闹不折腾, 且 purge 要提权, 不够格直接跳过);
; 2) 只 trim 工作集 >=50MB 的用户进程 (跳过 System/自身);
; 3) 返回 {beforeGB, afterGB, freedMB(实测可用增量), standbyMB(实测待机释放),
;    purged, trimmed} —— 没效果就报 optimal, 不编数字
StatsBall_DoBoost() {
    before := 0
    after := 0
    try {
        st := GlobalMemoryStatusEx()
        if (IsObject(st))
            before := st[3]
    } catch {
    }
    sbBefore := StatsBall_StandbyMB()
    purged := false
    if (sbBefore >= 100) {
        try purged := StatsBall_PurgeStandby()
        catch {
            purged := false
        }
    }
    trimmed := 0
    try trimmed := StatsBall_TrimBigWorkingSets(52428800)
    catch {
        trimmed := 0
    }
    Sleep(400)
    try {
        st2 := GlobalMemoryStatusEx()
        if (IsObject(st2))
            after := st2[3]
    } catch {
    }
    sbAfter := StatsBall_StandbyMB()
    freed := 0
    if (after > before)
        freed := Round((after - before) / 1048576)
    sbFreed := 0
    if (sbAfter < sbBefore)
        sbFreed := sbBefore - sbAfter
    return {beforeGB: Round(before / 1073741824, 1), afterGB: Round(after / 1073741824, 1), freedMB: freed, standbyMB: sbFreed, purged: purged, trimmed: trimmed}
}

; ============================================================
; GDI+ 自绘三段横条 (扁平三色+内存注水+悬停闪电, 白字黑影)
; 经 UpdateLayeredWindow 上屏, 逐像素 Alpha; 失败 (如无 gdiplus) 返回 false,
; 调用方用纯 GDI 实色兜底; 1Hz 小面重绘开销可忽略
; ============================================================
StatsBall_GdipInit() {
    static ok := "", token := 0
    if (ok != "")
        return ok
    try {
        ; GdiplusStartupInput x64 下 24 字节 (version + 对齐填充 + 回调指针 + 2×BOOL),
        ; 给小了堆越界读, 成功率看脸 (实测同一脚本三连 1/0/1)
        si := Buffer(24, 0)
        NumPut("UInt", 1, si, 0)
        if (DllCall("gdiplus\GdiplusStartup", "Ptr*", &token, "Ptr", si, "Ptr", 0) = 0)
            ok := true
        else
            ok := false
    } catch {
        ok := false
    }
    return ok
}

; (球体渲染已彻底删除, 现为纯三段横条, 见 StatsBall_RenderStrip)

StatsBall_DrawTextBox(gfx, txt, argb, x, y, w, h, px, bold := 1, family := "Segoe UI", align := 1) {
    if (txt = "")
        return
    fam := 0
    font := 0
    fmt := 0
    br := 0
    try {
        DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", family, "Ptr", 0, "Ptr*", &fam)
        if (!fam)
            DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", "Segoe UI", "Ptr", 0, "Ptr*", &fam)
        if (!fam)
            return
        DllCall("gdiplus\GdipCreateFont", "Ptr", fam, "Float", px, "Int", bold ? 1 : 0, "Int", 3, "Ptr*", &font)
        DllCall("gdiplus\GdipCreateStringFormat", "Int", 0, "Int", 0, "Ptr*", &fmt)
        ; NoWrap(0x1000): 窄框禁止换行 (之前 "↓311.2"+"K/S" 被折成两行)
        DllCall("gdiplus\GdipSetStringFormatFlags", "Ptr", fmt, "Int", 0x1000)
        DllCall("gdiplus\GdipSetStringFormatAlign", "Ptr", fmt, "Int", align)
        DllCall("gdiplus\GdipSetStringFormatLineAlign", "Ptr", fmt, "Int", 1)
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", argb, "Ptr*", &br)
        rc := Buffer(16, 0)
        NumPut("Float", x, rc, 0)
        NumPut("Float", y, rc, 4)
        NumPut("Float", w, rc, 8)
        NumPut("Float", h, rc, 12)
        DllCall("gdiplus\GdipDrawString", "Ptr", gfx, "WStr", txt, "Int", -1
            , "Ptr", font, "Ptr", rc, "Ptr", fmt, "Ptr", br)
    } finally {
        try {
            if (br)
                DllCall("gdiplus\GdipDeleteBrush", "Ptr", br)
            if (fmt)
                DllCall("gdiplus\GdipDeleteStringFormat", "Ptr", fmt)
            if (font)
                DllCall("gdiplus\GdipDeleteFont", "Ptr", font)
            if (fam)
                DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", fam)
        } catch {
        }
    }
}

; 横条网速单位 (智能阶梯: 静置显 0 K/S 对齐原版; 涓流显 B/s;
; K/S <100 留 1 位小数, ≥100 取整防超宽; 大流量进 M/S)
StatsBall_FormatK(bps) {
    b := Float(bps)
    if (b < 10)
        return "0 K/S"
    if (b < 1024)
        return Format("{:.0f} B/s", b)
    kb := b / 1024
    if (kb < 100)
        return Format("{:.1f} K/S", kb)
    if (kb < 1024)
        return Format("{:.0f} K/S", kb)
    mbs := kb / 1024
    if (mbs < 100)
        return Format("{:.1f} M/S", mbs)
    return Format("{:.0f} M/S", mbs)
}

; 横条文字 (对齐原版: 不加粗, 白字稍淡 0xFFF2F2F2, 阴影同步调淡;
; align: 1 居中, 0 左对齐, 2 右对齐)
StatsBall_StripText(gfx, txt, x, y, w, h, px, bold := 0, family := "Segoe UI", align := 1) {
    if (txt = "")
        return
    StatsBall_DrawTextBox(gfx, txt, 0x66000000, x + 1, y + 1, w, h, px, bold, family, align)
    StatsBall_DrawTextBox(gfx, txt, 0xFFF2F2F2, x, y, w, h, px, bold, family, align)
}

; 横条挂件一帧 (CPU 蓝 / 内存 绿 / 上下行 橙, 内存段水位计), 返回 true=已上屏
; bolt=1 (悬停): 白闪电盖住内存格; hint 文字走原生 ToolTip, 不占窗体
StatsBall_RenderStrip(hwnd, s, w, stripH, opacity, bolt := false) {
    h := stripH
    if (!StatsBall_GdipInit())
        return false
    hdcScr := 0
    hdcMem := 0
    hbm := 0
    oldBm := 0
    gfx := 0
    try {
        cpuTxt := Integer(s.cpu) . "%"
        memTxt := Integer(s.memPct) . "%"
        upVal := StatsBall_FormatK(s.up)
        dnVal := StatsBall_FormatK(s.dn)
        hdcScr := DllCall("User32.dll\GetDC", "Ptr", 0, "Ptr")
        hdcMem := DllCall("Gdi32.dll\CreateCompatibleDC", "Ptr", hdcScr, "Ptr")
        bmi := Buffer(40, 0)
        NumPut("UInt", 40, bmi, 0)
        NumPut("Int", w, bmi, 4)
        NumPut("Int", -h, bmi, 8)
        NumPut("UShort", 1, bmi, 12)
        NumPut("UShort", 32, bmi, 14)
        bits := 0
        hbm := DllCall("Gdi32.dll\CreateDIBSection", "Ptr", hdcMem, "Ptr", bmi
            , "UInt", 0, "Ptr*", &bits, "Ptr", 0, "UInt", 0, "Ptr")
        if (!hbm)
            return false
        oldBm := DllCall("Gdi32.dll\SelectObject", "Ptr", hdcMem, "Ptr", hbm, "Ptr")
        if (DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdcMem, "Ptr*", &gfx) != 0)
            return false
        DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", gfx, "Int", 4)
        DllCall("gdiplus\GdipSetTextRenderingHint", "Ptr", gfx, "Int", 5)
        ; 三段扁平底 + 轻微注水 (对齐参照物: 静置即亮色, 水位只做 subtle 渐变)
        ; CPU/内存按 %, 网速按下行占动态峰值; 水面一条亮线, 文字加阴影保可读
        ; 配比对齐原版: CPU=内存各 ~26% (各 42px), 网速占剩余;
        ; 网速段纯扁平不注水
        seg1 := Round(w * 0.26)
        seg2 := seg1
        netW := w - seg1 - seg2
        ; 实测取色 (2026-09): 蓝 #23A1C4 / 绿 #61AE12 / 注水绿 #85BE51 / 橘 #E38C14
        ; CPU 与内存同色注水 (#85BE51), 橘段纯扁平
        fracs := [Float(s.cpu) / 100, Float(s.memPct) / 100, 0]
        segs := [{x: 0, w: seg1, c: 0xFF23A1C4, wc: 0xFF85BE51}, {x: seg1, w: seg2, c: 0xFF61AE12, wc: 0xFF85BE51}, {x: seg1 + seg2, w: netW, c: 0xFFE38C14, wc: 0xFFE38C14}]
        fi := 0
        for _, sg in segs {
            fi++
            frac := fracs[fi]
            if (frac > 1)
                frac := 1
            if (frac < 0)
                frac := 0
            ; 扁平底: 直接用原色, 静置也是亮色 (之前 Shade -22 全暗是差别主因)
            eb := 0
            DllCall("gdiplus\GdipCreateSolidFill", "UInt", sg.c, "Ptr*", &eb)
            DllCall("gdiplus\GdipFillRectangle", "Ptr", gfx, "Ptr", eb
                , "Float", sg.x, "Float", 0, "Float", sg.w, "Float", stripH)
            DllCall("gdiplus\GdipDeleteBrush", "Ptr", eb)
            ; 注水 (实色平涂, 无渐变无水面线, 对齐原版)
            fillH := Round(frac * stripH)
            if (fillH > stripH)
                fillH := stripH
            if (fillH >= 2) {
                fy := stripH - fillH
                wb := 0
                DllCall("gdiplus\GdipCreateSolidFill", "UInt", sg.wc, "Ptr*", &wb)
                DllCall("gdiplus\GdipFillRectangle", "Ptr", gfx, "Ptr", wb
                    , "Float", sg.x, "Float", fy, "Float", sg.w, "Float", fillH)
                DllCall("gdiplus\GdipDeleteBrush", "Ptr", wb)
            }
        }
        ; 外圈细描边 (格子间不画分隔线, 对齐原版无黑缝)
        fr := 0
        DllCall("gdiplus\GdipCreatePen1", "UInt", 0x55000000, "Float", 1, "Int", 3, "Ptr*", &fr)
        DllCall("gdiplus\GdipDrawRectangle", "Ptr", gfx, "Ptr", fr
            , "Float", 0.5, "Float", 0.5, "Float", w - 1, "Float", h - 1)
        DllCall("gdiplus\GdipDeletePen", "Ptr", fr)
        ; 白字 (整数坐标防糊, 黑影保水面可读): 标题 10px 置顶半区, 数值 14px 置底半区;
        ; 网络段上下行 9px 各占一半; 中文走 YaHei 更锐; 左右各留 2px 防截断
        halfH := stripH // 2
        tH := halfH - 1
        vY := halfH
        vH := stripH - halfH + 1
        ; 窄框 11px 保 "%" 不被 NoWrap 裁掉; 全段不加粗对齐原版
        valPx := (seg1 < 60 || stripH < 44) ? 11 : 13
        StatsBall_StripText(gfx, "CPU", 2, 1, seg1 - 4, tH, 9, 0)
        StatsBall_StripText(gfx, cpuTxt, 2, vY, seg1 - 4, vH, valPx, 0)
        StatsBall_StripText(gfx, T("statsball.seg_mem"), seg1 + 2, 1, seg2 - 4, tH, 9, 0, "Microsoft YaHei UI")
        StatsBall_StripText(gfx, memTxt, seg1 + 2, vY, seg2 - 4, vH, valPx, 0)
        ; 网速段对齐原版 (左 space 右): 箭头固定左列 (纵向对称),
        ; 数值右对齐 (单位纵向对齐, 长短不一也不乱)
        nx := seg1 + seg2
        netPx := (netW < 68) ? 8 : 9
        ; 箭头对齐原版: 比数值大 3px + 加粗, 实心感 (数值保持不加粗)
        arrowPx := netPx + 3
        StatsBall_StripText(gfx, "↑", nx + 5, 1, 12, tH, arrowPx, 1, "Segoe UI", 0)
        StatsBall_StripText(gfx, upVal, nx + 17, 1, netW - 17 - 4, tH, netPx, 0, "Segoe UI", 2)
        StatsBall_StripText(gfx, "↓", nx + 5, vY, 12, vH, arrowPx, 1, "Segoe UI", 0)
        StatsBall_StripText(gfx, dnVal, nx + 17, vY, netW - 17 - 4, vH, netPx, 0, "Segoe UI", 2)
        ; 悬停闪电 (复刻软媒: 白闪电盖住整个内存格, 文字被盖住)
        if (bolt) {
            bx := seg1 + 5
            by := 3
            bw := seg2 - 10
            bh := stripH - 6
            coords := [[0.60, 0.00], [0.18, 0.58], [0.44, 0.58], [0.34, 1.00], [0.82, 0.40], [0.54, 0.40]]
            pts := Buffer(48, 0)
            for i, pt in coords {
                NumPut("Float", bx + pt[1] * bw, pts, (i - 1) * 8)
                NumPut("Float", by + pt[2] * bh, pts, (i - 1) * 8 + 4)
            }
            bb := 0
            DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFFFFFFFF, "Ptr*", &bb)
            DllCall("gdiplus\GdipFillPolygon", "Ptr", gfx, "Ptr", bb, "Ptr", pts, "Int", 6, "Int", 0)
            DllCall("gdiplus\GdipDeleteBrush", "Ptr", bb)
            bp := 0
            DllCall("gdiplus\GdipCreatePen1", "UInt", 0xBB000000, "Float", 1, "Int", 3, "Ptr*", &bp)
            DllCall("gdiplus\GdipDrawPolygon", "Ptr", gfx, "Ptr", bp, "Ptr", pts, "Int", 6)
            DllCall("gdiplus\GdipDeletePen", "Ptr", bp)
        }
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gfx)
        gfx := 0
        ptSrc := Buffer(8, 0)
        szWin := Buffer(8, 0)
        NumPut("Int", w, szWin, 0)
        NumPut("Int", h, szWin, 4)
        blend := Buffer(4, 0)
        NumPut("UChar", 0, blend, 0)
        NumPut("UChar", 0, blend, 1)
        NumPut("UChar", opacity, blend, 2)
        NumPut("UChar", 1, blend, 3)
        DllCall("User32.dll\UpdateLayeredWindow", "Ptr", hwnd, "Ptr", hdcScr
            , "Ptr", 0, "Ptr", szWin, "Ptr", hdcMem, "Ptr", ptSrc
            , "UInt", 0, "Ptr", blend, "UInt", 2)
        DllCall("Gdi32.dll\SelectObject", "Ptr", hdcMem, "Ptr", oldBm)
        oldBm := 0
        DllCall("Gdi32.dll\DeleteObject", "Ptr", hbm)
        hbm := 0
        DllCall("Gdi32.dll\DeleteDC", "Ptr", hdcMem)
        hdcMem := 0
        DllCall("User32.dll\ReleaseDC", "Ptr", 0, "Ptr", hdcScr)
        hdcScr := 0
        return true
    } catch {
        return false
    } finally {
        try {
            if (gfx)
                DllCall("gdiplus\GdipDeleteGraphics", "Ptr", gfx)
            if (oldBm)
                DllCall("Gdi32.dll\SelectObject", "Ptr", hdcMem, "Ptr", oldBm)
            if (hbm)
                DllCall("Gdi32.dll\DeleteObject", "Ptr", hbm)
            if (hdcMem)
                DllCall("Gdi32.dll\DeleteDC", "Ptr", hdcMem)
            if (hdcScr)
                DllCall("User32.dll\ReleaseDC", "Ptr", 0, "Ptr", hdcScr)
        } catch {
        }
    }
}

; strip 回落兜底 (纯 GDI, 无 GDI+ 依赖): 实色矩形上屏, 宁可没字也不隐身
; GDI+ 失败 / ULW 异常时调用, 保证窗口可见
StatsBall_FallbackStrip(hwnd, w, h, opacity) {
    hdcScr := 0
    hdcMem := 0
    hbm := 0
    oldBm := 0
    try {
        hdcScr := DllCall("User32.dll\GetDC", "Ptr", 0, "Ptr")
        hdcMem := DllCall("Gdi32.dll\CreateCompatibleDC", "Ptr", hdcScr, "Ptr")
        bmi := Buffer(40, 0)
        NumPut("UInt", 40, bmi, 0)
        NumPut("Int", w, bmi, 4)
        NumPut("Int", -h, bmi, 8)
        NumPut("UShort", 1, bmi, 12)
        NumPut("UShort", 32, bmi, 14)
        bits := 0
        hbm := DllCall("Gdi32.dll\CreateDIBSection", "Ptr", hdcMem, "Ptr", bmi
            , "UInt", 0, "Ptr*", &bits, "Ptr", 0, "UInt", 0, "Ptr")
        if (!hbm || !bits)
            return false
        oldBm := DllCall("Gdi32.dll\SelectObject", "Ptr", hdcMem, "Ptr", hbm, "Ptr")
        ; 三段实色直接写像素 (ARGB, 不依赖 GDI+)
        cols := [0xFF23A1C4, 0xFF61AE12, 0xFFE38C14]
        seg1 := Round(w * 0.26)
        seg2 := seg1
        netW := w - seg1 - seg2
        widths := [seg1, seg2, netW]
        p := bits
        y := 0
        while (y < h) {
            x := 0
            si := 0
            for _, sw in widths {
                si++
                c := cols[si]
                xi := 0
                while (xi < sw && x < w) {
                    NumPut("UInt", c, p, 0)
                    p += 4
                    x++
                    xi++
                }
            }
            y++
        }
        szWin := Buffer(8, 0)
        NumPut("Int", w, szWin, 0)
        NumPut("Int", h, szWin, 4)
        ptSrc := Buffer(8, 0)
        blend := Buffer(4, 0)
        NumPut("UChar", 0, blend, 0)
        NumPut("UChar", 0, blend, 1)
        NumPut("UChar", opacity, blend, 2)
        NumPut("UChar", 1, blend, 3)
        DllCall("User32.dll\UpdateLayeredWindow", "Ptr", hwnd, "Ptr", hdcScr
            , "Ptr", 0, "Ptr", szWin, "Ptr", hdcMem, "Ptr", ptSrc
            , "UInt", 0, "Ptr", blend, "UInt", 2)
        DllCall("Gdi32.dll\SelectObject", "Ptr", hdcMem, "Ptr", oldBm)
        oldBm := 0
        DllCall("Gdi32.dll\DeleteObject", "Ptr", hbm)
        hbm := 0
        DllCall("Gdi32.dll\DeleteDC", "Ptr", hdcMem)
        hdcMem := 0
        DllCall("User32.dll\ReleaseDC", "Ptr", 0, "Ptr", hdcScr)
        hdcScr := 0
        return true
    } catch {
        return false
    } finally {
        try {
            if (oldBm)
                DllCall("Gdi32.dll\SelectObject", "Ptr", hdcMem, "Ptr", oldBm)
            if (hbm)
                DllCall("Gdi32.dll\DeleteObject", "Ptr", hbm)
            if (hdcMem)
                DllCall("Gdi32.dll\DeleteDC", "Ptr", hdcMem)
            if (hdcScr)
                DllCall("User32.dll\ReleaseDC", "Ptr", 0, "Ptr", hdcScr)
        } catch {
        }
    }
}

; 挂件中心所在的显示器工作区, 找不到回主屏
StatsBall_MonRect(cx, cy) {
    try {
        n := MonitorGetCount()
        first := ""
        Loop n {
            MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
            if (first = "")
                first := {l: l, t: t, r: r, b: b}
            if (cx >= l && cx <= r && cy >= t && cy <= b)
                return {l: l, t: t, r: r, b: b}
        }
        if (first != "")
            return first
    } catch {
    }
    sw := 1920
    sh := 1080
    try {
        sw := SysGet(78)
        sh := SysGet(79)
    } catch {
    }
    return {l: 0, t: 0, r: sw, b: sh}
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
        ; Top进程按需刷新: 面板每 tick 都刷太贵, 仅 key 变化大时刷
        try {
            rows := StatsBall_TopProcs(3)
            t := ""
            for _, r in rows
                t .= r.exe . "  " . Round(r.ws / 1048576) . "MB`n"
            if (t = "")
                t := T("statsball.top_empty")
            this.panelTop.Value := T("statsball.top_title") . "`n" . t
        } catch {
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
