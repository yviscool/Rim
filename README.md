# Rim

键盘 + 鼠标手势驱动的模式化快速启动器。

Rim 把三种桌面操作能力熔进一个工具：

- **Run** — 一键快速启动（`Win+J` 呼出，模糊匹配文件 / 命令 / 网址）
- **Vim** — 模式化键盘操作（normal / insert，多键序列，计数），为 TC、资源管理器、编辑器注入 Vim 灵魂
- **Swipe / Stroke** — 鼠标手势触发（右键拖拽，方向链 + 字母模板双引擎）

名字取自 **Run + Vim**，也暗示"边缘 / 边界"——在键鼠之间自由游走。

> English: Rim is a keyboard-and-mouse-gesture-driven modal launcher for Windows.
> One tool fusing a fuzzy launcher, Vim-style modal keymaps per application,
> and a stroke-gesture engine. Built with AutoHotkey v2.

## 快速开始

```
# 依赖: AutoHotkey v2 (https://www.autohotkey.com)
# 双击运行
Rim.ahk

# 或命令行
AutoHotkey64.exe Rim.ahk
```

| 快捷键 | 功能 |
|--------|------|
| `Win+J` | 打开快速启动器 |
| `Alt+E` | 打开 / 切换 Total Commander |
| `i` / `Esc` | 进入插入模式 / 返回 normal 模式 |
| `j/k/h/l` | 下 / 上 / 左 / 右 |
| `fc` / `fx` | 复制 / 移动到对侧（TC） |
| `q` | TC 快速预览（再按关闭） |
| `g` 前缀 | 按键提示面板（中文） |
| 右键拖拽 | 鼠标手势 |

## 配置

- 托盘右键 → **配置**：可视化配置中心（按键 / 全局热键 / 插件 / TC 设置 / 启动器 / 动作 / 帮助）
- `Conf/rim.ini`：主配置（文本，注释完整，可手改；配置中心写入时保留注释与顺序）
- `Conf/Skins/`：皮肤

TC 键位沿袭 VimDesktop 原版三源合一：`Conf/rim.ini [TTOTAL_CMD]`（用户定制优先）
+ 插件硬编码 + 458 条 TC 命令编号对照（抽自原版实现）。

## 目录结构

```
Rim/
├── Rim.ahk                 # 主入口
├── Core/                  # 引擎 / 配置 / 搜索 / 执行 / 热键 / 手势
├── Gui/                   # 配置中心 / 手势管理
├── Plugins/               # General / TotalCommander / Explorer / Misc / ...
├── Lib/                   # EasyIni / TCMatch / MonsterEval / JSON
└── Conf/                  # rim.ini / Skins/
```

## 开发

- 加插件：在 `Plugins/` 建 `YourPlugin.ahk`，定义 `RegisterPlugin_YourPlugin()`，
  用 `RegisterAction()` 注册动作、`MapKey()` 绑键，主入口加 `#Include`。
- 加皮肤：在 `Conf/Skins/` 建 `YourSkin.ini`，配置里切 Skin 名。
- 构建号：`Rim.ahk` 顶部 `g_BuildTag`，日志 BUILD 行与配置中心帮助页同源。

## 许可证

MIT License — 见 [LICENSE](LICENSE)。
