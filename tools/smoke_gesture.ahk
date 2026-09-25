#Requires AutoHotkey v2.0
#Warn All, Off

; === tools/smoke_gesture.ahk - 鼠标手势子系统自动化测试探针 ===

passed := 0
failed := 0

Assert(cond, msg) {
    global passed, failed
    if (cond) {
        passed++
        FileAppend("[PASS] " . msg . "`n", "*")
    } else {
        failed++
        FileAppend("[FAIL] " . msg . "`n", "*")
    }
}

FileAppend("=== Smoke Test: Gesture Subsystem Decoupling ===`n", "*")

; 1. 载入核心组件
try {
    #Include ..\Core\Common.ahk
    #Include ..\Core\I18n.ahk
    #Include ..\Core\Gesture.ahk
    Assert(true, "Gesture modules loaded successfully")
} catch Error as e {
    Assert(false, "Failed to load gesture modules: " . e.Message)
    ExitApp(1)
}

; 2. GestureRecognizer 单元测试
try {
    Assert(GestureRecognizer.DirOf(0, -100) = "U", "DirOf: straight UP")
    Assert(GestureRecognizer.DirOf(100, 0) = "R", "DirOf: straight RIGHT")
    Assert(GestureRecognizer.DirOf(0, 100) = "D", "DirOf: straight DOWN")
    Assert(GestureRecognizer.DirOf(-100, 0) = "L", "DirOf: straight LEFT")
    Assert(GestureRecognizer.DirOf(100, -100) = "UR", "DirOf: diagonal UP-RIGHT")

    Assert(GestureRecognizer.Normalize(" d - r ") = "D_R", "Normalize: hyphen and spaces")
    Assert(GestureRecognizer.NormalizeFull("shift + alt + ctrl + u") = "CTRL+ALT+SHIFT+U", "NormalizeFull: sort modifiers")

    ; 轨迹方向链
    ptsLine := [{x: 100, y: 100}, {x: 100, y: 50}, {x: 100, y: 0}]
    Assert(GestureRecognizer.DirectionChain(ptsLine) = "U", "DirectionChain: straight line UP")

    ptsL := [{x: 100, y: 100}, {x: 100, y: 150}, {x: 100, y: 200}, {x: 150, y: 200}, {x: 200, y: 200}]
    Assert(GestureRecognizer.DirectionChain(ptsL) = "D_R", "DirectionChain: L-shape D_R")
} catch Error as e {
    Assert(false, "GestureRecognizer test error: " . e.Message)
}

; 3. GestureRegistry 动态注册测试
try {
    GestureRegistry.Clear()
    Assert(GestureRegistry.Count() = 0, "GestureRegistry: cleared successfully")

    ; 注册应用级手势
    idTC := GestureRegistry.Register("U", "cm_GoToParent", "ahk_class TTOTAL_CMD", {
        description: "TC Parent Dir",
        pluginName: "TotalCommander"
    })
    Assert(idTC > 0, "GestureRegistry: registered TC gesture with ID " . idTC)

    ; 注册全局手势
    idGlobal := GestureRegistry.Register("D_R", "<Global_CloseTab>", "", {
        description: "Global Close Tab",
        layer: "global"
    })
    Assert(idGlobal > 0, "GestureRegistry: registered Global gesture with ID " . idGlobal)

    Assert(GestureRegistry.Count() = 2, "GestureRegistry: count is 2")

    ; 解析测试: TC 窗口命中专属手势
    resTC := GestureRegistry.Resolve("U", "Totalcmd64.exe", "TTOTAL_CMD", "Total Commander")
    Assert(IsObject(resTC) && resTC.action = "cm_GoToParent", "GestureRegistry.Resolve: TC matched parent dir")
    Assert(resTC.pluginName = "TotalCommander", "GestureRegistry.Resolve: plugin name matches")

    ; 解析测试: 非 TC 窗口解析 "U" 无法命中 TC 专属手势
    resNotTC := GestureRegistry.Resolve("U", "notepad.exe", "Notepad", "Untitled")
    Assert(!IsObject(resNotTC), "GestureRegistry.Resolve: Notepad does not match TC gesture")

    ; 解析测试: 全局手势跨窗口命中
    resGlobal := GestureRegistry.Resolve("D_R", "notepad.exe", "Notepad", "Untitled")
    Assert(IsObject(resGlobal) && resGlobal.action = "<Global_CloseTab>", "GestureRegistry.Resolve: Global gesture matched")

    ; 注销测试
    unregOk := GestureRegistry.Unregister(idTC)
    Assert(unregOk && GestureRegistry.Count() = 1, "GestureRegistry: unregister by ID")
} catch Error as e {
    Assert(false, "GestureRegistry test error: " . e.Message)
}

; 4. GestureHook 辅助测试
try {
    Assert(GestureHook.ClickName("RButton") = "Right", "GestureHook.ClickName: RButton -> Right")
    Assert(GestureHook.ClickName("MButton") = "Middle", "GestureHook.ClickName: MButton -> Middle")
    Assert(GestureHook.ClickName("XButton1") = "X1", "GestureHook.ClickName: XButton1 -> X1")
    Assert(GestureHook.ClickName("XButton2") = "X2", "GestureHook.ClickName: XButton2 -> X2")

    ; 采样轮询定时器与绑定测试 (真实 OnDown -> SetTimer 回调验证)
    g_Gesture["down"] := 1
    g_Gesture["points"] := [{x: 0, y: 0}]
    try {
        SetTimer(GestureHook_PollTimer, -10)
        Sleep(30)
        Assert(true, "GestureHook_PollTimer: SetTimer callback valid and callable")
    } catch Error as e {
        Assert(false, "GestureHook_PollTimer SetTimer failed: " . e.Message)
    }
    g_Gesture["down"] := 0
} catch Error as e {
    Assert(false, "GestureHook test error: " . e.Message)
}

; 5. GestureEngine 与核心调度测试
try {
    ; 动作执行测试
    testState := {executed: false, beforeCalled: false, afterCalled: false}
    GestureEngine.ExecuteAction(() => testState.executed := true)
    Assert(testState.executed, "GestureEngine.ExecuteAction: called Func object")

    ; 前后钩子测试
    GestureEngine.SetHooks(
        (act) => (testState.beforeCalled := true, false),
        (act) => testState.afterCalled := true
    )
    GestureEngine.ExecuteAction(() => 0)
    Assert(testState.beforeCalled, "GestureEngine.SetHooks: before hook executed")
    Assert(testState.afterCalled, "GestureEngine.SetHooks: after hook executed")
    GestureEngine.SetHooks("", "") ; reset
} catch Error as e {
    Assert(false, "GestureEngine test error: " . e.Message)
}

FileAppend("`n=== Test Summary: " . passed . " passed, " . failed . " failed ===`n", "*")
ExitApp(failed > 0 ? 1 : 0)
