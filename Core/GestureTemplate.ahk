#Requires AutoHotkey v2.0
#Warn All, Off

; === GestureTemplate - 字母/异形手势模板匹配 ($1 风格) ===
; 方向链擅长折线 (R/D_R...), 字母 (e/G/3/B...) 靠模板模糊匹配.
; 模板是形状样本，动作统一由手势名称在作用域中解析。
; 存储: [GestureTemplates] name=v2:x1,y1 ...||||v2:x1,y1 ...
; 内置字母模板由理想笔顺合成, 用户录制可覆盖同名项.

global g_TplNPT, g_TplSize, g_TplThreshold, g_TplMaxSamples, g_TplWeightVec, g_TplWeightPos, g_Templates
if !IsSet(g_TplNPT)
    g_TplNPT := 64
if !IsSet(g_TplSize)
    g_TplSize := 64
if !IsSet(g_TplThreshold)
    g_TplThreshold := 75
if !IsSet(g_TplMaxSamples)
    g_TplMaxSamples := 6
if !IsSet(g_TplWeightVec)
    g_TplWeightVec := 0.65
if !IsSet(g_TplWeightPos)
    g_TplWeightPos := 0.35
if !IsSet(g_Templates)
    g_Templates := Map()   ; canonical name -> {samples:[pts...], features:[feat...], builtin}

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

; ---- 等比缩放, 保留手写字母的宽高比 ----
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
    scale := size / Max(1, Max(maxX - minX, maxY - minY))
    out := []
    for i, p in pts {
        qx := (p.x - minX) * scale
        qy := (p.y - minY) * scale
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

; ---- 方向敏感的 $1 预处理: 等弧长采样、等比缩放、平移 ----
Tpl_Normalize(pts) {
    global g_TplNPT, g_TplSize
    npt := (IsSet(g_TplNPT) && g_TplNPT) ? g_TplNPT : 64
    sz := (IsSet(g_TplSize) && g_TplSize) ? g_TplSize : 64
    r := Tpl_Resample(pts, npt)
    r := Tpl_ScaleTo(r, sz)
    r := Tpl_TranslateToOrigin(r)
    return r
}

; Unmarked user samples were saved by the earlier rotation-invariant matcher.
Tpl_PrepareLegacy(rawPts) {
    global g_TplNPT, g_TplSize
    npt := (IsSet(g_TplNPT) && g_TplNPT) ? g_TplNPT : 64
    sz := (IsSet(g_TplSize) && g_TplSize) ? g_TplSize : 64
    r := Tpl_Resample(rawPts, npt)
    c := Tpl_Centroid(r)
    theta := Tpl_Atan2(c[2] - r[1].y, c[1] - r[1].x)
    r := Tpl_RotateBy(r, -theta)
    bb := Tpl_BBox(r)
    w := bb[3] - bb[1], h := bb[4] - bb[2]
    old := []
    for i, p in r
        old.Push(Tpl_Pt(w > 0 ? (p.x - bb[1]) * sz / w : 0,
            h > 0 ? (p.y - bb[2]) * sz / h : 0))
    return Tpl_Decode(Tpl_Encode(Tpl_ScaleShiftBack(Tpl_TranslateToOrigin(old))))
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

; ---- 提取平滑单位方向向量序列 (移动平均降噪) ----
Tpl_ExtractVectors(pts) {
    if (pts.Length < 2)
        return []
    vecs := []
    rx := 0.0, ry := 0.0
    coef := 0.75
    i := 1
    while (i < pts.Length) {
        dx := pts[i + 1].x - pts[i].x
        dy := pts[i + 1].y - pts[i].y
        rx := coef * rx + (1.0 - coef) * dx
        ry := coef * ry + (1.0 - coef) * dy
        mag := Sqrt(rx * rx + ry * ry)
        if (mag > 0.0001)
            vecs.Push({x: rx / mag, y: ry / mag})
        else
            vecs.Push({x: 0.0, y: 0.0})
        i++
    }
    return vecs
}

; ---- 单位向量序列的余弦相似度 (带首尾截断滑动容错) ----
Tpl_VectorSimilarity(vA, vB) {
    lenA := vA.Length, lenB := vB.Length
    if (lenA = 0 || lenB = 0)
        return 0.0
    n := Min(lenA, lenB)
    sumCos := 0.0
    Loop n {
        sumCos += vA[A_Index].x * vB[A_Index].x + vA[A_Index].y * vB[A_Index].y
    }
    bestSim := sumCos / n

    ; 初筛短路: 若走势完全相悖(余弦过低), 无需做昂贵的滑动微调
    if (bestSim < 0.5)
        return Max(0.0, bestSim * 100.0)

    ; 滑动偏移微调 (吸收起手迟滞和释放甩尾微动)
    maxOffset := Min(4, Floor(n / 10))
    offset := 2
    while (offset <= maxOffset) {
        cnt1 := n - offset
        if (cnt1 > 0) {
            sum1 := 0.0
            sum2 := 0.0
            Loop cnt1 {
                sum1 += vA[A_Index + offset].x * vB[A_Index].x + vA[A_Index + offset].y * vB[A_Index].y
                sum2 += vA[A_Index].x * vB[A_Index + offset].x + vA[A_Index].y * vB[A_Index + offset].y
            }
            sim1 := sum1 / cnt1
            sim2 := sum2 / cnt1
            if (sim1 > bestSim)
                bestSim := sim1
            if (sim2 > bestSim)
                bestSim := sim2
        }
        offset += 2
    }
    return Max(0.0, bestSim * 100.0)
}

; ---- 构建点集与向量联合特征 ----
Tpl_BuildFeature(rawPts) {
    norm := Tpl_Prepare(rawPts)
    vecs := Tpl_ExtractVectors(norm)
    return {points: norm, vectors: vecs}
}

; ---- 多特征融合打分 (方向走势 + 轮廓位置) ----
Tpl_ScoreSample(candNormPts, candVecs, sampNormPts, sampVecs, half) {
    global g_TplWeightVec, g_TplWeightPos
    simVec := Tpl_VectorSimilarity(candVecs, sampVecs)
    dist := Tpl_PathDistance(candNormPts, sampNormPts)
    simPos := Max(0.0, (1.0 - dist / half) * 100.0)
    return g_TplWeightVec * simVec + g_TplWeightPos * simPos
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
    if (SubStr(s, 1, 3) = "v2:" || SubStr(s, 1, 3) = "v1:")
        s := SubStr(s, 4)
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

; ==================== 内置模板 ====================
; 动作以 StrokesPlus.xml 全局动作为准:
;   e 在 SP 中有模板无动作 -> NoOp (画了没反应, 与原版一致);
;   S 在 SP 中是运行 Sublime, 不是媒体停止.
; 样本以 Core/GestureSPData.ahk 真实记录轨迹为首样本 (SPTpl_RawDefs),
; 理想笔顺合成仅作第二样本兜底 (笔顺差异容错, 如 Right-Down 在 SP 即有 2 样本).
Tpl_BuiltinDefs() {
    return Map(
        "e", ["function|GestureEngine.NoOp", [[55,55],[35,45],[25,55],[30,70],[50,75],[70,65],[75,50],[60,45],[45,50]]],
        "G", ["run|https://www.google.com", [[75,30],[55,15],[30,20],[15,40],[15,65],[30,85],[55,90],[75,80],[70,60],[50,60]]],
        "U", ["key|^z", [[20,15],[20,70],[35,88],[60,88],[78,68],[80,15]]],
        "R", ["key|^y", [[25,10],[25,90],[25,10],[60,12],[72,30],[60,48],[25,50],[75,90]]],
        "D", ["function|GestureEngine.IgnoreNext", [[30,10],[30,90],[30,10],[60,10],[80,30],[85,50],[80,70],[60,90],[30,90]]],
        "P", ["<SP_PlayPause>", [[30,10],[30,90],[30,45],[65,40],[72,25],[60,12],[30,10]]],
        "L", ["key|{Media_Prev}", [[30,10],[30,80],[75,80]]],
        "N", ["<SP_Next>", [[25,85],[25,15],[75,85],[75,15]]],
        "S", ["run|D:\software\SublimeText\sublime_text.exe", [[70,20],[45,12],[25,25],[30,45],[55,50],[72,60],[60,80],[35,88]]],
        "M", ["<SP_Mute>", [[20,85],[20,15],[50,60],[80,15],[80,85]]],
        "Z", ["function|GestureEngine.NoOp", [[20,20],[80,20],[20,80],[80,80]]],
        "B", ["function|GestureEngine.NoOp", [[30,10],[30,90],[30,10],[60,12],[72,28],[60,48],[30,50],[65,52],[75,70],[62,88],[30,90]]],
        "J", ["function|GestureEngine.NoOp", [[65,10],[60,70],[40,88],[22,78]]],
        "h", ["function|GestureEngine.NoOp", [[30,10],[30,90],[30,55],[55,50],[65,65],[65,90]]],
        "X", ["key|^x", [[20,15],[80,85],[80,15],[20,85]]],
        "3", ["function|GestureEngine.NoOp", [[25,20],[55,12],[70,30],[50,45],[65,55],[70,70],[50,88],[25,82]]],
        "V", ["function|GestureEngine.NoOp", [[10,10],[50,88],[90,10]]],
        "InvV", ["function|GestureEngine.NoOp", [[10,88],[50,10],[90,88]]]
    )
}

; ---- 匹配用制备管线 (模板与候选必须同空间): 归一化->搬回网格->量化 ----
Tpl_BuiltinName(name) {
    up := StrUpper(name)
    return (up = "U" || up = "R" || up = "D" || up = "L") ? "LETTER_" . up : up
}

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
Tpl_BuildTemplateFeatures(samples) {
    feats := []
    for _, s in samples {
        feats.Push(Tpl_BuildFeature(s))
    }
    return feats
}

Tpl_LoadAll() {
    global g_Templates, g_TplThreshold, g_Conf
    g_Templates := Map()
    try {
        if (IsSet(g_Conf) && IsObject(g_Conf) && g_Conf.HasSection("Gesture")) {
            th := g_Conf.Get("Gesture", "TemplateThreshold", "")
            if (th != "" && th + 0 > 0)
                g_TplThreshold := th + 0
        }
    }
    ; 先装内置: SP 真实轨迹为首样本 + 理想合成兜底 (双样本)
    try {
        rawDefs := SPTpl_RawDefs()
    } catch {
        rawDefs := Map()
    }
    try {
        for name, def in Tpl_BuiltinDefs() {
            samples := []
            try {
                if (rawDefs.Has(name)) {
                    raw := Tpl_Decode(rawDefs[name])
                    if (raw.Length >= 3)
                        samples.Push(Tpl_Prepare(raw))
                }
            }
            samples.Push(Tpl_Synth(def[2]))
            g_Templates[Tpl_BuiltinName(name)] := {samples: samples, features: Tpl_BuildTemplateFeatures(samples), builtin: 1}
        }
    }
    ; ini 覆盖（仅保存样本，动作统一在 Gestures / GestureApp 中绑定）: name=s1||||s2 ...
    try {
        if (IsSet(g_Conf) && IsObject(g_Conf) && g_Conf.HasSection("GestureTemplates")) {
            for _k, _v in g_Conf["GestureTemplates"] {
                _k := Trim(_k)
                if (_k = "" || SubStr(_k, 1, 1) = ";")
                    continue
                rest := Trim(_v)
                samples := []
                versions := []
                for i, sp in StrSplit(rest, "||||") {
                    sp := Trim(sp)
                    pts := Tpl_Decode(sp)
                    if (pts.Length > 0) {
                        samples.Push(pts)
                        versions.Push(SubStr(sp, 1, 3) = "v2:" ? 2 : 1)
                    }
                }
                if (samples.Length = 0)
                    continue
                g_Templates[Tpl_BuiltinName(_k)] := {samples: samples, features: Tpl_BuildTemplateFeatures(samples), versions: versions, builtin: 0}
            }
        }
    }
}

; ==================== 匹配 ====================
; 返回 [name, score0_100], 无模板或太小返回 ["", 0]
Tpl_Match(rawPts, minSize := 0, onlyName := "") {
    candidates := Tpl_Candidates(rawPts, minSize)
    if (candidates.Length = 0)
        return ["", 0]
    bestCand := ""
    secondCand := ""
    for _, c in candidates {
        if (onlyName != "" && StrUpper(c.name) != StrUpper(onlyName))
            continue
        if (!IsObject(bestCand) || c.score > bestCand.score) {
            secondCand := bestCand
            bestCand := c
        } else if (!IsObject(secondCand) || c.score > secondCand.score) {
            secondCand := c
        }
    }
    if (!IsObject(bestCand))
        return ["", 0]
    if (onlyName = "" && IsObject(secondCand) && bestCand.score - secondCand.score < 4)
        return ["", 0]
    return [bestCand.name, bestCand.score]
}

Tpl_Candidates(rawPts, minSize := 0) {
    global g_Templates, g_TplSize
    out := []
    if (!IsObject(rawPts) || rawPts.Length < 3)
        return out
    if (minSize > 0) {
        bb := Tpl_BBox(rawPts)
        if (bb[3] - bb[1] < minSize && bb[4] - bb[2] < minSize)
            return out
    }
    candFeat := Tpl_BuildFeature(rawPts)
    half := 0.5 * Sqrt(g_TplSize * g_TplSize * 2)
    for name, tmpl in g_Templates {
        if (GestureEngine.TplOff(name))
            continue
        bestScore := 0.0
        bestSample := 0
        feats := tmpl.HasOwnProp("features") ? tmpl.features : []
        if (feats.Length = 0) {
            feats := Tpl_BuildTemplateFeatures(tmpl.samples)
            tmpl.features := feats
        }
        for index, sFeat in feats {
            score := Tpl_ScoreSample(candFeat.points, candFeat.vectors, sFeat.points, sFeat.vectors, half)
            if (score > bestScore) {
                bestScore := score
                bestSample := index
            }
        }
        if (bestSample > 0 && bestScore > 0)
            out.Push({name: name, score: bestScore, sample: bestSample})
    }
    return out
}

Tpl_RemoveSample(name, index) {
    tmpl := Tpl_Get(name)
    if (!IsObject(tmpl) || index < 1 || index > tmpl.samples.Length || tmpl.samples.Length < 2)
        return false
    samples := []
    for i, sample in tmpl.samples {
        if (i = index)
            continue
        version := 2
        try version := tmpl.versions[i]
        samples.Push((version = 1 ? "v1:" : "v2:") . Tpl_Encode(sample))
    }
    return GestureStore_SetTemplateSamples(name, samples)
}

Tpl_Get(name) {
    global g_Templates
    try {
        key := StrUpper(name)
        if (g_Templates.Has(key))
            return g_Templates[key]
    }
    return ""
}

; ---- 样本拼回存储串 ----
Tpl_JoinSamples(t) {
    s := ""
    try {
        i := 1
        for _, samp in t.samples {
            version := 2
            try version := t.versions[i]
            s .= (i > 1 ? "||||" : "") . (version = 1 ? "v1:" : "v2:") . Tpl_Encode(samp)
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
            out.Push([name, "", (t.builtin ? "内置" : "自定义") . " x" . t.samples.Length])
    }
    return out
}
