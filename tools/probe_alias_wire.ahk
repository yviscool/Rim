#Requires AutoHotkey v2.0
#Warn All, Off
; 别名落表探针: 真 LauncherCompat.AddCommand 必须记 g_CommandAlias[content]=name,
; 同 content 首胜不覆盖 (防后注册顶掉 ghost).

T(key, *) => key
global g_Commands := []
global g_CommandAlias := Map()

#Include ..\Core\Command.ahk

Main() {
    LauncherCompat.AddCommand("Google", "url", "https://www.google.com/search?q={query}", "谷歌搜索")
    LauncherCompat.AddCommand("Google2", "url", "https://www.google.com/search?q={query}", "重复内容首胜")
    ok := CmdAliasOf("https://www.google.com/search?q={query}") = "Google"
    ok := ok && g_Commands.Length = 2
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
