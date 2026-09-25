#Requires AutoHotkey v2.0
#Warn All, Off

; === Misc.Search - 搜索/翻译 (搜索引擎/有道/百度/HTML清理/语言检测, 纯实现, 注册见 Misc.ahk) ===

; === 搜索引擎 ===
; 搜索命令格式：命令名|url|描述
; 在 Launcher 中输入 "Google keyword" 即可搜索

; === 翻译功能 (g_Arg > 剪切板 > InputBox) ===
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
        appid := Rim.config.Get("Config", "baidu_fanyi_appid", "")
        secret := Rim.config.Get("Config", "baidu_fanyi_secret", "")

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
        json := JSON.parse(response)
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
