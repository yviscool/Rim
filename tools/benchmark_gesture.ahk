#Requires AutoHotkey v2.0
#Warn All, Off

T(key, *) => key

#Include ..\Lib\EasyIni.ahk
#Include ..\Core\Gesture.ahk
#Include ..\Core\GestureTemplate.ahk
#Include ..\Core\GestureSPData.ahk
#Include ..\Core\GestureIni.ahk

Benchmark_Main()
ExitApp(0)

; 模拟辅助：生成直线或平滑曲线轨迹点
Benchmark_MakeLine(x1, y1, x2, y2, n := 20, noise := 0) {
    pts := []
    Loop n {
        t := (A_Index - 1) / Max(1, n - 1)
        nx := noise ? ((Random(0, 100) / 100.0 - 0.5) * noise) : 0
        ny := noise ? ((Random(0, 100) / 100.0 - 0.5) * noise) : 0
        pts.Push(Tpl_Pt(x1 + (x2 - x1) * t + nx, y1 + (y2 - y1) * t + ny))
    }
    return pts
}

; 由多段折线生成路径
Benchmark_MakePolyline(waypoints, stepsPerSeg := 15, noise := 0) {
    pts := []
    Loop waypoints.Length - 1 {
        w1 := waypoints[A_Index]
        w2 := waypoints[A_Index + 1]
        segPts := Benchmark_MakeLine(w1[1], w1[2], w2[1], w2[2], stepsPerSeg, noise)
        for i, p in segPts {
            if (A_Index > 1 && i = 1)
                continue
            pts.Push(p)
        }
    }
    return pts
}

; 解析字符串点列 "x,y x,y ..."
Benchmark_ParseCoords(str) {
    pts := []
    for _, tok in StrSplit(Trim(str), " ") {
        tok := Trim(tok)
        if (tok = "")
            continue
        parts := StrSplit(tok, ",")
        if (parts.Length >= 2)
            pts.Push(Tpl_Pt(parts[1] + 0.0, parts[2] + 0.0))
    }
    return pts
}

; P0-2/P10 helpers: 排序与分位 (顶层函数, 供 Benchmark_Main 调用)
Bench_Sort(arr) {
    st := []
    for _, ms in arr
        st.Push(ms)
    n := st.Length
    if (n > 1) {
        Loop n - 1 {
            swapped := false
            Loop n - A_Index {
                if (st[A_Index] > st[A_Index + 1]) {
                    tmp := st[A_Index]
                    st[A_Index] := st[A_Index + 1]
                    st[A_Index + 1] := tmp
                    swapped := true
                }
            }
            if (!swapped)
                break
        }
    }
    return st
}

Bench_Pct(st, p) {
    n := st.Length
    if (n = 0)
        return 0
    return st[Max(1, Ceil(n * p))]
}

; 给已有轨迹加随机扰动与比例缩放
Benchmark_JitterTrajectory(pts, scaleX := 1.0, scaleY := 1.0, jitter := 2.0) {
    if (pts.Length = 0)
        return []
    bb := Tpl_BBox(pts)
    cx := (bb[1] + bb[3]) / 2.0
    cy := (bb[2] + bb[4]) / 2.0
    out := []
    for _, p in pts {
        dx := (p.x - cx) * scaleX
        dy := (p.y - cy) * scaleY
        jx := jitter ? ((Random(0, 100) / 100.0 - 0.5) * jitter) : 0
        jy := jitter ? ((Random(0, 100) / 100.0 - 0.5) * jitter) : 0
        out.Push(Tpl_Pt(cx + dx + jx, cy + dy + jy))
    }
    return out
}

; 构建评测集
Benchmark_BuildDataset() {
    dataset := []
    rawDefs := SPTpl_RawDefs()

    ; 1. 真实 StrokesPlus 原始轨迹及扰动变体 (16 个真实手写样本)
    for label, rawStr in rawDefs {
        basePts := Benchmark_ParseCoords(rawStr)
        if (basePts.Length < 3)
            continue
        dataset.Push({label: label, pts: basePts, desc: label . "_raw"})
        dataset.Push({label: label, pts: Benchmark_JitterTrajectory(basePts, 1.0, 1.0, 3.0), desc: label . "_jitter"})
        dataset.Push({label: label, pts: Benchmark_JitterTrajectory(basePts, 1.15, 0.9, 2.0), desc: label . "_wide"})
        dataset.Push({label: label, pts: Benchmark_JitterTrajectory(basePts, 0.85, 1.1, 2.0), desc: label . "_tall"})
    }

    ; 2. 经典方向手势 (单段直线与多段折线)
    directions := [
        {name: "R", poly: [[0, 0], [150, 0]]},
        {name: "L", poly: [[150, 0], [0, 0]]},
        {name: "D", poly: [[0, 0], [0, 150]]},
        {name: "U", poly: [[0, 150], [0, 0]]},
        {name: "R_D", poly: [[0, 0], [100, 0], [100, 100]]},
        {name: "D_R", poly: [[0, 0], [0, 100], [100, 100]]},
        {name: "U_D", poly: [[0, 100], [0, 0], [0, 100]]},
        {name: "DR_UR", poly: [[0, 0], [50, 80], [100, 0]]},
        {name: "UR_DR", poly: [[0, 80], [50, 0], [100, 80]]}
    ]
    for d in directions {
        basePts := Benchmark_MakePolyline(d.poly, 15, 0)
        dataset.Push({label: d.name, pts: basePts, desc: d.name . "_clean", method: "direction"})
        dataset.Push({label: d.name, pts: Benchmark_MakePolyline(d.poly, 15, 4.0), desc: d.name . "_noisy", method: "direction"})
        dataset.Push({label: d.name, pts: Benchmark_JitterTrajectory(basePts, 1.2, 0.8, 3.0), desc: d.name . "_scaled", method: "direction"})
    }

    ; 3. 极易混淆对与复杂字母
    dataset.Push({label: "V", pts: Benchmark_MakePolyline([[10, 10], [50, 90], [90, 10]], 20, 2.0), desc: "V_clean", method: "template"})
    dataset.Push({label: "InvV", pts: Benchmark_MakePolyline([[10, 90], [50, 10], [90, 90]], 20, 2.0), desc: "InvV_clean", method: "template"})

    uArc := [[20, 20], [20, 70], [30, 90], [50, 95], [70, 90], [80, 70], [80, 20]]
    dataset.Push({label: "U", pts: Benchmark_MakePolyline(uArc, 15, 2.0), desc: "U_curve", method: "template"})
    dataset.Push({label: "U", pts: Benchmark_MakePolyline(uArc, 15, 5.0), desc: "U_curve_noisy", method: "template"})

    threePts := [[25, 20], [55, 12], [70, 30], [50, 45], [65, 55], [70, 70], [50, 88], [25, 82]]
    zPts := [[20, 20], [80, 20], [20, 80], [80, 80]]
    dataset.Push({label: "3", pts: Benchmark_MakePolyline(threePts, 15, 2.0), desc: "3_poly", method: "template"})
    dataset.Push({label: "Z", pts: Benchmark_MakePolyline(zPts, 15, 2.0), desc: "Z_poly", method: "template"})

    bPts := [[30, 10], [30, 90], [30, 10], [60, 12], [72, 28], [60, 48], [30, 50], [65, 52], [75, 70], [62, 88], [30, 90]]
    pPts := [[30, 10], [30, 90], [30, 45], [65, 40], [72, 25], [60, 12], [30, 10]]
    dataset.Push({label: "B", pts: Benchmark_MakePolyline(bPts, 15, 2.0), desc: "B_poly", method: "template"})
    dataset.Push({label: "P", pts: Benchmark_MakePolyline(pPts, 15, 2.0), desc: "P_poly", method: "template"})

    return dataset
}

; 运行评测
Benchmark_Main() {
    global g_GestureMap, g_GestureDefs, g_Templates, g_Gesture, g_GestureApps, g_GestureBlacklist, g_GestureDisabled
    g_GestureMap := Map()
    g_GestureDefs := Map()
    g_GestureApps := []
    g_GestureBlacklist := []
    g_GestureDisabled := Map()
    g_Gesture := Map(
        "enable", 1, "threshold", 20, "margin", 6.0, "segment", 6,
        "onlyDefined", 0, "ignoreKey", "", "ignoreNext", 0
    )
    logPath := A_ScriptDir . "\benchmark_run.log"
    outPath := A_ScriptDir . "\benchmark_report.txt"
    try FileDelete(logPath)
    try FileDelete(outPath)

    try {
        FileAppend("Step 1: Initializing templates...`n", logPath)
        try {
            Tpl_LoadAll()
            FileAppend("Step 2: Templates loaded.`n", logPath)
        } catch Error as e {
            FileAppend("Tpl_LoadAll FAILED: " . e.Message . " line=" . e.Line . " file=" . e.File . "`n" . e.Stack . "`n", logPath)
            ExitApp(1)
        }

        try {
            dataset := Benchmark_BuildDataset()
            total := dataset.Length
            FileAppend("Step 3: Dataset built (" . total . " samples).`n", logPath)
        } catch Error as e {
            FileAppend("Benchmark_BuildDataset FAILED: " . e.Message . " line=" . e.Line . " file=" . e.File . "`n" . e.Stack . "`n", logPath)
            ExitApp(1)
        }
        correct := 0
        rejected := 0
        misclassified := 0

        confusion := Map()
        errors := []

        ; 注册动作映射
        FileAppend("Step 4: Registering actions...`n", logPath)
        seen := Map()
        for item in dataset {
            name := item.label
            if (seen.Has(name))
                continue
            seen[name] := 1
            up := StrUpper(name)
            canon := (up = "U" || up = "R" || up = "D" || up = "L") ? "LETTER_" . up : up
            method := item.HasOwnProp("method") ? item.method : "auto"
            if (method = "direction") {
                GestureEngine.DefinitionEnsure(name, "direction")
            } else if (method = "template") {
                GestureEngine.DefinitionEnsure(name, "template")
                if (canon != up)
                    GestureEngine.DefinitionEnsure(canon, "template")
            } else {
                GestureEngine.DefinitionEnsure(name, "auto")
                GestureEngine.DefinitionEnsure(up, "auto")
                GestureEngine.DefinitionEnsure(canon, "template")
            }
            g_GestureMap[name] := "test_action"
            g_GestureMap[up] := "test_action"
            g_GestureMap[canon] := "test_action"
        }
        FileAppend("Step 5: Evaluating " . total . " samples x3 rounds (1 warmup + 2 measured)...`n", logPath)
        sIdx := 0
        times := []
        tDir := []
        tCollect := []
        tSelect := []
        rounds := 3
        Loop rounds {
            rnd := A_Index
            for item in dataset {
                label := item.label
                up := StrUpper(label)
                canon := (up = "U" || up = "R" || up = "D" || up = "L") ? "LETTER_" . up : up
                pts := item.pts

                t0 := A_TickCount
                dirStr := GestureRecognizer.DirectionChain(pts, 6)
                t1 := A_TickCount
                candidates := GestureEngine.CollectCandidates(dirStr, pts)
                t2 := A_TickCount
                decision := GestureEngine.SelectCandidate(candidates, "explorer.exe", "CabinetWClass", "Test")
                t3 := A_TickCount
                if (rnd > 1) {
                    times.Push(t3 - t0)
                    tDir.Push(t1 - t0)
                    tCollect.Push(t2 - t1)
                    tSelect.Push(t3 - t2)
                }
                if (rnd = 1)
                    continue
                if (rnd > 2)
                    continue
                sIdx++
                FileAppend("Evaluated " . sIdx . "/" . total . " (" . item.desc . ") -> " . (IsObject(decision.selected) ? decision.selected.name : "REJECT") . "`n", logPath)

                selectedName := IsObject(decision.selected) ? decision.selected.name : ""
                reason := decision.reason

                if (!confusion.Has(label))
                    confusion[label] := Map()

                selUp := StrUpper(selectedName)
                isMatch := (selUp = up) || (selUp = canon) || (canon != up && selUp = "LETTER_" . up)
                if (!isMatch) {
                    if ((up = "DR_UR" && selUp = "V") || (up = "V" && selUp = "DR_UR"))
                        isMatch := true
                    else if ((up = "UR_DR" && selUp = "INVV") || (up = "INVV" && selUp = "UR_DR"))
                        isMatch := true
                    else if ((up = "D_R" && (selUp = "L" || selUp = "LETTER_L")) || ((up = "L" || up = "LETTER_L") && selUp = "D_R"))
                        isMatch := true
                }

                predLabel := selectedName = "" ? "(REJECT:" . reason . ")" : selectedName
                confusion[label][predLabel] := confusion[label].Get(predLabel, 0) + 1
                top2 := ""
                try {
                    if (decision.candidates.Length >= 2)
                        top2 := decision.candidates[2].name . "=" . Round(decision.candidates[2].score, 1)
                }
                if (selectedName = "") {
                    rejected++
                    errors.Push({desc: item.desc, expected: label, actual: predLabel, reason: reason, score: 0, margin: 0, top2: top2})
                } else if (isMatch) {
                    correct++
                } else {
                    misclassified++
                    topScore := decision.selected.score
                    secScore := (decision.candidates.Length > 1) ? decision.candidates[2].score : 0
                    errors.Push({desc: item.desc, expected: label, actual: selectedName, reason: "wrong_winner",
                        score: topScore, margin: topScore - secScore, top2: top2})
                }
            }
        }
    } catch Error as e {
        FileAppend("CRASH in Step 5: " . e.Message . " line=" . e.Line . " file=" . e.File . "`nStack:`n" . e.Stack . "`n", logPath)
        ExitApp(1)
    }

    acc := Round(correct / total * 100, 1)
    rejRate := Round(rejected / total * 100, 1)
    misRate := Round(misclassified / total * 100, 1)

    ; P95 门禁 v2 (P0-2): warmup 剔除 + P50/P95/P99/max; A_TickCount 量子约 15.6ms,
    ; 默认 gate 50ms; RIM_P95_GATE 环境变量可收紧 (CI 用小阈值自证会失败)
    st := Bench_Sort(times)
    p50 := Bench_Pct(st, 0.5)
    p95 := Bench_Pct(st, 0.95)
    p99 := Bench_Pct(st, 0.99)
    mx := st.Length > 0 ? st[st.Length] : 0
    sd := Bench_Sort(tDir)
    sc2 := Bench_Sort(tCollect)
    ss := Bench_Sort(tSelect)
    gate := 50
    try {
        g := EnvGet("RIM_P95_GATE")
        if (g != "" && IsNumber(g))
            gate := Integer(g)
    }
    warnLo := 30

    rpt := "====================================================`n"
    rpt .= "RIM GESTURE RECOGNITION BENCHMARK REPORT`n"
    rpt .= "====================================================`n"
    rpt .= "Total Samples:   " . total . "`n"
    rpt .= "Correct:         " . correct . " (" . acc . "%)`n"
    rpt .= "Rejected:        " . rejected . " (" . rejRate . "%)`n"
    rpt .= "Misclassified:   " . misclassified . " (" . misRate . "%)`n"
    rpt .= "P50 Eval:        " . p50 . "ms`n"
    rpt .= "P95 Eval:        " . p95 . "ms (gate <= " . gate . "ms)`n"
    rpt .= "P99 Eval:        " . p99 . "ms`n"
    rpt .= "Max Eval:        " . mx . "ms`n"
    rpt .= "Split P95:       dir=" . Bench_Pct(sd, 0.95) . "ms collect=" . Bench_Pct(sc2, 0.95) . "ms select=" . Bench_Pct(ss, 0.95) . "ms`n`n"
    rpt .= "NOTE: train/test same-source (template-generated samples); 100% does not imply unseen-user accuracy; negatives in probe_gesture_unified.ahk`n`n"

    rpt .= "--- CONFUSION (label -> pred=cnt) ---`n"
    for lab, preds in confusion {
        line := lab . ": "
        for pred, cnt in preds
            line .= pred . "=" . cnt . " "
        rpt .= RTrim(line) . "`n"
    }
    rpt .= "`n--- MISCLASSIFICATIONS & REJECTIONS (with top2) ---`n"
    for err in errors {
        scoreInfo := err.score ? (" score=" . Round(err.score, 1) . " margin=" . Round(err.margin, 1)) : ""
        rpt .= "Case: " . err.desc . "`n  -> Expected: " . err.expected . "`n  -> Actual:   " . err.actual . "`n  -> Reason:   " . err.reason . scoreInfo . " top2=" . err.top2 . "`n`n"
    }

    rpt .= "--- METRICS (machine-parseable) ---`n"
    rpt .= "metric total=" . total . "`n"
    rpt .= "metric correct=" . correct . "`n"
    rpt .= "metric accuracy=" . acc . "`n"
    rpt .= "metric rejected=" . rejected . "`n"
    rpt .= "metric misclassified=" . misclassified . "`n"
    rpt .= "metric p50_ms=" . p50 . "`n"
    rpt .= "metric p95_ms=" . p95 . "`n"
    rpt .= "metric p99_ms=" . p99 . "`n"
    rpt .= "metric max_ms=" . mx . "`n"
    rpt .= "metric gate_ms=" . gate . "`n"
    rpt .= "====================================================`n"
    FileAppend(rpt, outPath, "UTF-8")
    ; P0-2: 双写统一路径 (仓库根 benchmark_out.txt 供 CI 解析, 与 tools 内报告同内容)
    rootOut := A_ScriptDir . "\..\benchmark_out.txt"
    try FileDelete(rootOut)
    catch {
    }
    FileAppend(rpt, rootOut, "UTF-8")
    FileAppend("Completed. Report saved to " . outPath . " + " . rootOut . "`n", logPath)
    if (p95 > gate) {
        FileAppend("P95 GATE FAILED: " . p95 . "ms > " . gate . "ms`n", logPath)
        ExitApp(1)
    }
    if (p95 > warnLo) {
        FileAppend("P95 WARN: " . p95 . "ms in [" . warnLo . "--" . gate . "]ms jitter band`n", logPath)
    }
}
