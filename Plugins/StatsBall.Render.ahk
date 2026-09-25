#Requires AutoHotkey v2.0
#Warn All, Off

; === StatsBall.Render - GDI+ 自绘三段横条 (纯函数, 组装见 StatsBall.ahk) ===

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

