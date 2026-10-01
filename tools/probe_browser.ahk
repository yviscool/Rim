#Requires AutoHotkey v2.0
#Warn All, Off

; 回归探针: 浏览器 Vim 模式 (Plugins/Browser.ahk)
; 1) 三窗注册 (Chrome/Edge 同类 Chrome_WidgetWin_1, 靠 exe 区分; VSCode 同类不误命中)
; 2) normal/insert 映射抽查 + f 预留未映射 (链接提示留给扩展)
; 3) 动作↔函数一一对应 (源码扫描, 防 EXEC_FAILED 悬空)
; 4) 三窗 BeforeActionDo 菜单透传已挂载
T(key, *) => key

#Include ..\Core\Plugin.ahk
#Include ..\Core\Engine.ahk
#Include ..\Plugins\Browser.ahk

Assert(cond, msg) {
    if (!cond) {
        FileAppend("FAIL: " . msg . "`n", "*")
        ExitApp(1)
    }
    FileAppend("PASS: " . msg . "`n", "*")
}

engine := VimEngine()
Browser_Keymaps(engine)

; --- 1) 窗口注册 ---
chromeWin := engine.GetWin("Browser_Chrome")
edgeWin := engine.GetWin("Browser_Edge")
firefoxWin := engine.GetWin("Browser_Firefox")
Assert(IsObject(chromeWin), "win-chrome-exists")
Assert(IsObject(edgeWin), "win-edge-exists")
Assert(IsObject(firefoxWin), "win-firefox-exists")
Assert(chromeWin.WinClass = "Chrome_WidgetWin_1" && chromeWin.WinFile = "chrome.exe", "win-chrome-id")
Assert(edgeWin.WinClass = "Chrome_WidgetWin_1" && edgeWin.WinFile = "msedge.exe", "win-edge-id")
Assert(firefoxWin.WinClass = "MozillaWindowClass" && firefoxWin.WinFile = "firefox.exe", "win-firefox-id")

; exe 优先轮次复刻 (Engine.CheckWin 前半段语义): 同类不同 exe 必须各中各窗
hit := "__global__"
for winName, bwWin in engine.WinList {
    if (winName = "__global__")
        continue
    if (bwWin.WinFile != "" && "chrome.exe" = bwWin.WinFile) {
        hit := winName
        break
    }
}
Assert(hit = "Browser_Chrome", "exe-chrome-hit")
hit := "__global__"
for winName, bwWin in engine.WinList {
    if (winName = "__global__")
        continue
    if (bwWin.WinFile != "" && "msedge.exe" = bwWin.WinFile) {
        hit := winName
        break
    }
}
Assert(hit = "Browser_Edge", "exe-edge-hit")
hit := "__global__"
for winName, bwWin in engine.WinList {
    if (winName = "__global__")
        continue
    if (bwWin.WinFile != "" && "firefox.exe" = bwWin.WinFile) {
        hit := winName
        break
    }
}
Assert(hit = "Browser_Firefox", "exe-firefox-hit")

; --- 2) 映射抽查 (大写经 NormalizeVimKey 归一, 对齐 MapKey 存储形态) ---
normalMap := chromeWin.modeList["normal"].keymapList
MapOf(raw) => normalMap.Has(NormalizeVimKey(raw)) ? normalMap[NormalizeVimKey(raw)] : "<MISSING>"
Assert(MapOf("j") = "<Bw_Down>", "map-j")
Assert(MapOf("k") = "<Bw_Up>", "map-k")
Assert(MapOf("d") = "<Bw_HalfDown>", "map-d")
Assert(MapOf("u") = "<Bw_HalfUp>", "map-u")
Assert(MapOf("gg") = "<Bw_Top>", "map-gg")
Assert(MapOf("G") = "<Bw_Bottom>", "map-G")
Assert(MapOf("0") = "<Bw_Home>", "map-0")
Assert(MapOf("$") = "<Bw_End>", "map-dollar")
Assert(MapOf("t") = "<Bw_NewTab>", "map-t")
Assert(MapOf("x") = "<Bw_CloseTab>", "map-x")
Assert(MapOf("X") = "<Bw_RestoreTab>", "map-X")
Assert(MapOf("J") = "<Bw_NextTab>", "map-J")
Assert(MapOf("K") = "<Bw_PrevTab>", "map-K")
Assert(MapOf("gn") = "<Bw_NextTab>", "map-gn")
Assert(MapOf("g0") = "<Bw_LastTab>", "map-g0")
Assert(MapOf("H") = "<Bw_Back>", "map-H")
Assert(MapOf("L") = "<Bw_Forward>", "map-L")
Assert(MapOf("r") = "<Bw_Reload>", "map-r")
Assert(MapOf("R") = "<Bw_ForceReload>", "map-R")
Assert(MapOf("o") = "<Bw_AddrBar>", "map-o")
Assert(MapOf("/") = "<Bw_Find>", "map-slash")
Assert(MapOf("n") = "<Bw_FindNext>", "map-n")
Assert(MapOf("N") = "<Bw_FindPrev>", "map-N")
Assert(MapOf("zi") = "<Bw_ZoomIn>", "map-zi")
Assert(MapOf("zo") = "<Bw_ZoomOut>", "map-zo")
Assert(MapOf("z0") = "<Bw_ZoomReset>", "map-z0")
Assert(MapOf("b") = "<Bw_Bookmark>", "map-b")
Assert(MapOf("gh") = "<Bw_History>", "map-gh")
Assert(MapOf("gd") = "<Bw_Downloads>", "map-gd")
Assert(MapOf("i") = "<Bw_InsertMode>", "map-i")
Assert(MapOf("?") = "<Bw_Help>", "map-help")
for _, digit in ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
    Assert(MapOf(digit) = "<Pass>", "map-count-" . digit)
; f 预留给链接提示扩展, normal 下必须未映射 (未映射键引擎直接透传)
Assert(!normalMap.Has("f"), "map-f-reserved")
; 三窗映射一致 (Edge/Firefox 抽查核心键)
Assert(edgeWin.modeList["normal"].keymapList[NormalizeVimKey("J")] = "<Bw_NextTab>", "edge-parity")
Assert(firefoxWin.modeList["normal"].keymapList["j"] = "<Bw_Down>", "firefox-parity")
Assert(firefoxWin.modeList["normal"].keymapList["t"] = "<Bw_NewTab>", "firefox-tab")

; insert 模式: 只留出口
insertMap := chromeWin.modeList["insert"].keymapList
Assert(insertMap[NormalizeVimKey("<Esc>")] = "<Bw_NormalMode>", "insert-esc")
Assert(insertMap[NormalizeVimKey("<C-[>")] = "<Bw_NormalMode>", "insert-ctrl-lbracket")
Assert(!insertMap.Has("j"), "insert-passthrough")

; --- 3) 动作↔函数一一对应 (源码扫描) ---
src := FileRead(A_ScriptDir . "\..\Plugins\Browser.ahk", "UTF-8")
registered := Map()
pos := 1
while (pos := RegExMatch(src, 'engine\.SetAction\("(<Bw_[A-Za-z0-9_]+>)"', &m, pos)) {
    registered[m[1]] := true
    pos += StrLen(m[0])
}
defined := Map()
pos := 1
while (pos := RegExMatch(src, 'm)^Bw_([A-Za-z0-9_]+)\(\) \{', &d, pos)) {
    defined["<Bw_" . d[1] . ">"] := true
    pos += StrLen(d[0])
}
for actName in registered {
    if (!defined.Has(actName)) {
        FileAppend("FAIL: action-no-func " . actName . "`n", "*")
        ExitApp(1)
    }
}
FileAppend("PASS: actions-wired=" . registered.Count . "`n", "*")
; MapKey 引用的 <Bw_*> 必须全部已注册
pos := 1
while (pos := RegExMatch(src, 'engine\.MapKey\(.+?, "(<Bw_[A-Za-z0-9_]+>)"', &k, pos)) {
    if (!registered.Has(k[1])) {
        FileAppend("FAIL: map-unregistered " . k[1] . "`n", "*")
        ExitApp(1)
    }
    pos += StrLen(k[0])
}
FileAppend("PASS: maps-registered`n", "*")

; --- 4) 模式切换有提示 (对齐 VimEditor: 切模式弹 ToolTip 600ms 自消) ---
Assert(InStr(src, 'Bw_InsertMode() {`n    Bw_SetMode("insert")`n    ToolTip(') > 0, "tip-insert")
Assert(InStr(src, 'Bw_NormalMode() {`n    Bw_SetMode("normal")') > 0, "tip-normal")
Assert(InStr(src, 'SetTimer(() => ToolTip(), -600)') > 0, "tip-autohide")

; --- 5) BeforeActionDo 挂载 ---
for _, bwName in ["Browser_Chrome", "Browser_Edge", "Browser_Firefox"] {
    bwWin := engine.GetWin(bwName)
    Assert(IsObject(bwWin.BeforeActionDoFunc), "before-" . bwName)
}

try FileDelete(A_ScriptDir . "\..\probe_browser.out.txt")
FileAppend("probe-browser-ok`n", A_ScriptDir . "\..\probe_browser.out.txt")
ExitApp(0)
