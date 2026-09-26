#Requires AutoHotkey v2.0
#Warn All, Off

; === Misc Plugin - 杂项工具 (翻译/计算器/搜索引擎) ===
; 子模块: Misc.Search / Misc.Clip / Misc.Net / Misc.Codec (纯实现);
; 全直注: url 行走命令池, 功能行走 RimCommand, 无别名表, 无 legacy 分发

#Include Misc.Search.ahk
#Include Misc.Clip.ahk
#Include Misc.Net.ahk
#Include Misc.Codec.ahk

class MiscPlugin extends RimPlugin {
    static Name => "Misc"
    static Title => "Misc Utilities"
    static Description => "搜索/翻译/计算器/剪贴板/网络诊断"

    static RegisterCommands() {
        RegisterMiscUrls()
        RegisterMiscTools()
    }
}

if (IsSet(RimPluginManager) && IsObject(RimPluginManager))
    RimPluginManager.Register(MiscPlugin)

RegisterMiscUrls() {
    ; 搜索引擎 (url 直注册, 无执行函数)
    RegisterCommand("Google", "url", "https://www.google.com/search?q={query}", T("cmd.Misc.Google"))
    RegisterCommand("Baidu", "url", "https://www.baidu.com/s?wd={query}", T("cmd.Misc.Baidu"))
    RegisterCommand("Bing", "url", "https://www.bing.com/search?q={query}", T("cmd.Misc.Bing"))
    RegisterCommand("GitHub", "url", "https://github.com/search?q={query}", T("cmd.Misc.GitHub"))
    RegisterCommand("Npm", "url", "https://www.npmjs.com/search?q={query}", T("cmd.Misc.Npm"))
    RegisterCommand("Zhihu", "url", "https://www.zhihu.com/search?q={query}", T("cmd.Misc.Zhihu"))
    RegisterCommand("Bilibili", "url", "https://search.bilibili.com/all?keyword={query}", T("cmd.Misc.Bilibili"))
    RegisterCommand("Taobao", "url", "https://s.taobao.com/search?q={query}", T("cmd.Misc.Taobao"))
    RegisterCommand("JD", "url", "https://search.jd.com/Search?keyword={query}", T("cmd.Misc.JD"))
}

RegisterMiscTools() {
    ; 功能命令直注 RimCommand (无别名表; 旧 SearchOn*/Dictionary/CNY 别名已删, 关键词保留可搜)
    RimCommand.Register("Translate", "Translate", MakeLegacyCmd("TranslateWord"), Map("Category", "Tool", "Description", T("cmd.Misc.Translate"), "Keywords", "Translate dictionary"))
    RimCommand.Register("En2Cn", "En2Cn", MakeLegacyCmd("EnToCn"), Map("Category", "Tool", "Description", T("cmd.Misc.En2Cn"), "Keywords", "En2Cn"))
    RimCommand.Register("Cn2En", "Cn2En", MakeLegacyCmd("CnToEn"), Map("Category", "Tool", "Description", T("cmd.Misc.Cn2En"), "Keywords", "Cn2En"))
    RimCommand.Register("Calc", "Calc", MakeLegacyCmd("CalcExpression"), Map("Category", "Tool", "Description", T("cmd.Misc.Calc"), "Keywords", "Calc"))
    RimCommand.Register("Eval", "Eval", MakeLegacyCmd("EvalExpression"), Map("Category", "Tool", "Description", T("cmd.Misc.Eval"), "Keywords", "Eval"))
    RimCommand.Register("ClipShow", "ClipShow", MakeLegacyCmd("Misc_ShowClipboard"), Map("Category", "Tool", "Description", T("cmd.Misc.ClipShow"), "Keywords", "ClipShow"))
    RimCommand.Register("ClipClear", "ClipClear", MakeLegacyCmd("ClearClipboard"), Map("Category", "Tool", "Description", T("cmd.Misc.ClipClear"), "Keywords", "ClipClear"))
    RimCommand.Register("ClipSave", "ClipSave", MakeLegacyCmd("SaveClipboard"), Map("Category", "Tool", "Description", T("cmd.Misc.ClipSave"), "Keywords", "ClipSave"))
    RimCommand.Register("Date", "Date", MakeLegacyCmd("InsertDate"), Map("Category", "Tool", "Description", T("cmd.Misc.Date"), "Keywords", "Date"))
    RimCommand.Register("Time", "Time", MakeLegacyCmd("InsertTime"), Map("Category", "Tool", "Description", T("cmd.Misc.Time"), "Keywords", "Time"))
    RimCommand.Register("DateTime", "DateTime", MakeLegacyCmd("InsertDateTime"), Map("Category", "Tool", "Description", T("cmd.Misc.DateTime"), "Keywords", "DateTime"))
    RimCommand.Register("ColorPicker", "ColorPicker", MakeLegacyCmd("PickColor"), Map("Category", "Tool", "Description", T("cmd.Misc.ColorPicker"), "Keywords", "ColorPicker colorinfo"))
    RimCommand.Register("CNY2USD", "CNY2USD", MakeLegacyCmd("CNY2USD"), Map("Category", "Tool", "Description", T("cmd.Misc.CNY2USD"), "Keywords", "CNY2USD"))
    RimCommand.Register("USD2CNY", "USD2CNY", MakeLegacyCmd("USD2CNY"), Map("Category", "Tool", "Description", T("cmd.Misc.USD2CNY"), "Keywords", "USD2CNY"))
    RimCommand.Register("CurrencyRate", "CurrencyRate", MakeLegacyCmd("CurrencyRate"), Map("Category", "Tool", "Description", T("cmd.Misc.CurrencyRate"), "Keywords", "CurrencyRate"))
    RimCommand.Register("ShowIp", "ShowIp", MakeLegacyCmd("ShowIp"), Map("Category", "Tool", "Description", T("cmd.Misc.ShowIp"), "Keywords", "ShowIp"))
    RimCommand.Register("Wifi", "Wifi", MakeLegacyCmd("WifiShow"), Map("Category", "Tool", "Description", T("cmd.Misc.Wifi"), "Keywords", "Wifi"))
    RimCommand.Register("Dns", "Dns", MakeLegacyCmd("DnsShow"), Map("Category", "Tool", "Description", T("cmd.Misc.Dns"), "Keywords", "Dns"))
    RimCommand.Register("Ping", "Ping", MakeLegacyCmd("PingShow"), Map("Category", "Tool", "Description", T("cmd.Misc.Ping"), "Keywords", "Ping"))
    RimCommand.Register("PubIp", "PubIp", MakeLegacyCmd("PubIpShow"), Map("Category", "Tool", "Description", T("cmd.Misc.PubIp"), "Keywords", "PubIp"))
    RimCommand.Register("Env", "Env", MakeLegacyCmd("EnvShow"), Map("Category", "Tool", "Description", T("cmd.Misc.Env"), "Keywords", "Env"))
    RimCommand.Register("Calendar", "Calendar", MakeLegacyCmd("Calendar"), Map("Category", "Tool", "Description", T("cmd.Misc.Calendar"), "Keywords", "Calendar"))
    RimCommand.Register("UrlEncode", "UrlEncode", MakeLegacyCmd("UrlEncodeCmd"), Map("Category", "Tool", "Description", T("cmd.Misc.UrlEncode"), "Keywords", "UrlEncode"))
    RimCommand.Register("UrlDecode", "UrlDecode", MakeLegacyCmd("UrlDecodeCmd"), Map("Category", "Tool", "Description", T("cmd.Misc.UrlDecode"), "Keywords", "UrlDecode"))
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

