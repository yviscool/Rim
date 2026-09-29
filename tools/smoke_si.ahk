#Requires AutoHotkey v2.0
#Warn All, Off

; 常驻冒烟探针: SmartInput 纯函数 (headless 可跑, 不碰 GUI/配置)
; i18n:protocol-file (全文件为含中文 desc 的命令池固件, 断言解析行为, 必须字面一致)
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/smoke_si.ahk
#Include ..\Core\ConfigSchema.ahk
#Include ..\Core\SmartInput.ahk
#Include ..\Core\Command.ahk

global g_SiFail := 0

SI_Check(name, cond) {
    global g_SiFail
    if (cond) {
        FileAppend("PASS: " . name . "`n", "*")
    } else {
        FileAppend("FAIL: " . name . "`n", "*")
        g_SiFail++
    }
}

; ---- 前缀补全 ----
SI_Check("prefix-basic", SI_MatchPrefixPure("git", ["git status", "git log", "ls"]) == "git status")
SI_Check("prefix-case", SI_MatchPrefixPure("GIT", ["ls", "git log"]) == "git log")
SI_Check("prefix-nomatch", SI_MatchPrefixPure("zzz", ["git status"]) == "")
SI_Check("prefix-equal-noghost", SI_MatchPrefixPure("git", ["git"]) == "")
SI_Check("prefix-empty", SI_MatchPrefixPure("", ["git"]) == "")
SI_Check("prefix-firstwin", SI_MatchPrefixPure("q", ["qq", "qqmusic"]) == "qq")

; ---- 子串过滤 ----
SI_Check("substr-order", SI_SubstrPure("doc", ["docker ps", "git status", "docker compose up"]).Length == 2)
got := SI_SubstrPure("doc", ["docker ps", "git status", "docker compose up"])
SI_Check("substr-first", got.Length >= 1 && got[1] == "docker ps")
SI_Check("substr-empty-all", SI_SubstrPure("", ["a", "b"]).Length == 2)
SI_Check("substr-case", SI_SubstrPure("QQ", ["qqmusic", "git"]).Length == 1)
SI_Check("substr-none", SI_SubstrPure("zzz", ["a", "b"]).Length == 0)

; ---- 一词接受 ----
SI_Check("word-next", SI_NextWordPure("git status --short", 3) == "git status")
SI_Check("word-skipspace", SI_NextWordPure("git   status", 3) == "git   status")
SI_Check("word-end", SI_NextWordPure("git", 3) == "git")
SI_Check("word-full", SI_NextWordPure("git status", 10) == "git status")

; ---- 元素取核 (列表行统一 "command | <id>", 裸行取自身) ----
SI_Check("core-command", SI_CoreOfPure("command | ShutdownTimer") == "ShutdownTimer")
SI_Check("core-fileid", SI_CoreOfPure("command | file:D:\soft\QQMusic.exe") == "file:D:\soft\QQMusic.exe")
SI_Check("core-bare", SI_CoreOfPure("ShutdownTimer") == "ShutdownTimer")

; ---- 历史核 (规范记录先拆包, 参数栏永不进核) ----
g_HistoryCommands := [HistPack("command | ShutdownTimer", "30"), "command | ShowIp"]
SI_Check("histcores-unpack", SI_HistoryCores()[1] == "ShutdownTimer" && SI_HistoryCores()[2] == "ShowIp")
g_HistoryCommands := []

; ---- 隐私 ----
SI_Check("blocked-token", SI_BlockedPure("export token=abc123") == true)
SI_Check("blocked-cn", SI_BlockedPure("我的密码123") == true)
SI_Check("blocked-empty", SI_BlockedPure("") == true)
SI_Check("blocked-ok", SI_BlockedPure("git status") == false)

; ---- 向后删一词 ----
SI_Check("prevword-basic", SI_PrevWordPure("git status", 10) == "git")
SI_Check("prevword-part", SI_PrevWordPure("git sta", 7) == "git")
SI_Check("prevword-only", SI_PrevWordPure("con", 3) == "")
SI_Check("prevword-zero", SI_PrevWordPure("git", 0) == "")
SI_Check("prevword-trailspace", SI_PrevWordPure("git ", 4) == "")

; ---- 精确命中 (行形态为 SearchRow 产物 Map, 手拼即可测) ----
_R1 := Map("name", "ShutdownTimer", "id", "ShutdownTimer", "target", "ShutdownTimer", "desc", "定时关机")
SI_Check("exact-alias", SI_IsExactHitRow(_R1, "shutdowntimer") == true)
SI_Check("exact-case", SI_IsExactHitRow(_R1, "ShutdownTimer") == true)
_R2 := Map("name", "git status", "id", "run:git status", "target", "git status", "desc", "desc")
SI_Check("exact-seg", SI_IsExactHitRow(_R2, "git status") == true)
_R3 := Map("name", "CancelShutdown", "id", "CancelShutdown", "target", "CancelShutdown", "desc", "取消定时关机")
SI_Check("exact-no", SI_IsExactHitRow(_R3, "shutdowntimer") == false)
SI_Check("exact-partial", SI_IsExactHitRow(_R1, "shutdown") == false)
SI_Check("exact-empty", SI_IsExactHitRow(_R1, "") == false)

; ---- 历史输入态还原 (规范记录 HistPack, 含参; 名解析在应用层) ----
SI_Check("histinput-witharg", SI_HistoryInputOfPure(HistPack("command | ShutdownTimer", "30")) == "ShutdownTimer 30")
SI_Check("histinput-command-arg", SI_HistoryInputOfPure(HistPack("command | Calc", "1 + 2")) == "Calc 1 + 2")
SI_Check("histinput-noarg", SI_HistoryInputOfPure("command | CancelShutdown") == "CancelShutdown")
SI_Check("histinput-fileid", SI_HistoryInputOfPure(HistPack("command | file:D:\soft\QQ.exe", "")) == "file:D:\soft\QQ.exe")

; ---- 命令头拆分 (框留整句/搜命令头) ----
SI_Check("head-arg", SI_HeadPure("ShutdownTimer 30") == "ShutdownTimer")
SI_Check("head-multi", SI_HeadPure("a b c") == "a")
SI_Check("head-none", SI_HeadPure("ShutdownTimer") == "ShutdownTimer")
SI_Check("head-empty", SI_HeadPure("") == "")

; ---- ghost 取向 (桩数据: 可见列表优先于会话历史, 头优先; 名经 Registry 解) ----
RimCommand.Register("CancelShutdown", "CancelShutdown", (*) => 0, Map("Description", "取消定时关机"))
RimCommand.Register("ShutdownTimer", "ShutdownTimer", (*) => 0, Map("Description", "定时关机"))
RimCommand.Register("showip", "showip", (*) => 0, Map("Description", "查外网IP"))
g_CurrentCommandList := ["command | CancelShutdown", "command | ShutdownTimer", "command | showip"]
g_HistoryCommands := []
g_SI["inputHist"] := ["showip"]
SI_Check("ghost-visible-family", SI_FindGhost("sh") == "ShutdownTimer")
SI_Check("ghost-head-first", SI_FindGhost("cancel") == "CancelShutdown")
SI_Check("ghost-name-resolve", SI_NameOf("showip") == "showip" && SI_NameOf("ShutdownTimer") == "ShutdownTimer")
g_CurrentCommandList := ["command | CancelShutdown"]
SI_Check("ghost-pool-fallback", SI_FindGhost("shutd") == "ShutdownTimer")

if (g_SiFail > 0) {
    FileAppend("smoke-si FAIL: " . g_SiFail . "`n", "*")
    ExitApp(1)
}
FileAppend("smoke-si-ok`n", "*")
ExitApp(0)
