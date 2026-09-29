#Requires AutoHotkey v2.0
#Warn All, Off
; === Core/ConfigTxn.ahk - 配置事务 (校验→临时文件→替换→重载→发布) ===
; P1-4: 原子保存管线, 供 VimCfg_DoSave 与 CfgSetTxn 共用
; 流程: ValidateDirty → 写 .tmp → 校验读回 → FileMove 替换 → g_Conf.Load → CfgPublish
; 任一步失败回滚, 绝不产生半保存文件

CfgTxn_SaveIni(path, setMap, validateFn := "") {
    ; 重入守卫: VimCfg_DoSave 手势编辑均为同管线, 并发整盘写直接报 busy, 不留半吊子文件
    global g_CfgTxnActive
    if (IsSet(g_CfgTxnActive) && g_CfgTxnActive)
        return Map("ok", false, "stage", "busy", "msg", "txn already active")
    g_CfgTxnActive := true
    try {
        return CfgTxn_SaveIniBody(path, setMap, validateFn)
    } finally {
        g_CfgTxnActive := false
    }
}

; 值约定: 字符串 = upsert; Map{val, del} = 删键(del=true)或 upsert, 供 VimCfg_DoSave 复用同一 writer
CfgTxn_IsDel(v) {
    return IsObject(v) && v.Has("del") && v["del"]
}

CfgTxn_ValOf(v) {
    if (IsObject(v) && v.Has("val"))
        return String(v["val"])
    return String(v)
}

CfgTxn_SaveIniBody(path, setMap, validateFn := "") {
    backup := ""
    try backup := VimCfg_BackupIni(path)
    catch {
        backup := CfgTxn_Backup(path)
    }
    errs := ""
    if (IsObject(validateFn)) {
        try errs := validateFn(setMap)
        catch as ex {
            errs := ex.Message
        }
    } else {
        errs := CfgTxn_ValidateAll(setMap)
    }
    if (IsObject(errs) && errs.Length > 0) {
        first := ""
        try first := errs[1]
        catch {
            first := "validate failed"
        }
        return Map("ok", false, "stage", "validate", "msg", String(first))
    }
    if (Type(errs) = "String" && errs != "") {
        return Map("ok", false, "stage", "validate", "msg", errs)
    }
    tmp := path . ".rimtmp"
    try {
        CfgTxn_WriteTmp(path, tmp, setMap)
    } catch as ex {
        return Map("ok", false, "stage", "write-tmp", "msg", ex.Message)
    }
    try {
        CfgTxn_VerifyTmp(tmp, setMap)
    } catch as ex {
        try FileDelete(tmp)
        catch {
        }
        return Map("ok", false, "stage", "verify", "msg", ex.Message)
    }
    oldVals := Map()
    try {
        global g_Conf
        for sec, kv in setMap {
            for k, v in kv {
                old := ""
                try old := g_Conf.Get(sec, k, "")
                catch {
                }
                oldVals[sec . Chr(1) . k] := old
            }
        }
    }
    try {
        FileMove(tmp, path, 1)
    } catch as ex {
        try FileDelete(tmp)
        catch {
        }
        return Map("ok", false, "stage", "replace", "msg", ex.Message)
    }
    try {
        global g_Conf
        g_Conf.Load(path)
    } catch as ex {
        if (backup != "" && FileExist(backup)) {
            try FileCopy(backup, path, 1)
            catch {
            }
            try g_Conf.Load(path)
            catch {
            }
        }
        return Map("ok", false, "stage", "reload", "msg", ex.Message)
    }
    changes := []
    for sec, kv in setMap {
        for k, v in kv {
            sk := sec . Chr(1) . k
            old := oldVals.Has(sk) ? oldVals[sk] : ""
            scope := "restart"
            try scope := CfgScope(sec, k)
            ; 删键按 restart 走, 广播空值供订阅方清理
            changes.Push(Map("sec", sec, "key", k, "val", CfgTxn_IsDel(v) ? "" : CfgTxn_ValOf(v), "old", old, "scope", scope, "source", "txn"))
        }
    }
    pubRes := Map("ok", true, "failed", [])
    try pubRes := CfgPublish(changes)
    catch as ex {
        pubRes := Map("ok", false, "failed", [Map("sec", "", "key", "", "msg", ex.Message)])
    }
    if (!pubRes["ok"]) {
        if (backup != "" && FileExist(backup)) {
            try FileCopy(backup, path, 1)
            catch {
            }
            try g_Conf.Load(path)
            catch {
            }
            try CfgPublish(CfgTxn_Invert(changes))
            catch {
            }
        }
        msg := ""
        try msg := pubRes["failed"][1]["msg"]
        catch {
        }
        return Map("ok", false, "stage", "publish", "msg", msg)
    }
    return Map("ok", true, "stage", "done", "msg", "")
}

CfgTxn_ValidateAll(setMap) {
    errs := []
    for sec, kv in setMap {
        for k, v in kv {
            ; 删键不校验 (与 VimCfg_ValidateDirty 同语义)
            if (CfgTxn_IsDel(v))
                continue
            msg := ""
            try msg := CfgValidate(sec, k, CfgTxn_ValOf(v))
            catch {
                msg := ""
            }
            if (msg != "")
                errs.Push(sec . "." . k . ": " . msg)
        }
    }
    return errs
}

CfgTxn_Backup(path) {
    dest := path . ".bak1"
    try {
        if FileExist(path)
            FileCopy(path, dest, 1)
    }
    return dest
}

CfgTxn_WriteTmp(origPath, tmpPath, setMap) {
    content := ""
    try content := FileRead(origPath, "UTF-8")
    catch {
        content := ""
    }
    if (SubStr(content, 1, 1) = Chr(0xFEFF))
        content := SubStr(content, 2)
    lines := []
    if (content != "") {
        Loop Parse, content, "`n", "`r" {
            lines.Push(A_LoopField)
        }
    }
    curSec := ""
    done := Map()
    out := []
    for _, ln in lines {
        t := Trim(ln)
        if (RegExMatch(t, "^\[(.+)\]$", &m)) {
            ; 段尾: 本段新增键追到段末 (与 VimCfg_WriteIni 同语义, 缺了新键会落到错误段尾)
            if (curSec != "" && setMap.Has(curSec)) {
                for k, v in setMap[curSec] {
                    if (CfgTxn_IsDel(v) || done.Has(curSec . Chr(1) . k))
                        continue
                    out.Push(k . "=" . CfgTxn_ValOf(v))
                    done[curSec . Chr(1) . k] := true
                }
            }
            curSec := m[1]
            out.Push(ln)
            continue
        }
        if (curSec != "" && setMap.Has(curSec) && InStr(ln, "=")) {
            pos := InStr(ln, "=")
            k := Trim(SubStr(ln, 1, pos - 1))
            if (setMap[curSec].Has(k)) {
                if (CfgTxn_IsDel(setMap[curSec][k])) {
                    ; 删键: 吞掉该行, 不写回
                    done[curSec . Chr(1) . k] := true
                    continue
                }
                out.Push(k . "=" . CfgTxn_ValOf(setMap[curSec][k]))
                done[curSec . Chr(1) . k] := true
                continue
            }
        }
        out.Push(ln)
    }
    ; 末段 flush
    if (curSec != "" && setMap.Has(curSec)) {
        for k, v in setMap[curSec] {
            if (CfgTxn_IsDel(v) || done.Has(curSec . Chr(1) . k))
                continue
            out.Push(k . "=" . CfgTxn_ValOf(v))
            done[curSec . Chr(1) . k] := true
        }
    }
    ; 全新段追到文件尾
    for sec, kv in setMap {
        if (CfgTxn_HasSection(lines, sec))
            continue
        out.Push("")
        out.Push("[" . sec . "]")
        for k, v in kv {
            if (CfgTxn_IsDel(v) || done.Has(sec . Chr(1) . k))
                continue
            out.Push(k . "=" . CfgTxn_ValOf(v))
            done[sec . Chr(1) . k] := true
        }
    }
    f := FileOpen(tmpPath, "w", "UTF-8")
    for _, ln in out {
        f.WriteLine(ln)
    }
    f.Close()
}

CfgTxn_HasSection(lines, sec) {
    for _, ln in lines {
        if (Trim(ln) = "[" . sec . "]")
            return true
    }
    return false
}

CfgTxn_VerifyTmp(tmpPath, setMap) {
    back := FileRead(tmpPath, "UTF-8")
    if (SubStr(back, 1, 1) = Chr(0xFEFF))
        back := SubStr(back, 2)
    found := Map()
    curSec := ""
    Loop Parse, back, "`n", "`r" {
        ln := A_LoopField
        t := Trim(ln)
        if (RegExMatch(t, "^\[(.+)\]$", &m)) {
            curSec := m[1]
            continue
        }
        if (curSec != "" && setMap.Has(curSec) && InStr(ln, "=")) {
            pos := InStr(ln, "=")
            k := Trim(SubStr(ln, 1, pos - 1))
            v := SubStr(ln, pos + 1)
            ; WriteTmp 写 k=v 无前后空格, 此处按行精确比对, 避免子串误判;
            ; 删键(del)反向断言: 该节内无此键行才算通过
            if (setMap[curSec].Has(k)) {
                want := setMap[curSec][k]
                if (CfgTxn_IsDel(want))
                    found[curSec . Chr(1) . k] := true
                else if (v = CfgTxn_ValOf(want))
                    found[curSec . Chr(1) . k] := true
            }
        }
    }
    for sec, kv in setMap {
        for k, v in kv {
            sk := sec . Chr(1) . k
            if (CfgTxn_IsDel(v)) {
                ; 删键反向断言: 写后该节内残留此键行即失败
                if (found.Has(sk))
                    throw Error("verify miss " . sec . "." . k)
                continue
            }
            if (!found.Has(sk))
                throw Error("verify miss " . sec . "." . k)
        }
    }
}

CfgTxn_Invert(changes) {
    out := []
    for _, ch in changes {
        out.Push(Map("sec", ch["sec"], "key", ch["key"], "val", ch.Has("old") ? ch["old"] : "", "old", ch.Has("val") ? ch["val"] : "", "scope", ch.Has("scope") ? ch["scope"] : "restart", "source", "rollback"))
    }
    return out
}
