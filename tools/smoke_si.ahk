#Requires AutoHotkey v2.0
#Warn All, Off

; 常驻冒烟探针: SmartInput 纯函数 (headless 可跑, 不碰 GUI/配置)
; i18n:protocol-file (全文件为含中文 desc 的命令池固件, 断言解析行为, 必须字面一致)
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/smoke_si.ahk
#Include ..\Core\SmartInput.ahk

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

; ---- 元素取核 ----
SI_Check("core-4part", SI_CoreOfPure("qq | file | D:\soft\qq.exe | desc") == "qq")
SI_Check("core-func", SI_CoreOfPure("function | Calc | 计算器") == "Calc")
SI_Check("core-file3", SI_CoreOfPure("file | D:\soft\QQMusic.exe | 音乐") == "QQMusic")
SI_Check("core-file2", SI_CoreOfPure("file | D:\soft\WeChat.exe") == "WeChat")
SI_Check("core-run", SI_CoreOfPure("run | git status | desc") == "git status")
SI_Check("core-histarg", SI_CoreOfPure("function | CancelShutdown | 取消定时关机 | 30m") == "CancelShutdown")
SI_Check("core-histarg2", SI_CoreOfPure("function | ShutdownTimer | 定时关机 shutdown timer | 1h30m") == "ShutdownTimer")

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

; ---- 精确命中 (搜索置顶用) ----
SI_Check("exact-alias", SI_IsExactHit("function | ShutdownTimer | 定时关机 shutdown timer", "shutdowntimer") == true)
SI_Check("exact-case", SI_IsExactHit("function | ShutdownTimer | 定时关机", "ShutdownTimer") == true)
SI_Check("exact-seg", SI_IsExactHit("run | git status | desc", "git status") == true)
SI_Check("exact-no", SI_IsExactHit("function | CancelShutdown | 取消定时关机", "shutdowntimer") == false)
SI_Check("exact-partial", SI_IsExactHit("function | ShutdownTimer | 定时关机", "shutdown") == false)
SI_Check("exact-empty", SI_IsExactHit("function | ShutdownTimer | x", "") == false)

; ---- 历史输入态还原 (含参) ----
SI_Check("histinput-witharg", SI_HistoryInputOfPure("function | ShutdownTimer | 定时关机 shutdown timer | 30") == "ShutdownTimer 30")
SI_Check("histinput-witharg2", SI_HistoryInputOfPure("function | CancelShutdown | 取消定时关机 | 30m") == "CancelShutdown 30m")
SI_Check("histinput-noarg", SI_HistoryInputOfPure("function | CancelShutdown | 取消定时关机") == "CancelShutdown")
SI_Check("histinput-4part", SI_HistoryInputOfPure("qq | file | D:\soft\qq.exe | desc") == "qq")
SI_Check("histinput-4partarg", SI_HistoryInputOfPure("qq | file | D:\soft\qq.exe | desc | 123") == "qq 123")
SI_Check("histinput-file3", SI_HistoryInputOfPure("file | D:\soft\QQ.exe | 音乐") == "QQ")

; ---- 命令头拆分 (框留整句/搜命令头) ----
SI_Check("head-arg", SI_HeadPure("ShutdownTimer 30") == "ShutdownTimer")
SI_Check("head-multi", SI_HeadPure("a b c") == "a")
SI_Check("head-none", SI_HeadPure("ShutdownTimer") == "ShutdownTimer")
SI_Check("head-empty", SI_HeadPure("") == "")

; ---- ghost 取向 (桩数据: 可见列表优先于会话历史, 头优先) ----
g_CurrentCommandList := ["function | CancelShutdown | 取消定时关机", "function | ShutdownTimer | 定时关机 shutdown timer", "function | showip | 查外网IP"]
g_Commands := ["function | CancelShutdown | 取消定时关机", "function | ShutdownTimer | 定时关机 shutdown timer", "function | showip | 查外网IP"]
g_HistoryCommands := []
g_SI["inputHist"] := ["showip"]
SI_Check("ghost-visible-family", SI_FindGhost("sh") == "ShutdownTimer")
SI_Check("ghost-head-first", SI_FindGhost("cancel") == "CancelShutdown")
g_CurrentCommandList := ["function | CancelShutdown | 取消定时关机"]
SI_Check("ghost-pool-fallback", SI_FindGhost("shutd") == "ShutdownTimer")

if (g_SiFail > 0) {
    FileAppend("smoke-si FAIL: " . g_SiFail . "`n", "*")
    ExitApp(1)
}
FileAppend("smoke-si-ok`n", "*")
ExitApp(0)
