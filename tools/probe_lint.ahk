#Requires AutoHotkey v2.0
#Warn All, Off
; 静态 v2 lint: AGENTS.md 血泪错误重现即失败 (全是零误报项, 基线干净).
; 规则 (全行注释跳过; 行尾注释不豁免——违禁串本就不该出现在代码侧):
;  A_LoopFileLongPath / IsFunc( / FileGetTime(& / #MaxHotkeysPerInterval /
;  GoSub / 裸 catch 名 (缺 as) / .Focused / SearchIdx_ / 已删兼容别名.
; 跑法: MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut tools/probe_lint.ahk

fails := []
Flag(file, line, rule, text) {
    global fails
    fails.Push(file . ":" . line . " [" . rule . "] " . SubStr(Trim(text), 1, 100))
}

IsComment(line) {
    return SubStr(Trim(line), 1, 1) = ";"
}

HasBareCatch(line) {
    if (!InStr(line, "catch"))
        return false
    if (InStr(line, "catch {") || InStr(line, "catch{"))
        return false
    if RegExMatch(line, "i)\bcatch\s+as\b")
        return false
    if RegExMatch(line, "i)\bcatch\s+Error\b")
        return false
    return RegExMatch(line, "i)\bcatch\s+[A-Za-z_]") > 0
}

CheckFile(path, rel) {
    content := ""
    try content := FileRead(path, "UTF-8")
    catch {
        return
    }
    ln := 0
    Loop Parse, content, "`n", "`r" {
        ln++
        line := A_LoopField
        if (IsComment(line))
            continue
        if (InStr(line, "A_LoopFileLongPath"))
            Flag(rel, ln, "loopfile-longpath", line)
        if RegExMatch(line, "IsFunc\s*\(")
            Flag(rel, ln, "isfunc", line)
        if (InStr(line, "FileGetTime(&"))
            Flag(rel, ln, "filegettime-&", line)
        if (InStr(line, "#MaxHotkeysPerInterval"))
            Flag(rel, ln, "maxhotkeys-directive", line)
        if RegExMatch(line, "i)(^|[\s{;])GoSub\b")
            Flag(rel, ln, "gosub", line)
        if (HasBareCatch(line))
            Flag(rel, ln, "bare-catch", line)
        if RegExMatch(line, "\.Focused\b")
            Flag(rel, ln, "focused", line)
        if (InStr(line, "SearchIdx_"))
            Flag(rel, ln, "searchidx-retired", line)
        for _, alias in ["ExecuteActionResult", "RunAndGetOutputEx", "ReadTextFileEx", "RegisterEx"] {
            if (InStr(line, alias))
                Flag(rel, ln, "retired-alias", line)
        }
    }
}

Main() {
    global fails
    root := A_ScriptDir . "\.."
    CheckFile(root . "\Rim.ahk", "Rim.ahk")
    for _, dir in ["Core", "Plugins", "Lib", "Gui"] {
        Loop Files, root . "\" . dir . "\*.ahk", "R" {
            CheckFile(A_LoopFileFullPath, dir . "\" . A_LoopFileName)
        }
    }
    if (fails.Length > 0) {
        txt := "lint-FAIL:`n"
        for _, x in fails
            txt .= "  - " . x . "`n"
        FileAppend(txt, "*", "UTF-8")
        ExitApp(1)
    }
    FileAppend("lint-ok`n", "*", "UTF-8")
    ExitApp(0)
}

Main()
