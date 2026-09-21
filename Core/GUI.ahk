#Requires AutoHotkey v2.0
#Warn All, Off

; === GUI - 显示和对齐 (从 RunZ Core/GUI.ahk 移植) ===

; 获取鼠标所在行号
getMouseCurrentLine() {
    global g_DisplayArea, g_DisplayRows, g_WindowName

    MouseGetPos(, &mouseY, , &classnn)
    if (classnn != g_DisplayArea)
        return -1

    ControlGetPos(, &y, , &h, g_DisplayArea, g_WindowName)
    lineHeight := h / g_DisplayRows
    index := Ceil((mouseY - y) / lineHeight)
    return index
}

; 上下导航命令
ChangeCommand(step, resetCurrentLine := false) {
    global g_CurrentInput, g_InputEdit, g_CurrentLine, g_CurrentCommandList
    global g_CurrentCommand, g_FirstChar, g_DisplayRows, g_UseFallbackCommands
    global g_DisplayEdit, g_UseDisplay

    try {
        g_CurrentInput := g_InputEdit.Value
    } catch {
        return
    }

    if (resetCurrentLine
        || (SubStr(g_CurrentInput, 1, 1) != "@" && SubStr(g_CurrentInput, 1, 2) != "|@"))
        g_CurrentLine := 1

    row := g_CurrentCommandList.Length
    if (row > g_DisplayRows)
        row := g_DisplayRows
    ; 空列表直接返回 (v1 Mod(x,0) 得空, v2 会抛除零错)
    if (row < 1)
        return

    g_CurrentLine := Mod(g_CurrentLine + step, row)
    if (g_CurrentLine = 0)
        g_CurrentLine := row

    g_CurrentCommand := g_CurrentCommandList[g_CurrentLine]

    currentChar := Chr(g_FirstChar + g_CurrentLine - 1)
    if (SubStr(g_CurrentInput, 1, 1) = "|")
        newInput := "|@" . currentChar . " "
    else
        newInput := "@" . currentChar . " "

    if (g_UseFallbackCommands) {
        if (SubStr(g_CurrentInput, 1, 1) = "@")
            newInput .= SubStr(g_CurrentInput, 4)
        else
            newInput .= g_CurrentInput
    }

    try {
        result := g_DisplayEdit.Value
    } catch {
        return
    }
    ; v2 Edit.Value 只有 LF (原版 ControlGetText 是 CRLF), 先统一再搬标记
    result := StrReplace(result, "`r`n", "`n")
    result := StrReplace(result, ">| ", " | ")
    if (currentChar = Chr(g_FirstChar))
        result := currentChar . ">" . SubStr(result, 3)
    else
        result := StrReplace(result, "`n" . currentChar . " | ", "`n" . currentChar . ">| ")

    DisplaySearchResult(result)
    g_InputEdit.Value := newInput
    Send("{End}")
}

; GUI 关闭
GuiClose(*) {
    global g_Conf
    if (g_Conf["Config"]["RunInBackground"] != "1")
        ExitRunZ()
}

; 设置显示区文本 (带对齐)
DisplayControlText(text) {
    global g_DisplayEdit
    aligned := AlignText(text)
    g_DisplayEdit.Value := aligned
}

; 设置显示区文本 (不带对齐)
DisplayResult(result := "") {
    global g_DisplayEdit, g_UseDisplay
    ; 先归一再转 CRLF, 否则 FileRead 类自带 CRLF 的内容会被转成空行
    textToDisplay := StrReplace(StrReplace(result, "`r`n", "`n"), "`n", "`r`n")
    g_DisplayEdit.Value := textToDisplay
    g_UseDisplay := true
}

; 显示搜索结果
DisplaySearchResult(result) {
    global g_CurrentCommandList, g_Conf, g_CurrentCommand, g_CommandEdit, g_SkinConf

    DisplayControlText(result)

    if (g_CurrentCommandList.Length = 1 && g_Conf.Get("Config", "RunIfOnlyOne", "0") = "1")
        RunCommand(g_CurrentCommand)

    if ((g_SkinConf.Has("ShowCurrentCommand") ? g_SkinConf["ShowCurrentCommand"] : "1") = "1") {
        commandToShow := SubStr(g_CurrentCommand, InStr(g_CurrentCommand, " | ") + 3)
        ; 与列表同语言: 类型中文化 (原版此处英文原串, 列表中文, 统一为中文)
        commandToShow := StrReplace(commandToShow, "file | ", Chr(0x6587) . Chr(0x4EF6) . " | ")
        commandToShow := StrReplace(commandToShow, "function | ", Chr(0x529F) . Chr(0x80FD) . " | ")
        commandToShow := StrReplace(commandToShow, "cmd | ", Chr(0x547D) . Chr(0x4EE4) . " | ")
        commandToShow := StrReplace(commandToShow, "url | ", Chr(0x7F51) . Chr(0x5740) . " | ")
        try g_CommandEdit.Value := commandToShow
    }
}

; 鼠标移动事件
WM_MOUSEMOVE(wParam, lParam, msg, hwnd) {
    global g_Conf, g_DisplayArea, g_DisplayRows, g_CurrentCommandList, g_WindowName

    if (wParam = 1)
        PostMessage(0xA1, 2, , , "A")

    if (g_Conf["Config"]["ChangeCommandOnMouseMove"] != "1")
        return -1

    MouseGetPos(, &mouseY, , &classnn)
    if (classnn != g_DisplayArea)
        return -1

    ControlGetPos(, &y, , &h, g_DisplayArea, g_WindowName)
    lineHeight := h / g_DisplayRows
    index := Ceil((mouseY - y) / lineHeight)

    ; v2 数组越界抛错 (原版返回空串), 先判界
    if (index >= 1 && index <= g_CurrentCommandList.Length)
        ChangeCommand(index - 1, true)
}

; 窗口激活/失焦事件 (对齐原版: WinExist("RunZ.ahk") 判调试器, 否则 HideOrExit)
WM_ACTIVATE(wParam, lParam, msg, hwnd) {
    global g_DisableAutoExit, g_Conf, g_InputEdit, g_WindowName

    if (g_DisableAutoExit)
        return

    if (wParam >= 1)
        return
    else if (wParam <= 0) {
        if (!WinExist("RunZ.ahk")) {
            if (g_Conf.Get("Config", "KeepInputText", "1") != "1") {
                try g_InputEdit.Value := ""
            }
            HideOrExit()
        }
    }
}

; 按键帮助文本
KeyHelpText() {
    return AlignText(""
    . "* | Key | Shift + F1  | Show pinned key help`n"
    . "* | Key | Alt + F4    | Close pinned key help`n"
    . "* | Key | Enter       | Run current command`n"
    . "* | Key | Esc         | Close window`n"
    . "* | Key | Alt +       | Run by first char per row`n"
    . "* | Key | Tab +       | Then press first char to run`n"
    . "* | Key | Tab +       | Then Shift + char to locate`n"
    . "* | Key | Win  + j    | Toggle window`n"
    . "* | Key | Ctrl + j    | Move to next command`n"
    . "* | Key | Ctrl + k    | Move to previous command`n"
    . "* | Key | Ctrl + f    | Page down in output`n"
    . "* | Key | Ctrl + b    | Page up in output`n"
    . "* | Key | Ctrl + h    | Show history`n"
    . "* | Key | Ctrl + n    | Increase command weight`n"
    . "* | Key | Ctrl + p    | Decrease command weight`n"
    . "* | Key | Ctrl + l    | Clear input box`n"
    . "* | Key | Ctrl + r    | Rebuild file index`n"
    . "* | Key | Ctrl + q    | Restart`n"
    . "* | Key | Ctrl + d    | Open current file dir in TC`n"
    . "* | Key | Ctrl + s    | Show and copy full file path`n"
    . "* | Key | Ctrl + x    | Delete current file`n"
    . "* | Key | Ctrl + i    | Move cursor to line start`n"
    . "* | Key | Ctrl + o    | Move cursor to line end`n"
    . "* | Key | F2          | Edit config file`n"
    . "* | Key | F3          | Edit auto config file`n"
    . "* | Func | URL input  | Enter www or http URL directly`n"
    . "* | Func | `; prefix   | Command run by ahk`n"
    . "* | Func | : prefix   | Command run by cmd`n"
    . "* | Func | No result  | Enter runs via ahk`n"
    . "* | Func | Space      | Lock search results")
}

; 列对齐 (对齐原版 RunZ/Core/GUI.ahk AlignText)
AlignText(text) {
    global g_SkinConf

    col3MaxLen := (g_SkinConf.Has("DisplayCol3MaxLength") ? g_SkinConf["DisplayCol3MaxLength"] : "30") + 0
    col4MaxLen := (g_SkinConf.Has("DisplayCol4MaxLength") ? g_SkinConf["DisplayCol4MaxLength"] : "36") + 0
    col3Pos := 10
    hasCol2 := false

    static s_PaddedSpaces := "                                                                                                    "
    totalLen := col3MaxLen + col4MaxLen + 1
    if (totalLen > StrLen(s_PaddedSpaces))
        totalLen := StrLen(s_PaddedSpaces)
    strSpace := SubStr(s_PaddedSpaces, 1, totalLen)

    result := ""
    hasCol2 := false

    if (g_SkinConf["HideCol2"] = "1") {
        col3MaxLen += 7
        col3Pos := 5

        hasCol2 := true
        Loop Parse, text, "`n", "`r" {
            if (SubStr(A_LoopField, 3, 1) != "|" || SubStr(A_LoopField, 8, 1) != "|") {
                hasCol2 := false
                break
            }
        }
        if (hasCol2)
            col3Pos := 10
    }

    if ((g_SkinConf.Has("HideCol4IfEmpty") ? g_SkinConf["HideCol4IfEmpty"] : "1") = "1") {
        hasCol4 := false
        Loop Parse, text, "`n", "`r" {
            if (A_LoopField = "")
                continue
            _cell := SubStr(A_LoopField, col3Pos)
            if (_cell = "")
                continue
            _parts := StrSplit(_cell, " | ")
            if (_parts.Length >= 2 && _parts[2] != "") {
                hasCol4 := true
                break
            }
        }
        if (!hasCol4) {
            col3MaxLen += col4MaxLen + 3
            col4MaxLen := 0
        }
    }

    Loop Parse, text, "`n", "`r" {
        if (A_LoopField = "") {
            result .= "`r`n"
            continue
        }
        if (!InStr(A_LoopField, " | ")) {
            result .= A_LoopField . "`r`n"
            continue
        }

        if (hasCol2)
            result .= SubStr(A_LoopField, 1, 4)
        else
            result .= SubStr(A_LoopField, 1, col3Pos - 1)

        _rest := SubStr(A_LoopField, col3Pos)
        if (_rest = "")
            _rest := " "
        splitedLine := StrSplit(_rest, " | ")
        if (splitedLine.Length < 1) {
            result .= "`r`n"
            continue
        }
        col3RealLen := StrLen(RegExReplace(splitedLine[1], "[^\x00-\xff]", "`t`t"))

        if (col3RealLen > col3MaxLen)
            result .= SubStrByByte(splitedLine[1], col3MaxLen)
        else
            result .= splitedLine[1] . SubStr(strSpace, 1, col3MaxLen - col3RealLen)

        ; 原版: col4MaxLen>0 即画 " | " (即使为空也占位); 保持一致
        if (col4MaxLen > 0) {
            result .= " | "
            col4Text := splitedLine.Length >= 2 ? splitedLine[2] : ""
            col4RealLen := StrLen(RegExReplace(col4Text, "[^\x00-\xff]", "`t`t"))
            if (col4RealLen > col4MaxLen)
                result .= SubStrByByte(col4Text, col4MaxLen)
            else
                result .= col4Text
        }

        result .= "`r`n"
    }

    return result
}
