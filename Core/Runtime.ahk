#Requires AutoHotkey v2.0
#Warn All, Off
; === Core/Runtime.ahk - 运行时状态聚合 (第一阶段: 集中存储) ===
; 方向: g_* 全局直读写收敛到 Runtime 容器; 第一阶段只要求"集中存储",
; 调用点迁移逐子系统进行 (Launcher → Vim → Runtime, 见各 Map 注释).
; 已迁移: 动作轨迹 (Trace, 原 g_ActionTrace).

class Runtime {
    ; 动作轨迹 (环形 50 条; 读写经 ActionTracePush/ActionLastTrace, 不直碰)
    static Trace := []
    ; 启动器状态 (迁移目标: g_CurrentInput/g_CurrentCommand/g_CurrentCommandList/g_Arg/g_HistoryCommands)
    static Launcher := Map()
    ; Vim 状态 (迁移目标: 模式/前缀/计数/活动窗; 引擎对象本身仍驻 g_VimEngine)
    static Vim := Map()
    ; 运行时状态 (迁移目标: g_Conf/g_AutoConf 引用/插件管理/搜索索引纪元)
    static State := Map()
}
