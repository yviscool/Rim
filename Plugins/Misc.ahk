#Requires AutoHotkey v2.0
#Warn All, Off

; === Misc Plugin - 杂项工具 ===
; 移植自 RunZ 的 Misc 插件（翻译/计算器/搜索引擎）

RegisterPlugin_Misc() {
    ; 搜索引擎
    RegisterCommand("Google", "url", "https://www.google.com/search?q={query}", "Google搜索")
    RegisterCommand("Baidu", "url", "https://www.baidu.com/s?wd={query}", "百度搜索")
    RegisterCommand("Bing", "url", "https://www.bing.com/search?q={query}", "Bing搜索")
    RegisterCommand("GitHub", "url", "https://github.com/search?q={query}", "GitHub搜索")
    RegisterCommand("Npm", "url", "https://www.npmjs.com/search?q={query}", "Npm搜索")
    RegisterCommand("Zhihu", "url", "https://www.zhihu.com/search?q={query}", "知乎搜索")
    RegisterCommand("Bilibili", "url", "https://search.bilibili.com/all?keyword={query}", "B站搜索")
    RegisterCommand("Taobao", "url", "https://s.taobao.com/search?q={query}", "淘宝搜索")
    RegisterCommand("JD", "url", "https://search.jd.com/Search?keyword={query}", "京东搜索")

    ; 翻译
    RegisterCommand("Translate", "function", "TranslateWord", "有道翻译")
    RegisterCommand("En2Cn", "function", "EnToCn", "英译中")
    RegisterCommand("Cn2En", "function", "CnToEn", "中译英")

    ; 计算器
    RegisterCommand("Calc", "function", "CalcExpression", "计算器")
    RegisterCommand("Eval", "function", "EvalExpression", "计算表达式")

    ; 剪切板工具
    RegisterCommand("ClipShow", "function", "Misc_ShowClipboard", "显示剪切板")
    RegisterCommand("ClipClear", "function", "ClearClipboard", "清空剪切板")
    RegisterCommand("ClipSave", "function", "SaveClipboard", "保存剪切板到文件")

    ; 日期时间
    RegisterCommand("Date", "function", "InsertDate", "插入当前日期")
    RegisterCommand("Time", "function", "InsertTime", "插入当前时间")
    RegisterCommand("DateTime", "function", "InsertDateTime", "插入日期时间")

    ; 颜色工具
    RegisterCommand("ColorPicker", "function", "PickColor", "拾色器")
    RegisterCommand("ColorInfo", "function", "PickColor", "颜色信息")

    ; 原版别名 (SearchOn*/Dictionary/CNY/USD/IP/日历/URL编解码/运行剪切板)
    RegisterCommand("SearchOnGoogle", "url", "https://www.google.com/search?q={query}", "谷歌搜索")
    RegisterCommand("SearchOnBaidu", "url", "https://www.baidu.com/s?wd={query}", "百度搜索")
    RegisterCommand("SearchOnBing", "url", "https://cn.bing.com/search?q={query}", "必应搜索")
    RegisterCommand("SearchOnZhihu", "url", "https://www.zhihu.com/search?type=content&q={query}", "知乎搜索")
    RegisterCommand("SearchOnNpm", "url", "https://www.npmjs.com/search?q={query}", "Npm搜索")
    RegisterCommand("SearchOnGithub", "url", "https://github.com/search?q={query}", "GitHub搜索")
    RegisterCommand("SearchOnBilibili", "url", "https://search.bilibili.com/all?keyword={query}", "B站搜索")
    RegisterCommand("SearchOnTaobao", "url", "https://s.taobao.com/search?q={query}", "淘宝搜索")
    RegisterCommand("SearchOnJD", "url", "https://search.jd.com/Search?keyword={query}", "京东搜索")
    RegisterCommand("Dictionary", "function", "TranslateWord", "词典")
    RegisterCommand("CNY2USD", "function", "CNY2USD", "人民币转美元")
    RegisterCommand("USD2CNY", "function", "USD2CNY", "美元转人民币")
    RegisterCommand("CurrencyRate", "function", "CurrencyRate", "汇率 (示例: CurrencyRate USD CNY 2)")
    RegisterCommand("ShowIp", "function", "ShowIp", "本机IP")
    RegisterCommand("Calendar", "function", "Calendar", "万年历")
    RegisterCommand("UrlEncode", "function", "UrlEncodeCmd", "URL编码")
    RegisterCommand("UrlDecode", "function", "UrlDecodeCmd", "URL解码")
    ; 注: RunClipboard 由 LauncherCore 提供(Arg 感知), 此处不重复注册避免同名
}

; 管道输入: Arg > 剪切板 > InputBox
MiscPipeInput(prompt, title) {
    global Arg
    if (Trim(Arg) != "")
        return Trim(Arg)
    clip := Trim(A_Clipboard)
    if (clip != "")
        return clip
    return InputBox(prompt, title).Value
}

; === 搜索引擎 ===
; 搜索命令格式：命令名|url|描述
; 在 Launcher 中输入 "Google keyword" 即可搜索

; === 翻译功能 (Arg > 剪切板 > InputBox) ===
TranslateWord() {
    word := MiscPipeInput("输入要翻译的单词:", "翻译")
    if (word = "")
        return

    ; 使用必应翻译完整解析 (9维度), 结果进显示区不弹新窗
    result := BingFanyiFull(word)
    if (result != "") {
        DisplayResult("翻译 - " word "`n`n" result)
    } else {
        ; 失败则打开网页
        url := "https://dict.youdao.com/w?le=en&q=" UriEncode(word)
        Run url
    }
}

EnToCn() {
    word := MiscPipeInput("输入英文:", "英译中")
    if (word = "")
        return

    result := BingDictLookup(word, "en-zh")
    if (result != "") {
        DisplayResult("英译中 - " word "`n`n" result)
    } else {
        url := "https://dict.youdao.com/w?le=en&q=" UriEncode(word)
        Run url
    }
}

CnToEn() {
    word := MiscPipeInput("输入中文:", "中译英")
    if (word = "")
        return

    result := BingDictLookup(word, "zh-en")
    if (result != "") {
        DisplayResult("中译英 - " word "`n`n" result)
    } else {
        url := "https://dict.youdao.com/w?le=zh&q=" UriEncode(word)
        Run url
    }
}

; === Bing 词典抓取 ===
BingDictLookup(word, lang := "en-zh") {
    try {
        ; Bing 词典 API
        url := "https://www.bing.com/api/v6/DictionaryLookup?词=" UriEncode(word) "&lang=" lang
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.Open("GET", url, false)
        http.SetRequestHeader("User-Agent", "Mozilla/5.0")
        http.Send()

        if (http.Status = 200) {
            response := http.ResponseText
            return ParseBingResponse(response, word)
        }
    }

    ; 备用：抓取 Bing 网页
    try {
        url := "https://www.bing.com/dict/search?q=" UriEncode(word)
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.Open("GET", url, false)
        http.SetRequestHeader("User-Agent", "Mozilla/5.0")
        http.Send()

        if (http.Status = 200) {
            html := http.ResponseText
            return ParseBingHtml(html, word)
        }
    }

    return ""
}

; === 解析 Bing API 响应 ===
ParseBingResponse(response, word) {
    result := word "`n`n"

    ; 简单 JSON 解析
    if RegExMatch(response, "Translations.*?\[.*?\]", &transMatch) {
        translations := transMatch[0]
        ; 提取翻译
        pos := 1
        while RegExMatch(translations, 'Text.*?:.*?"([^"]+)"', &match, pos) {
            result .= match[1] "`n"
            pos += match.Pos[0] + match.Len[0]
        }
    }

    ; 提取音标
    if RegExMatch(response, 'UsPhonetic.*?:.*?"([^"]+)"', &phonetic) {
        result .= "`n美式: [" phonetic[1] "]"
    }
    if RegExMatch(response, 'UkPhonetic.*?:.*?"([^"]+)"', &phonetic) {
        result .= " 英式: [" phonetic[1] "]"
    }

    return result
}

; === 解析 Bing 网页 ===
ParseBingHtml(html, word) {
    result := word "`n`n"

    ; 提取音标
    if RegExMatch(html, 'class="phonetic"[^>]*>([^<]+)<', &phonetic) {
        result .= "音标: " phonetic[1] "`n"
    }

    ; 提取基本释义
    if RegExMatch(html, 'class="pos"[^>]*>([^<]+)<', &pos) {
        result .= pos[1] " "
    }
    if RegExMatch(html, 'class="def"[^>]*>([^<]+)<', &def) {
        result .= def[1] "`n"
    }

    ; 提取更多释义
    pos := 1
    count := 0
    while (count < 5 && RegExMatch(html, 'class="se_l_dict"[^>]*>([^<]+)<', &meaning, pos)) {
        result .= "• " meaning[1] "`n"
        pos += meaning.Pos[0] + meaning.Len[0]
        count++
    }

    ; 提取例句
    if RegExMatch(html, 'class="的例子例句"[^>]*>([^<]+)<', &example) {
        result .= "`n例句: " example[1]
    }

    return result
}

; === 有道翻译 API ===
YouDaoFanyi(word) {
    try {
        ; 有道翻译 API（免费版）
        url := "https://dict.youdao.com/jsonapi_s?doctype=json&jsonversion=4&le=en&q=" UriEncode(word)
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.Open("GET", url, false)
        http.SetRequestHeader("User-Agent", "Mozilla/5.0")
        http.Send()

        if (http.Status = 200) {
            response := http.ResponseText
            return ParseYouDaoResponse(response, word)
        }
    }

    ; 备用：抓取网页
    try {
        url := "https://dict.youdao.com/w?le=en&q=" UriEncode(word)
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.Open("GET", url, false)
        http.SetRequestHeader("User-Agent", "Mozilla/5.0")
        http.Send()

        if (http.Status = 200) {
            html := http.ResponseText
            return ParseYouDaoHtml(html, word)
        }
    }

    return ""
}

; === 解析有道 API 响应 ===
ParseYouDaoResponse(response, word) {
    result := word "`n`n"

    ; 提取基本翻译
    if RegExMatch(response, 'translation.*?\[.*?\]', &transMatch) {
        translations := transMatch[0]
        pos := 1
        while RegExMatch(translations, '"([^"]+)"', &match, pos) {
            result .= match[1] "`n"
            pos += match.Pos[0] + match.Len[0]
        }
    }

    ; 提取音标
    if RegExMatch(response, 'us-phonetic.*?"([^"]+)"', &phonetic) {
        result .= "`n美式: [" phonetic[1] "]"
    }
    if RegExMatch(response, 'uk-phonetic.*?"([^"]+)"', &phonetic) {
        result .= " 英式: [" phonetic[1] "]"
    }

    ; 提取词性
    if RegExMatch(response, 'pos.*?"([^"]+)"', &pos) {
        result .= "`n`n" pos[1] " "
    }
    if RegExMatch(response, 'definition.*?\[([^\]]+)\]', &def) {
        definitions := def[1]
        pos := 1
        while RegExMatch(definitions, '"([^"]+)"', &match, pos) {
            result .= match[1] "; "
            pos += match.Pos[0] + match.Len[0]
        }
    }

    ; 提取例句
    if RegExMatch(response, 'eng-sent.*?sentence.*?sentence.*?"([^"]+)"', &engSent) {
        result .= "`n`n例句: " engSent[1]
    }
    if RegExMatch(response, 'chn-sent.*?sentence.*?sentence.*?"([^"]+)"', &chnSent) {
        result .= "`n翻译: " chnSent[1]
    }

    return result
}

; === 解析有道网页 ===
ParseYouDaoHtml(html, word) {
    result := word "`n`n"

    ; 提取音标：class="phonetic"
    phoneticPattern := 'class="phonetic"[^>]*>(.*?)</span>'
    phoneticCount := 0
    Loop Parse, html, "`n", "`r" {
        if RegExMatch(A_LoopField, phoneticPattern, &phoneticMatch) {
            phoneticCount++
            result .= phoneticMatch[1] . " "
            if (phoneticCount >= 2) {
                result := SubStr(result, 1, -1) . "`n"
                break
            }
        }
    }

    ; 提取词性：class="pos"
    posPattern := 'class="pos"[^>]*>(.*?)</span>'
    posArr := []
    Loop Parse, html, "`n", "`r" {
        if RegExMatch(A_LoopField, posPattern, &posMatch) {
            posArr.Push(posMatch[1])
        }
    }

    ; 提取释义：class="trans"
    transPattern := 'class="trans"[^>]*>(.*?)</span>'
    transArr := []
    Loop Parse, html, "`n", "`r" {
        if RegExMatch(A_LoopField, transPattern, &transMatch) {
            cleanTrans := RegExReplace(transMatch[1], "<[^>]+>", "")
            transArr.Push(cleanTrans)
        }
    }

    ; 合并输出词性和释义
    Loop Min(posArr.Length, transArr.Length) {
        result .= posArr[A_Index] . " " . transArr[A_Index] . "`n"
    }

    ; 提取例句
    sentPattern := 'class="example"[^>]*>.*?<p[^>]*>(.*?)</p>.*?<p[^>]*>(.*?)</p>'
    sentCount := 0
    Loop Parse, html, "`n", "`r" {
        if RegExMatch(A_LoopField, sentPattern, &sentMatch) {
            sentCount++
            if (sentCount > 3)
                break
            enSent := RegExReplace(sentMatch[1], "<[^>]+>", "")
            cnSent := RegExReplace(sentMatch[2], "<[^>]+>", "")
            result .= "`n例句: " enSent
            if (cnSent != "")
                result .= "`n翻译: " cnSent
        }
    }

    return result
}

; === 百度翻译 API ===
BaiduFanyi(word) {
    try {
        ; 百度翻译 API（需要 APPID）
        appid := Rim.config.GetConfig("baidu_fanyi_appid", "")
        secret := Rim.config.GetConfig("baidu_fanyi_secret", "")

        if (appid = "" || secret = "") {
            ; 未配置 API，使用网页版
            url := "https://fanyi.baidu.com/#en/zh/" UriEncode(word)
            Run url
            return
        }

        ; 生成签名
        salt := Random(10000, 99999)
        signStr := appid . word . salt . secret
        sign := MD5.Hash(signStr)

        ; 调用 API
        url := "https://fanyi-api.baidu.com/api/trans/vip/translate"
        url .= "?q=" UriEncode(word)
        url .= "&from=en&to=zh"
        url .= "&appid=" appid
        url .= "&salt=" salt
        url .= "&sign=" sign

        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.Open("GET", url, false)
        http.SetRequestHeader("User-Agent", "Mozilla/5.0")
        http.Send()

        if (http.Status = 200) {
            response := http.ResponseText
            ; 解析 JSON
            result := BaiduFanyi_ParseResponse(response, word)
            if (result != "") {
                DisplayResult("百度翻译 - " word "`n`n" result)
            }
        }
    } catch as e {
        DisplayResult("翻译失败: " e.Message)
    }
}

BaiduFanyi_ParseResponse(response, word) {
    result := word "`n`n"

    try {
        ; 尝试使用 JSON 解析
        json := JSON.Load(response)
        if (Type(json) = "Map") {
            ; 检查错误
            if json.Has("error_code") {
                return "错误: " json["error_msg"]
            }

            ; 提取翻译结果
            if json.Has("trans_result") {
                transResults := json["trans_result"]
                if (Type(transResults) = "Array") {
                    for item in transResults {
                        if (Type(item) = "Map") {
                            if item.Has("dst") {
                                result .= item["dst"] "`n"
                            }
                        }
                    }
                }
            }
            return result
        }
    }

    ; 回退到正则解析
    if RegExMatch(response, 'trans_result.*?dst.*?"([^"]+)"', &match) {
        result .= match[1]
        return result
    }

    return ""
}

MD5Hash(str) {
    ; 使用 Windows 内置的 certutil 计算 MD5
    ; 旧实现读的是输入文件而非 certutil 输出 (恒返回 ""), 且 certutil 输出大写 hex, 正则须 (?i)
    tempFile := A_Temp "\md5_temp.txt"
    outFile := A_Temp "\md5_out.txt"
    try FileDelete(tempFile)
    try FileDelete(outFile)
    result := ""
    try {
        FileAppend(str, tempFile, "UTF-8-RAW")
        RunWait(A_ComSpec ' /C certutil -hashfile "' tempFile '" MD5 > "' outFile '"', , "Hide")
        for _mline in ReadFileLines(outFile) {
            line := Trim(_mline)
            if (StrLen(line) = 32 && RegExMatch(line, "(?i)^[a-f0-9]+$")) {
                result := line
                break
            }
        }
    } catch {
    }
    try FileDelete(tempFile)
    try FileDelete(outFile)
    return result
}

; === 计算器 (原版: 结果进剪切板 + 实时执行) ===
CalcExpression() {
    input := MiscPipeInput("输入表达式:`n支持: +, -, *, /, ^, %, (), sin, cos, tan, sqrt, abs, log, ln, pi, e", "计算器")
    if (input = "")
        return

    result := EvalExpression(input)
    if (result != "" && !InStr(result, "错误")) {
        A_Clipboard := result
        DisplayResult(input " = " result)
        TurnOnRealtimeExec()
    } else {
        DisplayResult(input " = " result)
    }
}

EvalExpression(input) {
    ; 薄包装: 表达式引擎见 Lib/MonsterEval.ahk (原 RunZ Eval.ahk 忠实移植 + 阶乘/排列组合)
    try {
        if (Trim(input) = "")
            return ""
        return String(MonsterEval(input))
    } catch as e {
        return "错误: " e.Message
    }
}

; === 剪切板工具 (结果进显示区, 对齐原版 Clip) ===
Misc_ShowClipboard() {
    clipText := A_Clipboard
    ActivateRunZ()
    if (clipText = "")
        DisplayResult("剪切板为空")
    else
        DisplayResult("长度: " StrLen(clipText) "`n" clipText)
}

ClearClipboard() {
    A_Clipboard := ""
    Log("剪切板已清空")
}

SaveClipboard() {
    if (A_Clipboard = "") {
        DisplayResult("剪切板为空")
        return
    }

    filePath := FileSelect("S16", , "保存剪切板", "文本文件 (*.txt)")
    if (filePath != "") {
        try {
            f := FileOpen(filePath, "w")
            f.Write(A_Clipboard)
            f.Close()
            DisplayResult("已保存到: " filePath)
        } catch as e {
            DisplayResult("保存失败: " e.Message)
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

; === 辅助函数 (UTF-8 多字节正确编码, 供搜索/翻译/QR共用) ===
UriEncode(str) {
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

; === IP 显示 (原版: A_IPAddress1-4 经 DisplayResult; 另附 WMI 网卡明细) ===
ShowIp() {
    result := A_IPAddress1
        . "`r`n" . A_IPAddress2
        . "`r`n" . A_IPAddress3
        . "`r`n" . A_IPAddress4

    ; WMI 网卡明细 (多网卡时更全)
    try {
        for obj in ComObjGet("winmgmts:").ExecQuery("SELECT Description, IPAddress FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled = TRUE") {
            result .= "`n`n" obj.Description "`n"
            if IsObject(obj.IPAddress) {
                for ip in obj.IPAddress {
                    result .= "  " ip "`n"
                }
            }
        }
    } catch as e {
        result .= "`n`n获取网卡明细失败: " e.Message
    }

    DisplayResult(result)
}

; === 汇率查询 (原版: CurrencyRate USD CNY amount 三段式 + CNY2USD/USD2CNY 单发) ===
CurrencyRate() {
    input := MiscPipeInput("使用示例：`nCurrencyRate USD CNY 2", "汇率查询")
    if (input = "")
        return
    args := StrSplit(RegExReplace(Trim(input), "\s+", " "), " ")
    if (args.Length = 3) {
        DisplayResult("查询中，可能会比较慢或者查询失败，请稍后...")
        DisplayResult(QueryCurrencyRate(args[1], args[2], args[3]))
    } else if (args.Length >= 1 && RegExMatch(args[1], "^([A-Z]{3})/([A-Z]{3})$", &match)) {
        amount := args.Length >= 2 ? args[2] : 1
        DisplayResult("查询中，可能会比较慢或者查询失败，请稍后...")
        DisplayResult(QueryCurrencyRate(match[1], match[2], amount))
    } else {
        DisplayResult("使用示例：`nCurrencyRate USD CNY 2")
    }
}

CNY2USD() {
    amount := MiscPipeInput("输入人民币金额:", "人民币转美元")
    if (amount = "")
        return
    DisplayResult("查询中，可能会比较慢或者查询失败，请稍后...")
    DisplayResult(QueryCurrencyRate("CNY", "USD", amount))
}

USD2CNY() {
    amount := MiscPipeInput("输入美元金额:", "美元转人民币")
    if (amount = "")
        return
    DisplayResult("查询中，可能会比较慢或者查询失败，请稍后...")
    DisplayResult(QueryCurrencyRate("USD", "CNY", amount))
}

; 原版 QueryCurrencyRate 等价实现 (百度 apistore 已下线, 走 finance 汇率接口; 返回展示字符串)
QueryCurrencyRate(fromCurrency, toCurrency, amount := 1) {
    fromCurrency := Trim(fromCurrency)
    toCurrency := Trim(toCurrency)
    if (fromCurrency = "" || toCurrency = "")
        return "使用示例：`nCurrencyRate USD CNY 2"
    if (amount = "" || !IsNumber(amount))
        amount := 1
    url := "https://finance.baidu.com/api/ExchangeRate/getrate?from=" fromCurrency "&to=" toCurrency
    jsonText := UrlDownloadToString(url)
    if (jsonText = "")
        return "查询失败：无法获取汇率数据"
    rate := ""
    try {
        data := JSON.Load(jsonText)
        if (Type(data) = "Map") {
            if data.Has("data") {
                d := data["data"]
                if (Type(d) = "Map")
                    rate := String(d.Get("rate", d.Get("close", "")))
                else if (Type(d) = "Array" && d.Length >= 1 && Type(d[1]) = "Map")
                    rate := String(d[1].Get("rate", d[1].Get("close", "")))
            }
            if (rate = "")
                rate := String(data.Get("rate", ""))
        }
    } catch {
    }
    if (rate = "" && RegExMatch(jsonText, 'rate.*?"([\d.]+)"', &rateMatch))
        rate := rateMatch[1]
    if (rate = "" || !IsNumber(rate))
        return "查询失败，错误信息：`n`n" jsonText
    result := fromCurrency " 兑换 " toCurrency " 当前汇率：`n`n" rate "`n`n`n"
    result .= amount " " fromCurrency " = " Round(amount * rate, 4) " " toCurrency
    return result
}

QueryAndShowRate(pair, amount := "") {
    if RegExMatch(pair, "^([A-Z]{3})/([A-Z]{3})$", &match) {
        DisplayResult(QueryCurrencyRate(match[1], match[2], amount = "" ? 1 : amount))
    } else {
        DisplayResult("格式错误，请使用 XXX/YYY 格式")
    }
}

; === 万年历 (原版: 百度万年历) ===
Calendar() {
    Run "http://www.baidu.com/baidu?wd=%CD%F2%C4%EA%C0%FA"
    ; 备用: https://wannianrili.bmcx.com/
}

; === URL 编码/解码 (原版: Arg > 剪切板, 结果进剪切板 + DisplayResult) ===
UrlEncodeCmd() {
    input := MiscPipeInput("输入要编码的文本:", "URL编码")
    if (input = "")
        return

    encoded := UriEncode(input)
    A_Clipboard := encoded
    DisplayResult(encoded)
}

UrlDecodeCmd() {
    input := MiscPipeInput("输入要解码的URL:", "URL解码")
    if (input = "")
        return

    decoded := UriDecode(input)
    A_Clipboard := decoded
    DisplayResult(decoded)
}

UriDecode(str) {
    result := ""
    i := 1
    while (i <= StrLen(str)) {
        char := SubStr(str, i, 1)
        if (char = "%" && i + 2 <= StrLen(str)) {
            hex := SubStr(str, i + 1, 2)
            result .= Chr(Integer("0x" hex))
            i += 3
        } else if (char = "+") {
            result .= " "
            i++
        } else {
            result .= char
            i++
        }
    }
    return result
}

; === RunClipboard (结果/错误进显示区, 不弹新窗) ===
RunClipboard() {
    if (A_Clipboard != "") {
        try {
            Run A_Clipboard
        } catch as e {
            DisplayResult("无法运行: " A_Clipboard "`n" e.Message)
        }
    } else {
        DisplayResult("剪切板为空")
    }
}

; === 显示帮助 ===
ShowHelp() {
    helpText := "Rim 快捷键帮助`n`n"
    helpText .= "通用:`n"
    helpText .= "  i        - 进入 insert 模式`n"
    helpText .= "  Esc      - 返回 normal 模式`n"
    helpText .= "  j/k/h/l  - 下/上/左/右移动`n"
    helpText .= "  t        - 新建标签页`n"
    helpText .= "  x        - 关闭标签页`n"
    helpText .= "  gn/gp    - 下/上一个标签页`n"
    helpText .= "  g1-g9    - 切换到标签页 1-9`n"
    helpText .= "  zj/zk    - 移动窗口下/上`n"
    helpText .= "  zh/zl    - 移动窗口左/右`n"
    helpText .= "  zm/zn    - 最大化/最小化窗口`n"
    helpText .= "  za       - 窗口置顶`n"
    helpText .= "`n"
    helpText .= "快速启动:`n"
    helpText .= "  Win+J    - 打开快速启动器`n"
    helpText .= "`n"
    helpText .= "右键托盘图标查看更多选项"

    MsgBox helpText, "Rim 帮助"
}

; === HTML 清理函数 ===
BingFanyi_StripHtml(html) {
    ; 第一遍：去掉完整标签
    t := RegExReplace(html, "<[^>]+>", " ")
    ; 去掉残留的 class/id 等属性
    t := RegExReplace(t, '\w+="[^"]*"', "")
    ; 去掉残留的 >
    t := RegExReplace(t, ">", "")
    ; HTML 实体
    t := RegExReplace(t, "&nbsp;", " ")
    t := RegExReplace(t, "&#\d+;", " ")
    t := RegExReplace(t, "&\w+;", "")
    t := RegExReplace(t, "\s{2,}", " ")
    return RegExReplace(t, "^\s+|\s+$", "")
}

; === 语言检测 ===
IsEnglish(text) {
    pattern := "^[A-Za-z]+$"
    return RegExMatch(text, pattern)
}

; === 必应翻译完整解析 (9维度) ===
BingFanyiFull(word) {
    try {
        url := "https://cn.bing.com/dict/search?q=" UriEncode(word)
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.Open("GET", url, false)
        http.SetRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
        http.Send()
        
        if (http.Status != 200)
            return ""
        
        raw := http.ResponseText
        result := word "`n`n"

        ; === 1. 音标 (meta description) ===
        metaIdx := InStr(raw, 'name="description"')
        if (metaIdx > 0) {
            ci := InStr(raw, 'content="', false, metaIdx)
            if (ci > 0) {
                ci += 9
                ei := InStr(raw, '"', false, ci)
                if (ei > ci) {
                    desc := SubStr(raw, ci, ei - ci)
                    ; 美式音标
                    usI := InStr(desc, Chr(32654) . "[")
                    if (usI > 0) {
                        ue := InStr(desc, "]", false, usI)
                        if (ue > usI)
                            result .= Chr(32654) . " [" . SubStr(desc, usI + 2, ue - usI - 2) . "] "
                    }
                    ; 英式音标
                    ukI := InStr(desc, Chr(33521) . "[")
                    if (ukI > 0) {
                        ue := InStr(desc, "]", false, ukI)
                        if (ue > ukI)
                            result .= Chr(33521) . " [" . SubStr(desc, ukI + 2, ue - ukI - 2) . "]`n"
                    }
                }
            }
        }

        ; === 2. 词形变化 (hd_if) ===
        hdIfIdx := InStr(raw, 'id="hd_if"')
        if (hdIfIdx > 0) {
            hdIfEnd := InStr(raw, "</div>", false, hdIfIdx)
            if (hdIfEnd > hdIfIdx) {
                hdHtml := SubStr(raw, hdIfIdx, hdIfEnd - hdIfIdx)
                hdText := BingFanyi_StripHtml(hdHtml)
                if (hdText != "")
                    result .= "[词形] " . hdText . "`n"
            }
        }

        ; === 3. 基本释义 (qdef li) ===
        Loop 2 {
            searchTag := (A_Index = 1) ? ">v.<" : ">n.<"
            posTag := (A_Index = 1) ? "v." : "n."
            searchStart := 1
            Loop {
                liOpen := InStr(raw, "<li", false, searchStart)
                if (liOpen = 0)
                    break
                liClose := InStr(raw, "</li>", false, liOpen)
                if (liClose = 0)
                    break
                liHtml := SubStr(raw, liOpen, liClose - liOpen)
                searchStart := liClose

                if (InStr(liHtml, searchTag)) {
                    defStart := InStr(liHtml, 'class="def b_regtxt"')
                    if (defStart = 0)
                        defStart := InStr(liHtml, 'class="def"')
                    if (defStart > 0) {
                        defText := SubStr(liHtml, defStart)
                        defText := BingFanyi_StripHtml(defText)
                        defText := RegExReplace(defText, "；\s*$", "")
                        defText := RegExReplace(defText, "^\s+", "")
                        if (defText != "")
                            result .= posTag . " " . defText . "`n"
                    }
                    break
                }
            }
        }

        ; === 4. 搭配 (colid) ===
        colIdx := InStr(raw, 'id="colid"')
        if (colIdx > 0) {
            colEndSearch := InStr(raw, 'id="synoid"')
            if (colEndSearch = 0)
                colEndSearch := colIdx + 20000
            colHtml := SubStr(raw, colIdx, Min(colEndSearch - colIdx, 20000))

            if (InStr(colHtml, 'class="df_div2"')) {
                result .= "[搭配]`n"
                searchStart := 1
                Loop {
                    tIdx := InStr(colHtml, 'class="de_title2"', false, searchStart)
                    if (tIdx = 0)
                        break
                    tEnd := InStr(colHtml, "</div>", false, tIdx)
                    if (tEnd = 0)
                        break
                    titleText := BingFanyi_StripHtml(SubStr(colHtml, tIdx + 17, tEnd - tIdx - 17))

                    cIdx := InStr(colHtml, 'class="col_fl"', false, tEnd)
                    if (cIdx > 0 && cIdx < tEnd + 500) {
                        cEnd := InStr(colHtml, "</div>", false, cIdx)
                        if (cEnd > cIdx) {
                            colText := BingFanyi_StripHtml(SubStr(colHtml, cIdx + 14, cEnd - cIdx - 14))
                            colText := RegExReplace(colText, ",\s*$", "")
                            result .= "  " . titleText . ": " . colText . "`n"
                            searchStart := cEnd
                            continue
                        }
                    }
                    result .= "  " . titleText . "`n"
                    searchStart := tEnd
                }
            }
        }

        ; === 5. 同义词 (synoid) ===
        synoIdx := InStr(raw, 'id="synoid"')
        if (synoIdx > 0) {
            synoHtml := SubStr(raw, synoIdx, Min(20000, StrLen(raw) - synoIdx))
            if (InStr(synoHtml, 'class="df_div2"')) {
                result .= "[同义词]`n"
                searchStart := 1
                Loop {
                    tIdx := InStr(synoHtml, 'class="de_title1"', false, searchStart)
                    if (tIdx = 0)
                        break
                    tEnd := InStr(synoHtml, "</div>", false, tIdx)
                    if (tEnd = 0)
                        break
                    titleText := BingFanyi_StripHtml(SubStr(synoHtml, tIdx + 17, tEnd - tIdx - 17))

                    cIdx := InStr(synoHtml, 'class="col_fl"', false, tEnd)
                    if (cIdx > 0 && cIdx < tEnd + 500) {
                        cEnd := InStr(synoHtml, "</div>", false, cIdx)
                        if (cEnd > cIdx) {
                            colText := BingFanyi_StripHtml(SubStr(synoHtml, cIdx + 14, cEnd - cIdx - 14))
                            colText := RegExReplace(colText, ",\s*$", "")
                            result .= "  " . titleText . ": " . colText . "`n"
                            searchStart := cEnd
                            continue
                        }
                    }
                    result .= "  " . titleText . "`n"
                    searchStart := tEnd
                }
            }
        }

        ; === 6. 双解释义 (authid) ===
        authIdx := InStr(raw, 'id="authid"')
        if (authIdx > 0) {
            authHtml := SubStr(raw, authIdx, Min(50000, StrLen(raw) - authIdx))
            if (InStr(authHtml, 'class="def_pa"')) {
                result .= "[双解]`n"
                searchStart := 1
                Loop {
                    paIdx := InStr(authHtml, 'class="def_pa"', false, searchStart)
                    if (paIdx = 0)
                        break
                    paEnd := InStr(authHtml, "</div>", false, paIdx)
                    if (paEnd = 0)
                        break
                    paHtml := SubStr(authHtml, paIdx, paEnd - paIdx + 6)
                    paText := BingFanyi_StripHtml(paHtml)
                    paText := RegExReplace(paText, "\s+", " ")
                    if (paText != "")
                        result .= "  " . paText . "`n"
                    searchStart := paEnd
                }

                ; 习语
                idmIdx := InStr(authHtml, 'class="idm_s"')
                if (idmIdx > 0) {
                    idsIdx := InStr(authHtml, 'class="ids"', false, idmIdx)
                    if (idsIdx = 0)
                        idsIdx := InStr(authHtml, 'class="ids "', false, idmIdx)
                    if (idsIdx > 0) {
                        idsEnd := InStr(authHtml, "</span>", false, idsIdx)
                        if (idsEnd > idsIdx) {
                            idmText := BingFanyi_StripHtml(SubStr(authHtml, idsIdx, idsEnd - idsIdx + 7))
                            result .= "  [习语] " . idmText . "`n"
                        }
                    }
                }
            }
        }

        ; === 7. 英英释义 (homoid) ===
        homoIdx := InStr(raw, 'id="homoid"')
        if (homoIdx > 0) {
            homoHtml := SubStr(raw, homoIdx, Min(20000, StrLen(raw) - homoIdx))
            if (InStr(homoHtml, 'class="df_cr_w"')) {
                result .= "[英英]`n"
                searchStart := 1
                Loop {
                    posIdx := InStr(homoHtml, 'class="pos pos1"', false, searchStart)
                    if (posIdx = 0)
                        break
                    posEnd := InStr(homoHtml, "</div>", false, posIdx)
                    if (posEnd = 0)
                        break
                    posText := BingFanyi_StripHtml(SubStr(homoHtml, posIdx + 15, posEnd - posIdx - 15))

                    dfIdx := InStr(homoHtml, 'class="df_cr_w"', false, posEnd)
                    if (dfIdx = 0 || dfIdx > posEnd + 500) {
                        searchStart := posEnd
                        continue
                    }
                    dfEnd := InStr(homoHtml, "</div>", false, dfIdx)
                    if (dfEnd = 0)
                        break
                    dfText := BingFanyi_StripHtml(SubStr(homoHtml, dfIdx + 15, dfEnd - dfIdx - 15))
                    if (posText != "" && dfText != "")
                        result .= "  " . posText . " " . dfText . "`n"
                    searchStart := dfEnd
                }
            }
        }

        ; === 8. 网络释义 (webid) ===
        webIdx := InStr(raw, 'id="webid"')
        if (webIdx > 0) {
            webHtml := SubStr(raw, webIdx, Min(20000, StrLen(raw) - webIdx))
            if (InStr(webHtml, 'class="df_hm_w1"')) {
                result .= "[网络释义]`n"
                searchStart := 1
                Loop {
                    wIdx := InStr(webHtml, 'class="df_hm_w1"', false, searchStart)
                    if (wIdx = 0)
                        break
                    wEnd := InStr(webHtml, "</div>", false, wIdx)
                    if (wEnd = 0)
                        break
                    wText := BingFanyi_StripHtml(SubStr(webHtml, wIdx, wEnd - wIdx + 6))
                    if (wText != "")
                        result .= "  " . wText . "`n"
                    searchStart := wEnd
                }
            }
        }

        ; === 9. 例句 (sentenceSeg) ===
        senIdx := InStr(raw, 'id="sentenceSeg"')
        if (senIdx > 0) {
            senHtml := SubStr(raw, senIdx, Min(50000, StrLen(raw) - senIdx))
            sentCount := 0
            result .= "[例句]`n"
            searchStart := 1
            Loop {
                liIdx := InStr(senHtml, 'class="se_li"', false, searchStart)
                if (liIdx = 0)
                    break
                nextLi := InStr(senHtml, 'class="se_li"', false, liIdx + 10)
                if (nextLi = 0)
                    nextLi := StrLen(senHtml) + 1
                senBlock := SubStr(senHtml, liIdx, nextLi - liIdx)

                enIdx := InStr(senBlock, 'class="sen_en')
                enText := ""
                if (enIdx > 0) {
                    enEnd := InStr(senBlock, "</div>", false, enIdx)
                    if (enEnd > enIdx)
                        enText := BingFanyi_StripHtml(SubStr(senBlock, enIdx, enEnd - enIdx + 6))
                }

                cnIdx := InStr(senBlock, 'class="sen_cn"')
                cnText := ""
                if (cnIdx > 0) {
                    cnEnd := InStr(senBlock, "</div>", false, cnIdx)
                    if (cnEnd > cnIdx)
                        cnText := BingFanyi_StripHtml(SubStr(senBlock, cnIdx, cnEnd - cnIdx + 6))
                }

                if (enText != "") {
                    sentCount++
                    if (sentCount > 5)
                        break
                    result .= "  " . sentCount . ". " . enText . "`n"
                    if (cnText != "")
                        result .= "     " . cnText . "`n"
                }
                searchStart := nextLi
            }
        }

        return result
    } catch as e {
        return "翻译失败: " e.Message
    }
}
