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
├── Core/                  # 引擎 / 配置 / 搜索 / 执行 / 热键 / 手势 / 国际化
├── Gui/                   # 配置中心 / 手势管理
├── Plugins/               # General / TotalCommander / Explorer / Misc / ...
├── Lib/                   # EasyIni / TCMatch / MonsterEval / JSON
├── Lang/                  # 语言包 (zh-CN / en 全量, ja/de/fr/es 占位)
├── tools/                 # i18n_audit.py 审计脚本
└── Conf/                  # rim.ini / Skins/
```

## 国际化 (i18n)

- UI 文案一律走 `T("key")` / `T("key", arg...)`（`Core/I18n.ahk`），占位符 `{1} {2}...`，
  缺键自动回落英文，永不抛错。`g_WindowName` 是窗口匹配哨兵，禁止翻译。
- 语言包 `Lang/<bcp47>.ini`（`[Strings]` 段，UTF-8，`\n` 换行），`zh-CN` / `en` 全量，
  其余占位。切换：配置中心 → 启动器 → 界面语言（或 `[Config] Language=auto`）。
- 审计（新增 / 改查 / 覆盖率 / 残留扫描）：
  `python tools/i18n_audit.py audit --check`（CI 门禁），
  `stats` 看覆盖率，`query <key>` 查值与引用，
  `scaffold <lang>` 导出待译 key，`add <key> --zh … --en …` 新增。
- P1 已迁移：托盘 / 启动提示 / 配置中心。P2 已迁移：手势管理 / 全部插件动作与命令描述 /
  Core 手势 OSD / 各插件对话框与帮助（`zh-CN`/`en` 全量约 1640 key）。
  有意保留中文：层存储标识（`全部/全局/应用层:/模板:/黑名单:/内置`）、`MonsterEval` 错误前缀
  （与 `Search` 的 `InStr(val,"错误")` 协议耦合）、日志行、字体名、匹配器（密码排除词、
  网页 class 钩子、API 参数）。`audit --include-plugins` 跟踪残留（应仅剩上述白名单）。

## 开发

- 加插件：在 `Plugins/` 建 `YourPlugin.ahk`，定义 `RegisterPlugin_YourPlugin()`，
  用 `RegisterAction()` 注册动作、`MapKey()` 绑键，主入口加 `#Include`。
- 加皮肤：在 `Conf/Skins/` 建 `YourSkin.ini`，配置里切 Skin 名。
- 构建号：`Rim.ahk` 顶部 `g_BuildTag`，日志 BUILD 行与配置中心帮助页同源。

## 致谢

Rim 站在三位前辈的肩膀上：

- [RunZ](https://github.com/goreliu/runz)（goreliu）—— 快速启动器的设计与实现源头
- [VimDesktop](https://github.com/goreliu/vimdesktop)（goreliu）—— 模式化键盘操作与 TC 键位体系的源头
- [StrokesPlus](https://github.com/roblarky/roblarky.github.io)（roblarky）—— 鼠标手势的设计灵感来源

## 许可证

MIT License — 见 [LICENSE](LICENSE)。
