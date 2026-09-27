#Requires AutoHotkey v2.0
#Warn All, Off
; 别名回归探针: 插件注册名进池被丢 → ghost/冻结/精确命中全对 content (整串 URL),
; "Goo" Tab 不出 "Google". 修法: g_CommandAlias[content]=name, core 优先别名.

T(key, *) => key

global g_CommandAlias := Map()
g_CommandAlias[Trim("https://www.google.com/search?q={query}")] := "Google"

CmdAliasOf(content) {
    global g_CommandAlias
    key := Trim(String(content))
    if (g_CommandAlias.Has(key))
        return g_CommandAlias[key]
    return ""
}

#Include ..\Core\SmartInputPure.ahk

fails := []
Check(name, cond) {
    global fails
    if (!cond)
        fails.Push(name)
}

Main() {
    global fails
    googleLine := "url | https://www.google.com/search?q={query} | 谷歌搜索"
    Check("alias-fn", CmdAliasOf("https://www.google.com/search?q={query}") = "Google")
    Check("core-is-name", SI_CoreOfPure(googleLine) = "Google")
    Check("ghost-goo", SI_MatchPrefixPure("Goo", ["Google", "https://www.google.com/search?q={query}"]) = "Google")
    Check("exact-google", SI_IsExactHit(googleLine, "google"))
    Check("exact-goo-no", !SI_IsExactHit(googleLine, "goo"))
    ; 无别名回落 content (file/未知行不受影响)
    Check("fallback-content", SI_CoreOfPure("url | https://example.com/x | 例子") = "https://example.com/x")
    Check("function-core", SI_CoreOfPure("function | AhkRun | 运行") = "AhkRun")
    ; 真接线静态断言
    cmdSrc := FileRead(A_ScriptDir . "\..\Core\Command.ahk", "UTF-8")
    Check("wire-record", InStr(cmdSrc, "g_CommandAlias[key] := Trim(name)") > 0)
    rimSrc := FileRead(A_ScriptDir . "\..\Rim.ahk", "UTF-8")
    Check("wire-init", InStr(rimSrc, "global g_CommandAlias := Map()") > 0)
    pureSrc := FileRead(A_ScriptDir . "\..\Core\SmartInputPure.ahk", "UTF-8")
    Check("wire-core", InStr(pureSrc, "CmdAliasOf(parts[2])") > 0)
    searchSrc := FileRead(A_ScriptDir . "\..\Core\Search.ahk", "UTF-8")
    Check("wire-search", InStr(searchSrc, "CmdAliasOf(splitedElement[2])") > 0)
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
