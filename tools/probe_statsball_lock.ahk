#Requires AutoHotkey v2.0
#Warn All, Off

; 回归探针: 雷达 LockPos 热应用链 (用户报"配置中心打勾不生效, 始终能拖")
; 覆盖: Init 订阅注册 → CfgPublish 广播 → StatsBall_ApplyConfig 落对象 →
; 构造期从 ini 读值. 全程不建 Gui (构造/Apply 皆无窗口依赖).
T(key, *) => key

#Include ..\Lib\EasyIni.ahk
#Include ..\Core\Plugin.ahk
#Include ..\Core\ConfigSchema.ahk
#Include ..\Plugins\StatsBall.ahk

Assert(cond, msg) {
    if (!cond) {
        FileAppend("FAIL: " . msg . "`n", "*")
        ExitApp(1)
    }
    FileAppend("PASS: " . msg . "`n", "*")
}

global g_Conf := EasyIni(A_ScriptDir . "\..\Conf\rim.ini")
Assert(IsObject(g_Conf), "conf-load")

; schema 侧 LockPos 必须是 live (否则保存只攒重启单, 不广播)
Assert(CfgScope("StatsBall", "LockPos") = "live", "lockpos-scope-live")

; Init 注册 9 键订阅 (抛错即挂, 订阅漏了热应用全死)
StatsBallPlugin.Init()
Assert(g_CfgSubs.Has("StatsBall" . Chr(1) . "LockPos"), "sub-lockpos")
Assert(g_CfgSubs["StatsBall" . Chr(1) . "LockPos"].Length >= 1, "sub-lockpos-n")

; 构造期从 ini 读值 (现网 ini LockPos=1 → 对象直接锁死)
global g_StatsBall := StatsBallObj()
Assert(IsObject(g_StatsBall), "obj-born")
Assert(g_StatsBall.lockPos = true, "init-lock-from-ini")

; 模拟取消勾选: 内存同步 + 广播 → 对象解锁
g_Conf.Set("StatsBall", "LockPos", "0")
pub := CfgPublish([Map("sec", "StatsBall", "key", "LockPos", "val", "0")])
Assert(pub["ok"], "publish-ok-unlock")
Assert(g_StatsBall.lockPos = false, "apply-unlock")

; 模拟打勾: 广播 → 对象上锁 (用户报障的正向路径)
g_Conf.Set("StatsBall", "LockPos", "1")
pub := CfgPublish([Map("sec", "StatsBall", "key", "LockPos", "val", "1")])
Assert(pub["ok"], "publish-ok-lock")
Assert(g_StatsBall.lockPos = true, "apply-lock")

; 对象缺失时广播不抛 (启动早期/隐藏态)
g_StatsBall := ""
pub := CfgPublish([Map("sec", "StatsBall", "key", "LockPos", "val", "1")])
Assert(pub["ok"], "publish-noobj-safe")

try FileDelete(A_ScriptDir . "\..\probe_statsball_lock.out.txt")
FileAppend("probe-statsball-lock-ok`n", A_ScriptDir . "\..\probe_statsball_lock.out.txt")
ExitApp(0)
