# Rim

Rim 是一款基于 AutoHotkey v2 的 Windows 桌面工具，将命令启动器、按应用生效的 Vim 风格键位和鼠标手势整合在一起。此仓库提供源码，目前没有安装程序或预编译发布包。

[English](../README.md) · [MIT 许可证](../LICENSE)

## 功能

- **快速启动器：** 搜索并运行索引文件、配置命令及回退动作。搜索结果可结合历史记录和排序；文件索引范围由搜索目录与文件过滤器决定。
- **按应用切换的键盘操作：** 可按窗口或进程配置模式、多键序列、计数和动作。内置映射涵盖 Windows 资源管理器、Total Commander、编辑器和部分桌面应用。
- **鼠标手势：** 按住配置的鼠标键绘制方向手势；可将方向序列或手势模板映射到动作，并设置应用规则和排除项。右键按住时还可直接用滚轮前后切换任务栏窗口，或点一下左键进入音量模式滚轮调音量，详见[滚轮手势专项](gesture-wheel.zh-CN.md)。
- **桌面状态监控：** 可选的悬浮雷达显示 CPU、内存和网络活动，并支持刷新间隔与告警设置。
- **可视化配置中心：** 从托盘菜单管理启动器、热键、插件、Total Commander、手势及其他设置。
- **内置集成：** 启动器与系统命令、资源管理器导航、Total Commander 命令、Vim 风格编辑、媒体控制、二维码工具、文字转换，以及若干第三方应用集成。部分动作需要安装对应应用。
- **界面语言：** 英文和简体中文为完整维护语言。日语、德语、法语和西班牙语目前只有语言名称等少量条目，未翻译内容会回退到英文。

## 默认快捷键

以下全局快捷键来自默认配置 `Conf/rim.ini`，可在配置中心或 `[GlobalHotkey]` 中修改。

| 快捷键 | 功能 |
| --- | --- |
| `Win+J` | 显示或切换启动器 |
| `Win+Backtick` | 显示或切换启动器 |
| `Win+Esc` | 显示或切换启动器 |
| `Alt+Space` | 显示或切换启动器 |
| `Alt+E` | 切换 Total Commander |
| `Win+W` | 切换 VimEditor 集成 |

`h`、`j`、`k`、`l` 等 Vim 风格按键按应用分别配置，并非全局快捷键。例如，默认配置为资源管理器和记事本配置了这些按键。默认手势触发键是鼠标右键；短按仍执行普通右键点击。

## 系统要求

- Windows
- [AutoHotkey v2](https://www.autohotkey.com/)

仓库没有安装程序或预编译发布包，请从克隆后的源码目录运行。

## 开始使用

1. 安装 AutoHotkey v2 并克隆仓库：

   ```powershell
   git clone https://github.com/yviscool/Rim.git
   cd Rim
   ```

2. 首次启动前检查 `Conf/rim.ini`，特别是 `SearchFileDir`、`SearchFileType` 和 `TCPath`。仓库中的示例配置含有开发环境路径，需要按本机情况调整。

3. 检查 `[Config]` 中的 `CreateStartupLnk` 和 `CreateSendToLnk`。示例配置默认启用这两项，用于创建 Windows 启动项和“发送到”快捷方式；不需要时可设为 `0`。

4. 运行脚本：

   ```powershell
   & "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe" .\Rim.ahk
   ```

   如果 `.ahk` 已关联 AutoHotkey v2，也可以直接运行 `Rim.ahk`。

5. 按 `Win+J` 打开启动器。右击 Rim 托盘图标可打开配置中心、手势管理器、状态监控及其他命令。

## 配置

- `Conf/rim.ini`：启动器、全局热键、应用键位、鼠标手势、插件和状态监控配置。
- `Conf/Skins/`：启动器皮肤。
- 托盘菜单中的配置中心提供常用配置项。影响启动过程或底层按键绑定的设置可能需要重启后生效。
- 手势可设为全局或按应用生效；触发键、识别阈值、应用规则、模板和排除项都在 `Conf/rim.ini` 中。滚轮手势（任务栏切换、音量锁存）与提示开关、静止取消等细节见[滚轮手势专项](gesture-wheel.zh-CN.md)。
- 在 `[Config] Language` 设置界面语言。完整语言可使用 `auto`、`en` 或 `zh-CN`。

## 目录结构

```text
Rim.ahk       程序入口
Core/         启动器、配置、搜索、键盘、手势和国际化引擎
Gui/          配置中心与手势管理界面
Plugins/      内置命令和应用集成
Lib/          共用库
Conf/         主配置和皮肤
Lang/         界面语言文件
Assets/       程序 Logo 与 Windows 图标
docs/         项目文档及翻译
tools/        国际化审计与冒烟测试脚本
```

## 开发与检查

CI 会检查国际化 key 覆盖，并在 Windows 上运行 AutoHotkey 解析与插件注册冒烟测试。本地可执行：

```powershell
python tools/i18n_audit.py audit --check
& "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut tools/smoke_parse.ahk
& "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut tools/smoke_register.ahk
```

新增集成时，可在 `Plugins/` 中按现有插件模式注册动作或命令，并从 `Rim.ahk` 引入。UI 文案请维护在 `Lang/en.ini` 与 `Lang/zh-CN.ini`，之后运行国际化审计。

## 致谢

- [RunZ](https://github.com/goreliu/runz)：启动器设计与实现基础。
- [VimDesktop](https://github.com/goreliu/vimdesktop)：模式化键盘操作及 Total Commander 键位体系来源。
- [StrokesPlus](https://roblarky.github.io/)：鼠标手势设计灵感。

## 许可证

Rim 使用 [MIT License](../LICENSE)。
