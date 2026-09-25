#Requires AutoHotkey v2.0
#Warn All, Off

; === Core/Context.ahk - Rim 上下文引擎 (Context Engine) ===
; 统一提取和管理系统当前上下文 (活动窗口/进程/控件/路径/选中项/输入态)
; 键盘分发、鼠标手势、启动器与扩展动作均可从 Context 获取统一视图

class RimContext {
    Hwnd := 0
    Title := ""
    Class := ""
    Exe := ""
    ProcessPath := ""
    Control := ""
    ControlHwnd := 0
    ControlClass := ""
    IsInput := false
    AppId := ""
    CurrentDir := ""
    SelectedFile := ""
    SelectedFiles := []

    ; 全局上下文提供者注册表 (AppId -> Func(ctx))
    static Providers := Map()

    ; 注册特定应用的上下文扩展提供者 (例如 TC、Explorer、VSCode 等提供路径/选中项)
    static RegisterProvider(appId, providerFunc) {
        RimContext.Providers[StrLower(appId)] := providerFunc
    }

    ; 获取当前活动窗口（或指定窗口）的上下文快照
    static Capture(target := "A") {
        ctx := RimContext()
        hwnd := 0
        try {
            hwnd := WinExist(target)
        } catch {
            return ctx
        }
        if (!hwnd)
            return ctx

        ctx.Hwnd := hwnd

        try ctx.Title := WinGetTitle("ahk_id " . hwnd)
        catch {
        }
        try ctx.Class := WinGetClass("ahk_id " . hwnd)
        catch {
        }
        try ctx.Exe := WinGetProcessName("ahk_id " . hwnd)
        catch {
        }
        try ctx.ProcessPath := WinGetProcessPath("ahk_id " . hwnd)
        catch {
        }

        ; 识别高层 AppId
        ctx.AppId := RimContext.ResolveAppId(ctx.Exe, ctx.Class)

        ; 获取当前焦点控件信息
        try {
            ctrlHwnd := ControlGetFocus("ahk_id " . hwnd)
            if (ctrlHwnd) {
                ctx.ControlHwnd := ctrlHwnd
                try ctx.Control := ControlGetClassNN(ctrlHwnd)
                catch {
                }
                try ctx.ControlClass := ControlGetClass(ctrlHwnd)
                catch {
                }
            }
        } catch {
        }

        ; 判断是否处于输入态 (可编辑文本控件)
        ctx.IsInput := RimContext.CheckIsInput(ctx.ControlClass, ctx.Control, ctx.Class)

        ; 尝试通过注册的 Provider 丰富路径与选中项信息
        if (ctx.AppId != "" && RimContext.Providers.Has(StrLower(ctx.AppId))) {
            try {
                RimContext.Providers[StrLower(ctx.AppId)](ctx)
            } catch {
            }
        }

        ; 如果当前没有获取到路径，且是 #32770 对话框，尝试从通用对话框提取
        if (ctx.CurrentDir = "" && ctx.Class = "#32770") {
            try {
                ctx.CurrentDir := RimContext.ExtractDialogPath(hwnd)
            } catch {
            }
        }

        return ctx
    }

    ; 判定是否为输入框控件
    static CheckIsInput(ctrlClass, ctrlClassNN, winClass) {
        if (ctrlClass != "") {
            if RegExMatch(ctrlClass, "i)^(Edit|RichEdit|Scintilla|TextBox|Windows\.UI\.Input)")
                return true
        }
        if (ctrlClassNN != "") {
            if RegExMatch(ctrlClassNN, "i)^(Edit\d+|RichEdit|Scintilla)")
                return true
            ; Explorer 重命名或搜索栏
            if (winClass = "CabinetWClass" && (ctrlClassNN = "Edit1" || ctrlClassNN = "DirectUIHWND1"))
                return true
        }
        return false
    }

    ; 根据 Exe 和 Class 映射为标准 AppId
    static ResolveAppId(exe, cls) {
        exeLow := StrLower(exe)
        if (exeLow = "totalcmd.exe" || exeLow = "totalcmd64.exe" || cls = "TTOTAL_CMD")
            return "totalcommander"
        if (exeLow = "explorer.exe" && (cls = "CabinetWClass" || cls = "ExploreWClass"))
            return "explorer"
        if (cls = "Progman" || cls = "WorkerW")
            return "desktop"
        if (exeLow = "windowsterminal.exe" || exeLow = "wt.exe" || cls = "CASCADIA_HOSTING_WINDOW_CLASS" || cls = "ConsoleWindowClass")
            return "terminal"
        if (exeLow = "code.exe")
            return "vscode"
        if (exeLow = "chrome.exe" || exeLow = "msedge.exe" || exeLow = "firefox.exe" || exeLow = "brave.exe")
            return "browser"
        if (cls = "#32770")
            return "dialog"
        return exeLow != "" ? StrReplace(exeLow, ".exe", "") : "general"
    }

    ; 从通用文件对话框 (#32770) 提取路径
    static ExtractDialogPath(hwnd) {
        try {
            txt := ControlGetText("Edit1", "ahk_id " . hwnd)
            if (txt != "" && InStr(txt, "\") && FileExist(txt)) {
                if (DirExist(txt))
                    return txt
                SplitPath(txt, , &dir)
                return dir
            }
        } catch {
        }
        return ""
    }
}

; 全局便捷函数: 获取当前上下文快照
GetActiveContext() {
    return RimContext.Capture("A")
}
