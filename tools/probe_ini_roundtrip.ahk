#Requires AutoHotkey v2.0
#Warn All, Off
; ini round-trip 门: EasyIni Save→Load 必须语义无损, 重点覆盖分隔符杀手:
;   裸行 (FallbackCommand, 含 = | # ; CJK)、URL Rank 键 (?q=/ ?wd=)、History 数值键、
;   [Commands] k=v、引号值、空值、UNC 路径. 另锁 shipped 数据: 两 ini 的回退裸行
;   经 EasyIni 切分 + FallbackJoin 必须原行 (防 "=变|" 重演).

#Include ..\Lib\EasyIni.ahk
#Include ..\Core\Files.ahk

fails := []
Check(name, cond) {
    global fails
    if (!cond)
        fails.Push(name)
}

SplitIni(line) {
    if RegExMatch(line, "^((?:\\=|[^=])*)=(.*)", &m)
        return [Trim(StrReplace(m[1], "\=", "=")), Trim(m[2])]
    return [line, ""]
}

Main() {
    global fails
    tmp := A_ScriptDir . "\..\probe_rt_test.ini"
    try FileDelete(tmp)
    catch {
    }
    ini := EasyIni()
    ini.Set("FallbackCommand", "url | https://www.google.com/search?q={query} | 使用 谷歌 #搜索;剪切板", "")
    ini.Set("FallbackCommand", "function | AhkRun | 运行", "")
    ini.Set("Rank", "url | https://www.baidu.com/s?wd={query} | B站搜索", "1")
    ini.Set("Rank", "file | \\srv\share\a=b.txt", "2|20260927")
    ini.Set("History", "1", "function | AhkRun | x | a=b#c;d")
    ini.Set("Commands", "Goo", "url|https://x.y/?q={query}|desc")
    ini.Set("Gestures", "D_L_D", "function|GestureEngine.IgnoreNext")
    ini.Set("Q", "quoted", '"  padded  "')
    ini.Set("Q", "empty", "")
    ini.Save(tmp)
    back := EasyIni(tmp)
    Check("rt-fb-url", back.Get("FallbackCommand", "url | https://www.google.com/search?q={query} | 使用 谷歌 #搜索;剪切板", "MISS") = "")
    Check("rt-fb-fn", back.HasKey("FallbackCommand", "function | AhkRun | 运行"))
    Check("rt-rank-url", back.Get("Rank", "url | https://www.baidu.com/s?wd={query} | B站搜索", "") = "1")
    Check("rt-unc-eq", back.Get("Rank", "file | \\srv\share\a=b.txt", "") = "2|20260927")
    Check("rt-hist", back.Get("History", "1", "") = "function | AhkRun | x | a=b#c;d")
    Check("rt-cmd", back.Get("Commands", "Goo", "") = "url|https://x.y/?q={query}|desc")
    Check("rt-gesture", back.Get("Gestures", "D_L_D", "") = "function|GestureEngine.IgnoreNext")
    Check("rt-quoted", back.Get("Q", "quoted", "") = "  padded  ")
    Check("rt-empty", back.HasKey("Q", "empty") && back.Get("Q", "empty", "X") = "")
    ; 二次 Save→Load 幂等 (转义不叠加: \= 不变 \\=)
    back.Save(tmp)
    back2 := EasyIni(tmp)
    Check("rt-idem", back2.Get("Rank", "url | https://www.baidu.com/s?wd={query} | B站搜索", "") = "1")
    raw := FileRead(tmp, "UTF-8")
    Check("rt-no-double-esc", !InStr(raw, "\\\="))
    ; shipped 数据锁: 两 ini 回退段每行裸行重组原行
    for _, iniName in ["Conf\rim.ini", "Conf\rim.template.ini"] {
        content := FileRead(A_ScriptDir . "\..\" . iniName, "UTF-8")
        inSec := false
        for _, ln in StrSplit(content, "`n") {
            t := Trim(StrReplace(ln, "`r", ""))
            if (t = "")
                continue
            if (SubStr(t, 1, 1) = "[") {
                inSec := (t = "[FallbackCommand]")
                continue
            }
            if (!inSec || SubStr(t, 1, 1) = ";")
                continue
            sp := SplitIni(t)
            if (FallbackJoin(sp[1], sp[2]) != t)
                fails.Push(iniName . " fallback corrupt <" . SubStr(t, 1, 60) . ">")
        }
    }
    try FileDelete(tmp)
    catch {
    }
    out := A_ScriptDir . "\..\probe_ini_roundtrip.out.txt"
    try FileDelete(out)
    catch {
    }
    if (fails.Length > 0) {
        txt := "ini-roundtrip-FAIL:`n"
        for _, x in fails
            txt .= "  - " . x . "`n"
        FileAppend(txt, out, "UTF-8")
        ExitApp(1)
    }
    FileAppend("ini-roundtrip-ok`n", out, "UTF-8")
    ExitApp(0)
}

Main()
