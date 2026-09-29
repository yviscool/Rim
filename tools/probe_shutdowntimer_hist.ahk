#Requires AutoHotkey v2.0
#Warn All, Off

; 回归探针: 历史规范记录 (HistPack/HistSplit, 参数边界与类型无关)
; 锁死: shutdowntimer 30 重启后 Tab/Alt+Up 丢参; 历史回放执行丢参; Rank 分流
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_shutdowntimer_hist.ahk
#Include ..\Core\SmartInput.ahk
#Include ..\Core\Command.ahk
#Include ..\Core\Files.ahk
#Include ..\Lib\EasyIni.ahk

RimCommand.Register("ShutdownTimer", "ShutdownTimer", (*) => 0, Map("Description", "定时关机"))
RimCommand.Register("Calc", "Calc", (*) => 0, Map("Description", "计算器"))
RimCommand.Register("ShowIp", "ShowIp", (*) => 0, Map("Description", "本机IP"))
RimCommand.Register("CancelShutdown", "CancelShutdown", (*) => 0, Map("Description", "取消定时关机"))

global g_ProbeFail := 0

ProbeCheck(name, cond, extra := "") {
    global g_ProbeFail
    if (cond) {
        FileAppend("PASS: " . name . "`n", "*")
    } else {
        msg := "FAIL: " . name
        if (extra != "")
            msg .= " | got=[" . extra . "]"
        FileAppend(msg . "`n", "*")
        g_ProbeFail++
    }
}

JoinArr(arr, sep) {
    out := ""
    for _, v in arr {
        if (out == "")
            out := v
        else
            out .= sep . v
    }
    return out
}

; ---- 1. 打包/拆包往返 (全类型一致, 无白名单) ----
ProbeCheck("pack-command", HistSplit(HistPack("command | ShutdownTimer | 定时关机", "30"))["arg"] == "30")
ProbeCheck("pack-el-kept", HistSplit(HistPack("command | ShutdownTimer | 定时关机", "30"))["el"] == "command | ShutdownTimer | 定时关机")
ProbeCheck("pack-noarg", HistSplit(HistPack("command | ShowIp | 本机IP", ""))["has"] == false)
ProbeCheck("pack-future-kind", HistSplit(HistPack("combo | zoom | 缩放", "in"))["arg"] == "in")
ProbeCheck("pack-sep-scrub", HistSplit(HistPack("a" . Chr(1) . "b", "c"))["el"] == "ab")

; ---- 2. 含参还原 (重启后 Alt+Up/Tab 的唯一来源) ----
ProbeCheck("histinput-command-arg", SI_HistoryInputOfPure(HistPack("command | ShutdownTimer | 定时关机", "30")) == "ShutdownTimer 30", SI_HistoryInputOfPure(HistPack("command | ShutdownTimer | 定时关机", "30")))
ProbeCheck("histinput-command-calc", SI_HistoryInputOfPure(HistPack("command | Calc | 计算器", "1 + 2")) == "Calc 1 + 2")
ProbeCheck("histinput-function", SI_HistoryInputOfPure(HistPack("function | ShutdownTimer | 定时关机", "30")) == "ShutdownTimer 30")
ProbeCheck("histinput-noarg", SI_HistoryInputOfPure("command | ShowIp | 本机IP") == "ShowIp")
ProbeCheck("histinput-key4", SI_HistoryInputOfPure(HistPack("command | qq", "123")) == "qq 123")

; ---- 3. Rank 归一 (参数永不进 key, 全类型一致) ----
ProbeCheck("rankkey-command-strip", RankKeyOfElement(HistPack("command | ShutdownTimer | 定时关机", "30")) == "command | ShutdownTimer | 定时关机", RankKeyOfElement(HistPack("command | ShutdownTimer | 定时关机", "30")))
ProbeCheck("rankkey-function-strip", RankKeyOfElement(HistPack("function | ShutdownTimer | 定时关机", "30")) == "function | ShutdownTimer | 定时关机")
ProbeCheck("rankkey-noarg-passthrough", RankKeyOfElement("command | ShowIp | 本机IP") == "command | ShowIp | 本机IP")

; ---- 4. EasyIni 落盘往返 (分隔符必须透传, 否则重启即丢参) ----
tmp := A_ScriptDir . "\..\probe_hist_test.ini"
try FileDelete(tmp)
catch {
}
ini := EasyIni()
ini.Set("History", "1", HistPack("command | ShutdownTimer | 定时关机", "30"))
ini.Set("History", "2", "command | ShowIp | 本机IP")
ini.Save(tmp)
back := EasyIni(tmp)
ProbeCheck("easyini-hist-arg", SI_HistoryInputOfPure(back.Get("History", "1", "")) == "ShutdownTimer 30", back.Get("History", "1", ""))
ProbeCheck("easyini-hist-bare", SI_HistoryInputOfPure(back.Get("History", "2", "")) == "ShowIp")
try FileDelete(tmp)
catch {
}

; ---- 5. 端到端: 重启前后 Alt+Up 候选池 (列表行统一 command|<id>, 名经 Registry 解) ----
; 文件行走生产路径 IngestRow (直注 Register 只用于 command-kind 注册)
RimCommand.IngestRow("file | D:\soft\QQ.exe | 音乐")
global g_HistoryCommands := [HistPack("command | ShutdownTimer", "30"), HistPack("command | Calc", "1 + 2"), "command | ShowIp", HistPack("command | file:D:\soft\QQ.exe", "")]
global g_CurrentCommandList := ["command | ShutdownTimer", "command | CancelShutdown"]

; 重启态: 会话 inputHist 清空, 只能靠落盘历史
g_SI["inputHist"] := []
FileAppend("INFO: HistoryInputs after restart = [" . JoinArr(SI_HistoryInputs(), ";") . "]`n", "*")
mAfter := SI_SubstrMatches("ShutdownTimer")
foundAfter := false
for _, c in mAfter {
    if (c == "ShutdownTimer 30") {
        foundAfter := true
        break
    }
}
ProbeCheck("e2e-after-restart-has-arg", foundAfter, JoinArr(mAfter, ";"))

; 文件历史核必须是名 (QQ) 而非 id, 否则 Alt+Up 往框里填路径垃圾
coresAfter := SI_HistoryCores()
hasQQ := false
hasRawId := false
for _, c in coresAfter {
    if (c == "QQ")
        hasQQ := true
    if (c == "file:D:\soft\QQ.exe")
        hasRawId := true
}
ProbeCheck("e2e-histcores-name", hasQQ && !hasRawId, JoinArr(coresAfter, ";"))

; Tab ghost 在重启态
gh := SI_FindGhost("shut")
FileAppend("INFO: ghost(shut) after restart = [" . gh . "]`n", "*")

if (g_ProbeFail > 0) {
    FileAppend("probe-shutdowntimer-hist FAIL: " . g_ProbeFail . "`n", "*")
    ExitApp(1)
}
FileAppend("probe-shutdowntimer-hist-ok`n", "*")
ExitApp(0)
