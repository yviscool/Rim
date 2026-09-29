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

    ; 全局上下文提供者注册表 (AppId -> {capture, canHandle, capabilities})
    ; v1 协议: provider 必须是 Map, 含可调用 capture; 可选 canHandle(ctx)→bool、
    ; capabilities Map (能力自述, 供 AI/新功能机读). 形状不对直接抛, 不兼容旧裸函数形.
    static Providers := Map()

    ; 注册特定应用的上下文扩展提供者 (如 TC、Explorer 提供路径/选中项)
    static RegisterProvider(appId, provider) {
        if (!IsObject(provider) || !provider.Has("capture"))
            throw Error("RimContext.RegisterProvider needs Map{capture[, canHandle, capabilities]}: " . String(appId))
        cap := provider["capture"]
        if (!IsObject(cap) || !HasMethod(cap, "Call"))
            throw Error("RimContext.RegisterProvider capture not callable: " . String(appId))
        entry := Map("capture", cap, "canHandle", "", "capabilities", Map())
        if (provider.Has("canHandle")) {
            ch := provider["canHandle"]
            if (IsObject(ch) && HasMethod(ch, "Call"))
                entry["canHandle"] := ch
            else
                throw Error("RimContext.RegisterProvider canHandle not callable: " . String(appId))
        }
        if (provider.Has("capabilities")) {
            caps := provider["capabilities"]
            if (!IsObject(caps))
                throw Error("RimContext.RegisterProvider capabilities not a Map: " . String(appId))
            entry["capabilities"] := caps
        }
        RimContext.Providers[StrLower(appId)] := entry
    }

    ; 能力自述查询 (机读; 未注册返回空 Map, 永不抛错)
    static CapabilitiesOf(appId) {
        try {
            if (RimContext.Providers.Has(StrLower(appId))) {
                caps := RimContext.Providers[StrLower(appId)]["capabilities"]
                if (IsObject(caps))
                    return caps
            }
        } catch {
        }
        return Map()
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
        ; P9: 同 HWND 300ms TTL 缓存 (按键/手势连击零 WinAPI)
        try {
            cached := CtxCache_Get(hwnd)
            if (IsObject(cached))
                return cached
        }

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

        ; 尝试通过注册的 Provider 丰富路径与选中项信息 (单点, 可单测)
        try RimContext.ApplyProvider(ctx)
        catch {
        }

        ; 如果当前没有获取到路径，且是 #32770 对话框，尝试从通用对话框提取
        if (ctx.CurrentDir = "" && ctx.Class = "#32770") {
            try {
                ctx.CurrentDir := RimContext.ExtractDialogPath(hwnd)
            } catch {
            }
        }

        try CtxCache_Put(hwnd, ctx)
        catch {
        }
        return ctx
    }

    ; 对单个 ctx 执行其 AppId 的 provider (canHandle 先行, 失败记日志; 单点可单测)
    static ApplyProvider(ctx) {
        appId := ""
        try appId := StrLower(String(ctx.AppId))
        catch {
            return false
        }
        if (appId = "" || !RimContext.Providers.Has(appId))
            return false
        entry := RimContext.Providers[appId]
        if (!IsObject(entry) || !IsObject(entry["capture"]) || !HasMethod(entry["capture"], "Call"))
            return false
        can := true
        if (IsObject(entry["canHandle"]) && HasMethod(entry["canHandle"], "Call")) {
            try can := !!entry["canHandle"].Call(ctx)
            catch {
                can := false
            }
        }
        if (!can)
            return false
        try {
            entry["capture"].Call(ctx)
            return true
        } catch as e {
            try RimLog("CTX_PROVIDER_FAIL", appId, e)
            catch {
            }
            return false
        }
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
