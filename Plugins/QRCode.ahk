#Requires AutoHotkey v2.0

; === QRCode Plugin - 二维码生成 ===
; 移植自 RunZ 的 QRCode 插件
; 命令经 Hybrid RegisterCommands 直注

class QRCodePlugin extends RimPlugin {
    static Name => "QRCode"
    static Title => "QR Code Generator"
    static Description => "二维码生成 (文本/剪切板/URL)"

    static RegisterCommands() {
        RimCommand.Register("QRCode", "QRCode", MakeLegacyCmd("GenerateQRCode"), Map("Category", "Tool", "Description", T("cmd.QRCode.QRCode"), "Keywords", "QRCode"))
        RimCommand.Register("QRText", "QRText", MakeLegacyCmd("QRFromText"), Map("Category", "Tool", "Description", T("cmd.QRCode.QRText"), "Keywords", "QRText"))
        RimCommand.Register("QRClip", "QRClip", MakeLegacyCmd("QRFromClipboard"), Map("Category", "Tool", "Description", T("cmd.QRCode.QRClip"), "Keywords", "QRClip"))
        RimCommand.Register("QRUrl", "QRUrl", MakeLegacyCmd("QRFromUrl"), Map("Category", "Tool", "Description", T("cmd.QRCode.QRUrl"), "Keywords", "QRUrl"))
    }
}

if (IsSet(RimPluginManager) && IsObject(RimPluginManager))
    RimPluginManager.Register(QRCodePlugin)

; === 二维码生成 (g_Arg > 剪切板 > InputBox; 空输入 DisplayResult 报错) ===
QRCodePipeInput(prompt, title) {
    global g_Arg
    if (Trim(g_Arg) != "")
        return Trim(g_Arg)
    clip := Trim(A_Clipboard)
    if (clip != "")
        return clip
    return InputBox(prompt, title).Value
}

GenerateQRCode() {
    input := QRCodePipeInput(T("qr.prompt_text_url"), T("qr.title_qr"))
    if (input = "") {
        DisplayResult("* | " . T("qr.type_error") . " | " . T("qr.err_empty_content"))
        return
    }

    GenerateAndShowQR(input)
}

QRFromText() {
    input := QRCodePipeInput(T("qr.prompt_text"), T("qr.title_text"))
    if (input = "") {
        DisplayResult("* | " . T("qr.type_error") . " | " . T("qr.err_empty_content"))
        return
    }

    GenerateAndShowQR(input)
}

QRFromClipboard() {
    text := Trim(A_Clipboard)
    if (text = "") {
        DisplayResult("* | " . T("qr.type_error") . " | " . T("qr.err_empty_clip"))
        return
    }

    GenerateAndShowQR(text)
}

QRFromUrl() {
    input := QRCodePipeInput(T("qr.prompt_url"), T("qr.title_url"))
    if (input = "") {
        DisplayResult("* | " . T("qr.type_error") . " | " . T("qr.err_empty_content"))
        return
    }

    ; 确保有协议前缀
    if !RegExMatch(input, "^https?://")
        input := "https://" input

    GenerateAndShowQR(input)
}

; 本地 UTF-8 编码器 (不依赖 Misc 是否加载)
QR_UriEncode(str) {
    result := ""
    bufSize := StrPut(str, "UTF-8")
    buf := Buffer(bufSize, 0)
    StrPut(str, buf, "UTF-8")
    Loop bufSize - 1 {
        byte := NumGet(buf, A_Index - 1, "UChar")
        unreserved := (byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x5A)
        unreserved := unreserved || (byte >= 0x61 && byte <= 0x7A)
        unreserved := unreserved || byte = 0x2D || byte = 0x5F || byte = 0x2E || byte = 0x7E
        if (unreserved) {
            result .= Chr(byte)
        } else if (byte = 0x20) {
            result .= "+"
        } else {
            result .= "%" Format("{:02X}", byte)
        }
    }
    return result
}

GenerateAndShowQR(text) {
    ; 使用在线 API 生成二维码 (本地编码, 离线只影响图片加载)
    encodedText := QR_UriEncode(text)
    qrUrl := "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=" encodedText

    ; 先下载到临时文件, 原生 Picture 显示 (无网络也能开窗提示)
    tmpPng := A_Temp "\Rim.QR.png"
    try Download(qrUrl, tmpPng)
    catch {
        DisplayResult("* | " . T("qr.type_error") . " | " . T("qr.err_download"))
        return
    }

    ; 创建 GUI 显示二维码 (+Owner 挂主窗: 关 QR 焦点回主窗, 不走失活隐藏链;
    ; 显式 Close/Escape: 默认 Close 只是 Hide, 留僵尸窗)
    global g_MainGui, g_LastQRGui
    try {
        if (IsSet(g_LastQRGui) && IsObject(g_LastQRGui))
            g_LastQRGui.Destroy()
    } catch {
    }
    ownerOpt := ""
    try {
        if (IsSet(g_MainGui) && IsObject(g_MainGui))
            ownerOpt := " +Owner" g_MainGui.Hwnd
    } catch {
    }
    myGui := Gui("+Resize" ownerOpt, T("qr.gui_title", SubStr(text, 1, 30)))
    try g_LastQRGui := myGui
    catch {
    }
    myGui.OnEvent("Close", QRGui_Close)
    myGui.OnEvent("Escape", QRGui_Close)
    myGui.AddText("w300 h20", T("qr.content_label", SubStr(text, 1, 50)))
    myGui.Add("Picture", "w300 h300", tmpPng)

    ; 添加按钮
    myGui.AddButton("w100 h30", T("qr.btn_copy")).OnEvent("Click", (*) => (A_Clipboard := qrUrl, MsgBox(T("qr.link_copied"))))
    myGui.AddButton("x+10 w100 h30", T("qr.btn_save")).OnEvent("Click", (*) => SaveQRImage(text))
    myGui.AddButton("x+10 w100 h30", T("qr.btn_close")).OnEvent("Click", (*) => QRGui_Close(myGui))

    myGui.Show("w320 h400")
}

QRGui_Close(guiObj, *) {
    global g_LastQRGui
    try guiObj.Destroy()
    catch {
    }
    try g_LastQRGui := ""
    catch {
    }
    return true
}

SaveQRImage(text) {
    filePath := FileSelect("S16", , T("qr.save_title"), T("qr.save_filter"))
    if (filePath = "")
        return

    encodedText := QR_UriEncode(text)
    qrUrl := "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=" encodedText

    try {
        Download(qrUrl, filePath)
        MsgBox(T("qr.saved_to", filePath), T("qr.save_ok"))
    } catch as e {
        MsgBox(T("qr.save_failed", e.Message), T("qr.err_title"))
    }
}
