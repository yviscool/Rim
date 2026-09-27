#Requires AutoHotkey v2.0
#Warn All, Off
; 回退 "=" 探针: URL 查询串 (?q=/ ?wd=) 会被 EasyIni 按首 "=" 切成 key/value,
; 旧 "key | value" 回拼把 "=" 换成 "|" 烂行 (描述列变 {query}, 执行丢参数).
; 修法: Files.ahk FallbackJoin, "=" 拼回是裸行文法才认.

T(key, *) => key

#Include ..\Core\Files.ahk

fails := []
Check(name, cond) {
    global fails
    if (!cond)
        fails.Push(name)
}

; 模拟 EasyIni 首 "=" 切分
SplitIni(line) {
    if RegExMatch(line, "^([^=]+)=(.*)", &m)
        return [Trim(m[1]), Trim(m[2])]
    return [line, ""]
}

Main() {
    global fails
    baidu := "url | https://www.baidu.com/s?wd={query} | 使用 百度 搜索剪切板或输入内容"
    google := "url | https://www.google.com/search?q={query} | 使用 谷歌 搜索剪切板或输入内容"
    bing := "url | https://www.bing.com/search?q={query} | 使用 必应 搜索剪切板或输入内容"
    for _, raw in [baidu, google, bing] {
        sp := SplitIni(raw)
        Check("eq-roundtrip", FallbackJoin(sp[1], sp[2]) = raw)
    }
    Check("eq-query-kept", InStr(FallbackJoin(SplitIni(google)[1], SplitIni(google)[2]), "?q={query}") > 0)
    Check("bare-naked", FallbackJoin("function | AhkRun | 运行", "") = "function | AhkRun | 运行")
    Check("legacy-kv", FallbackJoin("foo", "bar") = "foo | bar")
    ; 真文件端到端: 用 EasyIni 读 ini 再拼, 必须原行
    Check("ini-has-url", InStr(FileRead(A_ScriptDir . "\..\Conf\rim.ini", "UTF-8"), "s?wd={query}") > 0)
    out := A_ScriptDir . "\..\probe_fallback_eq.out.txt"
    try FileDelete(out)
    catch {
    }
    if (fails.Length > 0) {
        txt := "fallback-eq-FAIL:`n"
        for _, x in fails
            txt .= "  - " . x . "`n"
        FileAppend(txt, out, "UTF-8")
        ExitApp(1)
    }
    FileAppend("fallback-eq-ok`n", out, "UTF-8")
    ExitApp(0)
}

Main()
