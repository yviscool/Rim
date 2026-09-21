#Requires AutoHotkey v2.0

; === Foobar2000 Plugin ===
; 完整移植自 VimDesktop 的 Foobar2000 插件
; 支持 insert/normal 模式系统, 帮助显示, 控件定位

RegisterPlugin_Foobar2000() {
    RegisterWin("Foobar2000", "BaseWindow_Root2", "foobar2000.exe")

    ; 注册动作
    RegisterAction("<FB_Next>", T("act.Foobar2000.FB_Next"))
    RegisterAction("<FB_Prev>", T("act.Foobar2000.FB_Prev"))
    RegisterAction("<FB_Stop>", T("act.Foobar2000.FB_Stop"))
    RegisterAction("<FB_Play>", T("act.Foobar2000.FB_Play"))
    RegisterAction("<FB_NextTab>", T("act.Foobar2000.FB_NextTab"))
    RegisterAction("<FB_PrevTab>", T("act.Foobar2000.FB_PrevTab"))
    RegisterAction("<FB_Search>", T("act.Foobar2000.FB_Search"))
    RegisterAction("<FB_Home>", T("act.Foobar2000.FB_Home"))
    RegisterAction("<FB_End>", T("act.Foobar2000.FB_End"))
    RegisterAction("<FB_PgUp>", T("act.Foobar2000.FB_PgUp"))
    RegisterAction("<FB_PgDn>", T("act.Foobar2000.FB_PgDn"))
    RegisterAction("<FB_VolUp>", T("act.Foobar2000.FB_VolUp"))
    RegisterAction("<FB_VolDown>", T("act.Foobar2000.FB_VolDown"))
    RegisterAction("<FB_VolMute>", T("act.Foobar2000.FB_VolMute"))
    RegisterAction("<FB_FocusTree>", T("act.Foobar2000.FB_FocusTree"))
    RegisterAction("<FB_FocusList>", T("act.Foobar2000.FB_FocusList"))
    RegisterAction("<FB_ShowHelp>", T("act.Foobar2000.FB_ShowHelp"))

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
    ; 双语文本见 Lang/*.ini help.foobar
    helpText := T("help.foobar")

    ToolTip(helpText)
    SetTimer () => ToolTip(), -5000
}
