#Requires AutoHotkey v2.0
#Warn All, Off

; === Misc.Net - 网络诊断 (IP/WiFi/DNS/Ping/公网/环境, 纯实现, 注册见 Misc.ahk) ===

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

; === 公网 IP (ip.netart.cn, 国产源免代理; 不用 JSON 库, 正则直取) ===
PubIpShow() {
    global g_Arg
    target := Trim(g_Arg)
    geo := Misc_NetartGeo(target)
    if (!geo.Has("ip")) {
        DisplayResult(T("misc.pubip_failed"))
        return
    }
    title := target = "" ? T("misc.pubip_title") : T("misc.pubip_titleq", target)
    items := [Map("type", "head", "text", title), Map("type", "head", "text", "")]
    order := ["ip", "country", "region", "isp", "net"]
    labels := Map("ip", "IP", "country", T("misc.pubip_country"), "region", T("misc.pubip_region")
        , "isp", T("misc.pubip_isp"), "net", T("misc.pubip_net"))
    for k in order {
        if (geo.Has(k) && geo[k] != "")
            items.Push(Map("type", "row", "mark", "*", "label", labels[k], "value", geo[k]
                , "copy", geo[k], "tip", T("misc.copied_val", geo[k])))
    }
    RowNavShow(items)
}

Misc_NetartGeo(ip) {
    url := "https://ip.netart.cn/" . (ip = "" ? "" : ip)
    out := Misc_HttpGet(url)
    res := Map()
    if (Trim(out) = "")
        return res
    if RegExMatch(out, '"ip"\s*:\s*"([^"]+)"', &m)
        res["ip"] := m[1]
    if (!res.Has("ip"))
        return res
    if RegExMatch(out, '"country"\s*:\s*\{[^}]*"name"\s*:\s*"([^"]+)"', &m)
        res["country"] := m[1]
    loc := ""
    for f in ["subdivision", "city", "area"] {
        if RegExMatch(out, '"' f '"\s*:\s*"([^"]*)"', &m) && Trim(m[1]) != ""
            loc .= m[1]
    }
    if (loc != "")
        res["region"] := loc
    if RegExMatch(out, '"as"\s*:\s*\{[^}]*"info"\s*:\s*"([^"]+)"', &m)
        res["isp"] := m[1]
    else if RegExMatch(out, '"isp"\s*:\s*"([^"]+)"', &m)
        res["isp"] := m[1]
    if RegExMatch(out, '"addr"\s*:\s*"([^"]+)"', &m)
        res["net"] := m[1]
    return res
}

Misc_HttpGet(url) {
    out := Misc_HttpDirect(url)
    if (Trim(out) != "")
        return out
    ; 传输兜底: curl.exe (Win10 1803+ 自带)
    q := Chr(34)
    return Misc_RunUtf8("curl.exe -s -m 15 --proto =http,https " . q . url . q)
}

Misc_HttpDirect(url) {
    try {
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.SetTimeouts(8000, 8000, 8000, 8000)
        http.Open("GET", url, false)
        http.SetRequestHeader("User-Agent", "Mozilla/5.0")
        http.Send()
        return http.ResponseText
    } catch {
        return ""
    }
}

; === 环境变量 (空参全表; 单名精确取; 含分号自动拆行; 只读) ===
EnvShow() {
    global g_Arg
    name := Trim(g_Arg)
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

