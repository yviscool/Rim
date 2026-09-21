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
    RegisterAction("<SP_Back>", "手势: 后退")
    RegisterAction("<SP_Forward>", "手势: 前进")
    RegisterAction("<SP_Up>", "手势: 上滚/上一页")
    RegisterAction("<SP_Down>", "手势: 下滚/下一页")
    RegisterAction("<SP_Home>", "手势: 行首/顶部")
    RegisterAction("<SP_End>", "手势: 行尾/底部")
    RegisterAction("<SP_VolUp>", "手势: 音量+")
    RegisterAction("<SP_VolDown>", "手势: 音量-")
    RegisterAction("<SP_Mute>", "手势: 静音切换")
    RegisterAction("<SP_CloseTab>", "手势: 关闭标签页")
    RegisterAction("<SP_ReopenTab>", "手势: 恢复标签页")
    RegisterAction("<SP_NewTab>", "手势: 新建标签页")
    RegisterAction("<SP_Copy>", "手势: 复制")
    RegisterAction("<SP_Paste>", "手势: 粘贴")
    RegisterAction("<SP_Cut>", "手势: 剪切")
    RegisterAction("<SP_PlayPause>", "手势: 播放/暂停")
    RegisterAction("<SP_Next>", "手势: 下一首")
    RegisterAction("<SP_Prev>", "手势: 上一首")
    Register_GestureDefaults()
}

; ---- 缺键补默认(只增不改, 用户 ini 优先) ----
Register_GestureDefaults() {
    global g_Conf, g_ConfFile, g_GestureMap
    defaultsGesture := Map(
        "Enable", "1",
        "Trigger", "RButton",
        "Threshold", "20",
        "Segment", "30",
        "ShowOSD", "1",
        "NoMatch", "swallow",
        "IgnoreKey", "",
        "OnlyDefinedApps", "0",
        "Trail", "1",
        "TrailColor", "45ABFF",
        "TrailWidth", "5"
    )
    ; 原版 StrokesPlus 默认动作对齐 (/ Up=最大化 / Down=最小化 U=复制 D=粘贴 U_D=F5 等)
    ; 单字母 (e/G/U/R/D/P/L/N/S/M/Z/B/J/h/X/3) 走模板, 见 Core/GestureTemplate.ahk 内置
    defaultsGestures := Map(
        "L", "key|{Browser_Back}",
        "R", "key|{Browser_Forward}",
        "U", "key|^c",
        "D", "key|^v",
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
        "U_R", "<SP_VolUp>",
        "U_L", "<SP_VolDown>",
        "R_D", "<SP_End>",
        "L_D", "run|explorer.exe",
        "R_U", "<SP_Home>",
        "L_U", "<SP_Home>",
        "DR", "key|{Browser_Forward}",
        "DL", "key|{Browser_Back}",
        "UL", "key|{BackSpace}",
        "UR", "key|{Tab}",
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
