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

    ; 注册插件类 (返回结构化结果 Map{ok,id,name,version,replaced,msg})
    static Register(pluginClass) {
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

    ; 依赖解析 (Kahn 拓扑排序): 返回 Map{order, missing, cycles, disabled}.
    ; order: 无缺失/无环插件的初始化序 (依赖在前, 同层按注册序);
    ; missing: [{plugin, dep}]; cycles: [[names...]] (环成员全部禁用);
    ; 缺失/成环者统一 Disable (理由进 disabled + Registry disabledReason).
    static ResolveOrder() {
        rep := Map("order", [], "missing", [], "cycles", [], "disabled", [])
        names := []
        for key, info in RimPluginManager.Registry
            names.Push(key)
        bad := Map()
        ; 缺失依赖: 直接判死
        for _, key in names {
            info := RimPluginManager.Registry[key]
            deps := info.Has("deps") ? info["deps"] : []
            if (!IsObject(deps))
                continue
            for _, d in deps {
                ds := StrLower(Trim(String(d)))
                if (ds = "")
                    continue
                if (!RimPluginManager.Plugins.Has(ds) && !RimPluginManager.Registry.Has(ds)) {
                    rep["missing"].Push(Map("plugin", info["name"], "dep", String(d)))
                    if (!bad.Has(key)) {
                        bad[key] := true
                        rep["disabled"].Push(Map("plugin", info["name"], "reason", "missing dep " . String(d)))
                        RimPluginManager.Disable(info["name"], "missing dep " . String(d))
                    }
                }
            }
        }
        ; Kahn 分层 (只看存活节点; 依赖写法 Id/Name 大小写不敏感, 统一 Registry key 比对)
        keyOf := Map()
        for _, key in names {
            info := RimPluginManager.Registry[key]
            keyOf[StrLower(String(info["name"]))] := key
            try {
                if (String(info["id"]) != "")
                    keyOf[StrLower(String(info["id"]))] := key
            }
            keyOf[key] := key
        }
        indeg := Map()
        dependents := Map()
        alive := []
        for _, key in names {
            if (bad.Has(key))
                continue
            alive.Push(key)
            indeg[key] := 0
            dependents[key] := []
        }
        for _, key in alive {
            info := RimPluginManager.Registry[key]
            deps := info.Has("deps") ? info["deps"] : []
            if (!IsObject(deps))
                continue
            seen := Map()
            for _, d in deps {
                dk := StrLower(Trim(String(d)))
                if (dk = "" || !keyOf.Has(dk) || seen.Has(dk))
                    continue
                seen[dk] := true
                depKey := keyOf[dk]
                if (depKey = key || bad.Has(depKey))
                    continue
                indeg[key]++
                dependents[depKey].Push(key)
            }
        }
        ready := []
        for _, key in alive {
            if (indeg[key] = 0)
                ready.Push(key)
        }
        while (ready.Length > 0) {
            cur := ready.RemoveAt(1)
            rep["order"].Push(cur)
            for _, nxt in dependents[cur] {
                indeg[nxt]--
                if (indeg[nxt] = 0)
                    ready.Push(nxt)
            }
        }
        ; 未产出即环成员 (含自依赖): 整环禁用
        if (rep["order"].Length < alive.Length) {
            ring := []
            for _, key in alive {
                hit := false
                for _, ok in rep["order"] {
                    if (ok = key) {
                        hit := true
                        break
                    }
                }
                if (!hit)
                    ring.Push(RimPluginManager.Registry[key]["name"])
            }
            if (ring.Length > 0) {
                rep["cycles"].Push(ring)
                for _, pname in ring {
                    rep["disabled"].Push(Map("plugin", pname, "reason", "dependency cycle"))
                    RimPluginManager.Disable(pname, "dependency cycle")
                }
            }
        }
        return rep
    }

    static CheckDependencies() {
        return RimPluginManager.ResolveOrder()
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

    ; IsEnabled 缓存 (配置节扫描只做一次; InitAll 起手清空, 启动期配置静态)
    static EnabledCache := Map()

    ; 校验插件是否在配置中启用（[Plugins] 键大小写不敏感：先精确命中，缺失再扫全节比对）
    static IsEnabled(name) {
        key := StrLower(Trim(String(name)))
        if (RimPluginManager.EnabledCache.Has(key))
            return RimPluginManager.EnabledCache[key]
        on := RimPluginManager.IsEnabledRaw(name)
        RimPluginManager.EnabledCache[key] := on
        return on
    }

    static IsEnabledRaw(name) {
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

    ; 有序插件键 (依赖在前; 未解析出序时回退注册序, 永不空跑)
    static OrderedKeys() {
        try {
            rep := RimPluginManager.ResolveOrder()
            if (rep["order"].Length > 0)
                return rep["order"]
        } catch {
        }
        out := []
        for key in RimPluginManager.EnabledPlugins
            out.Push(key)
        return out
    }

    ; 阶段快照 (命令表/按键表/上下文/手势发号; 回滚基准)
    static BeginTx(engine := "") {
        tx := Map("cmds", Map(), "keys", "", "ctx", [], "gestureNext", 0)
        try {
            if (IsSet(RimCommand) && IsObject(RimCommand)) {
                for id, cmd in RimCommand.Registry
                    tx["cmds"][id] := cmd
            }
        } catch {
        }
        try {
            if (IsObject(engine) && HasMethod(engine, "SnapshotKeys"))
                tx["keys"] := engine.SnapshotKeys()
        } catch {
        }
        try {
            if (IsSet(RimContext) && IsObject(RimContext)) {
                for pid in RimContext.Providers
                    tx["ctx"].Push(pid)
            }
        } catch {
        }
        try {
            if (IsSet(GestureRegistry) && IsObject(GestureRegistry))
                tx["gestureNext"] := GestureRegistry._nextId + 0
        } catch {
        }
        return tx
    }

    ; 阶段回滚 (删本阶段新增, 恢复被覆盖; 返回 Map{commands, keys, wins, modes, actions, ctx, gestures})
    static RollbackTx(tx, engine := "") {
        done := Map("commands", 0, "keys", 0, "wins", 0, "modes", 0, "actions", 0, "ctx", 0, "gestures", 0)
        try {
            if (IsSet(RimCommand) && IsObject(RimCommand) && tx.Has("cmds")) {
                gone := []
                for id in RimCommand.Registry {
                    if (!tx["cmds"].Has(id))
                        gone.Push(id)
                }
                for _, id in gone {
                    if (RimCommand.Unregister(id))
                        done["commands"]++
                }
                for id, cmd in tx["cmds"] {
                    try {
                        if (RimCommand.Registry.Has(id) && RimCommand.Registry[id] !== cmd) {
                            RimCommand.Registry[id] := cmd
                            RimCommand.Seq++
                        }
                    }
                }
            }
        } catch {
        }
        try {
            if (IsObject(engine) && IsObject(tx["keys"]) && HasMethod(engine, "RollbackKeys")) {
                kr := engine.RollbackKeys(tx["keys"])
                try done["keys"] := kr["keys"] + 0
                try done["wins"] := kr["wins"] + 0
                try done["modes"] := kr["modes"] + 0
                try done["actions"] := kr["actions"] + 0
            }
        } catch {
        }
        try {
            if (IsSet(RimContext) && IsObject(RimContext) && tx.Has("ctx")) {
                for pid in RimContext.Providers {
                    hit := false
                    for _, old in tx["ctx"] {
                        if (old = pid) {
                            hit := true
                            break
                        }
                    }
                    if (!hit) {
                        try RimContext.Providers.Delete(pid)
                        catch {
                        }
                        done["ctx"]++
                    }
                }
            }
        } catch {
        }
        try {
            if (IsSet(GestureRegistry) && IsObject(GestureRegistry) && (tx["gestureNext"] + 0) > 0)
                done["gestures"] := GestureRegistry.TrimSince(tx["gestureNext"]) + 0
        } catch {
        }
        return done
    }

    ; 单阶段运行器 (有序 + 事务: 某插件本阶段失败 → 回滚本阶段注册并整插件禁用,
    ; 后续阶段跳过, 杜绝半套命令/热键)
    static RunPhase(stage, engine := "") {
        n := 0
        for _, key in RimPluginManager.OrderedKeys() {
            if (!RimPluginManager.EnabledPlugins.Has(key))
                continue
            pCls := RimPluginManager.EnabledPlugins[key]
            pName := ""
            try pName := pCls.Name
            catch {
                continue
            }
            failsBefore := RimPluginManager.Failures.Length
            tx := RimPluginManager.BeginTx(engine)
            try {
                if (HasMethod(pCls, stage)) {
                    if (IsObject(engine) && stage = "RegisterKeymaps")
                        pCls.%stage%(engine)
                    else
                        pCls.%stage%()
                }
            } catch as e {
                RimPluginManager.RecordFailure(stage, pName, e)
            }
            if (RimPluginManager.Failures.Length > failsBefore) {
                rb := RimPluginManager.RollbackTx(tx, engine)
                try RimPluginManager.Disable(pName, stage . " failed, rolled back")
                catch {
                }
                try RimLog("PLUGIN_ERR", pName . "." . stage . " rolled back"
                    . " commands=" . rb["commands"] . " keys=" . rb["keys"] . " gestures=" . rb["gestures"])
                catch {
                }
            } else {
                n++
            }
        }
        return n
    }

    ; 阶段 1: 初始化所有激活插件 (依赖序; 沙箱保护, 首败即整插件禁用)
    static InitAll() {
        RimPluginManager.EnabledPlugins := Map()
        RimPluginManager.EnabledCache := Map()
        rep := ""
        try rep := RimPluginManager.ResolveOrder()
        catch {
        }
        order := []
        try {
            if (IsObject(rep) && rep["order"].Length > 0)
                order := rep["order"]
        }
        if (order.Length = 0) {
            for key in RimPluginManager.Plugins
                order.Push(key)
        }
        for _, key in order {
            if (!RimPluginManager.Plugins.Has(key))
                continue
            pCls := RimPluginManager.Plugins[key]
            pName := ""
            try pName := pCls.Name
            catch {
                continue
            }
            if (RimPluginManager.IsEnabled(pName)) {
                RimPluginManager.EnabledPlugins[key] := pCls
                failsBefore := RimPluginManager.Failures.Length
                RimPluginManager._SafeCall(pCls, "Init", pName)
                if (RimPluginManager.Failures.Length > failsBefore) {
                    try RimPluginManager.Disable(pName, "Init failed")
                    catch {
                    }
                    try RimPluginManager.EnabledPlugins.Delete(key)
                    catch {
                    }
                }
            }
        }
    }

    ; 阶段 2: 注册所有插件的 Context Provider
    static RegisterAllContexts() {
        return RimPluginManager.RunPhase("RegisterContext")
    }

    ; 阶段 3: 注册所有插件的语义指令 (RimCommand)
    static RegisterAllCommands() {
        return RimPluginManager.RunPhase("RegisterCommands")
    }

    ; 阶段 4: 注册所有插件的按键映射 (向 VimEngine 注入)
    static RegisterAllKeymaps(engine) {
        return RimPluginManager.RunPhase("RegisterKeymaps", engine)
    }

    ; 阶段 5: 注册所有插件的手势映射
    static RegisterAllGestures() {
        return RimPluginManager.RunPhase("RegisterGestures")
    }

    ; 阶段 6: 进程退出或重载时优雅注销
    static OnExitAll() {
        for key, pCls in RimPluginManager.EnabledPlugins {
            RimPluginManager._SafeCall(pCls, "OnExit", pCls.Name)
        }
    }

    ; 失败记录 (Failures + 日志 + 观测; _SafeCall 与 RunPhase 共用)
    static RecordFailure(stage, pluginName, err) {
        msg := ""
        try msg := err.Message
        catch {
            try msg := String(err)
            catch {
                msg := "unknown error"
            }
        }
        RimPluginManager.Failures.Push(Map("stage", stage, "plugin", pluginName, "msg", msg, "at", A_Now))
        RimPluginManager._LogErr(pluginName . "." . stage, err)
        try ObsRecordFailure(stage, pluginName, msg)
        catch {
        }
    }

    ; 沙箱隔离执行: 捕获单点异常，防止单个插件故障拖垮内核
    static _SafeCall(targetCls, methodName, pluginName, args*) {
        try {
            if (HasMethod(targetCls, methodName)) {
                targetCls.%methodName%(args*)
            }
        } catch as e {
            RimPluginManager.RecordFailure(methodName, pluginName, e)
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
