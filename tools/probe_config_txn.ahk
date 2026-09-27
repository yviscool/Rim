#Requires AutoHotkey v2.0
#Warn All, Off
; P1-4: 配置事务探针 (CfgSet 校验拒收 + CfgPublish old/scope/source + 临时文件事务)

T(key, params*) {
    return key
}
RimLog(level, msg, err := "") {
    return
}

class FakeIni {
    data := Map()
    __New() {
        this.data := Map()
    }
    Get(sec, key, def := "") {
        if (this.data.Has(sec) && this.data[sec].Has(key))
            return this.data[sec][key]
        return def
    }
    Set(sec, key, val) {
        if (!this.data.Has(sec))
            this.data[sec] := Map()
        this.data[sec][key] := val
    }
    HasSection(sec) {
        return this.data.Has(sec)
    }
    Load(path) {
        return
    }
}

global g_Conf := FakeIni()
global g_CfgSchema := [
    Map("sec", "Config", "key", "HistorySize", "type", "int", "min", 1, "max", 500, "default", "100", "scope", "live"),
    Map("sec", "Config", "key", "SaveHistory", "type", "bool", "default", "1", "scope", "live"),
]

global g_ProbeCalls := 0

#Include ..\Core\ConfigSchema.ahk
#Include ..\Core\ConfigTxn.ahk

ProbeBoom(val, sec, key, old := "", scope := "", source := "") {
    global g_ProbeCalls
    g_ProbeCalls++
    throw Error("handler-boom")
}

fails := []
Check(name, cond) {
    global fails
    if (!cond)
        fails.Push(name)
}

gotEvt := ""
Main() {
    global fails, gotEvt, g_Conf, g_ProbeCalls
    g_Conf.Set("Config", "HistorySize", "100")
    r := CfgSet("Config", "HistorySize", "200", "probe")
    Check("cfgset-ok", r["ok"])
    Check("cfgset-mem", g_Conf.Get("Config", "HistorySize", "") = "200")
    bad := CfgSet("Config", "HistorySize", "99999", "probe")
    Check("cfgset-reject", !bad["ok"])
    Check("cfgset-no-clobber", g_Conf.Get("Config", "HistorySize", "") = "200")
    bad2 := CfgSet("Config", "SaveHistory", "2", "probe")
    Check("bool-reject", !bad2["ok"])
    gotEvt := ""
    CfgSubscribe("Config", "HistorySize", (val, sec, key, old := "", scope := "", source := "") => (gotEvt := val . "|" . old . "|" . scope . "|" . source))
    r2 := CfgSet("Config", "HistorySize", "150", "probe-src")
    Check("publish-extended", gotEvt = "150|200|live|probe-src")
    ; 老 3 参回调仍兼容
    gotOld := ""
    CfgSubscribe("Config", "SaveHistory", (val, sec, key) => (gotOld := val . "|" . sec . "." . key))
    r3 := CfgSet("Config", "SaveHistory", "0", "probe")
    Check("publish-compat3", r3["ok"] && gotOld = "0|Config.SaveHistory")
    r4 := CfgSet("Config", "SaveHistory", "1", "probe")
    ; 抛错 handler: 只记失败, 不换参重试 (counter 必须恰为 1, 内存回滚)
    CfgSubscribe("Config", "SaveHistory", ProbeBoom)
    r5 := CfgSet("Config", "SaveHistory", "0", "probe")
    Check("publish-fail-once", !r5["ok"] && g_ProbeCalls = 1)
    Check("publish-rollback", g_Conf.Get("Config", "SaveHistory", "") = "1")
    setMap := Map("Config", Map("HistorySize", "120"))
    tmp := A_ScriptDir . "\..\probe_txn_test.ini"
    try FileDelete(tmp)
    catch {
    }
    try FileDelete(tmp . ".rimtmp")
    catch {
    }
    FileAppend("[Config]`nHistorySize=100`n", tmp, "UTF-8")
    res := CfgTxn_SaveIni(tmp, setMap)
    Check("txn-ok", res["ok"])
    back := FileRead(tmp, "UTF-8")
    Check("txn-replaced", InStr(back, "HistorySize=120") > 0)
    badMap := Map("Config", Map("HistorySize", "99999"))
    res2 := CfgTxn_SaveIni(tmp, badMap)
    Check("txn-validate-block", !res2["ok"] && res2["stage"] = "validate")
    back2 := FileRead(tmp, "UTF-8")
    Check("txn-no-halfwrite", InStr(back2, "HistorySize=120") > 0)
    try FileDelete(tmp)
    catch {
    }
    try FileDelete(tmp . ".bak1")
    catch {
    }
    out := A_ScriptDir . "\..\probe_config_txn.out.txt"
    try FileDelete(out)
    catch {
    }
    if (fails.Length > 0) {
        txt := "config-txn-FAIL:`n"
        for _, x in fails
            txt .= "  - " . x . "`n"
        FileAppend(txt, out, "UTF-8")
        ExitApp(1)
    }
    FileAppend("config-txn-ok`n", out, "UTF-8")
    ExitApp(0)
}

Main()
