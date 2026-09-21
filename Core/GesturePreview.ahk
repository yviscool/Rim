#Requires AutoHotkey v2.0
#Warn All, Off

; === GesturePreview - 手势线条预览 (GDI 离屏位图) ===
; 把方向链 (D_R) / 模板点列画成小预览图, 供管理器列表选中与编辑框实时显示.
; 用法: hbm := GesturePreview_Chain("D_R", 120, 120)
;       GesturePreview_SetPic(picCtrl, hbm)
; 旧位图由模块按控件 HWND 跟踪并释放, 调用方不用管.

global g_PreviewBmps := Map()

; ---- 方向向量 (屏幕坐标 y 向下), 对角归一化 ----
GesturePreview_DirVec(d) {
    if (d = "R")
        return [1.0, 0.0]
    if (d = "L")
        return [-1.0, 0.0]
    if (d = "U")
        return [0.0, -1.0]
    if (d = "D")
        return [0.0, 1.0]
    if (d = "UR")
        return [0.7071, -0.7071]
    if (d = "UL")
        return [-0.7071, -0.7071]
    if (d = "DR")
        return [0.7071, 0.7071]
    if (d = "DL")
        return [-0.7071, 0.7071]
    return ""
}

; ---- 是否可画 / 描述文本. 返回 [可画, 描述] ----
GesturePreview_ChainInfo(key) {
    key := Trim(key)
    if (key = "")
        return [false, ""]
    up := StrUpper(key)
    up := StrReplace(up, " ", "")
    if InStr(up, "WHEEL") {
        desc := "滚轮手势"
        if InStr(up, "WHEELUP")
            desc := "滚轮: 上滚"
        else if InStr(up, "WHEELDOWN")
            desc := "滚轮: 下滚"
        else if InStr(up, "WHEELLEFT")
            desc := "滚轮: 左滚"
        else if InStr(up, "WHEELRIGHT")
            desc := "滚轮: 右滚"
        if InStr(up, "CTRL+")
            desc .= " (Ctrl)"
        if InStr(up, "ALT+")
            desc .= " (Alt)"
        if InStr(up, "SHIFT+")
            desc .= " (Shift)"
        return [false, desc]
    }
    ; 去修饰前缀, 取最后一段
    parts := StrSplit(up, "+")
    body := parts[parts.Length]
    segs := StrSplit(body, "_")
    if (segs.Length = 0)
        return [false, key]
    for i, s in segs {
        if (GesturePreview_DirVec(s) = "")
            return [false, key]
    }
    mods := ""
    i := 1
    while (i < parts.Length) {
        p := parts[i]
        if (p = "CTRL" || p = "CONTROL" || p = "C")
            mods .= "Ctrl+"
        else if (p = "ALT" || p = "A")
            mods .= "Alt+"
        else if (p = "SHIFT" || p = "S")
            mods .= "Shift+"
        i++
    }
    return [true, mods . body]
}

; ---- 方向链 -> 点列 (起点 0,0, 步长 30) ----
GesturePreview_ChainPoints(key) {
    info := GesturePreview_ChainInfo(key)
    if (!info[1])
        return []
    up := StrUpper(StrReplace(Trim(key), " ", ""))
    parts := StrSplit(up, "+")
    segs := StrSplit(parts[parts.Length], "_")
    pts := [{x: 0.0, y: 0.0}]
    cx := 0.0
    cy := 0.0
    for i, s in segs {
        v := GesturePreview_DirVec(s)
        cx += v[1] * 30
        cy += v[2] * 30
        pts.Push({x: cx, y: cy})
    }
    return pts
}

; ---- 点列 -> 位图句柄 (0=失败). 起点绿, 终点红箭头 ----
GesturePreview_PointsBitmap(pts, w, h) {
    if (!IsObject(pts) || pts.Length < 2 || w <= 0 || h <= 0)
        return 0
    hdcScr := DllCall("GetDC", "Ptr", 0, "Ptr")
    if (!hdcScr)
        return 0
    hbm := 0
    try {
        hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdcScr, "Ptr")
        hbm := DllCall("CreateCompatibleBitmap", "Ptr", hdcScr, "Int", w, "Int", h, "Ptr")
        oldBm := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hbm, "Ptr")
        ; 白底
        DllCall("FillRect", "Ptr", hdcMem, "Ptr", GesturePreview_MakeRect(0, 0, w, h), "Ptr", DllCall("GetStockObject", "Int", 0, "Ptr"))
        ; 缩放到框 (留边 14)
        minX := pts[1].x
        maxX := pts[1].x
        minY := pts[1].y
        maxY := pts[1].y
        for i, p in pts {
            if (p.x < minX)
                minX := p.x
            if (p.x > maxX)
                maxX := p.x
            if (p.y < minY)
                minY := p.y
            if (p.y > maxY)
                maxY := p.y
        }
        bw := maxX - minX
        bh := maxY - minY
        sc := 1.0
        if (bw > 0 && (w - 28) / bw < sc)
            sc := (w - 28) / bw
        if (bh > 0 && (h - 28) / bh < sc)
            sc := (h - 28) / bh
        ox := (w - bw * sc) / 2 - minX * sc
        oy := (h - bh * sc) / 2 - minY * sc
        sx := []
        for i, p in pts
            sx.Push([Round(ox + p.x * sc), Round(oy + p.y * sc)])
        ; 折线 (蓝, 3px)
        pen := DllCall("CreatePen", "Int", 0, "Int", 3, "UInt", 0xDC781E, "Ptr")
        oldPen := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", pen, "Ptr")
        DllCall("MoveToEx", "Ptr", hdcMem, "Int", sx[1][1], "Int", sx[1][2], "Ptr", 0)
        i := 2
        while (i <= sx.Length) {
            DllCall("LineTo", "Ptr", hdcMem, "Int", sx[i][1], "Int", sx[i][2])
            i++
        }
        DllCall("SelectObject", "Ptr", hdcMem, "Ptr", oldPen)
        DllCall("DeleteObject", "Ptr", pen)
        ; 起点绿点
        GesturePreview_Dot(hdcMem, sx[1][1], sx[1][2], 5, 0x00A000)
        ; 终点红箭头
        n := sx.Length
        ang := 0.0
        try {
            ang := DllCall("msvcrt\atan2", "Double", sx[n][2] - sx[n-1][2], "Double", sx[n][1] - sx[n-1][1], "Cdecl Double")
        } catch {
            ang := 0.0
        }
        GesturePreview_Dot(hdcMem, sx[n][1], sx[n][2], 5, 0x0000CC)
        if (sx[n][1] != sx[n-1][1] || sx[n][2] != sx[n-1][2]) {
            pen2 := DllCall("CreatePen", "Int", 0, "Int", 3, "UInt", 0x0000CC, "Ptr")
            oldPen2 := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", pen2, "Ptr")
            a1 := ang + 2.62
            a2 := ang - 2.62
            DllCall("MoveToEx", "Ptr", hdcMem, "Int", sx[n][1], "Int", sx[n][2], "Ptr", 0)
            DllCall("LineTo", "Ptr", hdcMem, "Int", Round(sx[n][1] + 12 * Cos(a1)), "Int", Round(sx[n][2] + 12 * Sin(a1)))
            DllCall("MoveToEx", "Ptr", hdcMem, "Int", sx[n][1], "Int", sx[n][2], "Ptr", 0)
            DllCall("LineTo", "Ptr", hdcMem, "Int", Round(sx[n][1] + 12 * Cos(a2)), "Int", Round(sx[n][2] + 12 * Sin(a2)))
            DllCall("SelectObject", "Ptr", hdcMem, "Ptr", oldPen2)
            DllCall("DeleteObject", "Ptr", pen2)
        }
        DllCall("SelectObject", "Ptr", hdcMem, "Ptr", oldBm)
        DllCall("DeleteDC", "Ptr", hdcMem)
    } catch {
        if (hbm) {
            try DllCall("DeleteObject", "Ptr", hbm)
            catch {
            }
            hbm := 0
        }
    }
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScr)
    return hbm
}

GesturePreview_MakeRect(l, t, r, b) {
    rc := Buffer(16, 0)
    NumPut("Int", l, rc, 0)
    NumPut("Int", t, rc, 4)
    NumPut("Int", r, rc, 8)
    NumPut("Int", b, rc, 12)
    return rc
}

GesturePreview_Dot(hdc, x, y, rad, color) {
    try {
        br := DllCall("CreateSolidBrush", "UInt", color, "Ptr")
        oldBr := DllCall("SelectObject", "Ptr", hdc, "Ptr", br, "Ptr")
        DllCall("Ellipse", "Ptr", hdc, "Int", x - rad, "Int", y - rad, "Int", x + rad, "Int", y + rad)
        DllCall("SelectObject", "Ptr", hdc, "Ptr", oldBr)
        DllCall("DeleteObject", "Ptr", br)
    } catch {
    }
}

; ---- 方向链 -> 位图 (不可画返回 0) ----
GesturePreview_Chain(key, w, h) {
    pts := GesturePreview_ChainPoints(key)
    if (pts.Length < 2)
        return 0
    return GesturePreview_PointsBitmap(pts, w, h)
}

; ---- 模板名 -> 位图 (0=无模板) ----
GesturePreview_Template(name, w, h) {
    try {
        t := Tpl_Get(name)
        if (!IsObject(t) || t.samples.Length = 0)
            return 0
        return GesturePreview_PointsBitmap(t.samples[1], w, h)
    } catch {
        return 0
    }
}

; ---- 点串 (x1,y1 x2,y2 ...) -> 位图 ----
GesturePreview_Encoded(enc, w, h) {
    try {
        pts := Tpl_Decode(enc)
        if (pts.Length < 2)
            return 0
        return GesturePreview_PointsBitmap(pts, w, h)
    } catch {
        return 0
    }
}

; ---- 显示到位图控件, 自动释放旧图 ----
GesturePreview_SetPic(pic, hbm) {
    global g_PreviewBmps
    try {
        hwnd := pic.Hwnd
        if (g_PreviewBmps.Has(hwnd)) {
            old := g_PreviewBmps[hwnd]
            if (old) {
                try DllCall("DeleteObject", "Ptr", old)
                catch {
                }
            }
            g_PreviewBmps.Delete(hwnd)
        }
        if (hbm) {
            DllCall("SendMessage", "Ptr", hwnd, "UInt", 0x0172, "Ptr", 0, "Ptr", hbm)
            g_PreviewBmps[hwnd] := hbm
        } else {
            DllCall("SendMessage", "Ptr", hwnd, "UInt", 0x0172, "Ptr", 0, "Ptr", 0)
        }
    } catch {
    }
}
