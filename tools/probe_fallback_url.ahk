#Requires AutoHotkey v2.0
#Warn All, Off
; 回退搜索命令修复探针: [FallbackCommand] 谷歌/百度/必应必须走 url|{query},
; 不得再引用已删除的 SearchOn* 函数 (ecfb4b3 删 79 别名遗留悬空, EXEC_FAILED 根因)

T(key, *) => key

fails := []
Check(name, cond) {
    global fails
    if (!cond)
        fails.Push(name)
}

Main() {
    global fails
    src := FileRead(A_ScriptDir . "\..\Conf\rim.ini", "UTF-8")
    Check("no-searchon-func", !InStr(src, "function | SearchOnGoogle") && !InStr(src, "function | SearchOnBaidu") && !InStr(src, "function | SearchOnBing"))
    Check("google-url", InStr(src, "url | https://www.google.com/search?q={query}") > 0)
    Check("baidu-url", InStr(src, "url | https://www.baidu.com/s?wd={query}") > 0)
    Check("bing-url", InStr(src, "url | https://www.bing.com/search?q={query}") > 0)
    ; 端到端构造: 模拟 ExecuteAction_Body url| 分支 (Run 除外)
    line := "url | https://www.google.com/search?q={query} | 使用 谷歌 搜索剪切板或输入内容"
    parts := StrSplit(line, " | ")
    action := parts[1] . "|" . parts[2]
    actionArg := "Hud是什么"
    url := SubStr(action, 5)
    if InStr(url, "{query}") {
        q := Trim(actionArg)
        url := StrReplace(url, "{query}", q)
    }
    Check("query-subst", url = "https://www.google.com/search?q=Hud是什么")
    ; 模板 ini 同步
    tpl := FileRead(A_ScriptDir . "\..\Conf\rim.template.ini", "UTF-8")
    Check("tpl-no-searchon", !InStr(tpl, "function | SearchOn"))
    Check("tpl-google-url", InStr(tpl, "url | https://www.google.com/search?q={query}") > 0)
    out := A_ScriptDir . "\..\probe_fallback_url.out.txt"
    try FileDelete(out)
    catch {
    }
    if (fails.Length > 0) {
        txt := "fallback-url-FAIL:`n"
        for _, x in fails
            txt .= "  - " . x . "`n"
        FileAppend(txt, out, "UTF-8")
        ExitApp(1)
    }
    FileAppend("fallback-url-ok`n", out, "UTF-8")
    ExitApp(0)
}

Main()
