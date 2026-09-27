#Requires AutoHotkey v2.0
#Warn All, Off
; 跨层劫持探针: 浏览器里画 DL (全局最小化) 被误识为 J (浏览器层 Ctrl+J),
; 打开下载历史且误触率高. 根因: SelectCandidate 里应用层候选一旦存在,
; 全局候选直接出局, 分数不看 —— 76 分的 J 劫 88 分的 DL.
; 修法: 应用候选须进分差带 (bestGlobal - margin) 才参评, 带外按分走.

T(key, *) => key

#Include ..\Lib\EasyIni.ahk
#Include ..\Core\ConfigSchema.ahk
#Include ..\Core\Gesture.ahk
#Include ..\Core\GestureTemplate.ahk
#Include ..\Core\GestureSPData.ahk
#Include ..\Core\GestureIni.ahk

global g_ConfFile := A_Temp . "\rim-gesture-crosslayer-" . A_TickCount . ".ini"
global g_Conf := ""
global failures := 0

Check(label, condition) {
    global failures
    if !condition {
        FileAppend("FAIL " . label . "`n", "*")
        failures++
    }
}

MkCand(name, method, score) {
    return {name: name, method: method, score: score, sample: 0}
}

Main() {
    global failures
    try {
        FileAppend("[Gesture]`nTemplateThreshold=75`n"
            . "[GestureDefinitions]`nDL=direction`nJ=template`n"
            . "[Gestures]`nDL=<wm_min>`n"
            . "[GestureApp:Browser]`nset_file=browser.exe`nJ=key|^j`n", g_ConfFile, "UTF-8")
        global g_Conf := EasyIni(g_ConfFile)
        Tpl_LoadAll()
        GestureEngine.ReloadLayers()
        ; 主案: DL88 (全局) vs J76 (应用) → 全局按分胜, 不得开下载页
        r1 := GestureEngine.SelectCandidate([MkCand("DL", "direction", 88.0), MkCand("J", "template", 76.0)], "browser.exe", "Browser", "Test")
        Check("global-beats-app-straggler", IsObject(r1.selected) && r1.selected.name = "DL" && r1.selected.action = "<wm_min>")
        ; 带内 (分差 < margin): 宁可拒识也不错杀
        r2 := GestureEngine.SelectCandidate([MkCand("DL", "direction", 88.0), MkCand("J", "template", 85.0)], "browser.exe", "Browser", "Test")
        Check("in-margin-ambiguous", !IsObject(r2.selected) && r2.reason = "ambiguous")
        ; 应用独占 (全局无绑定): 应用低分也中 (覆盖语义保留)
        r3 := GestureEngine.SelectCandidate([MkCand("J", "template", 76.0)], "browser.exe", "Browser", "Test")
        Check("app-alone-wins", IsObject(r3.selected) && r3.selected.action = "key|^j")
        ; 全局独占: 照常
        r4 := GestureEngine.SelectCandidate([MkCand("DL", "direction", 88.0)], "browser.exe", "Browser", "Test")
        Check("global-alone-wins", IsObject(r4.selected) && r4.selected.action = "<wm_min>")
        ; 非浏览器 (无应用层): 原行为, 高分胜
        r5 := GestureEngine.SelectCandidate([MkCand("DL", "direction", 88.0), MkCand("J", "template", 76.0)], "other.exe", "Other", "Test")
        Check("no-app-layer", IsObject(r5.selected) && r5.selected.name = "DL")
        ; J 在浏览器仍可直达 (真画出 J 形不受影响)
        r6 := GestureEngine.SelectCandidate([MkCand("J", "template", 92.0)], "browser.exe", "Browser", "Test")
        Check("app-high-wins", IsObject(r6.selected) && r6.selected.action = "key|^j")
    } catch Error as e {
        FileAppend("ERROR " . e.Message . " line=" . e.Line . "`n", "*")
        failures++
    } finally {
        try FileDelete(g_ConfFile)
        catch {
        }
    }
    FileAppend(failures ? "FAIL " . failures . "`n" : "crosslayer-ok`n", "*")
    ExitApp(failures ? 1 : 0)
}

Main()
