#Requires AutoHotkey v2.0
#Warn All, Off

; === Core/Plugin.ahk - Rim 统一插件生命周期架构 (Unified Plugin Architecture) ===
; 标准化插件契约 (Lifecycle Contract) 与隔离执行沙箱 (Sandbox Manager)
; 全插件经 RimPlugin 六阶段直注引擎/注册表, 无双轨分发; OnExitAll 由 Rim_OnExit 触发

; ==============================================================================
; 1. 基础插件契约类: 供新式插件继承并按需实现各生命周期方法
; ==============================================================================
class RimPlugin {
    static Name => ""              ; 插件唯一代号 (如 "Explorer", "TotalCommander")
    static Title => ""             ; 插件显示名称
    static Author => "Rim"         ; 作者
    static Description => ""       ; 功能说明
    static Version => "1.0.0"      ; 版本号
    ; P1-6 契约第二版 (全可选, 缺省零行为变化)
    static Id => ""                ; 稳定 ID, 缺省回退 Name
    static ApiVersion => "1"       ; 声明兼容的 Rim API 主版本
    static Dependencies => []      ; 依赖的插件 Id/Name 数组
    static Capabilities => []      ; 能力声明: commands/keymaps/gestures/context/provider

    ; 生命周期阶段 1: 自身基础数据初始化 (读取专属配置、创建内部状态)
    static Init() {
    }

    ; 生命周期阶段 2: 注册上下文感知 Provider (向 Core/Context 注入)
    static RegisterContext() {
    }

    ; 生命周期阶段 3: 注册系统/应用级一级语义指令 (向 Core/Command 注册)
    static RegisterCommands() {
    }

    ; 生命周期阶段 4: 注册按键映射与窗口模式 (向 Core/Engine 注册)
    static RegisterKeymaps(engine) {
    }

    ; 生命周期阶段 5: 注册专属鼠标手势 (向 Core/Gesture 注册)
    static RegisterGestures() {
    }

    ; 生命周期阶段 6: 退出/重载资源释放 (清理外部钩子、专属定时器)
    static OnExit() {
    }
}

; ==============================================================================
; 2. 插件管理器单例: 负责插件生命周期编排与沙箱隔离执行
; ==============================================================================
class RimPluginManager {
    static Plugins := Map()         ; 已注册的 Plugin 类 (Key: 小写名称)
    static EnabledPlugins := Map()  ; 已激活的 Plugin 类
    static Registry := Map()        ; P1-6: key -> Map(cls, id, version, api, deps, caps, at)
    static CommandOwners := Map()   ; P1-6: commandId -> pluginName (冲突检测)
    static HotkeyOwners := Map()    ; P1-6: hotkey -> pluginName
    static GestureOwners := Map()   ; P1-6: gesture -> pluginName
    static Conflicts := []          ; P1-6: Array of Map(type,id,a,b,at)
    static Failures := []           ; P1-6: Array of Map(stage,plugin,msg,at)

    ; 注册插件类 (P1-6: 返回结构化结果, 保持 true/false 兼容: res["ok"])
    static Register(pluginClass) {
        res := RimPluginManager.RegisterEx(pluginClass)
        return res["ok"]
    }

    static RegisterEx(pluginClass) {
        if (!IsObject(pluginClass))
            return Map("ok", false, "id", "", "msg", "not an object")
        name := ""
        try name := pluginClass.Name
        if (name = "")
            return Map("ok", false, "id", "", "msg", "empty name")
        id := name
        try {
            if (pluginClass.Id != "")
                id := pluginClass.Id
        }
        ver := "1.0.0"
        try ver := pluginClass.Version
        api := "1"
        try api := pluginClass.ApiVersion
        deps := []
        try deps := pluginClass.Dependencies
        caps := []
        try caps := pluginClass.Capabilities
        key := StrLower(Trim(name))
        replaced := RimPluginManager.Plugins.Has(key) ? RimPluginManager.Plugins[key].Name : ""
        RimPluginManager.Plugins[key] := pluginClass
        RimPluginManager.Registry[key] := Map("cls", pluginClass, "id", id, "name", name, "version", ver, "api", api, "deps", deps, "caps", caps, "at", A_Now, "replaced", replaced, "disabledReason", "")
        if (replaced != "")
            RimPluginManager.Conflicts.Push(Map("type", "plugin", "id", name, "a", replaced, "b", name, "at", A_Now))
        return Map("ok", true, "id", id, "name", name, "version", ver, "replaced", replaced, "msg", "")
    }

    static Disable(name, reason := "") {
        key := StrLower(Trim(name))
        try RimPluginManager.EnabledPlugins.Delete(key)
        catch {
        }
        if (RimPluginManager.Registry.Has(key))
            RimPluginManager.Registry[key]["disabledReason"] := reason
        try ObsRecordFailure("plugin", name, "disabled: " . reason)
    }

    static CheckDependencies() {
        missing := []
        for key, info in RimPluginManager.Registry {
            deps := info.Has("deps") ? info["deps"] : []
            if (!IsObject(deps))
                continue
            for _, d in deps {
                dk := StrLower(Trim(String(d)))
                if (dk = "" || RimPluginManager.Plugins.Has(dk))
                    continue
                missing.Push(Map("plugin", info["name"], "dep", d))
                RimPluginManager.Disable(info["name"], "missing dep " . d)
            }
        }
        return missing
    }

    ; 命令/热键/手势冲突登记 (先到先得拥有, 后者记冲突但不阻塞)
    static ClaimCommand(cmdId, pluginName) {
        k := StrLower(Trim(cmdId))
        if (RimPluginManager.CommandOwners.Has(k)) {
            RimPluginManager.Conflicts.Push(Map("type", "command", "id", cmdId, "a", RimPluginManager.CommandOwners[k], "b", pluginName, "at", A_Now))
            return false
        }
        RimPluginManager.CommandOwners[k] := pluginName
        return true
    }

    static ClaimHotkey(hk, pluginName) {
        k := StrLower(Trim(hk))
        if (RimPluginManager.HotkeyOwners.Has(k)) {
            RimPluginManager.Conflicts.Push(Map("type", "hotkey", "id", hk, "a", RimPluginManager.HotkeyOwners[k], "b", pluginName, "at", A_Now))
            return false
        }
        RimPluginManager.HotkeyOwners[k] := pluginName
        return true
    }

    static ClaimGesture(ge, pluginName) {
        k := StrLower(Trim(ge))
        if (RimPluginManager.GestureOwners.Has(k)) {
            RimPluginManager.Conflicts.Push(Map("type", "gesture", "id", ge, "a", RimPluginManager.GestureOwners[k], "b", pluginName, "at", A_Now))
            return false
        }
        RimPluginManager.GestureOwners[k] := pluginName
        return true
    }

    ; 获取已注册的插件
    static Get(name) {
        key := StrLower(Trim(name))
        if (RimPluginManager.Plugins.Has(key))
            return RimPluginManager.Plugins[key]
        return ""
    }

    ; 获取所有已注册的插件列表
    static List() {
        list := []
        for key, cls in RimPluginManager.Plugins
            list.Push(cls)
        return list
    }

    ; 校验插件是否在配置中启用（[Plugins] 键大小写不敏感：先精确命中，缺失再扫全节比对）
    static IsEnabled(name) {
        global g_Conf
        if (IsSet(g_Conf) && IsObject(g_Conf) && g_Conf.HasSection("Plugins")) {
            val := g_Conf.Get("Plugins", name, "__MISSING__")
            if (val = "__MISSING__") {
                try {
                    for k, v in g_Conf.GetSection("Plugins") {
                        if (StrLower(k) = StrLower(name)) {
                            val := v
                            break
                        }
                    }
                }
                if (val = "__MISSING__")
                    return true
            }
            return (val != "0")
        }
        return true
    }

    ; 阶段 1: 初始化所有激活插件 (沙箱保护)
    static InitAll() {
        RimPluginManager.EnabledPlugins := Map()
        for key, pCls in RimPluginManager.Plugins {
            pName := pCls.Name
            if (RimPluginManager.IsEnabled(pName)) {
                RimPluginManager.EnabledPlugins[key] := pCls
                RimPluginManager._SafeCall(pCls, "Init", pName)
            }
        }
    }

    ; 阶段 2: 注册所有插件的 Context Provider
    static RegisterAllContexts() {
        for key, pCls in RimPluginManager.EnabledPlugins {
            RimPluginManager._SafeCall(pCls, "RegisterContext", pCls.Name)
        }
    }

    ; 阶段 3: 注册所有插件的语义指令 (RimCommand)
    static RegisterAllCommands() {
        for key, pCls in RimPluginManager.EnabledPlugins {
            RimPluginManager._SafeCall(pCls, "RegisterCommands", pCls.Name)
        }
    }

    ; 阶段 4: 注册所有插件的按键映射 (向 VimEngine 注入)
    static RegisterAllKeymaps(engine) {
        for key, pCls in RimPluginManager.EnabledPlugins {
            RimPluginManager._SafeCall(pCls, "RegisterKeymaps", pCls.Name, engine)
        }
    }

    ; 阶段 5: 注册所有插件的手势映射
    static RegisterAllGestures() {
        for key, pCls in RimPluginManager.EnabledPlugins {
            RimPluginManager._SafeCall(pCls, "RegisterGestures", pCls.Name)
        }
    }

    ; 阶段 6: 进程退出或重载时优雅注销
    static OnExitAll() {
        for key, pCls in RimPluginManager.EnabledPlugins {
            RimPluginManager._SafeCall(pCls, "OnExit", pCls.Name)
        }
    }

    ; 沙箱隔离执行: 捕获单点异常，防止单个插件故障拖垮内核
    static _SafeCall(targetCls, methodName, pluginName, args*) {
        try {
            if (HasMethod(targetCls, methodName)) {
                targetCls.%methodName%(args*)
            }
        } catch Error as e {
            RimPluginManager.Failures.Push(Map("stage", methodName, "plugin", pluginName, "msg", e.Message, "at", A_Now))
            RimPluginManager._LogErr(pluginName . "." . methodName, e)
            try ObsRecordFailure(methodName, pluginName, e.Message)
        }
    }

    static _LogErr(where, err) {
        ; RimLog 常驻 (Core/Utils.ahk); 探针等未包含 Utils 时回落直写 (外层 try 兜底)
        try {
            RimLog("PLUGIN_ERR", where, err)
        } catch {
            try {
                msg := A_Now . " [PLUGIN_ERR] " . where . ": " . err.Message . " @ " . err.File . ":" . err.Line . "`n"
                FileAppend(msg, A_ScriptDir . "\Rim.error.log")
            } catch {
            }
        }
    }
}

; P1-6 兼容函数: 冲突/失败报告查询
PluginConflicts() {
    try return RimPluginManager.Conflicts
    catch {
        return []
    }
}

PluginFailures() {
    try return RimPluginManager.Failures
    catch {
        return []
    }
}
