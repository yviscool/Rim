#Requires AutoHotkey v2.0
#Warn All, Off
; 前缀吞键探针: BeforeActionDo (输入框保护) 只在完整动作后执行,
; g/<C-w> 等多键前缀在 KeyTemp 分支直接吞键返回 —— Explorer 重命名框按 g
; 出"可用动作"菜单即此. 修法: EngineShouldPassthroughPrefix + 前缀分支预检.

T(key, *) => key

#Include ..\Core\Engine.ahk

fails := []
Check(name, cond) {
    global fails
    if (!cond)
        fails.Push(name)
}

TrueCb(*) {
    return true
}

FalseCb(*) {
    return false
}

BoomCb(*) {
    throw Error("boom")
}

class FakeWin {
    BeforeActionDoFunc := ""
}

class FakeWinBare {
}

; 回调实现必须忽略 actionName (空串调用安全), 否则预检不可用
ImplIgnoresArg(path, sig) {
    content := FileRead(path, "UTF-8")
    lines := []
    Loop Parse, content, "`n", "`r" {
        lines.Push(A_LoopField)
    }
    start := 0
    for i, ln in lines {
        if (Trim(ln) = sig) {
            start := i
            break
        }
    }
    if (!start)
        return false
    depth := 0
    started := false
    for i in Range(start, lines.Length) {
        ln := lines[i]
        if (i = start)
            continue
        for _, ch in StrSplit(ln) {
            if (ch = "{")
                depth++, started := true
            else if (ch = "}")
                depth--
        }
        if (started && depth <= 0)
            return true
        if (InStr(ln, "actionName"))
            return false
    }
    return true
}

Range(a, b) {
    out := []
    i := a
    while (i <= b) {
        out.Push(i)
        i++
    }
    return out
}

Main() {
    global fails
    wTrue := FakeWin()
    wTrue.BeforeActionDoFunc := TrueCb
    wFalse := FakeWin()
    wFalse.BeforeActionDoFunc := FalseCb
    wBoom := FakeWin()
    wBoom.BeforeActionDoFunc := BoomCb
    wNone := FakeWinBare()
    Check("win-true", EngineShouldPassthroughPrefix(wTrue, ""))
    Check("win-false", !EngineShouldPassthroughPrefix(wFalse, TrueCb))
    Check("win-boom", !EngineShouldPassthroughPrefix(wBoom, ""))
    Check("global-true", EngineShouldPassthroughPrefix(wNone, TrueCb))
    Check("global-empty", !EngineShouldPassthroughPrefix(wNone, ""))
    Check("global-boom", !EngineShouldPassthroughPrefix(wNone, BoomCb))
    Check("str-guard", !EngineShouldPassthroughPrefix(wNone, "notafunc"))
    ; 实现忽略 actionName (空串预检安全)
    root := A_ScriptDir . "\.."
    Check("explorer-ignores", ImplIgnoresArg(root . "\Plugins\Explorer.ahk", "Explorer_ForceInsertMode(actionName, win) {"))
    Check("tc-ignores", ImplIgnoresArg(root . "\Plugins\TotalCommander.ahk", "TC_BeforeActionDo(actionName, win) {"))
    ; 接线: 预检在 KeyTemp 追加之前
    src := FileRead(root . "\Core\Engine.ahk", "UTF-8")
    pre := InStr(src, "EngineShouldPassthroughPrefix(win, this.BeforeActionDoFunc)")
    app := InStr(src, "win.KeyTemp .= vimKey")
    Check("wire-order", pre > 0 && app > 0 && pre < app)
    out := root . "\probe_prefix_passthrough.out.txt"
    try FileDelete(out)
    catch {
    }
    if (fails.Length > 0) {
        txt := "prefix-passthrough-FAIL:`n"
        for _, x in fails
            txt .= "  - " . x . "`n"
        FileAppend(txt, out, "UTF-8")
        ExitApp(1)
    }
    FileAppend("prefix-passthrough-ok`n", out, "UTF-8")
    ExitApp(0)
}

Main()
