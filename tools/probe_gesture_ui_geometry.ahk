#Requires AutoHotkey v2.0
#Warn All, Off
; i18n:protocol-file (断言 zh 语言包解析出的状态栏中文, 固件期望值必须字面一致)

T(key, p1 := "", p2 := "", *) {
    global g_LangMap
    if !IsSet(g_LangMap)
        g_LangMap := Map()
    if g_LangMap.Has(key) {
        val := g_LangMap[key]
        if (p1 != "")
            val := StrReplace(val, "{1}", p1)
        if (p2 != "")
            val := StrReplace(val, "{2}", p2)
        return val
    }
    return key
}

; 载入真语言文件测试
g_LangMap := Map()
if FileExist("..\Lang\zh-CN.ini") {
    content := FileRead("..\Lang\zh-CN.ini", "UTF-8")
    Loop Parse, content, "`n", "`r" {
        line := Trim(A_LoopField)
        if (line = "" || SubStr(line, 1, 1) = ";")
            continue
        eq := InStr(line, "=")
        if (eq > 1) {
            k := SubStr(line, 1, eq - 1)
            v := SubStr(line, eq + 1)
            g_LangMap[k] := v
        }
    }
}

#Include ..\Lib\EasyIni.ahk
#Include ..\Core\Gesture.ahk
#Include ..\Core\GestureTemplate.ahk
#Include ..\Core\GestureSPData.ahk
#Include ..\Core\GestureIni.ahk
#Include ..\Core\GesturePreview.ahk
#Include ..\Gui\GestureUI.ahk

global g_ConfFile := A_Temp . "\rim-gesture-ui-geom-" . A_TickCount . ".ini"
global g_Conf := ""

try {
    FileAppend("[Gesture]`nEnable=1`nTrigger=RButton`nCancelDelay=1500`n"
        . "[Gestures]`nR_D=key|^t`n", g_ConfFile, "UTF-8")
    g_Conf := EasyIni(g_ConfFile)
    GestureEngine.LoadConfig()
    GestureEngine.ReloadLayers()
    Tpl_LoadAll()

    ShowGestureManager()
    guiObj := g_GestureMgr["gui"]
    tabs := g_GestureMgr["tabs"]
    lv := g_GestureMgr["lv"]
    status := g_GestureMgr["status"]

    tabs.GetPos(&tx, &ty, &tw, &th)
    lv.GetPos(&lx, &ly, &lw, &lh)
    status.GetPos(&sx, &sy, &sw, &sh)

    ; 断言 1: Tab 顶部和高度
    if (ty != 10 || tw != 816 || th != 484)
        throw Error("Tabs geometry mismatch: " ty " " tw " " th)

    ; 断言 2: ListView Y >= 90，避开 Tab 页眉
    if (ly < 90)
        throw Error("ListView Y too high, colliding with tab header: ly=" ly)

    ; 断言 3: ListView X >= 20，位于 Tab 客户区内，不压左边框
    if (lx < 20)
        throw Error("ListView X too small, colliding with tab left border: lx=" lx)

    ; 断言 4: 状态栏位于 Tab 控件下方 (sy > ty + th)
    if (sy < ty + th)
        throw Error("Status bar is inside Tab container: sy=" sy ", tabBottom=" (ty + th))

    ; 断言 5: 默认状态栏显示手势统计，而不是黑名单信息
    statusText := status.Text
    if InStr(statusText, "屏蔽规则") || !InStr(statusText, "手势")
        throw Error("Status text was overwritten by blacklist on startup: " statusText)

    ; 断言 6: 切换 Tab 测试状态栏联动
    tabs.Value := 2
    GestureMgr_OnTabChange(tabs)
    if !InStr(status.Text, "样本") && !InStr(status.Text, "模板")
        throw Error("Status text did not update on Tab 2 change: " status.Text)

    tabs.Value := 3
    GestureMgr_OnTabChange(tabs)
    if !InStr(status.Text, "屏蔽规则")
        throw Error("Status text did not update on Tab 3 change: " status.Text)

    guiObj.Destroy()
    FileAppend("PASS gesture UI geometry & tab switching`n", "*")
} catch Error as e {
    try g_GestureMgr["gui"].Destroy()
    FileAppend("FAIL gesture UI geometry: " . e.Message . " line=" . e.Line . "`n", "*")
    ExitApp(1)
} finally {
    try FileDelete(g_ConfFile)
}
ExitApp(0)
