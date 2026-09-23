#Requires AutoHotkey v2.0
#Warn All, Off

; === StrokePlus Plugin - 默认手势集 ===
; 以全局手势复用 Rim 既有动作体系 (<Gen_xxx>/<wm_xxx>/key|/run|...),
; 经 VIMD_CMD 统一派发, 无需重复实现功能.
; 真正的手势->动作映射在 Conf\rim.ini [Gestures] 中, 此处只做:
;   1) 若 ini 缺 [Gesture]/[Gestures] 则写入开箱默认值(不覆盖用户已有键)
;   2) 注册手势动作的 Action 说明(供 KeyHelp/帮助体系检索)
;   3) 提供几个手势专属小动作(前进/后退/上下页/音量)

RegisterPlugin_StrokePlus() {
    global g_Conf, g_ConfFile
    ; 动作说明注册(与 General 插件风格一致, 经 ActionToFuncName 转函数调用)
    RegisterAction("<SP_Back>", T("act.StrokePlus.SP_Back"))
    RegisterAction("<SP_Forward>", T("act.StrokePlus.SP_Forward"))
    RegisterAction("<SP_Up>", T("act.StrokePlus.SP_Up"))
    RegisterAction("<SP_Down>", T("act.StrokePlus.SP_Down"))
    RegisterAction("<SP_Home>", T("act.StrokePlus.SP_Home"))
    RegisterAction("<SP_End>", T("act.StrokePlus.SP_End"))
    RegisterAction("<SP_VolUp>", T("act.StrokePlus.SP_VolUp"))
    RegisterAction("<SP_VolDown>", T("act.StrokePlus.SP_VolDown"))
    RegisterAction("<SP_Mute>", T("act.StrokePlus.SP_Mute"))
    RegisterAction("<SP_CloseTab>", T("act.StrokePlus.SP_CloseTab"))
    RegisterAction("<SP_ReopenTab>", T("act.StrokePlus.SP_ReopenTab"))
    RegisterAction("<SP_NewTab>", T("act.StrokePlus.SP_NewTab"))
    RegisterAction("<SP_Copy>", T("act.StrokePlus.SP_Copy"))
    RegisterAction("<SP_Paste>", T("act.StrokePlus.SP_Paste"))
    RegisterAction("<SP_Cut>", T("act.StrokePlus.SP_Cut"))
    RegisterAction("<SP_PlayPause>", T("act.StrokePlus.SP_PlayPause"))
    RegisterAction("<SP_Next>", T("act.StrokePlus.SP_Next"))
    RegisterAction("<SP_Prev>", T("act.StrokePlus.SP_Prev"))
    Register_GestureDefaults()
}

; ---- 缺键补默认(只增不改, 用户 ini 优先) ----
Register_GestureDefaults() {
    global g_Conf, g_ConfFile, g_GestureMap
    defaultsGesture := Map(
        "Enable", "1",
        "Trigger", "RButton",
        "Threshold", "6",
        "Segment", "6",
        "Poll", "10",
        "CancelDelay", "1500",
        "ShowOSD", "1",
        "NoMatch", "swallow",
        "IgnoreKey", "",
        "OnlyDefinedApps", "0",
        "Trail", "1",
        "TrailColor", "45ABFF",
        "TrailWidth", "5"
    )
    ; 原版 StrokesPlus 默认动作对齐:
    ; 单笔斜线: / Up(右上)=最大化 / Down(左下)=最小化 \ Up(左上)=Alt+F4 \ Down(右下)=Ctrl+W
    ;   Right-Down=打开 Chrome; U=复制 D=粘贴 U_D=刷新
    ; 方向链 (DIR 空间, 全大写) 与字母模板 (TPL 空间, TPL:U) 命名隔离,
    ; 单字母模板动作走 [GestureTemplates]/TPL: 覆盖, 见 Core/GestureTemplate.ahk;
    ; 浏览器专属 Z/B/J/h/3 与 U 后斜向前后页在 Conf/rim.ini 的 Browsers 层定义.
    defaultsGestures := Map(
        "L", "key|{Browser_Back}",
        "R", "key|{Browser_Forward}",
        "U", "key|^c",
        "D", "key|^v",
        "UR", "<wm_max>",
        "DL", "<wm_min>",
        "UL", "key|!{F4}",
        "DR", "key|^w",
        "UR_U", "<wm_max>",
        "DR_D", "<wm_min>",
        "UL_U", "key|!{F4}",
        "U_D", "key|{F5}",
        "U_D_U", "<Reload>",
        "D_R", "<SP_NewTab>",
        "D_L", "<SP_CloseTab>",
        "DL_D", "key|^w",
        "L_R", "key|#{Left}",
        "R_L", "key|#{Right}",
        "R_D", "run|D:\software\Chrome\App\Chrome.exe",
        "L_D", "run|explorer.exe",
        "L_U", "<SP_Home>",
        "D_L_D", "function|Gesture_IgnoreNext",
        "WheelUp", "<Gen_NextTab>",
        "WheelDown", "<Gen_PrevTab>",
        "CTRL+WheelUp", "<SP_VolUp>",
        "CTRL+WheelDown", "<SP_VolDown>"
    )
    changed := false
    append := ""
    hadGesture := false
    hadGestures := false
    try hadGesture := g_Conf.HasSection("Gesture")
    try hadGestures := g_Conf.HasSection("Gestures")
    if (!hadGesture)
        append .= "`r`n[Gesture]`r`n"
    for k, v in defaultsGesture {
        try {
            ; 注意: 空值是合法配置(如 IgnoreKey), 必须用 HasKey 判缺键, 不能用 Get(... )=""
            if (!g_Conf.HasKey("Gesture", k)) {
                g_Conf.AddKey("Gesture", k, v)
                append .= k "=" v "`r`n"
                changed := true
            }
        }
    }
    if (!hadGestures)
        append .= "`r`n[Gestures]`r`n"
    for k, v in defaultsGestures {
        try {
            if (!g_Conf.HasKey("Gestures", k)) {
                g_Conf.AddKey("Gestures", k, v)
                append .= k "=" v "`r`n"
                changed := true
            }
        }
    }
    if (changed) {
        ; 注意: 不得用 g_Conf.Save(), 它重写全文件会吃掉 ini 全部注释;
        ; 缺键只向文件尾追加, 重启后 EasyIni 照常解析(重复键后值覆盖, 值相同无害)
        try FileAppend(append, g_ConfFile, "UTF-8")
        catch {
        }
    }
    ; 同步进内存映射(ini 已有键由 GestureInit 载入, 这里只补新增)
    for k, v in defaultsGestures {
        nk := Gesture_NormalizeFull(k)
        try {
            if (!g_GestureMap.Has(nk))
                g_GestureMap[nk] := v
        }
    }
}

; === 手势专属动作实现 (名与 <> 内一致, 经 ActionToFuncName 调用) ===
SP_Back() {
    Send("!{Left}")
}

SP_Forward() {
    Send("!{Right}")
}

SP_Up() {
    Send("{PgUp}")
}

SP_Down() {
    Send("{PgDn}")
}

SP_Home() {
    Send("^{Home}")
}

SP_End() {
    Send("^{End}")
}

SP_VolUp() {
    Send("{Volume_Up}")
}

SP_VolDown() {
    Send("{Volume_Down}")
}

SP_Mute() {
    Send("{Volume_Mute}")
}

SP_CloseTab() {
    Send("^w")
}

SP_ReopenTab() {
    Send("^+t")
}

SP_NewTab() {
    Send("^t")
}

SP_Copy() {
    Send("^c")
}

SP_Cut() {
    Send("^x")
}

SP_Paste() {
    Send("^v")
}

SP_PlayPause() {
    Send("{Media_Play_Pause}")
}

SP_Next() {
    Send("{Media_Next}")
}

SP_Prev() {
    Send("{Media_Prev}")
}
