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
    "candidateList", []
)

global g_GestureMap := Map()       ; 全局层: 手势串 -> 动作串
global g_GestureApps := []         ; 应用层: [{name, exe, cls, map}]
global g_GestureBlacklist := []    ; 黑名单
global g_GestureAppPrefix := "GestureApp:"
global g_GestureDefs := Map()
global g_GestureDisabled := Map()  ; 禁用集: id -> 1
global g_GestureHookBefore := ""
global g_GestureHookAfter := ""
