#Requires AutoHotkey v2.0
#Warn All, Off

; Registry 收编契约: IngestRow/SearchRow 与旧池行逐字一致 (C2 切换读侧的前置锁死)
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_registry_ingest.ahk
#Include ..\Core\Command.ahk
#Include ..\Core\SmartInputPure.ahk

global g_Fail := 0
global g_CommandAlias := Map()
g_CommandAlias["https://www.bing.com/search?q={query}"] := "Bing"

Ck(name, cond, extra := "") {
    global g_Fail
    if (cond)
        FileAppend("PASS: " . name . "`n", "*")
    else {
        FileAppend("FAIL: " . name . (extra != "" ? " | got=[" . extra . "]" : "") . "`n", "*")
        g_Fail++
    }
}

RowOf(line, showExt := false, searchFull := false) {
    id := RimCommand.IngestRow(line)
    return RimCommand.SearchRow(RimCommand.Get(id), showExt, searchFull)
}

; ---- 注册行: show 第三段取 label 形 ----
RimCommand.Register("probe.shutdown", "probe.shutdown", (*) => 0, Map("Description", "定时关机"))
r := RimCommand.SearchRow(RimCommand.Get("probe.shutdown"))
Ck("reg-show", r["show"] == "command | probe.shutdown | 定时关机", r["show"])
Ck("reg-search", r["search"] == "probe.shutdown 定时关机", r["search"])
Ck("reg-rankkey", r["rankKey"] == "command | probe.shutdown", r["rankKey"])
Ck("reg-targetkey", r["targetKey"] == "command|probe.shutdown", r["targetKey"])

RimCommand.Register("sys.doc", "Doc", (*) => 0, Map("Description", "诊断"))
r2 := RimCommand.SearchRow(RimCommand.Get("sys.doc"))
Ck("reg-label-show", r2["show"] == "command | sys.doc | Doc - 诊断", r2["show"])

; ---- 四段行: 显示 type|key|desc, 搜索 key+cmd+desc ----
q := RowOf("taskmgr | run | taskmgr.exe | 任务管理器")
Ck("four-show", q["show"] == "run | taskmgr | 任务管理器", q["show"])
Ck("four-search", q["search"] == "taskmgr taskmgr.exe 任务管理器", q["search"])
Ck("four-targetkey", q["targetKey"] == "run|taskmgr.exe", q["targetKey"])
Ck("four-rankkey", q["rankKey"] == "command | taskmgr", q["rankKey"])

; ---- 文件行: 显示无扩展名, 搜索恒无扩展名 ----
f := RowOf("file | D:\soft\Weixin\Weixin.exe")
Ck("file-show", f["show"] == "file | Weixin", f["show"])
Ck("file-search", f["search"] == "Weixin", f["search"])
f2 := RowOf("file | D:\soft\Weixin\Weixin.exe", true)
Ck("file-showext", f2["show"] == "file | Weixin.exe", f2["show"])
Ck("file-search-noext-always", f2["search"] == "Weixin", f2["search"])
f3 := RowOf("file | D:\soft\Tools\Notepad.exe | 笔记", false, true)
Ck("file-searchfull", InStr(f3["search"], "Tools") > 0 && InStr(f3["search"], "Notepad") > 0 && InStr(f3["search"], "笔记") > 0, f3["search"])

; ---- url/run 行 ----
u := RowOf("url | https://www.google.com/search?q={query} | Google搜索")
Ck("url-show", u["show"] == "url | https://www.google.com/search?q={query} | Google搜索", u["show"])
Ck("url-search", u["search"] == "https:  www.google.com search?q={query} Google搜索", u["search"])

; ---- 首注胜: 收编不覆盖直注 ----
RimCommand.Register("keepme", "keepme", (*) => 1, Map("Description", "活的"))
RimCommand.IngestRow("command | keepme | 空壳描述")
Ck("first-wins", RimCommand.Get("keepme").Description == "活的", RimCommand.Get("keepme").Description)

; ---- 幂等 ----
n0 := RimCommand.Registry.Count
RimCommand.IngestRow("taskmgr | run | taskmgr.exe | 任务管理器")
RimCommand.IngestRow("file | D:\soft\Weixin\Weixin.exe")
Ck("idempotent", RimCommand.Registry.Count = n0, String(RimCommand.Registry.Count - n0))

; ---- 状态行 (原版底部输入框 remainder 形, 文件行即完整路径) ----
Ck("status-file", RimCommand.StatusOf("command | file:D:\soft\Weixin\Weixin.exe") == "D:\soft\Weixin\Weixin.exe", RimCommand.StatusOf("command | file:D:\soft\Weixin\Weixin.exe"))
Ck("status-file-desc", RimCommand.StatusOf("command | file:D:\soft\Tools\Notepad.exe") == "D:\soft\Tools\Notepad.exe | 笔记")
Ck("status-four", RimCommand.StatusOf("command | taskmgr") == "run | taskmgr.exe | 任务管理器", RimCommand.StatusOf("command | taskmgr"))
Ck("status-reg", RimCommand.StatusOf("command | probe.shutdown") == "probe.shutdown | 定时关机", RimCommand.StatusOf("command | probe.shutdown"))
Ck("status-legacy", RimCommand.StatusOf("function | AhkRun | 运行") == "AhkRun | 运行", RimCommand.StatusOf("function | AhkRun | 运行"))

; ---- 别名优先进 Name (收编时别名表已就绪; 显示/冻结/精确命中全对名) ----
bingId := RimCommand.IngestRow("url | https://www.bing.com/search?q={query} | 必应搜索")
bingRow := RimCommand.SearchRow(RimCommand.Get(bingId))
Ck("alias-name-first", bingRow["name"] == "Bing", bingRow["name"])
Ck("alias-show-first", bingRow["show"] == "url | Bing | 必应搜索", bingRow["show"])

if (g_Fail > 0) {
    FileAppend("probe-registry-ingest FAIL: " . g_Fail . "`n", "*")
    ExitApp(1)
}
FileAppend("probe-registry-ingest-ok`n", "*")
ExitApp(0)
