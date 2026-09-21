#Requires AutoHotkey v2.0

; === General Plugin - 通用Vim键位 ===
; 为所有窗口提供基础Vim操作

RegisterPlugin_General() {
    ; 注册窗口
    RegisterWin("General", "", "")

    ; 注册动作
    RegisterAction("<Gen_Toggle>", "切换通用模式")
    RegisterAction("<Gen_InsertMode>", "进入插入模式")
    RegisterAction("<Gen_NormalMode>", "返回正常模式")
    RegisterAction("<down>", "向下移动")
    RegisterAction("<up>", "向上移动")
    RegisterAction("<left>", "向左移动")
    RegisterAction("<right>", "向右移动")
    RegisterAction("<enter>", "回车")
    RegisterAction("<bs>", "退格")
    RegisterAction("<tab>", "制表")
    RegisterAction("<space>", "空格")
    RegisterAction("<home>", "行首")
    RegisterAction("<end>", "行尾")
    RegisterAction("<pgup>", "上一页")
    RegisterAction("<pgdn>", "下一页")
    RegisterAction("<del>", "删除")
    RegisterAction("<c-a>", "全选")
    RegisterAction("<c-c>", "复制")
    RegisterAction("<c-v>", "粘贴")
    RegisterAction("<c-x>", "剪切")
    RegisterAction("<c-z>", "撤销")
    RegisterAction("<c-y>", "重做")
    RegisterAction("<c-s>", "保存")
    RegisterAction("<c-f>", "查找")
    RegisterAction("<c-h>", "替换")
    RegisterAction("<c-w>", "关闭窗口")

    ; 窗口管理动作
    RegisterAction("<wm_left>", "移动窗口到左侧")
    RegisterAction("<wm_right>", "移动窗口到右侧")
    RegisterAction("<wm_up>", "移动窗口到上方")
    RegisterAction("<wm_down>", "移动窗口到下方")
    RegisterAction("<wm_max>", "最大化窗口")
    RegisterAction("<wm_min>", "最小化窗口")
    RegisterAction("<wm_restore>", "还原窗口")
    RegisterAction("<wm_center>", "居中窗口")
    RegisterAction("<wm_full>", "全屏窗口")

    ; 标签页管理
    RegisterAction("<Gen_NewTab>", "新建标签页")
    RegisterAction("<Gen_CloseTab>", "关闭标签页")
    RegisterAction("<Gen_NextTab>", "下一个标签页")
    RegisterAction("<Gen_PrevTab>", "上一个标签页")
    RegisterAction("<Gen_Tab1>", "切换到标签页1")
    RegisterAction("<Gen_Tab2>", "切换到标签页2")
    RegisterAction("<Gen_Tab3>", "切换到标签页3")
    RegisterAction("<Gen_Tab4>", "切换到标签页4")
    RegisterAction("<Gen_Tab5>", "切换到标签页5")
    RegisterAction("<Gen_Tab6>", "切换到标签页6")
    RegisterAction("<Gen_Tab7>", "切换到标签页7")
    RegisterAction("<Gen_Tab8>", "切换到标签页8")
    RegisterAction("<Gen_Tab9>", "切换到标签页9")
    RegisterAction("<Gen_Tab0>", "切换到最后一个标签页")

    ; 鼠标操作
    RegisterAction("<MouseUp>", "鼠标向上移动")
    RegisterAction("<MouseDown>", "鼠标向下移动")
    RegisterAction("<MouseLeft>", "鼠标向左移动")
    RegisterAction("<MouseRight>", "鼠标向右移动")
    RegisterAction("<MouseClick>", "鼠标左键点击")
    RegisterAction("<MouseRightClick>", "鼠标右键点击")
    RegisterAction("<MouseDoubleClick>", "鼠标双击")

    ; IME 切换
    RegisterAction("<Gen_SwitchIME>", "切换输入法")
    RegisterAction("<Gen_EnglishIME>", "切换到英文输入法")

    ; 诊断命令 (启动器输入 VimDiag, 在目标窗口聚焦时执行)
    RegisterCommand("VimDiag", "function", "VimDiagCmd", "vim 状态诊断")

    ; 媒体动作
    RegisterAction("<media_next>", "下一首")
    RegisterAction("<media_prev>", "上一首")
    RegisterAction("<media_play>", "播放/暂停")
    RegisterAction("<media_stop>", "停止")

    ; 编辑器通用动作 (记事本类 ini 引用, 按键直达编辑器)
    RegisterAction("<word>", "下个词首")
    RegisterAction("<wordb>", "上个词首")
    RegisterAction("<wordend>", "词尾")
    RegisterAction("<deletedLine>", "删除整行")
    RegisterAction("<copyLine>", "复制整行")
    RegisterAction("<paste>", "粘贴")
    RegisterAction("<undo>", "撤销")
    RegisterAction("<redo>", "重做")
    RegisterAction("<deletechar>", "删除字符")
    RegisterAction("<insertBefore>", "光标前插入")
    RegisterAction("<insertAfter>", "光标后插入")
    RegisterAction("<insertNewLine>", "下方开新行")
    RegisterAction("<insertLineStart>", "行首插入")
    RegisterAction("<insertLineEnd>", "行尾插入")
    RegisterAction("<insertLineAbove>", "上方开新行")
    RegisterAction("<visualMode>", "可视选择")
    RegisterAction("<search>", "查找")
    RegisterAction("<nextMatch>", "下个匹配")
    RegisterAction("<prevMatch>", "上个匹配")

    ; 窗口控制
    RegisterAction("<Gen_AlwaysOnTop>", "窗口置顶")
    RegisterAction("<Gen_CancelAlwaysOnTop>", "取消窗口置顶")
    RegisterAction("<Gen_ToggleTitleBar>", "切换标题栏")
    RegisterAction("<Gen_Suspend>", "挂起机器")
    RegisterAction("<Reload>", "重新加载脚本")
    RegisterAction("<Gen_ShowHelp>", "显示帮助")
    RegisterAction("<Gen_SearchInWeb>", "网络搜索")

    ; 设置 normal 模式映射
    MapKey("j", "<down>", "General", "normal")
    MapKey("k", "<up>", "General", "normal")
    MapKey("h", "<left>", "General", "normal")
    MapKey("l", "<right>", "General", "normal")
    MapKey("i", "<Gen_InsertMode>", "General", "normal")
    MapKey("<Esc>", "<Gen_NormalMode>", "General", "insert")

    ; 标签页管理
    MapKey("t", "<Gen_NewTab>", "General", "normal")
    MapKey("x", "<Gen_CloseTab>", "General", "normal")
    MapKey("gn", "<Gen_NextTab>", "General", "normal")
    MapKey("gp", "<Gen_PrevTab>", "General", "normal")
    MapKey("g1", "<Gen_Tab1>", "General", "normal")
    MapKey("g2", "<Gen_Tab2>", "General", "normal")
    MapKey("g3", "<Gen_Tab3>", "General", "normal")
    MapKey("g4", "<Gen_Tab4>", "General", "normal")
    MapKey("g5", "<Gen_Tab5>", "General", "normal")
    MapKey("g6", "<Gen_Tab6>", "General", "normal")
    MapKey("g7", "<Gen_Tab7>", "General", "normal")
    MapKey("g8", "<Gen_Tab8>", "General", "normal")
    MapKey("g9", "<Gen_Tab9>", "General", "normal")
    MapKey("g0", "<Gen_Tab0>", "General", "normal")

    ; 窗口管理
    MapKey("zj", "<wm_down>", "General", "normal")
    MapKey("zk", "<wm_up>", "General", "normal")
    MapKey("zh", "<wm_left>", "General", "normal")
    MapKey("zl", "<wm_right>", "General", "normal")
    MapKey("zc", "<wm_center>", "General", "normal")
    MapKey("zf", "<wm_full>", "General", "normal")
    MapKey("zm", "<wm_max>", "General", "normal")
    MapKey("zn", "<wm_min>", "General", "normal")
    MapKey("zr", "<wm_restore>", "General", "normal")

    ; 鼠标操作
    MapKey("<c-j>", "<MouseDown>", "General", "normal")
    MapKey("<c-k>", "<MouseUp>", "General", "normal")
    MapKey("<c-h>", "<MouseLeft>", "General", "normal")
    MapKey("<c-l>", "<MouseRight>", "General", "normal")

    ; 窗口控制
    MapKey("za", "<Gen_AlwaysOnTop>", "General", "normal")
    MapKey("zA", "<Gen_CancelAlwaysOnTop>", "General", "normal")
    MapKey("zt", "<Gen_ToggleTitleBar>", "General", "normal")
    MapKey("zs", "<Gen_Suspend>", "General", "normal")

    ; 系统操作
    MapKey("<F5>", "<Reload>", "General", "normal")
    MapKey("z/", "<Gen_ShowHelp>", "General", "normal")
    MapKey("zw", "<Gen_SearchInWeb>", "General", "normal")

    ; 数字键传递 (同 TC 插件: 无对应函数, 直接透传, Count 逻辑在引擎层)
    MapKey("0", "<Pass>", "General", "normal")
    MapKey("1", "<Pass>", "General", "normal")
    MapKey("2", "<Pass>", "General", "normal")
    MapKey("3", "<Pass>", "General", "normal")
    MapKey("4", "<Pass>", "General", "normal")
    MapKey("5", "<Pass>", "General", "normal")
    MapKey("6", "<Pass>", "General", "normal")
    MapKey("7", "<Pass>", "General", "normal")
    MapKey("8", "<Pass>", "General", "normal")
    MapKey("9", "<Pass>", "General", "normal")

    ; IME 切换
    MapKey("<c-\>", "<Gen_SwitchIME>", "General", "normal")
}

; === 基础动作函数 (模式切换作用于当前窗口, 非 __global__) ===
VimDiagCmd() {
    global g_VimEngine
    if IsObject(g_VimEngine)
        g_VimEngine.VimDiag()
}

CurVimWin() {
    global g_VimEngine
    if !IsObject(g_VimEngine)
        return ""
    try {
        name := g_VimEngine.CheckWin()
        w := g_VimEngine.GetWin(name)
        if IsObject(w)
            return w
    }
    return g_VimEngine.winGlobal
}

Gen_Toggle() {
    ; 切换模式：normal ↔ insert
    win := CurVimWin()
    if !IsObject(win)
        return

    if (win.currentMode = "normal") {
        win.currentMode := "insert"
        Log("Mode: insert")
    } else {
        win.currentMode := "normal"
        Log("Mode: normal")
    }
}

Gen_InsertMode() {
    ; 进入插入模式
    win := CurVimWin()
    if !IsObject(win)
        return

    win.currentMode := "insert"
    Log("Mode: insert")
}

Gen_NormalMode() {
    ; 返回正常模式
    win := CurVimWin()
    if !IsObject(win)
        return

    win.currentMode := "normal"
    Log("Mode: normal")
}

; === 编辑器通用动作 (按键直达, 适配记事本类) ===
word() {
    Send("^{Right}")
}

wordb() {
    Send("^{Left}")
}

wordend() {
    Send("^{Right}{Left}")
}

deletedLine() {
    Send("{Home}+{End}{Del}")
}

copyLine() {
    Send("{Home}+{End}^c")
}

paste() {
    Send("^v")
}

undo() {
    Send("^z")
}

redo() {
    Send("^y")
}

deletechar() {
    Send("{Del}")
}

insertBefore() {
    Gen_InsertMode()
}

insertAfter() {
    Send("{Right}")
    Gen_InsertMode()
}

insertNewLine() {
    Send("{End}{Enter}")
    Gen_InsertMode()
}

insertLineStart() {
    Send("{Home}")
    Gen_InsertMode()
}

insertLineEnd() {
    Send("{End}")
    Gen_InsertMode()
}

insertLineAbove() {
    Send("{Home}{Enter}{Up}")
    Gen_InsertMode()
}

visualMode() {
    Send("+{Right}")
}

search() {
    Send("^f")
}

nextMatch() {
    Send("{F3}")
}

prevMatch() {
    Send("+{F3}")
}

down() {
    Send "{Down}"
}

up() {
    Send "{Up}"
}

left() {
    Send "{Left}"
}

right() {
    Send "{Right}"
}

enter() {
    Send "{Enter}"
}

bs() {
    Send "{Backspace}"
}

tab() {
    Send "{Tab}"
}

space() {
    Send "{Space}"
}

home() {
    Send "{Home}"
}

end() {
    Send "{End}"
}

pgup() {
    Send "{PgUp}"
}

pgdn() {
    Send "{PgDn}"
}

del() {
    Send "{Del}"
}

; === 编辑操作 ===
c_a() {
    Send "^a"
}

c_c() {
    Send "^c"
}

c_v() {
    Send "^v"
}

c_x() {
    Send "^x"
}

c_z() {
    Send "^z"
}

c_y() {
    Send "^y"
}

c_s() {
    Send "^s"
}

c_f() {
    Send "^f"
}

c_h() {
    Send "^h"
}

c_w() {
    Send "^w"
}

; === 窗口管理函数 ===
wm_left() {
    WinGetPos(&x, &y, &w, &h, "A")
    WinMove(x - 50, , , , "A")
}

wm_right() {
    WinGetPos(&x, &y, &w, &h, "A")
    WinMove(x + 50, , , , "A")
}

wm_up() {
    WinGetPos(&x, &y, &w, &h, "A")
    WinMove(, y - 50, , , "A")
}

wm_down() {
    WinGetPos(&x, &y, &w, &h, "A")
    WinMove(, y + 50, , , "A")
}

wm_max() {
    WinMaximize "A"
}

wm_min() {
    WinMinimize "A"
}

wm_restore() {
    WinRestore "A"
}

wm_center() {
    WinGetPos(, , &w, &h, "A")
    x := (A_ScreenWidth - w) // 2
    y := (A_ScreenHeight - h) // 2
    WinMove(x, y, , , "A")
}

wm_full() {
    static isFull := false
    if !isFull {
        WinGetPos(&x, &y, &w, &h, "A")
        WinMove(0, 0, A_ScreenWidth, A_ScreenHeight, "A")
        isFull := true
    } else {
        WinRestore "A"
        isFull := false
    }
}

; === 媒体控制 ===
media_next() {
    Send "{Media_Next}"
}

media_prev() {
    Send "{Media_Prev}"
}

media_play() {
    Send "{Media_Play_Pause}"
}

media_stop() {
    Send "{Media_Stop}"
}

; === 标签页管理 ===
Gen_NewTab() {
    Send "^t"
}

Gen_CloseTab() {
    Send "^w"
}

Gen_NextTab() {
    Send "^{Tab}"
}

Gen_PrevTab() {
    Send "^+{Tab}"
}

Gen_Tab1() {
    Send "^1"
}

Gen_Tab2() {
    Send "^2"
}

Gen_Tab3() {
    Send "^3"
}

Gen_Tab4() {
    Send "^4"
}

Gen_Tab5() {
    Send "^5"
}

Gen_Tab6() {
    Send "^6"
}

Gen_Tab7() {
    Send "^7"
}

Gen_Tab8() {
    Send "^8"
}

Gen_Tab9() {
    Send "^9"
}

Gen_Tab0() {
    Send "^0"
}

; === 鼠标操作 ===
MouseUp() {
    MouseMove(0, -50, 0, "R")
}

MouseDown() {
    MouseMove(0, 50, 0, "R")
}

MouseLeft() {
    MouseMove(-50, 0, 0, "R")
}

MouseRight() {
    MouseMove(50, 0, 0, "R")
}

MouseClick() {
    Click
}

MouseRightClick() {
    Click "Right"
}

MouseDoubleClick() {
    Click "2"
}

; === IME 切换 ===
Gen_SwitchIME() {
    ; 切换输入法
    Send "^{Space}"
}

Gen_EnglishIME() {
    ; 切换到英文输入法
    ; 使用 Windows API
    try {
        hwnd := WinActive("A")
        ; 发送语言切换消息
        PostMessage 0x0050, 0, 0x04090409, , "ahk_id " hwnd  ; 英文 US
    }
}

; 对原版 <SwitchToEngIMEAndEsc> (custom ini <esc> 用): 先 Esc 再连切英文
SwitchToEngIMEAndEsc(*) {
    Send("{Esc}")
    SwitchToEngIME()
}

; === 窗口控制 ===
Gen_AlwaysOnTop() {
    WinSetAlwaysOnTop(1, "A")
}

Gen_CancelAlwaysOnTop() {
    WinSetAlwaysOnTop(0, "A")
}

Gen_ToggleTitleBar() {
    static hasBorder := true
    WinGetPos(, , &w, &h, "A")
    if hasBorder {
        WinMove(, , w, h + 30, "A")
        hasBorder := false
    } else {
        WinMove(, , w, h - 30, "A")
        hasBorder := true
    }
}

Gen_Suspend() {
    if ShowConfirm("确定要挂起机器吗？", "挂起") {
        DllCall("PowrProf\SetSuspendState", "int", 0, "int", 0, "int", 0)
    }
}

; === 系统操作 ===
Reload() {
    ; 重新加载脚本
    Reload()
}

Gen_ShowHelp() {
    ; 显示帮助信息
    helpText := "Rim 快捷键帮助`n`n"
    helpText .= "模式切换:`n"
    helpText .= "  i        - 进入插入模式`n"
    helpText .= "  <Esc>    - 返回正常模式`n`n"
    helpText .= "方向键:`n"
    helpText .= "  h/j/k/l  - 左/下/上/右`n"
    helpText .= "  <C-j/k>  - 鼠标上/下移动`n"
    helpText .= "  <C-h/l>  - 鼠标左/右移动`n`n"
    helpText .= "窗口管理:`n"
    helpText .= "  zc       - 居中窗口`n"
    helpText .= "  zf       - 全屏窗口`n"
    helpText .= "  zm       - 最大化窗口`n"
    helpText .= "  zn       - 最小化窗口`n"
    helpText .= "  zr       - 还原窗口`n"
    helpText .= "  za/zA    - 置顶/取消置顶`n"
    helpText .= "  zt       - 切换标题栏`n`n"
    helpText .= "标签页:`n"
    helpText .= "  t        - 新建标签页`n"
    helpText .= "  x        - 关闭标签页`n"
    helpText .= "  gn/gp    - 下一个/上一个`n"
    helpText .= "  g1-g9    - 切换到标签1-9`n`n"
    helpText .= "其他:`n"
    helpText .= "  F5       - 重新加载`n"
    helpText .= "  zw       - 网络搜索`n"
    helpText .= "  zs       - 挂起机器`n"

    ToolTip(helpText)
    SetTimer () => ToolTip(), -5000
}

Gen_SearchInWeb() {
    ; 网络搜索剪贴板内容
    A_Clipboard := Trim(A_Clipboard)
    if (A_Clipboard = "") {
        ToolTip("请先复制要搜索的内容")
        SetTimer () => ToolTip(), -2000
        return
    }

    ; 使用默认浏览器搜索
    searchUrl := "https://www.google.com/search?q=" UriEncode(A_Clipboard)
    Run(searchUrl)
    Log("Gen: Searched in web: " A_Clipboard)
}
