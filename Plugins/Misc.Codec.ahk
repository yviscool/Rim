#Requires AutoHotkey v2.0
#Warn All, Off

; === Misc.Codec - 汇率/万年历/URL编解码/RunClipboard/帮助 (纯实现, 注册见 Misc.ahk) ===

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
        data := JSON.parse(jsonText)
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

; === URL 编码/解码 (原版: g_Arg > 剪切板, 结果进剪切板 + DisplayResult) ===
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

