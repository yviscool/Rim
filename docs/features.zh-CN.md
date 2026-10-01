# 功能详解

[English](features.md) · [返回文档索引](README.md) · [滚轮手势专项](gesture-wheel.zh-CN.md)

本文按默认配置（`Conf/rim.ini` + 内置插件）介绍全部常用功能。所有行为都可在配置中心或直接改 ini 调整。

## 一、启动器

按 `Win+J`（或 `Win+\``、`Win+Esc`、`Alt+Space`）呼出/隐藏。输入即搜，回车即跑。

### 1.1 能搜到什么

- **文件索引**：`[Config] SearchFileDir` 目录下的 `SearchFileType` 文件（默认 D 盘软件目录的 exe/lnk），`SearchFileExclude` 排除卸载类文件。改完范围后在启动器里 `Ctrl+R` 重建索引。
- **`[Commands]` 自定义命令**：`名字=类型|内容|说明`，类型有 `run`（运行程序）、`url`（打开网址）、`function`（调内部函数）。默认自带 `notepad`、`cmd` 等，外加 `settings`（打开配置）、`reload`（重启 Rim）、`exit`（退出）；计算器、翻译、搜索这类活都由插件命令承担（见 1.4）。
- **插件命令**：见 1.4，数量最多的一类。

### 1.2 输入框操作

| 按键 | 作用 |
| --- | --- |
| `Enter` | 执行选中项 |
| `Up`/`Down`、`Ctrl+J`/`Ctrl+K` | 上下移动选择 |
| `Ctrl+F`/`Ctrl+B` | 输出区下翻/上翻页 |
| `Tab` / `→` | 接受灰字补全；`Ctrl+→` 只接受一词 |
| `Alt+↑`/`Alt+↓` | 按内容翻历史（`↑↓` 本身仍翻列表） |
| `Space` | 结果过滤模式 |
| `Alt+字母/数字` | 按首字母/序号直接执行该行 |
| `Ctrl+Enter` | 把当前输入存为管道参数 |
| `Ctrl+H` | 显示历史 |
| `Ctrl+N`/`Ctrl+P` | 增加/减少该命令权重（影响排序） |
| `Ctrl+D` | 在 TC 中打开当前文件目录 |
| `Ctrl+X` | 删除当前文件 |
| `Ctrl+S` | 显示完整路径并复制 |
| `Ctrl+L`/`Ctrl+U` | 清空输入 |
| `Ctrl+I`/`Ctrl+O` | 光标到行首/行尾 |
| `Ctrl+R` / `Ctrl+Q` | 重建索引 / 重启 Rim |
| `F1` | 帮助；`Shift+F1` 按键帮助 |
| `F2` / `F3` | 编辑配置 / 自动配置 |
| `Esc` | 先清空输入，再关闭 |

输入增强（`[SmartInput]`，默认全开）：

- **灰字补全**：根据历史和候选实时显示灰色后缀，`Tab` 吃掉。
- **历史翻找**：`Alt+↑↓` 按输入内容过滤历史。
- **输入校验**：未知命令头会给输入框染底色提示，防抖 300ms。
- **隐私保护**：含 password/token/secret/密码/身份证等字样的输入不记历史，可在 `PrivacyExtra` 追加。
- **自动排序**：`AutoRank=1` 时常用命令自动靠前；`RunIfOnlyOne=1` 可让唯一结果直接运行。

### 1.3 命令前缀

| 前缀 | 含义 | 例子 |
| --- | --- | --- |
| `;` | 用 AHK 直接运行 | `;MsgBox("hi")` |
| `:` | 用 CMD 运行 | `:dir` |
| `\|` | 管道参数（配合 `Ctrl+Enter` 存参） | 先 `Ctrl+Enter` 存参，再 `\|` 引用 |
| `@` | 跳转 | `@` 类命令 |
| 无前缀直接输网址 | 打开浏览器 | `github.com` |
| 搜不到时 | 走 `[FallbackCommand]`：AHK 运行 / CMD 运行 / Win+R 运行 / CMD 运行并显示结果 / 谷歌百度必应搜索 | 输入即有对应行可选 |

### 1.4 常用命令速查

插件命令直接输名字（支持中英文、支持 `{query}` 带参，参数跟在名字后空格输入）：

| 类别 | 命令 | 说明 |
| --- | --- | --- |
| 搜索 | `Google`、`Baidu`、`Bing`、`GitHub`、`Zhihu`、`Bilibili`、`Taobao`、`JD`、`Npm` | `Google xxx` 即搜 xxx |
| 计算翻译 | `Calc`、`Eval` | 计算表达式；`Translate`/`En2Cn`/`Cn2En`/`Dictionary` 查词翻译 |
| 货币 | `CNY2USD`、`USD2CNY`、`CurrencyRate` | 汇率换算与查询 |
| 编码 | `UrlEncode`、`UrlDecode` | URL 编解码（对剪贴板/输入） |
| 剪贴板 | `ClipShow`、`ClipClear`、`ClipSave`、`Clip` | 查看/清空/保存剪贴板 |
| 日期 | `Date`、`Time`、`DateTime`、`Calendar` | 插入日期时间、日历 |
| 取色 | `ColorPicker`、`ColorInfo` | 屏幕取色 |
| 网络 | `ShowIp`、`PubIp`、`Wifi`、`Dns`、`Ping`、`Env` | 本机/公网 IP、WiFi、DNS、ping、环境变量 |
| 系统 | `ShutdownMachine`、`RestartMachine`、`SuspendMachine`、`HibernateMachine`、`Logoff` | 关机/重启/睡眠/休眠/注销 |
| 系统 | `EmptyRecycle`、`ListProcess`、`KillProcess`、`ListWindow`、`ActivateWindow`、`DiskSpace`、`SystemState`、`IncreaseVolume`、`DecreaseVolume` | 清空回收站、进程/窗口管理、磁盘、系统状态、音量 |
| 繁简 | `Kanji2S`/`T2S`、`Kanji2T`/`S2T` | 繁简转换 |
| 二维码 | `QRCode`、`QRText`、`QRClip`、`QRUrl` | 文本/剪贴板/网址转二维码 |
| 启动器 | `Help`、`KeyHelp`、`ReindexFiles`、`EditConfig`、`RunClipboard`、`ListPlugin` | 帮助、重建索引、改配置、运行剪贴板内容、插件列表 |

## 二、鼠标手势

默认右键按住拖拽画手势，松开触发；**短点一下仍是普通右键**；绘制中按 `Esc` 取消。手势名由方向组成（`U/D/L/R` 及 `UR/UL/DR/DL`，多笔用 `_` 连接，如 `D_R`），外加单字母形状模板（`G/P/N/S/M/Z/B/X` 等）。

### 2.1 常用手势（全局默认）

| 手势 | 动作 | 手势 | 动作 |
| --- | --- | --- | --- |
| `L` / `R` | 浏览器后退/前进 | `U` / `D` | 复制/粘贴 |
| `UR` | 最大化 | `DL` | 最小化 |
| `UL` | 关闭窗口（Alt+F4） | `DR` | 关闭标签（Ctrl+W） |
| `U_D` | 刷新（F5） | `U_D_U` | 重载 Rim |
| `D_R` | 新建标签 | `D_L` | 关闭标签 |
| `L_R` / `R_L` | Win+左/右分屏 | `R_D` | 打开 Chrome |
| `L_D` | 打开资源管理器 | `L_U` | 回顶部 |
| `G` | 打开 Google | `P/N` | 播放暂停/下一首 |
| `M` | 静音 | `X` | 剪切 |
| `LETTER_U/R` | 撤销/重做 | `Z` | 滚轮缩放组合 |
| `WheelUp/Down` | 切换任务栏窗口 | `Ctrl+Wheel` | 系统音量 |

滚轮手势另有专项说明（含"右键按住点左键进音量模式"）：[滚轮手势](gesture-wheel.zh-CN.md)。

### 2.2 应用层覆盖

同名手势在特定应用里动作不同（`[GestureApp:*]`），优先级高于全局：

- **TotalCommander**（`TOTALCMD.EXE`）：`D_R` 新建文件夹（F7）、`D_L` 删除（F8）。
- **浏览器**（Chrome/Firefox/IE）：`L/R` 切换标签、`U/D` 行首行尾、`U_D` 恢复标签、`R_U` 全屏、`B` 收藏、`H` 主页、`3` 新建标签等。
- **桌面**：几个斜线手势被吞掉（防误触）。

### 2.3 管理与设置

托盘 → 手势管理：录新手势、给形状录样本、增删改查、黑名单、导入导出、演练模式（只显示识别结果不执行）。设置页可调触发键、触发距离、采样间隔、静止取消、形状阈值、轨迹线、提示开关等，保存即时生效。命中黑名单（`[GestureBlacklist]`，如游戏进程）的窗口里手势全旁路，鼠标行为完全不变。

## 三、Vim 风格键位

键位按应用生效（进程名/窗口类/标题匹配），每个应用节可设多键序列超时（`set_time_out`，默认 800ms）。`h/j/k/l` 这类键只在配置了的应用里接管，其他地方保持原生。

模式与开关（各窗通用）：大部分窗口分 `normal` / `insert` 两态，`i` 进输入、`Esc` 回普通并透传 `Esc`；`?` 在应用内弹出 condensed 键表（与下文表格一致）；`3j` 这类数字前缀对可重复动作生效；`Win+W` 按窗口独立开关（即时生效，不用重启）；在窗口节加 `vim_enable=0` 则持久关闭该窗接管（重启仍有效）。

### 3.1 全局热键（默认）

| 热键 | 动作 |
| --- | --- |
| `Win+J` / `Win+\`` / `Win+Esc` / `Alt+Space` | 呼出/隐藏启动器 |
| `Alt+E` | 打开/切换 Total Commander |
| `Win+W` | 开关当前窗口的 Vim 接管（真开关，即时生效） |
| `Alt+H` | 一键居中活动窗口 |

### 3.2 Total Commander（`TTOTAL_CMD`，精选）

移动：`h` 上级目录、`j/k` 上下、`l` 进入（超级回车）、`a` 全选；文件：`c` 新建目录、`i` 新建文件、`e` 编辑、`d` 标记列表、`o` 右键菜单、`p` 打包、`b` 解包、`u` 关当前标签；`zz`/`zh` 50/100% 分栏切换；`f2` 改名、`f5` 重启 TC、`f9/f10` 队列复制/移动、`f11/f12` 前后标签；`Shift+A–Z` 一批 cm_ 命令（查看/搜索/同步/比较等）；`Ctrl+字母` 一批跳转（`Ctrl+T` 新标签打开目录、`Ctrl+Q` 命令选择等）。完整映射见 `Conf/rim.ini [TTOTAL_CMD]`。

### 3.3 资源管理器（`CabinetWClass`）

`h` 后退、`l` 回车进入、`j/k` 上下、`t` Tab 切换焦点、`f` 把当前目录甩到 TC。

### 3.4 记事本类（`Notepad` / `Notepad++`）

`i` 进插入模式、`Esc` 回普通模式；普通模式下 `h/j/k/l` 移动、`w/b/e` 单词跳转、`0/$` 行首尾（`0`/`Shift+4`）、`dd` 删行、`yy` 复制行、`p` 粘贴、`u` 撤销、`Ctrl+R` 重做、`x` 删字符、`a/o/I/A/O` 进入各种插入、`v` 可视模式、`/` 搜索、`n/N` 下上一个匹配。

Typora / CMD 窗口节已预留（匹配规则就绪），暂无默认键位，可自行添加。持久关闭某窗口的接管：在其窗口节加 `vim_enable=0`（重启仍有效，见上）。

### 3.5 浏览器（Chrome / Edge / Firefox，`Browser` 插件）

滚动：`j/k/h/l`、`d/u` 半页、`Ctrl+D/U`、`Ctrl+F/B` 整页、`gg/G` 顶底、`0/$` 行首尾；标签：`t` 新建、`x` 关闭、`X` 恢复、`J/K`（`gn/gp` 同义）前后、`g1..g8`/`g0` 跳转；历史：`H/L` 后退前进、`r` 刷新、`R` 硬刷新；`o` 地址栏、`/` 查找、`n/N` 上下匹配（自动进 insert）；`zi/zo/z0` 缩放、`b` 收藏、`gh` 历史、`gd` 下载；`i/a` 进输入、`Esc` 回普通、`?` 帮助。默认进 insert（`[Browser_*] default_mode`，可在配置中心改回）。`f` 故意留空透传，给 Surfingkeys / Vimium 类扩展的链接提示让路（两者可混用）。

### 3.6 Excel（`XLMAIN`，`Excel` 插件，复刻 VimDesktop 按键层，免 COM）

移动：`h/j/k/l`、`H/J/K/L` 扩展选择、`gg/G` 表首尾（`Ctrl+Home/End`）、`0` 首列、`$` 区域右沿、`gk/gj/gh/gl`（`sk/sj/sh/sl` 同义）区域边缘；翻页：`Ctrl+D/U`、`Space/Shift+Space`；编辑：`i`（发 F2 进单元格）、`a` 行尾追加、`I` 功能区键提示；剪贴：`x` 剪切、`dd/D` 清除、`yy/Y` 复制、`yr/yc` 整行列复制、`p` 粘贴、`P` 选择性粘贴、`yh/yl/yk/yj` 邻格复制、`Fj/Fl` 向下/右填充（`Ctrl+D/R`）；查找：`/` 查找、`R` 替换、`go` 定位（F5，自动进 insert）；工作表：`gt/gT` 前后（`Ctrl+PgDn/PgUp`）；`sr/sc/sa` 选整行/列/全；`or/oc/Or/Oc` 插行列（中文界面右键菜单序列）；`ZZ` 保存并关闭、`ZQ` 只关闭（保存弹窗自己点，无 COM 静默弃存）。安全：normal 下未映射单字符一律吞掉（防写进单元格），打字按 `i`；`u` 撤销、`Ctrl+R` 重做。深 COM 功能（自动筛选、颜色、合并）本期不做。

### 3.7 Everything（`EVERYTHING`，`Everything` 插件）

`j/k` 上下、`gg/G`/`0` 首尾、`Enter` 原生打开、`i` 或 `/` 聚焦搜索框（自动进 insert）、`Esc` 回普通、`?` 帮助。搜索框/重命名框聚焦时全部透传；normal 下未映射字母透传即快搜，不吞键。默认进 insert（`[Everything] default_mode`，可在配置中心改回）。

### 3.8 PDF（SumatraPDF + 福昕，`Pdf` 插件）

Sumatra 按类名精确匹配，福昕（类名多变）按 `FoxitReader.exe` / `FoxitPDFReader.exe` 兜底。`j/k/h/l` 滚动、`d/u` 翻页（Space）、`Ctrl+D/U` 大翻页（PgDn/PgUp）、`gg/G` 首尾、`0/$`、`/` 查找（自动进 insert）、`n/N` 上下匹配（F3）、`zi/zo/z0` 缩放（best-effort）、`Esc` 回普通、`?` 帮助。

自定义：在配置中心可视化改，或按 ini 格式 `按键=<动作>[=模式]` 写，如 `dd=<deletedLine>[=normal]`。动作名参考 General 插件（方向/窗口管理/标签页/鼠标模拟等）与各应用插件。

默认模式：窗口节加一行 `default_mode=insert`（或 `normal`），该窗启动即进此模式，覆盖插件硬编码（如 Everything 默认 insert、浏览器默认 insert 都可被翻转）。配置中心按键页右下“默认模式”下拉与窗口选择联动，`(跟随默认)` 即删键（完全恢复要重启）。非法值保存时进重启单，不会断启动。

## 四、托盘与配置中心

右击托盘图标：显示启动器、手势管理、配置中心、悬浮球开关、暂停、重启、退出。配置中心可改启动器、雷达、智能输入、热键、插件开关、TC、Vim 映射等；`[Plugins]` 可按需开关各插件（见 `Conf/rim.template.ini`）。

## 五、悬浮球（StatsBall）

桌面三段雷达：CPU / 内存 / 网速，秒级刷新，占用超阈值告警，可调刷新间隔、透明度、置顶、锁定位置。托盘开关，不想要可关。

## 六、语言

`[Config] Language`：`auto` 跟系统，`zh-CN` / `en` 完整维护；日德法西仅少量条目、缺失回落英文。
