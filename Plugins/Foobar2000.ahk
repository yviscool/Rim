#Requires AutoHotkey v2.0

; === Foobar2000 Plugin ===
; 完整移植自 VimDesktop 的 Foobar2000 插件
; 支持 insert/normal 模式系统, 帮助显示, 控件定位

class Foobar2000Plugin extends RimPlugin {
    static Name => "Foobar2000"
    static Title => "Foobar2000"
    static Description => "Foobar2000 播放控制 Vim 映射"

    static RegisterKeymaps(engine) {
        Foobar2000_Keymaps(engine)
    }
}

if (IsSet(RimPluginManager) && IsObject(RimPluginManager))
    RimPluginManager.Register(Foobar2000Plugin)

Foobar2000_Keymaps(engine) {
    engine.SetWin("Foobar2000", "BaseWindow_Root2", "foobar2000.exe")

    ; 注册动作
    engine.SetAction("<FB_Next>", T("act.Foobar2000.FB_Next"))
    engine.SetAction("<FB_Prev>", T("act.Foobar2000.FB_Prev"))
    engine.SetAction("<FB_Stop>", T("act.Foobar2000.FB_Stop"))
    engine.SetAction("<FB_Play>", T("act.Foobar2000.FB_Play"))
    engine.SetAction("<FB_NextTab>", T("act.Foobar2000.FB_NextTab"))
    engine.SetAction("<FB_PrevTab>", T("act.Foobar2000.FB_PrevTab"))
    engine.SetAction("<FB_Search>", T("act.Foobar2000.FB_Search"))
    engine.SetAction("<FB_Home>", T("act.Foobar2000.FB_Home"))
    engine.SetAction("<FB_End>", T("act.Foobar2000.FB_End"))
    engine.SetAction("<FB_PgUp>", T("act.Foobar2000.FB_PgUp"))
    engine.SetAction("<FB_PgDn>", T("act.Foobar2000.FB_PgDn"))
    engine.SetAction("<FB_VolUp>", T("act.Foobar2000.FB_VolUp"))
    engine.SetAction("<FB_VolDown>", T("act.Foobar2000.FB_VolDown"))
    engine.SetAction("<FB_VolMute>", T("act.Foobar2000.FB_VolMute"))
    engine.SetAction("<FB_FocusTree>", T("act.Foobar2000.FB_FocusTree"))
    engine.SetAction("<FB_FocusList>", T("act.Foobar2000.FB_FocusList"))
    engine.SetAction("<FB_ShowHelp>", T("act.Foobar2000.FB_ShowHelp"))

    ; insert 模式映射
    engine.MapKey("<enter>", "<enter>", "Foobar2000", "insert")
    engine.MapKey("<bs>", "<bs>", "Foobar2000", "insert")
    engine.MapKey("<tab>", "<tab>", "Foobar2000", "insert")
    engine.MapKey("<space>", "<space>", "Foobar2000", "insert")
    engine.MapKey("<del>", "<del>", "Foobar2000", "insert")

    ; normal 模式映射
    ; 播放控制
    engine.MapKey("n", "<FB_Next>", "Foobar2000", "normal")
    engine.MapKey("p", "<FB_Prev>", "Foobar2000", "normal")
    engine.MapKey("s", "<FB_Stop>", "Foobar2000", "normal")
    engine.MapKey("<Space>", "<FB_Play>", "Foobar2000", "normal")

    ; 标签页
    engine.MapKey("t", "<FB_NextTab>", "Foobar2000", "normal")
    engine.MapKey("m", "<FB_PrevTab>", "Foobar2000", "normal")

    ; 搜索
    engine.MapKey("/", "<FB_Search>", "Foobar2000", "normal")

    ; 导航
    engine.MapKey("gg", "<FB_Home>", "Foobar2000", "normal")
    engine.MapKey("G", "<FB_End>", "Foobar2000", "normal")
    engine.MapKey("<C-u>", "<FB_PgUp>", "Foobar2000", "normal")
    engine.MapKey("<C-d>", "<FB_PgDn>", "Foobar2000", "normal")

    ; 音量控制
    engine.MapKey("+", "<FB_VolUp>", "Foobar2000", "normal")
    engine.MapKey("-", "<FB_VolDown>", "Foobar2000", "normal")
    engine.MapKey("z", "<FB_VolMute>", "Foobar2000", "normal")

    ; 控件定位
    engine.MapKey("<C-w>h", "<FB_FocusTree>", "Foobar2000", "normal")
    engine.MapKey("<C-w>l", "<FB_FocusList>", "Foobar2000", "normal")

    ; 帮助
    engine.MapKey("z/", "<FB_ShowHelp>", "Foobar2000", "normal")

    ; 模式切换
    engine.MapKey("i", "<Gen_InsertMode>", "Foobar2000", "normal")
    engine.MapKey("<Esc>", "<Gen_NormalMode>", "Foobar2000", "insert")
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
