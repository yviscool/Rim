# AutoHotkey v1 → v2 迁移指南 (坑点汇总)

基于实战迁移 VimDesktop + RunZ → VimRunZ 积累的经验。

## 一、语法变化（必知）

### 1. 字符串
- **双引号字符串中嵌入引号**：用 `""` 表示字面引号，或用单引号 `'...'` 包裹含 `"` 的字符串
- **单引号字符串中不能用 `\'` 转义**：用 `'''`（三个单引号）或字符串拼接 `"'" . var`
- **反引号 `` ` `` 是转义符**：发送字面反引号用 `{Backtick}`，不是 `` ` ``
- **自动串联必须有空格/Tab**：`"a" "b"` 合法，`"a""b"` 非法

### 2. 变量与赋值
- **删除旧式赋值**：`var = value` → `var := "value"`
- **函数和变量共享命名空间**：不能有同名的函数和变量
- **`super`、`Map` 是保留关键字**：不能作变量/函数名
- **`@`、`#`、`$` 不能出现在函数名中**
- **双重引用 `%var%()` 现在是动态调用**：等同于 `f := %var%, f()`

### 3. 表达式
- **`&&`/`||` 返回值类型变化**：`"" or "default"` 返回 `"default"` 而非 `1`
- **`!=` 总是不区分大小写**：区分大小写用 `!==`
- **`<>` 已删除**
- **`&var` 不再是取地址**：改为引用运算符（VarRef），取地址用 `StrPtr(var)`/`ObjPtr(obj)`
- **逗号后的等号不再是赋值**：`x:=y, y=z` 中 `y=z` 是比较

### 4. 控制流
- **删除 `GoSub`**：全部改为函数调用
- **`Goto`/`Break`/`Continue` 需要无引号的标签名**
- **标签不能与函数同名**
- **`return` 最多接受 1 个参数**：多值返回需用数组或对象

## 二、函数变化

### 1. 函数调用语法
- **命令全部变为函数**：`MsgBox text` → `MsgBox(text)`
- **省略括号时返回值被丢弃**
- **参数都是表达式**：文本必须加引号，逗号不需要转义
- **函数名和参数之间不能有逗号**：`WinMove(, y)` = 省略 x

### 2. 输出变量 → 返回值
- **旧命令的输出变量变为返回值**：`FileGetTime(&var, file)` → `var := FileGetTime(file)`
- **`SysGet` 直接返回值**：`SysGet(&var, 79)` → `var := SysGet(79)`
- **`FileGetTime` 不再用 `&` 输出**：`FileGetTime(file)` 直接返回时间字符串

### 3. 动态调用
- **`Func("name")` 可能失败**：对 `#Include` 的函数，直接传函数名 `FuncName` 而非 `Func("FuncName")`
- **字符串调用函数**：`cmd()` 不行，用 `%cmd%()`（双解引用）
- **`IsFunc("name")` 对不存在的函数返回 0**，不会报错

### 4. ByRef
- **声明改为 `&param`**：不再是 `ByRef param`
- **调用者必须用 `&var` 显式传引用**

### 5. 可变参数
- **最后一个参数加 `*`**：`Foo(args*)`
- **回调函数必须接受 `(*)` 参数**：Menu/Hotkey/GUI/Timer 回调

## 三、内置函数/命令变化

### 1. 重命名
| v1 | v2 | 说明 |
|---|---|---|
| `Asc()` | `Ord()` | 获取字符编码 |
| `A_LoopFileLongPath` | `A_LoopFileFullPath` | 循环中的长路径 |
| `Clipboard` | `A_Clipboard` | 剪贴板 |
| `ComSpec` | `A_ComSpec` | 命令行路径 |
| `IsLabel()` | `IsFunc()` | 检查标签/函数是否存在 |
| `ObjRawGet`/`ObjRawSet` | 不存在 | 用 `DefineProp`/`GetOwnPropDesc` |
| `NumGet`/`NumPut` | 语法变化 | 见下方 |

### 2. 语法变化
| v1 | v2 | 说明 |
|---|---|---|
| `NumPut(type, var, offset)` | `NumPut(type, value, var, offset)` | Type 为第一参数 |
| `ControlSetText ctrl,,win` | `ControlSetText(text, ctrl, win)` | 参数顺序：Text, Control, WinTitle |
| `WinMove title,x,y,w,h` | `WinMove(x,y,w,h,title)` | 标题移到最后一个参数 |
| `Gui.Show(,title)` | `Gui.Show(options)` | 标题在 `Gui()` 创建时设置 |
| `FileAppend text,file` | `FileAppend(text, file)` | 空文本需传 `""` |
| `Input` | `InputHook` | 输入命令改为函数 |
| `SetTimer label` | `SetTimer(FuncName)` | 传函数引用，非字符串 |
| `Hotkey "key", "label"` | `Hotkey("key", FuncName)` | 传函数引用 |
| `Menu.Add "text", "label"` | `Menu.Add("text", FuncName)` | 传函数引用 |

### 3. 删除的功能
- `Eval()` 不存在 → 用自定义计算函数
- `#MaxHotkeysPerInterval` 不识别 → 删除
- `Gui.Focused` 不存在 → 用其他方式获取焦点控件
- `*`（deref 运算符）删除 → 用 `NumGet`

## 四、对象/数据结构变化

### 1. Map
- **不支持点语法**：`map.key` → `map["key"]`
- **不存在的键会报错**：用 `map.Has(key)` 检查，或 `map.Get(key, default)`
- **字符串键区分大小写**
- **`for k, v in map` 遍历键值对**

### 2. Array
- **索引从 1 开始**：`arr[0]` 无效
- **越界访问会报错**：必须检查 `index >= 1 && index <= arr.Length`
- **负索引**：`arr[-1]` 返回最后一个元素

### 3. SubStr
- **`SubStr(str, 0)` 返回空字符串**（v1 返回最后一个字符）
- **取最后一个字符用 `SubStr(str, -1)`**
- **`SubStr(str, 2, -2)` 在 v2 中删除最后 2 个字符**（v1 删除 1 个）
- **正确写法**：`SubStr(str, 2, StrLen(str) - 2)` 删除最后一个字符

### 4. 对象语法
- **删除 `new` 关键字**：`new MyClass()` → `MyClass()`
- **`base.Method()` → `super.Method()`**
- **属性和方法分开**：`obj.prop` 是属性，`obj.method()` 是方法
- **不存在的属性访问会报错**

## 五、GUI 变化

### 1. 创建语法
- **删除字符串语法**：`Gui, Add, Edit, ...` → `guiObj := Gui(options, title)`
- **`guiObj.Add("Edit", options)`**
- **`guiObj.Show(options)`** — 标题在 `Gui()` 创建时设置
- **删除 `-Caption` 的替代方案**：仍用 `"-Caption"` 选项

### 2. 事件
- **删除 `g` 前缀回调**：`g_InputEdit := guiObj.Add("Edit", "gMyFunc")` → `guiObj.OnEvent("Change", MyFunc)`
- **GUI 控件事件**：用 `.OnEvent("EventName", FuncName)`
- **`Gui` 不支持 `HasProperty` 和 `CtrlDown` 事件**
- **`Edit` 控件不支持 `Click`/`MouseMove`/`LButtonUp`**：用 `OnMessage` 处理

### 3. 控件
- **`ControlSetText` 参数顺序**：`ControlSetText(Text, Control, WinTitle)` — **Text 是第一个参数！**
- **`ControlGetText` 同理**
- **`ControlFocus` 需要窗口存在**

## 六、热键变化

### 1. 注册语法
- **删除标签语法**：`^a::MyLabel` → `^a::MyFunc`
- **`HotIfWinActive` 必须在注册热键之前调用**
- **函数名直接传递**：`Hotkey("key", FuncName)` — 不用 `Func("FuncName")`

### 2. 回调函数
- **必须接受 `(*)` 参数**：`MyFunc(*) { ... }`
- **`A_ThisHotkey` 包含修饰符**：`!a` 的 `A_ThisHotkey` 是 `"!a"`
- **取最后字符用 `SubStr(A_ThisHotkey, -1)`**，不是 `SubStr(A_ThisHotkey, 0, 1)`

### 3. 窗口匹配
- **`HotIfWinActive(title)` 必须精确匹配窗口标题**
- **窗口创建后热键才生效**

## 七、文件/路径

### 1. 编码
- **`FileEncoding "UTF-8"` 放在脚本开头**
- **`Loop Read` 正确处理 LF/CRLF**

### 2. 路径
- **`#Include` 默认相对路径**：`#Include Lib\EasyIni.ahk`
- **不能用 `A_ScriptDir` 拼接 `#Include` 路径**
- **`Loop Files` 用 `A_LoopFileFullPath`**（不是 `A_LoopFileLongPath`）

### 3. 文件操作
- **`FileGetTime(file)` 直接返回值**，不用 `&` 输出变量
- **`FileAppend` 需要 2 个参数**：`FileAppend(text, file)`
- **`FileExist` 检查文件是否存在**

## 八、错误处理

### 1. try/catch
- **`catch as e` 无效**：用 `catch {` 或 `catch Error as e {`
- **`catch e`（无 `Error`）也无效**
- **`try` 包裹可能失败的调用**

### 2. Map 访问
- **访问不存在的键抛异常**：用 `map.Has(key)` 检查
- **或用 `map.Get(key, default)` 提供默认值**
- **批量设置默认值**：
```ahk
defaults := Map("key1", "val1", "key2", "val2")
for k, v in defaults
    if !map.Has(k)
        map[k] := v
```

### 3. 数组访问
- **越界访问抛异常**：必须检查索引范围
- **`arr.Length` 获取数组长度**

## 九、#Warn 和调试

### 1. `#Warn All, Off`
- 放在每个 `.ahk` 文件开头可抑制误报警告
- **但不抑制运行时错误**
- 某些内置函数在 `#Warn` 下可能产生意外警告

### 2. 调试技巧
- **`FileAppend` 写调试输出到文件**
- **`Type(value)` 检查值类型**
- **`StrLen(string)` 获取字符串长度**
- **`A_IsCompiled` 检查是否编译**

## 十、常见错误模式

### 错误 1：`SubStr(str, 0)` 返回空
```ahk
; ❌ v1 写法
lastChar := SubStr(str, 0)
; ✅ v2 写法
lastChar := SubStr(str, -1)
```

### 错误 2：`ControlSetText` 参数顺序反了
```ahk
; ❌ 错误（Control 在前）
ControlSetText(g_DisplayArea, text, g_WindowName)
; ✅ 正确（Text 在前）
ControlSetText(text, g_DisplayArea, g_WindowName)
```

### 错误 3：`FileGetTime` 用 `&` 输出
```ahk
; ❌ v1 写法
FileGetTime(&time, file)
; ✅ v2 写法
time := FileGetTime(file)
```

### 错误 4：Map 用点语法访问
```ahk
; ❌ 错误
val := map.key
; ✅ 正确
val := map["key"]
```

### 错误 5：访问 Map 不存在的键
```ahk
; ❌ 抛异常
val := map["nonexistent"]
; ✅ 先检查
if map.Has("nonexistent")
    val := map["nonexistent"]
; ✅ 或用默认值
val := map.Get("nonexistent", "")
```

### 错误 6：数组索引 0
```ahk
; ❌ 数组从 1 开始
val := arr[0]
; ✅ 从 1 开始
val := arr[1]
```

### 错误 7：字符串调用函数
```ahk
; ❌ v2 不支持
cmd()
; ✅ 用双解引用
%cmd%()
```

### 错误 8：`GoSub` 已删除
```ahk
; ❌ 删除
GoSub MyLabel
; ✅ 直接调用函数
MyFunc()
```

### 错误 9：`SetTimer`/`Hotkey` 传字符串
```ahk
; ❌ v1 写法
SetTimer, MyLabel, 1000
Hotkey, ^a, MyLabel
; ✅ v2 写法
SetTimer(MyFunc, 1000)
Hotkey("^a", MyFunc)
```

### 错误 10：`catch` 语法
```ahk
; ❌ 无效
catch as e
catch e
; ✅ 正确
catch {
catch Error as e {
```

### 错误 11：`NumPut` 参数顺序
```ahk
; ❌ v1
NumPut(text, LE)
; ✅ v2（Type 为第一参数）
NumPut("UShort", text, LE, 0)
```

### 错误 12：`WinMove` 参数顺序
```ahk
; ❌ v1（标题在前）
WinMove title, x, y, w, h
; ✅ v2（标题在后）
WinMove(x, y, w, h, title)
```

### 错误 13：`A_LoopFileLongPath` 不存在
```ahk
; ❌ v1
A_LoopFileLongPath
; ✅ v2
A_LoopFileFullPath
```

### 错误 14：`IsFunc` 检查不存在的函数
```ahk
; ⚠️ v2 中 IsFunc("NonExist") 返回 0，不会报错
; 但某些情况下可能触发变量未赋值警告
; 建议用 try 包裹
try {
    if IsFunc("MyFunc")
        MyFunc()
}
```

### 错误 15：回调函数参数不匹配
```ahk
; ❌ Menu/Hotkey/GUI/Timer 回调必须接受参数
MyFunc() { ... }
; ✅ 用 (*) 接受任意参数
MyFunc(*) { ... }
MyFunc(params*) { ... }
```

### 错误 16：无 BOM 的 UTF-8 文件用 `Loop read` 会吞换行
```ahk
; ❌ 实测: 行尾是 CJK 的无 BOM 文件, 381 行只读出 349 行
; 注释行与下一键行被粘成一行当注释丢弃, 配置键无声蒸发,
; 且残缺 Map 读缺失键可能 hang 住 (AddCommand/LoadFiles 全卡死)
Loop read, filePath {
    line := A_LoopReadLine
}
; ✅ 显式 UTF-8 + 去 BOM + Loop Parse
content := FileRead(filePath, "UTF-8")
if (SubStr(content, 1, 1) = Chr(0xFEFF))
    content := SubStr(content, 2)
Loop Parse, content, "`n", "`r" {
    line := Trim(A_LoopField)
}
; 见 Core/Common.ahk: ReadTextFile()/ReadFileLines(), Lib/EasyIni.ahk: Load()
```

### 错误 17：字面量与函数调用不能隐式串联
```ahk
; ❌ "LEAK:" Func() / Chr(x) Chr(y) —— 加载错或静默异常
out .= "LEAK:" TryEvalInput(x)
; ✅ 用 . 或中间变量
out .= "LEAK:" . TryEvalInput(x)
tmp := TryEvalInput(x)
out .= "LEAK:" . tmp
```

### 错误 18：`#Include` 文件的顶层 `global X := ...` 会清空早前已赋值

```ahk
; ❌ 实测翻车 (i18n 托盘显示 raw key)：主入口 15 行调 I18nBoot() 填好语言表，
;   163 行 #Include Core\I18n.ahk 的顶层 global g_I18nStrings := Map() 又把它清空
; ✅ 只在未赋值时初始化
global g_I18nLang, g_I18nStrings
if !IsSet(g_I18nLang)
    g_I18nLang := "zh-CN"
if !IsSet(g_I18nStrings)
    g_I18nStrings := Map()
```
; 原理：`#Include` 文件的顶层语句按 auto-execute 顺序在 include 行位置执行，
; 不是“先于一切”——凡是在 include 行之前就运行的代码（如启动早期的 Boot），
; 其写入的全局量都会被后执行的顶层 `:=` 覆盖。见 Core/I18n.ahk 顶层守卫。

### 错误 19：库文件用 `A_ScriptDir` 定位资源，换目录运行就失联

```ahk
; ❌ 实测翻车 (tools/ 下跑冒烟探针, Lang/ 读不到, 静默空表全员 raw key)：
path := A_ScriptDir . "\Lang\" . lang . ".ini"
; ✅ 相对模块自身定位 (A_LineFile 在函数体内即本文件)：
I18nRoot() {
    SplitPath(A_LineFile, , &dir)
    return dir . "\.."
}
```
; 探针/测试脚本常放在子目录，`A_ScriptDir` 只对主入口可靠；
; 库自带资源一律相对模块路径解析，并给探针加“语言表为空直接失败”的金丝雀。

### 错误 20：函数内局部变量名与内置类同名（大小写不敏感），构造调用被遮蔽

```ahk
; ❌ 实测翻车 (TC 下 i/m/d/n/c-q 全灭, 日志 VIMKEY-ERR "local variable ... global declaration ...",
;   extra=menu)：函数作用域内局部量 menu 建好后, 同名 Menu() 解析到未赋值的局部量, 不再是全局类
MyFunc() {
    menu := Menu()
}
; ✅ 改名避让 (mm/regMenu/setMarkMenu 等非全等名不受影响; Gui/Map/Array/Buffer 同理)
MyFunc() {
    mm := Menu()
}
```
; AHK 大小写不敏感：`menu` 与类 `Menu` 视为同名。全局作用域 `m1 := Menu()` 没事，
; 一进函数就翻车。同坑：`map := Map()`（Lib/JSON.ahk 已改 `m`）、`gui := Gui()`。
; 排查特征：错误行就是构造行，extra= 变量名。见 Plugins/TotalCommander.ahk 6 处批量改名。
;
; 同族连环坑：循环变量 `t` 会遮蔽全局函数 `T()`（i18n 取词函数）——凡调 `T()` 的函数，
; 循环量一律用 `tp`/`tmpl`/`r` 等（实测：`for t in tpls` + `T("...")` 同函数即炸，extra=t）。
; 另：`TryEvalInput` 等含 `T` 开头的倒没事，只有全等名（无视大小写）才遮蔽。

### 错误 21：v2 `Menu()` 弹的是 `Xaml_WindowedPopupClass`，不是 `#32768`

```ahk
; ❌ 实测翻车 (TC 下 i 菜单 F/S/上下/回车/Esc 全死)：
;   BeforeActionDo 里只认 WinExist("ahk_class #32768") 做"菜单开着就透传"，
;   v2 自家菜单是 XAML 岛窗口，检查永远为假，钩子把按键全吞了，菜单变死菜单
if WinExist("ahk_class #32768") && g_TCLastCmd != 572
    return true
; ✅ 两个类都认 (WinExist 返回 HWND 数字，注意 || 与 && 的优先级，加括号)：
menuOpen := WinExist("ahk_class #32768") || WinExist("ahk_class Xaml_WindowedPopupClass")
if (menuOpen && g_TCLastCmd != 572)
    return true
```
; 取证法：`Menu.Show()` 后枚举 `WinGetList()` 找新增窗口类（注意 `WinGetTitle()` 可能在个别窗口上 hang，
; 探针只取类名；另 `Menu.Show()` 是非阻塞的，配合 `SetTimer(-ms)` 快照）。
; 附带：顶层 `LOG := "..."` 这类全大写命名也可能撞内置 `Log()`（探针报 "This Func cannot be used
; as output variable"），临时探针变量用小写路径名。
;
; 同错下半场：`BeforeActionDo` 的菜单透传只覆盖"动作键"，`F/S` 这类多键前缀在 KeyHandler 里
; 先被 `KeyTemp` 吞掉，根本走不到 BeforeActionDo —— 菜单开着时 F/S 照样死。
; 修法：在 KeyHandler 取到 win/mode 后、全局回退之前，对 TTOTAL_CMD 提前判一次菜单透传
; （见 Core/Engine.ahk "菜单开着： 全键提前透传"）。
;
; 下半场翻盘：v2 XAML 弹出菜单不抢键盘焦点，按键落在原窗，透传 Send 也进错窗——
; 需要键盘交互的菜单一律用可聚焦 Gui+ListBox 自造（见 TC_PopupMenu：原生字母跳转/上下，
; 屏外 1px Default 按钮接回车，Escape 事件接 Esc，双击确认，失焦定时自关，+Owner 回 TC），
; 不要再跟钩子斗法。
;
; Gui 菜单三件套（都是血泪）：① 打开瞬间可能还没抢到前台，此时按键走 TC 钩子——
; KeyHandler 对 TTOTAL_CMD 要先判自家 "TCMenu ahk_class AutoHotkeyGUI" 存在但未激活，
; 则先 WinActivate 再透传（偶发 fc/fa 提示框即此竞态）；② Gui 抢过激活，关闭必须把焦点
; 送回打开前记录的 TC 控件（`g_TCMenuFocusHwnd`，用户切走则不动），否则下次定位全走回退；
; ③ `Gui.Show(x,y)` 坐标即屏幕坐标（探针量过 asked=实际），`GetWindowRect` 直给即可。
;
; 附带两则：① 图标列表用 ListView + ImageList（`IL_Create/IL_Add` 正常，
; 但**全局 `LV_*` 函数在 headless 探针环境会 hang**，一律用控件方法
; `lv.ModifyCol/GetCount/GetNext/Modify/Delete`，imagelist 挂载用原生
; `SendMessage(LVM_SETIMAGELIST=0x1003)`；真机桌面上全局版一般正常，但方法版双环境都通）；
; ② ListBox/ListView 的字母跳转/上下是原生行为，探针里 `Send` 过去可能因会话无前台而丢失，
; 测交互逻辑用程序设值 + 直调 `TC_MenuConfirm/TC_MenuBackOrClose`，别跟输入路由较劲
; （`ControlSend` 同理可能 hang）。

### 错误 22：`Send("f")` 触发不了 `$f` 热键 —— 菜单竞态兜底不能经 Send

```ahk
; ❌ 实测翻车 (TC 下 i,f 快速连按必须停顿, 快了就出 fa/ff 提示框)：
;   KeyHandler 里菜单开但未激活时 WinActivate + Sleep(50) + Send("f")，
;   $ 前缀的本意就是"Send 不触发"，于是 TC_MenuLetterJump 永远收不到，
;   f 反而落进 TC 变成 fa/ff 的 KeyTemp 前缀
; ✅ 菜单开着时 KeyHandler 直接调 TC_MenuRouteKey(vimKey)（直调字母跳转/回车/Esc/上下，
;   注意大写字母归一后形如 <S-F> 要拆包），与焦点无关，免回车才跟手。
;   只有路由不消费的键才 WinActivate + Send。见 Core/Engine.ahk + TC_MenuRouteKey。
```

### 错误 23：Gui 子菜单/二级对话框别跟一级挤在列表左上 —— 贴到父菜单右侧

```ahk
; ❌ TC_MenuSetItems 同窗 drill-in 不搬家 + TC_NewFileDialog 无坐标 Show，
;   二级永远跟一级挤在 TC_MenuPos (焦点控件左上)，跟原版原生子菜单向右展开脱节
; ✅ 关弹/进二级前记矩形 g_TCMenuLastX/Y/W/H，进 sub 即 TC_MenuCascadeRight()
;   (父宽 +4 右移，屏边钳制)，新建文件对话框 Show("x" lastX+lastW+8 " y" lastY)，
;   右边不够才翻到左侧。另 TC_PopupMenu 里 `try lb.Focus()` 的 lb 根本不存在，
;   ListView 从没拿到过焦点 —— 已改 lv.Focus()。
```

### 错误 24：v2 plain Object 不支持数字索引 —— 跨进程结构体一律用 Map 装

```ahk
; ❌ 实测翻车 (StatsBall 内存全 0, SystemState 同病)：Core/Common.ahk 的
;   GlobalMemoryStatusEx() 返回 {2: total, 3: avail} plain Object，
;   st[2]/st["2"] 全抛 "has no property named __Item__"，且不可枚举
; ✅ 改返回 Map(2, total, 3, avail, ...)；凡数字键容器一律 Map，不要 Object 字面量
```

### 错误 25：Win32 结构体偏移禁止手算 —— 上机标定 (Python+ctypes 对 MSVC 对齐)

```ahk
; ❌ 实测翻车三连 (StatsBall 网速 7GB/s 野值 / Top进程全空 / ping 零涨幅)：
;   MIB_IF_ROW2 手算 rowSize=848/tableOff=4/inOff=1040/outOff=1056 全错；
;   真值 (GetIfTable2, 37 口机标定)：tableOff=8 (NumEntries 后 4 字节对齐填充),
;   rowSize=1352, Type@1128, OperStatus@1156 (1=up), InOctets@1208, OutOctets@1280
;   (旧值 @1312 系 OutDiscards/Errors 恒零区 —— 上行永远 0 的根因, 2026-09 本机
;   31 口双向激励复测锤实: @1280/+14064 与包计数 @1288/+108 同步涨, @1312 纹丝不动；
;   @1256/@1320 为单播镜像, 靠 (rx,tx) 去重消除)。PROCESSENTRY32W: cb=568
;   (pcPriClassBase 占 8 字节!), pid@8, exe@40+4=44, cb 不对即 A_LastError=24。
;   PROCESS_MEMORY_COUNTERS x64 下 72 字节 (不是 48)，cb 写小则 GetProcessMemoryInfo
;   全员失败，workingset 全 0。
; ✅ 新结构体先写 calib_*.py (ctypes.Structure 照抄 SDK 字段顺序, 让编译器算偏移)，
;   再用“回环 ping 定量流量看哪个 u64 涨”定位计数器；网卡求和要按 (rx,tx) 去重
;   (QoS/WFP/虚拟交换机镜像同一物理计数器, 否则网速 ×N)，回环 Type=24 排除，
;   速率>10Gbps 视为异常重建基线。见 Plugins/StatsBall.ahk StatsBall_NetRate。
```

### 错误 26：Git Bash 会吞掉 AHK 的 `/` 开关 —— `/ErrorStdOut` 变脚本路径

```ahk
; ❌ 实测翻车 (探针超时 120s, 用户截图 "Script file not found C:/Program Files/Git/ErrorStdOut")：
;   MSYS 把 /ErrorStdOut 当路径重写，AHK 弹错框 forever 等待
; ✅ 调 AHK 一律加 MSYS_NO_PATHCONV=1 前缀：
;   MSYS_NO_PATHCONV=1 "/c/Program Files/AutoHotkey/v2/AutoHotkey64.exe" /ErrorStdOut foo.ahk
; ✅ 另：探针桩函数别写单行 `Foo() {}` (报 Unexpected "{")，必须展开多行。
```

### 错误 27：GDI+ 结构体尺寸手算必翻 + layered 窗回落要 unhide 控件

```ahk
; ❌ 实测翻车 (同一脚本三连 1/0/1, 薛定谔 false)：GdiplusStartupInput x64 下 24 字节
;   (version+对齐填充+回调指针+2×BOOL)，给了 16 字节堆越界读，成功率看脸
; ✅ 新结构体一律先过 Python+ctypes 标定 sizeof (见错误 25)，Buffer 按真尺寸开
; ❌ 连环坑：fancy 自绘成功后藏了原生 Text 控件，某帧渲染失败回落扁平时球直接隐身
;   (layered 空窗 + 控件 Hide = 全透明)
; ✅ fancy true→false 时必须 lblMain/lblSub.Visible := true；回落路径探针常驻断言
;   (probe_ui.ahk: fancy=1)。另：WinSetRegion 必须在首次可见 Show 之后调，
;   对 Hide 窗报 "Target window not found" (GetWindowRgn 回 0 即没裁上，3 才对)；
;   UpdateLayeredWindow 后边缘真抗锯齿，region 仅作点击裁剪保留。
```

### 错误 28：悬浮窗拖拽跟随写在秒级 Tick 里 + 窗外松手收不到 LUp —— 球被甩丢 + 状态卡死

```ahk
; ❌ 实测翻车 (拖快了松手球不见, 其实是停在 1 秒前的路径上；窗外松手 0x202 到不了自家窗口，
;   downTick/dragging 卡死)：PollDrag 跟随放在 1s Tick 里，拖拽延迟整整一帧 tick
; ✅ 按住移动走 OnMessage(0x200) 即时跟随，首超 6px 即 SetCapture(ballHwnd)，
;   capture 下窗外移动/松手都路由到本窗，OnLUp 先 ReleaseCapture 再结算；
;   PollDrag 只留作 LUp 丢失时的兜底 (键已松且 dragging → SnapAndSave 提交, 否则清 downTick)；
;   Hide/Destroy/RecreateWidget 统一 ReleaseCapture + 清拖拽态。见 Plugins/StatsBall.ahk。
```

### 错误 29：线程级 OnMessage 里无条件 ReleaseCapture —— 全进程按钮静默死亡，唯独列表正常

```ahk
; ❌ 实测翻车 (配置中心保存/编辑器/勾选全死、左列表正常、零日志零报错)：
;   StatsBall.OnLUp 是 OnMessage(0x202) 线程级监听, 每次左键松开都进, 与焦点/窗口无关;
;   开头无条件 ReleaseCapture() → 抢掉正在按下的别家按钮的隐式 capture →
;   WM_CAPTURECHANGED 取消按压 → BN_CLICKED 永不产生。列表是按下(0x201)即选中，
;   所以唯独列表活着；键盘空格/BM_CLICK 不走 capture，照样能点；
;   手动隐藏球清不掉监听 (RemoveMsg 是空桩), 只有重启+不自启能好 —— 极易误判成"悬浮窗遮挡"
; ✅ 松开只释放自己持有的 capture: if (this.dragging) ReleaseCapture；
;   诊断法：OnMessage(0x201/0x202) 记 hwnd, WM_COMMAND(0x111) 看 BN_CLICKED 出没出，
;   按下松开同句柄却无 BN_CLICKED 即此坑。见 Plugins/StatsBall.ahk OnLUp。
```

### 错误 30：临时变量撞内建函数名（大小写不敏感）—— `ln` 撞 `Ln()` 对数函数

```ahk
; ❌ 实测翻车 (probe_gesture_unified 新增语料段, 加载错 "This Func cannot be used as output variable",
;   extra 指向赋值行)：Loop Parse 里写 ln := Trim(A_LoopField)，ln 与内建 Ln() 同名，
;   解析器把 ln 当函数，赋值即炸。同族：LOG(撞 Log())、t(撞 T())、menu(撞 Menu()) 见错误 20
; ✅ 循环/临时变量一律用完整小写名 (negLine/codeLine/value)，绝不用两三字母缩写
```
