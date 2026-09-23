# 手势统一命名空间与源码对照

## 已克隆的参考实现

| 项目 | 本地目录 | 固定版本 | 结论 |
| --- | --- | --- | --- |
| StrokesPlus classic | `C:\Users\Administrator\AppData\Local\Temp\rim-clones-git\clone2\StrokesPlus` | `f7788b1` | C++ 识别器开源，动作和样本分离 |
| Stroke | `C:\Users\Administrator\AppData\Local\Temp\rim-clones-git\clone2\Stroke` | `cc72a7a` | C# 向量识别，只有一个 `Gesture.Name` |
| OpenMouseGesture | `C:\Users\Administrator\AppData\Local\Temp\rim-clones-git\clone2\OpenMouseGesture` | `9fab0bc` | JSON 中模板和动作都引用同一个 gesture 名称 |
| StrokesPlus.net archive | `C:\Users\Administrator\AppData\Local\Temp\rim-clones-git\clone2\StrokesPlus.net_archive` | `9e08323` | 只有归档文档、脚本和变更记录，识别器没有源代码 |

克隆使用了 Git Bash、HTTP/1.1、Schannel 和本机代理。`StrokesPlus.net` 的实现只能依据归档文档判断，不能把它当作可审计的源码实现。

## 参考实现怎么组织

经典 StrokesPlus 在 `StrokesPlusHook.cpp` 中先把轨迹重采样成角度序列，再对每个手势的多个 `PointPattern` 计算概率。得到 `DrawnGestureName` 后，程序才到全局或应用层查找 `GestureName` 对应的动作。应用层只改变动作，不复制或改变模板。

Stroke 和 OpenMouseGesture 也只有一个手势名称。方向向量、点列、平滑和阈值属于识别器；全局、应用包和脚本属于动作层。用户不需要知道“字母模板”和“方向链”是两个配置键空间。

## Rim 当前改动

`Core/Gesture.ahk` 增加了统一绑定查找：

- 裸名称优先作为统一手势名，例如 `V=key|{F5}`；
- `DIR:` 和 `TPL:` 保留为旧配置的显式消歧前缀；
- 修饰键、应用层、全局层和 `noglobal` 对两种识别方式使用同一套查找；
- 当 V 形同时量化为 `DR_UR` 且模板 V 达到阈值时，只要 V 有应用或全局绑定，就优先模板 V；
- 当没有模板绑定时，方向链行为保持原样；
- 旧配置中的 `TPL:U` 与方向 `U` 同时存在时，显式 `TPL:` 仍优先，避免兼容性回归。

推荐的新配置写法：

```ini
[Gestures]
V=key|{F5}
DR_UR=key|{F5}

[GestureApp:Browser]
set_file=chrome.exe|firefox.exe
V=key|^r
noglobal=0
```

迁移期间可以继续使用：

```ini
TPL:V=key|{F5}
DIR:DR_UR=key|{F5}
```

## 验证结果

以下探针在 AutoHotkey v2 下通过：

- `tools/probe_gesture_fix.ahk`：原有命名空间、应用覆盖、`noglobal`、模板识别，以及新增的裸 `V` 全局/应用绑定；
- `tools/probe_gesture_recognition.ahk`：方向链、V/InvV、抖动和多样本模板；
- `tools/probe_gesture_store.ahk`：配置保存、迁移、禁用和导入导出；
- `tools/probe_gesture_relay.ahk`：未命中轨迹回放路径。

## 仍需继续做的工作

当前是兼容式统一，识别器仍保留方向链和模板两个候选来源。下一轮应把结果包装成候选列表，记录名称、识别方式、分数、样本序号和被拒绝的第二候选，再用真实轨迹评估 V、B、P、R 等混淆。没有这组数据前，不应只靠调阈值宣称识别率提升。

