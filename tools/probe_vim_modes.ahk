#Requires AutoHotkey v2.0
#Warn All, Off
; vim 模式双写探针: VimEditor_* 只写插件变量+冒提示, 引擎 win.currentMode
; 永远 normal → insert 形同虚设, 编辑器里什么都敲不了.
; 修法: VimEditor_SetMode 双写 (插件变量 + 引擎窗; __global__ 永不碰).

T(key, *) => key

class FakeWinObj {
    currentMode := "normal"
}

class FakeEng {
    winName := "Typora"
    CheckWin() {
        return this.winName
    }
    GetWin(n) {
        global g_FakeWinObj
        return g_FakeWinObj
    }
}

class FakeEng2 {
    winName := ""
    CheckWin() {
        return this.winName
    }
    GetWin(n) {
        global g_FakeWinObj
        return g_FakeWinObj
    }
}

global g_FakeWinObj := FakeWinObj()
global g_VimEngine := FakeEng()

#Include ..\Core\Plugin.ahk
#Include ..\Plugins\VimEditor.ahk
#Include ..\Plugins\General.ahk

fails := []
Check(name, cond) {
    global fails
    if (!cond)
        fails.Push(name)
}

Main() {
    global fails, g_FakeWinObj, g_VimEngine
    g_FakeWinObj.currentMode := "normal"
    VimEditor_SetMode("insert")
    Check("plugin-var", VimEditorPlugin.currentMode = "insert")
    Check("engine-win", g_FakeWinObj.currentMode = "insert")
    VimEditor_SetMode("normal")
    Check("back-normal", VimEditorPlugin.currentMode = "normal" && g_FakeWinObj.currentMode = "normal")
    ; __global__ 永不碰 (切过去无映射接回来, 等于全灭)
    g_VimEngine.winName := "__global__"
    g_FakeWinObj.currentMode := "SENTINEL"
    VimEditor_SetMode("insert")
    Check("global-untouched", g_FakeWinObj.currentMode = "SENTINEL")
    Check("global-plugin-still", VimEditorPlugin.currentMode = "insert")
    g_VimEngine.winName := "Typora"
    ; 四个模式函数走 helper (静态)
    src := FileRead(A_ScriptDir . "\..\Plugins\VimEditor.ahk", "UTF-8")
    Check("wire-insert", InStr(src, "VimEditor_InsertMode() {`n    VimEditor_SetMode(VimEditorPlugin.MODE_INSERT)") > 0)
    Check("wire-normal", InStr(src, "VimEditor_NormalMode() {`n    VimEditor_SetMode(VimEditorPlugin.MODE_NORMAL)") > 0)
    ; 零散装赋值残留 (helper 自身那行是 := mode, 不匹配本模式串)
    n := 0
    pos := 1
    while (pos := InStr(src, "VimEditorPlugin.currentMode := VimEditorPlugin.MODE_", false, pos)) {
        n++
        pos += 10
    }
    Check("no-strays", n = 0)
    ; command 模式 Esc 出口 (无映射的模式表整体穿透, Esc 必须显式注册建表,
    ; 否则 / 进查找框后关框切不回 normal)
    Check("command-esc", InStr(src, 'mk(wn, VimEditorPlugin.MODE_COMMAND, "<Esc>", "VimEditor_NormalMode")') > 0)
    ; CurVimWin 永不返回全局对象 (Gen_* 翻转打到 winGlobal 等于全局哑火)
    g_VimEngine := FakeEng2()
    g_VimEngine.winName := ""
    Check("curwin-empty", CurVimWin() = "")
    g_VimEngine.winName := "__global__"
    Check("curwin-global", CurVimWin() = "")
    g_VimEngine.winName := "Typora"
    Check("curwin-hit", IsObject(CurVimWin()))
    out := A_ScriptDir . "\..\probe_vim_modes.out.txt"
    try FileDelete(out)
    catch {
    }
    if (fails.Length > 0) {
        txt := "vim-modes-FAIL:`n"
        for _, x in fails
            txt .= "  - " . x . "`n"
        FileAppend(txt, out, "UTF-8")
        ExitApp(1)
    }
    FileAppend("vim-modes-ok`n", out, "UTF-8")
    ExitApp(0)
}

Main()
