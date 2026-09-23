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
    "threshold", 6,
    "segment", 6,
    "poll", 10,
    "cancelDelay", 1500,
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
    "lastMoveTick", 0,
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
    "comboKind", "",
    "trailX", -1, "trailY", -1,
    "downMods", "",
    "startHwnd", 0,
    "startContext", "",
    "forwardDown", 0,
    "leftCombo", 0
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
            ownerCls := g_Conf.Get(sectionName, "set_owner_class", "")
            ctrlCls := g_Conf.Get(sectionName, "set_ctrl_class", "")
            ctrlTitle := g_Conf.Get(sectionName, "set_ctrl_title", "")
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
            g_GestureApps.Push({name: appName, exe: exe, cls: cls, title: title, titleRx: titleRx,
                ownerCls: ownerCls, ctrlCls: ctrlCls, ctrlTitle: ctrlTitle, noglobal: noglobal, map: mp})
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
; 命名空间 (StrokesPlus 对齐): 方向链是 DIR 空间 (U=向上直线),
; 字母模板是 TPL 空间 (TPL:U=字母 U). "TPL:"/"DIR:" 前缀原样保留,
; 链查不到时才走模板, 两者不再互遮 (见 Gesture_ResolveStroke).
Gesture_Normalize(s) {
    s := Trim(s)
    prefix := ""
    up := StrUpper(s)
    if (SubStr(up, 1, 4) = "TPL:" || SubStr(up, 1, 4) = "DIR:") {
        prefix := SubStr(up, 1, 4)
        s := Trim(SubStr(s, 5))
    }
    s := StrReplace(s, " ", "")
    s := StrReplace(s, ",", "_")
    s := StrReplace(s, "-", "_")
    s := StrReplace(s, "__", "_")
    return prefix . StrUpper(s)
}

; ---- 全归一化 (含修饰键前缀): "ctrl + d_r" -> "CTRL+D_R", 顺序固定 CTRL+ALT+SHIFT ----
; "TPL:U"/"DIR:U" 命名空间前缀优先剥离, 修饰键只认 CTRL/ALT/SHIFT
Gesture_NormalizeFull(s) {
    s := StrUpper(Trim(s))
    s := StrReplace(s, " ", "")
    ns := ""
    if (SubStr(s, 1, 4) = "TPL:" || SubStr(s, 1, 4) = "DIR:") {
        ns := SubStr(s, 1, 4)
        s := SubStr(s, 5)
    }
    if !InStr(s, "+")
        return ns . Gesture_Normalize(s)
    parts := StrSplit(s, "+")
    if (parts.Length < 2)
        return ns . Gesture_Normalize(s)
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
    return prefix . ns . Gesture_Normalize(parts[parts.Length])
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

; ---- 取当前活动窗口要素 (exe/class/title + owner/ctrl, 失败给空串) ----
Gesture_GetActiveIds(&exe, &cls, &title, &ownerCls := "", &ctrlCls := "", &ctrlTitle := "") {
    exe := ""
    cls := ""
    title := ""
    ownerCls := ""
    ctrlCls := ""
    ctrlTitle := ""
    try exe := WinGetProcessName("A")
    catch {
    }
    try cls := WinGetClass("A")
    catch {
    }
    try title := WinGetTitle("A")
    catch {
    }
    ; 控件级 (Desktop 层 FolderView 等): 焦点控件类名 + 文本, 失败留空不拦主流程
    try {
        focused := ControlGetFocus("A")
        if (focused != "") {
            try ctrlCls := ControlGetClass(focused, "A")
            catch {
            }
            try ctrlTitle := ControlGetText(focused, "A")
            catch {
            }
        }
    }
    try {
        hwnd := WinExist("A")
        owner := DllCall("GetWindow", "Ptr", hwnd, "UInt", 4, "Ptr")
        if owner
            ownerCls := WinGetClass("ahk_id " . owner)
    }
}

Gesture_WindowClass(hwnd) {
    if (!hwnd)
        return ""
    try {
        return WinGetClass("ahk_id " . hwnd)
    } catch {
    }
    return ""
}

Gesture_WindowText(hwnd) {
    if (!hwnd)
        return ""
    try {
        textBuf := Buffer(2048, 0)
        DllCall("GetWindowTextW", "Ptr", hwnd, "Ptr", textBuf, "Int", 1024, "Int")
        return StrGet(textBuf, "UTF-16")
    }
    return ""
}

Gesture_AddContextClass(&classes, &seen, hwnd) {
    cls := Gesture_WindowClass(hwnd)
    key := StrLower(cls)
    if (cls != "" && !seen.Has(key)) {
        seen[key] := 1
        classes.Push(cls)
    }
}

; Capture the hit control, its top-level window, and host/owner classes once at gesture start.
Gesture_CaptureWindowContext(x, y) {
    hit := Gesture_HwndFromPoint(x, y)
    root := 0
    if (hit) {
        try root := DllCall("GetAncestor", "Ptr", hit, "UInt", 2, "Ptr")
    }
    if (!root)
        root := hit
    ctx := {hitHwnd: hit, rootHwnd: root, exe: "", cls: "", title: "",
        ownerCls: "", ctrlCls: "", ctrlTitle: ""}
    if (!hit)
        return ctx

    try ctx.exe := WinGetProcessName("ahk_id " . root)
    ctx.cls := Gesture_WindowClass(root)
    ctx.title := Gesture_WindowText(root)
    ctx.ctrlCls := Gesture_WindowClass(hit)
    ctx.ctrlTitle := Gesture_WindowText(hit)

    classes := []
    seen := Map()
    parent := hit
    Loop 16 {
        try parent := DllCall("GetParent", "Ptr", parent, "Ptr")
        catch {
            break
        }
        if (!parent)
            break
        Gesture_AddContextClass(&classes, &seen, parent)
    }
    owner := root
    Loop 8 {
        try owner := DllCall("GetWindow", "Ptr", owner, "UInt", 4, "Ptr")
        catch {
            break
        }
        if (!owner)
            break
        Gesture_AddContextClass(&classes, &seen, owner)
    }
    for i, ownerClass in classes
        ctx.ownerCls .= (i > 1 ? "|" : "") . ownerClass
    return ctx
}

Gesture_MatchContextClasses(value, patterns) {
    for i, candidate in StrSplit(value, "|") {
        if (Gesture_MatchList(candidate, patterns))
            return true
    }
    return false
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
; StrokesPlus 对齐: 除 exe/class/title 外, 还支持 owner class / control class / control title
; (ini: set_owner_class / set_ctrl_class / set_ctrl_title, 多值 " | " 精确匹配, title 类为包含匹配)
Gesture_MatchApp(exe, cls, title := "", ownerCls := "", ctrlCls := "", ctrlTitle := "") {
    global g_GestureApps
    for i, app in g_GestureApps {
        ex := Gesture_AppField(app, "exe")
        cl := Gesture_AppField(app, "cls")
        ti := Gesture_AppField(app, "title")
        rx := Gesture_AppField(app, "titleRx")
        ow := Gesture_AppField(app, "ownerCls")
        cc := Gesture_AppField(app, "ctrlCls")
        ct := Gesture_AppField(app, "ctrlTitle")
        nm := Gesture_AppField(app, "name")
        if (nm != "" && Gesture_LayerOff(nm))
            continue
        if (ex = "" && cl = "" && ti = "" && rx = "" && ow = "" && cc = "" && ct = "")
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
        if (ow != "" && !Gesture_MatchContextClasses(ownerCls, ow))
            continue
        if (cc != "" && !Gesture_MatchList(ctrlCls, cc))
            continue
        if (ct != "" && (ctrlTitle = "" || !InStr(StrLower(ctrlTitle), StrLower(ct))))
            continue
        return app
    }
    return ""
}

; ---- 分层解析 (纯逻辑, 可单测): 返回 [动作, 层名], 未命中返回 ["", ""] ----
; 顺序: 应用层[修饰] -> 应用层[裸] -> 全局[修饰] -> 全局[裸]; noglobal 切断全局回退
; Return keys in the unified namespace first, then the explicit legacy
; DIR:/TPL: namespaces. This lets old profiles keep working while new
; profiles bind a template exactly like any other gesture.
Gesture_BindingKeys(kind, name, mods := "") {
    n := Gesture_Normalize(name)
    prefix := (kind = "template") ? "TPL:" : "DIR:"
    out := []
    seen := Map()
    add := (key) => (seen.Has(key) ? 0 : (seen[key] := 1, out.Push(key)))
    ; When both namespaces use the same literal (U is the common case), an
    ; explicit legacy prefix wins. New names still work bare when no legacy
    ; collision exists.
    if (kind = "template") {
        if (mods != "") {
            add(Gesture_NormalizeFull(mods . "+" . prefix . n))
            add(Gesture_NormalizeFull(mods . "+" . n))
        }
        add(prefix . n)
        add(n)
    } else {
        if (mods != "") {
            add(Gesture_NormalizeFull(mods . "+" . n))
            add(Gesture_NormalizeFull(mods . "+" . prefix . n))
        }
        add(n)
        add(prefix . n)
    }
    return out
}

Gesture_LookupBinding(mapObj, kind, name, mods, layer, &usedKey := "") {
    usedKey := ""
    if !IsObject(mapObj)
        return ""
    for _, key in Gesture_BindingKeys(kind, name, mods) {
        try {
            if mapObj.Has(key) && !Gesture_ChainOff(layer, key) {
                usedKey := key
                return mapObj[key]
            }
        }
    }
    return ""
}

Gesture_HasBinding(kind, name, exe, cls, title, mods := "", ownerCls := "", ctrlCls := "", ctrlTitle := "") {
    global g_GestureMap
    app := Gesture_MatchApp(exe, cls, title, ownerCls, ctrlCls, ctrlTitle)
    if (IsObject(app)) {
        if (Gesture_LookupBinding(app.map, kind, name, mods, app.name, &key) != "")
            return {found: 1, canonical: !InStr(key, (kind = "template" ? "TPL:" : "DIR:"))}
        if (Gesture_AppField(app, "noglobal"))
            return {found: 0, blocked: 1, canonical: 0}
    }
    if (Gesture_LookupBinding(g_GestureMap, kind, name, mods, "全局", &key) != "")
        return {found: 1, canonical: !InStr(key, (kind = "template" ? "TPL:" : "DIR:"))}
    return {found: 0, blocked: 0, canonical: 0}
}

Gesture_ResolveFor(gesture, exe, cls, mods := "", title := "", ownerCls := "", ctrlCls := "", ctrlTitle := "") {
    global g_GestureMap
    g := Gesture_Normalize(gesture)
    if (g = "")
        return ["", ""]
    app := Gesture_MatchApp(exe, cls, title, ownerCls, ctrlCls, ctrlTitle)
    if (IsObject(app)) {
        action := Gesture_LookupBinding(app.map, "direction", g, mods, app.name)
        if (action != "")
            return [action, app.name]
        if (Gesture_AppField(app, "noglobal"))
            return ["", ""]
    }
    action := Gesture_LookupBinding(g_GestureMap, "direction", g, mods, "全局")
    if (action != "")
        return [action, "全局"]
    return ["", ""]
}

; ---- 是否旁路: 自家窗口 / 黑名单 / IgnoreKey 按住 / 单次忽略 / 仅限定应用 ----
Gesture_IsBypass(consumeNext := true, ctx := "") {
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
    if IsObject(ctx) {
        exe := ctx.exe
        cls := ctx.cls
        title := ctx.title
        ownerCls := ctx.ownerCls
        ctrlCls := ctx.ctrlCls
        ctrlTitle := ctx.ctrlTitle
    } else {
        Gesture_GetActiveIds(&exe, &cls, &title, &ownerCls, &ctrlCls, &ctrlTitle)
    }
    if (Gesture_IsBlacklisted(exe, cls, title))
        return true
    if (g_Gesture["onlyDefined"]) {
        app := Gesture_MatchApp(exe, cls, title, ownerCls, ctrlCls, ctrlTitle)
        if (!IsObject(app))
            return true
    }
    return false
}

; ---- 笔画统一解析: 链(DIR)优先, 模板(TPL)次之. 返回 [动作, 说明] ----
; 方向链 "U"(向上直线) 与模板 "TPL:U"(字母 U) 分属两个命名空间:
; 直线笔画命中链即返回; 链未命中再做模板匹配, 此时先查 TPL: 覆盖
; (应用层 -> 全局层), 都没有才用模板自带动作. 因此直线 U 不会再遮蔽字母 U.
Gesture_ResolveStroke(gestureStr, pts, exe, cls, title, mods := "", ownerCls := "", ctrlCls := "", ctrlTitle := "") {
    global g_Gesture, g_TplThreshold, g_GestureMap
    forced := ""
    name := gestureStr
    if (gestureStr != "") {
        up := StrUpper(gestureStr)
        if (SubStr(up, 1, 4) = "TPL:") {
            forced := "template"
            name := Trim(SubStr(gestureStr, 5))
        } else if (SubStr(up, 1, 4) = "DIR:") {
            forced := "direction"
            name := Trim(SubStr(gestureStr, 5))
        }
    }

    if (forced = "template")
        return Gesture_ResolveTpl(name, pts, exe, cls, title, mods, ownerCls, ctrlCls, ctrlTitle)
    if (forced = "direction")
        return Gesture_ResolveFor(name, exe, cls, mods, title, ownerCls, ctrlCls, ctrlTitle)

    dirRes := (name != "" ? Gesture_ResolveFor(name, exe, cls, mods, title, ownerCls, ctrlCls, ctrlTitle) : ["", ""])
    tplRes := Gesture_ResolveTpl("", pts, exe, cls, title, mods, ownerCls, ctrlCls, ctrlTitle)
    if (dirRes[1] = "")
        return tplRes
    if (tplRes[1] = "")
        return dirRes

    ; A configured template is a deliberate shape binding. Prefer it for a
    ; chevron when both the quantized chain and the template are bound.
    m := Tpl_Match(pts, 0)
    isChevron := (name = "DR_UR" || name = "DL_UR" || name = "UR_DR" || name = "UL_DL")
    if (isChevron && m[1] != "") {
        tplBinding := Gesture_HasBinding("template", m[1], exe, cls, title, mods, ownerCls, ctrlCls, ctrlTitle)
        if (tplBinding.found)
            return tplRes
    }
    return dirRes
}

Gesture_ResolveTpl(tplOnly, pts, exe, cls, title, mods := "", ownerCls := "", ctrlCls := "", ctrlTitle := "") {
    global g_Gesture, g_TplThreshold, g_GestureMap
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
    m := Tpl_Match(pts, minSize, tplOnly)
    if (m[1] = "" || m[2] < th)
        return ["", ""]
    if (tplOnly != "" && StrUpper(tplOnly) != StrUpper(m[1]))
        return ["", ""]
    app := Gesture_MatchApp(exe, cls, title, ownerCls, ctrlCls, ctrlTitle)
    if (IsObject(app)) {
        action := Gesture_LookupBinding(app.map, "template", m[1], mods, app.name)
        if (action != "")
            return [action, app.name . "/模板"]
        if (Gesture_AppField(app, "noglobal"))
            return ["", ""]
    }
    action := Gesture_LookupBinding(g_GestureMap, "template", m[1], mods, "全局")
    if (action != "")
        return [action, "全局/模板"]
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
; 手势期间不向目标窗口注入鼠标按下; 旁路时才转发 Down/Up, 短点在释放时重放完整点击.
; 修饰键与应用/控件上下文都在按下瞬间快照, 窗口动作目标取命中控件的顶层窗口.
Gesture_Down(*) {
    global g_Gesture
    CoordMode("Mouse", "Screen")
    if (g_Gesture["down"])
        return
    trig := g_Gesture["trigger"]
    MouseGetPos(&sx, &sy)
    ctx := Gesture_CaptureWindowContext(sx, sy)
    if (!g_Gesture["enable"] || Gesture_IsBypass(true, ctx)) {
        g_Gesture["forwardDown"] := 1
        try Send("{" . trig . " Down}")
        catch {
        }
        return
    }
    g_Gesture["startContext"] := ctx
    g_Gesture["startHwnd"] := ctx.rootHwnd
    g_Gesture["down"] := 1
    g_Gesture["gesturing"] := 0
    g_Gesture["cancelled"] := 0
    g_Gesture["leftCombo"] := 0
    g_Gesture["forwardDown"] := 0
    g_Gesture["comboUntil"] := 0
    g_Gesture["startX"] := sx
    g_Gesture["startY"] := sy
    g_Gesture["downTick"] := A_TickCount
    g_Gesture["lastMoveTick"] := A_TickCount
    g_Gesture["points"] := [{x: sx, y: sy}]
    g_Gesture["dirs"] := []
    g_Gesture["gesture"] := ""
    try g_Gesture["downMods"] := Gesture_ActiveMods()
    catch {
        g_Gesture["downMods"] := ""
    }
    SetTimer(Gesture_Poll, g_Gesture["poll"])
}

; ---- 坐标取窗口句柄 (起点窗口用, 失败返回 0) ----
Gesture_HwndFromPoint(x, y) {
    try {
        pt := Buffer(8, 0)
        NumPut("Int", x, pt, 0)
        NumPut("Int", y, pt, 4)
        hwnd := DllCall("WindowFromPoint", "Int64", NumGet(pt, 0, "Int64"), "Ptr")
        return hwnd + 0
    } catch {
        return 0
    }
}

; ---- 起点窗口三要素 (窗口动作的目标; 句柄失效回退活动窗口) ----
Gesture_StartIds(&exe, &cls, &title, &ownerCls := "", &ctrlCls := "", &ctrlTitle := "") {
    global g_Gesture
    try {
        ctx := g_Gesture["startContext"]
        if IsObject(ctx) {
            exe := ctx.exe
            cls := ctx.cls
            title := ctx.title
            ownerCls := ctx.ownerCls
            ctrlCls := ctx.ctrlCls
            ctrlTitle := ctx.ctrlTitle
            return
        }
    }
    Gesture_GetActiveIds(&exe, &cls, &title, &ownerCls, &ctrlCls, &ctrlTitle)
}

; ---- 动作目标窗口 spec (起点有效即起点, 否则 "A") ----
Gesture_ActionWin() {
    global g_Gesture
    try {
        if (g_Gesture["startHwnd"] + 0 && IsObject(g_Gesture["startContext"]))
            return "ahk_id " . (g_Gesture["startHwnd"] + 0)
    } catch {
    }
    return "A"
}

; ---- 采样轮询: 判断进入手势 / 追加方向 / Esc 取消 ----
Gesture_Poll() {
    global g_Gesture
    if (!g_Gesture["down"])
        return
    CoordMode("Mouse", "Screen")
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
    ; 左键组合 (StrokesPlus: 手势中按左键): 置位后 Up 处按 L/R 分发切换窗口
    try {
        if GetKeyState("LButton", "P")
            g_Gesture["leftCombo"] := 1
    }
    MouseGetPos(&mx, &my)
    pts := g_Gesture["points"]
    last := pts[pts.Length]
    dx0 := mx - last.x
    dy0 := my - last.y
    if (dx0 * dx0 + dy0 * dy0 >= 16)
        g_Gesture["lastMoveTick"] := A_TickCount
    else if (g_Gesture["cancelDelay"] > 0 && !g_Gesture["recording"]
        && !g_Gesture["tplRecording"] && !g_Gesture["tryMode"]
        && A_TickCount - g_Gesture["lastMoveTick"] >= g_Gesture["cancelDelay"]
        && !Gesture_ComboActive()) {
        Gesture_BeginRelay()
        return
    }
    if (dx0 * dx0 + dy0 * dy0 < 16) {
        ; 无位移也刷新组合武装 (Z 画完停住即滚轮, 不必等新采样点)
        Gesture_PollComboArm()
        return
    }
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
    Gesture_PollComboArm()
    if (g_Gesture["showOSD"])
        Gesture_OSD()
}

; ---- 按住期组合武装 (StrokesPlus: Z 画完不松键直接滚轮): 当前链命中 combo 即武装 ----
Gesture_PollComboArm() {
    global g_Gesture
    try {
        g := g_Gesture["gesture"]
        if (g = "")
            return
        Gesture_StartIds(&exe, &cls, &title, &ownerCls, &ctrlCls, &ctrlTitle)
        res := Gesture_ResolveStroke(g, g_Gesture["points"], exe, cls, title,
            g_Gesture["downMods"], ownerCls, ctrlCls, ctrlTitle)
        if (res[1] != "" && SubStr(Trim(res[1]), 1, 6) = "combo|")
            Gesture_ComboArm(res[1])
        else if (g_Gesture["comboUntil"] > 0) {
            g_Gesture["comboUntil"] := 0
            g_Gesture["comboKind"] := ""
        }
    } catch {
    }
}

; Preserve meaningful corners while suppressing small hand jitter.
Gesture_Simplify(pts, tolerance) {
    if (pts.Length < 3)
        return pts
    kept := Map(1, 1, pts.Length, 1)
    stack := [[1, pts.Length]]
    while (stack.Length) {
        span := stack.Pop()
        a := span[1], b := span[2]
        vx := pts[b].x - pts[a].x, vy := pts[b].y - pts[a].y
        len2 := vx * vx + vy * vy
        far := 0.0, farIdx := 0
        Loop b - a - 1 {
            i := a + A_Index
            wx := pts[i].x - pts[a].x, wy := pts[i].y - pts[a].y
            t := len2 > 0 ? Max(0, Min(1, (wx * vx + wy * vy) / len2)) : 0
            dx := wx - t * vx, dy := wy - t * vy
            dist2 := dx * dx + dy * dy
            if (dist2 > far) {
                far := dist2, farIdx := i
            }
        }
        if (farIdx && far > tolerance * tolerance) {
            kept[farIdx] := 1
            stack.Push([a, farIdx], [farIdx, b])
        }
    }
    out := []
    for i, p in pts
        if kept.Has(i)
            out.Push(p)
    return out
}

; Canonicalize chevrons before direction quantization. This prevents a pause or
; a few samples near the apex from turning V/InvV into U_UR_D/UR_DR_D.
Gesture_ChevronApex(corners, idx, size) {
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

Gesture_ChevronChain(corners, size) {
    if (corners.Length < 3 || corners.Length > 4)
        return ""
    minIdx := 2
    maxIdx := 2
    for i in Gesture_Range(3, corners.Length - 1) {
        if (corners[i].y < corners[minIdx].y)
            minIdx := i
        if (corners[i].y > corners[maxIdx].y)
            maxIdx := i
    }
    first := corners[1]
    last := corners[corners.Length]
    if (Abs(last.y - first.y) > Max(12, size * 0.26))
        return ""
    baseY := (first.y + last.y) * 0.5
    if (corners[minIdx].y < baseY - size * 0.20 && Gesture_ChevronApex(corners, minIdx, size))
        return (corners[minIdx].x > first.x) ? "UR_DR" : "UL_DL"
    if (corners[maxIdx].y > baseY + size * 0.20 && Gesture_ChevronApex(corners, maxIdx, size))
        return (corners[maxIdx].x > first.x) ? "DR_UR" : "DL_UR"
    return ""
}

Gesture_DirectionChain(pts, segment := 6) {
    if (pts.Length < 2)
        return ""
    bb := Tpl_BBox(pts)
    size := Max(bb[3] - bb[1], bb[4] - bb[2])
    if (size < segment)
        return ""
    simplifyTol := Max(4, Max(segment * 0.8, size * 0.045))
    corners := Gesture_Simplify(pts, simplifyTol)
    minLeg := Max(10, Max(segment * 1.5, size * 0.09))
    chevron := Gesture_ChevronChain(corners, size)
    if (chevron != "")
        return chevron
    dirs := []
    anchor := corners[1]
    for i in Gesture_Range(2, corners.Length) {
        p := corners[i]
        dx := p.x - anchor.x, dy := p.y - anchor.y
        if (dx * dx + dy * dy < minLeg * minLeg)
            continue
        d := Gesture_DirOf(dx, dy)
        if (dirs.Length = 0 || dirs[dirs.Length] != d)
            dirs.Push(d)
        anchor := p
    }
    s := ""
    for i, d in dirs
        s .= (i > 1 ? "_" : "") . d
    return s
}

; ---- 全量识别: 轨迹简化后编码有意义的方向段 ----
Gesture_Recognize() {
    global g_Gesture
    pts := g_Gesture["points"]
    if (pts.Length < 2)
        return
    s := Gesture_DirectionChain(pts, g_Gesture["segment"])
    dirs := (s = "") ? [] : StrSplit(s, "_")
    g_Gesture["dirs"] := dirs
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
        Gesture_StartIds(&exe, &cls, &title, &ownerCls, &ctrlCls, &ctrlTitle)
        mods := ""
        try mods := g_Gesture["downMods"]
        catch {
        }
        if (mods = "")
            mods := Gesture_ActiveMods()
        res := Gesture_ResolveStroke(g, g_Gesture["points"], exe, cls, title,
            mods, ownerCls, ctrlCls, ctrlTitle)
        if (res[1] != "")
            txt .= "`n" . T("gesture.osd_action", res[1], res[2])
    }
    ToolTip(txt)
}

; ---- 触发键松开: 录制截获 / 分层执行 / 短点透传 ----
; 手势候选期间暂存触发键; 短点或 passthrough 重放完整点击, 旁路状态配对转发 Down/Up.
Gesture_Up(*) {
    global g_Gesture
    CoordMode("Mouse", "Screen")
    try SetTimer(Gesture_Poll, 0)
    catch {
    }
    try Gesture_UpCore()
    finally {
        Gesture_ClearStartContext()
    }
}

Gesture_UpCore() {
    global g_Gesture
    trig := g_Gesture["trigger"]
    if (!g_Gesture["down"]) {
        if (g_Gesture["forwardDown"]) {
            try Send("{" . trig . " Up}")
            catch {
            }
            g_Gesture["forwardDown"] := 0
        }
        return
    }
    MouseGetPos(&endX, &endY)
    pts := g_Gesture["points"]
    last := pts[pts.Length]
    dx := endX - last.x, dy := endY - last.y
    if (dx * dx + dy * dy >= 16) {
        pts.Push({x: endX, y: endY})
        sx := g_Gesture["startX"], sy := g_Gesture["startY"]
        if ((endX - sx) ** 2 + (endY - sy) ** 2 >= g_Gesture["threshold"] ** 2)
            g_Gesture["gesturing"] := 1
        if (g_Gesture["gesturing"])
            Gesture_Recognize()
    }
    g_Gesture["down"] := 0
    wasGesturing := g_Gesture["gesturing"]
    wasCancelled := g_Gesture["cancelled"]
    gesture := g_Gesture["gesture"]
    leftCombo := g_Gesture["leftCombo"]
    g_Gesture["gesturing"] := 0
    g_Gesture["cancelled"] := 0
    g_Gesture["leftCombo"] := 0
    try ToolTip()
    catch {
    }
    try GestureTrail_Hide()
    catch {
    }
    if (wasGesturing && !wasCancelled) {
        ; 录制模式: 截获, 不执行 (吞 Up, 不弹菜单)
        if (g_Gesture["recording"]) {
            if (gesture = "")
                return
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
        ; 模板录制: 归一化为点串交回调, 不执行 (吞 Up)
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
            SetTimer(Gesture_HideTip, -1200)
            if (IsObject(tcb) && enc != "") {
                try tcb(enc)
            }
            return
        }
        ; 左键组合 (StrokesPlus: 画 L/R 过程中按左键 -> 切窗口), 优先于常规解析
        if (leftCombo && (gesture = "L" || gesture = "R")) {
            if (g_Gesture["tryMode"]) {
                try ToolTip(T("gesture.try_hit", gesture . "+LButton"
                    , gesture = "L" ? "<SP_SwitchLast>" : "<SP_SwitchNext>", "组合"))
                catch {
                }
                SetTimer(Gesture_HideTip, -2000)
            } else if (gesture = "L") {
                try Send("!+{Esc}")
                catch {
                }
            } else {
                try Send("!{Esc}")
                catch {
                }
            }
            return
        }
        ; 修饰键用按下瞬间快照 (CaptureModifiersOnMouseDown 对等),
        ; 匹配与窗口目标用起点窗口 (gsx/gsy 对等)
        Gesture_StartIds(&exe, &cls, &title, &ownerCls, &ctrlCls, &ctrlTitle)
        mods := ""
        try mods := g_Gesture["downMods"]
        catch {
        }
        res := Gesture_ResolveStroke(gesture, g_Gesture["points"], exe, cls, title, mods,
            ownerCls, ctrlCls, ctrlTitle)
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
        ; 未命中透传保留拖拽所需的按下/移动/松开事件.
        if (g_Gesture["noMatch"] = "passthrough") {
            Gesture_RelayStroke(true)
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
    ; 短点: 重放一次完整点击, 保留普通右键菜单行为.
    Gesture_SendTriggerClick(trig)
}

Gesture_ClearStartContext() {
    global g_Gesture
    g_Gesture["startHwnd"] := 0
    g_Gesture["startContext"] := ""
    g_Gesture["downMods"] := ""
    g_Gesture["leftCombo"] := 0
    g_Gesture["comboUntil"] := 0
    g_Gesture["comboKind"] := ""
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
    leftHeld := false
    try leftHeld := GetKeyState("LButton", "P")
    catch {
    }
    gestureDown := g_Gesture["down"]
    if (gestureDown)
        Gesture_StartIds(&exe, &cls, &title, &ownerCls, &ctrlCls, &ctrlTitle)
    else
        Gesture_GetActiveIds(&exe, &cls, &title, &ownerCls, &ctrlCls, &ctrlTitle)
    ; 左键组合 (StrokesPlus: 按住手势键 + 左键 + 滚轮 -> 音量)
    if (held && leftHeld && (which = "WheelUp" || which = "WheelDown")) {
        if (g_Gesture["tryMode"]) {
            try ToolTip(T("gesture.try_wheel", which . "+LButton"
                , which = "WheelUp" ? "<SP_VolUp>" : "<SP_VolDown>", "组合"))
            catch {
            }
            SetTimer(Gesture_HideTip, -2000)
        } else {
            try Send(which = "WheelUp" ? "{Volume_Up}" : "{Volume_Down}")
            catch {
            }
        }
        return
    }
    ; 组合技 (StrokesPlus: Z 画完不松键直接滚轮 -> 缩放): 必须仍按住触发键
    if (Gesture_ComboActive()) {
        if (!held) {
            try Send("{" . which . "}")
            catch {
            }
            return
        }
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
    if (!held || Gesture_IsBypass(false, gestureDown ? g_Gesture["startContext"] : "")) {
        try Send("{" . which . "}")
        catch {
        }
        return
    }
    mods := ""
    try mods := g_Gesture["downMods"]
    catch {
    }
    if (mods = "" || !g_Gesture["down"])
        mods := Gesture_ActiveMods()
    res := Gesture_ResolveFor(which, exe, cls, mods, title, ownerCls, ctrlCls, ctrlTitle)
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

Gesture_SendTriggerClick(trigger) {
    button := Gesture_ClickName(trigger)
    try Click(button)
    catch {
        try Send("{" . trigger . "}")
        catch {
        }
    }
}

; Replay a held button and sampled movement. A timeout leaves the button down
; until the physical trigger is released; no-match replay completes it here.
Gesture_RelayStroke(release := true) {
    global g_Gesture
    CoordMode("Mouse", "Screen")
    pts := g_Gesture["points"]
    if (pts.Length = 0)
        return false
    MouseGetPos(&endX, &endY)
    last := pts[pts.Length]
    if (last.x != endX || last.y != endY)
        pts.Push({x: endX, y: endY})
    trig := g_Gesture["trigger"]
    if (pts.Length < 2 || (pts.Length = 2 && pts[1].x = pts[2].x && pts[1].y = pts[2].y)) {
        if (release) {
            Gesture_SendTriggerClick(trig)
        } else {
            try {
                SendEvent("{" . trig . " Down}")
            } catch {
                return false
            }
        }
        return true
    }
    pressed := false
    try {
        Critical("On")
        SetMouseDelay(-1)
        MouseMove(pts[1].x, pts[1].y, 0)
        SendEvent("{" . trig . " Down}")
        pressed := true
        step := Max(1, Ceil((pts.Length - 1) / 200))
        i := 2
        while (i < pts.Length) {
            MouseMove(pts[i].x, pts[i].y, 0)
            i += step
        }
        MouseMove(endX, endY, 0)
        if (release) {
            SendEvent("{" . trig . " Up}")
            pressed := false
        }
        return true
    } catch {
        if (pressed)
            try SendEvent("{" . trig . " Up}")
        return false
    } finally {
        Critical("Off")
    }
}

Gesture_BeginRelay() {
    global g_Gesture
    try SetTimer(Gesture_Poll, 0)
    catch {
    }
    try GestureTrail_Hide()
    catch {
    }
    try ToolTip()
    catch {
    }
    if (Gesture_RelayStroke(false)) {
        g_Gesture["down"] := 0
        g_Gesture["gesturing"] := 0
        g_Gesture["forwardDown"] := 1
        Gesture_ClearStartContext()
    }
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
        wasActive := (g_Gesture["comboKind"] = kind && Gesture_ComboActive())
        g_Gesture["comboUntil"] := A_TickCount + 1500
        g_Gesture["comboKind"] := kind
        if (!wasActive) {
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
