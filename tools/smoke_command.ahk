#Requires AutoHotkey v2.0
#Warn All, Off

; 冒烟探针: Command Registry 与通用指令测试
#Include ..\Core\I18n.ahk
#Include ..\Core\Context.ahk
#Include ..\Core\Command.ahk
#Include ..\Core\Execution.ahk

Assert(cond, msg) {
    if (!cond) {
        FileAppend("FAIL: " . msg . "`n", "*")
        ExitApp(1)
    }
    FileAppend("PASS: " . msg . "`n", "*")
}

; 1. 基础注册与获取
executed := false
execArg := ""
testAction(arg := "") {
    global executed, execArg
    executed := true
    execArg := arg
}

cmd := RimCommand.Register("test.echo", "Test Echo", testAction, Map(
    "Category", "Testing",
    "Description", "Echoes test input",
    "Keywords", "echo test probe"
))

Assert(IsObject(cmd), "cmd-registered-obj")
Assert(RimCommand.Get("test.echo") == cmd, "cmd-get-matches")
Assert(cmd.Category == "Testing", "cmd-category")
Assert(cmd.Description == "Echoes test input", "cmd-description")
Assert(RimCommand.Categories.Has("Testing"), "cmd-categories-map")

; 2. 执行机制 (直接 Execute)
executed := false
execArg := ""
RimCommand.Execute("test.echo", "hello-world")
Assert(executed == true, "cmd-executed-direct")
Assert(execArg == "hello-world", "cmd-exec-arg-passed")

; 3. 上下文过滤机制 (ContextFilter)
filterPassRan := false
filterFailRan := false
onPass(*) {
    global filterPassRan
    filterPassRan := true
}
onFail(*) {
    global filterFailRan
    filterFailRan := true
}
filterPass(c := "") => true
filterFail(c := "") => false
RimCommand.Register("test.filter_pass", "Filter Pass", onPass, Map(
    "ContextFilter", filterPass
))
RimCommand.Register("test.filter_fail", "Filter Fail", onFail, Map(
    "ContextFilter", filterFail
))

RimCommand.Execute("test.filter_pass")
Assert(filterPassRan == true, "cmd-filter-pass-ran")
RimCommand.Execute("test.filter_fail")
Assert(filterFailRan == false, "cmd-filter-fail-blocked")

; 4. ExecuteAction 协议联动 ("command|..." 与直接 ID 调用)
executed := false
execArg := ""
ExecuteAction("command|test.echo", "via-protocol")
Assert(executed == true, "cmd-via-executeaction-protocol")
Assert(execArg == "via-protocol", "cmd-via-executeaction-arg")

executed := false
ExecuteAction("test.echo")
Assert(executed == true, "cmd-via-executeaction-direct-id")

; 5. 搜索功能
searchResults := RimCommand.Search("echo")
Assert(searchResults.Length >= 1, "cmd-search-by-name")
Assert(searchResults[1].Id == "test.echo", "cmd-search-matched-id")

kwResults := RimCommand.Search("probe")
Assert(kwResults.Length >= 1, "cmd-search-by-keyword")

; 6. 通用人机指令集初始化
InitUniversalCommands()
Assert(RimCommand.Get("file.copy_path") != "", "universal-file-copy-path")
Assert(RimCommand.Get("file.copy_name") != "", "universal-file-copy-name")
Assert(RimCommand.Get("file.open_dir") != "", "universal-file-open-dir")
Assert(RimCommand.Get("file.open_terminal") != "", "universal-file-open-term")
Assert(RimCommand.Get("file.open_in_tc") != "", "universal-file-open-tc")
Assert(RimCommand.Get("file.open_in_explorer") != "", "universal-file-open-exp")

Assert(RimCommand.Get("window.close") != "", "universal-win-close")
Assert(RimCommand.Get("window.maximize") != "", "universal-win-max")
Assert(RimCommand.Get("window.minimize") != "", "universal-win-min")
Assert(RimCommand.Get("window.toggle_top") != "", "universal-win-top")
Assert(RimCommand.Get("window.center") != "", "universal-win-center")

Assert(RimCommand.Get("system.reload_rim") != "", "universal-sys-reload")
Assert(RimCommand.Get("system.edit_config") != "", "universal-sys-config")
Assert(RimCommand.Get("system.lock") != "", "universal-sys-lock")
Assert(RimCommand.Get("system.sleep") != "", "universal-sys-sleep")

; 7. 命令面板联想搜索
copyMatches := RimCommand.Search("copy")
Assert(copyMatches.Length >= 2, "palette-search-copy-multi")

winMatches := RimCommand.Search("window")
Assert(winMatches.Length >= 5, "palette-search-window-multi")

termMatches := RimCommand.Search("terminal")
Assert(termMatches.Length >= 1, "palette-search-terminal")

FileAppend("smoke-command-ok`n", A_ScriptDir . "\..\smoke_command.out.txt")
ExitApp(0)
