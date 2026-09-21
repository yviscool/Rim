#Requires AutoHotkey v2.0

; === Foobar2000 Plugin ===
; 完整移植自 VimDesktop 的 Foobar2000 插件
; 支持 insert/normal 模式系统, 帮助显示, 控件定位

RegisterPlugin_Foobar2000() {
    RegisterWin("Foobar2000", "BaseWindow_Root2", "foobar2000.exe")

    ; 注册动作
    RegisterAction("<FB_Next>", "下一首")
    RegisterAction("<FB_Prev>", "上一首")
    RegisterAction("<FB_Stop>", "停止")
    RegisterAction("<FB_Play>", "播放/暂停")
    RegisterAction("<FB_NextTab>", "下一个标签页")
    RegisterAction("<FB_PrevTab>", "上一个标签页")
    RegisterAction("<FB_Search>", "搜索")
    RegisterAction("<FB_Home>", "跳到开头")
    RegisterAction("<FB_End>", "跳到结尾")
    RegisterAction("<FB_PgUp>", "上一页")
    RegisterAction("<FB_PgDn>", "下一页")
    RegisterAction("<FB_VolUp>", "音量增加")
    RegisterAction("<FB_VolDown>", "音量减少")
    RegisterAction("<FB_VolMute>", "静音")
    RegisterAction("<FB_FocusTree>", "定位到目录窗口")
    RegisterAction("<FB_FocusList>", "定位到播放列表")
    RegisterAction("<FB_ShowHelp>", "显示帮助")

    ; insert 模式映射
    MapKey("<enter>", "<enter>", "Foobar2000", "insert")
    MapKey("<bs>", "<bs>", "Foobar2000", "insert")
    MapKey("<tab>", "<tab>", "Foobar2000", "insert")
    MapKey("<space>", "<space>", "Foobar2000", "insert")
    MapKey("<del>", "<del>", "Foobar2000", "insert")

    ; normal 模式映射
    ; 播放控制
    MapKey("n", "<FB_Next>", "Foobar2000", "normal")
    MapKey("p", "<FB_Prev>", "Foobar2000", "normal")
    MapKey("s", "<FB_Stop>", "Foobar2000", "normal")
    MapKey("<Space>", "<FB_Play>", "Foobar2000", "normal")

    ; 标签页
    MapKey("t", "<FB_NextTab>", "Foobar2000", "normal")
    MapKey("m", "<FB_PrevTab>", "Foobar2000", "normal")

    ; 搜索
    MapKey("/", "<FB_Search>", "Foobar2000", "normal")

    ; 导航
    MapKey("gg", "<FB_Home>", "Foobar2000", "normal")
    MapKey("G", "<FB_End>", "Foobar2000", "normal")
    MapKey("<C-u>", "<FB_PgUp>", "Foobar2000", "normal")
    MapKey("<C-d>", "<FB_PgDn>", "Foobar2000", "normal")

    ; 音量控制
    MapKey("+", "<FB_VolUp>", "Foobar2000", "normal")
    MapKey("-", "<FB_VolDown>", "Foobar2000", "normal")
    MapKey("z", "<FB_VolMute>", "Foobar2000", "normal")

    ; 控件定位
    MapKey("<C-w>h", "<FB_FocusTree>", "Foobar2000", "normal")
    MapKey("<C-w>l", "<FB_FocusList>", "Foobar2000", "normal")

    ; 帮助
    MapKey("z/", "<FB_ShowHelp>", "Foobar2000", "normal")

    ; 模式切换
    MapKey("i", "<Gen_InsertMode>", "Foobar2000", "normal")
    MapKey("<Esc>", "<Gen_NormalMode>", "Foobar2000", "insert")
}

; === 动作函数 ===

FB_Next() {
    Send "{Media_Next}"
}

FB_Prev() {
    Send "{Media_Prev}"
}

FB_Stop() {
    Send "{Media_Stop}"
}

FB_Play() {
    Send "{Media_Play_Pause}"
}

FB_NextTab() {
    Send "^{Tab}"
}

FB_PrevTab() {
    Send "^+{Tab}"
}

FB_Search() {
    Send "^f"
}

FB_Home() {
    Send "^{Home}"
}

FB_End() {
    Send "^{End}"
}

FB_PgUp() {
    Send "{PgUp}"
}

FB_PgDn() {
    Send "{PgDn}"
}

FB_VolUp() {
    Send "{Volume_Up}"
}

FB_VolDown() {
    Send "{Volume_Down}"
}

FB_VolMute() {
    Send "{Volume_Mute}"
}

FB_FocusTree() {
    try {
        ControlFocus("SysTreeView321", "A")
    }
}

FB_FocusList() {
    try {
        ; Foobar2000 播放列表控件
        ControlFocus("SysListView321", "A")
    }
}

FB_ShowHelp() {
    helpText := "Foobar2000 快捷键帮助`n`n"
    helpText .= "播放控制:`n"
    helpText .= "  <Space>  - 播放/暂停`n"
    helpText .= "  n        - 下一首`n"
    helpText .= "  p        - 上一首`n"
    helpText .= "  s        - 停止`n`n"
    helpText .= "音量控制:`n"
    helpText .= "  +        - 音量增加`n"
    helpText .= "  -        - 音量减少`n"
    helpText .= "  z        - 静音`n`n"
    helpText .= "导航:`n"
    helpText .= "  gg       - 跳到开头`n"
    helpText .= "  G        - 跳到结尾`n"
    helpText .= "  <C-u>    - 上一页`n"
    helpText .= "  <C-d>    - 下一页`n`n"
    helpText .= "标签页:`n"
    helpText .= "  t        - 下一个标签`n"
    helpText .= "  m        - 上一个标签`n`n"
    helpText .= "其他:`n"
    helpText .= "  /        - 搜索`n"
    helpText .= "  <C-w>h   - 定位到目录窗口`n"
    helpText .= "  <C-w>l   - 定位到播放列表`n"

    ToolTip(helpText)
    SetTimer () => ToolTip(), -5000
}
