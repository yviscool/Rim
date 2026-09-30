#Requires AutoHotkey v2.0
#Warn All, Off

; === VimCfg_Save - 配置中心保存管线 (WriteIni/事务/预览/备份/撤销/配置集/历史) ===
; 入口见 VimConfigUI.ahk, 加载顺序见 Rim.ahk (Gui 组, ConfigSchema 之后)
; ==================== 保存层 (纯函数, 可单测) ====================
; final: Map, key = sec Chr(1) key, value = {val: "...", del: true/false}
; 单写器: final→setMap 适配后走 CfgTxn_WriteTmp/VerifyTmp (与 CfgTxn_SaveIni 同实现);
; 老直写实现保留为无 ConfigTxn 上下文时的回落 (仅探针外 exotic 引用会走到)
VimCfg_WriteIni(path, final) {
    if (IsSet(CfgTxn_WriteTmp) && IsSet(CfgTxn_VerifyTmp)) {
        setMap := Map()
        for sk, d in final {
            pos := InStr(sk, Chr(1))
            sec := SubStr(sk, 1, pos - 1)
            if (!setMap.Has(sec))
                setMap[sec] := Map()
            setMap[sec][d["key"]] := Map("val", d["val"], "del", d["del"])
        }
        tmp := path . ".rimtmp"
        CfgTxn_WriteTmp(path, tmp, setMap)
        try {
            CfgTxn_VerifyTmp(tmp, setMap)
        } catch {
            try FileDelete(tmp)
            catch {
            }
            throw
        }
        FileMove(tmp, path, 1)
        return
    }
    VimCfg_WriteIniDirect(path, final)
}

VimCfg_WriteIniDirect(path, final) {
    lines := ReadFileLines(path)
    out := []
    cur := ""
    seen := Map()
    done := Map()
    for line in lines {
        if RegExMatch(line, "^\s*\[(.+)\]\s*$", &m) {
            ; 段尾: 把本段新增键追到段末
            if (cur != "") {
                for sk, d in final {
                    pos := InStr(sk, Chr(1))
                    if (SubStr(sk, 1, pos - 1) = cur && !done.Has(sk) && !d["del"])
                        out.Push(d["key"] "=" d["val"]), done[sk] := true
                }
            }
            cur := Trim(m[1])
            seen[cur] := true
            out.Push(line)
            continue
        }
        if (cur != "" && !RegExMatch(line, "^\s*[;#]")) {
            if RegExMatch(line, "^([^=]+)=(.*)$", &k) {
                kk := Trim(k[1])
                sk := cur . Chr(1) . kk
                if (final.Has(sk) && !done.Has(sk)) {
                    done[sk] := true
                    d := final[sk]
                    if (!d["del"])
                        out.Push(d["key"] "=" d["val"])
                    continue
                }
            }
        }
        out.Push(line)
    }
    if (cur != "") {
        for sk, d in final {
            pos := InStr(sk, Chr(1))
            if (SubStr(sk, 1, pos - 1) = cur && !done.Has(sk) && !d["del"])
                out.Push(d["key"] "=" d["val"]), done[sk] := true
        }
    }
    ; 全新段追到文件尾
    for sk, d in final {
        if (done.Has(sk) || d["del"])
            continue
        pos := InStr(sk, Chr(1))
        sec := SubStr(sk, 1, pos - 1)
        if (!seen.Has(sec)) {
            seen[sec] := true
            out.Push("")
            out.Push("[" sec "]")
        }
        out.Push(d["key"] "=" d["val"])
        done[sk] := true
    }
    content := ""
    for ln in out
        content .= ln "`r`n"
    f := FileOpen(path, "w", "UTF-8-RAW")
    f.Write(content)
    f.Close()
}

VimCfg_MarkDirty(sec, key, val := "", del := false) {
    global g_VimCfg
    g_VimCfg["dirty"][sec . Chr(1) . key] := Map("key", key, "val", val, "del", del)
}

VimCfg_LogErr(fn, e) {
    try {
        extra := ""
        try extra := e.Extra
        catch {
        }
        line := ""
        try line := e.Line
        catch {
        }
        FileAppend(A_Now . " VIMCFG-ERR " . fn . ": " . e.Message . " @line=" . line . " extra=" . extra . "`n", A_ScriptDir . "\Rim.error.log")
    } catch {
    }
}

VimCfg_ShowErr(fn, e) {
    VimCfg_LogErr(fn, e)
    global g_VimCfg
    try {
        if (g_VimCfg.Has("warnbar")) {
            cur := ""
            try cur := g_VimCfg["warnbar"].Value
            catch {
            }
            g_VimCfg["warnbar"].Value := cur . "`n✖ " . T("cfg.handler_failed", fn, e.Message)
        }
    } catch {
    }
}

VimCfg_OnSave(*) {
    try {
        VimCfg_OnSaveInner()
    } catch as e {
        VimCfg_ShowErr("OnSave", e)
        try MsgBox(T("cfg.save_failed", e.Message), T("cfg.title"), 16)
        catch {
        }
    }
}

VimCfg_OnSaveInner(*) {
    global g_VimCfg, g_Conf, g_AutoConf
    VimCfg_CollectLauncherTab()
    VimCfg_CollectStatsBallTab()
    VimCfg_CollectSmartInputTab()
    VimCfg_CollectTCTab()
    VimCfg_CollectPluginTab()
    VimCfg_RefreshWarnBar()
    dirty := g_VimCfg["dirty"]
    if (dirty.Count = 0) {
        ToolTip(T("cfg.no_change"))
        SetTimer(RemoveToolTip, -1200)
        return
    }
    ; 原子校验: 任一项非法整单拒绝, 动都不动
    errs := VimCfg_ValidateDirty(dirty)
    if (errs.Length > 0) {
        MsgBox(T("cfg.val_failed") "`n" . VimCfg_JoinLines(errs, 10), T("cfg.title"), 16)
        return
    }
    VimCfg_PreviewSave(dirty)
}

VimCfg_JoinLines(arr, cap := 10) {
    out := ""
    n := 0
    for line in arr {
        n++
        if (n > cap)
            break
        out .= line . "`n"
    }
    return RTrim(out, "`n")
}

; 全单 schema 校验 (删键不校验, 未知键放行——那是手写段的地盘)
VimCfg_ValidateDirty(dirty) {
    errs := []
    for sk, d in dirty {
        if (d["del"])
            continue
        pos := InStr(sk, Chr(1))
        sec := SubStr(sk, 1, pos - 1)
        msg := CfgValidate(sec, d["key"], d["val"])
        if (msg != "")
            errs.Push("[" sec "] " . d["key"] . ": " . msg)
    }
    return errs
}

; 单项生效分级: Plugins/TC 段/删 vim 键/新段一律 restart (诚实, 不玩假热删);
; TC 段键只在插件 Setup/Detect 时读一次, 无订阅即标 live 是撒谎;
; schema 键走 CfgScope; 其余新增改键走引擎运行时 MapKey = live
VimCfg_ItemScope(sec, key, del, secIsNew := false) {
    if (sec = "Plugins" || sec = "TotalCommander_Config" || del || secIsNew)
        return "restart"
    spec := CfgFind(sec, key)
    if (IsObject(spec))
        return CfgScope(sec, key)
    return "live"
}

; ==================== 保存预览 (ListView: 项/旧值/新值/生效方式) ====================
VimCfg_PreviewSave(dirty) {
    global g_VimCfg, g_Conf
    if (g_VimCfg.Has("pvGui")) {
        try g_VimCfg["pvGui"].Destroy()
        catch {
        }
    }
    rows := []
    for sk, d in dirty {
        pos := InStr(sk, Chr(1))
        sec := SubStr(sk, 1, pos - 1)
        old := ""
        try old := CfgGet(sec, d["key"], "")
        secIsNew := false
        try secIsNew := !g_Conf.HasSection(sec)
        scope := VimCfg_ItemScope(sec, d["key"], d["del"], secIsNew)
        rows.Push(Map("sec", sec, "key", d["key"], "old", old
            , "new", d["del"] ? "(delete)" : d["val"], "scope", scope))
    }
    if (rows.Length = 0) {
        ToolTip(T("cfg.preview_empty"))
        SetTimer(RemoveToolTip, -1200)
        return
    }
    pv := Gui("+Owner" g_VimCfg["gui"].Hwnd, T("cfg.preview_title"))
    pv.SetFont("s10", "Microsoft YaHei")
    lv := pv.Add("ListView", "x10 y10 w640 h260 grid", [T("cfg.preview_col_item"), T("cfg.preview_col_old"), T("cfg.preview_col_new"), T("cfg.preview_col_scope")])
    lv.ModifyCol(1, 220)
    lv.ModifyCol(2, 150)
    lv.ModifyCol(3, 150)
    lv.ModifyCol(4, 100)
    ; scope 徽标走静态 T() 映射 (字符串拼接进 T() 会被 i18n 审计判缺键)
    scopeLabel := Map("live", T("cfg.scope_live"), "rebuild", T("cfg.scope_rebuild"), "restart", T("cfg.scope_restart"))
    for row in rows
        lv.Add("", "[" row["sec"] "] " row["key"], row["old"], row["new"], scopeLabel.Has(row["scope"]) ? scopeLabel[row["scope"]] : row["scope"])
    pv.Add("Button", "x400 y280 w120 Default", T("cfg.preview_confirm")).OnEvent("Click", VimCfg_PreviewOK)
    pv.Add("Button", "x530 y280 w120", T("cfg.preview_back")).OnEvent("Click", VimCfg_PreviewBack)
    g_VimCfg["pvGui"] := pv
    pv.Show("w660 h320")
}

VimCfg_PreviewBack(*) {
    global g_VimCfg
    try g_VimCfg["pvGui"].Destroy()
    catch {
    }
    g_VimCfg.Delete("pvGui")
}

VimCfg_PreviewOK(*) {
    global g_VimCfg
    try g_VimCfg["pvGui"].Destroy()
    catch {
    }
    g_VimCfg.Delete("pvGui")
    dirty := g_VimCfg["dirty"]
    VimCfg_DoSave(dirty)
}

; ==================== 事务保存: 备份→写盘→内存+undo→广播→按需重启 ====================
; 原子语义: 广播失败则用备份整盘回滚 (内存重载 + 旧值重广播), 不留半吊子状态
; 文件相与 CfgTxn_SaveIni 同 writer/verifier (CfgTxn_WriteTmp/VerifyTmp), 重入由 g_CfgTxnActive 串行化
VimCfg_DoSave(dirty) {
    global g_CfgTxnActive
    if (IsSet(g_CfgTxnActive) && g_CfgTxnActive) {
        try MsgBox(T("cfg.save_failed", "txn busy"), T("cfg.title"), 16)
        catch {
        }
        return
    }
    g_CfgTxnActive := true
    try {
        VimCfg_DoSaveBody(dirty)
    } finally {
        g_CfgTxnActive := false
    }
}

VimCfg_DoSaveBody(dirty) {
    global g_VimCfg, g_Conf, g_AutoConf, g_CfgSelfWriteTick, g_VimEngine
    path := A_ScriptDir "\Conf\rim.ini"
    backup := VimCfg_BackupIni(path)
    ; 单管线文件相 (WriteIni 内走 txn writer/verifier, 删键吞行)
    try {
        VimCfg_WriteIni(path, dirty)
    } catch as e {
        MsgBox(T("cfg.save_failed", e.Message), T("cfg.title"), 16)
        return
    }
    ; 内存同步 + 记 undo (旧值快照; 新段记 had=false); 同步前先快照段存在性 (新段判 restart 用)
    undo := []
    newLang := ""
    secHad := Map()
    try {
        for sk, d in dirty {
            pos := InStr(sk, Chr(1))
            sec := SubStr(sk, 1, pos - 1)
            if (!secHad.Has(sec)) {
                hadSec := false
                try hadSec := g_Conf.HasSection(sec)
                secHad[sec] := hadSec
            }
            had := false
            old := ""
            try {
                had := g_Conf.HasKey(sec, d["key"])
                old := CfgGet(sec, d["key"], "")
            }
            undo.Push(Map("sec", sec, "key", d["key"], "had", had, "val", old))
            if (d["del"])
                g_Conf.DeleteKey(sec, d["key"])
            else
                ; 事务内内存同步必须直写: 走 CfgSet 会提前广播 (发布在 DoSave 末尾统一做)
                g_Conf.Set(sec, d["key"], d["val"])
            if (sec = "Config" && d["key"] = "Language" && !d["del"])
                newLang := d["val"]
        }
    }
    if (!g_VimCfg.Has("undo"))
        g_VimCfg["undo"] := []
    g_VimCfg["undo"].Push(undo)
    while (g_VimCfg["undo"].Length > 10)
        g_VimCfg["undo"].RemoveAt(1)
    ; 分级: live/rebuild 走广播 (+vim 增改走引擎), restart 攒单
    changes := []
    needRestart := []
    vimLive := []
    for sk, d in dirty {
        pos := InStr(sk, Chr(1))
        sec := SubStr(sk, 1, pos - 1)
        isNewSec := secHad.Has(sec) ? !secHad[sec] : false
        scope := VimCfg_ItemScope(sec, d["key"], d["del"], isNewSec)
        if (scope = "restart") {
            needRestart.Push("[" sec "] " . d["key"])
            continue
        }
        if (!IsObject(CfgFind(sec, d["key"])) && !d["del"]) {
            vimLive.Push(Map("sec", sec, "key", d["key"], "val", d["val"]))
            continue
        }
        if (!d["del"])
            changes.Push(Map("sec", sec, "key", d["key"], "val", d["val"]))
    }
    ; vim 增改运行时 MapKey (与启动同一条路; 失败转重启单)
    if (vimLive.Length > 0 && IsSet(g_VimEngine) && IsObject(g_VimEngine)) {
        for item in vimLive {
            ok := false
            try {
                ok := VimCfg_ApplyVimKey(item["sec"], item["key"], item["val"])
            } catch {
                ok := false
            }
            if (!ok)
                needRestart.Push("[" item["sec"] "] " . item["key"])
        }
    } else {
        for item in vimLive
            needRestart.Push("[" item["sec"] "] " . item["key"])
    }
    pub := CfgPublish(changes)
    if (!pub["ok"]) {
        ; 回滚: 备份整盘拷回 + 内存重载 + 旧值重广播
        try FileCopy(backup, path, 1)
        catch {
        }
        try g_Conf.Load(path)
        catch {
        }
        back := []
        for step in undo
            back.Push(Map("sec", step["sec"], "key", step["key"], "val", step["val"]))
        try CfgPublish(back)
        catch {
        }
        try g_VimCfg["undo"].Pop()
        catch {
        }
        first := ""
        try first := pub["failed"][1]["sec"] . "/" . pub["failed"][1]["key"] . ": " . pub["failed"][1]["msg"]
        VimCfg_LogHistory(dirty, undo, "ROLLEDBACK", [], first)
        MsgBox(T("cfg.rolled_back", first), T("cfg.title"), 16)
        return
    }
    g_VimCfg["dirty"] := Map()
    if (g_VimCfg.Has("specErr"))
        g_VimCfg["specErr"] := Map()
    VimCfg_RefreshWarnBar()
    VimCfg_LogHistory(dirty, undo, "APPLIED", needRestart)
    if (newLang != "") {
        ; 语言切换: 托盘已由订阅重建, 问是否重启使全部界面生效 (保留旧行为)
        try {
            if (MsgBox(T("cfg.lang_restart_prompt"), T("cfg.lang_restart_title"), "YesNo") = "Yes") {
                VimCfg_MarkReopen()
                RestartRim()
                return
            }
        } catch {
        }
    }
    if (needRestart.Length > 0) {
        VimCfg_MarkReopen()
        if (MsgBox(T("cfg.need_restart", needRestart.Length) "`n" . VimCfg_JoinLines(needRestart, 8), T("cfg.title"), "YesNo") = "Yes") {
            RestartRim()
            return
        }
        ToolTip(T("cfg.need_restart", needRestart.Length))
        SetTimer(RemoveToolTip, -2000)
        return
    }
    ; 全热: 压住 watcher 的重启 (自写 8s 内免重启, 见 WatchUserFileList)
    g_CfgSelfWriteTick := A_TickCount
    applied := dirty.Count
    ToolTip(T("cfg.applied_live", applied))
    SetTimer(RemoveToolTip, -1500)
}

; vim 增改运行时生效: 解析 [=mode] 后缀, 与 VimdCheckHotKey 同语义 MapKey
VimCfg_ApplyVimKey(wname, key, raw) {
    global g_VimEngine
    mode := "normal"
    act := raw
    if RegExMatch(raw, "^(.*)\[=(.+)\]$", &mm) {
        act := mm[1]
        mode := mm[2]
    }
    if (!g_VimEngine.IsValidAction(act))
        return false
    win := g_VimEngine.GetWin(wname)
    if (!IsObject(win))
        return false
    try {
        g_VimEngine.SetMode(mode, wname)
        g_VimEngine.MapKey(key, act, wname, mode)
    } catch {
        return false
    }
    return true
}

VimCfg_MarkReopen() {
    global g_AutoConf
    try {
        if (IsObject(g_AutoConf)) {
            try g_AutoConf.Set("UI", "ReopenConfig", "1")
            catch {
            }
            try g_AutoConf.Save()
            catch {
            }
        }
    } catch {
    }
}

; ==================== 备份与撤销 ====================
VimCfg_BackupIni(path) {
    stamp := FormatTime(, "yyyyMMddHHmmss")
    dir := A_ScriptDir "\Conf\backup"
    try DirCreate(dir)
    catch {
    }
    backup := dir . "\rim_" . stamp . ".ini"
    try FileCopy(path, backup)
    catch {
    }
    ; 滚动保留 5 份
    try {
        files := []
        Loop Files, dir . "\rim_*.ini" {
            files.Push(A_LoopFileFullPath)
        }
        while (files.Length > 5) {
            FileDelete(files[1])
            files.RemoveAt(1)
        }
    } catch {
    }
    return backup
}

VimCfg_UndoLast(*) {
    global g_VimCfg, g_Conf
    if (!g_VimCfg.Has("undo") || g_VimCfg["undo"].Length = 0) {
        ToolTip(T("cfg.undo_empty"))
        SetTimer(RemoveToolTip, -1200)
        return
    }
    undo := g_VimCfg["undo"].Pop()
    if (g_VimCfg.Has("dirty") && g_VimCfg["dirty"].Count > 0) {
        ToolTip(T("cfg.unsaved_n", g_VimCfg["dirty"].Count))
        SetTimer(RemoveToolTip, -1500)
        return
    }
    dirty := Map()
    for step in undo {
        sk := step["sec"] . Chr(1) . step["key"]
        if (step["had"])
            dirty[sk] := Map("key", step["key"], "val", step["val"], "del", false)
        else
            dirty[sk] := Map("key", step["key"], "val", "", "del", true)
    }
    for sk, d in dirty
        g_VimCfg["dirty"][sk] := d
    VimCfg_RefreshWarnBar()
    VimCfg_PreviewSave(dirty)
}

; ==================== 配置集 (Conf/profiles 整盘快照: 存/应用/删) ====================
; 应用走备份恢复同路 (整盘拷回 + 重启), 不经过 dirty 管线
VimCfg_ProfileDir() {
    dir := A_ScriptDir "\Conf\profiles"
    try DirCreate(dir)
    catch {
    }
    return dir
}

VimCfg_ProfileShow(*) {
    global g_VimCfg
    if (g_VimCfg.Has("profGui")) {
        try g_VimCfg["profGui"].Destroy()
        catch {
        }
    }
    pg := Gui("+Owner" g_VimCfg["gui"].Hwnd, T("cfg.profile_title"))
    pg.SetFont("s10", "Microsoft YaHei")
    lb := pg.Add("ListBox", "x10 y10 w300 R8", [])
    pg.Add("Text", "x10 y190 w60", T("cfg.profile_name"))
    ed := pg.Add("Edit", "x75 y187 w235 h25")
    pg.Add("Button", "x10 y220 w95", T("cfg.profile_save")).OnEvent("Click", VimCfg_ProfileSave)
    pg.Add("Button", "x112 y220 w95", T("cfg.profile_apply")).OnEvent("Click", VimCfg_ProfileApply)
    pg.Add("Button", "x215 y220 w95", T("cfg.profile_delete")).OnEvent("Click", VimCfg_ProfileDel)
    g_VimCfg["profGui"] := pg
    g_VimCfg["profLb"] := lb
    g_VimCfg["profEd"] := ed
    VimCfg_ProfileReload()
    pg.Show("w320 h260")
}

VimCfg_ProfileReload() {
    global g_VimCfg
    if (!g_VimCfg.Has("profLb"))
        return
    lb := g_VimCfg["profLb"]
    try lb.Delete()
    try {
        Loop Files, VimCfg_ProfileDir() . "\*.ini" {
            SplitPath(A_LoopFileName, , , , &stem)
            if (stem != "")
                lb.Add([stem])
        }
    }
}

VimCfg_ProfileName() {
    global g_VimCfg
    name := ""
    try name := Trim(g_VimCfg["profLb"].Text)
    if (name = "") {
        try name := Trim(g_VimCfg["profEd"].Value)
    }
    name := RegExReplace(name, '[\\/:*?"<>|]', "")
    return Trim(name)
}

VimCfg_ProfileSave(*) {
    name := VimCfg_ProfileName()
    if (name = "")
        return
    try FileCopy(A_ScriptDir "\Conf\rim.ini", VimCfg_ProfileDir() . "\" . name . ".ini", 1)
    catch as e {
        MsgBox(T("cfg.save_failed", e.Message), T("cfg.title"), 16)
        return
    }
    VimCfg_ProfileReload()
    ToolTip(T("cfg.profile_saved", name))
    SetTimer(RemoveToolTip, -1500)
}

VimCfg_ProfileApply(*) {
    name := VimCfg_ProfileName()
    if (name = "")
        return
    src := VimCfg_ProfileDir() . "\" . name . ".ini"
    if (!FileExist(src))
        return
    if (MsgBox(name, T("cfg.profile_apply"), "YesNo") != "Yes")
        return
    try FileCopy(src, A_ScriptDir "\Conf\rim.ini", 1)
    catch as e {
        MsgBox(T("cfg.save_failed", e.Message), T("cfg.title"), 16)
        return
    }
    VimCfg_MarkReopen()
    MsgBox(T("cfg.profile_done"), T("cfg.title"))
    RestartRim()
}

VimCfg_ProfileDel(*) {
    global g_VimCfg
    name := VimCfg_ProfileName()
    if (name = "")
        return
    target := VimCfg_ProfileDir() . "\" . name . ".ini"
    if (!FileExist(target))
        return
    if (MsgBox(name, T("cfg.profile_delete"), "YesNo") != "Yes")
        return
    try FileDelete(target)
    VimCfg_ProfileReload()
}

