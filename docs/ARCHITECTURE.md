# Rim 架构总览与技术设计规范 (Architecture Specification)

> **定位**：Rim 是为 Windows 平台打造的高性能人机交互与操作编排系统（Windows Human-Machine Operation Layer），深度融合快速启动器、全局 Vim 模式、低级鼠标手势与工作空间编排。

---

## 一、分层架构模型 (6-Tier Architecture)

Rim 采用严格的单向依赖 6 层架构模型，杜绝模块间的循环依赖与交叉硬编码：

```
┌────────────────────────────────────────────────────────────────────────┐
│ 1. 体验层 (Experience Tier)                                           │
│    - Launcher UI (单例浮动输入框、自适应列表、圆角毛玻璃)                 │
│    - StatsBall (GDI+ Layered 悬浮雷达球、网速/内存/进程自绘)             │
│    - Gesture Trail & Preview (分段贝塞尔手势轨迹、可视化提示窗)           │
├────────────────────────────────────────────────────────────────────────┤
│ 2. 交互层 (Interaction Tier)                                           │
│    - SmartInput (Ghost Text 幽灵补全、前缀/子串模糊多模态匹配)           │
│    - VimEngine (模态按键调度器、Leader Key 多键序列缓冲、动作过滤器)      │
│    - GestureEngine (WH_MOUSE_LL 低级鼠标钩子、8向特征提取、容差判决)     │
├────────────────────────────────────────────────────────────────────────┤
│ 3. 命令与编排层 (Command & Orchestration Tier)                         │
│    - RimCommand (统一语义指令注册表、分类索引、上下文前置过滤)             │
│    - RimWorkspace (工作空间引擎、多窗口/编辑器/终端/文件管理器一键联动)   │
│    - RimWindow (监视器感知窗口分屏、多显示器比例抛掷、纯 Win32 调度)      │
│    - Execution Pipeline (ExecuteAction 统一协议派发)                   │
├────────────────────────────────────────────────────────────────────────┤
│ 4. 上下文感知层 (Context Awareness Tier)                              │
│    - RimContext (活动窗口焦点提取、输入框智能判定、路径提取 Provider)    │
│    - ExplorerProvider / TCProvider / TerminalProvider                 │
├────────────────────────────────────────────────────────────────────────┤
│ 5. 扩展与插件层 (Integration & Plugin Tier)                           │
│    - RimPlugin (标准插件生命周期抽象契约)                                │
│    - RimPluginManager (自动发现、沙箱隔离调用、向下兼容分发适配器)        │
├────────────────────────────────────────────────────────────────────────┤
│ 6. 系统底层驱动 (Windows Subsystem Tier)                              │
│    - Win32 API 原生互操作 (MoveWindow, MonitorFromWindow, DllCall)     │
│    - 内存对齐标定 (MONITORINFO cb=40, PROCESSENTRY32W cb=568)          │
│    - 线程级消息泵与钩子安全隔离                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 二、统一插件架构契约 (`Core/Plugin.ahk`)

Rim 正在从双轨制向统一插件契约过渡。现状是过渡态：新插件继承 `RimPlugin` 即插即用，11 个历史 Vim 插件仍经 `RimPluginManager.LegacyVimPlugins` 白名单 + `RegisterPlugin_*` 字符串协议分发（命令通道在 `Core/Files.ahk:238 RegisterAllCommands`，Vim 通道在 `Rim.ahk` 引擎就绪后；`OnExitAll` 由进程退出回调触发，见 `Rim.ahk Rim_OnExit`）。新增插件 checklist：

### 1. 生命周期阶段 (Lifecycle Phases)

```
[Boot]
  │
  ├─ 1. RimPluginManager.InitAll()
  │     └─ Plugin.Init()                 (配置解析、状态初始化)
  │
  ├─ 2. RimPluginManager.RegisterAllContexts()
  │     └─ Plugin.RegisterContext()      (向 RimContext 注入 Provider)
  │
  ├─ 3. RimPluginManager.RegisterAllCommands()
  │     └─ Plugin.RegisterCommands()     (向 RimCommand 注册一级语义指令)
  │
  ├─ 4. RimPluginManager.RegisterAllKeymaps(engine)
  │     └─ Plugin.RegisterKeymaps(vEng)  (向 VimEngine 注入窗口/模式/按键)
  │
  ├─ 5. RimPluginManager.RegisterAllGestures()
  │     └─ Plugin.RegisterGestures()     (向手势引擎挂载专属动作)
  │
[Shutdown / Reload]
  └─ 6. RimPluginManager.OnExitAll()
        └─ Plugin.OnExit()               (销毁外部钩子、专属定时器)
```

> 新增插件 checklist（缺一即静默不加载，无报错）：
> 1. `Plugins/Foo.ahk` 写 `RegisterPlugin_Foo()`（旧）或 `class FooPlugin extends RimPlugin` + 尾部 `RimPluginManager.Register()`（新；Vim 部分仍需旧函数）。
> 2. `Rim.ahk` 加 `#Include *i Plugins\Foo.ahk`（目录扫描只填名单不加载代码）。
> 3. `Conf/rim.ini [Plugins]` 加 `Foo=1`（开关大小写不敏感，见 `Core/Plugin.ahk IsEnabled`）。
> 4. 用户可见串走 `T("...")` 并在 `Lang/en.ini + zh-CN.ini` 补键，跑 `python tools/i18n_audit.py audit --check`。
> 5. Vim 插件确认 `LegacyVimPlugins` 名单；手势插件判 `IsSet(GestureRegistry)` 后注册。

### 2. 标准插件实现范式 (示例)

```ahk
#Requires AutoHotkey v2.0

class ObsidianPlugin extends RimPlugin {
    static Name => "Obsidian"
    static Title => "Obsidian Knowledge Base Integration"
    static Description => "Obsidian 笔记库快速定位、新建即时日记与 Vim 增强"

    ; 1. 初始化
    static Init() {
        ; 读取专属配置等
    }

    ; 2. 上下文感知
    static RegisterContext() {
        RimContext.RegisterProvider("obsidian", (hwnd) => Map(
            "appId", "obsidian",
            "currentDir", "D:\Notes\Vault"
        ))
    }

    ; 3. 语义指令
    static RegisterCommands() {
        RimCommand.Register("obsidian.daily", "Open Daily Note", (*) => Run("obsidian://open?vault=Vault"), Map(
            "Category", "Note",
            "Description", "打开今日随手记"
        ))
    }

    ; 4. Vim 模式
    static RegisterKeymaps(engine) {
        engine.RegisterWin("Obsidian", "Chrome_WidgetWin_1", "Obsidian.exe")
        engine.MapKey("<C-n>", "obsidian.daily", "Obsidian", "normal")
    }
}

; 注册至管理器
RimPluginManager.Register(ObsidianPlugin)
```

---

## 三、执行管道 (`Core/Execution.ahk`)

所有触发源（Launcher 回车、按键映射、鼠标手势、托盘菜单、脚本自调用）一律汇聚到统一执行协议：

```ahk
ExecuteAction(action, actionArg := "")
```

- **三段式/四段式协议支持**：
  - `run|path`：执行外部程序/脚本
  - `key|keys`：键盘序列宏模拟
  - `dir|folder`：打开文件夹
  - `cmd|command`：控制台运行命令
  - `url|link`：浏览器打开网址
  - `function|fn|arg`：动态函数调用
  - `command|id` 或裸 ID：转交 `RimCommand.Execute` 执行，自动享受上下文环境过滤！

---

## 四、手势子系统解耦架构 (`Core/Gesture/`)

针对历史巨石 `Core/Gesture.ahk` (1824行) 进行了彻底的模块化解耦与低级钩子加固：

```
Core/Gesture.ahk (主门面 Facade, 保持向后兼容 API 与全局 Map)
  ├── Gesture/Recognizer.ahk  (纯数学特征提取与8向向量量化器，零 UI/状态依赖)
  ├── Gesture/Registry.ahk    (动态手势注册中心，支持插件与代码动态注册、目标窗口过滤)
  ├── Gesture/Hook.ahk        (低级钩子守卫，零冻结保护，原子化点击重放与采样)
  └── Gesture/Engine.ahk      (协调调度引擎，多层解析: Registry -> App -> Global -> Template)
```

- **零冻结保护 (Zero-Freeze Guard)**：
  - Windows `LowLevelHooksTimeout` 机制会在钩子回调超过 200ms 时静默移除低级钩子。`GestureHook` 将采样与判定完全下沉至异步定时器，钩子回调 1ms 内瞬间返回，并在短点（无位移松开）下无缝重放物理按键原生点击，保留普通右键菜单与上下文菜单。
- **动态手势注册 API**：
  - 插件通过 `GestureRegistry.Register(pattern, action, targetWin, options)` 动态挂载手势，支持 `exe/cls/title/ctrlCls` 窗口特征精确匹配。

---

## 五、健壮性与安全规则 (Engineering Rules)

开发与维护 Rim 必须严格恪守以下原则（血泪汇总见根目录 `AGENTS.md`）：

1. **Win32 结构体尺寸禁止手算**：
   - 跨进程结构体与 Windows API 结构体，必须使用 Python `ctypes.Structure` 依照 MSVC 对齐规则在真机严格标定（如 `MONITORINFO: cbSize=40, rcWork@20`）。
2. **Win32 窗口操作使用纯 API**：
   - 窗口分屏与位移一律采用 Win32 原生 `MoveWindow` / `SetWindowPos`，严防 AHK `WinMove` 在无头探针或非激活状态下的挂起陷阱。
3. **低级钩子与 OnMessage 隔离**：
   - 线程级消息回调（如 `0x202 WM_LBUTTONUP`）禁止无条件调用 `ReleaseCapture()`，只能释放本窗口捕获的句柄，防止篡改系统其他应用的按钮交互。
4. **路径解析相对化**：
   - 库与模块内读取数据或配置，严禁使用 `A_ScriptDir` 拼接，统一采用 `A_LineFile` 反查根目录，确保从子目录或测试脚本执行时均不丢失依赖。

---

## 六、Legacy 退役与巨石拆分路线

### 1. Hybrid 现状（新壳旧体，行为不变）
- `TotalCommander / Explorer / LauncherSystem`（早先）＋ `QRCode / Kanji`（本轮）：`class XxxPlugin extends RimPlugin` 只做通道注册，体内转调旧 `RegisterPlugin_*()`。`LoadLegacyCommandPlugins` 以 `Plugins.Has(小写名)` 去重，不会 double-register。
- 每迁完一个 legacy 插件：从 `LegacyVimPlugins` 删名（Vim 通道）或确认命令通道单注册，记 CHANGELOG；`g_FuncAlias` 别名表随最后一个 legacy 命令插件退役而 sunset。`VimDConfig` 留 Vim 通道（`RegisterAction` 需引擎，勿动）。
- TODO `Plugins/MicrosoftExcel.ahk`：三层全死（`Rim.ahk` 未 `#Include` ＋ 无 `RegisterPlugin_*` 入口 ＋ ini 置 0），55 动作/54 映射为旧 `Plugin` 基类写法，待 COM 重移植后按 Hybrid 重写或删除（2026-09 决议：先留）。
- `g_FuncAlias` sunset 条件（非日期）：全部 `RegisterCommand(name,"function",...)` 调用方（Misc / QRCode / Kanji / LauncherCore-Host / LauncherSystem / StatsBall / VimDConfig）迁为 `RimCommand.Register` 后，删除 `LauncherCompat.AddCommand` 别名分支 + `ResolveFuncAlias` + `SearchTargetKey` 的别名回查。QRCode/Kanji 虽已 Hybrid 但仍走旧 `RegisterCommand`，别名表暂不可删。
- 小语种缺口（`python tools/i18n_audit.py scaffold <lang>` 实测 de 缺约 1900 键，en/zh 双全量约 1918 键）：机翻填 `Lang/*.ini` 后跑 `audit --check` 即可合，翻不翻、机翻审不审由维护者定，CI 只卡 en/zh。

### 2. 巨石拆分图（按注释边界机械切，对外仅保留原 `RegisterPlugin_*` 入口）
- `Plugins/Misc.ahk (1693)` → 主文件保留聚合注册（44 命令零增减）＋共享 `MiscPipeInput/UriEncode/EvalExpression`，纯实现下沉 `Misc.Search.ahk`（搜索/翻译）/ `Misc.Clip.ahk`（剪贴板日期取色）/ `Misc.Net.ahk`（IP/WiFi/DNS/Ping/公网/环境）/ `Misc.Codec.ahk`（汇率/万年历/URL编解码/RunClipboard/帮助），经主文件 `#Include` 组装（`smoke_register` 命令数断言不变）。
- `Plugins/StatsBall.ahk (1793)` → 采样 `StatsBall.Sample.ahk`（CPU/内存/网速/Top进程/Boost数据）＋ 自绘 `StatsBall.Render.ahk`（GDI+三段横条）＋ 主文件（入口/`g_StatsBall`/`StatsBallObj` 类整体保留：方法经 `this` 互调，类内不可再切），经主文件 `#Include` 组装（注册期不建窗的 headless 约束不变）。
- `Plugins/TotalCommander.ahk (3798)` → 自造菜单 `TC.Menu.ahk`（定位/级联/字母跳转/回车确认/新建文件对话框，原 1803–2715）独立文件、`#Include` 组装；映射表与动作主体留本文件（`TC_MenuRouteKey` 直调探针覆盖，不走 `Send` 回环）。
- `Core/Hotkeys.ahk (657)` 按“绑定 vs rank/历史/文件业务”拆；`Core/SmartInput.ahk` 的 `*Pure` 纯函数抽独立可测库。
- 物理搬移待工作区脏文件落地后一次性执行（本轮只定边界，不断编译）。

### 3. 真机回归最小清单（headless 探针测不到输入路由，必须人手过）
1. Explorer 拖文件时画手势：文件不丢、不误触，短点右键菜单正常。
2. 桌面空白右键菜单、浏览器拖选文本，长按不触发。
3. R+滚轮切任务栏窗口（含最小化恢复不闪烁），R+左键点+滚轮进音量模式，松开不弹菜单。
4. TC 下 i 菜单：F/S/上下/回车/Esc，菜单未抢到焦点时不吞键。
5. 多屏 + 125%/150% DPI：手势轨迹不断裂，StatsBall 贴边位置正确。
6. 睡眠唤醒后钩子仍在（`LowLevelHooksTimeout` 200ms 零冻结），托盘图标不 Doppelganger。

### 4. CI 门禁现状
- 已有：`i18n_audit --check` ＋ `smoke_parse/register/si/command/context/plugin/workspace/gesture/audit_fixes`（见 `.github/workflows/i18n.yml`）。
- 待补（本轮脚本已就绪，工作流文件等脏区落地后加两行）：`probe_gesture_store/unified/fix` 进 `smoke` job；`benchmark_gesture.ahk` P95 门禁（>30ms 即非 0 退出，本地基线 16ms）。
