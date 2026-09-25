#Requires AutoHotkey v2.0
#Warn All, Off

; === Core/Gesture/Recognizer.ahk - 纯算法手势特征量化器 (Pure Math & Quantizer) ===
; 无任何 UI 依赖与全局状态耦合，专注于点阵滤波、几何角计算与 8 方向离散化

class GestureRecognizer {
    ; ---- 向量 -> 8 方向 (屏幕坐标 y 向下, atan2(-dy,dx) 转数学角) ----
    static DirOf(dx, dy) {
        deg := 0.0
        try {
            rad := DllCall("msvcrt\atan2", "Double", -dy, "Double", dx, "Cdecl Double")
            deg := rad * 57.29577951308232
        } catch {
            if (Abs(dx) >= Abs(dy))
                return dx > 0 ? "R" : "L"
            return dy > 0 ? "D" : "U"
        }
        if (deg >= -22.5 && deg < 22.5)
            return "R"
        if (deg >= 22.5 && deg < 67.5)
            return "UR"
        if (deg >= 67.5 && deg < 112.5)
            return "U"
        if (deg >= 112.5 && deg < 157.5)
            return "UL"
        if (deg >= 157.5 || deg < -157.5)
            return "L"
        if (deg >= -157.5 && deg < -112.5)
            return "DL"
        if (deg >= -112.5 && deg < -67.5)
            return "D"
        return "DR"
    }

    ; ---- 轨迹简化: Ramer-Douglas-Peucker 降噪，压制微小抖动 ----
    static Simplify(pts, tolerance := 4.0) {
        if (!IsObject(pts) || pts.Length < 3)
            return pts
        kept := Map(1, 1, pts.Length, 1)
        stack := [[1, pts.Length]]
        while (stack.Length > 0) {
            seg := stack.Pop()
            i0 := seg[1], i1 := seg[2]
            maxD := 0.0, maxIdx := 0
            x0 := pts[i0].x, y0 := pts[i0].y
            x1 := pts[i1].x, y1 := pts[i1].y
            dx := x1 - x0, dy := y1 - y0
            lineLenSq := dx * dx + dy * dy
            i := i0 + 1
            while (i < i1) {
                px := pts[i].x, py := pts[i].y
                if (lineLenSq = 0) {
                    dist := Sqrt((px - x0) ** 2 + (py - y0) ** 2)
                } else {
                    t := ((px - x0) * dx + (py - y0) * dy) / lineLenSq
                    t := Max(0.0, Min(1.0, t))
                    projX := x0 + t * dx, projY := y0 + t * dy
                    dist := Sqrt((px - projX) ** 2 + (py - projY) ** 2)
                }
                if (dist > maxD) {
                    maxD := dist
                    maxIdx := i
                }
                i++
            }
            if (maxD > tolerance && maxIdx > 0) {
                kept[maxIdx] := 1
                if (maxIdx - i0 > 1)
                    stack.Push([i0, maxIdx])
                if (i1 - maxIdx > 1)
                    stack.Push([maxIdx, i1])
            }
        }
        res := []
        i := 1
        while (i <= pts.Length) {
            if (kept.Has(i))
                res.Push(pts[i])
            i++
        }
        return res
    }

    ; ---- 几何包围盒 ----
    static BBox(pts) {
        if (!IsObject(pts) || pts.Length = 0)
            return [0, 0, 0, 0]
        minX := pts[1].x, maxX := pts[1].x
        minY := pts[1].y, maxY := pts[1].y
        for _, p in pts {
            if (p.x < minX)
                minX := p.x
            if (p.x > maxX)
                maxX := p.x
            if (p.y < minY)
                minY := p.y
            if (p.y > maxY)
                maxY := p.y
        }
        return [minX, minY, maxX, maxY]
    }

    ; ---- V/InvV 尖点特征分析 ----
    static ChevronApex(corners, idx, size) {
        if (idx <= 1 || idx >= corners.Length)
            return false
        first := corners[1]
        apex := corners[idx]
        last := corners[corners.Length]
        leftDx := apex.x - first.x
        rightDx := last.x - apex.x
        if (Abs(leftDx) < Max(6, size * 0.12) || Abs(rightDx) < Max(6, size * 0.12))
            return false
        if ((leftDx > 0) != (rightDx > 0))
            return false
        baseY := first.y + (last.y - first.y) * ((apex.x - first.x) / Max(1, last.x - first.x))
        if (Abs(apex.y - baseY) < size * 0.28)
            return false
        p1 := corners[idx - 1]
        p2 := corners[idx + 1]
        v1x := apex.x - p1.x, v1y := apex.y - p1.y
        v2x := p2.x - apex.x, v2y := p2.y - apex.y
        l1 := Sqrt(v1x * v1x + v1y * v1y)
        l2 := Sqrt(v2x * v2x + v2y * v2y)
        if (l1 <= 0 || l2 <= 0)
            return false
        if (Abs(v1x) < l1 * 0.22 || Abs(v2x) < l2 * 0.22)
            return false
        return true
    }

    static ChevronChain(corners, size) {
        if (corners.Length < 3 || corners.Length > 4)
            return ""
        minIdx := 2
        maxIdx := 2
        i := 3
        while (i <= corners.Length - 1) {
            if (corners[i].y < corners[minIdx].y)
                minIdx := i
            if (corners[i].y > corners[maxIdx].y)
                maxIdx := i
            i++
        }
        first := corners[1]
        last := corners[corners.Length]
        if (Abs(last.y - first.y) > Max(12, size * 0.26))
            return ""
        baseY := (first.y + last.y) * 0.5
        if (corners[minIdx].y < baseY - size * 0.20 && GestureRecognizer.ChevronApex(corners, minIdx, size))
            return (corners[minIdx].x > first.x) ? "UR_DR" : "UL_DL"
        if (corners[maxIdx].y > baseY + size * 0.20 && GestureRecognizer.ChevronApex(corners, maxIdx, size))
            return (corners[maxIdx].x > first.x) ? "DR_UR" : "DL_UR"
        return ""
    }

    ; ---- 点阵 -> 方向链字符串 (如 "D_R", "U_D") ----
    static DirectionChain(pts, minSegment := 6) {
        if (!IsObject(pts) || pts.Length < 2)
            return ""
        bb := GestureRecognizer.BBox(pts)
        size := Max(bb[3] - bb[1], bb[4] - bb[2])
        if (size < minSegment)
            return ""

        simplifyTol := Max(4.0, Max(minSegment * 0.8, size * 0.045))
        simplified := GestureRecognizer.Simplify(pts, simplifyTol)
        if (simplified.Length < 2)
            return ""

        minLeg := Max(10.0, Max(minSegment * 1.5, size * 0.09))
        chevron := GestureRecognizer.ChevronChain(simplified, size)
        if (chevron != "")
            return chevron

        dirs := []
        anchor := simplified[1]
        i := 2
        while (i <= simplified.Length) {
            p := simplified[i]
            dx := p.x - anchor.x, dy := p.y - anchor.y
            if (dx * dx + dy * dy < minLeg * minLeg) {
                i++
                continue
            }
            d := GestureRecognizer.DirOf(dx, dy)
            if (dirs.Length = 0 || dirs[dirs.Length] != d)
                dirs.Push(d)
            anchor := p
            i++
        }

        s := ""
        for _, d in dirs
            s .= (s = "" ? "" : "_") . d
        return s
    }

    ; ---- 计算方向置信度 (60.0 ~ 88.0) ----
    static DirectionConfidence(pts, direction) {
        direction := GestureRecognizer.Normalize(direction)
        if (direction = "" || !IsObject(pts) || pts.Length < 2)
            return 0.0

        chain := GestureRecognizer.DirectionChain(pts, 6)
        if (chain = direction)
            return 85.0

        if (InStr(direction, "_")) {
            parts := StrSplit(direction, "_")
            if (chain = "")
                return 0.0
            chainParts := StrSplit(chain, "_")
            if (parts.Length = chainParts.Length) {
                matched := 0
                for idx, p in parts {
                    if (idx <= chainParts.Length && p = chainParts[idx])
                        matched++
                }
                if (matched = parts.Length)
                    return 80.0
            }
        }
        return (chain != "" && InStr(chain, direction)) ? 68.0 : 0.0
    }

    ; ---- 字符归一化: 去空格, 转大写, 统一为下划线连接 ----
    static Normalize(s) {
        s := Trim(s)
        s := StrReplace(s, " ", "")
        s := StrReplace(s, ",", "_")
        s := StrReplace(s, "-", "_")
        while InStr(s, "__")
            s := StrReplace(s, "__", "_")
        return StrUpper(s)
    }

    ; ---- 全归一化 (含修饰键前缀, 顺序固定 CTRL+ALT+SHIFT) ----
    static NormalizeFull(s) {
        s := StrUpper(Trim(s))
        s := StrReplace(s, " ", "")
        if !InStr(s, "+")
            return GestureRecognizer.Normalize(s)
        parts := StrSplit(s, "+")
        if (parts.Length < 2)
            return GestureRecognizer.Normalize(s)
        hasC := false, hasA := false, hasS := false
        i := 1
        while (i < parts.Length) {
            p := parts[i]
            if (p = "CTRL" || p = "CONTROL" || p = "C")
                hasC := true
            else if (p = "ALT" || p = "A")
                hasA := true
            else if (p = "SHIFT" || p = "S")
                hasS := true
            i++
        }
        prefix := (hasC ? "CTRL+" : "") . (hasA ? "ALT+" : "") . (hasS ? "SHIFT+" : "")
        return prefix . GestureRecognizer.Normalize(parts[parts.Length])
    }

    ; ---- 获取物理按住的修饰键 (与归一化同顺序) ----
    static ActiveMods() {
        mods := ""
        try {
            if GetKeyState("Ctrl", "P")
                mods .= "CTRL+"
            if GetKeyState("Alt", "P")
                mods .= "ALT+"
            if GetKeyState("Shift", "P")
                mods .= "SHIFT+"
        }
        return mods
    }

    static BindingName(key) {
        key := GestureRecognizer.NormalizeFull(key)
        pos := InStr(key, "+", false, -1)
        return pos > 0 ? SubStr(key, pos + 1) : key
    }

    static IsReservedDirectionName(name) {
        name := GestureRecognizer.Normalize(name)
        return name = "U" || name = "R" || name = "D" || name = "L"
    }
}
