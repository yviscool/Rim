#Requires AutoHotkey v2.0
#Warn All, Off

; 文件执行链复现: 真 IngestRow + 真 CmdLine_Parse + 真 ActionParse + 真分发判定 (止于 Run 之前)
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_file_exec.ahk
#Include ..\Core\Command.ahk
#Include ..\Core\SmartInputPure.ahk
#Include ..\Core\ActionProtocol.ahk

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

T(key, *) => key
RimLog(level, msg, err := "") {
}

lines := ["file | D:\software\Weixin\Weixin.exe",
    "file | D:\software\Weixin\4.1.15.13\WeixinExt.exe",
    "file | D:\software\Weixin\4.1.15.13\WeixinUpdate.exe",
    "file | D:\software\Weixin\微信.lnk"]
for _, line in lines {
    id := RimCommand.IngestRow(line)
    Ck("ingest-id-" . id, id != "", line)
    cmd := RimCommand.Get(id)
    Ck("ingest-found-" . id, IsObject(cmd), id)
    row := RimCommand.SearchRow(cmd)
    Ck("row-show-" . id, row["show"] != "", row["show"])
    ; 列表行 (SearchRenderItem 产物)
    idline := "command | " . row["id"]
    ; RunCommand 解析 (CmdLine_Parse)
    parsed := CmdLine_Parse(idline)
    Ck("parse-type-" . id, parsed["type"] = "command", parsed["type"])
    Ck("parse-cmd-" . id, parsed["cmd"] = row["id"], parsed["cmd"])
    ; ExecuteAction 动作串
    actStr := parsed["type"] . "|" . parsed["cmd"]
    pact := ActionParse(actStr, "probe")
    Ck("dispatch-kind-" . id, pact["ok"] && pact["kind"] = "command", pact["kind"])
    Ck("registry-hit-" . id, RimCommand.Registry.Has(pact["target"]), pact["target"])
    ; RimCommand.Execute 取 Action, 不真正 Run
    target2 := RimCommand.Get(pact["target"])
    Ck("exec-action-" . id, IsObject(target2) && SubStr(String(target2.Action), 1, 5) = "file|", IsObject(target2) ? String(target2.Action) : "noobj")
    pbody := ActionParse(String(target2.Action), "probe")
    Ck("body-kind-" . id, pbody["ok"] && pbody["kind"] = "file", pbody["kind"])
    ; Body file| 分支目标抽取 (与 Execution.ahk 同式, 不 Run)
    tact := String(target2.Action)
    tpath := SubStr(tact, SubStr(tact, 1, 4) = "run|" ? 5 : 6)
    Ck("body-target-" . id, tpath != "" && InStr(tpath, ".exe") > 0 || InStr(tpath, ".lnk") > 0, tpath)
    Ck("target-exists-" . id, FileExist(tpath) != "", tpath)
}

if (g_Fail > 0) {
    FileAppend("probe-file-exec FAIL: " . g_Fail . "`n", "*")
    ExitApp(1)
}
FileAppend("probe-file-exec-ok`n", "*")
ExitApp(0)
