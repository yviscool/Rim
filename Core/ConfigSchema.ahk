#Requires AutoHotkey v2.0
#Warn All, Off

; === ConfigSchema - 配置 schema 中心 ===
; 中央表 g_CfgSchema: Array of Map(sec,key,type,min,max,options,pattern,default,label,help,scope)
;   type: bool/text/int/lang/skin/choice/slider
;   scope: live(内存同步即生效, 按需调 Apply)/rebuild(本域重建, 不杀进程)/restart(需重启)
; 配套: CfgGet(读值, 缺键回 schema default)/CfgValidate(校验)/CfgSubscribe/Publish/Unsubscribe(变更广播)
; 加载顺序: Core\I18n.ahk 之后 (label/help 与校验串走 T()), 插件与 Gui 之前.
; 零运行时依赖: 无 g_Conf 时 CfgGet 回 default (探针可用, 见 tools/probe_config_schema.ahk).

global g_CfgSchema := [
    ; ---- [Config] 启动器行为 (lspecs, 与 VimCfg_LauncherSpecs 同源, 以此表为准) ----
    Map("sec", "Config", "key", "SearchFileDir", "type", "text", "default", "", "label", "cfg.opt_searchdir", "help", "cfg.help_searchdir", "scope", "live"),
    Map("sec", "Config", "key", "SearchFileType", "type", "text", "default", "*.exe | *.lnk", "label", "cfg.opt_searchtype", "help", "cfg.help_searchtype", "scope", "live"),
    Map("sec", "Config", "key", "SearchFileExclude", "type", "text", "default", "", "label", "cfg.opt_exclude", "help", "cfg.help_exclude", "scope", "live"),
    Map("sec", "Config", "key", "TCMatchPath", "type", "text", "default", "", "label", "cfg.opt_tcmatch", "help", "cfg.help_tcmatch", "scope", "restart"),
    Map("sec", "Config", "key", "Language", "type", "lang", "default", "auto", "label", "cfg.opt_language", "help", "cfg.help_language", "scope", "rebuild"),
    Map("sec", "Config", "key", "RunInBackground", "type", "bool", "default", "1", "label", "cfg.opt_bg", "help", "cfg.help_bg", "scope", "live"),
    Map("sec", "Config", "key", "ExitIfInactivate", "type", "bool", "default", "1", "label", "cfg.opt_exitblur", "help", "cfg.help_exitblur", "scope", "live"),
    Map("sec", "Config", "key", "WindowAlwaysOnTop", "type", "bool", "default", "0", "label", "cfg.opt_topmost", "help", "cfg.help_topmost", "scope", "rebuild"),
    Map("sec", "Config", "key", "SaveHistory", "type", "bool", "default", "1", "label", "cfg.opt_history", "help", "cfg.help_history", "scope", "live"),
    Map("sec", "Config", "key", "HistorySize", "type", "int", "min", 1, "max", 500, "default", "100", "label", "cfg.opt_historysize", "help", "cfg.help_historysize", "scope", "live"),
    Map("sec", "Config", "key", "AutoRank", "type", "bool", "default", "1", "label", "cfg.opt_autorank", "help", "cfg.help_autorank", "scope", "live"),
    Map("sec", "Config", "key", "ClickToRun", "type", "bool", "default", "1", "label", "cfg.opt_clicktorun", "help", "cfg.help_clicktorun", "scope", "live"),
    Map("sec", "Config", "key", "KeepInputText", "type", "bool", "default", "1", "label", "cfg.opt_keepinput", "help", "cfg.help_keepinput", "scope", "live"),
    Map("sec", "Config", "key", "RunOnce", "type", "bool", "default", "0", "label", "cfg.opt_runonce", "help", "cfg.help_runonce", "scope", "live"),
    Map("sec", "Config", "key", "RunIfOnlyOne", "type", "bool", "default", "0", "label", "cfg.opt_runifone", "help", "cfg.help_runifone", "scope", "live"),
    Map("sec", "Config", "key", "SwitchToEngIME", "type", "bool", "default", "0", "label", "cfg.opt_engime", "help", "cfg.help_engime", "scope", "live"),
    Map("sec", "Config", "key", "DebugMode", "type", "bool", "default", "0", "label", "cfg.opt_debug", "help", "cfg.help_debug", "scope", "live"),
    Map("sec", "Config", "key", "ShowFileExt", "type", "bool", "default", "0", "label", "cfg.opt_showext", "help", "cfg.help_showext", "scope", "live"),
    Map("sec", "Config", "key", "SearchFullPath", "type", "bool", "default", "0", "label", "cfg.opt_searchfull", "help", "cfg.help_searchfull", "scope", "live"),
    Map("sec", "Config", "key", "LoadControlPanelFunctions", "type", "bool", "default", "0", "label", "cfg.opt_cpl", "help", "cfg.help_cpl", "scope", "live"),
    Map("sec", "Config", "key", "RankHalfLife", "type", "int", "min", 1, "max", 365, "default", "14", "label", "cfg.opt_rankhalf", "help", "cfg.help_rankhalf", "scope", "live"),
    Map("sec", "Config", "key", "SaveInputText", "type", "bool", "default", "0", "label", "cfg.opt_saveinput", "help", "cfg.help_saveinput", "scope", "live"),
    Map("sec", "Config", "key", "CreateSendToLnk", "type", "bool", "default", "0", "label", "cfg.opt_sendto", "help", "cfg.help_sendto", "scope", "live"),
    Map("sec", "Config", "key", "CreateStartupLnk", "type", "bool", "default", "0", "label", "cfg.opt_startuplnk", "help", "cfg.help_startuplnk", "scope", "live"),
    Map("sec", "Config", "key", "ChangeCommandOnMouseMove", "type", "bool", "default", "0", "label", "cfg.opt_mousemove", "help", "cfg.help_mousemove", "scope", "live"),
    Map("sec", "Config", "key", "ClearInputWithEsc", "type", "bool", "default", "0", "label", "cfg.opt_clearesc", "help", "cfg.help_clearesc", "scope", "live"),
    Map("sec", "Config", "key", "Editor", "type", "text", "default", "", "label", "cfg.opt_editor", "help", "cfg.help_editor", "scope", "live"),

    ; ---- [Gui] 外观 (同上) ----
    Map("sec", "Gui", "key", "Skin", "type", "skin", "default", "New", "label", "cfg.opt_skin", "help", "cfg.help_skin", "scope", "rebuild"),
    Map("sec", "Gui", "key", "HideTitle", "type", "bool", "default", "1", "label", "cfg.opt_hidetitle", "help", "cfg.help_hidetitle", "scope", "rebuild"),
    Map("sec", "Gui", "key", "ShowTrayIcon", "type", "bool", "default", "1", "label", "cfg.opt_tray", "help", "cfg.help_tray", "scope", "restart"),
    Map("sec", "Gui", "key", "ShowCurrentCommand", "type", "bool", "default", "1", "label", "cfg.opt_showcmd", "help", "cfg.help_showcmd", "scope", "rebuild"),
    Map("sec", "Gui", "key", "DisplayRows", "type", "int", "min", 5, "max", 30, "default", "15", "label", "cfg.opt_rows", "help", "cfg.help_rows", "scope", "rebuild"),
    Map("sec", "Gui", "key", "WidgetWidth", "type", "int", "min", 300, "max", 1200, "default", "600", "label", "cfg.opt_width", "help", "cfg.help_width", "scope", "rebuild"),
    Map("sec", "Gui", "key", "FontName", "type", "text", "default", "宋体", "label", "cfg.opt_font", "help", "cfg.help_font", "scope", "rebuild"),
    Map("sec", "Gui", "key", "FontSize", "type", "int", "min", 8, "max", 28, "default", "12", "label", "cfg.opt_fontsize", "help", "cfg.help_fontsize", "scope", "rebuild"),
    Map("sec", "Gui", "key", "FontColor", "type", "text", "pattern", "^[0-9a-fA-F]{6}$", "default", "000000", "label", "cfg.opt_fontcolor", "help", "cfg.help_fontcolor", "scope", "rebuild"),
    Map("sec", "Gui", "key", "BackgroundColor", "type", "text", "pattern", "^[0-9a-fA-F]{6}$", "default", "f1f1f1", "label", "cfg.opt_bgcolor", "help", "cfg.help_bgcolor", "scope", "rebuild"),
    Map("sec", "Gui", "key", "EditColor", "type", "text", "pattern", "^[0-9a-fA-F]{6}$", "default", "ffffff", "label", "cfg.opt_editcolor", "help", "cfg.help_editcolor", "scope", "rebuild"),
    ; ---- [StatsBall] 雷达 (sbspecs, 与 VimCfg_StatsBallSpecs 同源) ----
    Map("sec", "StatsBall", "key", "Enable", "type", "bool", "default", "1", "label", "cfg.opt_statsball_enable", "help", "cfg.help_statsball_enable", "scope", "live"),
    Map("sec", "StatsBall", "key", "RefreshMs", "type", "slider", "min", 500, "max", 5000, "default", "1000", "label", "cfg.opt_statsball_refresh", "help", "cfg.help_statsball_refresh", "scope", "live"),
    Map("sec", "StatsBall", "key", "StripW", "type", "slider", "min", 120, "max", 480, "default", "156", "label", "cfg.opt_statsball_stripw", "help", "cfg.help_statsball_stripw", "scope", "live"),
    Map("sec", "StatsBall", "key", "StripH", "type", "slider", "min", 32, "max", 80, "default", "40", "label", "cfg.opt_statsball_striph", "help", "cfg.help_statsball_striph", "scope", "live"),
    Map("sec", "StatsBall", "key", "Opacity", "type", "slider", "min", 80, "max", 255, "default", "255", "label", "cfg.opt_statsball_opacity", "help", "cfg.help_statsball_opacity", "scope", "live"),
    Map("sec", "StatsBall", "key", "TopMost", "type", "bool", "default", "1", "label", "cfg.opt_statsball_topmost", "help", "cfg.help_statsball_topmost", "scope", "live"),
    Map("sec", "StatsBall", "key", "LockPos", "type", "bool", "default", "0", "label", "cfg.opt_statsball_lock", "help", "cfg.help_statsball_lock", "scope", "live"),
    Map("sec", "StatsBall", "key", "SnapEdge", "type", "bool", "default", "0", "label", "cfg.opt_statsball_snap", "help", "cfg.help_statsball_snap", "scope", "live"),
    Map("sec", "StatsBall", "key", "AlertThreshold", "type", "slider", "min", 50, "max", 100, "default", "85", "label", "cfg.opt_statsball_alert", "help", "cfg.help_statsball_alert", "scope", "live"),
    ; ---- [SmartInput] 智能输入 (边界与代码钳制对齐: MaxHist>=10, ValidateDelay>=50) ----
    Map("sec", "SmartInput", "key", "Enabled", "type", "bool", "default", "1", "label", "cfg.opt_si_enabled", "help", "cfg.help_si_enabled", "scope", "live"),
    Map("sec", "SmartInput", "key", "MaxHist", "type", "int", "min", 10, "max", 1000, "default", "100", "label", "cfg.opt_si_maxhist", "help", "cfg.help_si_maxhist", "scope", "live"),
    Map("sec", "SmartInput", "key", "ValidateDelay", "type", "int", "min", 50, "max", 2000, "default", "300", "label", "cfg.opt_si_delay", "help", "cfg.help_si_delay", "scope", "live"),
    Map("sec", "SmartInput", "key", "PrivacyExtra", "type", "text", "default", "", "label", "cfg.opt_si_privacy", "help", "cfg.help_si_privacy", "scope", "live")
]

; 订阅表: "sec\x01key" -> Array of Map(tok, fn); "*" 通配整表
global g_CfgSubs := Map()
global g_CfgTokSeq := 0

; ---- 查 schema 行 (无则返回 "") ----
; infra 永不抛: 表缺失/非对象即退化空表 (启动疑案: 某进程在表未就绪时进过此函数,
; 此前直接炸"未赋值"; 现退化与 g_Conf 未就绪同语义, 调用方按缺省走)
CfgFind(sec, key) {
    global g_CfgSchema
    try {
        if (!IsSet(g_CfgSchema) || !IsObject(g_CfgSchema)) {
            ; 取证: 复发即落盘 (每进程一次, 无弹窗), 下次贴日志即定案
            static logged := false
            if (!logged) {
                logged := true
                try FileAppend(A_Now . " CFGSCHEMA-UNSET first-hit=" . sec . "/" . key . "`n", A_ScriptDir . "\Rim.error.log")
                catch {
                }
            }
            return ""
        }
        for spec in g_CfgSchema {
            if (spec["sec"] = sec && spec["key"] = key)
                return spec
        }
    } catch {
    }
    return ""
}

; ---- 读值: ini 有值用 ini, 缺键回 schema default, 再无回传入 def ----
; g_Conf 未就绪 (探针/启动早期) 直接回 default, 永不抛错
CfgGet(sec, key, def := "") {
    global g_Conf
    try {
        if (IsSet(g_Conf) && IsObject(g_Conf)) {
            got := g_Conf.Get(sec, key, "")
            if (got != "")
                return got
        }
    }
    spec := CfgFind(sec, key)
    if (IsObject(spec) && spec.Has("default"))
        return spec["default"]
    return def
}

; ---- scope 查询 (未知键一律 restart, 宁保守不瞎热) ----
CfgScope(sec, key) {
    spec := CfgFind(sec, key)
    if (IsObject(spec) && spec.Has("scope"))
        return spec["scope"]
    return "restart"
}

; ---- 校验: 返回 ""=通过, 否则返回人类可读错误串 ----
CfgValidate(sec, key, val) {
    spec := CfgFind(sec, key)
    val := String(val)
    if (!IsObject(spec))
        return ""
    kind := spec["type"]
    if (kind = "bool") {
        if (val != "0" && val != "1")
            return T("cfg.val_bool", key)
        return ""
    }
    if (kind = "int" || kind = "slider") {
        if (!RegExMatch(val, "^[+-]?\d+$"))
            return T("cfg.val_int", key)
        num := Integer(val)
        lo := spec.Has("min") ? spec["min"] : -2147483648
        hi := spec.Has("max") ? spec["max"] : 2147483647
        if (num < lo || num > hi)
            return T("cfg.val_range", key, lo, hi)
        return ""
    }
    if (kind = "choice") {
        opts := spec.Has("options") ? spec["options"] : []
        for opt in opts {
            if (String(opt) = val)
                return ""
        }
        return T("cfg.val_choice", key)
    }
    if (spec.Has("pattern") && spec["pattern"] != "") {
        if (!RegExMatch(val, spec["pattern"]))
            return T("cfg.val_pattern", key, spec["pattern"])
        return ""
    }
    return ""
}

; ---- 订阅: fn(val, sec, key)；返回 token, 凭 token 退订 ----
CfgSubscribe(sec, key, fn) {
    global g_CfgSubs, g_CfgTokSeq
    g_CfgTokSeq++
    tok := g_CfgTokSeq
    sk := sec . Chr(1) . key
    if (!g_CfgSubs.Has(sk))
        g_CfgSubs[sk] := []
    g_CfgSubs[sk].Push(Map("tok", tok, "fn", fn))
    return tok
}

CfgUnsubscribe(tok) {
    global g_CfgSubs
    for sk, arr in g_CfgSubs {
        idx := 0
        for i, sub in arr {
            if (sub["tok"] = tok) {
                idx := i
                break
            }
        }
        if (idx > 0) {
            arr.RemoveAt(idx)
            return true
        }
    }
    return false
}

; ---- 广播: changes = Array of Map(sec,key,val[,old,scope,source])；订阅异常隔离, 返回 {ok, failed} ----
; failed 每项 {sec,key,msg}；无订阅者直接 ok
; P1-4: 回调签名 fn(val, sec, key[, old, scope, source]), 老回调 fn(val,sec,key) 仍兼容
CfgPublish(changes) {
    global g_CfgSubs
    out := Map("ok", true, "failed", [])
    for chg in changes {
        sk := chg["sec"] . Chr(1) . chg["key"]
        if (!g_CfgSubs.Has(sk))
            continue
        for sub in g_CfgSubs[sk] {
            chOld := chg.Has("old") ? chg["old"] : ""
            chScope := chg.Has("scope") ? chg["scope"] : CfgScope(chg["sec"], chg["key"])
            chSrc := chg.Has("source") ? chg["source"] : ""
            ; 先按 arity 决定调用形态, handler 出错只记失败不换参重试 (避免跑两遍)
            wants6 := false
            try wants6 := (sub["fn"].MaxParams >= 6)
            catch {
                wants6 := false
            }
            try {
                if (wants6)
                    sub["fn"](chg["val"], chg["sec"], chg["key"], chOld, chScope, chSrc)
                else
                    sub["fn"](chg["val"], chg["sec"], chg["key"])
            } catch as ex {
                out["ok"] := false
                msg := ""
                try msg := ex.Message
                out["failed"].Push(Map("sec", chg["sec"], "key", chg["key"], "msg", msg))
            }
        }
    }
    return out
}

; ---- 统一写入入口: 校验→内存→发布 (落盘走 CfgTxn_SaveIni 事务) ----
; P1-4: 新代码禁止直写 g_Conf.Set, 一律走 CfgSet; 非法值拒收不落盘
CfgSet(sec, key, val, source := "api") {
    msg := ""
    try msg := CfgValidate(sec, key, val)
    catch {
        msg := ""
    }
    if (msg != "")
        return Map("ok", false, "msg", msg)
    old := ""
    try {
        global g_Conf
        old := g_Conf.Get(sec, key, "")
    }
    try {
        global g_Conf
        g_Conf.Set(sec, key, val)
    } catch as ex {
        return Map("ok", false, "msg", ex.Message)
    }
    scope := CfgScope(sec, key)
    res := CfgPublish([Map("sec", sec, "key", key, "val", val, "old", old, "scope", scope, "source", source)])
    if (!res["ok"]) {
        msg := ""
        try msg := res["failed"][1]["msg"]
        catch {
        }
        ; 发布失败回滚内存, 与发布成功态一致
        try {
            global g_Conf
            g_Conf.Set(sec, key, old)
        }
        return Map("ok", false, "msg", msg)
    }
    return Map("ok", true, "msg", "")
}
