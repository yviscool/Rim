#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, Off

FileEncoding "UTF-8"
SendMode "Input"
SetWorkingDir(A_ScriptDir)
; 重启链路灯: 进程一起就记, 若卡死/崩溃, 日志停在哪段一目了然
try FileAppend(A_Now . " STARTUP begin`n", A_ScriptDir . "\Rim.error.log")
catch {
}
; 防洪阈值对齐 v1 (#MaxHotkeysPerInterval 200 等价)
A_MaxHotkeysPerInterval := 200
; 构建号 (配置中心帮助页显示, 日志 BUILD 行同源)
global g_BuildTag := "20260921-VDTRAY1"

; ==================== 兼容层: 供插件引用 Rim.xxx ====================
class Rim {
    static appDir := A_ScriptDir
    static config := ""
    static vim := ""
    static launcher := ""
}

; ==================== 全局变量 (RunZ 兼容) ====================
; 配置文件路径
global g_SearchFileList := A_ScriptDir . "\Conf\SearchFileList.txt"
global g_UserFileList := A_ScriptDir . "\Conf\UserFileList.txt"
global g_ConfFile := A_ScriptDir . "\Conf\rim.ini"
global g_AutoConfFile := A_ScriptDir . "\Conf\rim.auto.ini"

; 备份恢复
if (FileExist(g_AutoConfFile ".EasyIni.bak")) {
    MsgBox("发现上次写入配置的备份文件：`n"
        . g_AutoConfFile ".EasyIni.bak"
        . "`n确定则将其恢复，否则请手动检查文件内容再继续")
    FileMove(g_AutoConfFile ".EasyIni.bak", g_AutoConfFile)
} else if (!FileExist(g_AutoConfFile)) {
    FileAppend("; 此文件由 Rim 自动写入，如需手动修改请先关闭 Rim ！`n`n"
        . "[Auto]`n[Rank]`n[History]", g_AutoConfFile)
}

; 配置对象
global g_Conf := EasyIni(g_ConfFile)
global g_AutoConf := EasyIni(g_AutoConfFile)

; 启动 guard: 配置没读出来就 loud-fail, 不带病运行
; (OnError 网会吞掉加载异常, 曾导致 g_Conf 未赋值还继续跑)
if (!IsObject(g_Conf) || !g_Conf.HasSection("Config")) {
    try FileAppend(A_Now . " FATAL: 配置加载失败 " . g_ConfFile . "`n", A_ScriptDir . "\Rim.error.log")
    catch {
    }
    MsgBox("配置文件加载失败, 可能是文件被占用, 稍后重试.`n" . g_ConfFile)
    ExitApp(1)
}
try FileAppend(A_Now . " STARTUP config-ok`n", A_ScriptDir . "\Rim.error.log")
catch {
}

; 皮肤配置
if (g_Conf["Gui"]["Skin"] != "")
    global g_SkinConf := EasyIni(A_ScriptDir "\Conf\Skins\" g_Conf["Gui"]["Skin"] ".ini")["Gui"]
else
    global g_SkinConf := g_Conf["Gui"]

; 皮肤配置默认值（避免 v2 Map 访问不存在的键报错, 对齐原版字段全集）
skinDefaults := Map("ShowInputBoxOnlyIfEmpty", "0", "BackgroundPicture", "", "RoundCorner", "0"
    , "ShowFileExt", "0", "HideCol2", "0", "HideCol4IfEmpty", "1", "ShowTrayIcon", "1", "ShowCurrentCommand", "1"
    , "DisplayCol3MaxLength", "30", "DisplayCol4MaxLength", "36", "DisplayRows", "15", "FirstChar", "a"
    , "HideTitle", "1", "WidgetWidth", "650", "EditHeight", "24", "DisplayAreaHeight", "246"
    , "FontName", "宋体", "FontSize", "12", "FontColor", "000000", "BackgroundColor", "f0f0f0", "BorderSize", "15"
    , "EditColor", "f0f0f0")
for k, v in skinDefaults
    if !g_SkinConf.Has(k)
        g_SkinConf[k] := v

; 运行时状态
global Arg := ""
global FullPipeArg := ""
; 不能是 Rim.ahk 的子串, 否则按键绑定会有问题 (对齐原版 4 空格)
global g_WindowName := "RunZ    "
global g_Commands := []
global g_FallbackCommands := []
global g_CurrentInput := ""
global g_CurrentCommand := ""
global g_CurrentCommandList := []
global g_EnableTCMatch := TCMatchOn(g_Conf["Config"]["TCMatchPath"])
global g_FirstChar := 0
try g_FirstChar := Ord(g_SkinConf.Has("FirstChar") ? g_SkinConf["FirstChar"] : "a")
if (!g_FirstChar)
    g_FirstChar := Ord("a")
global g_DisplayRows := (g_SkinConf.Has("DisplayRows") ? g_SkinConf["DisplayRows"] : "15") + 0
if (!g_DisplayRows)
    g_DisplayRows := 15
global g_UseDisplay := false
global g_HistoryCommands := []
global g_DisableAutoExit := false
global g_CurrentLine := 1
global g_UseFallbackCommands := false
global g_UseResultFilter := false
global g_UseRealtimeExec := false
global g_ExcludedCommands := ""
global g_ExcludedCommandsObj := Map()
global g_CommandObjects := []
global g_ExecInterval := -1
global g_LastExecLabel := ""
global g_LastExecCb := ""
global g_PipeArg := ""
global g_CommandFilter := ""
global g_Plugins := []
; 显示名→函数名别名表 (RegisterCommand 注册时填充, RunCommand 解析)
; 对齐原版: 插件命令形如 function | Calc | 描述, label 即 key
global g_FuncAlias := Map()

; ==================== 全局错误网 (本构建无 IsFunc/Func, 运行时错转日志不断线) ====================
Rim_OnError(e, mode) {
    try {
        FileAppend(A_Now . " ERROR: " . e.Message . " what=" . e.What . " extra=" . e.Extra . " @ " . e.Line . " " . e.File . "`n", A_ScriptDir . "\Rim.error.log")
    }
    return -1
}
OnError(Rim_OnError, -1)

; 动态名 → 可调用对象 (替代缺失的 Func(); 闭包内动态调用经验证可加载)
MakeCb(name) {
    return (*) => %name%()
}

; vim 动作 → 闭包 (必须经工厂函数: 循环内联闭包会共享循环变量, 全变成最后一个动作!)
MakeVimCb(action) {
    return (*) => VIMD_CMD(action)
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

; ==================== 加载 Core 模块 ====================
#Include Core\Config.ahk
#Include Core\Files.ahk
#Include Core\Search.ahk
#Include Core\GUI.ahk
#Include Core\Execution.ahk
#Include Core\Engine.ahk
#Include Core\Utils.ahk
#Include Core\Hotkeys.ahk
#Include Core\Gesture.ahk
#Include Core\GestureIni.ahk
#Include Core\GestureTrail.ahk
#Include Core\GestureTemplate.ahk
#Include Core\GesturePreview.ahk
#Include Gui\GestureUI.ahk
#Include Gui\VimConfigUI.ahk

; ==================== VimEditor 插件 ====================
#Include *i Plugins\VimEditor.ahk
#Include *i Plugins\VimEditorAdapters.ahk

; ==================== 其他插件 ====================
; RunZ 风格插件 (RegisterCommand 注册)
#Include *i Plugins\Misc.ahk
#Include *i Plugins\QRCode.ahk
#Include *i Plugins\Kanji.ahk
#Include *i Plugins\LauncherCore.ahk
#Include *i Plugins\LauncherSystem.ahk
#Include *i Plugins\General.ahk
#Include *i Plugins\StrokePlus.ahk
; VimDesktop 风格插件 (需 VimEngine, 已接线; Excel 待 COM 重移植)
#Include *i Plugins\Explorer.ahk
#Include *i Plugins\TCCompare.ahk
#Include *i Plugins\WinMerge.ahk
#Include *i Plugins\BeyondCompare4.ahk
#Include *i Plugins\Foobar2000.ahk
#Include *i Plugins\TCDialog.ahk
#Include *i Plugins\TotalCommander.ahk
#Include *i Plugins\VimDConfig.ahk
; #Include *i Plugins\MicrosoftExcel.ahk
; 用户自定义函数 (v2: 定义 Func() 后经 ini function|Func|arg 或 [Hotkey] 调用)
#Include *i custom.ahk

; ==================== 插件发现 ====================
; 扫描 Plugins 目录，自动加载未注册的插件
pluginDir := A_ScriptDir "\Plugins"
Loop Files, pluginDir "\*.ahk" {
    SplitPath(A_LoopFileName, , , , &pluginName)
    if (g_Conf.GetValue("Plugins", pluginName) != 0)
        g_Plugins.Push(pluginName)
}

; ==================== 托盘菜单 ====================
if (g_SkinConf["ShowTrayIcon"] = "1") {
    A_TrayMenu.Delete()
    if (g_Conf["Config"]["RunInBackground"] = "1") {
        A_TrayMenu.Add("显示 &S", ActivateRunZ)
        A_TrayMenu.Default := "显示 &S"
        A_TrayMenu.ClickCount := 1
    }
    A_TrayMenu.Add("手势 &G", ShowGestureManager)
    A_TrayMenu.Add("配置 &C", VimConfig_Show)
    A_TrayMenu.Add()
    A_TrayMenu.Add("禁用 &S", ToggleSuspend)
    A_TrayMenu.Add("重启 &R", RestartRunZ)
    A_TrayMenu.Add("退出 &X", ExitRunZ)
}

; ==================== 加载文件 ====================
if (FileExist(g_SearchFileList))
    LoadFiles()
else
    try {
        GenerateSearchFileList()
        LoadFiles()
    }

; ==================== 创建 GUI (AHK v2) ====================
; 置顶与否只看配置 (对齐原版: 默认不置顶, 二维码等子窗口 Show 才能到前面)
_topOpt := (g_Conf["Config"]["WindowAlwaysOnTop"] = "1") ? " +AlwaysOnTop" : ""
g_MainGui := Gui("+ToolWindow" _topOpt (g_SkinConf["HideTitle"] = "1" ? " -Caption" : ""), g_WindowName)
g_MainGui.BackColor := g_SkinConf["BackgroundColor"]

if (g_SkinConf["BackgroundPicture"] != "" && FileExist(A_ScriptDir "\Conf\Skins\" g_SkinConf["BackgroundPicture"]))
    g_MainGui.Add("Picture", "x0 y0", A_ScriptDir "\Conf\Skins\" g_SkinConf["BackgroundPicture"])

border := 10
if (g_SkinConf["BorderSize"] + 0 >= 0)
    border := g_SkinConf["BorderSize"] + 0
windowHeight := border * 3 + g_SkinConf["EditHeight"] + 0 + g_SkinConf["DisplayAreaHeight"] + 0

g_MainGui.SetFont("C" g_SkinConf["FontColor"] " S" g_SkinConf["FontSize"], g_SkinConf["FontName"])
; 输入框底色 (对齐原版 Gui,Color 的 Edit 色; try 兜底未知色值)
ApplyEditColor(ctrl) {
    global g_SkinConf
    try {
        if (g_SkinConf.Has("EditColor") && g_SkinConf["EditColor"] != "")
            ctrl.Opt("+Background" . g_SkinConf["EditColor"])
    }
}
g_InputEdit := g_MainGui.Add("Edit", "x" border " y" border " -WantReturn"
    . " w" g_SkinConf["WidgetWidth"] " h" g_SkinConf["EditHeight"])
ApplyEditColor(g_InputEdit)
g_InputEdit.OnEvent("Change", ProcessInputCommand)
g_MainGui.Add("Edit", "y+0 w0 h0 ReadOnly -WantReturn")
btn := g_MainGui.Add("Button", "y+0 w0 h0 Default")
btn.OnEvent("Click", RunCurrentCommand)
g_DisplayEdit := g_MainGui.Add("Edit", "y+" border " -VScroll ReadOnly -WantReturn"
    . " w" g_SkinConf["WidgetWidth"] " h" g_SkinConf["DisplayAreaHeight"])
ApplyEditColor(g_DisplayEdit)

g_CommandEdit := ""
if (g_SkinConf["ShowCurrentCommand"] = "1") {
    g_CommandEdit := g_MainGui.Add("Edit", "y+" border " ReadOnly"
        . " w" g_SkinConf["WidgetWidth"] " h" g_SkinConf["EditHeight"])
    ApplyEditColor(g_CommandEdit)
    windowHeight += border + g_SkinConf["EditHeight"] + 0
}

windowY := ""
if (g_SkinConf["ShowInputBoxOnlyIfEmpty"] = "1") {
    windowHeight := border * 2 + g_SkinConf["EditHeight"] + 0
    screenHeight := SysGet(79)
    windowY := "y" (screenHeight - border * 2 - g_SkinConf["EditHeight"] + 0 - g_SkinConf["DisplayAreaHeight"] + 0) / 2
}

cmdlineArg := A_Args.Length >= 1 ? A_Args[1] : ""
showCmd := (cmdlineArg = "--hide") ? "Hide" : ""

g_MainGui.Show(windowY " w" border * 2 + g_SkinConf["WidgetWidth"] + 0
    . " h" windowHeight " " showCmd)

; 初始化显示内容
_searchResult := SearchCommand("", true)
g_DisplayEdit.Value := AlignText(_searchResult)

if (g_SkinConf["RoundCorner"] + 0 > 0)
    WinSetRegion("0-0 w" border * 2 + g_SkinConf["WidgetWidth"] + 0 " h" windowHeight
        . " r" g_SkinConf["RoundCorner"] + 0 "-" g_SkinConf["RoundCorner"] + 0, g_WindowName)

; ==================== 窗口设置 ====================
if (g_Conf["Config"]["SwitchToEngIME"])
    SwitchToEngIME()

if (g_Conf["Config"]["ExitIfInactivate"])
    OnMessage(0x06, WM_ACTIVATE)

OnMessage(0x0200, WM_MOUSEMOVE)

; ==================== 绑定热键 (经 BindKey 统一 $ 前缀, 防 Send 回环) ====================
HotIfWinActive(g_WindowName)

BindKey("Esc", EscFunction)
BindKey("!F4", ExitRunZ)
BindKey("Tab", TabFunction)
BindKey("F1", Help)
BindKey("+F1", KeyHelp)
BindKey("F2", EditConfig)
BindKey("F3", EditAutoConfig)
BindKey("^q", RestartRunZ)
BindKey("^l", ClearInputLabel)
BindKey("^u", ClearInputLabel)
BindKey("^d", OpenCurrentFileDir)
BindKey("^x", DeleteCurrentFile)
BindKey("^s", ShowCurrentFile)
BindKey("^r", ReindexFiles)
BindKey("^h", DisplayHistoryCommands)
BindKey("^n", IncreaseRank)
BindKey("^=", IncreaseRank)
BindKey("^p", DecreaseRank)
BindKey("^-", DecreaseRank)
BindKey("^f", NextPage)
BindKey("^b", PrevPage)
BindKey("^i", HomeKey)
BindKey("^o", EndKey)
BindKey("^j", NextCommand)
BindKey("^k", PrevCommand)
BindKey("Down", NextCommand)
BindKey("Up", PrevCommand)
BindKey("~LButton", ClickFunction)
BindKey("RButton", OpenContextMenu)
BindKey("AppsKey", OpenContextMenu)
BindKey("^Enter", SaveResultAsArg)

; Alt+字母 快速执行 / Tab+字母 执行 / Shift+字母 定位 (对齐原版三组绑定)
; Tab+字母原理: TabFunction 把焦点切到隐藏 Edit2, 字母 ~ 键此时才放行执行
Loop g_DisplayRows {
    key := Chr(g_FirstChar + A_Index - 1)
    BindKey("!" key, RunSelectedCommand)
    Hotkey("~" key, RunSelectedCommand)
    Hotkey("~+" key, GotoCommand)
}

; 用户自定义热键 (<...> 经工厂绑闭包, 避免循环变量共享)
for key, label in g_Conf["Hotkey"] {
    if (label != "Default") {
        try {
            if (SubStr(label, 1, 1) = "<") {
                BindKey(key, MakeVimCb(label))
            } else {
                BindKey(key, MakeCb(label))
            }
        }
    } else {
        try Hotkey(key, "Off")
    }
}

HotIfWinActive()

; 全局热键 (<...> 经工厂绑闭包, 避免循环变量共享)
for key, label in g_Conf["GlobalHotkey"] {
    if (label != "Default") {
        try {
            if (SubStr(label, 1, 1) = "<") {
                BindKey(key, MakeVimCb(label), "On")
            } else {
                BindKey(key, MakeCb(label), "On")
            }
        }
    } else {
        try Hotkey(key, "Off")
    }
}

; ==================== 恢复状态 ====================
if (g_Conf["Config"]["SaveInputText"] && g_AutoConf["Auto"]["InputText"] != "")
    Send(g_AutoConf["Auto"]["InputText"])

if (g_Conf["Config"]["SaveHistory"]) {
    g_HistoryCommands := []
    LoadHistoryCommands()
}

; 启动时维护 SendTo/开机启动 (对齐原版, 不覆盖已存在)
UpdateSendTo(g_Conf["Config"]["CreateSendToLnk"], false)
UpdateStartupLnk(g_Conf["Config"]["CreateStartupLnk"], false)

; ==================== VimEngine 最小闭环 (VimDesktop 移植) ====================
global g_VimEngine := VimEngine()
; 兼容赋值: 移植插件经 Rim.vim/config 访问引擎与配置
Rim.vim := g_VimEngine
Rim.config := g_Conf
; 自家窗口旁路: 输入框打字不进 vim 分发
g_VimEngine.SelfWinTitle := g_WindowName
global g_TCPluginOn := false
VimPluginOn(name) {
    global g_Conf
    return g_Conf.Get("Plugins", name, "1") != "0"
}
    ; General 基础层: 无类名/进程限制, 先注册再按 ini 细化
    ; (本构建无 IsFunc, 以下函数皆随 #Include 存在, 直调 + OnError 网兜底;
    ;  不用 try 包整段, 避免单个失败吞掉后续注册)
    if (VimPluginOn("General"))
        RegisterPlugin_General()
    if (VimPluginOn("Explorer"))
        RegisterPlugin_Explorer()
    if (VimPluginOn("TCCompare"))
        RegisterPlugin_TCCompare()
    if (VimPluginOn("WinMerge"))
        RegisterPlugin_WinMerge()
    if (VimPluginOn("BeyondCompare4"))
        RegisterPlugin_BeyondCompare4()
    if (VimPluginOn("Foobar2000"))
        RegisterPlugin_Foobar2000()
    if (VimPluginOn("TotalCommander")) {
        RegisterPlugin_TotalCommander()
        g_TCPluginOn := true
    }
    if (VimPluginOn("TCDialog"))
        RegisterPlugin_TCDialog()
    if (VimPluginOn("VimDConfig"))
        RegisterPlugin_VimDConfig()
    VimdCheckHotKey()

    ; ==================== 鼠标手势 (StrokePlus 重构 P1) ====================
    ; 右键按住拖拽=手势, 短点=普通右键; 映射见 [Gesture]/[Gestures]
    if (VimPluginOn("StrokePlus"))
        RegisterPlugin_StrokePlus()
    GestureInit()

; ==================== 文件监控 ====================
SetTimer(WatchUserFileList, 3000)

; 启动胎记: 对版本 confusion, error.log 首行即构建号
try {
    FileAppend("BUILD " . g_BuildTag . " started " . A_Now . "`n", A_ScriptDir . "\Rim.error.log")
}

; ==================== 兼容层: 供插件 RegisterCommand 调用 ====================
; 插件通过 RegisterCommand(name, type, content, desc) 注册命令
; 对齐原版: function 型元素为 "function | <name> | <desc>" (name 可搜索),
; 真实函数名经 g_FuncAlias[name]=content 记录, RunCommand 时解析
class LauncherCompat {
    static AddCommand(name, type, content, description := "") {
        global g_Commands, g_FuncAlias
        if (type = "function") {
            element := "function | " name
            if (description != "")
                element .= " | " description
            g_FuncAlias[name] := content
        } else {
            element := type " | " content
            if (description != "")
                element .= " | " description
        }
        g_Commands.Push(element)
    }
}

ShowPluginInfo(*) {
    global g_Plugins
    msg := "已加载插件:`n"
    for i, name in g_Plugins
        msg .= "  - " name "`n"
    MsgBox(msg, "插件列表")
}

ToggleSuspend(*) {
    Suspend()
    if (A_IsSuspended)
        ToolTip("已禁用")
    else
        ToolTip("已启用")
    SetTimer(RemoveToolTip, -1000)
}

; 插件注册函数
RegisterCommand(name, type, content, description := "") {
    LauncherCompat.AddCommand(name, type, content, description)
}

RegisterAction(name, comment := "") {
    global g_VimEngine
    if IsObject(g_VimEngine)
        g_VimEngine.SetAction(name, comment)
}

RegisterWin(name, winClass := "", winFile := "") {
    global g_VimEngine
    if IsObject(g_VimEngine)
        g_VimEngine.SetWin(name, winClass, winFile)
}

RegisterMode(mode, winName := "") {
    global g_VimEngine
    if IsObject(g_VimEngine)
        g_VimEngine.SetMode(mode, winName)
}

MapKey(key, action, winName := "", mode := "normal") {
    global g_VimEngine
    if IsObject(g_VimEngine)
        g_VimEngine.MapKey(key, action, winName, mode)
}

MapGlobal(key, action) {
    global g_VimEngine
    if IsObject(g_VimEngine)
        g_VimEngine.MapGlobal(key, action)
}

ExcludeWindow(name) {
    global g_VimEngine
    if IsObject(g_VimEngine)
        g_VimEngine.ExcludeWin(name)
}

; ===== VimDesktop ini→map 编译器 (最小闭环: exclude/global/各窗口段) =====
VimdCheckHotKey() {
    global g_VimEngine, g_Conf, g_TCPluginOn
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
            setClass := g_Conf.Get(sectionName, "set_class", "")
            setFile := g_Conf.Get(sectionName, "set_file", "")
            if (setClass = "" && setFile = "")
                continue
            g_VimEngine.SetWin(sectionName, setClass, setFile)
            try g_VimEngine.GetWin(sectionName).SetTimeOut(Integer(g_Conf.Get(sectionName, "set_time_out", "800")))
            try g_VimEngine.GetWin(sectionName).MaxCount := Integer(g_Conf.Get(sectionName, "set_max_count", "99"))
            try {
                if (g_Conf.Get(sectionName, "enable_show_info", "") != "")
                    g_VimEngine.GetWin(sectionName).ShowInfo := g_Conf.Get(sectionName, "enable_show_info", "1") = "1"
            }
            for _k, _v in section {
                if (SubStr(_k, 1, 4) = "set_" || SubStr(_k, 1, 7) = "enable_")
                    continue
                _v := Trim(_v)
                if (_v = "" || SubStr(_v, 1, 1) = ";")
                    continue
                ; key=action[=mode] / function|... 派发到 VIMD_CMD
                mode := "normal"
                if RegExMatch(_v, "^(.*)\[=(.+)\]$", &_m) {
                    _v := _m[1]
                    mode := _m[2]
                }
                g_VimEngine.SetMode(mode, sectionName)
                ; 未知 cm_ 编号直接跳过映射 (保留原键透传; 否则运行时调不存在的函数, 按键变砖。
                ; 如 ini 里 cm_DirBranch 等无编号条目。插件硬编码的 cm_ 都有编号, 不受影响)
                if RegExMatch(_v, "^<cm_(.+)>$", &_cm) {
                    _cmNum := 1
                    try _cmNum := TC_GetCommandNumber("cm_" _cm[1])
                    catch {
                    }
                    if (!_cmNum)
                        continue
                }
                ; 中文注释保护: 插件已注册中文的不再用动作名覆盖 (g 面板中文就靠它)
                if !g_VimEngine.ActionList.Has(_v)
                    g_VimEngine.SetAction(_v, _v)
                if (SubStr(_v, 1, 4) = "run|" || SubStr(_v, 1, 4) = "key|" || SubStr(_v, 1, 4) = "dir|"
                    || SubStr(_v, 1, 6) = "tccmd|" || SubStr(_v, 1, 7) = "wshkey|" || SubStr(_v, 1, 9) = "function|") {
                    g_VimEngine.VIMD_CMD_LIST[_v] := _v
                    g_VimEngine.MapKey(_k, _v, sectionName, mode)
                } else {
                    g_VimEngine.MapKey(_k, _v, sectionName, mode)
                }
            }
        }
    }
    ; 引擎绑定改了 HotIf 上下文, 复位避免污染后续 launcher 热键
    HotIfWinActive()
}

; VIMD_CMD 派发: run|/key|/dir|/tccmd|/wshkey|/function|
VIMD_CMD(action := "") {
    global g_VimEngine
    if (action = "")
        action := g_VimEngine.lastAction
    if (action = "")
        return
    if (SubStr(action, 1, 4) = "run|")
        Run(SubStr(action, 5))
    else if (SubStr(action, 1, 4) = "key|")
        Send(SubStr(action, 5))
    else if (SubStr(action, 1, 4) = "dir|")
        OpenPath(SubStr(action, 5))
    else if (SubStr(action, 1, 6) = "tccmd|")
        TC_Run(SubStr(action, 7))
    else if (SubStr(action, 1, 7) = "wshkey|") {
        SendLevel 1
        Send(SubStr(action, 8))
        SendLevel 0
    } else if (SubStr(action, 1, 9) = "function|") {
        ; 无 IsFunc 可用: 直调 + OnError 网兜底 (缺失即记日志跳过)
        rest := SubStr(action, 10)
        parts := StrSplit(rest, "|")
        fn := Trim(parts[1])
        arg := parts.Length >= 2 ? Trim(parts[2]) : ""
        if (arg != "")
            %fn%(arg)
        else
            %fn%()
    } else {
        ; <Gen_xxx>/<TC_xxx> 等 Action 名: 转函数名调用 (直调, 缺失走 OnError 网)
        fn := ActionToFuncName(action)
        %fn%()
    }
}
