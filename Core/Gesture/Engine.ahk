#Requires AutoHotkey v2.0
#Warn All, Off

; === Core/Gesture/Engine.ahk - 手势核心引擎与分发协调器 (Gesture Engine & Orchestrator) ===
; 整合 Recognizer、Registry、Hook、Template 与 INI 配置层，完成从采样点到动作执行的全流程流转。

class GestureEngine {
    static fnHideTip := ObjBindMethod(GestureEngine, "HideTip")

    static stats := {
        total: 0,
        recognized: 0,
        missed: 0,
        lastPattern: "",
        lastAction: "",
        lastLayer: ""
    }

    ; ---- 实时采样点识别 (在 Hook.OnPoll 中触发) ----
    static Recognize() {
        global g_Gesture
        pts := g_Gesture["points"]
        if (pts.Length < 2)
            return
        s := GestureRecognizer.DirectionChain(pts, g_Gesture["segment"])
        dirs := (s = "") ? [] : StrSplit(s, "_")
        g_Gesture["dirs"] := dirs
        g_Gesture["gesture"] := s
    }

    ; ---- 手势完成时的全流程分发 (Hook.OnUp 触发) ----
    static DispatchComplete(gesture, pts, leftCombo := false) {
        global g_Gesture

        ; 1. 录制模式截获
        if (g_Gesture["recording"]) {
            if (gesture = "")
                return
            g_Gesture["recorded"] := gesture
            cb := g_Gesture["recordCb"]
            GestureEngine.CancelRecord()
            try ToolTip(T("gesture.recorded_is", gesture))
            SetTimer(GestureEngine.fnHideTip, -1200)
            if (IsObject(cb))
                try cb(gesture)
            return
        }

        ; 2. 模板录制截获
        if (g_Gesture["tplRecording"]) {
            tcb := g_Gesture["tplRecordCb"]
            g_Gesture["tplRecording"] := 0
            g_Gesture["tplRecordCb"] := ""
            enc := ""
            try {
                enc := "v2:" . Tpl_Encode(Tpl_Prepare(g_Gesture["points"]))
                ToolTip(T("gesture.tpl_recorded2"))
            } catch {
            }
            SetTimer(GestureEngine.fnHideTip, -1200)
            if (IsObject(tcb) && enc != "")
                try tcb(enc)
            return
        }

        ; 3. 左键组合技 (画 L/R 时按左键切窗口)
        if (leftCombo && (gesture = "L" || gesture = "R")) {
            if (g_Gesture["tryMode"]) {
                try ToolTip(T("gesture.try_hit", gesture . "+LButton",
                    gesture = "L" ? "<SP_SwitchLast>" : "<SP_SwitchNext>", "组合"))
                SetTimer(GestureEngine.fnHideTip, -2000)
            } else if (gesture = "L") {
                try Send("!+{Esc}")
            } else {
                try Send("!{Esc}")
            }
            return
        }

        ; 4. 获取起点窗口上下文与修饰键
        ctx := g_Gesture["startContext"]
        exe := IsObject(ctx) ? ctx.exe : ""
        cls := IsObject(ctx) ? ctx.cls : ""
        title := IsObject(ctx) ? ctx.title : ""
        ownerCls := IsObject(ctx) ? ctx.ownerCls : ""
        ctrlCls := IsObject(ctx) ? ctx.ctrlCls : ""
        ctrlTitle := IsObject(ctx) ? ctx.ctrlTitle : ""

        mods := g_Gesture.Has("downMods") ? g_Gesture["downMods"] : ""

        ; 5. 多层候选解析: 动态 Registry -> App 层 -> 全局层 -> 模板层
        res := GestureEngine.ResolveStroke(gesture, pts, exe, cls, title, mods, ownerCls, ctrlCls, ctrlTitle)
        action := res[1]
        layer := res[2]

        GestureEngine.stats.total++
        GestureEngine.stats.lastPattern := gesture

        if (action != "") {
            GestureEngine.stats.recognized++
            GestureEngine.stats.lastAction := Type(action) = "String" ? action : "Func"
            GestureEngine.stats.lastLayer := layer

            ; 试笔模式: 仅提示不执行
            if (g_Gesture["tryMode"]) {
                disp := mods . gesture
                actStr := Type(action) = "String" ? action : "Function"
                try ToolTip(T("gesture.try_hit", disp, actStr, layer) . "`n" . GestureEngine.CandidateSummary())
                SetTimer(GestureEngine.fnHideTip, -2000)
                return
            }

            GestureEngine.ExecuteAction(action)
            return
        }

        ; 未命中
        GestureEngine.stats.missed++
        if (g_Gesture["tryMode"]) {
            try ToolTip(T("gesture.try_miss", gesture) . "`n" . GestureEngine.CandidateSummary())
            SetTimer(GestureEngine.fnHideTip, -2000)
            return
        }

        if (g_Gesture["noMatch"] = "passthrough") {
            GestureHook.RelayStroke(true)
            return
        }

        if (g_Gesture["noMatch"] = "sound") {
            try SoundBeep(750, 120)
        }

        ; OSD 关闭时保持静默 (试笔模式除外, 那是显式诊断流程)
        if (g_Gesture["showOSD"] || g_Gesture["tryMode"]) {
            try ToolTip(T("gesture.unknown", gesture))
            SetTimer(GestureEngine.fnHideTip, -900)
        }
    }

    ; ---- 统一候选解析: 收集各层候选并评判胜出者 ----
    static ResolveStroke(gestureStr, pts, exe, cls, title, mods := "", ownerCls := "", ctrlCls := "", ctrlTitle := "") {
        global g_Gesture
        candidates := GestureEngine.CollectCandidates(gestureStr, pts)
        decision := GestureEngine.SelectCandidate(candidates, exe, cls, title, mods, ownerCls, ctrlCls, ctrlTitle)
        
        g_Gesture["candidateList"] := decision.candidates
        g_Gesture["candidate"] := decision.selected
        if (!IsObject(decision.selected))
            return ["", decision.reason]
        return [decision.selected.action, decision.selected.layer]
    }

    ; ---- 候选收集: 方向量化 + 模板识别 ----
    static CollectCandidates(direction, pts) {
        global g_GestureDefs, g_TplThreshold, g_Gesture
        if !IsSet(g_GestureDefs)
            g_GestureDefs := Map()

        out := []
        normDir := GestureRecognizer.Normalize(direction)
        if (normDir != "") {
            isDefined := g_GestureDefs.Has(normDir)
            if (!isDefined && IsSet(GestureRegistry) && IsObject(GestureRegistry)) {
                for _, item in GestureRegistry.List() {
                    basePat := RegExReplace(item.pattern, "^.*[\+\^!#]", "")
                    if (basePat = normDir) {
                        isDefined := true
                        break
                    }
                }
            }
            if (isDefined) {
                def := g_GestureDefs.Has(normDir) ? g_GestureDefs[normDir] : {method: "auto"}
                if (def.method = "direction" || def.method = "auto") {
                    dirScore := GestureRecognizer.DirectionConfidence(pts, normDir)
                    out.Push({name: normDir, method: "direction", score: dirScore, sample: 0})
                }
            }
        }

        ; 模板匹配
        if (IsObject(pts) && pts.Length >= 3) {
            minSize := 20
            try minSize := Max(20, g_Gesture["threshold"] + 0)
            try {
                matches := Tpl_Candidates(pts, minSize)
                for _, candidate in matches {
                    tName := GestureRecognizer.Normalize(candidate.name)
                    if (!g_GestureDefs.Has(tName) || GestureEngine.TplOff(tName))
                        continue
                    def := g_GestureDefs[tName]
                    if (def.method != "template" && def.method != "auto")
                        continue
                    if (candidate.score < g_TplThreshold)
                        continue
                    out.Push({name: tName, method: "template", score: candidate.score, sample: candidate.sample})
                }
            }
        }
        return out
    }

    ; ---- 候选裁决 (按优先级与置信度打分) ----
    static SelectCandidate(candidates, exe, cls, title, mods := "", ownerCls := "", ctrlCls := "", ctrlTitle := "") {
        global g_TplThreshold, g_Gesture
        ranked := []

        for _, candidate in candidates {
            binding := GestureEngine.ResolveFor(candidate.name, exe, cls, mods, title, ownerCls, ctrlCls, ctrlTitle)
            if (binding[1] = "")
                continue
            candidate.action := binding[1]
            candidate.layer := binding[2]
            ranked.Push(candidate)
        }

        if (ranked.Length = 0)
            return {selected: "", candidates: candidates, reason: "unbound"}

        ; 优先级: 插件/应用层优先
        appRanked := []
        for _, candidate in ranked {
            if (candidate.layer != "global" && candidate.layer != "全局")
                appRanked.Push(candidate)
        }
        evalPool := (appRanked.Length > 0) ? appRanked : ranked

        best := evalPool[1]
        second := ""
        for _, candidate in evalPool {
            if (candidate.score > best.score) {
                second := best
                best := candidate
            } else if (candidate.name != best.name && (!IsObject(second) || candidate.score > second.score)) {
                second := candidate
            }
        }

        ordered := [best]
        if (IsObject(second))
            ordered.Push(second)

        minThresh := g_TplThreshold
        try {
            if (g_Gesture.Has("tplThreshold") && g_Gesture["tplThreshold"] > 0)
                minThresh := g_Gesture["tplThreshold"]
        }
        if (best.score < minThresh)
            return {selected: "", candidates: ordered, reason: "below_threshold"}

        minMargin := 6.0
        try {
            if (g_Gesture.Has("margin") && g_Gesture["margin"] > 0)
                minMargin := g_Gesture["margin"] + 0.0
        }
        if (IsObject(second) && (best.action != second.action) && (best.score - second.score < minMargin))
            return {selected: "", candidates: ordered, reason: "ambiguous"}

        return {selected: best, candidates: ordered, reason: "matched"}
    }

    ; ---- 分层解析手势: Registry -> App -> Global ----
    static ResolveFor(gesture, exe, cls, mods := "", title := "", ownerCls := "", ctrlCls := "", ctrlTitle := "") {
        global g_GestureMap
        g := GestureRecognizer.Normalize(gesture)
        if (g = "")
            return ["", ""]

        ; 1. 动态注册中心 (代码/插件注册)
        regMatch := GestureRegistry.Resolve(g, exe, cls, title, mods, ownerCls, ctrlCls, ctrlTitle)
        if (IsObject(regMatch) && regMatch.action != "")
            return [regMatch.action, regMatch.layer]

        ; 2. INI 应用层匹配
        app := GestureEngine.MatchApp(exe, cls, title, ownerCls, ctrlCls, ctrlTitle)
        if (IsObject(app)) {
            action := GestureEngine.LookupUnified(app.map, g, mods, app.name)
            if (action != "")
                return [action, app.name]
            if (GestureEngine.AppField(app, "noglobal"))
                return ["", ""]
        }

        ; 3. INI 全局层匹配
        if (IsSet(g_GestureMap) && IsObject(g_GestureMap)) {
            action := GestureEngine.LookupUnified(g_GestureMap, g, mods, "全局")
            if (action != "")
                return [action, "全局"]
        }

        return ["", ""]
    }

    static LookupUnified(mapObj, name, mods, layer) {
        name := GestureRecognizer.Normalize(name)
        try {
            if (mods != "") {
                key := GestureRecognizer.NormalizeFull(mods . name)
                if (mapObj.Has(key) && !GestureEngine.ChainOff(layer, key))
                    return mapObj[key]
            }
            if (mapObj.Has(name) && !GestureEngine.ChainOff(layer, name))
                return mapObj[name]
        }
        return ""
    }

    ; ---- 动作执行器 ----
    static ExecuteAction(action) {
        global g_GestureHookBefore, g_GestureHookAfter
        if (Type(action) = "String" && Trim(action) = "")
            return
        if (!IsObject(action) && Type(action) != "String")
            return

        ; 前钩子
        if (IsSet(g_GestureHookBefore) && IsObject(g_GestureHookBefore)) {
            try {
                if (g_GestureHookBefore.Call(action))
                    return
            }
        }

        ; 函数对象直接调用
        if (IsObject(action) && HasMethod(action, "Call")) {
            action.Call()
        } else if (Type(action) = "String") {
            actStr := Trim(action)
            if (actStr = "")
                return

            if (SubStr(actStr, 1, 6) = "combo|") {
                GestureEngine.ComboArm(actStr)
                return
            }

            try {
                if (IsSet(VIMD_CMD)) {
                    VIMD_CMD(actStr)
                    return
                }
            } catch {
            }

            ; 兜底派发 (当 VIMD_CMD 不存在或调用失败时直接执行)
            if (SubStr(actStr, 1, 4) = "run|" || SubStr(actStr, 1, 5) = "file|") {
                target := SubStr(actStr, SubStr(actStr, 1, 4) = "run|" ? 5 : 6)
                try Run(target)
            } else if (SubStr(actStr, 1, 4) = "key|") {
                try Send(SubStr(actStr, 5))
            } else {
                try {
                    fn := actStr
                    %fn%()
                }
            }
        }

        ; 后钩子
        if (IsSet(g_GestureHookAfter) && IsObject(g_GestureHookAfter)) {
            try g_GestureHookAfter.Call(action)
        }
    }

    ; ---- 滚轮手势路由 ----
    static HandleWheel(which) {
        global g_Gesture
        if (!g_Gesture["enable"]) {
            try Send("{" . which . "}")
            return
        }

        held := false
        try held := GetKeyState(g_Gesture["trigger"], "P")
        leftHeld := false
        try leftHeld := GetKeyState("LButton", "P")

        gestureDown := g_Gesture["down"]
        ctx := g_Gesture["startContext"]
        exe := (gestureDown && IsObject(ctx)) ? ctx.exe : ""
        cls := (gestureDown && IsObject(ctx)) ? ctx.cls : ""
        title := (gestureDown && IsObject(ctx)) ? ctx.title : ""
        ownerCls := (gestureDown && IsObject(ctx)) ? ctx.ownerCls : ""
        ctrlCls := (gestureDown && IsObject(ctx)) ? ctx.ctrlCls : ""
        ctrlTitle := (gestureDown && IsObject(ctx)) ? ctx.ctrlTitle : ""

        if (!gestureDown || !IsObject(ctx)) {
            try exe := WinGetProcessName("A")
            try cls := WinGetClass("A")
            try title := WinGetTitle("A")
        }

        ; 组合: 触发键 + 左键 + 滚轮 -> 调音量.
        ; 两种进法: ① 按住左键的同时滚 (经典, 常开);
        ; ② 点一下左键锁存音量模式后松开左键再滚 (需 VolLatch=1,
        ;    Hook.OnLeftDown/OnPoll 置 volMode, 本次右键会话内有效, 松开左键仍可连滚).
        if (held && leftHeld && (which = "WheelUp" || which = "WheelDown")) {
            if (gestureDown && g_Gesture["volLatch"]) {
                g_Gesture["volMode"] := 1
                g_Gesture["volUsed"] := 1
            }
            if (g_Gesture["tryMode"]) {
                try ToolTip(T("gesture.try_wheel", which . "+LButton",
                    which = "WheelUp" ? "<SP_VolUp>" : "<SP_VolDown>", "组合"))
                SetTimer(GestureEngine.fnHideTip, -2000)
            } else {
                try Send(which = "WheelUp" ? "{Volume_Up}" : "{Volume_Down}")
            }
            return
        }
        volLatched := false
        try volLatched := gestureDown && g_Gesture["volLatch"] && g_Gesture["volMode"]
        if (volLatched && (which = "WheelUp" || which = "WheelDown")) {
            g_Gesture["volUsed"] := 1
            if (g_Gesture["tryMode"]) {
                try ToolTip(T("gesture.try_wheel", which . "+LButton",
                    which = "WheelUp" ? "<SP_VolUp>" : "<SP_VolDown>", "组合"))
                SetTimer(GestureEngine.fnHideTip, -2000)
            } else {
                try Send(which = "WheelUp" ? "{Volume_Up}" : "{Volume_Down}")
            }
            return
        }

        ; 组合技激活 (如 Z 画完滚轮缩放)
        if (GestureEngine.ComboActive()) {
            if (!held) {
                try Send("{" . which . "}")
                return
            }
            if (which = "WheelUp" || which = "WheelDown") {
                if (g_Gesture["tryMode"]) {
                    try ToolTip(T("gesture.try_zoom", which))
                    SetTimer(GestureEngine.fnHideTip, -1200)
                } else {
                    try Send(which = "WheelUp" ? "^{WheelUp}" : "^{WheelDown}")
                }
                return
            }
            try Send("{" . which . "}")
            return
        }

        if (!held || GestureHook.IsBypass(false, gestureDown ? ctx : "")) {
            try Send("{" . which . "}")
            return
        }

        mods := g_Gesture.Has("downMods") ? g_Gesture["downMods"] : ""
        if (mods = "" || !gestureDown)
            mods := GestureRecognizer.ActiveMods()

        res := GestureEngine.ResolveFor(which, exe, cls, mods, title, ownerCls, ctrlCls, ctrlTitle)
        if (res[1] != "") {
            if (g_Gesture["tryMode"]) {
                disp := (mods . which)
                actStr := Type(res[1]) = "String" ? res[1] : "Function"
                try ToolTip(T("gesture.try_wheel", disp, actStr, res[2]))
                SetTimer(GestureEngine.fnHideTip, -2000)
                return
            }
            GestureEngine.ExecuteAction(res[1])
            if (g_Gesture["showOSD"]) {
                actStr := Type(res[1]) = "String" ? res[1] : "Function"
                try ToolTip(T("gesture.wheel", (mods . which), actStr, res[2]))
                SetTimer(GestureEngine.fnHideTip, -900)
            }
            return
        }

        try Send("{" . which . "}")
    }

    ; ---- OSD 呈现 (本体自守卫: 调用方一般已 gate, 这里兜底) ----
    static OSD() {
        global g_Gesture
        if (!g_Gesture["showOSD"] && !g_Gesture["tryMode"])
            return
        g := g_Gesture["gesture"]
        txt := T("gesture.osd_gesture", (g = "" ? "..." : g))
        if (g_Gesture["recording"])
            txt := T("gesture.osd_recording", (g = "" ? "..." : g))
        else if (g != "") {
            ctx := g_Gesture["startContext"]
            exe := IsObject(ctx) ? ctx.exe : ""
            cls := IsObject(ctx) ? ctx.cls : ""
            title := IsObject(ctx) ? ctx.title : ""
            ownerCls := IsObject(ctx) ? ctx.ownerCls : ""
            ctrlCls := IsObject(ctx) ? ctx.ctrlCls : ""
            ctrlTitle := IsObject(ctx) ? ctx.ctrlTitle : ""
            mods := g_Gesture.Has("downMods") ? g_Gesture["downMods"] : ""

            res := GestureEngine.ResolveStroke(g, g_Gesture["points"], exe, cls, title, mods, ownerCls, ctrlCls, ctrlTitle)
            if (res[1] != "") {
                actStr := Type(res[1]) = "String" ? res[1] : "Function"
                txt .= "`n" . T("gesture.osd_action", actStr, res[2])
            }
            summary := GestureEngine.CandidateSummary()
            if (summary != "")
                txt .= "`n" . summary
        }
        ToolTip(txt)
    }

    static CandidateSummary() {
        global g_Gesture
        try {
            items := g_Gesture["candidateList"]
            if (!IsObject(items) || items.Length = 0)
                return ""
            out := ""
            for index, candidate in items {
                if (index > 2)
                    break
                out .= (out = "" ? "" : " | ") . candidate.name . " " . Round(candidate.score)
                    . " (" . candidate.method . ")"
            }
            return out
        }
        return ""
    }

    ; ---- 组合技状态管理 ----
    static PollComboArm() {
        global g_Gesture
        try {
            g := g_Gesture["gesture"]
            if (g = "")
                return
            ctx := g_Gesture["startContext"]
            exe := IsObject(ctx) ? ctx.exe : ""
            cls := IsObject(ctx) ? ctx.cls : ""
            title := IsObject(ctx) ? ctx.title : ""
            ownerCls := IsObject(ctx) ? ctx.ownerCls : ""
            ctrlCls := IsObject(ctx) ? ctx.ctrlCls : ""
            ctrlTitle := IsObject(ctx) ? ctx.ctrlTitle : ""
            mods := g_Gesture.Has("downMods") ? g_Gesture["downMods"] : ""

            res := GestureEngine.ResolveStroke(g, g_Gesture["points"], exe, cls, title, mods, ownerCls, ctrlCls, ctrlTitle)
            if (res[1] != "" && Type(res[1]) = "String" && SubStr(Trim(res[1]), 1, 6) = "combo|")
                GestureEngine.ComboArm(res[1])
            else if (g_Gesture["comboUntil"] > 0) {
                g_Gesture["comboUntil"] := 0
                g_Gesture["comboKind"] := ""
            }
        }
    }

    static ComboArm(action) {
        global g_Gesture
        kind := StrLower(Trim(SubStr(action, 7)))
        if (kind = "zoom") {
            wasActive := (g_Gesture["comboKind"] = kind && GestureEngine.ComboActive())
            g_Gesture["comboUntil"] := A_TickCount + 1500
            g_Gesture["comboKind"] := kind
            if (!wasActive && (g_Gesture["showOSD"] || g_Gesture["tryMode"])) {
                tip := g_Gesture["tryMode"] ? T("gesture.arm_zoom") : T("gesture.zoom_ready")
                try ToolTip(tip)
                SetTimer(GestureEngine.fnHideTip, -1500)
            }
        }
    }

    static ComboActive() {
        global g_Gesture
        try return g_Gesture["comboUntil"] > A_TickCount
        return false
    }

    ; ---- 黑名单 & 应用匹配辅助 ----
    static IsBlacklisted(exe, cls, title) {
        global g_GestureBlacklist
        if (!IsSet(g_GestureBlacklist) || !IsObject(g_GestureBlacklist))
            return false
        for _, pat in g_GestureBlacklist {
            if (pat = "" || GestureEngine.BlOff(pat))
                continue
            if (exe != "" && StrLower(exe) = StrLower(pat))
                return true
            if (cls != "" && StrLower(cls) = StrLower(pat))
                return true
            if (title != "" && InStr(title, pat))
                return true
        }
        return false
    }

    static MatchApp(exe, cls, title := "", ownerCls := "", ctrlCls := "", ctrlTitle := "") {
        global g_GestureApps
        if (!IsSet(g_GestureApps) || !IsObject(g_GestureApps))
            return ""
        bestApp := ""
        bestSpec := -1
        for _, app in g_GestureApps {
            ex := GestureEngine.AppField(app, "exe")
            cl := GestureEngine.AppField(app, "cls")
            ti := GestureEngine.AppField(app, "title")
            rx := GestureEngine.AppField(app, "titleRx")
            ow := GestureEngine.AppField(app, "ownerCls")
            cc := GestureEngine.AppField(app, "ctrlCls")
            ct := GestureEngine.AppField(app, "ctrlTitle")
            nm := GestureEngine.AppField(app, "name")
            if (nm != "" && GestureEngine.LayerOff(nm))
                continue
            if (ex = "" && cl = "" && ti = "" && rx = "" && ow = "" && cc = "" && ct = "")
                continue
            if (ex != "" && !GestureEngine.MatchList(exe, ex))
                continue
            if (cl != "" && !GestureEngine.MatchList(cls, cl))
                continue
            if (ti != "" && (title = "" || !InStr(StrLower(title), StrLower(ti))))
                continue
            if (rx != "" && title = "")
                continue
            if (rx != "") {
                found := false
                try found := (RegExMatch(title, rx) > 0)
                if (!found)
                    continue
            }
            if (ow != "" && !GestureEngine.MatchContextClasses(ownerCls, ow))
                continue
            if (cc != "" && !GestureEngine.MatchList(ctrlCls, cc))
                continue
            if (ct != "" && (ctrlTitle = "" || !InStr(StrLower(ctrlTitle), StrLower(ct))))
                continue
            spec := GestureEngine.AppSpecificity(app)
            if (spec > bestSpec) {
                bestSpec := spec
                bestApp := app
            }
        }
        return bestApp
    }

    static MatchContextClasses(value, patterns) {
        for _, candidate in StrSplit(value, "|") {
            if (GestureEngine.MatchList(candidate, patterns))
                return true
        }
        return false
    }

    static MatchList(value, patterns) {
        value := Trim(value)
        if (value = "")
            return false
        for _, pat in StrSplit(patterns, "|") {
            if (Trim(pat) != "" && StrLower(value) = StrLower(Trim(pat)))
                return true
        }
        return false
    }

    static AppField(app, field) {
        try return app.%field%
        return ""
    }

    static AppSpecificity(app) {
        spec := 0
        if (GestureEngine.AppField(app, "ctrlTitle") != "")
            spec += 16
        if (GestureEngine.AppField(app, "ctrlCls") != "")
            spec += 8
        if (GestureEngine.AppField(app, "titleRx") != "")
            spec += 8
        if (GestureEngine.AppField(app, "title") != "")
            spec += 4
        if (GestureEngine.AppField(app, "ownerCls") != "")
            spec += 2
        if (GestureEngine.AppField(app, "cls") != "")
            spec += 2
        if (GestureEngine.AppField(app, "exe") != "")
            spec += 1
        return spec
    }

    ; ---- 禁用集检查 ----
    static DisabledHas(id) {
        global g_GestureDisabled
        try return g_GestureDisabled.Has(id)
        return false
    }
    static ChainOff(layer, key) {
        return GestureEngine.DisabledHas(layer . ":" . key)
    }
    static TplOff(name) {
        return GestureEngine.DisabledHas("模板:" . name)
    }
    static BlOff(pat) {
        return GestureEngine.DisabledHas("黑名单:" . pat)
    }
    static LayerOff(name) {
        return GestureEngine.DisabledHas("应用层:" . name)
    }

    ; ---- 录制控制 ----
    static CancelRecord() {
        global g_Gesture
        g_Gesture["recording"] := 0
        g_Gesture["recordCb"] := ""
    }

    static HideTip() {
        try ToolTip()
        try SetTimer(GestureEngine.fnHideTip, 0)
    }

    ; ---- 初始化与配置载入 ----
    static Init() {
        global g_Gesture
        GestureEngine.LoadConfig()
        try Tpl_LoadAll()
        catch {
        }
        GestureEngine.ReloadLayers()
        if (!g_Gesture["enable"])
            return false
        GestureHook.Bind(g_Gesture["trigger"])
        return true
    }

    static LoadConfig() {
        global g_Gesture, g_Conf
        try {
            if (IsSet(g_Conf) && IsObject(g_Conf) && g_Conf.HasSection("Gesture")) {
                sec := g_Conf["Gesture"]
                if sec.Has("Enable")
                    g_Gesture["enable"] := (sec["Enable"] = "1") ? 1 : 0
                if sec.Has("Threshold") && (sec["Threshold"] + 0 > 0)
                    g_Gesture["threshold"] := sec["Threshold"] + 0
                ; 形状阈值主鍵 TemplateThreshold (设置页写入), TplThreshold 作旧别名兼容
                if sec.Has("TemplateThreshold") && (sec["TemplateThreshold"] + 0 > 0)
                    g_Gesture["tplThreshold"] := sec["TemplateThreshold"] + 0
                else if sec.Has("TplThreshold") && (sec["TplThreshold"] + 0 > 0)
                    g_Gesture["tplThreshold"] := sec["TplThreshold"] + 0
                if sec.Has("Segment") && (sec["Segment"] + 0 > 0)
                    g_Gesture["segment"] := sec["Segment"] + 0
                if sec.Has("Poll") && (sec["Poll"] + 0 >= 5)
                    g_Gesture["poll"] := sec["Poll"] + 0
                if sec.Has("CancelDelay") && (sec["CancelDelay"] + 0 >= 0)
                    g_Gesture["cancelDelay"] := sec["CancelDelay"] + 0
                if sec.Has("ShowOSD")
                    g_Gesture["showOSD"] := (sec["ShowOSD"] = "1") ? 1 : 0
                if sec.Has("Trigger") {
                    t := Trim(sec["Trigger"])
                    if (t = "RButton" || t = "MButton" || t = "XButton1" || t = "XButton2")
                        g_Gesture["trigger"] := t
                }
                if sec.Has("NoMatch") {
                    nm := StrLower(Trim(sec["NoMatch"]))
                    if (nm = "swallow" || nm = "passthrough" || nm = "sound")
                        g_Gesture["noMatch"] := nm
                }
                if sec.Has("IgnoreKey")
                    g_Gesture["ignoreKey"] := Trim(sec["IgnoreKey"])
                ; 右键按住时点左键锁存音量模式 (0=关闭, 左键直通恢复旧行为)
                if sec.Has("VolLatch")
                    g_Gesture["volLatch"] := (sec["VolLatch"] = "1") ? 1 : 0
                if sec.Has("OnlyDefinedApps")
                    g_Gesture["onlyDefined"] := (sec["OnlyDefinedApps"] = "1") ? 1 : 0
                if sec.Has("Trail")
                    g_Gesture["trail"] := (sec["Trail"] = "1") ? 1 : 0
                if sec.Has("TrailColor") && Trim(sec["TrailColor"]) != ""
                    g_Gesture["trailColor"] := Trim(sec["TrailColor"])
                if sec.Has("TrailWidth") && (sec["TrailWidth"] + 0 > 0)
                    g_Gesture["trailWidth"] := sec["TrailWidth"] + 0
            }
        }
    }

    static ReloadLayers() {
        global g_GestureMap, g_GestureApps, g_GestureBlacklist, g_GestureAppPrefix, g_Conf, g_GestureDisabled
        global g_GestureDefs
        g_GestureMap := Map()
        g_GestureApps := []
        g_GestureBlacklist := []
        g_GestureDisabled := Map()
        g_GestureDefs := Map()

        if (!IsSet(g_Conf) || !IsObject(g_Conf))
            return

        try {
            if (g_Conf.HasSection("GestureDefinitions")) {
                for rawName, rawMethod in g_Conf["GestureDefinitions"] {
                    name := GestureRecognizer.Normalize(rawName)
                    method := StrLower(Trim(rawMethod))
                    if (name != "" && (method = "direction" || method = "template" || method = "auto"))
                        g_GestureDefs[name] := {method: method, enabled: 1}
                }
            }
        }
        try {
            if (g_Conf.HasSection("Gestures")) {
                for rawKey, rawAction in g_Conf["Gestures"] {
                    key := GestureRecognizer.NormalizeFull(rawKey)
                    action := Trim(rawAction)
                    if (key != "" && action != "")
                        g_GestureMap[key] := action
                }
            }
        }
        try {
            if (g_Conf.HasSection("GestureBlacklist")) {
                for rawKey, rawValue in g_Conf["GestureBlacklist"] {
                    pat := Trim(rawKey)
                    if (pat != "" && SubStr(pat, 1, 1) != ";")
                        g_GestureBlacklist.Push(pat)
                }
            }
        }
        try {
            if (g_Conf.HasSection("GestureDisabled")) {
                for rawKey, rawValue in g_Conf["GestureDisabled"] {
                    id := Trim(rawKey)
                    if (id != "" && SubStr(id, 1, 1) != ";")
                        g_GestureDisabled[id] := 1
                }
            }
        }
        try {
            for sectionName, section in g_Conf.GetSections() {
                if (SubStr(sectionName, 1, StrLen(g_GestureAppPrefix)) != g_GestureAppPrefix)
                    continue
                appName := SubStr(sectionName, StrLen(g_GestureAppPrefix) + 1)
                if (Trim(appName) = "")
                    continue
                exe := g_Conf.Get(sectionName, "set_file", "")
                cls := g_Conf.Get(sectionName, "set_class", "")
                title := g_Conf.Get(sectionName, "set_title", "")
                titleRx := g_Conf.Get(sectionName, "set_title_regex", "")
                ownerCls := g_Conf.Get(sectionName, "set_owner_class", "")
                ctrlCls := g_Conf.Get(sectionName, "set_ctrl_class", "")
                ctrlTitle := g_Conf.Get(sectionName, "set_ctrl_title", "")
                noglobal := (g_Conf.Get(sectionName, "noglobal", "0") = "1") ? 1 : 0
                mp := Map()
                for rawKey, rawAction in section {
                    key := Trim(rawKey)
                    action := Trim(rawAction)
                    if (key = "" || action = "" || SubStr(key, 1, 1) = ";")
                        continue
                    if (SubStr(key, 1, 4) = "set_" || SubStr(key, 1, 7) = "enable_" || StrLower(key) = "noglobal")
                        continue
                    mp[GestureRecognizer.NormalizeFull(key)] := action
                }
                g_GestureApps.Push({name: appName, exe: exe, cls: cls, title: title, titleRx: titleRx,
                    ownerCls: ownerCls, ctrlCls: ctrlCls, ctrlTitle: ctrlTitle, noglobal: noglobal, map: mp})
            }
        }
        try {
            if IsSet(g_Templates) {
                for name, t in g_Templates
                    if !g_GestureDefs.Has(name)
                        g_GestureDefs[name] := {method: "template", enabled: 1}
            }
        }
        for key, action in g_GestureMap
            GestureEngine.DefinitionEnsure(GestureRecognizer.BindingName(key), "direction")
        for _, app in g_GestureApps
            for key, action in app.map
                GestureEngine.DefinitionEnsure(GestureRecognizer.BindingName(key), "direction")
    }

    static DefinitionEnsure(name, method := "") {
        global g_GestureDefs
        if !IsSet(g_GestureDefs)
            g_GestureDefs := Map()
        name := GestureRecognizer.Normalize(name)
        if (name = "")
            return
        if (method = "") {
            try method := IsObject(Tpl_Get(name)) ? "template" : "direction"
            catch {
                method := "direction"
            }
        }
        if !g_GestureDefs.Has(name)
            g_GestureDefs[name] := {method: method, enabled: 1}
    }

    static DefineGesture(name, method := "") {
        GestureEngine.DefinitionEnsure(name, method)
    }

    static DefinitionMethod(name) {
        global g_GestureDefs
        name := GestureRecognizer.Normalize(name)
        try {
            if g_GestureDefs.Has(name)
                return g_GestureDefs[name].method
        }
        return "direction"
    }

    static DefinitionOff(name) {
        return GestureEngine.DisabledHas("Global:" . GestureRecognizer.Normalize(name))
    }

    static SetTryMode(on) {
        global g_Gesture
        g_Gesture["tryMode"] := on ? 1 : 0
        try {
            if (IsSet(g_SkinConf) && g_SkinConf["ShowTrayIcon"] = "1")
                A_TrayMenu.ToggleCheck(T("gesture.tray_try"))
        }
    }

    static IsTryMode() {
        global g_Gesture
        return g_Gesture["tryMode"]
    }

    static ToggleTryMode(*) {
        GestureEngine.SetTryMode(!GestureEngine.IsTryMode())
        try ToolTip(GestureEngine.IsTryMode() ? T("gesture.try_on") : T("gesture.try_off"))
        SetTimer(GestureEngine.fnHideTip, -900)
    }

    static IgnoreNext() {
        global g_Gesture
        g_Gesture["ignoreNext"] := 1
        if (g_Gesture["showOSD"] || g_Gesture["tryMode"]) {
            try ToolTip(T("gesture.next_ignored"))
            SetTimer(GestureEngine.fnHideTip, -900)
        }
    }

    static NoOp() {
        return
    }

    static ArmRecord(cb := "") {
        global g_Gesture
        g_Gesture["recording"] := 1
        g_Gesture["recordCb"] := cb
        g_Gesture["recorded"] := ""
    }

    static IsRecording() {
        global g_Gesture
        return g_Gesture["recording"]
    }

    static ArmTplRecord(cb := "") {
        global g_Gesture
        g_Gesture["tplRecording"] := 1
        g_Gesture["tplRecordCb"] := cb
    }

    static CancelTplRecord() {
        global g_Gesture
        g_Gesture["tplRecording"] := 0
        g_Gesture["tplRecordCb"] := ""
    }

    static IsTplRecording() {
        global g_Gesture
        return g_Gesture["tplRecording"]
    }

    static ListAll() {
        global g_GestureMap, g_GestureApps
        out := []
        try {
            for _k, _v in g_GestureMap
                out.Push(["全局", _k, _v])
            for i, app in g_GestureApps {
                for _k, _v in app.map
                    out.Push([app.name, _k, _v])
            }
        }
        return out
    }

    static ListAppNames() {
        global g_GestureApps
        out := []
        try {
            for i, app in g_GestureApps
                out.Push(app.name)
        }
        return out
    }

    static GetApp(name) {
        global g_GestureApps
        try {
            for i, app in g_GestureApps {
                if (app.name = name)
                    return app
            }
        }
        return ""
    }

    static ListBlacklist() {
        global g_GestureBlacklist
        out := []
        try {
            for i, pat in g_GestureBlacklist
                out.Push(pat)
        }
        return out
    }

    static LayerHas(layer, gkey) {
        global g_GestureMap
        if (layer = "" || layer = "全局") {
            try return g_GestureMap.Has(gkey)
            return false
        }
        app := GestureEngine.GetApp(layer)
        if (!IsObject(app))
            return false
        try return app.map.Has(gkey)
        return false
    }

    static SetHooks(before := "", after := "") {
        global g_GestureHookBefore, g_GestureHookAfter
        g_GestureHookBefore := before
        g_GestureHookAfter := after
    }
}
