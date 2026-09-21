#Requires AutoHotkey v2.0
#Warn All, Off

; === GestureTemplate - 字母/异形手势模板匹配 ($1 风格) ===
; 方向链擅长折线 (R/D_R...), 字母 (e/G/3/B...) 靠模板模糊匹配.
; 流程: Up 时链未命中 -> 归一化笔画 -> 与模板比对 -> 分数达标则触发.
; 模板名区分大小写, 与链命名空间隔离 (链全大写归一, 模板保持原样).
; 存储: [GestureTemplates] 行格式 name=action|||x1,y1 x2,y2 ... (32 点, 0-64 网格).
; 内置字母模板由理想笔顺合成, 用户录制可覆盖同名项.

global g_TplNPT := 32
global g_TplSize := 64
global g_TplThreshold := 75
global g_TplMaxSamples := 3
global g_Templates := Map()   ; name -> {action, samples:[pts...], builtin}

; ---- 点结构: {x, y} 数组 ----
Tpl_Pt(x, y) {
    return {x: x, y: y}
}

Tpl_PathLength(pts) {
    d := 0.0
    i := 2
    while (i <= pts.Length) {
        dx := pts[i].x - pts[i-1].x
        dy := pts[i].y - pts[i-1].y
        d += Sqrt(dx * dx + dy * dy)
        i++
    }
    return d
}

Tpl_Centroid(pts) {
    cx := 0.0
    cy := 0.0
    for i, p in pts {
        cx += p.x
        cy += p.y
    }
    return [cx / pts.Length, cy / pts.Length]
}

Tpl_Atan2(y, x) {
    try {
        return DllCall("msvcrt\atan2", "Double", y, "Double", x, "Cdecl Double")
    } catch {
        return 0.0
    }
}

; ---- 重采样到 N 点 ----
Tpl_Resample(pts, n) {
    if (pts.Length = 0)
        return []
    if (pts.Length = 1) {
        out := []
        Loop n
            out.Push(Tpl_Pt(pts[1].x, pts[1].y))
        return out
    }
    total := Tpl_PathLength(pts)
    if (total <= 0) {
        out := []
        Loop n
            out.Push(Tpl_Pt(pts[1].x, pts[1].y))
        return out
    }
    iv := total / (n - 1)
    acc := 0.0
    src := []
    for i, p in pts
        src.Push(Tpl_Pt(p.x, p.y))
    newPts := [Tpl_Pt(src[1].x, src[1].y)]
    i := 2
    while (i <= src.Length) {
        dx := src[i].x - src[i-1].x
        dy := src[i].y - src[i-1].y
        segLen := Sqrt(dx * dx + dy * dy)
        if (acc + segLen >= iv && segLen > 0) {
            t := (iv - acc) / segLen
            qx := src[i-1].x + t * dx
            qy := src[i-1].y + t * dy
            newPts.Push(Tpl_Pt(qx, qy))
            src[i-1] := Tpl_Pt(qx, qy)
            acc := 0.0
        } else {
            acc += segLen
            i++
        }
    }
    while (newPts.Length < n)
        newPts.Push(Tpl_Pt(src[src.Length].x, src[src.Length].y))
    return newPts
}

; ---- 绕质心旋转 ----
Tpl_RotateBy(pts, rad) {
    c := Tpl_Centroid(pts)
    cx := c[1]
    cy := c[2]
    co := 0.0
    si := 0.0
    try {
        co := Cos(rad)
        si := Sin(rad)
    }
    out := []
    for i, p in pts {
        dx := p.x - cx
        dy := p.y - cy
        out.Push(Tpl_Pt(dx * co - dy * si + cx, dx * si + dy * co + cy))
    }
    return out
}

; ---- 缩放到正方形 ----
Tpl_ScaleTo(pts, size) {
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
    w := maxX - minX
    h := maxY - minY
    out := []
    for i, p in pts {
        qx := w > 0 ? (p.x - minX) * size / w : 0.0
        qy := h > 0 ? (p.y - minY) * size / h : 0.0
        out.Push(Tpl_Pt(qx, qy))
    }
    return out
}

; ---- 平移质心到原点 ----
Tpl_TranslateToOrigin(pts) {
    c := Tpl_Centroid(pts)
    out := []
    for i, p in pts
        out.Push(Tpl_Pt(p.x - c[1], p.y - c[2]))
    return out
}

; ---- 完整归一化: 重采样->去旋转(指示角)->缩放->平移 ----
Tpl_Normalize(pts) {
    global g_TplNPT, g_TplSize
    r := Tpl_Resample(pts, g_TplNPT)
    c := Tpl_Centroid(r)
    theta := Tpl_Atan2(c[2] - r[1].y, c[1] - r[1].x)
    r := Tpl_RotateBy(r, -theta)
    r := Tpl_ScaleTo(r, g_TplSize)
    r := Tpl_TranslateToOrigin(r)
    return r
}

; ---- 平均点距 ----
Tpl_PathDistance(a, b) {
    d := 0.0
    n := a.Length < b.Length ? a.Length : b.Length
    if (n = 0)
        return 1e9
    i := 1
    while (i <= n) {
        dx := a[i].x - b[i].x
        dy := a[i].y - b[i].y
        d += Sqrt(dx * dx + dy * dy)
        i++
    }
    return d / n
}

; ---- 序列化/反序列化 (0-64 整数网格) ----
Tpl_Encode(pts) {
    s := ""
    for i, p in pts {
        xi := Round(p.x)
        if (xi < 0)
            xi := 0
        if (xi > 64)
            xi := 64
        yi := Round(p.y)
        if (yi < 0)
            yi := 0
        if (yi > 64)
            yi := 64
        s .= (i > 1 ? " " : "") . xi . "," . yi
    }
    return s
}

Tpl_Decode(s) {
    pts := []
    s := Trim(s)
    if (s = "")
        return pts
    for i, tok in StrSplit(s, " ") {
        tok := Trim(tok)
        if (tok = "")
            continue
        pos := InStr(tok, ",")
        if (pos = 0)
            continue
        pts.Push(Tpl_Pt(Trim(SubStr(tok, 1, pos - 1)) + 0, Trim(SubStr(tok, pos + 1)) + 0))
    }
    return pts
}

; ---- 包围盒 (录制过小则拒识) ----
Tpl_BBox(pts) {
    if (pts.Length = 0)
        return [0, 0, 0, 0]
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
    return [minX, minY, maxX, maxY]
}

; ==================== 内置模板 (理想笔顺合成, 0-100 坐标 y 向下) ====================
Tpl_BuiltinDefs() {
    return Map(
        "e", ["key|#{e}", [[55,55],[35,45],[25,55],[30,70],[50,75],[70,65],[75,50],[60,45],[45,50]]],
        "G", ["run|https://www.google.com", [[75,30],[55,15],[30,20],[15,40],[15,65],[30,85],[55,90],[75,80],[70,60],[50,60]]],
        "U", ["key|^z", [[20,15],[20,70],[35,88],[60,88],[78,68],[80,15]]],
        "R", ["key|^y", [[25,10],[25,90],[25,10],[60,12],[72,30],[60,48],[25,50],[75,90]]],
        "D", ["function|Gesture_IgnoreNext", [[30,10],[30,90],[30,50],[60,50],[75,65],[60,82],[30,85]]],
        "P", ["<SP_PlayPause>", [[30,10],[30,90],[30,45],[65,40],[72,25],[60,12],[30,10]]],
        "L", ["key|{Media_Prev}", [[30,10],[30,80],[75,80]]],
        "N", ["<SP_Next>", [[25,85],[25,15],[75,85],[75,15]]],
        "S", ["key|{Media_Stop}", [[70,20],[45,12],[25,25],[30,45],[55,50],[72,60],[60,80],[35,88]]],
        "M", ["<SP_Mute>", [[20,85],[20,15],[50,60],[80,15],[80,85]]],
        "Z", ["combo|zoom", [[20,20],[80,20],[20,80],[80,80]]],
        "B", ["key|^d", [[30,10],[30,90],[30,55],[62,52],[70,68],[58,84],[30,86]]],
        "J", ["key|^j", [[65,10],[60,70],[40,88],[22,78]]],
        "h", ["key|{Browser_Home}", [[30,10],[30,90],[30,55],[55,50],[65,65],[65,90]]],
        "X", ["key|^x", [[20,15],[80,85],[80,15],[20,85]]],
        "3", ["key|^t", [[25,20],[55,12],[70,30],[50,45],[65,55],[70,70],[50,88],[25,82]]]
    )
}

; ---- 匹配用制备管线 (模板与候选必须同空间): 归一化->搬回网格->量化 ----
Tpl_Prepare(rawPts) {
    return Tpl_Decode(Tpl_Encode(Tpl_ScaleShiftBack(Tpl_Normalize(rawPts))))
}

; ---- 由 waypoint 合成模板点列 (与 ini 载入路径完全一致) ----
Tpl_Synth(points) {
    raw := []
    for i, w in points
        raw.Push(Tpl_Pt(w[1] + 0.0, w[2] + 0.0))
    return Tpl_Prepare(raw)
}

; ---- 归一化点(质心原点)搬回 0-64 网格用于存储 ----
Tpl_ScaleShiftBack(pts) {
    global g_TplSize
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
    w := maxX - minX
    h := maxY - minY
    m := w > h ? w : h
    if (m <= 0)
        m := 1.0
    out := []
    for i, p in pts
        out.Push(Tpl_Pt((p.x - minX) * g_TplSize / m, (p.y - minY) * g_TplSize / m))
    return out
}

; ==================== 载入 ====================
Tpl_LoadAll() {
    global g_Templates, g_TplThreshold, g_Conf
    g_Templates := Map()
    try {
        if IsObject(g_Conf) && g_Conf.HasSection("Gesture") {
            th := g_Conf.Get("Gesture", "TemplateThreshold", "")
            if (th != "" && th + 0 > 0)
                g_TplThreshold := th + 0
        }
    }
    ; 先装内置 (单样本)
    try {
        for name, def in Tpl_BuiltinDefs()
            g_Templates[name] := {action: def[1], samples: [Tpl_Synth(def[2])], builtin: 1}
    }
    ; ini 覆盖 (动作和样本都可自定义): name=action|||s1||||s2 ...
    try {
        if IsObject(g_Conf) && g_Conf.HasSection("GestureTemplates") {
            for _k, _v in g_Conf["GestureTemplates"] {
                _k := Trim(_k)
                if (_k = "" || SubStr(_k, 1, 1) = ";")
                    continue
                pos := InStr(_v, "|||")
                if (pos = 0)
                    continue
                act := Trim(SubStr(_v, 1, pos - 1))
                rest := Trim(SubStr(_v, pos + 3))
                samples := []
                for i, sp in StrSplit(rest, "||||") {
                    pts := Tpl_Decode(Trim(sp))
                    if (pts.Length > 0)
                        samples.Push(pts)
                }
                if (act = "" || samples.Length = 0)
                    continue
                g_Templates[_k] := {action: act, samples: samples, builtin: 0}
            }
        }
    }
}

; ==================== 匹配 ====================
; 返回 [name, score0_100], 无模板或太小返回 ["", 0]
Tpl_Match(rawPts, minSize := 0) {
    global g_Templates, g_TplNPT, g_TplSize
    if (rawPts.Length < 3)
        return ["", 0]
    if (minSize > 0) {
        bb := Tpl_BBox(rawPts)
        w := bb[3] - bb[1]
        h := bb[4] - bb[2]
        if (w < minSize && h < minSize)
            return ["", 0]
    }
    cand := Tpl_Prepare(rawPts)
    bestName := ""
    bestDist := 1e18
    for name, t in g_Templates {
        try {
            if (Gesture_TplOff(name))
                continue
        } catch {
        }
        for i, samp in t.samples {
            d := Tpl_PathDistance(cand, samp)
            if (d < bestDist) {
                bestDist := d
                bestName := name
            }
        }
    }
    if (bestName = "")
        return ["", 0]
    half := 0.5 * Sqrt(g_TplSize * g_TplSize * 2)
    score := (1 - bestDist / half) * 100
    return [bestName, score]
}

Tpl_Get(name) {
    global g_Templates
    try {
        if (g_Templates.Has(name))
            return g_Templates[name]
    }
    return ""
}

; ---- 样本拼回存储串 ----
Tpl_JoinSamples(t) {
    s := ""
    try {
        i := 1
        for _, samp in t.samples {
            s .= (i > 1 ? "||||" : "") . Tpl_Encode(samp)
            i++
        }
    }
    return s
}

Tpl_List() {
    global g_Templates
    out := []
    try {
        for name, t in g_Templates
            out.Push([name, t.action, (t.builtin ? "内置" : "自定义") . "x" . t.samples.Length])
    }
    return out
}
