#Requires AutoHotkey v2.0
#Warn All, Off

; === SmartInput - zsh 三件套移植 (autosuggest + substring-search + highlight) ===
; 设计约束: 输入框仍是原生 Edit (无富文本), 因此:
;   - ghost 用"选中后缀"实现 (浏览器地址栏同款): 全文填入 + EM_SETSEL 选中补全部分,
;     打字自然替换选中区, Tab/Right 回车接受, Esc 取消. 不碰已输入字符, IME 安全.
;   - 高亮用"整框底色 + 延迟校验": 未知命令头粉底, 已知/中性恢复皮肤色, 300ms 防抖.
;   - 历史翻找走 Alt+Up/Down, Up/Down 永远翻列表 (不再双义).
; 状态全部收敛在 g_SI (Map); 自家填充统一经 expect 标记, 防 Change 事件回环.

global g_SI
if !IsSet(g_SI) {
    g_SI := Map("ghostFull", "", "ghostShown", false, "expect", "", "expectOn", false
        , "matches", [], "idx", 0, "query", "", "histOn", false, "inputHist", [])
}

#Include SmartInputPure.ahk


SI_HistoryInputs() {
    out := []
    try {
        for _i, element in g_HistoryCommands
            out.Push(SI_HistoryInputOfPure(element))
    } catch {
    }
    return out
}

SI_CommandCores() {
    out := []
    try {
        for _i, element in g_Commands
            out.Push(SI_CoreOfPure(element))
    } catch {
    }
    return out
}

SI_FindGhost(prefix) {
    global g_CurrentCommandList
    cands := []
    ; 1. 列表头优先: 回车跑的就是它, ghost 与执行目标永远一致 (精确置顶后更稳定)
    try {
        if (g_CurrentCommandList.Length > 0) {
            headCore := SI_CoreOfPure(g_CurrentCommandList[1])
            if (headCore != "")
                cands.Push(headCore)
        }
    } catch {
    }
    ; 2. 当前可见列表 (按显示序): 保证建议出自用户正看着的一家子, 不劫持到框外项
    try {
        for _i, element in g_CurrentCommandList {
            if (_i > 30)
                break
            cands.Push(SI_CoreOfPure(element))
        }
    } catch {
    }
    ; 3. 会话/历史/全表 (可见列表无前缀命中时才兜底, 比如整句含参复现)
    ;    历史输入态 (含参) 在历史裸核之前: 整句复现优先于裸命令
    for _i, cand in SI_InputHistAll()
        cands.Push(cand)
    for _i, cand in SI_HistoryInputs()
        cands.Push(cand)
    for _i, cand in SI_HistoryCores()
        cands.Push(cand)
    for _i, cand in SI_CommandCores()
        cands.Push(cand)
    return SI_MatchPrefixPure(prefix, cands)
}

SI_PushUnique(pool, seen, cand) {
    if (cand == "")
        return
    try {
        if (!seen.Has(cand)) {
            seen[cand] := true
            pool.Push(cand)
        }
    } catch {
    }
}

SI_SubstrMatches(query) {
    pool := []
    seen := Map()
    for _i, cand in SI_InputHistAll()
        SI_PushUnique(pool, seen, cand)
    for _i, cand in SI_HistoryInputs()
        SI_PushUnique(pool, seen, cand)
    for _i, cand in SI_HistoryCores()
        SI_PushUnique(pool, seen, cand)
    if (query != "") {
        for _i, cand in SI_CommandCores()
            SI_PushUnique(pool, seen, cand)
    }
    if (pool.Length > 300)
        pool := SubSlice(pool, 1, 300)
    return SI_SubstrPure(query, pool)
}

; 小切片 helper (v2 无原生 slice, 越界安全)
SubSlice(arr, from, to) {
    out := []
    if (from < 1)
        from := 1
    if (to > arr.Length)
        to := arr.Length
    i := from
    while (i <= to) {
        out.Push(arr[i])
        i++
    }
    return out
}

; ---------------- Edit 选区 (EM_SETSEL / EM_GETSEL) ----------------

SI_SetSel(s, e) {
    global g_InputEdit
    try {
        hwnd := g_InputEdit.Hwnd
        DllCall("SendMessageW", "Ptr", hwnd, "UInt", 0x00B1, "Ptr", s, "Ptr", e, "Ptr")
    } catch {
    }
}

SI_GetSel(&s, &e) {
    global g_InputEdit
    s := 0
    e := 0
    try {
        hwnd := g_InputEdit.Hwnd
        packed := DllCall("SendMessageW", "Ptr", hwnd, "UInt", 0x00B0, "Ptr", 0, "Ptr", 0, "Ptr")
        s := packed & 0xFFFF
        e := (packed >> 16) & 0xFFFF
    } catch {
    }
}

SI_InputFocused() {
    global g_InputEdit
    try {
        return ControlGetFocus("A") == g_InputEdit.Hwnd
    } catch {
        return false
    }
}

SI_CurValue() {
    global g_InputEdit
    try {
        return g_InputEdit.Value
    } catch {
        return ""
    }
}

; ---------------- 输入变化主入口 (由 ProcessInputCommandCallBack 尾部调用) ----------------

SI_OnInputChanged() {
    global g_SI, g_CurrentInput
    if !SI_Enabled()
        return
    cur := SI_CurValue()
    if (cur == "" && !g_SI.Get("ghostShown", false)) {
        SI_ScheduleValidate()
        return
    }
    ; 自家填充 (ghost / 历史回填): 消费 expect 标记后直接返回, 不重算
    if (g_SI.Get("expectOn", false) && cur == g_SI.Get("expect", "")) {
        g_SI["expectOn"] := false
        g_SI["expect"] := ""
        return
    }
    g_SI["expectOn"] := false
    g_SI["expect"] := ""
    g_SI["histOn"] := false
    g_SI["idx"] := 0
    first := SubStr(cur, 1, 1)
    if (cur == "" || first == "@" || first == "|" || first == ";" || first == ":") {
        g_SI["ghostShown"] := false
        g_SI["ghostFull"] := ""
        SI_ScheduleValidate()
        return
    }
    full := SI_FindGhost(cur)
    if (full != "" && full != cur)
        SI_ShowGhost(full, StrLen(cur))
    else {
        g_SI["ghostShown"] := false
        g_SI["ghostFull"] := ""
    }
    SI_ScheduleValidate()
}

SI_ShowGhost(full, prefixLen) {
    global g_SI, g_InputEdit
    g_SI["expect"] := full
    g_SI["expectOn"] := true
    try {
        g_InputEdit.Value := full
    } catch {
        g_SI["expect"] := ""
        g_SI["expectOn"] := false
        return
    }
    SI_SetSel(prefixLen, StrLen(full))
    g_SI["ghostFull"] := full
    g_SI["ghostShown"] := true
    ; 注意: 打字时的建议只做 overlay, 不推搜索 (列表保持用户实敲前缀的结果,
    ; 否则每敲一字列表就被劫持到某一项, 宽匹配没法浏览). 对齐在接受时做.
    SI_ScheduleValidate()
}

; 自家填充 (历史翻找/恢复用): 填值 + 光标置尾, 不做选中
SI_FillInput(text) {
    global g_SI, g_InputEdit
    g_SI["expect"] := text
    g_SI["expectOn"] := true
    try {
        g_InputEdit.Value := text
        SI_SetSel(StrLen(text), StrLen(text))
    } catch {
        g_SI["expect"] := ""
        g_SI["expectOn"] := false
        return
    }
    SI_PushSearch(text)
}

; 自家填充后显式推搜索: 编程设 Edit.Value 不保证触发 Change 事件,
; 不能指望事件回环来刷新列表 (否则输入框与列表头脱节, 回车误执行).
; 若事件随后真的触发, expect 标记会消费掉, 不会重复计算.
SI_PushSearch(newVal) {
    global g_CurrentInput
    try {
        g_CurrentInput := newVal
    } catch {
    }
    ; 框里留整句 (参数供回车时 ParseArg 用), 只拿命令头去搜:
    ; 整句含空格会撞 SearchCommand 的空格冻结分支, 列表永远不刷新
    query := SI_HeadPure(newVal)
    try {
        SearchCommand(query)
    } catch {
    }
    SI_ScheduleValidate()
}

; ---------------- 接受 / 取消 ----------------

; 全接受: 收起选中区 + 显式推搜索 (接受是显式动作, 列表必须跟到接受后的全文)
; 注意: 若用户开了 RunIfOnlyOne 且结果唯一, 此处搜索可能直接执行一次,
; 外层回车会再执行一次 (默认关闭该选项, 暂接受此边缘行为)
SI_AcceptGhost() {
    global g_SI
    if !g_SI.Get("ghostShown", false)
        return false
    full := g_SI.Get("ghostFull", "")
    g_SI["ghostShown"] := false
    g_SI["ghostFull"] := ""
    if (full != "")
        SI_SetSel(StrLen(full), StrLen(full))
    SI_PushSearch(full)
    return true
}

; 取消: 回到选中前的前缀
SI_CancelGhost() {
    global g_SI, g_InputEdit, g_CurrentInput
    if !g_SI.Get("ghostShown", false)
        return false
    s := 0
    e := 0
    SI_GetSel(&s, &e)
    cur := SI_CurValue()
    prefix := cur
    if (e > s && e <= StrLen(cur))
        prefix := SubStr(cur, 1, s)
    g_SI["ghostShown"] := false
    g_SI["ghostFull"] := ""
    SI_FillInput(prefix)
    try {
        g_CurrentInput := prefix
    } catch {
    }
    SI_ScheduleValidate()
    return true
}

SI_AcceptWord() {
    global g_SI
    if !g_SI.Get("ghostShown", false)
        return false
    full := g_SI.Get("ghostFull", "")
    s := 0
    e := 0
    SI_GetSel(&s, &e)
    if (e <= s)
        return false
    grown := SI_NextWordPure(full, s)
    if (grown == SubStr(full, 1, s))
        return false
    SI_SetSel(StrLen(grown), StrLen(full))
    return true
}

; ---------------- 按键入口 (全部 (*) 签名, 经 BindKey 绑定) ----------------

; Tab: 有 ghost 则全接受, 否则吞掉 (焦点留在输入框; 老 TabFunction 切隐藏框已删除)
SI_Tab(*) {
    global g_InputEdit
    if !SI_Enabled()
        return
    if !SI_InputFocused()
        return
    SI_AcceptGhost()
}

; Right: 有 ghost 则全接受, 否则透传原生右移
SI_Right(*) {
    global g_SI
    if !SI_Enabled() {
        try {
            Send("{Right}")
        } catch {
        }
        return
    }
    if (SI_InputFocused() && g_SI.Get("ghostShown", false)) {
        SI_AcceptGhost()
        return
    }
    try {
        Send("{Right}")
    } catch {
    }
}

; Ctrl+Right: 有 ghost 则接受一词, 否则透传
SI_AcceptWordKey(*) {
    global g_SI
    if !SI_Enabled() {
        try {
            Send("^{Right}")
        } catch {
        }
        return
    }
    if (SI_InputFocused() && g_SI.Get("ghostShown", false)) {
        if (SI_AcceptWord())
            return
    }
    try {
        Send("^{Right}")
    } catch {
    }
}

; Backspace: 有灰字时 = 去灰字 + 实删一字 (保证每按必短一截, 不会被补全顶回来);
; 无灰字时透传原生. 无焦点时透传.
SI_Backspace(*) {
    global g_SI, g_CurrentInput
    if (!SI_Enabled() || !SI_InputFocused()) {
        try {
            Send("{Backspace}")
        } catch {
        }
        return
    }
    if !g_SI.Get("ghostShown", false) {
        try {
            Send("{Backspace}")
        } catch {
        }
        return
    }
    cur := SI_CurValue()
    s := 0
    e := 0
    SI_GetSel(&s, &e)
    prefix := cur
    if (e > s && e <= StrLen(cur))
        prefix := SubStr(cur, 1, s)
    newVal := SubStr(prefix, 1, StrLen(prefix) - 1)
    g_SI["ghostShown"] := false
    g_SI["ghostFull"] := ""
    SI_FillInput(newVal)
    try {
        g_CurrentInput := newVal
    } catch {
    }
    SI_ScheduleValidate()
}

; Ctrl+Backspace: 有灰字时 = 去灰字 + 实删一词; 否则透传
SI_CtrlBackspace(*) {
    global g_SI, g_CurrentInput
    if (!SI_Enabled() || !SI_InputFocused()) {
        try {
            Send("^{Backspace}")
        } catch {
        }
        return
    }
    if !g_SI.Get("ghostShown", false) {
        try {
            Send("^{Backspace}")
        } catch {
        }
        return
    }
    cur := SI_CurValue()
    s := 0
    e := 0
    SI_GetSel(&s, &e)
    prefixLen := StrLen(cur)
    if (e > s && e <= StrLen(cur))
        prefixLen := s
    newVal := SI_PrevWordPure(cur, prefixLen)
    g_SI["ghostShown"] := false
    g_SI["ghostFull"] := ""
    SI_FillInput(newVal)
    try {
        g_CurrentInput := newVal
    } catch {
    }
    SI_ScheduleValidate()
}

; Delete: 有灰字时先取消灰字 (吞掉这次, 再按才真删); 否则透传
SI_DeleteKey(*) {
    global g_SI
    if (SI_Enabled() && SI_InputFocused() && g_SI.Get("ghostShown", false)) {
        SI_CancelGhost()
        return
    }
    try {
        Send("{Delete}")
    } catch {
    }
}

; Esc: 第一优先级取消 ghost, 第二退出历史模式, 最后走老 EscFunction
SI_Esc(*) {
    global g_SI
    if (SI_Enabled() && g_SI.Get("ghostShown", false)) {
        SI_CancelGhost()
        return
    }
    if (SI_Enabled() && g_SI.Get("histOn", false)) {
        SI_ExitHist()
        return
    }
    EscFunction()
}

; Alt+Up / Alt+Down: 历史子串翻找 (Up/Down 本体永远翻列表)
SI_SubstrUp(*) {
    SI_SubstrNav(1)
}

SI_SubstrDown(*) {
    SI_SubstrNav(-1)
}

SI_SubstrNav(step) {
    global g_SI, g_CurrentInput
    if !SI_Enabled()
        return
    if !SI_InputFocused()
        return
    cur := SI_CurValue()
    ; ghost 展开态: query 取未选中前缀, 丢掉灰字部分
    if (g_SI.Get("ghostShown", false)) {
        s := 0
        e := 0
        SI_GetSel(&s, &e)
        if (e > s && e <= StrLen(cur))
            cur := SubStr(cur, 1, s)
        g_SI["ghostShown"] := false
        g_SI["ghostFull"] := ""
    }
    if !g_SI.Get("histOn", false) {
        g_SI["query"] := cur
        g_SI["matches"] := SI_SubstrMatches(cur)
        g_SI["idx"] := 0
        g_SI["histOn"] := true
    }
    matches := []
    try {
        matches := g_SI["matches"]
    } catch {
    }
    idx := g_SI.Get("idx", 0) + step
    if (idx < 1 || idx > matches.Length) {
        q := g_SI.Get("query", "")
        g_SI["histOn"] := false
        g_SI["idx"] := 0
        SI_FillInput(q)
        try {
            g_CurrentInput := q
        } catch {
        }
        SI_RenderStatus(T("si.no_match"))
        return
    }
    g_SI["idx"] := idx
    pick := matches[idx]
    SI_FillInput(pick)
    try {
        g_CurrentInput := pick
    } catch {
    }
    SI_RenderStatus(T("si.hist_pos", idx, matches.Length))
}

SI_ExitHist() {
    global g_SI, g_CurrentInput
    q := g_SI.Get("query", "")
    g_SI["histOn"] := false
    g_SI["idx"] := 0
    SI_FillInput(q)
    try {
        g_CurrentInput := q
    } catch {
    }
}

; Alt+数字: 按序号执行 (与 Alt+字母并存; 0 = 第 10 项)
SI_RunByIndex(*) {
    global g_CurrentCommandList
    last := SubStr(A_ThisHotkey, -1)
    idx := 0
    if (last == "0")
        idx := 10
    else
        idx := Ord(last) - Ord("0")
    try {
        if (idx >= 1 && idx <= g_CurrentCommandList.Length)
            RunCommand(g_CurrentCommandList[idx])
    } catch {
    }
}

; ---------------- 输入历史记录 (供 RunCommand 调用) ----------------

SI_NoteInput(input) {
    global g_SI
    try {
        if !SI_Enabled()
            return
        if (g_Conf["Config"]["SaveHistory"] != "1")
            return
    } catch {
        return
    }
    if (SI_BlockedPure(input))
        return
    try {
        hist := g_SI["inputHist"]
        i := 1
        while (i <= hist.Length) {
            if (hist[i] == input) {
                hist.RemoveAt(i)
                break
            }
            i++
        }
        hist.InsertAt(1, input)
        maxn := 100
        try {
            maxn := g_Conf.Get("SmartInput", "MaxHist", "100") + 0
        } catch {
        }
        if (maxn < 10)
            maxn := 10
        while (hist.Length > maxn)
            hist.Pop()
    } catch {
    }
}

; ---------------- 延迟校验 (整框底色) ----------------

SI_ScheduleValidate() {
    if !SI_Enabled()
        return
    delay := 300
    try {
        delay := g_Conf.Get("SmartInput", "ValidateDelay", "300") + 0
    } catch {
    }
    if (delay < 50)
        delay := 50
    try {
        SetTimer(SI_Validate, -delay)
    } catch {
    }
}

SI_Validate(*) {
    global g_InputEdit, g_SkinConf
    try {
        SetTimer(SI_Validate, 0)
    } catch {
    }
    if !SI_Enabled()
        return
    cur := SI_CurValue()
    state := SI_CheckState(cur)
    try {
        base := "f0f0f0"
        try {
            if (g_SkinConf.Has("EditColor") && g_SkinConf["EditColor"] != "")
                base := g_SkinConf["EditColor"]
        } catch {
        }
        if (state == 0)
            g_InputEdit.Opt("+BackgroundFFD9D9")
        else
            g_InputEdit.Opt("+Background" . base)
    } catch {
    }
}

; 1=已知, 0=未知命令头, -1=中性 (空/特殊前缀)
SI_CheckState(input) {
    if (input == "")
        return -1
    first := SubStr(input, 1, 1)
    if (first == "@" || first == "|" || first == ";" || first == ":")
        return -1
    head := input
    sp := InStr(input, " ")
    if (sp > 0)
        head := SubStr(input, 1, sp - 1)
    if (head == "")
        return -1
    try {
        if (TryEvalInput(input) != "")
            return 1
    } catch {
    }
    hl := StrLower(head)
    hlen := StrLen(head)
    try {
        for _i, cand in SI_InputHistAll() {
            if (cand != "" && SubStr(StrLower(cand), 1, hlen) == hl)
                return 1
        }
        for _i, cand in SI_HistoryCores() {
            if (cand != "" && SubStr(StrLower(cand), 1, hlen) == hl)
                return 1
        }
        for _i, cand in SI_CommandCores() {
            if (cand != "" && SubStr(StrLower(cand), 1, hlen) == hl)
                return 1
        }
    } catch {
        return -1
    }
    return 0
}

SI_RenderStatus(text) {
    global g_CommandEdit
    try {
        if (IsObject(g_CommandEdit))
            g_CommandEdit.Value := text
    } catch {
    }
}
