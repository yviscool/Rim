#Requires AutoHotkey v2.0
#Warn All, Off
; P0-1: 入口与 #Include 顺序可验证清单
; 用法: AutoHotkey64.exe /ErrorStdOut tools/probe_include_order.ahk
; 验收: 输出 include-order-ok, 且 Rim.ahk 的 #Include 顺序与清单一致
; 清单即本文件的 EXPECTED 数组, 改 Rim.ahk 必须同步改这里, 否则探针失败

EXPECTED := [
    "Lib\EasyIni.ahk",
    "Lib\TCMatch.ahk",
    "Lib\MonsterEval.ahk",
    "Core\Common.ahk",
    "Core\I18n.ahk",
    "Core\Tray.ahk",
    "Core\Config.ahk",
    "Core\ConfigSchema.ahk",
    "Core\ConfigTxn.ahk",
    "Core\Files.ahk",
    "Core\Search.ahk",
    "Core\GUI.ahk",
    "Core\Context.ahk",
    "Core\WindowIndex.ahk",
    "Core\Plugin.ahk",
    "Core\Command.ahk",
    "Core\ActionProtocol.ahk",
    "Core\Window.ahk",
    "Core\Workspace.ahk",
    "Core\Execution.ahk",
    "Core\Engine.ahk",
    "Core\Utils.ahk",
    "Core\Logging.ahk",
    "Core\Observability.ahk",
    "Core\TrainingLoop.ahk",
    "Core\Hotkeys.ahk",
]

Check(*) {
    content := FileRead(A_ScriptDir . "\..\Rim.ahk", "UTF-8")
    if (SubStr(content, 1, 1) = Chr(0xFEFF))
        content := SubStr(content, 2)
    found := []
    Loop Parse, content, "`n", "`r" {
        line := Trim(A_LoopField)
        if (SubStr(line, 1, 8) = "#Include") {
            rest := Trim(SubStr(line, 9))
            rest := RegExReplace(rest, "^\*i\s+", "")
            rest := StrReplace(rest, "/", "\")
            found.Push(rest)
        }
    }
    pos := 1
    for _, exp in EXPECTED {
        hit := 0
        Loop found.Length - pos + 1 {
            idx := pos + A_Index - 1
            if (found[idx] = exp) {
                hit := idx
                break
            }
        }
        if (!hit) {
            FileAppend("include-order-missing: " . exp . "`n", A_ScriptDir . "\..\probe_include_order.out.txt", "UTF-8")
            ExitApp(1)
        }
        pos := hit + 1
    }
    FileAppend("include-order-ok`n", A_ScriptDir . "\..\probe_include_order.out.txt", "UTF-8")
    ExitApp(0)
}
Check()
