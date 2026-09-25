#Requires AutoHotkey v2.0
#Warn All, Off

; === Misc Plugin - 杂项工具 ===
; 移植自 RunZ 的 Misc 插件（翻译/计算器/搜索引擎）
; 子模块: Misc.Search / Misc.Clip / Misc.Net / Misc.Codec (纯实现); 注册聚合仅此一处

#Include Misc.Search.ahk
#Include Misc.Clip.ahk
#Include Misc.Net.ahk
#Include Misc.Codec.ahk

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
    ; 注: RunClipboard 由 LauncherCore 提供(g_Arg 感知), 此处不重复注册避免同名
}

; 管道输入: g_Arg > 剪切板 > InputBox
MiscPipeInput(prompt, title) {
    global g_Arg
    if (Trim(g_Arg) != "")
        return Trim(g_Arg)
    clip := Trim(A_Clipboard)
    if (clip != "")
        return clip
    return InputBox(prompt, title).Value
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

