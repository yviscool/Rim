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

全插件经 `RimPlugin` 六阶段直注：命令进 `RimCommand`（`RegisterCommands`，字符串动作或闭包，无别名表），Vim 映射经 `engine.SetWin/SetAction/MapKey`（`RegisterKeymaps(engine)`），手势经 `GestureRegistry`，上下文经 `RimContext`。无白名单、无字符串分发、无双轨。`OnExitAll` 由进程退出回调触发，见 `Rim.ahk Rim_OnExit`。新增插件 checklist：

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

> 新增插件 checklist：
> 1. `Plugins/Foo.ahk` 写 `class FooPlugin extends RimPlugin` + 尾部 `RimPluginManager.Register()`，各阶段方法内直调引擎/注册表（命令见 Misc，键位见 TotalCommander）。
> 2. `Rim.ahk` 加 `#Include *i Plugins\Foo.ahk`。
> 3. `Conf/rim.ini [Plugins]` 加 `Foo=1`（开关大小写不敏感，见 `Core/Plugin.ahk IsEnabled`）。
> 4. 用户可见串走 `T("...")` 并在 `Lang/en.ini + zh-CN.ini` 补键，跑 `python tools/i18n_audit.py audit --check`。
> 5. 手势插件判 `IsSet(GestureRegistry)` 后注册；探针 `smoke_register` 加对等计数断言。

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

## 六、插件与拆分现状（零兼容）

### 1. 统一现状
- 全插件（命令 8 个 Hybrid 类＋Vim 11 个 Hybrid 类）经 `RimPlugin` 六阶段直注：命令 `RegisterCommands()` 直调 `RimCommand.Register`，键位 `RegisterKeymaps(engine)` 直调 `engine.SetWin/SetAction/MapKey`。`LoadLegacy*` 适配器、`LegacyVimPlugins` 白名单、6 个全局注册函数、`RegisterPlugin_*` 旧入口已全部删除；`smoke_register` 以对等计数断言（10 插件 W/A/M/G/Mode/X 精确值）锁死映射不丢失。
- `g_FuncAlias` 已退役：function 型命令内联为 `RimCommand`（闭包经 `LegacyDirectCall` 直调真实函数）；`ResolveFuncAlias` 及 `SearchTargetKey` 别名分支已删。现代指令池行统一三段式 `command | id | label`（旧四段式会被解析器误判 key/type，从启动器回车现代命令此前根本跑不通）。
- 小语种缺口（`python tools/i18n_audit.py scaffold <lang>` 实测 de 缺约 1900 键，en/zh 双全量约 1918 键）：机翻填 `Lang/*.ini` 后跑 `audit --check` 即可合，翻不翻、机翻审不审由维护者定，CI 只卡 en/zh。

### 2. 巨石拆分图（已执行完毕，入口均为 Hybrid 类方法）
- `Plugins/Misc.ahk (1693)` → 主文件 `MiscPlugin.RegisterCommands`（9 url 直注＋20 功能直注，旧 SearchOn*/Dictionary 别名已删）＋共享 `MiscPipeInput/UriEncode/EvalExpression`，纯实现下沉 `Misc.Search.ahk`（搜索/翻译）/ `Misc.Clip.ahk`（剪贴板日期取色）/ `Misc.Net.ahk`（IP/WiFi/DNS/Ping/公网/环境）/ `Misc.Codec.ahk`（汇率/万年历/URL编解码/RunClipboard/帮助），经主文件 `#Include` 组装。
- `Plugins/StatsBall.ahk (1793)` → 采样 `StatsBall.Sample.ahk`（CPU/内存/网速/Top进程/Boost数据）＋ 自绘 `StatsBall.Render.ahk`（GDI+三段横条）＋ 主文件（入口/`g_StatsBall`/`StatsBallObj` 类整体保留：方法经 `this` 互调，类内不可再切），经主文件 `#Include` 组装（注册期不建窗的 headless 约束不变）。
- `Plugins/TotalCommander.ahk (3798)` → 自造菜单 `TC.Menu.ahk`（定位/级联/字母跳转/回车确认/新建文件对话框，原 1803–2715）独立文件、`#Include` 组装；映射表与动作主体留本文件（`TC_MenuRouteKey` 直调探针覆盖，不走 `Send` 回环）。
- `Core/Hotkeys.ahk (657)` 已拆：绑定与窗口行为留本文件，rank/历史/文件/配置/帮助/管道迁 `Hotkeys.Commands.ahk`，经 `#Include` 组装（`BindLauncherHotkeys` 引用的函数对象在调用期解析，不受文件位置影响）。
- `Core/SmartInput.ahk (860)` 已拆：`*Pure` 九函数迁 `SmartInputPure.ahk`（零 GUI/零配置依赖，`smoke_si` 直测；与 `CmdLine_Parse` 同文法，改一处同步另一处）。
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
- 待补（本轮脚本已就绪，工作流文件等脏区落地后加两行）：`probe_gesture_store/unified/fix` 进 `smoke` job；`benchmark_gesture.ahk` P95 门禁（>50ms 即非 0 退出，A_TickCount 量子约 15.6ms，50ms 防抖动误杀，本地基线 16ms）。

### 5. 排序 frecency（指数半衰）
- 公式：`score = min(visits,25) × 0.5^(daysSinceUse/半衰期)`，精确桶永远第一，非精确桶内前缀子桶优先、同分保注册序。
- 存储 `[Rank] key = visits|YYYYMMDD`（旧裸整数按极旧计，一次使用即回血）；半衰期默认 14 天，`[Config] RankHalfLife` 可调；手动 `^n/^p` 为 ±10（一次就有话语权）；`ChangeRank` 30 秒节流落盘，退出照常全量保存。
