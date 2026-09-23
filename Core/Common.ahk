#Requires AutoHotkey v2.0
#Warn All, Off

; === Common - 工具函数 (从 RunZ Core/Common.ahk 移植) ===

; 根据字节取子字符串，如果多删了一个字节，补一个空格
SubStrByByte(text, length) {
    textForCalc := RegExReplace(text, "[^\x00-\xff]", "`t`t")
    textLength := 0
    textRealLength := 0

    Loop Parse, textForCalc {
        if (A_LoopField != "`t") {
            textLength++
            textRealLength++
        } else {
            textLength += 0.5
            textRealLength++
        }
        if (textRealLength >= length)
            break
    }

    result := SubStr(text, 1, Round(textLength - 0.5))
    if (Round(textLength - 0.5) != Round(textLength))
        result .= " "
    return result
}

; === 文件读取 (UTF-8 显式解码) ===
; 注意: 无 BOM 的 UTF-8 文件若行尾是 CJK, `Loop read` 会吞换行 (已实测 381→349 行)!
; 所有读配置/索引处必须走这里, 不得直接 Loop read
ReadTextFile(filePath, encoding := "UTF-8") {
    try {
        content := FileRead(filePath, encoding)
    } catch {
        return ""
    }
    ; 剥 BOM
    if (SubStr(content, 1, 1) = Chr(0xFEFF))
        content := SubStr(content, 2)
    return content
}

; 按行读取, 返回数组 (自动处理 CRLF/LF/CR)
ReadFileLines(filePath, encoding := "UTF-8") {
    content := ReadTextFile(filePath, encoding)
    if (content = "")
        return []
    lines := StrSplit(content, "`n", "`r")
    ; 去掉末尾空行 artefact
    while (lines.Length > 0 && Trim(lines[lines.Length]) = "")
        lines.Pop()
    return lines
}

; === 错误日志轮转 (启动时调一次即可; 日志每次 FileAppend 开关文件, 无句柄占用) ===
; 超过 maxBytes 就把当前日志挪到 .1 (只留一份历史, 防无界增长)
RotateErrorLog(maxBytes := 1048576) {
    path := A_ScriptDir . "\Rim.error.log"
    try {
        if (!FileExist(path))
            return
        f := FileOpen(path, "r")
        size := f.Length
        f.Close()
        if (size < maxBytes)
            return
        try FileDelete(path . ".1")
        catch {
        }
        try FileMove(path, path . ".1")
        catch {
        }
    } catch {
    }
}

; === 启动打点 (g_BootT0 由主入口最早赋值; 永不抛错) ===
BootMark(tag) {
    global g_BootT0
    t0 := 0
    try t0 := g_BootT0 + 0
    catch {
    }
    try FileAppend(A_Now . " +" . (A_TickCount - t0) . "ms " . tag . "`n", A_ScriptDir . "\Rim.error.log")
    catch {
    }
}

; === 启动器类型标签 (列表/详情区显示; 原先用 Chr(0x..) 硬编码中文, 审计扫不到) ===
TypeLabel(type) {
    if (type = "file")
        return T("type.file") . " | "
    else if (type = "function")
        return T("type.function") . " | "
    else if (type = "cmd")
        return T("type.cmd") . " | "
    else if (type = "url")
        return T("type.url") . " | "
    else if (type = "run")
        return T("type.run") . " | "
    return ""
}

; 获取焦点控件类名 (v2 ControlGetFocus 返回 HWND, 类名判断须转一道)
FocusedClassNN(winTitle := "A") {
    try {
        hwnd := ControlGetFocus(winTitle)
        if (!hwnd)
            return ""
        return ControlGetClassNN(hwnd)
    } catch {
        return ""
    }
}

; URL 编码 (v2: VarSetCapacity→Buffer)
UrlEncode(url, enc := "UTF-8") {
    enc := Trim(enc)
    if (enc = "")
        return url
    formatInteger := A_FormatInteger
    SetFormat("IntegerFast", "H")
    bufSize := StrPut(url, enc)
    buff := Buffer(bufSize, 0)
    StrPut(url, buff, enc)
    encoded := ""
    Loop bufSize - 1 {
        byte := NumGet(buff, A_Index - 1, "UChar")
        encoded .= (byte > 127 || byte < 33) ? "%" SubStr(byte, 3) : Chr(byte)
    }
    SetFormat("IntegerFast", formatInteger)
    return encoded
}

; 切换输入法 (v2: Control 传 HWND 会错位, 直接对窗口发)
SwitchIME(dwLayout) {
    HKL := DllCall("LoadKeyboardLayout", "Str", dwLayout, "UInt", 1)
    SendMessage(0x50, 0, HKL, , "A")
}

SwitchToEngIME() {
    ; 对齐原版: 调两次, 后者生效 (中文系统默认布局差异)
    SwitchIME(0x04090409)
    SwitchIME(0x08040804)
}

; 获取输入状态 (0=英文, 1=中文)
GetInputState(winTitle := "A") {
    try hwnd := WinGetID(winTitle)
    catch {
        return 0
    }
    if (A_Cursor = "IBeam")
        return 1
    if WinActive(winTitle) {
        ptrSize := !A_PtrSize ? 4 : A_PtrSize
        cbSize := 4 + 4 + (ptrSize * 6) + 16
        stGTI := Buffer(cbSize, 0)
        NumPut("UInt", cbSize, stGTI, 0)
        hwnd := DllCall("GetGUIThreadInfo", "UInt", 0, "Ptr", stGTI)
            ? NumGet(stGTI, 8 + ptrSize, "UInt") : hwnd
    }
    return DllCall("SendMessage"
        , "UInt", DllCall("imm32\ImmGetDefaultIMEWnd", "UInt", hwnd)
        , "UInt", 0x0283
        , "Int", 0x0005
        , "Int", 0)
}

; CPU 使用率 (v2 DllCall 用 "Int64*" 传址)
CPULoad() {
    static PIT := 0, PKT := 0, PUT := 0, started := false
    if (!started) {
        DllCall("GetSystemTimes", "Int64*", &PIT, "Int64*", &PKT, "Int64*", &PUT)
        started := true
        return 0
    }
    CIT := 0, CKT := 0, CUT := 0
    DllCall("GetSystemTimes", "Int64*", &CIT, "Int64*", &CKT, "Int64*", &CUT)
    IdleTime := PIT - CIT, KernelTime := PKT - CKT, UserTime := PUT - CUT
    SystemTime := KernelTime + UserTime
    result := ((SystemTime - IdleTime) * 100) // SystemTime
    PIT := CIT, PKT := CKT, PUT := CUT
    return result
}

; 获取内存状态 (v2: VarSetCapacity→Buffer/NumPut新签名)
; 注意: 必须返回 Map —— v2 plain Object 不支持 obj[2] 数字索引 (实测抛
; "has no property named __Item__"), Map 整数键才可 st[2]/枚举 (2026-09 校准)
GlobalMemoryStatusEx() {
    static MEMORYSTATUSEX := Buffer(64, 0), init := NumPut("UInt", 64, MEMORYSTATUSEX, 0)
    static status := Map(2, 0, 3, 0, 4, 0, 5, 0)
    if (DllCall("Kernel32.dll\GlobalMemoryStatusEx", "Ptr", MEMORYSTATUSEX)) {
        status[2] := NumGet(MEMORYSTATUSEX, 8, "UInt64")
        status[3] := NumGet(MEMORYSTATUSEX, 16, "UInt64")
        status[4] := NumGet(MEMORYSTATUSEX, 24, "UInt64")
        status[5] := NumGet(MEMORYSTATUSEX, 32, "UInt64")
        return status
    }
}

; 获取进程数
GetProcessCount() {
    proc := 0
    for process in ComObjGet("winmgmts:\\.\root\CIMV2").ExecQuery("SELECT * FROM Win32_Process")
        proc++
    return proc
}

; Unicode 解码
UnicodeDecode(text) {
    while pos := RegExMatch(text, "\\u\w{4}") {
        tmp := UrlEncodeEscape(SubStr(text, pos + 2, 4))
        text := RegExReplace(text, "\\u\w{4}", tmp, "", 1)
    }
    return text
}

UrlEncodeEscape(text) {
    text := "0x" . text
    LE := Buffer(2, 0)
    NumPut("UShort", Integer(text), LE, 0)
    return StrGet(LE, 2)
}

; 下载 URL 为字符串 (原版 Lib, 第三方/用户脚本兼容垫片)
UrlDownloadToString(url, headers := "") {
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.Open("GET", url, false)
        if (headers != "") {
            for line in StrSplit(headers, "`n") {
                line := Trim(line)
                if (line = "")
                    continue
                pos := InStr(line, ":")
                if (pos > 0)
                    req.SetRequestHeader(Trim(SubStr(line, 1, pos - 1)), Trim(SubStr(line, pos + 1)))
            }
        }
        req.Send()
        return req.ResponseText
    } catch {
        return ""
    }
}
