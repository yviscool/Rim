#Requires AutoHotkey v2.0
#Warn All, Off

; === Core/Plugin.ahk - Rim 统一插件生命周期架构 (Unified Plugin Architecture) ===
; 标准化插件契约 (Lifecycle Contract) 与隔离执行沙箱 (Sandbox Manager)
; 彻底拔除旧式双轨制加载与黑名单硬编码，提供即插即用、单文件自闭环的模块化扩展体系

; ==============================================================================
; 1. 基础插件契约类: 供新式插件继承并按需实现各生命周期方法
; ==============================================================================
class RimPlugin {
    static Name => ""              ; 插件唯一代号 (如 "Explorer", "TotalCommander")
    static Title => ""             ; 插件显示名称
    static Author => "Rim"         ; 作者
    static Description => ""       ; 功能说明
    static Version => "1.0.0"      ; 版本号

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
; 2. 插件管理器单例: 负责插件生命周期编排、沙箱隔离与向下兼容适配
; ==============================================================================
class RimPluginManager {
    static Plugins := Map()         ; 已注册的 Modern Plugin 类 (Key: 小写名称)
    static EnabledPlugins := Map()  ; 已激活的 Plugin 类
    ; 历史 VimDesktop 插件名表 (旧插件尚未重构为 RimPlugin 类时，在此维持安全分发)
    static LegacyVimPlugins := Map(
        "General", 1, "Explorer", 1, "TCCompare", 1, "WinMerge", 1,
        "BeyondCompare4", 1, "Foobar2000", 1, "TCDialog", 1, "TotalCommander", 1,
        "StrokePlus", 1, "VimDConfig", 1
    )

    ; 注册插件类
    static Register(pluginClass) {
        if (!IsObject(pluginClass))
            return false

        name := ""
        try name := pluginClass.Name
        if (name = "")
            return false

        key := StrLower(Trim(name))
        RimPluginManager.Plugins[key] := pluginClass
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

    ; 校验插件是否在配置中启用
    static IsEnabled(name) {
        global g_Conf
        if (IsSet(g_Conf) && IsObject(g_Conf) && g_Conf.HasSection("Plugins")) {
            val := g_Conf.Get("Plugins", name, "1")
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

    ; === 向下兼容适配器 (Legacy Adapters) ===
    ; 针对尚未重构为类的旧式 RunZ 命令插件 (在 LoadFiles 阶段执行命令注入)
    static LoadLegacyCommandPlugins(pluginList) {
        for idx, pName in pluginList {
            key := StrLower(Trim(pName))
            ; 若已是 Modern 插件或属于 Legacy Vim 插件，跳过 (按各阶段正常接入)
            if (RimPluginManager.Plugins.Has(key) || RimPluginManager.LegacyVimPlugins.Has(pName))
                continue

            if (!RimPluginManager.IsEnabled(pName))
                continue

            fnName := "RegisterPlugin_" . pName
            fn := ""
            try fn := %fnName%
            catch {
                continue
            }
            if (!IsObject(fn) || !HasMethod(fn, "Call"))
                continue

            try {
                fn()
            } catch Error as e {
                RimPluginManager._LogErr("LegacyCommand:" . pName, e)
            }
        }
    }

    ; 针对尚未重构为类的旧式 VimDesktop 插件 (在 VimEngine 实例化后执行按键注入)
    static LoadLegacyVimPlugins(pluginList) {
        for idx, pName in pluginList {
            key := StrLower(Trim(pName))
            ; 若已是 Modern 插件，跳过 (已统一走 RegisterAllKeymaps)
            if (RimPluginManager.Plugins.Has(key))
                continue

            if (!RimPluginManager.LegacyVimPlugins.Has(pName))
                continue

            if (!RimPluginManager.IsEnabled(pName))
                continue

            fnName := "RegisterPlugin_" . pName
            fn := ""
            try fn := %fnName%
            catch {
                continue
            }
            if (!IsObject(fn) || !HasMethod(fn, "Call"))
                continue

            try {
                fn()
            } catch Error as e {
                RimPluginManager._LogErr("LegacyVim:" . pName, e)
            }
        }
    }

    ; 沙箱隔离执行: 捕获单点异常，防止单个插件故障拖垮内核
    static _SafeCall(targetCls, methodName, pluginName, args*) {
        try {
            if (HasMethod(targetCls, methodName)) {
                targetCls.%methodName%(args*)
            }
        } catch Error as e {
            RimPluginManager._LogErr(pluginName . "." . methodName, e)
        }
    }

    static _LogErr(where, err) {
        try {
            msg := A_Now . " [PLUGIN_ERR] " . where . ": " . err.Message . " @ " . err.File . ":" . err.Line . "`n"
            FileAppend(msg, A_ScriptDir . "\Rim.error.log")
        } catch {
        }
    }
}
