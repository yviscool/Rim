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
