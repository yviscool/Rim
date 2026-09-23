# Rim 手势系统对标调研与下一步规划

调研日期：2026-09-23。范围：本仓库手势代码、经典 StrokesPlus 源码与帮助文档、StrokesPlus.net 归档文档及官网发布/变更记录。这里是静态代码与文档审查，不包含真人绘制数据、真机鼠标拖拽实验或新版闭源识别器的逆向结果。

实施进度（同日）：本报告的问题清单记录的是修改前基线。当前工作区已修预览函数、改名/换层残留、`GestureDesc` 包遗漏、模板 `noglobal`，并加了停住超时接管与未命中轨迹回放。`tools/probe_gesture_store.ahk` 和 `tools/probe_gesture_relay.ahk` 验证配置往返及测试窗口鼠标消息顺序。真实 Explorer 右键拖拽和多人识别率尚未验证，不能把阶段 1/2 视为完成。

## 一页结论

Rim 已有可用的手势骨架：单触发键、八方向链、字母/异形模板、应用层与全局层、修饰键、滚轮、录制、预览、禁用、黑名单、试笔和配置包。它不是“缺少手势识别”。核心差距在以下顺序：

1. **鼠标原生操作兼容**：按下被暂扣，短点或未命中只重发点击；缺少超时取消和完整鼠标轨迹回放。Explorer 右键拖动文件、需要长按的控件，以及误画后恢复原操作，都可能被破坏。这比再加若干默认手势更优先。
2. **识别质量缺少证据与反馈**：方向链是硬量化、精确查表，并先于模板；模板用 32 点归一坐标平均距离。当前测试基本在内置样本及近似形上验证，没有陌生用户、负样本、不同设备、误触率及候选冲突统计。无法负责任地宣称“比 StrokesPlus 准/不准”。
3. **新增/训练闭环不完整**：新增手势可以录制，但无冲突预警、候选及置信度诊断；预览回调有确定的函数名错误；编辑手势名或层时旧绑定仍留存。模板可追加样本，但没有依据误识别结果进行训练的引导。
4. **能力边界**：经典版和 .net 版支持更多鼠标修饰、双触发键、rocker、排除区域和回放策略；.net 还有宏、文本扩展、脚本、步骤动作。Rim 已有 VIMD_CMD 动作体系，优先把手势输入做可靠，再决定是否扩展动作平台。

## 对标资料及可验证范围

| 资料 | 核实到的事实 | 不能据此断言 |
| --- | --- | --- |
| [经典版仓库](https://github.com/minyoad/StrokesPlus/tree/f7788b1766d709199b551dc1718ddbc5a3d93b7a) | C++ 源码、Lua 动作、XML 点样本和帮助文档公开；[识别核心](https://github.com/minyoad/StrokesPlus/blob/f7788b1766d709199b551dc1718ddbc5a3d93b7a/StrokesPlusHook/StrokesPlusHook.cpp#L6602) 可直接审查。 | 经典版在当前 Windows/设备上必然优于 Rim。 |
| [StrokesPlus.net 归档](https://github.com/ozhegov-d/StrokesPlus.net_archive/tree/9e083235cf657eebee3c43e1ae69e004aadae3fb) | 主要是帮助文档和用户脚本，不是新版 C# 识别器源码；[选项说明](https://github.com/ozhegov-d/StrokesPlus.net_archive/blob/9e083235cf657eebee3c43e1ae69e004aadae3fb/StrokesPlus.net/hints/forum/Options.html) 可证实产品能力。 | 新版内部匹配公式、实际耗时或误识别率。 |
| [官网发布页](https://strokesplus.net/?f=Downloads)、[变更记录](https://strokesplus.net/ChangeLog.txt) | 页面提供 0.5.8.0 安装/便携版；变更记录标为 2024-10-20 “Final release”，并记录 No Match 脚本、排除区域、宏等演进。 | 归档仓库最近更新时间代表产品仍在继续发布。 |

### 经典版识别算法与 Rim 的实质区别

经典版采样点按**累计路径长度**插值（默认精度 100），计算连续点的方向角，对相同索引的角度取最小环形差，换算成概率；候选按概率过阈值（默认 75）选最高。[插值与角度序列](https://github.com/minyoad/StrokesPlus/blob/f7788b1766d709199b551dc1718ddbc5a3d93b7a/StrokesPlusHook/StrokesPlusHook.cpp#L5909)、[概率匹配](https://github.com/minyoad/StrokesPlus/blob/f7788b1766d709199b551dc1718ddbc5a3d93b7a/StrokesPlusHook/StrokesPlusHook.cpp#L6602)。[经典版训练说明](https://github.com/minyoad/StrokesPlus/blob/f7788b1766d709199b551dc1718ddbc5a3d93b7a/Help/StrokesPlus.html#L114) 支持在识别错误后将当前笔迹加入目标手势样本。

Rim 先按 10 ms 轮询、点间约 4 px 才追加点，超过 6 px 进入手势；Douglas-Peucker 式简化后分为八方向，得到 `R_D` 等字符串。命中绑定便**不再比较模板**；未命中时将轨迹按弧长采为 32 点，等比缩至 64 网格，比较平均欧氏点距，要求最高分过阈值且领先第二名至少 4 分。内置 16 条经典版实录轨迹另加理想形，V/InvV 为合成形。见 [Gesture.ahk](../Core/Gesture.ahk)、[GestureTemplate.ahk](../Core/GestureTemplate.ahk)、[GestureSPData.ahk](../Core/GestureSPData.ahk)。

两种方法各有取舍：Rim 的方向链对简单折线快且便于记忆；但八方向扇区边界（22.5 度）与硬精确匹配会放大角度微差，复杂字形可能提前落到某个已绑定方向链。模板坐标法保留形状，却对笔顺、方向、非线性变形敏感；当前仅用最近样本，不等于经典版角度概率。**两个项目的 75 分不是同一度量，不能直接对齐或据此比较优劣。**经典版源码似乎把同一手势多个样本的概率取平均，Rim 取最近样本，增加样本的效果也不应想当然地类推。

### 能力矩阵

| 场景 | Rim 现状 | StrokesPlus / .net 公开资料 | 判断 |
| --- | --- | --- | --- |
| 轨迹录制与辨认 | 26 个全局默认绑定（含滚轮），16 个经典版实录模板，另 2 个合成模板；方向链与模板双通道。 | 经典版任意点样本训练；.net 文档有匹配阈值、插值精度、快速匹配开关。 | Rim 基础已齐，准确率尚无同数据集比较。 |
| 新增手势 | 方向链可录制后填入，新建模板可录制并追加样本（默认最多 3）；有预览和即时生效。 | 经典版训练窗口可显示当前猜测，并纠正后追加样本；.net 支持多个 pattern。 | Rim 缺错误驱动训练、冲突提示和结果解释。 |
| 条件/应用 | 全局、按 ini 顺序首个应用层、进程/类/标题/正则/控件匹配、黑名单、按下时修饰键快照；可切断全局回退。 | 经典版多字段匹配和鼠标/键盘修饰；.net 另有每应用排除区域、二级触发键。 | Rim 条件基础好；首层命中后不会继续找其他匹配层。 |
| 组合输入 | 按住触发键滚轮，少量硬编码左键组合和 Z+滚轮缩放。 | 经典版可用鼠标及键盘修饰、滚轮；.net 支持左右键 rocker、双触发键、按下前后修饰状态。 | Rim 组合能力目前偏特例，难由 UI 定义通用组合。 |
| 原生鼠标操作 | 短点重发完整点击；未命中 `passthrough` 也只重发点击；Esc 可取消。 | 两代均提供 Cancel Delay；.net 可在超时/未命中回放按下、移动和释放，提供区域排除。 | **当前最大功能和兼容差距。** |
| 可观测性 | Tooltip 显示方向串/动作；试笔模式只识别不执行；有形状预览。 | 经典版训练显示候选；.net 提供提示文字、No Match 动作等。 | 缺匹配来源、分数、第二候选、事件和失败原因日志。 |
| 动作生态 | 复用 Rim 的 `VIMD_CMD`、插件函数、执行钩子，可运行命令、发键等。 | 经典版 Lua；.net V8、动作步骤、宏、文本扩展、热键和脚本共享能力。 | 这是产品范围差异；勿用动作数量代替手势质量。 |

## Rim 当前链路与确定问题

`Gesture_Down` 截住触发键并记录起点窗口/控件与修饰键；`Gesture_Poll` 累计点并实时算方向；`Gesture_UpCore` 依次处理录制、硬编码组合、方向链、模板、未命中；`Gesture_DoAction` 转 Rim 动作体系。配置在 `Conf/rim.ini`，管理器通过 `GestureIni` 定点写入并重载。相关入口：[Rim.ahk](../Rim.ahk)、[Gesture.ahk](../Core/Gesture.ahk)、[GestureUI.ahk](../Gui/GestureUI.ahk)。

按优先级列出可由代码直接确认的缺陷/风险：

1. **P0 原生拖拽丢失**：`Gesture_Down` 在待识别时不转发鼠标按下；`Gesture_UpCore` 的短点和 `passthrough` 最终仅调用 `Gesture_SendTriggerClick`。移动事件与按住时长均不回放；无超时路径。右键拖拽等依赖完整事件序列的操作无法等价透传。[Gesture.ahk:675](../Core/Gesture.ahk#L675)、[Gesture.ahk:1147](../Core/Gesture.ahk#L1147)、[Gesture.ahk:1317](../Core/Gesture.ahk#L1317)。
2. **P1 新增预览调用不存在的函数**：`GestureDlg_OnPreview()` 调用 `GestureDlg_Current()`；代码只定义 `GestureDlg_CurrentDlg()`，且外层 `try` 不包住该调用。新建/编辑对话框初始化、Edit 的 Change 和录制后都经过这里。[GestureUI.ahk:1049](../Gui/GestureUI.ahk#L1049)、[GestureUI.ahk:1149](../Gui/GestureUI.ahk#L1149)。需在真实 GUI 上验证具体错误呈现；函数缺失本身可静态确定。
3. **P1 编辑改名/换层留旧绑定**：保存先写新 `(layer, gesture)`，只删除旧说明，没有删除旧手势，也没有事务/回滚。用户以为“移动/重命名”，实际变为复制出两个动作。[GestureUI.ahk:1193](../Gui/GestureUI.ahk#L1193)、[GestureIni.ahk:309](../Core/GestureIni.ahk#L309)。
4. **P1 配置包漏用户说明**：管理界面把描述保存在 `[GestureDesc]`；导入/导出允许节名单不含它。跨机导出再导入后说明丢失。[GestureIni.ahk:189](../Core/GestureIni.ahk#L189)、[GestureIni.ahk:344](../Core/GestureIni.ahk#L344)。
5. **P1 `noglobal` 在模板路径失效**：方向链的 `Gesture_ResolveFor` 在匹配应用层未命中后检查 `noglobal`；`Gesture_ResolveTpl` 却继续尝试全局模板覆盖及模板内置动作。因此应用层声称“无全局回退”时，字母模板仍可执行全局/内置动作。[Gesture.ahk:501](../Core/Gesture.ahk#L501)、[Gesture.ahk:589](../Core/Gesture.ahk#L589)。
6. **P2 识别冲突静默**：优先精确方向链，再算模板；录制界面不给出两路候选、第二分数或被遮蔽的模板。新建模版可能保存成功却一直被已绑定方向链抢先执行。[Gesture.ahk:568](../Core/Gesture.ahk#L568)、[GestureTemplate.ahk:387](../Core/GestureTemplate.ahk#L387)。这是机制风险，须用实际笔迹统计影响面。
7. **P2 轨迹显示易受重绘影响**：XOR 直接绘在屏幕 DC，结束时重画擦除；窗口重绘、DPI/多屏和长轨迹值得做真机测试。配置默认 `Trail=0`，所以这不是当前识别主路径阻塞。[GestureTrail.ahk:23](../Core/GestureTrail.ahk#L23)、[rim.ini:204](../Conf/rim.ini#L204)。

已有验证：`tools/probe_gesture_recognition.ahk` 与 `tools/probe_gesture_fix.ahk` 在 AHK v2 下退出码均为 0；它们覆盖抖动折线、V/InvV、内置理想/记录样本、部分应用层。**这些测试无法测出生产误识别率**：被测试笔迹大量来自构造模板的同一记录或理想轨迹，没有训练/测试分离，也没有大量“应当不触发”的负样本。GUI、新增后保存、右键菜单和拖拽同样未由这两项覆盖。

## 实施规划

### 阶段 0：修复配置可信度（建议先做，1 个小迭代）

- 修正预览回调；对“新增、录制、改名、换层、禁用、导出再导入”做真实 GUI 冒烟。改名/换层采用先验证目标、持久化新键、删除旧键及禁用/描述元数据并处理失败回滚的明确事务；若 UI 意图是复制，则改成独立的“复制”命令。
- 让模板解析遵守应用层 `noglobal`，并用同一组应用/全局配置分别测试方向链、模板覆盖和内置模板。
- 配置包纳入 `GestureDesc`，加版本/格式检查及导入预览，验证合并与覆盖不会静默丢项。
- 给录制结果提供“方向链 / 模板”来源与当前会命中的动作；发现已有映射或形状相近时给冲突提示。
- 验收：新建及编辑界面不抛错；改名/换层后旧键不存在；`noglobal=1` 时两条识别路径均不回退全局；导出/导入往返保持绑定、样本、禁用状态和说明。

### 阶段 1：原生输入兼容（最高产品优先级，1-2 个迭代）

- 为一次触发建立清晰状态机：`pending -> capturing -> matched / relay / cancelled`。记录按下、移动、释放及目标窗口；配置 Cancel Delay 与重置规则。超时和未命中应在安全条件下回放完整事件流，或在技术上不可等价时清楚限定支持范围。
- 用 Explorer 右键拖文件、桌面右键菜单、浏览器拖选、长按上下文菜单、滚轮、触摸板以及多屏/高 DPI 做真机回归。捕获期间的左键组合和滚轮应有明确优先级；保证 Esc 和应用切换不会留下“按键仍按住”。
- 完整回放有副作用和重复操作风险，先在试验开关下实现，记录是否回放、丢失事件和目标 HWND；不把 `Click()` 当作拖拽回放。
- 验收：短点菜单与原生行为等价；无绑定轨迹或超时后，指定回归场景的按下/移动/释放能到原窗口；无卡键、重复动作或焦点错投。

### 阶段 2：用数据改善识别与训练（1-2 个迭代）

- 先建可复现语料：至少 5 人、鼠标和触摸板、常用 15-20 形状各 10 次以上，加右键拖动/随手移动等负样本；保存原始点、采样时间、设备、目标标签、应用上下文，不上传隐私窗口标题。训练者与测试者分开。
- 同一语料同时跑当前“双通道”和候选方案：方向链容差/角度序列、模板坐标距离、简单组合评分。统计 Top-1 命中率、拒识率、误触率、P50/P95 识别耗时；按手势和设备看混淆矩阵，尤其 `R/B/P`、`U/V/InvV`、短斜线。保持历史绑定兼容。
- 录制后展示最高/次高候选及分数、实际路由层、方向链遮蔽提示；误识别时可把当前笔迹加入正确模板，提示样本太相似。不要仅靠调一个“75”完成迁移。
- 初步验收目标（需以基线调整）：常用手势 Top-1 >= 95%，非手势负样本误触 <= 0.1%，P95 识别 <= 30 ms；相较现状两项前者不下降、误触显著改善。

### 阶段 3：扩展表达力（质量达标后选择）

- 优先做二级触发键和可配置的组合语法（鼠标按键、滚轮、按下前/后修饰），将硬编码 `L/R+LButton` 与 `Z+Wheel` 迁到统一配置；随后做应用/屏幕区域排除和“当前光标窗口”拾取器。
- “无匹配动作”、手势变量（起终点、轨迹边界、目标窗口）可复用 Rim 动作体系。宏录制、文本扩展和完整脚本 IDE 是更大产品范围，暂不作为手势引擎前置条件。
- 验收：用 UI 新增组合而无需改源码；同形状在两个触发键上可绑定不同动作；排除区域内原生鼠标操作通过；旧配置包仍可导入。

## 建议的下一个开发切片

从阶段 0 的三件事开始：修预览调用、明确编辑是移动还是复制并修正旧键处理、补配置包说明往返测试。之后立即处理原生拖拽/超时策略，同时建设识别语料。不要先重写模板算法：当前没有独立测试集，无法判断“换算法”是否真的提升用户体验。

## 资料链接

- [经典版帮助：训练、动作与应用匹配](https://github.com/minyoad/StrokesPlus/blob/f7788b1766d709199b551dc1718ddbc5a3d93b7a/Help/StrokesPlus.html)
- [经典版 C++：路径插值和角度比较](https://github.com/minyoad/StrokesPlus/blob/f7788b1766d709199b551dc1718ddbc5a3d93b7a/StrokesPlusHook/StrokesPlusHook.cpp#L5909)
- [新版归档：选项（双触发键、超时、回放、排除区域）](https://github.com/ozhegov-d/StrokesPlus.net_archive/blob/9e083235cf657eebee3c43e1ae69e004aadae3fb/StrokesPlus.net/hints/forum/Options.html)
- [新版归档：项目说明与脚本能力](https://github.com/ozhegov-d/StrokesPlus.net_archive/blob/9e083235cf657eebee3c43e1ae69e004aadae3fb/README.md)
- [官网发布页](https://strokesplus.net/?f=Downloads)、[官网变更记录](https://strokesplus.net/ChangeLog.txt)
