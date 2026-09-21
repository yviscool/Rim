#Requires AutoHotkey v2.0

; === QRCode Plugin - 二维码生成 ===
; 移植自 RunZ 的 QRCode 插件

RegisterPlugin_QRCode() {
    RegisterCommand("QRCode", "function", "GenerateQRCode", "生成二维码")
    RegisterCommand("QRText", "function", "QRFromText", "文本转二维码")
    RegisterCommand("QRClip", "function", "QRFromClipboard", "剪切板转二维码")
    RegisterCommand("QRUrl", "function", "QRFromUrl", "网址转二维码")
}

; === 二维码生成 (Arg > 剪切板 > InputBox; 空输入 DisplayResult 报错) ===
QRCodePipeInput(prompt, title) {
    global Arg
    if (Trim(Arg) != "")
        return Trim(Arg)
    clip := Trim(A_Clipboard)
    if (clip != "")
        return clip
    return InputBox(prompt, title).Value
}

GenerateQRCode() {
    input := QRCodePipeInput("输入文本或网址:", "生成二维码")
    if (input = "") {
        DisplayResult("* | 错误 | 二维码内容为空")
        return
    }

    GenerateAndShowQR(input)
}

QRFromText() {
    input := QRCodePipeInput("输入文本:", "文本转二维码")
    if (input = "") {
        DisplayResult("* | 错误 | 二维码内容为空")
        return
    }

    GenerateAndShowQR(input)
}

QRFromClipboard() {
    text := Trim(A_Clipboard)
    if (text = "") {
        DisplayResult("* | 错误 | 剪切板为空")
        return
    }

    GenerateAndShowQR(text)
}

QRFromUrl() {
    input := QRCodePipeInput("输入网址:", "网址转二维码")
    if (input = "") {
        DisplayResult("* | 错误 | 二维码内容为空")
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
        DisplayResult("* | 错误 | 二维码下载失败, 请检查网络")
        return
    }

    ; 创建 GUI 显示二维码
    myGui := Gui("+Resize", "二维码 - " SubStr(text, 1, 30))
    myGui.AddText("w300 h20", "内容: " SubStr(text, 1, 50))
    myGui.Add("Picture", "w300 h300", tmpPng)

    ; 添加按钮
    myGui.AddButton("w100 h30", "复制链接").OnEvent("Click", (*) => (A_Clipboard := qrUrl, MsgBox("链接已复制")))
    myGui.AddButton("x+10 w100 h30", "保存图片").OnEvent("Click", (*) => SaveQRImage(text))
    myGui.AddButton("x+10 w100 h30", "关闭").OnEvent("Click", (*) => myGui.Destroy())

    myGui.Show("w320 h400")
}

SaveQRImage(text) {
    filePath := FileSelect("S16", , "保存二维码", "图片文件 (*.png;*.jpg)")
    if (filePath = "")
        return

    encodedText := QR_UriEncode(text)
    qrUrl := "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=" encodedText

    try {
        Download(qrUrl, filePath)
        MsgBox("二维码已保存到: " filePath, "保存成功")
    } catch as e {
        MsgBox("保存失败: " e.Message, "错误")
    }
}
