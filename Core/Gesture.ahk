#Requires AutoHotkey v2.0
#Warn All, Off

; === Gesture - 鼠标手势引擎 (StrokePlus 重构 P2: 分层+录制) ===
; 按住触发键拖拽画手势, 松开触发动作; 短点(=无位移)则透传为普通点击.
; 方向量化: 8 向 (R/L/U/D + UR/UL/DR/DL), 手势串形如 "R", "D_R", "U_D".
; 动作语法与 VIMD_CMD 完全一致: run|/key|/dir|/tccmd|/wshkey|/function|/<Action名>.
;
; 分层 (优先级从高到低):
;   1) [GestureBlacklist] 命中 -> 全旁路, 右键行为完全不变
;   2) [GestureApp:应用名] (set_file/set_class 匹配, ini 顺序首个命中) -> 专属手势
;   3) [Gestures] 全局手势 (应用层未命中时回退)
; 本文件只依赖: g_Conf(EasyIni), g_WindowName, BindKey(), VIMD_CMD(), OnError 网.
; 加载期不读配置不绑热键, 一律经 GestureInit() 在主程序收尾阶段调用.

global g_Gesture := Map(
    "enable", 0,
    "trigger", "RButton",
    "boundTrigger", "",
    "threshold", 20,
    "segment", 30,
    "poll", 15,
    "showOSD", 1,
    "noMatch", "swallow",
    "ignoreKey", "",
    "onlyDefined", 0,
    "trail", 1,
    "trailColor", "45ABFF",
    "trailWidth", 5,
    "ignoreNext", 0,
    "down", 0,
    "gesturing", 0,
    "cancelled", 0,
    "startX", 0, "startY", 0,
    "downTick", 0,
    "points", [],
    "dirs", [],
    "gesture", "",
    "recording", 0,
    "recordCb", "",
    "recorded", "",
    "tplRecording", 0,
    "tplRecordCb", "",
    "tryMode", 0,
    "comboUntil", 0,
    "trailX", -1, "trailY", -1
)
global g_GestureMap := Map()       ; 全局层: 手势串 -> 动作串
global g_GestureApps := []         ; 应用层(ini 顺序): [{name, exe, cls, map}]
global g_GestureBlacklist := []    ; 黑名单模式串
global g_GestureAppPrefix := "GestureApp:"
global g_GestureDisabled := Map()  ; 禁用集: id -> 1
; id 格式: 链 "层:键" / 模板 "模板:名" / 黑名单 "黑名单:模式" / 应用层 "应用层:名"
global g_GestureHookBefore := ""
global g_GestureHookAfter := ""

; ---- 初始化: 读 [Gesture]/[Gestures]/各应用层/黑名单, 绑定触发键 ----
GestureInit() {
    global g_Gesture
    Gesture_LoadConfig()
    Gesture_ReloadLayers()
    try Tpl_LoadAll()
    catch {
    }
    if (!g_Gesture["enable"])
        return false
    Gesture_BindTrigger()
    return true
}

; ---- 重读 [Gesture] 配置节 (管理器设置页保存后调用, 即时生效) ----
Gesture_LoadConfig() {
    global g_Gesture, g_Conf
    try {
        if IsObject(g_Conf) && g_Conf.HasSection("Gesture") {
            sec := g_Conf["Gesture"]
            if sec.Has("Enable")
                g_Gesture["enable"] := (sec["Enable"] = "1") ? 1 : 0
            if sec.Has("Threshold") && (sec["Threshold"] + 0 > 0)
                g_Gesture["threshold"] := sec["Threshold"] + 0
            if sec.Has("Segment") && (sec["Segment"] + 0 > 0)
                g_Gesture["segment"] := sec["Segment"] + 0
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

; ---- (重)载所有层: 全局 [Gestures] + [GestureApp:*] + [GestureBlacklist] + [GestureDisabled] ----
Gesture_ReloadLayers() {
    global g_GestureMap, g_GestureApps, g_GestureBlacklist, g_GestureAppPrefix, g_Conf, g_GestureDisabled
    g_GestureMap := Map()
    g_GestureApps := []
    g_GestureBlacklist := []
    g_GestureDisabled := Map()
    if !IsObject(g_Conf)
        return
    try {
        if (g_Conf.HasSection("Gestures")) {
            for _k, _v in g_Conf["Gestures"] {
                _k := Trim(_k)
                _v := Trim(_v)
                if (_k = "" || _v = "" || SubStr(_k, 1, 1) = ";")
                    continue
                g_GestureMap[Gesture_NormalizeFull(_k)] := _v
            }
        }
    }
    try {
        if (g_Conf.HasSection("GestureBlacklist")) {
            for _k, _v in g_Conf["GestureBlacklist"] {
                pat := Trim(_k)
                if (pat = "" || SubStr(pat, 1, 1) = ";")
                    continue
                g_GestureBlacklist.Push(pat)
            }
        }
    }
    try {
        if (g_Conf.HasSection("GestureDisabled")) {
            for _k, _v in g_Conf["GestureDisabled"] {
                id := Trim(_k)
                if (id = "" || SubStr(id, 1, 1) = ";")
                    continue
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
            noglobal := (g_Conf.Get(sectionName, "noglobal", "0") = "1") ? 1 : 0
            mp := Map()
            for _k, _v in section {
                _k := Trim(_k)
                _v := Trim(_v)
                if (_k = "" || _v = "" || SubStr(_k, 1, 1) = ";")
                    continue
                if (SubStr(_k, 1, 4) = "set_" || SubStr(_k, 1, 7) = "enable_")
                    continue
                if (StrLower(_k) = "noglobal")
                    continue
                mp[Gesture_NormalizeFull(_k)] := _v
            }
            g_GestureApps.Push({name: appName, exe: exe, cls: cls, title: title, titleRx: titleRx, noglobal: noglobal, map: mp})
        }
    }
}

; ---- 绑定触发键 (可重复调用, 触发键变更时自动解绑旧键) ----
Gesture_BindTrigger() {
    global g_Gesture
    trig := g_Gesture["trigger"]
    old := g_Gesture["boundTrigger"]
    if (old != "" && old != trig) {
        try Hotkey("$" . old, "Off")
        catch {
        }
        try Hotkey("$" . old . " Up", "Off")
        catch {
        }
    }
    try {
        BindKey(trig, Gesture_Down)
        BindKey(trig . " Up", Gesture_Up)
        g_Gesture["boundTrigger"] := trig
    } catch {
        return false
    }
    ; 滚轮手势: 按住触发键时滚轮改道, 松开时永远透传(见 Gesture_Wheel)
    try BindKey("WheelUp", Gesture_WheelUp)
    catch {
    }
    try BindKey("WheelDown", Gesture_WheelDown)
    catch {
    }
    try BindKey("WheelLeft", Gesture_WheelLeft)
    catch {
    }
    try BindKey("WheelRight", Gesture_WheelRight)
    catch {
    }
    return true
}

; ---- 手势串归一化: 去空格, 大写, "_" 连接 ----
Gesture_Normalize(s) {
    s := Trim(s)
    s := StrReplace(s, " ", "")
    s := StrReplace(s, ",", "_")
    s := StrReplace(s, "-", "_")
    s := StrReplace(s, "__", "_")
    return StrUpper(s)
}

; ---- 全归一化 (含修饰键前缀): "ctrl + d_r" -> "CTRL+D_R", 顺序固定 CTRL+ALT+SHIFT ----
Gesture_NormalizeFull(s) {
    s := StrUpper(Trim(s))
    s := StrReplace(s, " ", "")
    if !InStr(s, "+")
        return Gesture_Normalize(s)
    parts := StrSplit(s, "+")
    if (parts.Length < 2)
        return Gesture_Normalize(s)
    hasC := false
    hasA := false
    hasS := false
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
    return prefix . Gesture_Normalize(parts[parts.Length])
}

; ---- 当前按住的修饰键 (与归一化同顺序) ----
Gesture_ActiveMods() {
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

; ---- 取当前活动窗口三要素 (exe/class/title, 失败给空串) ----
Gesture_GetActiveIds(&exe, &cls, &title) {
    exe := ""
    cls := ""
    title := ""
    try exe := WinGetProcessName("A")
    catch {
    }
    try cls := WinGetClass("A")
    catch {
    }
    try title := WinGetTitle("A")
    catch {
    }
}

; ---- 黑名单命中? (exe/class 精确匹配不分大小写, 或 title 包含) ----
Gesture_IsBlacklisted(exe, cls, title) {
    global g_GestureBlacklist
    for i, pat in g_GestureBlacklist {
        if (pat = "")
            continue
        if (Gesture_BlOff(pat))
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

; ---- 应用字段安全读取 (手造不完整对象也不抛异常) ----
Gesture_AppField(app, field) {
    try {
        return app.%field%
    } catch {
        return ""
    }
}

; ---- 多值精确匹配 (ini 用 " | " 分隔多个 exe/class), 不分大小写 ----
Gesture_MatchList(value, patterns) {
    value := Trim(value)
    if (value = "")
        return false
    for i, pat in StrSplit(patterns, "|") {
        if (Trim(pat) != "" && StrLower(value) = StrLower(Trim(pat)))
            return true
    }
    return false
}

; ---- 应用层匹配: 非空条件全满足才命中 (AND), 全空层永不命中 ----
Gesture_MatchApp(exe, cls, title := "") {
    global g_GestureApps
    for i, app in g_GestureApps {
        ex := Gesture_AppField(app, "exe")
        cl := Gesture_AppField(app, "cls")
        ti := Gesture_AppField(app, "title")
        rx := Gesture_AppField(app, "titleRx")
        nm := Gesture_AppField(app, "name")
        if (nm != "" && Gesture_LayerOff(nm))
            continue
        if (ex = "" && cl = "" && ti = "" && rx = "")
            continue
        if (ex != "" && !Gesture_MatchList(exe, ex))
            continue
        if (cl != "" && !Gesture_MatchList(cls, cl))
            continue
        if (ti != "" && (title = "" || !InStr(StrLower(title), StrLower(ti))))
            continue
        if (rx != "" && title = "")
            continue
        if (rx != "") {
            found := false
            try found := (RegExMatch(title, rx) > 0)
            catch {
                found := false
            }
            if (!found)
                continue
        }
        return app
    }
    return ""
}

; ---- 分层解析 (纯逻辑, 可单测): 返回 [动作, 层名], 未命中返回 ["", ""] ----
; 顺序: 应用层[修饰] -> 应用层[裸] -> 全局[修饰] -> 全局[裸]; noglobal 切断全局回退
Gesture_ResolveFor(gesture, exe, cls, mods := "", title := "") {
    global g_GestureMap
    g := Gesture_Normalize(gesture)
    if (g = "")
        return ["", ""]
    app := Gesture_MatchApp(exe, cls, title)
    if (IsObject(app)) {
        try {
            if (mods != "" && app.map.Has(mods . g) && !Gesture_ChainOff(app.name, mods . g))
                return [app.map[mods . g], app.name]
            if (app.map.Has(g) && !Gesture_ChainOff(app.name, g))
                return [app.map[g], app.name]
        }
        if (Gesture_AppField(app, "noglobal"))
            return ["", ""]
    }
    try {
        if (mods != "" && g_GestureMap.Has(mods . g) && !Gesture_ChainOff("全局", mods . g))
            return [g_GestureMap[mods . g], "全局"]
        if (g_GestureMap.Has(g) && !Gesture_ChainOff("全局", g))
            return [g_GestureMap[g], "全局"]
    }
    return ["", ""]
}

; ---- 是否旁路: 自家窗口 / 黑名单 / IgnoreKey 按住 / 单次忽略 / 仅限定应用 ----
Gesture_IsBypass(consumeNext := true) {
    global g_WindowName, g_Gesture
    try {
        if (g_WindowName != "" && WinActive(g_WindowName))
            return true
    }
    ; 单次忽略: 消费一次, 本次透传
    if (g_Gesture["ignoreNext"]) {
        if (consumeNext)
            g_Gesture["ignoreNext"] := 0
        return true
    }
    ; IgnoreKey 按住则整套手势暂停
    try {
        if (g_Gesture["ignoreKey"] != "" && GetKeyState(g_Gesture["ignoreKey"], "P"))
            return true
    }
    Gesture_GetActiveIds(&exe, &cls, &title)
    if (Gesture_IsBlacklisted(exe, cls, title))
        return true
    if (g_Gesture["onlyDefined"]) {
        app := Gesture_MatchApp(exe, cls, title)
        if (!IsObject(app))
            return true
    }
    return false
}

; ---- 笔画统一解析: 链优先, 模板次之. 返回 [动作, 说明] ----
Gesture_ResolveStroke(gestureStr, pts, exe, cls, title, mods := "") {
    global g_Gesture, g_TplThreshold
    if (gestureStr != "") {
        res := Gesture_ResolveFor(gestureStr, exe, cls, mods, title)
        if (res[1] != "")
            return [res[1], res[2]]
    }
    if (!IsObject(pts) || pts.Length < 3)
        return ["", ""]
    minSize := 20
    try {
        if (g_Gesture["threshold"] + 0 > 0)
            minSize := g_Gesture["threshold"] + 0
    }
    th := 75
    try {
        if (g_TplThreshold + 0 > 0)
            th := g_TplThreshold + 0
    }
    m := Tpl_Match(pts, minSize)
    if (m[1] = "" || m[2] < th)
        return ["", ""]
    app := Gesture_MatchApp(exe, cls, title)
    if (IsObject(app)) {
        try {
            tkey := "TPL:" . m[1]
            if (app.map.Has(tkey))
                return [app.map[tkey], app.name . "/模板"]
        }
    }
    t := Tpl_Get(m[1])
    if (IsObject(t))
        return [t.action, "模板"]
    return ["", ""]
}

; ---- 试笔模式: 只识别不执行 ----
Gesture_SetTryMode(on) {
    global g_Gesture
    g_Gesture["tryMode"] := on ? 1 : 0
    try {
        if (g_SkinConf["ShowTrayIcon"] = "1")
            A_TrayMenu.ToggleCheck(T("gesture.tray_try"))
    } catch {
    }
}

Gesture_IsTryMode() {
    global g_Gesture
    return g_Gesture["tryMode"]
}

ToggleTryMode(*) {
    Gesture_SetTryMode(!Gesture_IsTryMode())
    try ToolTip(Gesture_IsTryMode() ? T("gesture.try_on") : T("gesture.try_off"))
    catch {
    }
    SetTimer(Gesture_HideTip, -900)
}

; ---- 供动作调用: 忽略下一笔手势 (原版 acDisableNext 对等) ----
Gesture_IgnoreNext() {
    global g_Gesture
    g_Gesture["ignoreNext"] := 1
    try ToolTip(T("gesture.next_ignored"))
    catch {
    }
    SetTimer(Gesture_HideTip, -900)
}

; ---- 空动作 (桌面忽略手势等场景, 原版空 Lua 对等) ----
Gesture_NoOp() {
    return
}

; ---- 触发键按下: 记录起点, 启动采样 ----
Gesture_Down(*) {
    global g_Gesture
    if (!g_Gesture["enable"])
        return
    if (Gesture_IsBypass())
        return
    if (g_Gesture["down"])
        return
    MouseGetPos(&sx, &sy)
    g_Gesture["down"] := 1
    g_Gesture["gesturing"] := 0
    g_Gesture["cancelled"] := 0
    g_Gesture["startX"] := sx
    g_Gesture["startY"] := sy
    g_Gesture["downTick"] := A_TickCount
    g_Gesture["points"] := [{x: sx, y: sy}]
    g_Gesture["dirs"] := []
    g_Gesture["gesture"] := ""
    SetTimer(Gesture_Poll, g_Gesture["poll"])
}

; ---- 采样轮询: 判断进入手势 / 追加方向 / Esc 取消 ----
Gesture_Poll() {
    global g_Gesture
    if (!g_Gesture["down"])
        return
    try {
        if GetKeyState("Esc", "P") {
            g_Gesture["cancelled"] := 1
            g_Gesture["gesturing"] := 0
            g_Gesture["dirs"] := []
            g_Gesture["gesture"] := ""
            try GestureTrail_Hide()
            catch {
            }
            if (g_Gesture["showOSD"])
                ToolTip(T("gesture.cancelled"))
            return
        }
    }
    MouseGetPos(&mx, &my)
    pts := g_Gesture["points"]
    last := pts[pts.Length]
    dx0 := mx - last.x
    dy0 := my - last.y
    if (dx0 * dx0 + dy0 * dy0 < 16)
        return
    pts.Push({x: mx, y: my})
    sx := g_Gesture["startX"]
    sy := g_Gesture["startY"]
    ddx := mx - sx
    ddy := my - sy
    if (!g_Gesture["gesturing"]) {
        if (ddx * ddx + ddy * ddy < g_Gesture["threshold"] * g_Gesture["threshold"])
            return
        g_Gesture["gesturing"] := 1
        g_Gesture["points"] := [{x: sx, y: sy}, {x: mx, y: my}]
        Gesture_Recognize()
        try {
            GestureTrail_Show()
            GestureTrail_Line(sx, sy, mx, my)
        } catch {
        }
        g_Gesture["trailX"] := mx
        g_Gesture["trailY"] := my
        if (g_Gesture["showOSD"])
            Gesture_OSD()
        return
    }
    try GestureTrail_Line(g_Gesture["trailX"], g_Gesture["trailY"], mx, my)
    catch {
    }
    g_Gesture["trailX"] := mx
    g_Gesture["trailY"] := my
    Gesture_Recognize()
    if (g_Gesture["showOSD"])
        Gesture_OSD()
}

; ---- 全量识别: 锚点步进, 步长 segment, 方向去重 ----
Gesture_Recognize() {
    global g_Gesture
    pts := g_Gesture["points"]
    seg := g_Gesture["segment"]
    if (pts.Length < 2)
        return
    dirs := []
    ax := pts[1].x
    ay := pts[1].y
    for i in Gesture_Range(2, pts.Length) {
        px := pts[i].x
        py := pts[i].y
        dx := px - ax
        dy := py - ay
        if (dx * dx + dy * dy < seg * seg)
            continue
        d := Gesture_DirOf(dx, dy)
        if (dirs.Length = 0 || dirs[dirs.Length] != d)
            dirs.Push(d)
        ax := px
        ay := py
    }
    g_Gesture["dirs"] := dirs
    s := ""
    for i, d in dirs
        s .= (i > 1 ? "_" : "") . d
    g_Gesture["gesture"] := s
}

Gesture_Range(a, b) {
    out := []
    i := a
    while (i <= b) {
        out.Push(i)
        i++
    }
    return out
}

; ---- 向量 -> 8 方向 (屏幕坐标 y 向下, atan2(-dy,dx) 转数学角) ----
Gesture_DirOf(dx, dy) {
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

; ---- OSD: 手势串 + 命中动作名(含层) ----
Gesture_OSD() {
    global g_Gesture
    g := g_Gesture["gesture"]
    txt := T("gesture.osd_gesture", (g = "" ? "..." : g))
    if (g_Gesture["recording"])
        txt := T("gesture.osd_recording", (g = "" ? "..." : g))
    else if (g != "") {
        Gesture_GetActiveIds(&exe, &cls, &title)
        mods := Gesture_ActiveMods()
        res := Gesture_ResolveFor(g, exe, cls, mods, title)
        if (res[1] != "")
            txt .= "`n" . T("gesture.osd_action", res[1], res[2])
    }
    ToolTip(txt)
}

; ---- 触发键松开: 录制截获 / 分层执行 / 短点透传 ----
Gesture_Up(*) {
    global g_Gesture
    try SetTimer(Gesture_Poll, 0)
    catch {
    }
    if (!g_Gesture["down"])
        return
    g_Gesture["down"] := 0
    wasGesturing := g_Gesture["gesturing"]
    wasCancelled := g_Gesture["cancelled"]
    gesture := g_Gesture["gesture"]
    g_Gesture["gesturing"] := 0
    g_Gesture["cancelled"] := 0
    try ToolTip()
    catch {
    }
    try GestureTrail_Hide()
    catch {
    }
    if (wasGesturing && !wasCancelled && gesture != "") {
        ; 录制模式: 截获, 不执行
        if (g_Gesture["recording"]) {
            g_Gesture["recorded"] := gesture
            cb := g_Gesture["recordCb"]
            Gesture_CancelRecord()
            try ToolTip(T("gesture.recorded_is", gesture))
            catch {
            }
            SetTimer(Gesture_HideTip, -1200)
            if (IsObject(cb)) {
                try cb(gesture)
            }
            return
        }
        ; 模板录制: 归一化为点串交回调, 不执行
        if (g_Gesture["tplRecording"]) {
            tcb := g_Gesture["tplRecordCb"]
            g_Gesture["tplRecording"] := 0
            g_Gesture["tplRecordCb"] := ""
            enc := ""
            try {
                enc := Tpl_Encode(Tpl_Prepare(g_Gesture["points"]))
                ToolTip(T("gesture.tpl_recorded2"))
            } catch {
            }
            SetTimer(Gesture_HideTip, -1200)
            if (IsObject(tcb) && enc != "") {
                try tcb(enc)
            }
            return
        }
        Gesture_GetActiveIds(&exe, &cls, &title)
        mods := Gesture_ActiveMods()
        res := Gesture_ResolveStroke(gesture, g_Gesture["points"], exe, cls, title, mods)
        if (res[1] != "") {
            ; 试笔模式: 只报不执行
            if (g_Gesture["tryMode"]) {
                disp := mods . gesture
                try ToolTip(T("gesture.try_hit", disp, res[1], res[2]))
                catch {
                }
                SetTimer(Gesture_HideTip, -2000)
                return
            }
            Gesture_DoAction(res[1])
            return
        }
        if (g_Gesture["tryMode"]) {
            try ToolTip(T("gesture.try_miss", gesture))
            catch {
            }
            SetTimer(Gesture_HideTip, -2000)
            return
        }
        ; 未命中策略: swallow=吞+提示 / sound=提示音 / passthrough=透传点击
        if (g_Gesture["noMatch"] = "passthrough") {
            try {
                Click(Gesture_ClickName(g_Gesture["trigger"]))
            } catch {
                try Send("{" . g_Gesture["trigger"] . "}")
            }
            return
        }
        if (g_Gesture["noMatch"] = "sound") {
            try SoundBeep(750, 120)
            catch {
            }
        }
        try ToolTip(T("gesture.unknown", gesture))
        catch {
        }
        SetTimer(Gesture_HideTip, -900)
        return
    }
    if (wasCancelled) {
        return
    }
    ; 短点透传为普通点击
    try {
        Click(Gesture_ClickName(g_Gesture["trigger"]))
    } catch {
        try Send("{" . g_Gesture["trigger"] . "}")
    }
}

Gesture_HideTip() {
    try ToolTip()
    catch {
    }
    try SetTimer(Gesture_HideTip, 0)
    catch {
    }
}

; ==================== 滚轮手势 (按住触发键时滚轮改道) ====================
Gesture_WheelUp(*) {
    Gesture_Wheel("WheelUp")
}

Gesture_WheelDown(*) {
    Gesture_Wheel("WheelDown")
}

Gesture_WheelLeft(*) {
    Gesture_Wheel("WheelLeft")
}

Gesture_WheelRight(*) {
    Gesture_Wheel("WheelRight")
}

Gesture_Wheel(which) {
    global g_Gesture
    if (!g_Gesture["enable"]) {
        try Send("{" . which . "}")
        catch {
        }
        return
    }
    held := false
    try held := GetKeyState(g_Gesture["trigger"], "P")
    catch {
    }
    ; 组合技窗口内滚轮优先 (不要求按住触发键, 更宽松)
    if (Gesture_ComboActive()) {
        if (which = "WheelUp" || which = "WheelDown") {
            if (g_Gesture["tryMode"]) {
                try ToolTip(T("gesture.try_zoom", which))
                catch {
                }
                SetTimer(Gesture_HideTip, -1200)
            } else {
                try Send(which = "WheelUp" ? "^{WheelUp}" : "^{WheelDown}")
                catch {
                }
            }
            return
        }
        try Send("{" . which . "}")
        catch {
        }
        return
    }
    ; 触发键未按住 / 旁路窗口 -> 透传滚轮(不消费单次忽略)
    if (!held || Gesture_IsBypass(false)) {
        try Send("{" . which . "}")
        catch {
        }
        return
    }
    Gesture_GetActiveIds(&exe, &cls, &title)
    mods := Gesture_ActiveMods()
    res := Gesture_ResolveFor(which, exe, cls, mods, title)
    if (res[1] != "") {
        if (g_Gesture["tryMode"]) {
            try ToolTip(T("gesture.try_wheel", (mods . which), res[1], res[2]))
            catch {
            }
            SetTimer(Gesture_HideTip, -2000)
            return
        }
        Gesture_DoAction(res[1])
        if (g_Gesture["showOSD"]) {
            try ToolTip(T("gesture.wheel", (mods . which), res[1], res[2]))
            catch {
            }
            SetTimer(Gesture_HideTip, -900)
        }
        return
    }
    try Send("{" . which . "}")
    catch {
    }
}

; ---- 触发键 -> Click 名称 ----
Gesture_ClickName(trigger) {
    if (trigger = "MButton")
        return "Middle"
    if (trigger = "XButton1")
        return "X1"
    if (trigger = "XButton2")
        return "X2"
    return "Right"
}

; ---- 动作执行: 复用 VIMD_CMD, 未知裸名走动态调用(缺失由 OnError 网接住) ----
Gesture_DoAction(action) {
    global g_Gesture, g_GestureHookBefore, g_GestureHookAfter
    action := Trim(action)
    if (action = "")
        return
    ; 前钩子: 返回真则拦截本次执行 (custom.ahk 里定义并经 Gesture_SetHooks 注册)
    if (IsObject(g_GestureHookBefore)) {
        try {
            if (g_GestureHookBefore.Call(action))
                return
        } catch {
        }
    }
    ; 组合技: combo|xxx 武装后续滚轮 (如模板 Z 缩放), 动作本身不等执行
    if (SubStr(action, 1, 6) = "combo|") {
        Gesture_ComboArm(action)
        return
    }
    head4 := SubStr(action, 1, 4)
    head6 := SubStr(action, 1, 6)
    head7 := SubStr(action, 1, 7)
    head9 := SubStr(action, 1, 9)
    if (SubStr(action, 1, 1) = "<" || head4 = "run|" || head4 = "key|" || head4 = "dir|"
        || head6 = "tccmd|" || head7 = "wshkey|" || head9 = "function|") {
        VIMD_CMD(action)
    } else {
        fn := action
        %fn%()
    }
    ; 后钩子: 记录/联动用, 异常不影响主流程
    if (IsObject(g_GestureHookAfter)) {
        try g_GestureHookAfter.Call(action)
        catch {
        }
    }
}

; ---- 注册执行前后钩子 (custom.ahk 示例: Gesture_SetHooks((a)=>false, (a)=>ToolTip(a))) ----
Gesture_SetHooks(before := "", after := "") {
    global g_GestureHookBefore, g_GestureHookAfter
    g_GestureHookBefore := before
    g_GestureHookAfter := after
}

; ---- 组合技: 武装后续滚轮 (原版 Z+滚轮缩放对等, combo|zoom) ----
Gesture_ComboArm(action) {
    global g_Gesture
    kind := StrLower(Trim(SubStr(action, 7)))
    if (kind = "zoom") {
        g_Gesture["comboUntil"] := A_TickCount + 1500
        if (g_Gesture["tryMode"]) {
            try ToolTip(T("gesture.arm_zoom"))
            catch {
            }
        } else {
            try ToolTip(T("gesture.zoom_ready"))
            catch {
            }
        }
        SetTimer(Gesture_HideTip, -1500)
    }
}

Gesture_ComboActive() {
    global g_Gesture
    try {
        return g_Gesture["comboUntil"] > A_TickCount
    } catch {
        return false
    }
}

; ==================== 禁用集 ====================
Gesture_DisabledHas(id) {
    global g_GestureDisabled
    try {
        return g_GestureDisabled.Has(id)
    } catch {
        return false
    }
}

Gesture_ChainOff(layer, key) {
    return Gesture_DisabledHas(layer . ":" . key)
}

Gesture_TplOff(name) {
    return Gesture_DisabledHas("模板:" . name)
}

Gesture_BlOff(pat) {
    return Gesture_DisabledHas("黑名单:" . pat)
}

Gesture_LayerOff(name) {
    return Gesture_DisabledHas("应用层:" . name)
}

; ==================== 录制 ====================
Gesture_ArmRecord(cb := "") {
    global g_Gesture
    g_Gesture["recording"] := 1
    g_Gesture["recordCb"] := cb
    g_Gesture["recorded"] := ""
}

Gesture_CancelRecord() {
    global g_Gesture
    g_Gesture["recording"] := 0
    g_Gesture["recordCb"] := ""
}

Gesture_IsRecording() {
    global g_Gesture
    return g_Gesture["recording"]
}

; ---- 模板录制: 下一笔只归一化为点串, 不执行 ----
Gesture_ArmTplRecord(cb := "") {
    global g_Gesture
    g_Gesture["tplRecording"] := 1
    g_Gesture["tplRecordCb"] := cb
}

Gesture_CancelTplRecord() {
    global g_Gesture
    g_Gesture["tplRecording"] := 0
    g_Gesture["tplRecordCb"] := ""
}

Gesture_IsTplRecording() {
    global g_Gesture
    return g_Gesture["tplRecording"]
}

; ==================== 查询 (供管理界面) ====================
; 全量行: [[层, 手势, 动作], ...], 层 "全局" 在前, 后跟各应用层
Gesture_ListAll() {
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

Gesture_ListAppNames() {
    global g_GestureApps
    out := []
    try {
        for i, app in g_GestureApps
            out.Push(app.name)
    }
    return out
}

Gesture_GetApp(name) {
    global g_GestureApps
    try {
        for i, app in g_GestureApps {
            if (app.name = name)
                return app
        }
    }
    return ""
}

Gesture_ListBlacklist() {
    global g_GestureBlacklist
    out := []
    try {
        for i, pat in g_GestureBlacklist
            out.Push(pat)
    }
    return out
}

; ---- 某层是否已有该手势键 (保存覆盖确认用, gkey 须已归一化) ----
Gesture_LayerHas(layer, gkey) {
    global g_GestureMap
    if (layer = "" || layer = "全局") {
        try {
            return g_GestureMap.Has(gkey)
        } catch {
            return false
        }
    }
    app := Gesture_GetApp(layer)
    if (!IsObject(app))
        return false
    try {
        return app.map.Has(gkey)
    } catch {
        return false
    }
}
