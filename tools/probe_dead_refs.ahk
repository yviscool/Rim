#Requires AutoHotkey v2.0
#Warn All, Off
; 死引用审计探针 (静态文本审计, 零运行时依赖):
; ecfb4b3 删 79 别名而 ini 不动, SearchOn* 炸到用户才发现. 此探针锁三类:
;  1. ini (rim.ini/template) 里 function|X → X 裸函数须定义 / 点式 A.B 须类+静态方法俱在
;  2. 全仓 MakeLegacyCmd("X") / Host("Y") → X/Y 裸函数须定义
;  3. 上两类的定义集来自 ^Name(args) { 行扫描 (调用行以 ) 结尾, 不会误收)
; 故意不查: <SP_*> (插件前缀运行时注册)、command|X (ini 现无此类引用)、用户 auto.ini (用户数据)

fails := []
Check(name, cond) {
    global fails
    if (!cond)
        fails.Push(name)
}

ReadLines(path) {
    content := FileRead(path, "UTF-8")
    if (SubStr(content, 1, 1) = Chr(0xFEFF))
        content := SubStr(content, 2)
    out := []
    Loop Parse, content, "`n", "`r" {
        out.Push(A_LoopField)
    }
    return out
}

CollectAhk(root, funcs, methods, classes, legacyRefs, hostRefs) {
    Loop Files, root . "\*.ahk", "R" {
        try lines := ReadLines(A_LoopFileFullPath)
        catch {
            continue
        }
        curClass := ""
        for _, ln in lines {
            t := Trim(ln)
            if RegExMatch(t, "^class\s+([A-Za-z0-9_]+)", &m)
                curClass := m[1], classes[curClass] := true
            if RegExMatch(t, "^(static\s+)?([A-Za-z0-9_#@]+)\s*\(.*\)\s*\{\s*$", &f) {
                nm := f[2]
                if (nm = "if" || nm = "Loop" || nm = "While" || nm = "For" || nm = "Try" || nm = "Catch" || nm = "Finally" || nm = "Switch" || nm = "Case" || nm = "Default")
                    continue
                if (curClass != "" && InStr(ln, "static"))
                    methods[curClass . "." . nm] := true
                else if (curClass != "" && SubStr(ln, 1, 1) != " " && SubStr(ln, 1, 1) != "`t")
                    curClass := ""
                funcs[nm] := true
            }
            if (curClass != "" && !InStr(t, "static") && RegExMatch(t, "^[A-Za-z0-9_#@]+\s*\(.*\)\s*\{\s*$") && RegExMatch(t, "^([A-Za-z0-9_#@]+)", &g))
                methods[curClass . "." . g[1]] := true
            pos := 1
            while (pos := RegExMatch(ln, 'MakeLegacyCmd\("([A-Za-z0-9_]+)"', &h, pos)) {
                legacyRefs[h[1]] := true
                pos += StrLen(h[0])
            }
            pos := 1
            while (pos := RegExMatch(ln, 'Host\("([A-Za-z0-9_]+)"', &h2, pos)) {
                hostRefs[h2[1]] := true
                pos += StrLen(h2[0])
            }
        }
    }
}

Main() {
    global fails
    funcs := Map()
    methods := Map()
    classes := Map()
    legacyRefs := Map()
    hostRefs := Map()
    root := A_ScriptDir . "\.."
    CollectAhk(root . "\Core", funcs, methods, classes, legacyRefs, hostRefs)
    CollectAhk(root . "\Plugins", funcs, methods, classes, legacyRefs, hostRefs)
    CollectAhk(root . "\Lib", funcs, methods, classes, legacyRefs, hostRefs)
    CollectAhk(root . "\Gui", funcs, methods, classes, legacyRefs, hostRefs)
    try {
        for _, ln in ReadLines(root . "\Rim.ahk") {
            if RegExMatch(Trim(ln), "^(static\s+)?([A-Za-z0-9_#@]+)\s*\(.*\)\s*\{\s*$", &f)
                funcs[f[2]] := true
        }
    }
    ; --- ini function|X 引用 ---
    for _, iniName in ["Conf\rim.ini", "Conf\rim.template.ini"] {
        try lines := ReadLines(root . "\" . iniName)
        catch {
            fails.Push("unreadable " . iniName)
            continue
        }
        for _, ln in lines {
            t := Trim(ln)
            if (t = "" || SubStr(t, 1, 1) = ";" || SubStr(t, 1, 1) = "[")
                continue
            p := InStr(t, "function|")
            if (!p)
                continue
            rest := SubStr(t, p + 9)
            seg := StrSplit(rest, "|")
            ref := Trim(seg[1])
            if (ref = "")
                continue
            if InStr(ref, ".") {
                dot := StrSplit(ref, ".")
                cls := dot[1]
                if (!classes.Has(cls))
                    fails.Push(iniName . ": class gone <" . ref . ">")
                else if (!methods.Has(ref) && !funcs.Has(ref))
                    fails.Push(iniName . ": method gone <" . ref . ">")
            } else {
                if (!funcs.Has(ref))
                    fails.Push(iniName . ": func gone <" . ref . ">")
            }
        }
    }
    ; --- MakeLegacyCmd / Host 引用 ---
    for ref, _ in legacyRefs {
        if (!funcs.Has(ref))
            fails.Push("MakeLegacyCmd dead <" . ref . ">")
    }
    for ref, _ in hostRefs {
        if (!funcs.Has(ref))
            fails.Push("Host dead <" . ref . ">")
    }
    out := root . "\probe_dead_refs.out.txt"
    try FileDelete(out)
    catch {
    }
    if (fails.Length > 0) {
        txt := "dead-refs-FAIL:`n"
        for _, x in fails
            txt .= "  - " . x . "`n"
        FileAppend(txt, out, "UTF-8")
        ExitApp(1)
    }
    FileAppend("dead-refs-ok refs=" . (legacyRefs.Count + hostRefs.Count) . "`n", out, "UTF-8")
    ExitApp(0)
}

Main()
