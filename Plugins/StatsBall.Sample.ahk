#Requires AutoHotkey v2.0
#Warn All, Off

; === StatsBall.Sample - 采样层 (CPU/内存/网速/Top进程/Boost数据, 纯函数, 组装见 StatsBall.ahk) ===


; ============================================================
; 采样层
; ============================================================
StatsBall_Sample() {
    static cache := {cpu: 0, memPct: 0, availGB: 0, totalGB: 0, up: 0, dn: 0,
        rawUp: 0, rawDn: 0, peakUp: 0, peakDn: 0, netDt: 0, netValid: 0}
    static sampleTick := 0
    now := DllCall("kernel32\GetTickCount64", "UInt64")
    if (sampleTick && now - sampleTick < 100)
        return cache
    sampleTick := now
    cpu := 0
    try cpu := CPULoad()
    catch {
        cpu := cache.cpu
    }
    memPct := cache.memPct
    availGB := cache.availGB
    totalGB := cache.totalGB
    try {
        if (GlobalMemoryStatusFast(&total, &avail, &load)) {
            memPct := load
            availGB := Round(avail / 1073741824, 1)
            totalGB := Round(total / 1073741824, 1)
        }
    } catch {
    }
    net := ""
    try net := StatsBall_NetRate()
    catch {
        net := ""
    }
    cache.cpu := cpu
    cache.memPct := memPct
    cache.availGB := availGB
    cache.totalGB := totalGB
    if IsObject(net) {
        cache.up := net.up
        cache.dn := net.dn
        cache.rawUp := net.rawUp
        cache.rawDn := net.rawDn
        cache.peakUp := net.peakUp
        cache.peakDn := net.peakDn
        cache.netDt := net.dt
        cache.netValid := net.valid
    }
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

; GetIfTable2 聚合活动接口速率 (调用方 try 包裹; 首 tick 返回 0)
; 偏移经 Python+ctypes 按 MSVC 对齐实测标定 (2026-09, 31 口本机双向激励):
; tableOff=8(NumEntries 后 4 字节对齐填充), rowSize=1352, Type@1128,
; OperStatus@1112+44=1156(1=up), InOctets@1208, OutOctets@1280
; (旧值 @1312 实测恒零, 系 OutDiscards/Errors 区 —— 上行永远 0 的根因;
;  定量 ping+下载激励下 @1280/+14064 与包计数 @1288/+108 同步涨, 自洽;
;  @1256/@1320 为单播镜像, 求和时靠 (rx,tx) 去重消除)
; 注意: 虚拟层叠口 (QoS/WFP/虚拟交换机) 会镜像同一计数器, 先按 (rx,tx)
; 去重, 再按 Luid 逐口跟踪求差分, 否则网速 ×N; 回环口 (Type=24) 排除.
; 返回 rawUp/rawDn (瞬时差分), up/dn (EMA 平滑), peakUp/peakDn (衰减峰值).
StatsBall_NetRate() {
    ; 逐口 Luid 跟踪: 只统计新老快照都存在的口子, 新口/消失口不贡献差分
    ; (WiFi 重连/休眠唤醒/VPN 插拔时接口集合突变, 聚合求和会把新口的累计值
    ;  一次算进 1s 差分 —— 949M 这类野值的根因)
    static prevLuid := [], prevRx := [], prevTx := [], prevCount := 0, prevTick := 0
    static curLuid := [], curRx := [], curTx := [], curCount := 0
    static seenRx := [], seenTx := [], seenCount := 0
    static result := {up: 0, dn: 0, rawUp: 0, rawDn: 0, peakUp: 0, peakDn: 0,
        dt: 0, interfaces: 0, valid: 0}
    static smoothUp := 0.0, smoothDn := 0.0, peakUp := 0.0, peakDn := 0.0
    static hasRate := false
    rowSize := 1352
    tableOff := 8
    typeOff := 1128
    operOff := 1156
    inOff := 1208
    outOff := 1280
    pTable := 0
    hr := DllCall("iphlpapi\GetIfTable2", "Ptr*", &pTable, "UInt")
    if (hr != 0 || !pTable) {
        StatsBall_NetResetResult(&result, &smoothUp, &smoothDn, &peakUp, &peakDn, &hasRate)
        return result
    }
    curLuid.Length := 0
    curRx.Length := 0
    curTx.Length := 0
    curCount := 0
    seenRx.Length := 0
    seenTx.Length := 0
    seenCount := 0
    try {
        num := NumGet(pTable, 0, "UInt")
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
                duplicate := false
                j := 1
                while (j <= seenCount) {
                    if (seenRx[j] = r && seenTx[j] = t) {
                        duplicate := true
                        break
                    }
                    j++
                }
                if (duplicate)
                    continue
                seenCount++
                seenRx.Push(r)
                seenTx.Push(t)
                curCount++
                curLuid.Push(NumGet(base, 0, "UInt64"))
                curRx.Push(r)
                curTx.Push(t)
            } catch {
            }
        }
    } finally {
        DllCall("iphlpapi\FreeMibTable", "Ptr", pTable)
    }
    ; Use the Win32 64-bit clock directly. Older AutoHotkey v2 builds do not
    ; expose A_TickCount64; an unset variable would make every delta invalid.
    now := DllCall("kernel32\GetTickCount64", "UInt64")
    if (prevTick = 0 || prevCount = 0) {
        tmp := prevLuid, prevLuid := curLuid, curLuid := tmp
        tmp := prevRx, prevRx := curRx, curRx := tmp
        tmp := prevTx, prevTx := curTx, curTx := tmp
        prevCount := curCount
        prevTick := now
        StatsBall_NetResetResult(&result, &smoothUp, &smoothDn, &peakUp, &peakDn, &hasRate)
        result.interfaces := curCount
        return result
    }
    dt := (now - prevTick) / 1000.0
    if (dt < 0.05 || dt > 10.0) {
        tmp := prevLuid, prevLuid := curLuid, curLuid := tmp
        tmp := prevRx, prevRx := curRx, curRx := tmp
        tmp := prevTx, prevTx := curTx, curTx := tmp
        prevCount := curCount
        prevTick := now
        StatsBall_NetResetResult(&result, &smoothUp, &smoothDn, &peakUp, &peakDn, &hasRate)
        result.interfaces := curCount
        return result
    }
    dRx := 0
    dTx := 0
    validRx := 0
    validTx := 0
    common := 0
    maxDelta := 12500000000 * dt ; 100 Gbps per interface, protects reset spikes
    i := 1
    while (i <= curCount) {
        j := 1
        while (j <= prevCount && prevLuid[j] != curLuid[i])
            j++
        if (j <= prevCount) {
            common++
            ; 单口计数器回绕/清零: 该方向本轮贡献 0, 基线照常更新.
            dr := curRx[i] - prevRx[j]
            dt2 := curTx[i] - prevTx[j]
            if (dr >= 0 && dr <= maxDelta) {
                dRx += dr
                validRx++
            }
            if (dt2 >= 0 && dt2 <= maxDelta) {
                dTx += dt2
                validTx++
            }
        }
        i++
    }
    tmp := prevLuid, prevLuid := curLuid, curLuid := tmp
    tmp := prevRx, prevRx := curRx, curRx := tmp
    tmp := prevTx, prevTx := curTx, curTx := tmp
    prevCount := curCount
    prevTick := now
    rawUp := validTx > 0 ? dTx / dt : 0.0
    rawDn := validRx > 0 ? dRx / dt : 0.0
    if (common = 0) {
        StatsBall_NetResetResult(&result, &smoothUp, &smoothDn, &peakUp, &peakDn, &hasRate)
        result.interfaces := curCount
    } else {
        alpha := 1 - Exp(-dt / 1.25)
        if (!hasRate) {
            smoothUp := rawUp
            smoothDn := rawDn
            hasRate := true
        } else {
            smoothUp += alpha * (rawUp - smoothUp)
            smoothDn += alpha * (rawDn - smoothDn)
        }
        peakUp := Max(rawUp, peakUp * Exp(-dt / 8.0))
        peakDn := Max(rawDn, peakDn * Exp(-dt / 8.0))
        result.rawUp := rawUp
        result.rawDn := rawDn
        result.up := smoothUp
        result.dn := smoothDn
        result.peakUp := peakUp
        result.peakDn := peakDn
        result.dt := dt
        result.interfaces := curCount
        result.valid := common
    }
    return result
}

StatsBall_NetResetResult(&result, &smoothUp, &smoothDn, &peakUp, &peakDn, &hasRate) {
    smoothUp := 0.0
    smoothDn := 0.0
    peakUp := 0.0
    peakDn := 0.0
    hasRate := false
    result.up := 0
    result.dn := 0
    result.rawUp := 0
    result.rawDn := 0
    result.peakUp := 0
    result.peakDn := 0
    result.dt := 0
    result.interfaces := 0
    result.valid := 0
}

; Top-N 内存进程 (Toolhelp 快照, 无 WMI; 仅面板打开时调用)
; PROCESSENTRY32W 实测布局 (ctypes+内核双验证, 2026-09): cbSize=568
; (pcPriClassBase 占 8 字节!), pid@8, exe@40+4=44; cb 不对即 A_LastError=24
StatsBall_TopProcs(n := 3) {
    out := []
    if (n < 1)
        return out
    try {
        hSnap := DllCall("kernel32\CreateToolhelp32Snapshot", "UInt", 0x2, "UInt", 0, "Ptr")
        if (hSnap = -1)
            return out
        try {
            static pe := Buffer(568, 0), pmc := Buffer(72, 0)
            topExe := []
            topWs := []
            topPid := []
            NumPut("UInt", 568, pe, 0)
            ok := DllCall("kernel32\Process32FirstW", "Ptr", hSnap, "Ptr", pe)
            while (ok) {
                pid := NumGet(pe, 8, "UInt")
                exe := StrGet(pe.Ptr + 44, 260)
                ws := 0
                try {
                    hProc := DllCall("kernel32\OpenProcess", "UInt", 0x1000, "Int", 0, "UInt", pid, "Ptr")
                    if (hProc) {
                        try {
                            NumPut("UInt", 72, pmc, 0)
                            if (DllCall("psapi\GetProcessMemoryInfo", "Ptr", hProc, "Ptr", pmc, "UInt", 72))
                                ws := NumGet(pmc, 8, "Ptr")
                        } finally {
                            DllCall("kernel32\CloseHandle", "Ptr", hProc)
                        }
                    }
                } catch {
                }
                if (exe != "" && ws > 0) {
                    pos := 1
                    while (pos <= topWs.Length && topWs[pos] >= ws)
                        pos++
                    if (pos <= n) {
                        topWs.InsertAt(pos, ws)
                        topExe.InsertAt(pos, exe)
                        topPid.InsertAt(pos, pid)
                        if (topWs.Length > n) {
                            topWs.Pop()
                            topExe.Pop()
                            topPid.Pop()
                        }
                    }
                }
                ok := DllCall("kernel32\Process32NextW", "Ptr", hSnap, "Ptr", pe)
            }
            for i, ws in topWs
                out.Push({exe: topExe[i], ws: ws, pid: topPid[i]})
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

