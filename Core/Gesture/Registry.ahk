#Requires AutoHotkey v2.0
#Warn All, Off

; === Core/Gesture/Registry.ahk - 动态手势注册中心 (Dynamic Gesture Registry) ===
; 允许插件和运行时模块直接通过代码注册、注销、查询和分发手势，解耦手势配置与具体插件。

class GestureRegistryItem {
    __New(id, pattern, action, targetWin := "", options := "") {
        this.id := id
        this.pattern := GestureRecognizer.NormalizeFull(pattern)
        this.action := action
        this.targetWin := this._ParseTarget(targetWin)
        this.description := ""
        this.layer := "plugin"
        this.pluginName := ""
        this.enabled := true

        if (IsObject(options)) {
            if (HasProp(options, "description"))
                this.description := options.description
            if (HasProp(options, "layer"))
                this.layer := options.layer
            if (HasProp(options, "pluginName"))
                this.pluginName := options.pluginName
            if (HasProp(options, "enabled"))
                this.enabled := options.enabled ? true : false
        } else if (Type(options) = "String" && options != "") {
            this.description := options
        }
    }

    _ParseTarget(targetWin) {
        if (!targetWin)
            return ""
        if (IsObject(targetWin))
            return targetWin

        ; 解析类似 "ahk_exe explorer.exe" 或 "ahk_class CabinetWClass" 或纯 exe
        str := Trim(targetWin)
        res := {exe: "", cls: "", title: "", ctrlCls: ""}
        if (RegExMatch(str, "i)ahk_exe\s+([^\s]+)", &m))
            res.exe := m[1]
        if (RegExMatch(str, "i)ahk_class\s+([^\s]+)", &m))
            res.cls := m[1]
        if (RegExMatch(str, "i)ahk_title\s+(.+)$", &m))
            res.title := m[1]
        
        ; 简写兜底: "explorer.exe"
        if (res.exe = "" && res.cls = "" && res.title = "") {
            if (InStr(str, ".exe"))
                res.exe := str
            else
                res.cls := str
        }
        return res
    }

    MatchesTarget(exe, cls, title := "", ownerCls := "", ctrlCls := "", ctrlTitle := "") {
        if (!IsObject(this.targetWin))
            return true ; 全局手势，无目标限制

        t := this.targetWin
        tExe := HasProp(t, "exe") ? t.exe : ""
        tCls := HasProp(t, "cls") ? t.cls : ""
        tTitle := HasProp(t, "title") ? t.title : ""
        tTitleRx := HasProp(t, "titleRx") ? t.titleRx : ""
        tCtrlCls := HasProp(t, "ctrlCls") ? t.ctrlCls : ""

        if (tExe != "") {
            if (exe = "" || !this._MatchList(exe, tExe))
                return false
        }
        if (tCls != "") {
            if (cls = "" || !this._MatchList(cls, tCls))
                return false
        }
        if (tTitle != "") {
            if (title = "" || !InStr(StrLower(title), StrLower(tTitle)))
                return false
        }
        if (tTitleRx != "") {
            if (title = "")
                return false
            try {
                if (RegExMatch(title, tTitleRx) <= 0)
                    return false
            } catch {
                return false
            }
        }
        if (tCtrlCls != "") {
            if (ctrlCls = "" || !this._MatchList(ctrlCls, tCtrlCls))
                return false
        }
        return true
    }

    _MatchList(val, patterns) {
        val := StrLower(Trim(val))
        for _, p in StrSplit(patterns, "|") {
            p := StrLower(Trim(p))
            if (p != "" && val = p)
                return true
        }
        return false
    }
}

class GestureRegistry {
    static _items := []
    static _nextId := 1

    ; ---- 注册手势 ----
    ; pattern: "U", "D_R", "CTRL+L"
    ; action: 函数对象或字符串命令 (如 "/key ^w", "<Explorer_NewTab>")
    ; targetWin: 可选目标窗口 (如 "ahk_exe explorer.exe" 或 {exe: "Totalcmd64.exe"})
    ; options: 选项对象 {description, layer, pluginName, enabled}
    static Register(pattern, action, targetWin := "", options := "") {
        item := GestureRegistryItem(this._nextId++, pattern, action, targetWin, options)
        this._items.Push(item)

        ; 动态注册的手势同时纳入手势引擎候选集 (确保 CollectCandidates 能够识别新模式)
        try {
            if (IsSet(GestureEngine) && IsObject(GestureEngine) && HasMethod(GestureEngine, "DefineGesture")) {
                basePat := RegExReplace(item.pattern, "^.*[\+\^!#]", "")
                if (basePat != "")
                    GestureEngine.DefineGesture(basePat, "auto")
            }
        } catch {
        }

        return item.id
    }

    ; ---- 按 ID 注销 ----
    static Unregister(id) {
        i := 1
        while (i <= this._items.Length) {
            if (this._items[i].id = id) {
                this._items.RemoveAt(i)
                return true
            }
            i++
        }
        return false
    }

    ; ---- 清空注册项 (可按插件名过滤) ----
    static Clear(pluginName := "") {
        if (pluginName = "") {
            this._items := []
            return
        }
        filtered := []
        for item in this._items {
            if (item.pluginName != pluginName)
                filtered.Push(item)
        }
        this._items := filtered
    }

    ; ---- 解析手势 (优先命中指定窗口的特定手势，再全局手势) ----
    static Resolve(gestureStr, exe, cls, title := "", mods := "", ownerCls := "", ctrlCls := "", ctrlTitle := "") {
        g := GestureRecognizer.Normalize(gestureStr)
        if (g = "")
            return ""

        fullPattern := (mods != "") ? GestureRecognizer.NormalizeFull(mods . g) : g

        ; 第一轮: 精确匹配修饰键 + 专属目标窗口
        for item in this._items {
            if (!item.enabled)
                continue
            if (item.targetWin != "" && item.pattern = fullPattern) {
                if (item.MatchesTarget(exe, cls, title, ownerCls, ctrlCls, ctrlTitle))
                    return {action: item.action, layer: item.layer, pluginName: item.pluginName, item: item}
            }
        }

        ; 第二轮: 裸手势 (若无修饰键) + 专属目标窗口
        if (mods = "") {
            for item in this._items {
                if (!item.enabled)
                    continue
                if (item.targetWin != "" && item.pattern = g) {
                    if (item.MatchesTarget(exe, cls, title, ownerCls, ctrlCls, ctrlTitle))
                        return {action: item.action, layer: item.layer, pluginName: item.pluginName, item: item}
                }
            }
        }

        ; 第三轮: 精确匹配修饰键 + 全局目标
        for item in this._items {
            if (!item.enabled)
                continue
            if (item.targetWin = "" && item.pattern = fullPattern)
                return {action: item.action, layer: "global", pluginName: item.pluginName, item: item}
        }

        ; 第四轮: 裸手势 + 全局目标
        if (mods = "") {
            for item in this._items {
                if (!item.enabled)
                    continue
                if (item.targetWin = "" && item.pattern = g)
                    return {action: item.action, layer: "global", pluginName: item.pluginName, item: item}
            }
        }

        return ""
    }

    ; ---- 列表查询 ----
    static List(pluginName := "") {
        if (pluginName = "")
            return this._items
        out := []
        for item in this._items {
            if (item.pluginName = pluginName)
                out.Push(item)
        }
        return out
    }

    static Count() {
        return this._items.Length
    }
}
