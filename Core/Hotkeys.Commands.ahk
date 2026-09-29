#Requires AutoHotkey v2.0
#Warn All, Off

; === Hotkeys.Commands - 启动器业务命令池 (rank/历史/文件/配置/帮助/管道; 绑定见 Hotkeys.ahk) ===

NextCommand(*) {
    if (g_UseDisplay) {
        ; 行导航态: ^J 移动 >| 标记 (焦点不出输入框); 非行态才挪文本光标
        if (RowNavActive()) {
            RowNavMove(1)
            return
        }
        g_DisplayEdit.Focus()
        Send("{Down}")
        return
    }
    ChangeCommand(1)
}

PrevCommand(*) {
    if (g_UseDisplay) {
        if (RowNavActive()) {
            RowNavMove(-1)
            return
        }
        g_DisplayEdit.Focus()
        Send("{Up}")
        return
    }
    ChangeCommand(-1)
}

GotoCommand(*) {
    global g_InputEdit, g_CurrentCommandList, g_FirstChar
    try {
        if (ControlGetFocus("A") = g_InputEdit.Hwnd)
            return
    }
    index := Ord(SubStr(A_ThisHotkey, -1)) - g_FirstChar + 1
    if (index >= 1 && index <= g_CurrentCommandList.Length)
        ChangeCommand(index - 1, true)
}

ReindexFiles(*) {
    if WinActive(g_WindowName)
        ToolTip(T("ctx.reindexing"))
    GenerateSearchFileList()
    CleanupRank()  ; 内含 LoadFiles(false)→清理→LoadFiles(), 无需预 LoadFiles
    if WinActive(g_WindowName) {
        ToolTip(T("ctx.reindexed"))
        SetTimer(RemoveToolTip, -800)
    }
}

EditConfig(*) {
    if (CfgGet("Config", "Editor", "") != "")
        Run(CfgGet("Config", "Editor", "") ' "' g_ConfFile '"')
    else
        Run(g_ConfFile)
}

EditAutoConfig(*) {
    if (CfgGet("Config", "Editor", "") != "")
        Run(CfgGet("Config", "Editor", "") ' "' g_AutoConfFile '"')
    else
        Run(g_AutoConfFile)
}

ClearInputLabel(*) {
    ClearInput()
    ; 清空后回到默认结果页 (编程设置 Edit.Value 不保证触发 Change 事件,
    ; 显示区会停留在旧结果, 这里显式重建空串搜索的默认列表)
    SearchCommand("")
}

RunCurrentCommand(*) {
    ; 行导航态回车 = 复制当前行 (不执行、不关窗, 可连复制多行)
    if (RowNavActive()) {
        RowNavCopy()
        return
    }
    ; SmartInput: 有灰字先接受再执行 (否则跑的是旧列表头, 与框内文字脱节)
    try {
        SI_AcceptGhost()
    } catch {
    }
    RunCommand(g_CurrentCommand)
}

ParseArg(*) {
    global g_Arg, g_PipeArg, g_CurrentInput, g_UseFallbackCommands
    if (g_PipeArg != "") {
        g_Arg := g_PipeArg
        return
    }

    commandPrefix := SubStr(g_CurrentInput, 1, 1)

    if (commandPrefix = ";" || commandPrefix = ":") {
        g_Arg := SubStr(g_CurrentInput, 2)
        return
    }
    else if (commandPrefix = "@") {
        g_Arg := SubStr(g_CurrentInput, 4)
        return
    }

    if (InStr(g_CurrentInput, " ") && !g_UseFallbackCommands)
        g_Arg := SubStr(g_CurrentInput, InStr(g_CurrentInput, " ") + 1)
    else if (g_UseFallbackCommands)
        g_Arg := g_CurrentInput
    else
        g_Arg := ""
}

CleanupRank(*) {
    LoadFiles(false)
    for command, rank in g_AutoConf["Rank"] {
        keep := false
        try {
            rec := HistSplit(command)
            parts := StrSplit(rec["el"], " | ")
            if (parts.Length >= 2 && StrLower(Trim(parts[1])) = "command" && IsSet(RimCommand))
                keep := RimCommand.Registry.Has(Trim(parts[2]))
        } catch {
        }
        if (!keep)
            g_AutoConf.DeleteKey("Rank", command)
    }
    tries := 0
    Loop {
        tries++
        try g_AutoConf.Save()
        catch {
        }
        if (FileExist(g_AutoConfFile))
            break
        if (tries >= 3)
            break
        Sleep(100)
    }
    LoadFiles()
}

RunSelectedCommand(*) {
    global g_InputEdit, g_CurrentCommandList, g_FirstChar
    ; 原版守卫: ~ 键(输入框内按字母)只定位不执行
    try {
        if (SubStr(A_ThisHotkey, 1, 1) = "~" && ControlGetFocus("A") = g_InputEdit.Hwnd)
            return
    }
    index := Ord(SubStr(A_ThisHotkey, -1)) - g_FirstChar + 1
    if (index >= 1 && index <= g_CurrentCommandList.Length)
        RunCommand(g_CurrentCommandList[index])
}

IncreaseRank(*) {
    if (g_CurrentCommand != "") {
        ChangeRank(g_CurrentCommand, true, 10)
        LoadFiles()
    }
}

DecreaseRank(*) {
    if (g_CurrentCommand != "") {
        ChangeRank(g_CurrentCommand, true, -10)
        LoadFiles()
    }
}

DisplayHistoryCommands(*) {
    global g_UseDisplay, g_CurrentCommandList, g_CurrentLine, g_CurrentCommand
    global g_FirstChar, g_HistoryCommands, g_InputEdit
    g_UseDisplay := false
    result := ""
    g_CurrentCommandList := []
    g_CurrentLine := 1

    for index, element in g_HistoryCommands {
        if (index = 1) {
            result .= Chr(g_FirstChar + index - 1) . ">| "
            g_CurrentCommand := element
        } else {
            result .= Chr(g_FirstChar + index - 1) . " | "
        }

        ; 列表行统一 "command|<id>" (+历史参数栏); 显示经 Registry 解名, 未注册退化裸行
        _rec := HistSplit(element)
        _id := ""
        try {
            _ep := StrSplit(_rec["el"], " | ")
            if (_ep.Length >= 2 && StrLower(Trim(_ep[1])) = "command")
                _id := Trim(_ep[2])
            else
                _id := Trim(_ep[1])
        } catch {
            _id := ""
        }
        _h1 := "command"
        _h2 := _id
        _h3 := ""
        try {
            if (_id != "" && IsSet(RimCommand)) {
                _rc := RimCommand.Get(_id)
                if (IsObject(_rc)) {
                    if (_rc.Name != "")
                        _h2 := _rc.Name
                    try {
                        if (_rc.Kind = "command")
                            _h3 := RimCommand.MakeLabel(_rc.Title, _id, _rc.Description)
                        else if (_rc.Description != "")
                            _h3 := _rc.Description
                    } catch {
                    }
                }
            }
        } catch {
        }
        if (_rec["has"])
            _h4 := _rec["arg"]
        else
            _h4 := ""
        result .= _h1 " | " _h2 " | " _h3 . " " . T("hist.argsep") . " " . _h4 "`n"
        g_CurrentCommandList.Push(element)
    }

    DisplayControlText(result)
}

; 从当前行取文件路径 ("command | <id>" 经 Registry 取 Target)
GetFilePathFromCmd(cmd) {
    try {
        el := HistSplit(cmd)["el"]
        parts := StrSplit(el, " | ")
        if (parts.Length >= 2 && StrLower(Trim(parts[1])) = "command" && IsSet(RimCommand)) {
            rc := RimCommand.Get(Trim(parts[2]))
            if (IsObject(rc) && StrLower(rc.Kind) = "file" && Trim(String(rc.Target)) != "")
                return Trim(String(rc.Target))
        }
        return ""
    } catch {
        return ""
    }
}

OpenCurrentFileDir(*) {
    OpenPath(GetFilePathFromCmd(g_CurrentCommand))
}

DeleteCurrentFile(*) {
    filePath := GetFilePathFromCmd(g_CurrentCommand)
    if (!FileExist(filePath))
        return
    FileRecycle(filePath)
    ReindexFiles()
}

ShowCurrentFile(*) {
    ; 行导航态 ^S = 复制当前行 (与回车同义)
    if (RowNavActive()) {
        RowNavCopy()
        return
    }
    A_Clipboard := GetFilePathFromCmd(g_CurrentCommand)
    ToolTip(A_Clipboard)
    SetTimer(RemoveToolTip, -800)
}

; 复制显示区全部内容 (行导航/普通展示通用, 不改变焦点)
DisplayCopyAll(*) {
    global g_DisplayEdit
    text := ""
    try text := g_DisplayEdit.Value
    catch {
        return
    }
    if (text = "")
        return
    try A_Clipboard := text
    catch {
        return
    }
    ToolTip(T("ctx.copy_display"))
    SetTimer(RemoveToolTip, -1500)
}

ChangePath(*) {
    UpdateSendTo(CfgGet("Config", "CreateSendToLnk", "0"), true)
    UpdateStartupLnk(CfgGet("Config", "CreateStartupLnk", "0"), true)
}

WatchUserFileList(*) {
    static lastUserFileListModifyTime := ""
    static lastConfFileModifyTime := ""
    global g_CfgSelfWriteTick
    ; 注意: FileGetTime 失败回 "" (杀软/同步盘/编辑器短暂锁文件);
    ; 空串绝不能当"变化"处理, 更不能存进 last (一次抖动会连炸两次重启,
    ; 配置窗被杀、dirty 丢失 —— "勾选不上/保存无效"的根因之一)
    try {
        newUserFileListModifyTime := FileGetTime(g_UserFileList)
        if (newUserFileListModifyTime = "") {
            try FileAppend("", g_UserFileList)
            catch {
            }
        } else {
            if (lastUserFileListModifyTime != "" && lastUserFileListModifyTime != newUserFileListModifyTime)
                LoadFiles()
            lastUserFileListModifyTime := newUserFileListModifyTime
        }
    }
    try {
        newConfFileModifyTime := FileGetTime(g_ConfFile)
        if (newConfFileModifyTime != "") {
            if (lastConfFileModifyTime != "" && lastConfFileModifyTime != newConfFileModifyTime) {
                ; 配置中心自写且全热应用: 吃掉这次变化, 不重启 (8s 窗口, 见 VimCfg_DoSave)
                if (IsSet(g_CfgSelfWriteTick) && g_CfgSelfWriteTick > 0 && A_TickCount - g_CfgSelfWriteTick < 8000) {
                    g_CfgSelfWriteTick := 0
                    lastConfFileModifyTime := newConfFileModifyTime
                } else {
                    RestartRunZ()
                }
            } else {
                lastConfFileModifyTime := newConfFileModifyTime
            }
        }
    }
}

; 保存结果为参数: 纯计算部分 (显示文本 + 当前行 → {arg, pipe}; 无 GUI 副作用, 可单测).
; 旧式 (裸 StrSplit[][2]/[3]) 在空行/短行/空列表上抛错, 且 "file | " 前缀分支在统一行后已死.
SaveResultAsArg_Compute(result, hide2, curCmd) {
    result := String(result)
    arg := ""
    pipe := ""
    if (hide2) {
        Loop Parse, result, "`n", "`r" {
            fld := Trim(A_LoopField)
            if (fld = "")
                continue
            pipe .= SubStr(fld, 1, 2) "| placeholder | " . (StrLen(fld) >= 5 ? SubStr(fld, 5) : "") . "`n"
        }
    } else {
        pipe := result
    }

    ; 文件行取路径 (经 Registry, 列表行统一 command|<id>)
    fp := ""
    try fp := GetFilePathFromCmd(curCmd)
    catch {
    }
    if (fp != "")
        arg .= fp
    else if (!InStr(result, " | ")) {
        arg .= StrReplace(result, "`n", " ")
        arg := StrReplace(arg, "`r")
    } else {
        Loop Parse, result, "`n", "`r" {
            fld := Trim(A_LoopField)
            if (fld = "" || !InStr(fld, " | "))
                continue
            segs := StrSplit(fld, " | ")
            if (hide2) {
                if (segs.Length >= 2)
                    arg .= Trim(segs[2]) " "
            } else {
                if (segs.Length >= 3)
                    arg .= Trim(segs[3]) " "
            }
        }
    }
    return Map("arg", Trim(String(arg)), "pipe", pipe)
}

SaveResultAsArg(*) {
    global g_Arg, FullPipeArg, g_DisplayEdit, g_CurrentCommand, g_SkinConf
    global g_InputEdit, g_CommandFilter
    g_Arg := ""
    result := ""
    try result := String(g_DisplayEdit.Value)
    catch {
        return
    }
    hide2 := false
    try hide2 := g_SkinConf["HideCol2"] = "1"
    catch {
    }

    computed := ""
    try computed := SaveResultAsArg_Compute(result, hide2, g_CurrentCommand)
    catch {
        return
    }
    g_Arg := computed["arg"]
    FullPipeArg := computed["pipe"]

    g_InputEdit.Value := "|"
    g_InputEdit.Focus()
    Send("{End}")
    if (g_CommandFilter != "") {
        SearchCommand("|" g_CommandFilter)
        g_CommandFilter := ""
    }
}

Help(*) {
    DisplayResult(KeyHelpText() . GetAllFunctions())
}

KeyHelp(*) {
    ToolTip(KeyHelpText())
    SetTimer(RemoveToolTip, -5000)
}

; 用法查询: "Usage KillProcess" 展示参数规格 (无参查自身用法)
ShowUsage() {
    global g_Arg
    target := Trim(g_Arg)
    if (target = "")
        target := "Usage"
    usage := ""
    try usage := RimCommand.Usage(target)
    catch {
    }
    if (usage != "")
        DisplayResult(usage)
    else {
        try DisplayResult(T("cmd.usage_unknown", target))
        catch {
        }
    }
}

RemoveToolTip(*) {
    ToolTip()
    SetTimer(RemoveToolTip, 0)
}

; ==================== 输入处理 ====================

ProcessInputCommand(*) {
    global g_CurrentInput, g_InputEdit
    g_CurrentInput := g_InputEdit.Value
    if (SubStr(g_CurrentInput, -1) = " ") {
        ProcessInputCommandCallBack()
        return
    }
    SetTimer(ProcessInputCommandCallBack, -1)
}

ProcessInputCommandCallBack(*) {
    SetTimer(ProcessInputCommandCallBack, 0)

    if (g_SkinConf["ShowInputBoxOnlyIfEmpty"] = "1") {
        if (g_CurrentInput != "") {
            if (g_SkinConf["ShowCurrentCommand"] = "1")
                windowHeight := g_SkinConf["BorderSize"] * 4 + g_SkinConf["EditHeight"] * 2 + g_SkinConf["DisplayAreaHeight"]
            else
                windowHeight := g_SkinConf["BorderSize"] * 3 + g_SkinConf["EditHeight"] + g_SkinConf["DisplayAreaHeight"]
            WinMove(, , , windowHeight, g_WindowName)
        } else {
            windowHeight := g_SkinConf["BorderSize"] * 2 + g_SkinConf["EditHeight"]
            WinMove(, , , windowHeight, g_WindowName)
        }

        if (g_SkinConf["RoundCorner"] + 0 > 0) {
            WinSetRegion("0-0 w" g_SkinConf["BorderSize"] * 2 + g_SkinConf["WidgetWidth"] " h" windowHeight
                . " r" g_SkinConf["RoundCorner"] "-" g_SkinConf["RoundCorner"], g_WindowName)
        }
    }

    SearchCommand(g_CurrentInput)
    ; SmartInput: ghost 补全 + 延迟校验 (自家填充经 expect 标记, 内部直接返回)
    try {
        SI_OnInputChanged()
    } catch {
    }
}

StartCommandLine(*) {
    global g_FirstChar, g_CurrentInput
    g_FirstChar := 97
    SearchCommand(g_CurrentInput)
}

