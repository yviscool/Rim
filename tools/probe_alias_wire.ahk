#Requires AutoHotkey v2.0
#Warn All, Off
; 别名落表探针: 真 LauncherCompat.AddCommand 必须记 g_CommandAlias[content]=name,
; 同 content 首胜不覆盖 (防后注册顶掉 ghost); 收编进 Registry 不分叉.

T(key, *) => key
global g_CommandAlias := Map()

#Include ..\Core\Command.ahk

Main() {
    n0 := RimCommand.Registry.Count
    LauncherCompat.AddCommand("Google", "url", "https://www.google.com/search?q={query}", "谷歌搜索")
    LauncherCompat.AddCommand("Google2", "url", "https://www.google.com/search?q={query}", "重复内容首胜")
    ok := CmdAliasOf("https://www.google.com/search?q={query}") = "Google"
    ok := ok && RimCommand.Registry.Count = n0 + 1
    row := RimCommand.SearchRow(RimCommand.Get("url:https://www.google.com/search?q={query}"))
    ok := ok && InStr(row["search"], "Google") > 0
    out := A_ScriptDir . "\..\probe_alias_wire.out.txt"
    try FileDelete(out)
    catch {
    }
    if (!ok) {
        FileAppend("alias-wire-FAIL`n", out, "UTF-8")
        ExitApp(1)
    }
    FileAppend("alias-wire-ok`n", out, "UTF-8")
    ExitApp(0)
}

Main()
