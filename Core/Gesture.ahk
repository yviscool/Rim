#Requires AutoHotkey v2.0
#Warn All, Off

; === Core/Gesture.ahk - 鼠标手势子系统主入口 ===
; 纯粹导入各独立模块与状态定义，无任何冗余转发兼容层

#Include Gesture\Recognizer.ahk
#Include Gesture\Registry.ahk
#Include Gesture\Hook.ahk
#Include Gesture\Engine.ahk

global g_Gesture := Map(
    "enable", 0,
    "trigger", "RButton",
    "boundTrigger", "",
    "threshold", 6,
    "segment", 6,
    "poll", 10,
    "cancelDelay", 1500,
    "showOSD", 1,
    "noMatch", "swallow",
    "ignoreKey", "",
    "onlyDefined", 0,
    "trail", 1,
    "trailColor", "45ABFF",
    "trailWidth", 5,
    "ignoreNext", 0,
    "down", 0,
    "gesturing", 0,
    "cancelled", 0,
    "startX", 0, "startY", 0,
    "downTick", 0,
    "lastMoveTick", 0,
    "points", [],
    "dirs", [],
    "gesture", "",
    "recording", 0,
    "recordCb", "",
    "recorded", "",
    "tplRecording", 0,
    "tplRecordCb", "",
    "tryMode", 0,
    "comboUntil", 0,
    "comboKind", "",
    "trailX", -1, "trailY", -1,
    "downMods", "",
    "startHwnd", 0,
    "startContext", "",
    "forwardDown", 0,
    "leftCombo", 0,
    "volLatch", 1,
    "volMode", 0,
    "volUsed", 0,
    "candidate", "",
    "candidateList", [],
    ; 显式状态机 (Stage1): idle → pending(按下) → capturing(超阈值位移) → resolving/matched/cancelled/combo/recording;
    ; 只做观测 (tryMode 提示 + 探针断言), 不参与分支逻辑, 新分支禁另起状态名
    "phase", "idle"
)

global g_GestureMap := Map()       ; 全局层: 手势串 -> 动作串
global g_GestureApps := []         ; 应用层: [{name, exe, cls, map}]
global g_GestureBlacklist := []    ; 黑名单
global g_GestureAppPrefix := "GestureApp:"
global g_GestureDefs := Map()
global g_GestureDisabled := Map()  ; 禁用集: id -> 1
global g_GestureHookBefore := ""
global g_GestureHookAfter := ""

; === 旧过程式 API 兼容垫片 (探针/旧插件仍调全局函数, 转调新类方法; 新代码请直调类) ===
; probe_gesture_*.ahk 曾直调 Gesture_ResolveStroke/ReloadLayers/ChainOff/Normalize,
; 而实现已收敛为 GestureEngine/GestureRecognizer 静态方法, 此处垫平, 避免全员改调用点
Gesture_ResolveStroke(gestureStr, pts, exe, cls, title, mods := "", ownerCls := "", ctrlCls := "", ctrlTitle := "") {
    return GestureEngine.ResolveStroke(gestureStr, pts, exe, cls, title, mods, ownerCls, ctrlCls, ctrlTitle)
}

Gesture_ReloadLayers() {
    return GestureEngine.ReloadLayers()
}

Gesture_LoadConfig() {
    return GestureEngine.LoadConfig()
}

Gesture_ChainOff(layer, key) {
    return GestureEngine.ChainOff(layer, key)
}

Gesture_Normalize(s) {
    return GestureRecognizer.Normalize(s)
}

Gesture_NormalizeFull(s) {
    return GestureRecognizer.NormalizeFull(s)
}

Gesture_MatchApp(exe, cls, title := "", ownerCls := "", ctrlCls := "", ctrlTitle := "") {
    return GestureEngine.MatchApp(exe, cls, title, ownerCls, ctrlCls, ctrlTitle)
}

Gesture_ActionWin() {
    return GestureHook.ActionWin()
}

Gesture_StartIds(&exe, &cls, &title, &ownerCls := "", &ctrlCls := "", &ctrlTitle := "") {
    return GestureHook.StartIds(&exe, &cls, &title, &ownerCls, &ctrlCls, &ctrlTitle)
}

Gesture_ComboActive() {
    return GestureEngine.ComboActive()
}

; === 手势节名/层名常量 (改名只改此处; 模板 ini / 引擎 / 持久化三方同源, 禁止各处手写字面量) ===
GestureSec_Defs() => "GestureDefinitions"
GestureSec_Gestures() => "Gestures"
GestureSec_Blacklist() => "GestureBlacklist"
GestureSec_Templates() => "GestureTemplates"
GestureSec_Disabled() => "GestureDisabled"
GestureSec_Desc() => "GestureDesc"
GestureLayer_Global() => "全局" ; i18n:protocol (全局层 ID, ini 存储 + 引擎比对)
GestureLayer_Template() => "模板" ; i18n:protocol (禁用集 ID 前缀)
GestureLayer_Blacklist() => "黑名单" ; i18n:protocol (禁用集 ID 前缀)
GestureLayer_App() => "应用层" ; i18n:protocol (禁用集 ID 前缀)
