; === TCDialog 插件 - TC 文件对话框替代 ===
; 完整实现 TC 作为文件选择对话框的功能
; 功能: 检测系统文件打开对话框, 自动切换到 TC, 选择文件后返回原窗口

; TC 对话框实例 (TCDialog_Keymaps 创建)
global g_TCDialog := ""

class TCDialogPlugin extends RimPlugin {
    static Name => "TCDialog"
    static Title => "TC Dialog Takeover"
    static Description => "TC 接管系统文件对话框"

    static RegisterKeymaps(engine) {
        TCDialog_Keymaps(engine)
    }
}

if (IsSet(RimPluginManager) && IsObject(RimPluginManager))
    RimPluginManager.Register(TCDialogPlugin)

TCDialog_Keymaps(engine) {
    global g_TCDialog, g_Conf
    if (g_Conf.Get("Plugins", "TCDialog", "1") = "0")
        return
    g_TCDialog := Plugin_TCDialog("TCDialog", "", "", T("tcdlg.title"))
    g_TCDialog.Setup(engine)
}

; 全局动作入口 (Action.Do 经 ActionToFuncName 调这些)
TCD_Select() {
    global g_TCDialog
    if IsObject(g_TCDialog)
        g_TCDialog.TCD_Select()
}
TCD_Cancel() {
    global g_TCDialog
    if IsObject(g_TCDialog)
        g_TCDialog.TCD_Cancel()
}
TCD_PreSelected() {
    global g_TCDialog
    if IsObject(g_TCDialog)
        g_TCDialog.PreSelected()
}
TCD_Selected() {
    global g_TCDialog
    if IsObject(g_TCDialog)
        g_TCDialog.Selected()
}
TCD_SelectedCurrentDir() {
    global g_TCDialog
    if IsObject(g_TCDialog)
        g_TCDialog.SelectedCurrentDir()
}
TCD_ReturnToCaller() {
    global g_TCDialog
    if IsObject(g_TCDialog)
        g_TCDialog.ReturnToCaller()
}
TCD_OpenTCDialog() {
    global g_TCDialog
    if IsObject(g_TCDialog)
        g_TCDialog.OpenTCDialog()
}

class Plugin_TCDialog extends Plugin {
    name := "TCDialog"
    title := T("tcdlg.title")

    Callers := Map()  ; 窗体ID -> 调用者ID
    IsDialogMode := Map()  ; 窗体ID -> 是否在对话框模式
    CheckTimer := ""
    ExcludeList := ""

    Setup(engine) {
        ; 总开关: AsOpenFileDialog (对齐原版读 [TotalCommander_Config])
        try {
            if (Rim.config.Get("TotalCommander_Config", "AsOpenFileDialog", "0") != "1")
                return
        }
        ; 检查 TC 路径 (插件全局 > 配置)
        _tc := ""
        try _tc := TCPath
        catch {
            _tc := ""
        }
        if (_tc = "") {
            try _tc := Rim.config.Get("TotalCommander_Config", "TCPath", Rim.config.Get("Config", "TCPath", ""))
        }
        if (_tc = "" || !FileExist(_tc)) {
            try Log("TCDialog: TC path not found, disabled")
            return
        }

        ; 读取排除列表 (原版键 OpenFileDialogExclude)
        try {
            this.ExcludeList := Rim.config.Get("TotalCommander_Config", "OpenFileDialogExclude", "password, 密码")
        } catch {
            this.ExcludeList := "password, 密码"
        }

        ; 注册动作
        engine.SetAction("<TCD_Select>", T("act.TCDialog.TCD_Select"))
        engine.SetAction("<TCD_Cancel>", T("act.TCDialog.TCD_Cancel"))
        engine.SetAction("<TCD_PreSelected>", T("act.TCDialog.TCD_PreSelected"))
        engine.SetAction("<TCD_Selected>", T("act.TCDialog.TCD_Selected"))
        engine.SetAction("<TCD_SelectedCurrentDir>", T("act.TCDialog.TCD_SelectedCurrentDir"))
        engine.SetAction("<TCD_ReturnToCaller>", T("act.TCDialog.TCD_ReturnToCaller"))
        engine.SetAction("<TCD_OpenTCDialog>", T("act.TCDialog.TCD_OpenTCDialog"))

        ; 启动定时检测
        this.CheckTimer := ObjBindMethod(this, "CheckFileDialog")
        SetTimer(this.CheckTimer, 1000)

        try Log("TCDialog: Plugin initialized")
    }

    ; 检测系统文件打开对话框 (v2 返回值式控件读取)
    CheckFileDialog() {
        ; 检查当前窗口是否是文件对话框
        try {
            class := WinGetClass("A")
            if (class != "#32770")
                return

            ; 检查焦点是否在 Edit1 控件 (类名, v2 原生返回 HWND)
            ct := FocusedClassNN("ahk_class #32770")
            if (ct != "Edit1")
                return

            ; 检查 Edit1 是否为空（排除"另存为"或已有内容的对话框）
            str := ControlGetText("Edit1", "ahk_class #32770")
            if (StrLen(str) > 0)
                return

            ; 检查窗口文本是否在排除列表中
            winText := WinGetText("ahk_class #32770")
            title := WinGetTitle("ahk_class #32770")
            if (StrLen(title) = 0)
                return

            fullText := winText title
            excludeArr := StrSplit(this.ExcludeList, ",", " ")
            for _, item in excludeArr {
                if (item = "")
                    continue
                if InStr(fullText, item)
                    return
            }

            ; 获取当前窗口ID
            id := WinExist("A")
            if (id = 0)
                return

            ; 如果已经记录过，跳过
            if this.Callers.Has(id)
                return

            ; 记录调用者并切换到 TC
            this.Callers[id] := id
            this.IsDialogMode[id] := true

            ; 映射按键
            this.MapDialogKeys(id)

            ; 切换到 TC
            this.FocusTC()

            try Log("TCDialog: Detected file dialog, id=" id)
        }
    }

    ; 映射对话框模式下的按键
    MapDialogKeys(dialogId) {
        ; 在 TC 窗口映射特殊按键
        Rim.vim.SetWin("TTOTAL_CMD")
        Rim.vim.SetMode("normal", "TTOTAL_CMD")

        ; Enter -> 进入目录/选择文件
        Rim.vim.Map("<enter>", "<TCD_PreSelected>", "TTOTAL_CMD")
        ; Ctrl+Enter -> 选择文件并返回
        Rim.vim.Map("<c-enter>", "<TCD_Selected>", "TTOTAL_CMD")
        ; Shift+Enter -> 选择当前目录
        Rim.vim.Map("<s-enter>", "<TCD_SelectedCurrentDir>", "TTOTAL_CMD")
        ; Esc -> 返回调用者
        Rim.vim.Map("<esc>", "<TCD_ReturnToCaller>", "TTOTAL_CMD")
    }

    ; 取消映射对话框模式下的按键
    UnmapDialogKeys() {
        Rim.vim.SetWin("TTOTAL_CMD")
        Rim.vim.SetMode("normal", "TTOTAL_CMD")

        Rim.vim.Map("<enter>", "<Default>", "TTOTAL_CMD")
        Rim.vim.Map("<c-enter>", "<Default>", "TTOTAL_CMD")
        Rim.vim.Map("<s-enter>", "<Default>", "TTOTAL_CMD")
        Rim.vim.Map("<esc>", "<Default>", "TTOTAL_CMD")
    }

    ; 切换到 TC 窗口
    FocusTC() {
        if WinExist("ahk_class TTOTAL_CMD") {
            WinActivate("ahk_class TTOTAL_CMD")
        }
    }

    ; 返回调用者窗口
    ReturnToCaller() {
        this.UnmapDialogKeys()

        dialogId := this.GetActiveDialogId()
        if (dialogId = 0) {
            ; 最小化 TC
            WinMinimize("ahk_class TTOTAL_CMD")
            Sleep 500
            dialogId := WinExist("A")
            if (dialogId = 0)
                return
        }

        ; 激活调用者窗口
        if this.Callers.Has(dialogId) {
            callerId := this.Callers[dialogId]
            WinActivate("ahk_id " callerId)
        }
    }

    ; 获取当前对话框ID
    GetActiveDialogId() {
        try {
            if (WinGetClass("A") = "#32770")
                return WinExist("A")
        }
        return 0
    }

    ; 进入目录或选择文件
    PreSelected() {
        ; cm_CopyNetNamesToClip
        TC_SendPos(2021)
        Sleep 100

        clipContent := A_Clipboard

        ; 检查是否多选
        if !InStr(clipContent, "`n") {
            ; 单选：检查是否是目录
            if SubStr(clipContent, -1) = "\" {
                ; cm_GoToDir
                TC_SendPos(2003)
                return
            }
        }

        ; 多选或文件：直接选择
        this.Selected()
    }

    ; 选择文件并返回
    Selected() {
        this.UnmapDialogKeys()

        ; cm_CopySrcPathToClip
        TC_SendPos(2029)
        Sleep 100
        path := A_Clipboard

        ; cm_CopyNamesToClip
        TC_SendPos(2017)
        Sleep 100
        files := A_Clipboard

        ; 多选时添加引号
        if InStr(files, "`n") {
            files := ""
            Loop Parse, A_Clipboard, "`n", "`r" {
                files .= "`"" A_LoopField "`" "
            }
        } else {
            ; 单选：获取完整路径
            TC_SendPos(2021)
            Sleep 100
            files := A_Clipboard
        }

        ; 获取对话框ID
        dialogId := this.GetActiveDialogId()
        if (dialogId = 0) {
            WinMinimize("ahk_class TTOTAL_CMD")
            Sleep 500
            dialogId := WinExist("A")
            if (dialogId = 0)
                return
        }

        ; 激活调用者窗口
        if this.Callers.Has(dialogId) {
            callerId := this.Callers[dialogId]
            WinActivate("ahk_id " callerId)
            WinWait("ahk_id " callerId)
        }

        ; 单选：直接填入完整路径
        if !InStr(files, "`"") {
            A_Clipboard := files
            Send "{Home}"
            Send "^v"
            Send "{Enter}"
            return
        }

        ; 多选：两步操作
        ; 第一步：跳转到当前路径
        A_Clipboard := path
        Send "^a"
        Send "{Del}"
        Send "^v"
        Send "{Enter}"
        Sleep 100

        ; 第二步：提交文件名
        A_Clipboard := files
        Send "^v"
        Send "{Enter}"
    }

    ; 选择当前目录
    SelectedCurrentDir() {
        this.UnmapDialogKeys()

        ; cm_CopySrcPathToClip
        TC_SendPos(2029)
        Sleep 100

        ; 添加反斜杠
        A_Clipboard := A_Clipboard "\"

        ; 获取对话框ID
        dialogId := this.GetActiveDialogId()
        if (dialogId = 0) {
            WinMinimize("ahk_class TTOTAL_CMD")
            Sleep 500
            dialogId := WinExist("A")
            if (dialogId = 0)
                return
        }

        ; 激活调用者窗口
        if this.Callers.Has(dialogId) {
            callerId := this.Callers[dialogId]
            WinActivate("ahk_id " callerId)
            WinWait("ahk_id " callerId)
        }

        Send "{Home}"
        Send "^v"
        Send "{Enter}"
    }

    ; 手动打开 TC 对话框
    OpenTCDialog() {
        class := WinGetClass("A")

        ; 如果已经在 TC 中，执行选择
        if (class = "TTOTAL_CMD") {
            this.Selected()
            return
        }

        ; 记录调用者并切换到 TC
        this.Callers[WinExist("A")] := WinExist("A")
        this.FocusTC()
        this.MapDialogKeys(WinExist("A"))
    }

    ; TCD_Select 动作
    TCD_Select() {
        this.OpenTCDialog()
    }

    ; TCD_Cancel 动作
    TCD_Cancel() {
        this.ReturnToCaller()
    }
}

; 全局变量
TCDialog_Callers := Map()
TCDialog_IsDialogMode := Map()
