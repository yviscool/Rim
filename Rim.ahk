#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, Off

FileEncoding "UTF-8"
SendMode "Input"
SetWorkingDir(A_ScriptDir)
; 启动瞬间先藏托盘图标: 解释器一起就带默认菜单, 藏到自建菜单就绪再亮,
; 用户就看不到默认菜单闪现 (ShowTrayIcon=0 则全程隐藏, 原先启动期会短暂冒出)
try A_IconHidden := true
catch {
}
try TraySetIcon(A_ScriptDir . "\Assets\Rim.ico")
catch {
}
; 启动计时原点 + 错误日志轮转 (函数来自 Core/Common.ahk, 编译期可用)
global g_BootT0 := A_TickCount
; 启动阶段表 (RimPhaseBegin/End 打点; OnError 按当前阶段归因; BootPhases() 供诊断查询)
global g_BootPhases := []
global g_BootPhase := "early"
try RotateErrorLog()
catch {
}
; 重启链路灯: 进程一起就记, 若卡死/崩溃, 日志停在哪段一目了然
BootMark("STARTUP begin")
; 防洪阈值对齐 v1 (#MaxHotkeysPerInterval 200 等价)
A_MaxHotkeysPerInterval := 200
; i18n 抢跑: g_Conf 尚未加载, 先按 OS 语言起 (备份提示/配置失败提示要用)
I18nBoot()
; 构建号 (配置中心帮助页显示, 日志 BUILD 行同源)
global g_BuildTag := "20260926-O3BRIDGE"

; ==================== 兼容层: 供插件引用 Rim.xxx ====================
class Rim {
    static appDir := A_ScriptDir
    static config := ""
    static vim := ""
    static launcher := ""
}

; ==================== 全局变量 ====================
; 配置文件路径
global g_SearchFileList := A_ScriptDir . "\Conf\SearchFileList.txt"
global g_UserFileList := A_ScriptDir . "\Conf\UserFileList.txt"
global g_ConfFile := A_ScriptDir . "\Conf\rim.ini"
global g_AutoConfFile := A_ScriptDir . "\Conf\rim.auto.ini"

; 备份恢复
if (FileExist(g_AutoConfFile ".EasyIni.bak")) {
    MsgBox(T("msg.backup_found", g_AutoConfFile . ".EasyIni.bak"))
    FileMove(g_AutoConfFile ".EasyIni.bak", g_AutoConfFile)
} else if (!FileExist(g_AutoConfFile)) {
    FileAppend(T("app.auto_header"), g_AutoConfFile)
}

; 配置对象
global g_Conf := EasyIni(g_ConfFile)
global g_AutoConf := EasyIni(g_AutoConfFile)

; 启动 guard: 配置没读出来就 loud-fail, 不带病运行
; (OnError 网会吞掉加载异常, 曾导致 g_Conf 未赋值还继续跑)
if (!IsObject(g_Conf) || !g_Conf.HasSection("Config")) {
    ; 注意: 此处 RimLog 尚不可用 (Utils 在下方才 #Include), 直写保日志不丢
    try FileAppend(A_Now . " FATAL: 配置加载失败 " . g_ConfFile . "`n", A_ScriptDir . "\Rim.error.log") ; i18n:protocol (启动早夭日志, 与 MsgBox 同文案 key)
    catch {
    }
    MsgBox(T("msg.config_load_failed", g_ConfFile))
    ExitApp(1)
}
BootMark("STARTUP config-ok")

; 语言初始化 (尊重 [Config] Language, auto 跟系统; 此前 I18nBoot 已按 OS 语言兜底)
I18nInit()

; 皮肤配置 (缺键永不炸启动; 空串保持用内联 [Gui], 语义不变)
skinName := ""
try skinName := g_Conf["Gui"]["Skin"]
catch {
}
if (skinName != "")
    global g_SkinConf := EasyIni(A_ScriptDir "\Conf\Skins\" skinName ".ini")["Gui"]
else
    global g_SkinConf := g_Conf["Gui"]

; 皮肤配置默认值 (owner 见 Core/GUI.ahk EnsureSkinDefaults, 避免入口堆字段表)
EnsureSkinDefaults()

; ==================== 托盘菜单 (尽早构建一次: 默认菜单闪现窗口从 ~200ms 压到 ~10ms) ====================
; 回调名编译期已解析, 运行时引用安全; 失败也不拦启动, 后面正式位置会再建一次兜底
try {
    if (BuildTrayMenu())
        A_IconHidden := false
} catch {
}

; 运行时状态 (g_Arg: 命令参数总线; 写入 owner=Execution/Hotkeys 管道, 插件只读; g_ 前缀防局部遮蔽)
global g_Arg := ""
global FullPipeArg := ""
; 不能是 Rim.ahk 的子串, 否则按键绑定会有问题 (对齐原版 4 空格)
global g_WindowName := "Rim    "
global g_CommandAlias := Map()
global g_FallbackCommands := []
global g_CurrentInput := ""
global g_CurrentCommand := ""
global g_CurrentCommandList := []
; 缺键/坏行永不炸启动 (裸 Map 访问缺键即抛; 实测缺 TCMatchPath 行即加载死)
global g_EnableTCMatch := TCMatchInit(CfgGet("Config", "TCMatchPath", ""))
global g_FirstChar := 0
try g_FirstChar := Ord(g_SkinConf.Has("FirstChar") ? g_SkinConf["FirstChar"] : "a")
if (!g_FirstChar)
    g_FirstChar := Ord("a")
global g_DisplayRows := 0
try g_DisplayRows := (g_SkinConf.Has("DisplayRows") ? g_SkinConf["DisplayRows"] : "15") + 0
catch {
}
if (!g_DisplayRows)
    g_DisplayRows := 15
global g_UseDisplay := false
global g_HistoryCommands := []
global g_DisableAutoExit := false
global g_CurrentLine := 1
global g_UseFallbackCommands := false
global g_UseResultFilter := false
global g_UseRealtimeExec := false
global g_ExcludedCommandsObj := Map()
global g_PipeArg := ""
global g_CommandFilter := ""
global g_Plugins := []
; 命令注册: 结构化经 RimCommand.Register, 数据行经 LauncherCompat.AddCommand (别名+收编)

; ==================== 启动阶段打点 ====================
RimPhaseBegin(name) {
    global g_BootPhase, g_BootPhases
    g_BootPhase := name
    try g_BootPhases.Push(Map("name", name, "t0", A_TickCount, "ok", ""))
    catch {
    }
}

RimPhaseEnd(name) {
    global g_BootPhases
    try {
        for _, ph in g_BootPhases {
            if (ph["name"] = name && ph["ok"] = "") {
                ph["ok"] := true
                ph["ms"] := A_TickCount - ph["t0"]
            }
        }
    } catch {
    }
}

; 阶段状态查询 (诊断/探针用; 返回数组的快照)
BootPhases() {
    global g_BootPhases
    out := []
    try {
        for _, ph in g_BootPhases
            out.Push(Map("name", ph["name"], "ok", ph["ok"], "ms", ph.Has("ms") ? ph["ms"] : -1))
    } catch {
    }
    return out
}

; ==================== 全局错误网 (本构建无 IsFunc/Func, 运行时错转日志不断线) ====================
Rim_OnError(e, mode) {
    ; 全局错误网 (运行时错转日志不断线); RimLog 常驻 (错误回调只在运行期触发, Utils 必已加载)
    global g_BootPhase, g_BootPhases
    try {
        stack := ""
        try stack := StrReplace(e.Stack, "`n", " <- ")
        catch {
        }
        RimLog("ERROR", "[" . g_BootPhase . "] " . e.Message . " what=" . e.What . " extra=" . e.Extra . " @ " . e.Line . " " . e.File . " stack=" . stack)
    } catch {
        try FileAppend(A_Now . " ERROR: " . e.Message . " @ " . e.Line . "`n", A_ScriptDir . "\Rim.error.log")
        catch {
        }
    }
    ; 当前阶段记失败 (启动期定位到具体阶段; 运行期 g_BootPhase 常驻末段, 仅 ATTRIBUTION 用)
    try {
        for _, ph in g_BootPhases {
            if (ph["name"] = g_BootPhase && ph["ok"] = "")
                ph["ok"] := false
        }
    } catch {
    }
    return -1
}
OnError(Rim_OnError, -1)

; 进程退出/重载统一收尾：触发插件 OnExit（销毁钩子/定时器），IsSet 守卫防启动早期退出
Rim_OnExit(reason, code) {
    try {
        if IsSet(RimPluginManager)
            RimPluginManager.OnExitAll()
    }
}
OnExit(Rim_OnExit)

; 动态名 → 可调用对象 (替代缺失的 Func(); 闭包内动态调用经验证可加载)
MakeCb(name) {
    return (*) => %name%()
}

; vim 动作 → 闭包 (必须经工厂函数: 循环内联闭包会共享循环变量, 全变成最后一个动作!)
; 直达统一入口 ExecuteAction
MakeVimCb(action) {
    return (*) => ExecuteAction(action)
}

; 菜单回调工厂: Menu 回调固定传 3 参 (ItemName, ItemPos, MenuObj),
; 直接 .Bind(fn, args) 会把 3 参叠加导致 "Too many parameters";
; 而 (*) => fn(循环变量) 又会捕获越界循环变量 —— 工厂每次调用自带局部量, 两坑全避
; (经 factorytest.ahk 实测: 每项值独立 + arity 安全)
MakeMenuCb(fn, args*) {
    return (*) => %fn%(args*)
}

; $ 前缀绑定 (Send 不回环; ~ 开头保持原样, 鼠标键不走 Send 路径)
BindKey(key, funcObj, opts := "") {
    if (SubStr(key, 1, 1) != "$" && SubStr(key, 1, 1) != "~")
        key := "$" . key
    if (opts = "")
        Hotkey(key, funcObj)
    else
        Hotkey(key, funcObj, opts)
}
global g_InputArea := "Edit1"
global g_DisplayArea := "Edit3"
global g_CommandArea := "Edit4"

; ==================== 加载库 ====================
#Include Lib\EasyIni.ahk
#Include Lib\TCMatch.ahk
#Include Lib\MonsterEval.ahk
#Include Core\Common.ahk
#Include Core\I18n.ahk
#Include Core\Tray.ahk

; ==================== 加载 Core 模块 ====================
#Include Core\Config.ahk
#Include Core\ConfigSchema.ahk
#Include Core\ConfigTxn.ahk
#Include Core\Files.ahk
#Include Core\Search.ahk
#Include Core\GUI.ahk
#Include Core\Context.ahk
#Include Core\WindowIndex.ahk
#Include Core\Plugin.ahk
#Include Core\Runtime.ahk
#Include Core\Command.ahk
#Include Core\ActionProtocol.ahk
#Include Core\Window.ahk
#Include Core\Workspace.ahk
#Include Core\Execution.ahk
#Include Core\Engine.ahk
#Include Core\Utils.ahk
#Include Core\Logging.ahk
#Include Core\Observability.ahk
#Include Core\Hotkeys.ahk
#Include Core\SmartInput.ahk
#Include Core\Gesture.ahk
#Include Core\GestureIni.ahk
#Include Core\GestureTrail.ahk
#Include Core\GestureTemplate.ahk
#Include Core\GestureSPData.ahk
#Include Core\GesturePreview.ahk
#Include Gui\GestureUI.ahk
#Include Gui\VimConfigUI.ahk
#Include Gui\VimCfg_Save.ahk
#Include Gui\VimCfg_Schema.ahk
#Include Gui\VimCfg_TabsKeys.ahk
#Include Gui\VimCfg_TabsMisc.ahk

; ==================== VimEditor 插件 ====================
#Include *i Plugins\VimEditor.ahk
#Include *i Plugins\VimEditorAdapters.ahk

; ==================== 其他插件 ====================
; 数据行插件 (LauncherCompat.AddCommand 注册 url/file 行)
#Include *i Plugins\Misc.ahk
#Include *i Plugins\QRCode.ahk
#Include *i Plugins\Kanji.ahk
#Include *i Plugins\LauncherCore.ahk
#Include *i Plugins\LauncherSystem.ahk
#Include *i Plugins\General.ahk
#Include *i Plugins\StrokePlus.ahk
#Include *i Plugins\StatsBall.ahk
; VimDesktop 风格插件 (需 VimEngine, 已接线)
#Include *i Plugins\Explorer.ahk
#Include *i Plugins\Browser.ahk
#Include *i Plugins\Excel.ahk
#Include *i Plugins\Pdf.ahk
#Include *i Plugins\Terminal.ahk
#Include *i Plugins\TCCompare.ahk
#Include *i Plugins\WinMerge.ahk
#Include *i Plugins\BeyondCompare4.ahk
#Include *i Plugins\Foobar2000.ahk
#Include *i Plugins\TCDialog.ahk
#Include *i Plugins\TotalCommander.ahk
; 用户自定义函数 (v2: 定义 Func() 后经 ini function|Func|arg 或 [Hotkey] 调用)
#Include *i custom.ahk

; ==================== 插件发现 ====================
; 扫描 Plugins 目录，自动加载未注册的插件
pluginDir := A_ScriptDir "\Plugins"
Loop Files, pluginDir "\*.ahk" {
    SplitPath(A_LoopFileName, , , , &pluginName)
    if (CfgGet("Plugins", pluginName, "1") != "0")
        g_Plugins.Push(pluginName)
}

; ==================== 核心符号自检 (防中途加载: 跨文件引用的函数/类缺失则 loud-fail, 不带病进 LoadFiles) ====================
; 背景: 热更新/保存即重启可能撞上文件写半截的窗口期, 缺符号在深处才炸 (如 MakeLegacyCmd),
; 堆栈难读; 此处逐个动态解析, 缺谁报谁
Rim_CheckCoreSymbols() {
    missing := []
    for _, sym in ["MakeLegacyCmd", "LegacyDirectCall", "GetRunArg", "CmdLine_Parse",
        "RimCommand", "RimPluginManager", "GestureEngine", "ExecuteAction", "LoadFiles",
        "AddCommand"] {
        ok := false
        try {
            ref := %sym%
            ok := IsObject(ref) || ref != ""
        } catch {
            ok := false
        }
        if (!ok)
            missing.Push(sym)
    }
    return missing
}

_missingSyms := Rim_CheckCoreSymbols()
if (_missingSyms.Length > 0) {
    _msg := T("msg.selfcheck_fail")
    for _, _s in _missingSyms
        _msg .= "  - " _s "`n"
    try FileAppend(A_Now . " FATAL selfcheck: " . _missingSyms.Length . " missing`n", A_ScriptDir . "\Rim.error.log")
    catch {
    }
    MsgBox(_msg)
    ExitApp(1)
}

; ==================== 托盘菜单 (重建兜底: 前面已建过一次, 这里幂等重建; 语言切换即时生效亦走此函数, 见 Core/Tray.ahk) ====================
BuildTrayMenu()

; ==================== 统一插件生命周期初始化 ====================
RimPhaseBegin("plugin-init")
RimPluginManager.InitAll()
RimPluginManager.RegisterAllContexts()
RimPhaseEnd("plugin-init")

; ==================== 语义指令与工作空间注册 ====================
RimPhaseBegin("commands")
InitUniversalCommands()
InitWorkspaceCommands()
RimPhaseEnd("commands")

; ==================== 加载文件 ====================
RimPhaseBegin("files")
if (FileExist(g_SearchFileList))
    LoadFiles()
else
    try {
        GenerateSearchFileList()
        LoadFiles()
    }
BootMark("STARTUP files-loaded")
RimPhaseEnd("files")

; ==================== 创建 GUI (AHK v2) ====================
RimPhaseBegin("gui")
InitMainGui()
BootMark("STARTUP gui-shown")
RimPhaseEnd("gui")

; ==================== 绑定热键 (经 BindKey 统一 $ 前缀, 防 Send 回环) ====================
RimPhaseBegin("hotkeys")
BindLauncherHotkeys()
RimPhaseEnd("hotkeys")

; ==================== 恢复状态 (缺键永不炸启动, 语义不变) ====================
RimPhaseBegin("state")
if (CfgGet("Config", "SaveInputText", "0") = "1") {
    inputText := ""
    try inputText := g_AutoConf["Auto"]["InputText"]
    catch {
    }
    if (inputText != "")
        Send(inputText)
}

if (CfgGet("Config", "SaveHistory", "1") = "1") {
    g_HistoryCommands := []
    LoadHistoryCommands()
}

; 启动时维护 SendTo/开机启动 (对齐原版, 不覆盖已存在)
UpdateSendTo(CfgGet("Config", "CreateSendToLnk", "0"), false)
UpdateStartupLnk(CfgGet("Config", "CreateStartupLnk", "0"), false)
RimPhaseEnd("state")

; ==================== VimEngine 最小闭环 (VimDesktop 移植) ====================
RimPhaseBegin("vim")
global g_VimEngine := VimEngine()
; 兼容赋值: 移植插件经 Rim.vim/config 访问引擎与配置
Rim.vim := g_VimEngine
Rim.config := g_Conf
; 自家窗口旁路: 输入框打字不进 vim 分发
g_VimEngine.SelfWinTitle := g_WindowName

VimPluginOn(name) => RimPluginManager.IsEnabled(name)

; 插件按键模式注入 (全插件经 Hybrid RegisterKeymaps 直注引擎, 无双轨分发)
RimPluginManager.RegisterAllKeymaps(g_VimEngine)
BootMark("STARTUP keymaps-ready")
VimdCheckHotKey()
BootMark("STARTUP vimcheck-ready")

; 配置热应用订阅 (live/rebuild 档免重启; restart 档走重启链, 见 VimCfg_DoSave)
; 注意: 回调只做"读配置→改对象", 禁止阻塞 (单线程, 卡死界面)
try CfgSubscribe("Config", "Language", (val, _sec, _key) => I18nApplyTray(val))
; 语言 rebuild 落实: 托盘之后重建主窗, T() 全量刷新, 免重启
try CfgSubscribe("Config", "Language", (*) => Launcher_ApplyGui())
try CfgSubscribe("Config", "SearchFileDir", (*) => LoadFiles())
try CfgSubscribe("Config", "SearchFileType", (*) => LoadFiles())
try CfgSubscribe("Config", "SearchFileExclude", (*) => LoadFiles())
try CfgSubscribe("Config", "LoadControlPanelFunctions", (*) => LoadFiles())
; 快捷方式 live 落实: 改即生效 (ChangePath 读最新值, 幂等)
try CfgSubscribe("Config", "CreateSendToLnk", (*) => ChangePath())
try CfgSubscribe("Config", "CreateStartupLnk", (*) => ChangePath())
; 外观 rebuild 档: 重载皮肤并重建主窗 (输入与可见性由 Launcher_ApplyGui 保持)
try CfgSubscribe("Config", "WindowAlwaysOnTop", (*) => Launcher_ApplyGui())
for _idx, guiKey in ["Skin", "HideTitle", "ShowCurrentCommand", "DisplayRows", "WidgetWidth", "FontName", "FontSize", "FontColor", "BackgroundColor", "EditColor"] {
    try CfgSubscribe("Gui", guiKey, (*) => Launcher_ApplyGui())
}

    ; ==================== 鼠标手势 (StrokePlus 重构 P1) ====================
    ; 右键按住拖拽=手势, 短点=普通右键; 映射见 [Gesture]/[Gestures]
    RimPhaseEnd("vim")
    RimPhaseBegin("gestures")
    RimPluginManager.RegisterAllGestures()
    GestureEngine.Init()
    BootMark("STARTUP gestures-ready")
    RimPhaseEnd("gestures")

; ==================== 文件监控 ====================
RimPhaseBegin("finalize")
SetTimer(WatchUserFileList, 3000)

BootMark("STARTUP plugins-ready")

; 雷达挂件启动自恢复 (配置保存/手动重启后新进程自动亮球, 不用再点托盘)
try StatsBall_AutoShow()
catch {
}

; 配置中心保存重启后的恢复 (VimCfg_OnSave 立旗): 窗闪一下但回来, 所见即所得
try {
    if (IsObject(g_AutoConf) && g_AutoConf.Get("UI", "ReopenConfig", "0") = "1") {
        try g_AutoConf.Set("UI", "ReopenConfig", "0")
        catch {
        }
        try g_AutoConf.Save()
        catch {
        }
        try VimConfig_Show()
        catch {
        }
    }
} catch {
}
RimPhaseEnd("finalize")

; 启动胎记: 对版本 confusion, error.log 首行即构建号 (附启动总耗时)
try {
    FileAppend("BUILD " . g_BuildTag . " ready +" . (A_TickCount - g_BootT0) . "ms " . A_Now . "`n", A_ScriptDir . "\Rim.error.log")
}

ShowPluginInfo(*) {
    global g_Plugins
    msg := T("plugin.list_header")
    for i, name in g_Plugins
        msg .= "  - " name "`n"
    MsgBox(msg, T("plugin.list_title"))
}

ToggleSuspend(*) {
    Suspend()
    if (A_IsSuspended)
        ToolTip(T("state.disabled"))
    else
        ToolTip(T("state.enabled"))
    SetTimer(RemoveToolTip, -1000)
}

; ===== VimDesktop ini→map 编译器 (最小闭环: exclude/global/各窗口段) =====
VimdCheckHotKey() {
    global g_VimEngine, g_Conf
    if !IsObject(g_VimEngine)
        return
    ; 排除窗口
    try {
        for _k, _v in g_Conf["exclude"]
            g_VimEngine.ExcludeWin(_k)
    }
    ; 全局热键: [global] key=action
    try {
        for _k, _v in g_Conf["global"] {
            _v := Trim(_v)
            if (_v = "" || SubStr(_v, 1, 1) = ";")
                continue
            g_VimEngine.SetAction(_v, _v)
            g_VimEngine.MapGlobal(_k, _v)
        }
    }
    ; 各窗口段: 跳过已知非窗口段
    skipSections := Map("Config", 1, "Gui", 1, "exclude", 1, "global", 1, "plugins", 1
        , "FallbackCommand", 1, "Commands", 1, "Command", 1, "Hotkey", 1, "GlobalHotkey", 1
        , "Gesture", 1, "Gestures", 1, "GestureBlacklist", 1
        , "TotalCommander_Config", 1, "Auto", 1, "Rank", 1, "History", 1)
    try {
        for sectionName, section in g_Conf.GetSections() {
            if (skipSections.Has(sectionName))
                continue
            ; 手势应用层节 [GestureApp:*] 由手势引擎接管, 不进 vim 编译
            if (SubStr(sectionName, 1, 12) = "GestureApp:")
                continue
            ; TTOTAL_CMD: 插件硬编码先注册, ini 再编译覆盖 (用户定制/Shift 档生效;
            ; 原先整段跳过导致 ini 改键全部无声失效, 且 <S-Q>/<S-O> 等 Shift 映射丢失)
            setClass := CfgGet(sectionName, "set_class", "")
            setFile := CfgGet(sectionName, "set_file", "")
            if (setClass = "" && setFile = "") {
                ; 纯覆盖节 (如只有 default_mode): 不建窗, 只应用默认模式
                try VimdApplyDefaultMode(sectionName)
                catch {
                }
                continue
            }
            ; 单窗 vim 持久开关: 本节 vim_enable=0 则整节不编译进 vim (两层一起停, 重启仍有效; Win+W 只管临时)
            if (Trim(CfgGet(sectionName, "vim_enable", "1")) = "0")
                continue
            g_VimEngine.SetWin(sectionName, setClass, setFile)
            try g_VimEngine.GetWin(sectionName).SetTimeOut(Integer(CfgGet(sectionName, "set_time_out", "800")))
            try g_VimEngine.GetWin(sectionName).MaxCount := Integer(CfgGet(sectionName, "set_max_count", "99"))
            try {
                if (CfgGet(sectionName, "enable_show_info", "") != "")
                    g_VimEngine.GetWin(sectionName).ShowInfo := CfgGet(sectionName, "enable_show_info", "1") = "1"
            }
            for _k, _v in section {
                if (SubStr(_k, 1, 4) = "set_" || SubStr(_k, 1, 7) = "enable_")
                    continue
                ; default_mode 是窗口元配置, 不是热键 (不跳过会被绑成名叫 default_mode 的热键)
                if (_k = "default_mode")
                    continue
                _v := Trim(_v)
                if (_v = "" || SubStr(_v, 1, 1) = ";")
                    continue
                ; key=action[=mode] / function|... 派发到 ExecuteAction
                mode := "normal"
                if RegExMatch(_v, "^(.*)\[=(.+)\]$", &_m) {
                    _v := _m[1]
                    mode := _m[2]
                }
                g_VimEngine.SetMode(mode, sectionName)
                ; 动作合法性校验 (插件通过 RegisterActionValidator 注册验证规则, 无效动作跳过保留原键透传)
                if (!g_VimEngine.IsValidAction(_v))
                    continue

                ; 中文注释保护: 插件已注册中文的不再用动作名覆盖 (g 面板中文就靠它)
                if !g_VimEngine.ActionList.Has(_v)
                    g_VimEngine.SetAction(_v, _v)
                g_VimEngine.MapKey(_k, _v, sectionName, mode)
            }
            ; 默认模式压轴应用 (覆盖按键编译中的 SetMode, ini 压过插件硬编码)
            try VimdApplyDefaultMode(sectionName)
            catch {
            }
        }
    }
    ; 引擎绑定改了 HotIf 上下文, 复位避免污染后续 launcher 热键
    HotIfWinActive()
}
