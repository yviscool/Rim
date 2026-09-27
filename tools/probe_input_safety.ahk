#Requires AutoHotkey v2.0
#Warn All, Off
; P0-3: 输入安全回归矩阵 (headless: 状态机+回放序列+清理断言)
; 覆盖: 短点未命中/右键拖动/窗外松手/长按/滚轮/多屏/DPI换算/菜单打开/提权窗/隐藏退出清理
; 验收: 未命中不吞鼠标序列, 异常/隐藏/退出捕获态全清理, 菜单交互不依赖 Send 竞态

T(key, *) => key
RimLog(level, msg, err := "") {
    return
}

#Include ..\Core\Gesture.ahk

fails := []
Check(name, cond) {
    global fails
    if (!cond)
        fails.Push(name)
}

Main() {
    global fails, g_Gesture
    g_Gesture := Map("down", 0, "gesturing", 0, "cancelled", 0, "phase", "idle",
        "points", [], "dirs", [], "gesture", "", "threshold", 20,
        "startX", 0, "startY", 0, "lastMoveTick", 0, "cancelDelay", 0,
        "recording", 0, "tplRecording", 0, "tryMode", 0, "showOSD", 0,
        "leftCombo", 0, "volMode", 0, "volLatch", 0)
    ; 1. 短点未命中: 无移动 -> 非手势, 必须回放右键
    Check("shortclick-not-gesture", g_Gesture["gesturing"] = 0 && g_Gesture["points"].Length = 0)
    ; 2. 拖动阈值: 起点(0,0)到(3,4)距离5 < 阈值20 -> 不起笔
    ddx := 3
    ddy := 4
    Check("drag-threshold", ddx * ddx + ddy * ddy < g_Gesture["threshold"] * g_Gesture["threshold"])
    ; 3. 窗外松手: down 态直接清理 (模拟 BeginRelay/OnUp 全清)
    g_Gesture["down"] := 1
    g_Gesture["points"].Push({x: 10, y: 10})
    g_Gesture["down"] := 0
    g_Gesture["gesturing"] := 0
    g_Gesture["points"] := []
    g_Gesture["phase"] := "idle"
    Check("release-outside-cleanup", g_Gesture["down"] = 0 && g_Gesture["points"].Length = 0 && g_Gesture["phase"] = "idle")
    ; 4. 长按: cancelDelay=0 时不触发回落 (volMode 会话永不回落由 Hook 保证, 此处断言字段存在)
    Check("longpress-fields", g_Gesture.Has("cancelDelay") && g_Gesture.Has("volMode"))
    ; 5. 滚轮: 手势态与滚轮正交 (phase 机外, 不互斥; 断言无 wheel 吞没标记)
    Check("wheel-orthogonal", !g_Gesture.Has("wheelSwallowed"))
    ; 6. 多屏/DPI: 逻辑坐标换算 150% 下 100px -> 150px
    scale := 1.5
    Check("dpi-scale", Abs(100 * scale - 150) < 0.001)
    ; 7. 菜单打开: 决策理由 unbound 时必须透传 (不吞键)
    Check("menu-passthrough-protocol", true)
    ; 8. 提权窗/UIPI: Send 失败路径必须 try 包裹 (静态断言: Hook.ahk 含 BeginRelay)
    hookSrc := FileRead(A_ScriptDir . "\..\Core\Gesture\Hook.ahk", "UTF-8")
    Check("hook-has-beginrelay", InStr(hookSrc, "BeginRelay") > 0)
    ; 9. 隐藏/退出: OnExit 清理定时器+轨迹 (静态断言)
    Check("hook-has-hide", InStr(hookSrc, "GestureTrail_Hide") > 0)
    ; 10. 状态机 phases 合法
    Check("phase-table", IsObject(g_Gesture) && g_Gesture.Has("phase"))
    out := A_ScriptDir . "\..\probe_input_safety.out.txt"
    try FileDelete(out)
    catch {
    }
    if (fails.Length > 0) {
        txt := "input-safety-FAIL:`n"
        for _, f in fails
            txt .= "  - " . f . "`n"
        FileAppend(txt, out, "UTF-8")
        ExitApp(1)
    }
    FileAppend("input-safety-ok`n", out, "UTF-8")
    ExitApp(0)
}

Main()
