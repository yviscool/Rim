#Requires AutoHotkey v2.0
#Warn All, Off

; === Misc.Clip - 剪贴板/日期/取色 (纯实现, 注册见 Misc.ahk) ===

; === 剪切板工具 (结果进显示区, 对齐原版 Clip) ===
Misc_ShowClipboard() {
    clipText := A_Clipboard
    ActivateRunZ()
    if (clipText = "")
        DisplayResult(T("misc.clip_empty"))
    else
        DisplayResult(T("misc.clip_len", StrLen(clipText)) . "`n" . clipText)
}

ClearClipboard() {
    A_Clipboard := ""
    Log("剪切板已清空")
}

SaveClipboard() {
    if (A_Clipboard = "") {
        DisplayResult(T("misc.clip_empty"))
        return
    }

    filePath := FileSelect("S16", , T("misc.title_clip_save"), T("misc.filter_text"))
    if (filePath != "") {
        try {
            f := FileOpen(filePath, "w")
            f.Write(A_Clipboard)
            f.Close()
            DisplayResult(T("misc.saved_to", filePath))
        } catch as e {
            DisplayResult(T("misc.save_failed", e.Message))
        }
    }
}

; === 日期时间 ===
InsertDate() {
    dateStr := FormatTime(, "yyyy-MM-dd")
    Send dateStr
}

InsertTime() {
    timeStr := FormatTime(, "HH:mm:ss")
    Send timeStr
}

InsertDateTime() {
    dateTimeStr := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    Send dateTimeStr
}

; === 颜色工具 ===
PickColor() {
    ; 拾色器 - 获取鼠标位置颜色
    MouseGetPos(&x, &y)
    pixelColor := PixelGetColor(x, y)

    ; 转换为 RGB
    r := (pixelColor >> 16) & 0xFF
    g := (pixelColor >> 8) & 0xFF
    b := pixelColor & 0xFF

    result := "RGB: " r ", " g ", " b "`n"
    result .= "HEX: " Format("{:02X}{:02X}{:02X}", r, g, b) "`n"
    result .= "AHK: " pixelColor

    A_Clipboard := Format("{:02X}{:02X}{:02X}", r, g, b)
    DisplayResult(result)
}

; ColorInfo 别名: 与 ColorPicker 同一命令 (拾色实现见 PickColor)
GetColorInfo() {
    PickColor()
}

