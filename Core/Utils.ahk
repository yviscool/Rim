#Requires AutoHotkey v2.0

; === Utils - 工具函数库 ===
; 通用辅助函数 (字符串/路径/窗口小函数直接用内置 Trim/InStr/SubStr/SplitPath/WinAPI, 不再包垫片)

; === 热键格式转换: 唯一实现见 Engine.ahk Convert2VIM/ConvertFromVim ===
; === TC 路径唯一真相: [TotalCommander_Config].TCPath, [Config].TCPath 只做兜底读 ===
; (配置中心 TC 页唯一写入口; 老配置只有 Config 键时照样工作, 零丢数据)
TC_EffPath() {
    try {
        p := CfgGet("TotalCommander_Config", "TCPath", "")
        if (p != "")
            return p
    } catch {
    }
    try {
        return CfgGet("Config", "TCPath", "")
    } catch {
    }
    return ""
}

; === Action 名称工具 ===
; 将 "<Gen_Toggle>" 转为可调用的函数名 "Gen_Toggle"
; 将 "<c-a>" 转为可调用的函数名 "c_a"
ActionToFuncName(actionName) {
    name := actionName
    name := StrReplace(name, "<", "")
    name := StrReplace(name, ">", "")
    name := StrReplace(name, "-", "_")  ; AHK v2 函数名不支持 -
    return name
}

; === 调试日志 (唯一实现: OutputDebug; 文件落盘走 RimLog, 见下) ===
; 注: 旧 Logger 类 (Rim.log/级别过滤/轮转) 已删 —— Init 从未被调用,
; enable_log/log_level 键不存在, 文件分支恒死. 本函数即旧实际行为
; (INFO 门槛: DEBUG/未知级别丢弃, 与旧 ShouldLog 默认一致)
Log(message, level := "INFO") {
    if (level != "INFO" && level != "WARN" && level != "ERROR")
        return
    try OutputDebug "[" FormatTime(, "yyyy-MM-dd HH:mm:ss") "] [" level "] " message
    catch {
    }
}

; === 统一错误日志 (RimLog) ===
; 全库散落 FileAppend(..., "Rim.error.log") 的唯一收敛点: 同文件、同格式、永不抛错
; 用法: RimLog("WARN", "GestureEngine.Dispatch failed: ...") / RimLog("ERROR", where, err)
; 注意: 调试日志走 Log() (OutputDebug), 错误落盘只走这里
RimLog(level, msg, err := "") {
    try {
        line := A_Now . " [" . level . "] " . msg
        if (IsObject(err)) {
            try line .= ": " . err.Message . " @ " . err.File . ":" . err.Line
            catch {
            }
        } else if (err != "") {
            line .= " " . err
        }
        FileAppend(line . "`n", A_ScriptDir . "\Rim.error.log")
    } catch {
    }
    try OutputDebug "[Rim][" . level . "] " . msg
    catch {
    }
}

; === 错误处理 (ShowConfirm 唯一在用; 弹窗确认走 MsgBox 直调) ===
ShowConfirm(message, title := "Rim") {
    return MsgBox(message, title, 36) = "Yes"
}

; 文件尾注: PerfTimer / MemoryManager / FileWatcher / ConfigBackup 已切除
; (2026-09, 全仓零调用; 误删恢复见 git 历史)
; 同批: StrTrim/StrContains/StrStartsWith/StrEndsWith/FileAppendLine/GetFileName/GetFileExt/
; GetDirectoryName/CombinePath/GetActiveWindowClass/GetActiveProcessName/IsWindowActive/
; ShowError/ShowInfo/CleanupTempFiles/CleanupLogFiles (v2 内置/零调用, 同上理由切除)

