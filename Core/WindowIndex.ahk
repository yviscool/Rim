#Requires AutoHotkey v2.0
#Warn All, Off
; === Core/WindowIndex.ahk - 窗口与上下文匹配索引 ===
; P1/P2-9: exe/class/title 分层索引 + 活动 HWND 短 TTL 缓存 + 切换/控件变化失效
; 不变量: 无类+无文件且名非 __global__ 者纯数据窗, 永不建索引不注册钩子

global g_WinIdx := Map("built", 0, "tick", 0, "ttl", 5000, "byExe", Map(), "byClass", Map(), "order", [])
global g_CtxCache := Map("hwnd", 0, "tick", 0, "ttl", 300, "ctx", "")

WinIdx_Rebuild(engine) {
    global g_WinIdx
    byExe := Map()
    byClass := Map()
    order := []
    try {
        for name, win in engine.WinList {
            if (name = "__global__")
                continue
            f := ""
            c := ""
            try f := StrLower(win.WinFile)
            catch {
            }
            try c := win.WinClass
            catch {
            }
            if (f = "" && c = "")
                continue
            order.Push(name)
            if (f != "") {
                if (!byExe.Has(f))
                    byExe[f] := []
                byExe[f].Push(name)
            }
            if (c != "") {
                if (!byClass.Has(c))
                    byClass[c] := []
                byClass[c].Push(name)
            }
        }
    }
    g_WinIdx["byExe"] := byExe
    g_WinIdx["byClass"] := byClass
    g_WinIdx["order"] := order
    g_WinIdx["tick"] := A_TickCount
    g_WinIdx["built"] := 1
    return order.Length
}

WinIdx_Invalidate() {
    global g_WinIdx
    g_WinIdx["built"] := 0
    g_WinIdx["tick"] := 0
}

WinIdx_Match(winExe, winClass, engine) {
    global g_WinIdx
    now := A_TickCount
    if (!g_WinIdx["built"] || now - g_WinIdx["tick"] > g_WinIdx["ttl"])
        WinIdx_Rebuild(engine)
    exeLow := StrLower(winExe)
    if (exeLow != "" && g_WinIdx["byExe"].Has(exeLow) && g_WinIdx["byExe"][exeLow].Length > 0)
        return g_WinIdx["byExe"][exeLow][1]
    if (winClass != "" && g_WinIdx["byClass"].Has(winClass) && g_WinIdx["byClass"][winClass].Length > 0)
        return g_WinIdx["byClass"][winClass][1]
    return ""
}

CtxCache_Get(hwnd) {
    global g_CtxCache
    if (g_CtxCache["hwnd"] = hwnd && A_TickCount - g_CtxCache["tick"] < g_CtxCache["ttl"] && IsObject(g_CtxCache["ctx"]))
        return g_CtxCache["ctx"]
    return ""
}

CtxCache_Put(hwnd, ctx) {
    global g_CtxCache
    g_CtxCache["hwnd"] := hwnd
    g_CtxCache["tick"] := A_TickCount
    g_CtxCache["ctx"] := ctx
}

CtxCache_Invalidate() {
    global g_CtxCache
    g_CtxCache["hwnd"] := 0
    g_CtxCache["tick"] := 0
    g_CtxCache["ctx"] := ""
}
