#Requires AutoHotkey v2.0
#Warn All, Off
FileEncoding "UTF-8"

; 回归探针: 雷达全屏抑制
; 覆盖: 纯几何 / ClassifyFullscreen 真实窗口 / ShouldSuppress 同屏判定 / 源码不变量
; 判定: 0 退出 + 无 FAIL 行 + probe_statsball_fullscreen.out.txt 有 ok 标记
T(key, *) => key

#Include ..\Core\Window.ahk
#Include ..\Core\Plugin.ahk
#Include ..\Core\ConfigSchema.ahk
#Include ..\Plugins\StatsBall.ahk

global g_Fails := 0

Check(name, cond) {
    global g_Fails
    if (cond) {
        FileAppend("PASS: " . name . "`n", "*")
    } else {
        g_Fails++
        FileAppend("FAIL: " . name . "`n", "*")
    }
}

; ---- 1) 纯几何: rcMonitor 覆盖 / 工作区不覆盖 / 容差 / 多屏 ----
Check("geo-full", RimWindow.RectCoversMonitor(0, 0, 1920, 1080, 0, 0, 1920, 1080))
Check("geo-work", !RimWindow.RectCoversMonitor(0, 0, 1920, 1040, 0, 0, 1920, 1080))
Check("geo-tol", RimWindow.RectCoversMonitor(-4, -4, 1924, 1084, 0, 0, 1920, 1080))
; 比监视器更大 = 仍算覆盖 (容差只放宽"小于", 不放宽"大于")
Check("geo-oversize", RimWindow.RectCoversMonitor(-8, -8, 1928, 1088, 0, 0, 1920, 1080))
; 内缩超过容差 = 不算全屏 (带边框的窗口)
Check("geo-inset", !RimWindow.RectCoversMonitor(8, 8, 1912, 1072, 0, 0, 1920, 1080))
Check("geo-multi", RimWindow.RectCoversMonitor(1920, 0, 3840, 1080, 1920, 0, 3840, 1080))

; ---- 2) 真实窗口几何: 全屏尺寸 vs 小窗 (useQuns=false, 不受当前桌面状态影响) ----
monW := SysGet(78)
monH := SysGet(79)
fsGui := Gui("-Caption +ToolWindow")
fsGui.Show("x0 y0 w" . monW . " h" . monH . " Hide")
fs := RimWindow.ClassifyFullscreen(fsGui.Hwnd, false)
Check("classify-full", IsObject(fs) && fs["reason"] = "geometry")

smallGui := Gui("-Caption +ToolWindow")
smallGui.Show("x0 y0 w200 h120 Hide")
Check("classify-small", !IsObject(RimWindow.ClassifyFullscreen(smallGui.Hwnd, false)))

; ---- 2b) 前台检测: 同进程窗口必须被排除 (自己盖满屏也不算全屏) ----
fgGui := Gui("-Caption +ToolWindow")
fgGui.Show("x0 y0 w240 h140")
try WinActivate("ahk_id " . fgGui.Hwnd)
Sleep(80)
if (WinActive("ahk_id " . fgGui.Hwnd))
    Check("foreground-self-excluded", !IsObject(RimWindow.ForegroundFullscreen()))
else
    Check("foreground-self-excluded", true)  ; 无前台会话 (CI/锁屏) 时跳过
fgGui.Destroy()

; ---- 3) ShouldSuppress: 同屏藏 / 异屏不藏 / 开关关掉不藏 ----
global g_StatsBall := StatsBallObj()
g_StatsBall.ballHwnd := fsGui.Hwnd
hMon := DllCall("MonitorFromWindow", "Ptr", fsGui.Hwnd, "UInt", 2, "Ptr")
g_StatsBall.hideFullscreen := true
Check("suppress-same-mon", g_StatsBall.ShouldSuppress(Map("mon", hMon)))
Check("suppress-other-mon", !g_StatsBall.ShouldSuppress(Map("mon", hMon + 1)))
g_StatsBall.hideFullscreen := false
Check("suppress-off", !g_StatsBall.ShouldSuppress(Map("mon", hMon)))

; ---- 3b) 状态机: 注入同屏 → 抑制; 注入异屏 → 恢复 (不建真窗, 不闪屏) ----
g_StatsBall.hideFullscreen := true
g_StatsBall.visible := true
g_StatsBall.suppressed := false
g_StatsBall.UpdateSuppression(Map("mon", hMon))
Check("update-hide", g_StatsBall.suppressed)
g_StatsBall.UpdateSuppression(Map("mon", hMon + 1))
Check("update-restore", !g_StatsBall.suppressed)
g_StatsBall.UpdateSuppression(Map("mon", hMon + 1))
Check("update-idempotent", !g_StatsBall.suppressed)
g_StatsBall.hideFullscreen := false
g_StatsBall.UpdateSuppression(Map("mon", hMon))
Check("update-config-off", !g_StatsBall.suppressed)
try SetTimer(g_StatsBall.timerFn, 0)
g_StatsBall.visible := false

; ---- 3c) 真窗验证: Show → 注入同屏隐藏 → 注入异屏恢复 → 销毁 ----
; (会在桌面右下角短暂出现一条雷达, 约 0.3s)
; 真窗段临时关掉自动判定, 只验证显示/隐藏管线, 免得"当前前台恰好是全屏应用"让探针抖
g_StatsBall.hideFullscreen := false
g_StatsBall.Show()
Sleep(150)
Check("rt-show-visible", DllCall("IsWindowVisible", "Ptr", g_StatsBall.ballHwnd))
hMonBall := DllCall("MonitorFromWindow", "Ptr", g_StatsBall.ballHwnd, "UInt", 2, "Ptr")
g_StatsBall.hideFullscreen := true
g_StatsBall.UpdateSuppression(Map("mon", hMonBall))
Sleep(80)
Check("rt-suppressed-hidden", !DllCall("IsWindowVisible", "Ptr", g_StatsBall.ballHwnd))
g_StatsBall.UpdateSuppression(Map("mon", hMonBall + 1))
Sleep(80)
Check("rt-restored-visible", DllCall("IsWindowVisible", "Ptr", g_StatsBall.ballHwnd))
g_StatsBall.Hide()
hBall := g_StatsBall.ballHwnd
g_StatsBall.Destroy()
Check("rt-destroyed", !WinExist("ahk_id " . hBall))

; ---- 4) 源码不变量: 创建不再硬编码 topmost; 只有一个 g.Show 出口; 消息可解绑 ----
src := FileRead(A_ScriptDir . "\..\Plugins\StatsBall.ahk", "UTF-8")
if (SubStr(src, 1, 1) = Chr(0xFEFF))
    src := SubStr(src, 2)
src := StrReplace(src, "`r`n", "`n")
Check("no-hardcoded-topmost", !RegExMatch(src, 'Gui\("\+ToolWindow -Caption \+AlwaysOnTop'))

showCnt := 0
showPos := 1
while (showPos := RegExMatch(src, '\.g\.Show\(', &showM, showPos)) {
    showCnt++
    showPos += StrLen(showM[0])
}
Check("one-show-exit", showCnt = 1)
Check("unregister-msg", InStr(src, 'OnMessage(0x200, this.mmFn, 0)') > 0)
Check("suppress-gate", InStr(src, "ShouldSuppress(") > 0 && InStr(src, "UpdateSuppression()") > 0)

fsGui.Destroy()
smallGui.Destroy()

if (g_Fails > 0) {
    FileAppend("FAIL total=" . g_Fails . "`n", "*")
    ExitApp(1)
}
try FileDelete(A_ScriptDir . "\..\probe_statsball_fullscreen.out.txt")
FileAppend("probe-statsball-fullscreen-ok`n", A_ScriptDir . "\..\probe_statsball_fullscreen.out.txt")
ExitApp(0)
