#Requires AutoHotkey v2.0
#Warn All, Off
; EasyIni "=" 探针: Rank 键是整行命令 (URL ?q=/ ?wd= 必含 "="),
; 旧 Save→Load 回合键被截断 (rank 丢失/误入排除表). 修法: 键内 "=" 转义 "\=".

#Include ..\Lib\EasyIni.ahk

fails := []
Check(name, cond) {
    global fails
    if (!cond)
        fails.Push(name)
}

Main() {
    global fails
    tmp := A_ScriptDir . "\..\probe_eq_test.ini"
    try FileDelete(tmp)
    catch {
    }
    ini := EasyIni()
    ini.Set("Rank", "url | https://www.google.com/search?q={query} | Google搜索", "3|20260927")
    ini.Set("Rank", "url | https://www.baidu.com/s?wd={query} | B站搜索", "1")
    ini.Set("Rank", "file | D:\software\app\a=b.txt", "2|20260927")
    ini.Set("Rank", "command | Calc | 计算器", "5")
    ini.Set("History", "1", "function | AhkRun | x | a=b=c")
    ini.Save(tmp)
    raw := FileRead(tmp, "UTF-8")
    Check("save-escapes", InStr(raw, "?q\={query}") > 0 && InStr(raw, "?wd\={query}") > 0)
    back := EasyIni(tmp)
    Check("rt-google", back.Get("Rank", "url | https://www.google.com/search?q={query} | Google搜索", "") = "3|20260927")
    Check("rt-baidu", back.Get("Rank", "url | https://www.baidu.com/s?wd={query} | B站搜索", "") = "1")
    Check("rt-eqfile", back.Get("Rank", "file | D:\software\app\a=b.txt", "") = "2|20260927")
    Check("rt-plain", back.Get("Rank", "command | Calc | 计算器", "") = "5")
    Check("rt-value-eq", back.Get("History", "1", "") = "function | AhkRun | x | a=b=c")
    ; 原子落盘: 无残留 tmp, 内容一次到位
    Check("atomic-no-tmp", !FileExist(tmp . ".easytmp"))
    ; 老文件 (无转义) 照旧读: 首 "=" 切分 (2026-09-30 教训: 删测试不删容忍, 读侧单正则天然兼容)
    old := "[Rank]`nurl | https://x.y/?q={query} | 旧=2`nfoo=bar`n"
    FileAppend(old, tmp, "UTF-8")
    back2 := EasyIni(tmp)
    Check("old-compat", back2.Get("Rank", "foo", "") = "bar")
    ; 无转义 URL 行按首 "=" 切 (旧行为, 与转义新文件并存同一正则)
    Check("old-compat-eq", back2.Get("Rank", "url | https://x.y/?q", "") = "{query} | 旧=2")
    try FileDelete(tmp)
    catch {
    }
    out := A_ScriptDir . "\..\probe_easyini_eq.out.txt"
    try FileDelete(out)
    catch {
    }
    if (fails.Length > 0) {
        txt := "easyini-eq-FAIL:`n"
        for _, x in fails
            txt .= "  - " . x . "`n"
        FileAppend(txt, out, "UTF-8")
        ExitApp(1)
    }
    FileAppend("easyini-eq-ok`n", out, "UTF-8")
    ExitApp(0)
}

Main()
