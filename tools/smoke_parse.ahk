#Requires AutoHotkey v2.0
#Warn All, Off

; 常驻冒烟探针 1/2: 全文件解析 (CI + 本地 `./AutoHotkey64.exe /ErrorStdOut tools/smoke_parse.ahk`)
; 全部 #Include 能加载即写 marker 并 0 退出; 任何加载错走 /ErrorStdOut 并非 0 退出.
; 注意: 只做解析验证, 不执行任何注册/界面逻辑 (顶层可执行代码须保持无副作用).
#Include ..\Core\I18n.ahk
#Include ..\Core\SmartInput.ahk
#Include ..\Core\Context.ahk
#Include ..\Core\Plugin.ahk
#Include ..\Core\Command.ahk
#Include ..\Core\Window.ahk
#Include ..\Core\Workspace.ahk
#Include ..\Core\Execution.ahk
#Include ..\Core\Engine.ahk
#Include ..\Core\Gesture.ahk
#Include ..\Core\GestureIni.ahk
#Include ..\Core\GesturePreview.ahk
#Include ..\Core\GestureTemplate.ahk
#Include ..\Core\GestureSPData.ahk
#Include ..\Core\GestureTrail.ahk
#Include ..\Plugins\BeyondCompare4.ahk
#Include ..\Plugins\Explorer.ahk
#Include ..\Plugins\Foobar2000.ahk
#Include ..\Plugins\General.ahk
#Include ..\Plugins\Kanji.ahk
#Include ..\Plugins\LauncherCore.ahk
#Include ..\Plugins\LauncherSystem.ahk
#Include ..\Plugins\Misc.ahk
#Include ..\Plugins\QRCode.ahk
#Include ..\Plugins\StrokePlus.ahk
#Include ..\Plugins\StatsBall.ahk
#Include ..\Plugins\TCCompare.ahk
#Include ..\Plugins\TCDialog.ahk
#Include ..\Plugins\TotalCommander.ahk
#Include ..\Plugins\VimDConfig.ahk
#Include ..\Plugins\VimEditor.ahk
#Include ..\Plugins\WinMerge.ahk
#Include ..\Plugins\MicrosoftExcel.ahk
#Include ..\Gui\GestureUI.ahk
#Include ..\Gui\VimConfigUI.ahk

FileAppend("smoke-parse-ok`n", A_ScriptDir . "\..\smoke_parse.out.txt")
ExitApp(0)
