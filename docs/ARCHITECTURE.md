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

Rim 彻底抛弃了旧时代的黑名单与双轨制加载模式。任何新增功能模块只需继承 `RimPlugin` 即可即插即用：

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
