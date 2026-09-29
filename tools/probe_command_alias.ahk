#Requires AutoHotkey v2.0
#Warn All, Off
; 别名回归探针: 插件注册名进池被丢 → ghost/冻结/精确命中全对 content (整串 URL),
; "Goo" Tab 不出 "Google". 修法: g_CommandAlias[content]=name, SearchRow 搜索串补别名,
; ghost 名经 SI_NameOf 解.
; (旧 SI_CoreOfPure 别名分支已随池行退役, 别名唯一落点 = SearchRow + CmdAliasOf.)

T(key, *) => key

global g_CommandAlias := Map()
g_CommandAlias[Trim("https://www.google.com/search?q={query}")] := "Google"

#Include ..\Core\Command.ahk
#Include ..\Core\SmartInputPure.ahk

fails := []
Check(name, cond) {
    global fails
    if (!cond)
        fails.Push(name)
}

Main() {
    global fails
    Check("alias-fn", CmdAliasOf("https://www.google.com/search?q={query}") = "Google")
    id := RimCommand.IngestRow("url | https://www.google.com/search?q={query} | 谷歌搜索")
    row := RimCommand.SearchRow(RimCommand.Get(id))
    Check("searchrow-has-alias", InStr(row["search"], "Google") > 0)
    Check("core-is-id", SI_CoreOfPure("command | " . id) = id)
    Check("ghost-goo", SI_MatchPrefixPure("Goo", ["Google", "https://www.google.com/search?q={query}"]) = "Google")
    Check("exact-google", SI_IsExactHitRow(Map("name", "Google", "id", id, "target", "https://www.google.com/search?q={query}", "desc", "谷歌搜索"), "google"))
    Check("exact-goo-no", !SI_IsExactHitRow(Map("name", "Google", "id", id, "target", "x", "desc", "y"), "goo"))
    ; 无别名回落 content
    Check("fallback-content", SI_CoreOfPure("command | https://example.com/x") = "https://example.com/x")
    ; 真接线静态断言
    cmdSrc := FileRead(A_ScriptDir . "\..\Core\Command.ahk", "UTF-8")
    Check("wire-record", InStr(cmdSrc, "g_CommandAlias[key] := Trim(name)") > 0)
    rimSrc := FileRead(A_ScriptDir . "\..\Rim.ahk", "UTF-8")
    Check("wire-init", InStr(rimSrc, "global g_CommandAlias := Map()") > 0)
    pureSrc := FileRead(A_ScriptDir . "\..\Core\SmartInput.ahk", "UTF-8")
    Check("wire-nameof", InStr(pureSrc, "SI_NameOf") > 0)
    searchSrc := FileRead(A_ScriptDir . "\..\Core\Search.ahk", "UTF-8")
    Check("wire-searchrow", InStr(searchSrc, "RimCommand.SearchRow(cmd") > 0)
    out := A_ScriptDir . "\..\probe_command_alias.out.txt"
    try FileDelete(out)
    catch {
    }
    if (fails.Length > 0) {
        txt := "command-alias-FAIL:`n"
        for _, x in fails
            txt .= "  - " . x . "`n"
        FileAppend(txt, out, "UTF-8")
        ExitApp(1)
    }
    FileAppend("command-alias-ok`n", out, "UTF-8")
    ExitApp(0)
}

Main()
