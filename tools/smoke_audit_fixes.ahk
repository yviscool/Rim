#Requires AutoHotkey v2.0
#Warn All, Off

; === tools/smoke_audit_fixes.ahk - 验证 7 大修复点回归测试 ===

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

FileAppend("=== Smoke Test: Audit Fixes Verification ===`n", "*")

#Include ..\Core\Common.ahk
#Include ..\Core\I18n.ahk
#Include ..\Core\Config.ahk
#Include ..\Core\Context.ahk
#Include ..\Core\Command.ahk
#Include ..\Core\Window.ahk
#Include ..\Core\Workspace.ahk
#Include ..\Core\Engine.ahk
#Include ..\Core\Execution.ahk
#Include ..\Core\Gesture.ahk
#Include ..\Core\Plugin.ahk

; --- 测试 1: TC <cm_...> 动作前缀路由 ---
try {
    global g_VimEngine := VimEngine()
    global g_TCLastHandled := ""
    TcCmHandler(act) {
        global g_TCLastHandled
        g_TCLastHandled := act
        return true
    }
    g_VimEngine.RegisterPrefixActionHandler("cm_", TcCmHandler)

    ; 传入带角括号的 <cm_SelectAll>
    ExecuteAction("<cm_SelectAll>")
    Assert(g_TCLastHandled = "cm_SelectAll" || g_TCLastHandled = "<cm_SelectAll>", "TC <cm_SelectAll> correctly handled by cm_ prefix handler")

    ; 传入裸 cm_GoToParent
    g_TCLastHandled := ""
    ExecuteAction("cm_GoToParent")
    Assert(g_TCLastHandled = "cm_GoToParent", "TC cm_GoToParent correctly handled by cm_ prefix handler")
} catch Error as e {
    Assert(false, "Test 1 failed: " . e.Message)
}

; --- 测试 2: 命令注册幂等性 ---
try {
    catBefore := RimCommand.Categories.Has("TestCat") ? RimCommand.Categories["TestCat"].Length : 0
    RimCommand.Register("test.idempotent", "Test Title", (*) => 0, Map("Category", "TestCat"))
    RimCommand.Register("test.idempotent", "Test Title New", (*) => 0, Map("Category", "TestCat"))
    RimCommand.Register("test.idempotent", "Test Title Final", (*) => 0, Map("Category", "TestCat"))

    catAfter := RimCommand.Categories["TestCat"].Length
    Assert(catAfter = catBefore + 1, "RimCommand.Register is idempotent, categories not duplicated: count=" . catAfter)
    Assert(RimCommand.Get("test.idempotent").Title = "Test Title Final", "RimCommand.Get returns latest registered object")
} catch Error as e {
    Assert(false, "Test 2 failed: " . e.Message)
}

; --- 测试 3: 手势识别阈值分离 (移动像素 vs 模板置信度) ---
try {
    global g_Gesture, g_TplThreshold, g_GestureMap
    g_Gesture["threshold"] := 6 ; 像素移动阈值
    g_TplThreshold := 75        ; 模板置信度打分阈值
    g_GestureMap["LETTER_S"] := "test_act" ; 绑定手势目标

    ; 构造一个低分候选 (68 分)
    candLow := {name: "LETTER_S", method: "template", score: 68.0, action: "test_act", layer: "global"}
    decision := GestureEngine.SelectCandidate([candLow], "notepad.exe", "Notepad", "Test")
    Assert(decision.selected = "" && decision.reason = "below_threshold", "SelectCandidate: 68-score rejected when g_TplThreshold=75 despite g_Gesture['threshold']=6")

    ; 构造一个高分候选 (85 分)
    candHigh := {name: "LETTER_S", method: "template", score: 85.0, action: "test_act", layer: "global"}
    decision2 := GestureEngine.SelectCandidate([candHigh], "notepad.exe", "Notepad", "Test")
    Assert(IsObject(decision2.selected) && decision2.selected.score = 85.0, "SelectCandidate: 85-score accepted above threshold")
} catch Error as e {
    Assert(false, "Test 3 failed: " . e.Message)
}

; --- 测试 4: 动态注册新手势自动进入候选集 ---
try {
    GestureRegistry.Clear()
    ; 动态注册一个新图案
    GestureRegistry.Register("R_U_R", "test_action", "", {layer: "global"})
    Assert(g_GestureDefs.Has("R_U_R"), "GestureRegistry.Register automatically registered pattern in g_GestureDefs")

    ; 验证 CollectCandidates 可以收集到该动态手势
    cands := GestureEngine.CollectCandidates("R_U_R", [{x: 0, y: 0}, {x: 50, y: 0}, {x: 50, y: -50}, {x: 100, y: -50}])
    found := false
    for _, c in cands {
        if (c.name = "R_U_R") {
            found := true
            break
        }
    }
    Assert(found, "CollectCandidates includes dynamic registered gesture R_U_R")
} catch Error as e {
    Assert(false, "Test 4 failed: " . e.Message)
}

; --- 测试 5: LegacyVimPlugins 干净无死入口 ---
try {
    Assert(!RimPluginManager.LegacyVimPlugins.Has("MicrosoftExcel"), "LegacyVimPlugins does not contain MicrosoftExcel")
    Assert(!RimPluginManager.LegacyVimPlugins.Has("VimEditor"), "LegacyVimPlugins does not contain VimEditor")
    Assert(!RimPluginManager.LegacyVimPlugins.Has("VimEditorAdapters"), "LegacyVimPlugins does not contain VimEditorAdapters")
} catch Error as e {
    Assert(false, "Test 5 failed: " . e.Message)
}

; --- 测试 6: Context CheckIsInput 不误判 DirectUIHWND ---
try {
    isInputExplorer := RimContext.CheckIsInput("DirectUIHWND", "DirectUIHWND2", "CabinetWClass")
    Assert(!isInputExplorer, "CheckIsInput: DirectUIHWND file list in Explorer is NOT treated as text input")

    isInputRealEdit := RimContext.CheckIsInput("Edit", "Edit1", "CabinetWClass")
    Assert(isInputRealEdit, "CheckIsInput: Real Edit control in Explorer is treated as text input")
} catch Error as e {
    Assert(false, "Test 6 failed: " . e.Message)
}

; --- 测试 7: UrlEncode UTF-8 正确性 ---
try {
    encoded := UrlEncode("中文测试")
    Assert(encoded = "%E4%B8%AD%E6%96%87%E6%B5%8B%E8%AF%95", "UrlEncode: UTF-8 Chinese characters correctly percent-encoded")
} catch Error as e {
    Assert(false, "Test 7 failed: " . e.Message)
}

FileAppend("`n=== Summary: " . passed . " passed, " . failed . " failed ===`n", "*")
ExitApp(failed > 0 ? 1 : 0)
