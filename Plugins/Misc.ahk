#Requires AutoHotkey v2.0
#Warn All, Off

; === Misc Plugin - 杂项工具 ===
; 移植自 RunZ 的 Misc 插件（翻译/计算器/搜索引擎）

RegisterPlugin_Misc() {
    ; 搜索引擎
    RegisterCommand("Google", "url", "https://www.google.com/search?q={query}", T("cmd.Misc.Google"))
    RegisterCommand("Baidu", "url", "https://www.baidu.com/s?wd={query}", T("cmd.Misc.Baidu"))
    RegisterCommand("Bing", "url", "https://www.bing.com/search?q={query}", T("cmd.Misc.Bing"))
    RegisterCommand("GitHub", "url", "https://github.com/search?q={query}", T("cmd.Misc.GitHub"))
    RegisterCommand("Npm", "url", "https://www.npmjs.com/search?q={query}", T("cmd.Misc.Npm"))
    RegisterCommand("Zhihu", "url", "https://www.zhihu.com/search?q={query}", T("cmd.Misc.Zhihu"))
    RegisterCommand("Bilibili", "url", "https://search.bilibili.com/all?keyword={query}", T("cmd.Misc.Bilibili"))
    RegisterCommand("Taobao", "url", "https://s.taobao.com/search?q={query}", T("cmd.Misc.Taobao"))
    RegisterCommand("JD", "url", "https://search.jd.com/Search?keyword={query}", T("cmd.Misc.JD"))

    ; 翻译
    RegisterCommand("Translate", "function", "TranslateWord", T("cmd.Misc.Translate"))
    RegisterCommand("En2Cn", "function", "EnToCn", T("cmd.Misc.En2Cn"))
    RegisterCommand("Cn2En", "function", "CnToEn", T("cmd.Misc.Cn2En"))

    ; 计算器
    RegisterCommand("Calc", "function", "CalcExpression", T("cmd.Misc.Calc"))
    RegisterCommand("Eval", "function", "EvalExpression", T("cmd.Misc.Eval"))

    ; 剪切板工具
    RegisterCommand("ClipShow", "function", "Misc_ShowClipboard", T("cmd.Misc.ClipShow"))
    RegisterCommand("ClipClear", "function", "ClearClipboard", T("cmd.Misc.ClipClear"))
    RegisterCommand("ClipSave", "function", "SaveClipboard", T("cmd.Misc.ClipSave"))

    ; 日期时间
    RegisterCommand("Date", "function", "InsertDate", T("cmd.Misc.Date"))
    RegisterCommand("Time", "function", "InsertTime", T("cmd.Misc.Time"))
    RegisterCommand("DateTime", "function", "InsertDateTime", T("cmd.Misc.DateTime"))

    ; 颜色工具
    RegisterCommand("ColorPicker", "function", "PickColor", T("cmd.Misc.ColorPicker"))
    RegisterCommand("ColorInfo", "function", "PickColor", T("cmd.Misc.ColorInfo"))

    ; 原版别名 (SearchOn*/Dictionary/CNY/USD/IP/日历/URL编解码/运行剪切板)
    RegisterCommand("SearchOnGoogle", "url", "https://www.google.com/search?q={query}", T("cmd.Misc.SearchOnGoogle"))
    RegisterCommand("SearchOnBaidu", "url", "https://www.baidu.com/s?wd={query}", T("cmd.Misc.Baidu"))
    RegisterCommand("SearchOnBing", "url", "https://cn.bing.com/search?q={query}", T("cmd.Misc.SearchOnBing"))
    RegisterCommand("SearchOnZhihu", "url", "https://www.zhihu.com/search?type=content&q={query}", T("cmd.Misc.Zhihu"))
    RegisterCommand("SearchOnNpm", "url", "https://www.npmjs.com/search?q={query}", T("cmd.Misc.Npm"))
    RegisterCommand("SearchOnGithub", "url", "https://github.com/search?q={query}", T("cmd.Misc.GitHub"))
    RegisterCommand("SearchOnBilibili", "url", "https://search.bilibili.com/all?keyword={query}", T("cmd.Misc.Bilibili"))
    RegisterCommand("SearchOnTaobao", "url", "https://s.taobao.com/search?q={query}", T("cmd.Misc.Taobao"))
    RegisterCommand("SearchOnJD", "url", "https://search.jd.com/Search?keyword={query}", T("cmd.Misc.JD"))
    RegisterCommand("Dictionary", "function", "TranslateWord", T("cmd.Misc.Dictionary"))
    RegisterCommand("CNY2USD", "function", "CNY2USD", T("cmd.Misc.CNY2USD"))
    RegisterCommand("USD2CNY", "function", "USD2CNY", T("cmd.Misc.USD2CNY"))
    RegisterCommand("CurrencyRate", "function", "CurrencyRate", T("cmd.Misc.CurrencyRate"))
    RegisterCommand("ShowIp", "function", "ShowIp", T("cmd.Misc.ShowIp"))
    RegisterCommand("Wifi", "function", "WifiShow", T("cmd.Misc.Wifi"))
    RegisterCommand("Dns", "function", "DnsShow", T("cmd.Misc.Dns"))
    RegisterCommand("Ping", "function", "PingShow", T("cmd.Misc.Ping"))
    RegisterCommand("PubIp", "function", "PubIpShow", T("cmd.Misc.PubIp"))
    RegisterCommand("Env", "function", "EnvShow", T("cmd.Misc.Env"))
    RegisterCommand("Calendar", "function", "Calendar", T("cmd.Misc.Calendar"))
    RegisterCommand("UrlEncode", "function", "UrlEncodeCmd", T("cmd.Misc.UrlEncode"))
    RegisterCommand("UrlDecode", "function", "UrlDecodeCmd", T("cmd.Misc.UrlDecode"))
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
    word := MiscPipeInput(T("misc.prompt_translate"), T("misc.title_translate"))
    if (word = "")
        return

    ; 使用必应翻译完整解析 (9维度), 结果进显示区不弹新窗
    result := BingFanyiFull(word)
    if (result != "") {
        DisplayResult(T("misc.translate_title", word) . "`n`n" . result)
    } else {
        ; 失败则打开网页
        url := "https://dict.youdao.com/w?le=en&q=" UriEncode(word)
        Run url
    }
}

EnToCn() {
    word := MiscPipeInput(T("misc.prompt_en"), T("misc.title_en2cn"))
    if (word = "")
        return

    result := BingDictLookup(word, "en-zh")
    if (result != "") {
        DisplayResult(T("misc.en2cn_title", word) . "`n`n" . result)
    } else {
        url := "https://dict.youdao.com/w?le=en&q=" UriEncode(word)
        Run url
    }
}

CnToEn() {
    word := MiscPipeInput(T("misc.prompt_cn"), T("misc.title_cn2en"))
    if (word = "")
        return

    result := BingDictLookup(word, "zh-en")
    if (result != "") {
        DisplayResult(T("misc.cn2en_title", word) . "`n`n" . result)
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
        result .= "`n" . T("misc.label_us", phonetic[1])
    }
    if RegExMatch(response, 'UkPhonetic.*?:.*?"([^"]+)"', &phonetic) {
        result .= " " . T("misc.label_uk", phonetic[1])
    }

    return result
}

; === 解析 Bing 网页 ===
ParseBingHtml(html, word) {
    result := word "`n`n"

    ; 提取音标
    if RegExMatch(html, 'class="phonetic"[^>]*>([^<]+)<', &phonetic) {
        result .= T("misc.label_phonetic", phonetic[1]) . "`n"
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
        result .= "`n" . T("misc.label_example", example[1])
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
        result .= "`n" . T("misc.label_us", phonetic[1])
    }
    if RegExMatch(response, 'uk-phonetic.*?"([^"]+)"', &phonetic) {
        result .= " " . T("misc.label_uk", phonetic[1])
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
        result .= "`n`n" . T("misc.label_example", engSent[1])
    }
    if RegExMatch(response, 'chn-sent.*?sentence.*?sentence.*?"([^"]+)"', &chnSent) {
        result .= "`n" . T("misc.label_trans", chnSent[1])
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
            result .= "`n" . T("misc.label_example", enSent)
            if (cnSent != "")
                result .= "`n" . T("misc.label_trans", cnSent)
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
                DisplayResult(T("misc.baidu_title", word) . "`n`n" . result)
            }
        }
    } catch as e {
        DisplayResult(T("misc.translate_failed", e.Message))
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
    input := MiscPipeInput(T("misc.prompt_calc"), T("misc.title_calc"))
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

; === IP 显示 (升级: 逐网卡卡片 IPv4/掩码/IPv6/网关/DNS/MAC/DHCP, 默认出口标★) ===
ShowIp() {
    nics := []
    try {
        wmi := ComObjGet("winmgmts:")
        q := wmi.ExecQuery("SELECT Description, MACAddress, IPAddress, IPSubnet, DefaultIPGateway, DNSServerSearchOrder, DHCPEnabled, DHCPServer FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled = TRUE")
        for obj in q {
            info := Map("desc", Misc_ComStr(obj, (o) => o.Description)
                , "mac", Misc_ComStr(obj, (o) => o.MACAddress)
                , "ips", Misc_ComArr(obj, (o) => o.IPAddress)
                , "masks", Misc_ComArr(obj, (o) => o.IPSubnet)
                , "gws", Misc_ComArr(obj, (o) => o.DefaultIPGateway)
                , "dns", Misc_ComArr(obj, (o) => o.DNSServerSearchOrder)
                , "dhcp", Misc_ComBool(obj, (o) => o.DHCPEnabled)
                , "dhcpServer", Misc_ComStr(obj, (o) => o.DHCPServer))
            nics.Push(info)
        }
    } catch as e {
        DisplayResult(A_IPAddress1 . "`r`n" . A_IPAddress2 . "`r`n" . A_IPAddress3 . "`r`n" . A_IPAddress4
            . "`n`n" . T("misc.net_failed", e.Message))
        return
    }
    if (nics.Length = 0) {
        DisplayResult(A_IPAddress1 . "`r`n" . A_IPAddress2 . "`r`n" . A_IPAddress3 . "`r`n" . A_IPAddress4
            . "`n`n" . T("misc.ip_none"))
        return
    }

    items := [Map("type", "head", "text", T("misc.ip_title") . " (" . T("misc.ip_nics", nics.Length) . ")")
        , Map("type", "head", "text", "")]
    idx := 0
    for nic in nics {
        tag := Chr(Ord("a") + idx)
        head := "[" tag "] " nic["desc"]
        if (nic["gws"].Length > 0)
            head .= " " . T("misc.ip_default")
        items.Push(Map("type", "head", "text", head))
        v4s := []
        v6s := []
        for i, ip in nic["ips"] {
            mask := (i <= nic["masks"].Length) ? nic["masks"][i] : ""
            if InStr(ip, ":")
                v6s.Push(ip)
            else
                v4s.Push(Map("ip", ip, "mask", mask))
        }
        for v in v4s {
            val := v["ip"] . (v["mask"] != "" ? " / " . v["mask"] : "")
            items.Push(Map("type", "row", "mark", "*", "label", T("misc.ip_ipv4"), "value", val
                , "copy", v["ip"], "tip", T("misc.copied_val", v["ip"])))
        }
        for v in v6s
            items.Push(Map("type", "row", "mark", "*", "label", T("misc.ip_ipv6"), "value", v
                , "copy", v, "tip", T("misc.copied_val", v)))
        if (nic["gws"].Length > 0) {
            gv := Misc_JoinStr(nic["gws"], ", ")
            items.Push(Map("type", "row", "mark", "*", "label", T("misc.ip_gateway"), "value", gv
                , "copy", gv, "tip", T("misc.copied_val", gv)))
        }
        if (nic["dns"].Length > 0) {
            dv := Misc_JoinStr(nic["dns"], ", ")
            items.Push(Map("type", "row", "mark", "*", "label", T("misc.ip_dns"), "value", dv
                , "copy", dv, "tip", T("misc.copied_val", dv)))
        }
        if (nic["mac"] != "")
            items.Push(Map("type", "row", "mark", "*", "label", T("misc.ip_mac"), "value", nic["mac"]
                , "copy", nic["mac"], "tip", T("misc.copied_val", nic["mac"])))
        dhcpTxt := nic["dhcp"] ? T("misc.ip_on") : T("misc.ip_off")
        if (nic["dhcp"] && nic["dhcpServer"] != "")
            dhcpTxt .= " (" . T("misc.ip_server") . " " . nic["dhcpServer"] . ")"
        items.Push(Map("type", "row", "mark", "*", "label", T("misc.ip_dhcp"), "value", dhcpTxt
            , "copy", dhcpTxt, "tip", T("misc.copied_val", dhcpTxt)))
        idx++
    }
    RowNavShow(items)
}

; WMI 标量属性安全读 (null/异常一律回空串)
Misc_ComStr(obj, getter) {
    try {
        v := getter(obj)
        if (v = "")
            return ""
        return String(v)
    } catch {
        return ""
    }
}

; WMI 数组属性安全读 (null/异常一律回空数组)
Misc_ComArr(obj, getter) {
    try {
        v := getter(obj)
    } catch {
        return []
    }
    if !IsObject(v)
        return []
    out := []
    try {
        for item in v {
            try out.Push(String(item))
            catch {
            }
        }
    } catch {
    }
    return out
}

; WMI 布尔属性安全读
Misc_ComBool(obj, getter) {
    try {
        return getter(obj) ? true : false
    } catch {
        return false
    }
}

Misc_JoinStr(arr, sep) {
    out := ""
    for i, v in arr {
        if (i > 1)
            out .= sep
        out .= v
    }
    return out
}

; === WiFi: 已保存密码一览, 当前连接置顶 (netsh, 无线网卡缺失/服务关闭会提示) ===
WifiShow() {
    profiles := Misc_WlanProfiles()
    if (profiles.Length = 0) {
        probe := Misc_RunUtf8("netsh wlan show interfaces")
        if (Misc_WlanNoSvc(probe))
            DisplayResult(T("misc.wifi_nosvc"))
        else
            DisplayResult(T("misc.wifi_none"))
        return
    }
    conn := Misc_WlanConnected()
    myssid := conn.Has("ssid") ? conn["ssid"] : ""
    ordered := []
    if (myssid != "")
        ordered.Push(myssid)
    for p in profiles {
        dup := false
        for q in ordered {
            if (q = p) {
                dup := true
                break
            }
        }
        if (!dup)
            ordered.Push(p)
    }
    admin := A_IsAdmin
    title := T("misc.wifi_title", ordered.Length)
    if (myssid != "")
        title .= " - " . T("misc.wifi_cur", myssid)
    items := [Map("type", "head", "text", title)]
    if (!admin)
        items.Push(Map("type", "head", "text", T("misc.wifi_noadmin")))
    items.Push(Map("type", "head", "text", ""))
    idx := 0
    for ssid in ordered {
        tail := ""
        if (ssid = myssid) {
            mark := "★"
            if (conn.Has("signal") && conn["signal"] != "")
                tail := " | " . T("misc.wifi_signal", conn["signal"])
        } else {
            mark := Chr(Ord("a") + idx)
            idx++
        }
        key := Misc_WlanKey(ssid)
        if (key["open"]) {
            pwdTxt := T("misc.wifi_open")
            cp := ssid
            tip := T("misc.copied_val", ssid)
        } else if (key["pwd"] != "") {
            pwdTxt := T("misc.wifi_pwd", key["pwd"])
            cp := key["pwd"]
            tip := T("misc.copied_pwd", ssid)
        } else {
            pwdTxt := T("misc.wifi_hidden")
            cp := ""
            tip := T("misc.wifi_hidden")
        }
        items.Push(Map("type", "row", "mark", mark, "label", ssid, "value", pwdTxt . tail
            , "copy", cp, "tip", tip))
    }
    RowNavShow(items)
}

; netsh 输出统一按 UTF-8 拿 (chcp 65001, 中文 SSID 不乱码)
Misc_RunUtf8(cmd) {
    tmp := A_Temp "\Rim.Misc.cmd.out.txt"
    full := A_ComSpec ' /C "chcp 65001>nul & ' cmd ' > "' tmp '" 2>nul"'
    try {
        RunWait(full, , "Hide")
        out := FileRead(tmp, "UTF-8")
        if (SubStr(out, 1, 1) = Chr(0xFEFF))
            out := SubStr(out, 2)
    } catch {
        out := ""
    }
    try FileDelete(tmp)
    catch {
    }
    return out
}

; 已保存的 WiFi 配置名 (中/英 netsh 通吃)
Misc_WlanProfiles() {
    out := Misc_RunUtf8("netsh wlan show profiles")
    arr := []
    Loop Parse, out, "`n", "`r" {
        line := Trim(A_LoopField)
        if (line = "" || !InStr(line, ":"))
            continue
        if (InStr(line, "配置文件") || InStr(line, "Profile")) {
            if RegExMatch(line, ":\s*(.+)$", &m) {
                name := Trim(m[1])
                if (name != "")
                    arr.Push(name)
            }
        }
    }
    return arr
}

; 当前连接的 SSID + 信号 (未连接回空 ssid; BSSID 行不会误命中 SSID)
Misc_WlanConnected() {
    res := Map("ssid", "", "signal", "")
    out := Misc_RunUtf8("netsh wlan show interfaces")
    if (Trim(out) = "")
        return res
    block := Map("ssid", "", "state", "", "signal", "")
    Loop Parse, out, "`n", "`r" {
        line := Trim(A_LoopField)
        if (line = "") {
            Misc_WlanPickBlock(block, res)
            block := Map("ssid", "", "state", "", "signal", "")
            continue
        }
        if RegExMatch(line, "(?i)^SSID\s*:\s*(.+)$", &m)
            block["ssid"] := Trim(m[1])
        else if RegExMatch(line, "(?i)^(?:状态|State)\s*:\s*(.+)$", &m)
            block["state"] := Trim(m[1])
        else if RegExMatch(line, "(?i)^(?:信号|Signal)\s*:\s*(.+)$", &m)
            block["signal"] := Trim(m[1])
    }
    Misc_WlanPickBlock(block, res)
    if (res["ssid"] = "") {
        ; Win11 位置权限门: netsh interfaces 常 Access denied, 用 NLM 兜底 (无信号值)
        ; 注: v2 双引号内 "" 不是转义而是闭合+重开, 嵌套引号用 Chr(34) 显式拼接
        q := Chr(34)
        ps := "powershell -NoProfile -ExecutionPolicy Bypass -Command " . q . "Get-NetConnectionProfile | Where-Object { $_.IPv4Connectivity -ne 'NoTraffic' } | Select-Object -First 1 -ExpandProperty Name" . q
        name := Trim(Misc_RunUtf8(ps))
        if (name != "") {
            ; PS 输出 CRLF: Trim 默认不去 \r, 逐行取首个非空行
            for ln in StrSplit(StrReplace(name, "`r", ""), "`n") {
                ln := Trim(ln)
                if (ln != "") {
                    res["ssid"] := ln
                    break
                }
            }
        }
    }
    return res
}

Misc_WlanPickBlock(block, res) {
    if (block["ssid"] = "" || res["ssid"] != "")
        return
    st := block["state"]
    connected := false
    if (st = "")
        connected := true
    else if (InStr(st, "已连接") || RegExMatch(st, "(?i)^connected$"))
        connected := true
    if (connected) {
        res["ssid"] := block["ssid"]
        res["signal"] := block["signal"]
    }
}

; 单个配置的密码 (open=true 为开放网络; 非管理员拿不到 key=clear, pwd 为空)
Misc_WlanKey(ssid) {
    res := Map("pwd", "", "open", false)
    q := StrReplace(ssid, '"', '')
    out := Misc_RunUtf8('netsh wlan show profile name="' q '" key=clear')
    if (Trim(out) = "")
        return res
    Loop Parse, out, "`n", "`r" {
        line := Trim(A_LoopField)
        if RegExMatch(line, "(?i)^(?:安全密钥|Security key)\s*:\s*(.+)$", &m) {
            v := Trim(m[1])
            if (InStr(v, "不存在") || RegExMatch(v, "(?i)absent"))
                res["open"] := true
        } else if RegExMatch(line, "(?i)^(?:关键内容|Key Content)\s*:\s*(.+)$", &m) {
            res["pwd"] := Trim(m[1])
        }
    }
    return res
}

; 无无线网卡 / WLAN 服务不可用 / 非 netsh 环境
Misc_WlanNoSvc(text) {
    if (Trim(text) = "")
        return true
    markers := ["没有无线接口", "无线自动配置服务", "不是内部或外部命令"
        , "no wireless interface", "AutoConfig", "not recognized"]
    for mk in markers {
        if InStr(text, mk, true)
            return true
    }
    return false
}

; === DNS 查询 (nslookup, 类型默认 A, 中英输出通吃) ===
DnsShow() {
    input := MiscPipeInput(T("misc.prompt_dns"), T("misc.title_dns"))
    if (input = "")
        return
    toks := StrSplit(RegExReplace(Trim(input), "\s+", " "), " ")
    domain := toks[1]
    qtype := "A"
    if (toks.Length >= 2) {
        typ := StrUpper(toks[2])
        if (typ = "A" || typ = "AAAA" || typ = "MX" || typ = "TXT" || typ = "CNAME" || typ = "NS")
            qtype := typ
    }
    out := Misc_RunUtf8("nslookup -type=" qtype " " domain)
    if (Misc_DnsFailed(out)) {
        if (InStr(out, "Non-existent domain") || InStr(out, "找不到"))
            DisplayResult(T("misc.dns_notfound", domain))
        else
            DisplayResult(T("misc.dns_failed", domain))
        return
    }
    recs := Misc_DnsParse(out, qtype)
    if (recs.Length = 0) {
        DisplayResult(T("misc.dns_failed", domain))
        return
    }
    items := [Map("type", "head", "text", T("misc.dns_title", domain) . " · " . qtype)
        , Map("type", "head", "text", "")]
    for r in recs
        items.Push(Map("type", "row", "mark", "*", "label", r["label"], "value", r["value"]
            , "copy", r["value"], "tip", T("misc.copied_val", r["value"])))
    RowNavShow(items)
}

Misc_DnsFailed(out) {
    if (Trim(out) = "")
        return true
    markers := ["Non-existent domain", "can't find", "timed out", "No response"
        , "找不到", "超时", "无响应"]
    for mk in markers {
        if InStr(out, mk)
            return true
    }
    return false
}

Misc_DnsParse(out, qtype) {
    ; 记录行自带特征可直认 (MX/CNAME/NS/TXT); 只有裸 Address: 需要 Server 配对门
    ; (A 查询 Server 块在前, MX 应答经常无 Name: 行, 不能设统一门)
    recs := []
    skipNextAddress := false
    lastLabel := qtype
    Loop Parse, out, "`n", "`r" {
        line := Trim(A_LoopField)
        if (line = "")
            continue
        ; Server 自报家门: Server: 行之后紧跟的 Address: 是 DNS 服务器地址, 不是答案
        if RegExMatch(line, "(?i)^Server\s*:") {
            skipNextAddress := true
            continue
        }
        if RegExMatch(line, "(?i)^(?:Addresses|Address)\s*:\s*(.+)$", &m) {
            if (skipNextAddress) {
                skipNextAddress := false
                continue
            }
            v := Trim(m[1])
            lastLabel := InStr(v, ":") ? "AAAA" : "A"
            recs.Push(Map("label", lastLabel, "value", v))
        } else if RegExMatch(line, "(?i)MX preference\s*=\s*(\d+)\s*,\s*mail exchanger\s*=\s*(\S+)", &m) {
            lastLabel := "MX"
            recs.Push(Map("label", "MX", "value", m[1] . " " . m[2]))
        } else if RegExMatch(line, "(?i)mail exchanger\s*=\s*(\S+)", &m) {
            lastLabel := "MX"
            recs.Push(Map("label", "MX", "value", m[1]))
        } else if RegExMatch(line, "(?i)aliases\s*=\s*(\S+)", &m) {
            lastLabel := "CNAME"
            recs.Push(Map("label", "CNAME", "value", m[1]))
        } else if RegExMatch(line, "(?i)nameserver\s*=\s*(\S+)", &m) {
            lastLabel := "NS"
            recs.Push(Map("label", "NS", "value", m[1]))
        } else if RegExMatch(line, "(?i)\btext\s*=\s*(.+)$", &m) {
            lastLabel := "TXT"
            recs.Push(Map("label", "TXT", "value", Trim(m[1])))
        } else if RegExMatch(line, "(?i)^(?:primary name server|responsible mail addr|serial|refresh|retry|expire|default TTL)\s*=") {
            continue
        } else if (SubStr(line, 1, 1) = "(") {
            continue
        } else if (recs.Length > 0 && !RegExMatch(line, "^[^:]{1,40}:\s")) {
            ; Addresses 续行: 缩进裸 IP (IPv6 含冒号但后无空格, 与键行区分)
            v := line
            recs.Push(Map("label", InStr(v, ":") ? "AAAA" : lastLabel, "value", v))
        }
    }
    return recs
}

; === Ping (次数默认 4, 上限 20, 中英输出通吃) ===
PingShow() {
    input := MiscPipeInput(T("misc.prompt_ping"), T("misc.title_ping"))
    if (input = "")
        return
    toks := StrSplit(RegExReplace(Trim(input), "\s+", " "), " ")
    host := toks[1]
    count := 4
    if (toks.Length >= 2 && IsNumber(toks[2]))
        count := Min(Max(Integer(toks[2]), 1), 20)
    DisplayResult(T("misc.net_pinging", host))
    out := Misc_RunUtf8("ping -n " count " " host)
    if (Trim(out) = "" || InStr(out, "could not find host") || InStr(out, "找不到主机")) {
        DisplayResult(T("misc.ping_nohost", host))
        return
    }
    items := [Map("type", "head", "text", T("misc.ping_title", host))
        , Map("type", "head", "text", "")]
    n := 0
    got := false
    Loop Parse, out, "`n", "`r" {
        line := Trim(A_LoopField)
        if (line = "")
            continue
        if InStr(line, "TTL=") {
            n++
            tm := ""
            if RegExMatch(line, "(?:时间|time)\s*[=<]\s*(<?\d+)\s*ms", &m)
                tm := m[1] . "ms"
            ttl := ""
            if RegExMatch(line, "(?i)TTL\s*=\s*(\d+)", &m)
                ttl := " TTL=" . m[1]
            v := Trim(tm . ttl)
            items.Push(Map("type", "row", "mark", "*", "label", "#" . n, "value", v
                , "copy", v, "tip", T("misc.copied_val", v)))
            got := true
        } else if (InStr(line, "超时") || InStr(line, "timed out")
            || InStr(line, "unreachable") || InStr(line, "无法访问")) {
            n++
            items.Push(Map("type", "row", "mark", "*", "label", "#" . n
                , "value", T("misc.ping_timeout"), "copy", "", "tip", T("misc.ping_timeout")))
            got := true
        }
    }
    if (!got) {
        DisplayResult(T("misc.ping_failed", host))
        return
    }
    avg := ""
    if RegExMatch(out, "(?:平均|Average)\s*[=＝]\s*(\d+)\s*ms", &m)
        avg := m[1] . "ms"
    loss := ""
    if RegExMatch(out, "(\d+)\s*%\s*(?:loss|丢失)", &m)
        loss := m[1] . "%"
    else if RegExMatch(out, "(?:丢失|Lost)\s*[=＝]\s*(\d+)", &m)
        loss := m[1]
    if (avg != "")
        items.Push(Map("type", "row", "mark", "*", "label", T("misc.ping_avg"), "value", avg
            , "copy", avg, "tip", T("misc.copied_val", avg)))
    if (loss != "")
        items.Push(Map("type", "row", "mark", "*", "label", T("misc.ping_loss"), "value", loss
            , "copy", loss, "tip", T("misc.copied_val", loss)))
    RowNavShow(items)
}

; === 公网 IP (ip-api 主, ipify 备) ===
PubIpShow() {
    global Arg
    target := Trim(Arg)
    geo := Misc_PubIpGeo(target)
    if (geo.Has("ip")) {
        title := target = "" ? T("misc.pubip_title") : T("misc.pubip_titleq", target)
        items := [Map("type", "head", "text", title), Map("type", "head", "text", "")]
        order := ["ip", "country", "region", "city", "isp"]
        labels := Map("ip", "IP", "country", T("misc.pubip_country"), "region", T("misc.pubip_region")
            , "city", T("misc.pubip_city"), "isp", T("misc.pubip_isp"))
        for k in order {
            if (geo.Has(k) && geo[k] != "")
                items.Push(Map("type", "row", "mark", "*", "label", labels[k], "value", geo[k]
                    , "copy", geo[k], "tip", T("misc.copied_val", geo[k])))
        }
        RowNavShow(items)
        return
    }
    ip := Trim(Misc_HttpGet("https://api.ipify.org"))
    if (ip != "" && RegExMatch(ip, "^[\d\.:a-fA-F]+$")) {
        items := [Map("type", "head", "text", T("misc.pubip_title")), Map("type", "head", "text", "")
            , Map("type", "row", "mark", "*", "label", "IP", "value", ip
                , "copy", ip, "tip", T("misc.copied_val", ip))]
        RowNavShow(items)
        return
    }
    DisplayResult(T("misc.pubip_failed"))
}

Misc_PubIpGeo(ip) {
    url := "http://ip-api.com/json/" . (ip = "" ? "" : ip) . "?fields=status,message,query,country,regionName,city,isp"
    out := Misc_HttpGet(url)
    res := Map()
    if (Trim(out) = "")
        return res
    try {
        data := JSON.Load(out)
    } catch {
        return res
    }
    try {
        if (data["status"] != "success")
            return res
    } catch {
        return res
    }
    for k in ["query", "country", "regionName", "city", "isp"] {
        try {
            v := data[k]
            if (v != "")
                res[k = "query" ? "ip" : (k = "regionName" ? "region" : k)] := String(v)
        } catch {
        }
    }
    return res
}

Misc_HttpGet(url) {
    out := Misc_HttpDirect(url)
    if (Trim(out) != "")
        return out
    ; WinHTTP 不懂 socks 代理: curl.exe 兜底 (Win10 1803+ 自带, 认 env 代理)
    q := Chr(34)
    return Misc_RunUtf8("curl.exe -s -m 15 --proto =http,https " . q . url . q)
}

Misc_HttpDirect(url) {
    try {
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.SetTimeouts(8000, 8000, 8000, 8000)
        http.Open("GET", url, false)
        http.SetRequestHeader("User-Agent", "Mozilla/5.0")
        ; WinHTTP 不读 env 代理 (curl 会): 手动接 HTTPS_PROXY/HTTP_PROXY/ALL_PROXY
        proxy := Misc_HttpProxy()
        if (proxy != "") {
            try http.SetProxy(2, proxy, "")
            catch {
            }
        }
        http.Send()
        return http.ResponseText
    } catch {
        return ""
    }
}

; env 代理转 WinHTTP 格式 (socks5://h:p → socks=h:p; http://h:p → h:p)
Misc_HttpProxy() {
    raw := ""
    for k in ["HTTPS_PROXY", "https_proxy", "HTTP_PROXY", "http_proxy", "ALL_PROXY", "all_proxy"] {
        try {
            v := Trim(EnvGet(k))
            if (v != "") {
                raw := v
                break
            }
        } catch {
        }
    }
    if (raw = "")
        return ""
    addr := RegExReplace(raw, "^\w+://", "")
    addr := RegExReplace(addr, "/.*$", "")
    if (addr = "")
        return ""
    if RegExMatch(raw, "^(socks5?|http)", &m)
        scheme := StrLower(m[1])
    else
        scheme := ""
    if (scheme = "socks" || scheme = "socks5")
        return "socks=" . addr
    return addr
}

; === 环境变量 (空参全表; 单名精确取; 含分号自动拆行; 只读) ===
EnvShow() {
    global Arg
    name := Trim(Arg)
    all := Map()
    names := []
    out := Misc_RunUtf8("set")
    Loop Parse, out, "`n", "`r" {
        line := A_LoopField
        if (line = "")
            continue
        pos := InStr(line, "=")
        if (pos < 2)
            continue
        k := SubStr(line, 1, pos - 1)
        v := SubStr(line, pos + 1)
        all[StrUpper(k)] := Map("name", k, "value", v)
        names.Push(StrUpper(k))
    }
    if (name = "") {
        if (names.Length = 0) {
            DisplayResult(T("misc.env_failed"))
            return
        }
        sorted := Misc_SortLines(names)
        items := [Map("type", "head", "text", T("misc.env_title", sorted.Length))
            , Map("type", "head", "text", "")]
        for uk in sorted {
            e := all[uk]
            items.Push(Misc_EnvRow(e["name"], e["value"]))
        }
        RowNavShow(items)
        return
    }
    uk := StrUpper(name)
    if (!all.Has(uk)) {
        DisplayResult(T("misc.env_notfound", name))
        return
    }
    e := all[uk]
    if InStr(e["value"], ";") {
        parts := StrSplit(e["value"], ";")
        items := [Map("type", "head", "text", T("misc.env_title2", e["name"], parts.Length))
            , Map("type", "head", "text", "")]
        i := 1
        for p in parts {
            p := Trim(p)
            if (p = "")
                continue
            items.Push(Map("type", "row", "mark", String(i), "label", e["name"], "value", p
                , "copy", p, "tip", T("misc.copied_val", p)))
            i++
        }
        RowNavShow(items)
        return
    }
    items := [Map("type", "head", "text", T("misc.env_title2", e["name"], 1))
        , Map("type", "head", "text", "")]
    items.Push(Misc_EnvRow(e["name"], e["value"]))
    RowNavShow(items)
}

Misc_EnvRow(name, val) {
    if (Trim(val) = "")
        return Map("type", "row", "mark", "*", "label", name, "value", T("misc.env_empty")
            , "copy", "", "tip", T("misc.env_empty"))
    return Map("type", "row", "mark", "*", "label", name, "value", val
        , "copy", val, "tip", T("misc.copied_val", val))
}

Misc_SortLines(arr) {
    if (arr.Length < 2)
        return arr
    txt := ""
    for v in arr
        txt .= v . "`n"
    txt := Sort(RTrim(txt, "`n"))
    return StrSplit(txt, "`n")
}

; === 汇率查询 (原版: CurrencyRate USD CNY amount 三段式 + CNY2USD/USD2CNY 单发) ===
CurrencyRate() {
    input := MiscPipeInput(T("misc.fx_hint"), T("misc.title_fx"))
    if (input = "")
        return
    args := StrSplit(RegExReplace(Trim(input), "\s+", " "), " ")
    if (args.Length = 3) {
        DisplayResult(T("misc.querying"))
        DisplayResult(QueryCurrencyRate(args[1], args[2], args[3]))
    } else if (args.Length >= 1 && RegExMatch(args[1], "^([A-Z]{3})/([A-Z]{3})$", &match)) {
        amount := args.Length >= 2 ? args[2] : 1
        DisplayResult(T("misc.querying"))
        DisplayResult(QueryCurrencyRate(match[1], match[2], amount))
    } else {
        DisplayResult(T("misc.fx_hint"))
    }
}

CNY2USD() {
    amount := MiscPipeInput(T("misc.prompt_cny"), T("misc.title_cny2usd"))
    if (amount = "")
        return
    DisplayResult(T("misc.querying"))
    DisplayResult(QueryCurrencyRate("CNY", "USD", amount))
}

USD2CNY() {
    amount := MiscPipeInput(T("misc.prompt_usd"), T("misc.title_usd2cny"))
    if (amount = "")
        return
    DisplayResult(T("misc.querying"))
    DisplayResult(QueryCurrencyRate("USD", "CNY", amount))
}

; 原版 QueryCurrencyRate 等价实现 (百度 apistore 已下线, 走 finance 汇率接口; 返回展示字符串)
QueryCurrencyRate(fromCurrency, toCurrency, amount := 1) {
    fromCurrency := Trim(fromCurrency)
    toCurrency := Trim(toCurrency)
    if (fromCurrency = "" || toCurrency = "")
        return T("misc.fx_hint")
    if (amount = "" || !IsNumber(amount))
        amount := 1
    url := "https://finance.baidu.com/api/ExchangeRate/getrate?from=" fromCurrency "&to=" toCurrency
    jsonText := UrlDownloadToString(url)
    if (jsonText = "")
        return T("misc.fx_nodata")
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
        return T("misc.fx_failed") . "`n`n" . jsonText
    result := T("misc.fx_result", fromCurrency, toCurrency) . "`n`n" . rate . "`n`n`n"
    result .= amount " " fromCurrency " = " Round(amount * rate, 4) " " toCurrency
    return result
}

QueryAndShowRate(pair, amount := "") {
    if RegExMatch(pair, "^([A-Z]{3})/([A-Z]{3})$", &match) {
        DisplayResult(QueryCurrencyRate(match[1], match[2], amount = "" ? 1 : amount))
    } else {
        DisplayResult(T("misc.fx_badformat"))
    }
}

; === 万年历 (原版: 百度万年历) ===
Calendar() {
    Run "http://www.baidu.com/baidu?wd=%CD%F2%C4%EA%C0%FA"
    ; 备用: https://wannianrili.bmcx.com/
}

; === URL 编码/解码 (原版: Arg > 剪切板, 结果进剪切板 + DisplayResult) ===
UrlEncodeCmd() {
    input := MiscPipeInput(T("misc.prompt_urlenc"), T("misc.title_urlenc"))
    if (input = "")
        return

    encoded := UriEncode(input)
    A_Clipboard := encoded
    DisplayResult(encoded)
}

UrlDecodeCmd() {
    input := MiscPipeInput(T("misc.prompt_urldec"), T("misc.title_urldec"))
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
            DisplayResult(T("misc.cannot_run", A_Clipboard) . "`n" . e.Message)
        }
    } else {
        DisplayResult(T("misc.clip_empty"))
    }
}

; === 显示帮助 (双语文本见 Lang/*.ini help.misc) ===
ShowHelp() {
    helpText := T("help.misc")

    MsgBox(helpText, T("misc.help_title"))
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
                        result .= T("misc.dict_us", SubStr(desc, usI + 2, ue - usI - 2)) . " "
                    }
                    ; 英式音标
                    ukI := InStr(desc, Chr(33521) . "[")
                    if (ukI > 0) {
                        ue := InStr(desc, "]", false, ukI)
                        if (ue > ukI)
                            result .= T("misc.dict_uk", SubStr(desc, ukI + 2, ue - ukI - 2)) . "`n"
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
                    result .= T("misc.dict_form", hdText) . "`n"
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
                result .= T("misc.dict_coll") . "`n"
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
                result .= T("misc.dict_syn") . "`n"
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
                result .= T("misc.dict_dual") . "`n"
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
                            result .= "  " . T("misc.dict_idiom", idmText) . "`n"
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
                result .= T("misc.dict_enen") . "`n"
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
                result .= T("misc.dict_web") . "`n"
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
            result .= T("misc.dict_sent") . "`n"
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
        return T("misc.translate_failed", e.Message)
    }
}
