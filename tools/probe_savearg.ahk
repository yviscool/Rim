#Requires AutoHotkey v2.0
#Warn All, Off

; SaveResultAsArg 计算探针: 纯函数矩阵 (空行/短行/空列表/文件行/双模式), Ctrl+Enter 零错框.
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_savearg.ahk
#Include ..\Core\Command.ahk
#Include ..\Core\SmartInputPure.ahk
#Include ..\Core\Hotkeys.Commands.ahk

global g_Fail := 0
Ck(name, cond, extra := "") {
    global g_Fail
    if (cond)
        FileAppend("PASS: " . name . "`n", "*")
    else {
        FileAppend("FAIL: " . name . (extra != "" ? " | got=[" . extra . "]" : "") . "`n", "*")
        g_Fail++
    }
}

; 安全转储 (String(Map) 会抛"无 ToString 方法"; Map 只展键)
Dump(v) {
    try {
        if (IsObject(v)) {
            out := "{"
            try {
                for k, _ in v
                    out .= String(k) . ","
            } catch {
            }
            return RTrim(out, ",") . "}"
        }
        return String(v)
    } catch as e {
        return "<" . e.Message . ">"
    }
}

; 空显示区: 不抛, 空参空管道
r := ""
try r := SaveResultAsArg_Compute("", false, "command | Calc")
catch as e {
    r := "THROW:" . e.Message
}
Ck("empty-nothrow", IsObject(r), Dump(r))
Ck("empty-arg", r["arg"] == "", r["arg"])
Ck("empty-pipe", r["pipe"] == "", r["pipe"])

; 短行/坏行: 跳过不断言崩
r2 := SaveResultAsArg_Compute("abc`nxy | `na | b | c | d`n | leading", false, "command | Calc")
Ck("short-rows", r2["arg"] == "c", r2["arg"])

; 三段正常行取第 3 段
r3 := SaveResultAsArg_Compute("a>| run | notepad.exe | 记事本", false, "command | run:notepad.exe")
Ck("normal-col3", r3["arg"] == "记事本", r3["arg"])

; hide2 模式取标记后第二段 (旧语义原样保留: "a>| QQ | extra" 按 " | " 切只有两段)
r4 := SaveResultAsArg_Compute("a>| QQ | extra", true, "command | QQ")
Ck("hide2-col2", r4["arg"] == "extra", r4["arg"])
Ck("hide2-pipe", InStr(r4["pipe"], "placeholder") > 0, r4["pipe"])

; 文件行走 Registry 取路径 (生产路径 IngestRow 收编 file 行)
RimCommand.IngestRow("file | D:\soft\QQ.exe | 音乐")
r5 := SaveResultAsArg_Compute("a>| file | QQ | 音乐", false, "command | file:D:\soft\QQ.exe")
Ck("file-target", r5["arg"] == "D:\soft\QQ.exe", r5["arg"])

; 无分隔符全文进参
r6 := SaveResultAsArg_Compute("just some text", false, "command | Calc")
Ck("plain-passthrough", r6["arg"] == "just some text", r6["arg"])

; 间隔执行已死: RunCommand 不再武装 timer (静态断言)
execSrc := FileRead(A_ScriptDir . "\..\Core\Execution.ahk", "UTF-8")
Ck("no-interval-arm", !InStr(execSrc, "g_LastExecCb :="), "still-armed")
Ck("no-lastlabel", !InStr(execSrc, "g_LastExecLabel"), "still-there")

if (g_Fail > 0) {
    FileAppend("probe-savearg FAIL: " . g_Fail . "`n", "*")
    ExitApp(1)
}
FileAppend("probe-savearg-ok`n", "*")
ExitApp(0)
