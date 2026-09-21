#Requires AutoHotkey v2.0
#Warn All, Off

; === GestureTrail - 手势轨迹线 (屏幕 DC + XOR 反色画笔) ===
; 直接画在屏幕 DC 上, R2_XORPEN 保证任意背景可见;
; Hide 时把已画线段重绘一遍即擦除, 无残留.
; 宽度取 [Gesture] TrailWidth, Trail=0 则全部 no-op.

global g_GestureTrail := Map("active", 0, "segs", [], "width", 5)

GestureTrail_Show() {
    global g_Gesture, g_GestureTrail
    try {
        if (!g_Gesture["enable"] || !g_Gesture["trail"])
            return
        g_GestureTrail["active"] := 1
        g_GestureTrail["segs"] := []
        g_GestureTrail["width"] := g_Gesture["trailWidth"] + 0 > 0 ? g_Gesture["trailWidth"] + 0 : 5
    } catch {
    }
}

GestureTrail_Line(x1, y1, x2, y2) {
    global g_GestureTrail
    try {
        if (!g_GestureTrail["active"])
            return
        GestureTrail_Draw(x1, y1, x2, y2, g_GestureTrail["width"])
        segs := g_GestureTrail["segs"]
        segs.Push([x1, y1, x2, y2])
        if (segs.Length > 2000)
            segs.RemoveAt(1)
    } catch {
    }
}

GestureTrail_Hide() {
    global g_GestureTrail
    try {
        if (!g_GestureTrail["active"])
            return
        g_GestureTrail["active"] := 0
        w := g_GestureTrail["width"]
        for i, s in g_GestureTrail["segs"]
            GestureTrail_Draw(s[1], s[2], s[3], s[4], w)
        g_GestureTrail["segs"] := []
    } catch {
    }
}

; ---- 单线段 XOR 绘制(画两遍=擦除) ----
GestureTrail_Draw(x1, y1, x2, y2, width) {
    hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
    if (!hdc)
        return
    try {
        pen := DllCall("CreatePen", "Int", 0, "Int", width, "UInt", 0xFFFFFF, "Ptr")
        oldPen := DllCall("SelectObject", "Ptr", hdc, "Ptr", pen, "Ptr")
        DllCall("SetROP2", "Ptr", hdc, "Int", 7)
        DllCall("MoveToEx", "Ptr", hdc, "Int", x1, "Int", y1, "Ptr", 0)
        DllCall("LineTo", "Ptr", hdc, "Int", x2, "Int", y2)
        DllCall("SelectObject", "Ptr", hdc, "Ptr", oldPen)
        DllCall("DeleteObject", "Ptr", pen)
    }
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)
}
