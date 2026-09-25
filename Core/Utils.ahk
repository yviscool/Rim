#Requires AutoHotkey v2.0

; === Utils - 工具函数库 ===
; 通用辅助函数

; === 字符串工具 ===
; 注意：AHK v2 内置 StrLower/StrUpper，不要覆盖

StrTrim(str) {
    return Trim(str)
}

StrContains(str, needle) {
    return InStr(str, needle) > 0
}

StrStartsWith(str, prefix) {
    return SubStr(str, 1, StrLen(prefix)) = prefix
}

StrEndsWith(str, suffix) {
    return SubStr(str, -StrLen(suffix) + 1) = suffix
}

; === 文件工具 ===
FileAppendLine(filePath, line) {
    try {
        f := FileOpen(filePath, "a")
        f.WriteLine(line)
        f.Close()
    }
}

; === 路径工具 ===
GetFileName(path) {
    return SubStr(path, InStr(path, "\\", 0, -1) + 1)
}

GetFileExt(path) {
    return SubStr(path, InStr(path, ".", 0, -1) + 1)
}

GetDirectoryName(path) {
    return SubStr(path, 1, InStr(path, "\\", 0, -1) - 1)
}

CombinePath(base, relative) {
    if (SubStr(relative, 2, 1) = ":" || SubStr(relative, 1, 1) = "\")
        return relative
    return base "\" relative
}

; === 窗口工具 ===
GetActiveWindowClass() {
    try {
        cls := WinGetClass("A")
        return cls
    }
    return ""
}

GetActiveProcessName() {
    try {
        exe := WinGetProcessName("A")
        return exe
    }
    return ""
}

IsWindowActive(winTitle) {
    return WinActive(winTitle) > 0
}

; === 热键格式转换 (展示侧; 引擎绑定侧见 Engine.ahk Convert2VIM/ConvertFromVim, 以引擎侧为准) ===
; 方向: 未来收敛为单一 KeyCodec 模块, 合并前两对并存但禁新增第三套转换表
ConvertToAHK(vimKey) {
    key := vimKey
    key := StrReplace(key, "<C-", "^")
    key := StrReplace(key, "<A-", "!")
    key := StrReplace(key, "<S-", "+")
    key := StrReplace(key, "<Win-", "#")
    key := StrReplace(key, "<", "")
    key := StrReplace(key, ">", "")
    return key
}

ConvertToVIM(ahkKey) {
    key := ahkKey
    key := StrReplace(key, "^", "<C-")
    key := StrReplace(key, "!", "<A-")
    key := StrReplace(key, "+", "<S-")
    key := StrReplace(key, "#", "<Win-")
    if (SubStr(key, 1, 1) = "<")
        key .= ">"
    return key
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

; === 日志系统 ===
class Logger {
    static logFile := ""
    static logLevel := "INFO"
    static maxLogSize := 5 * 1024 * 1024  ; 5MB

    static Init(appDir) {
        this.logFile := appDir "\Rim.log"
        this.logLevel := Rim.config.Get("Config", "log_level", "INFO")
    }

    static Debug(message) {
        this.Log(message, "DEBUG")
    }

    static Info(message) {
        this.Log(message, "INFO")
    }

    static Warn(message) {
        this.Log(message, "WARN")
    }

    static Error(message) {
        this.Log(message, "ERROR")
    }

    static Log(message, level := "INFO") {
        ; 检查日志级别
        if !this.ShouldLog(level)
            return

        timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        logLine := "[" timestamp "] [" level "] " message

        ; 输出到调试窗口
        OutputDebug logLine

        ; 写入日志文件
        if (Rim.config.Get("Config", "enable_log", "0") = "1") {
            this.WriteLog(logLine)
        }
    }

    static ShouldLog(level) {
        levels := Map("DEBUG", 0, "INFO", 1, "WARN", 2, "ERROR", 3)
        return levels.Has(level) && levels[level] >= levels[this.logLevel]
    }

    static WriteLog(logLine) {
        try {
            ; 检查日志文件大小，超过限制则轮转
            if FileExist(this.logFile) {
                f := FileOpen(this.logFile, "r")
                size := f.Size
                f.Close()

                if (size > this.maxLogSize) {
                    this.RotateLog()
                }
            }

            f := FileOpen(this.logFile, "a")
            f.WriteLine(logLine)
            f.Close()
        } catch as e {
            OutputDebug T("util.log_write_fail") . e.Message
        }
    }

    static RotateLog() {
        backupFile := this.logFile ".bak"
        try {
            if FileExist(backupFile)
                FileDelete backupFile
            FileCopy this.logFile, backupFile
            FileDelete this.logFile
        } catch {
            ; 忽略轮转错误
        }
    }
}

; === 兼容旧日志函数 ===
Log(message, level := "INFO") {
    Logger.Log(message, level)
}

; === 统一错误日志 (RimLog) ===
; 全库散落 FileAppend(..., "Rim.error.log") 的唯一收敛点: 同文件、同格式、永不抛错
; 用法: RimLog("WARN", "GestureEngine.Dispatch failed: ...") / RimLog("ERROR", where, err)
; 注意: 不经 Logger (Logger 依赖 Rim.config 且默认关闭文件落盘); 此处直接写 Rim.error.log
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

; === 错误处理 ===
ShowError(message, title := "Rim Error") {
    MsgBox message, title, 16
}

ShowInfo(message, title := "Rim") {
    MsgBox message, title, 64
}

ShowConfirm(message, title := "Rim") {
    return MsgBox(message, title, 36) = "Yes"
}

; === 临时文件清理 ===
CleanupTempFiles() {
    tempDir := A_Temp "\Rim"
    if (!DirExist(tempDir)) {
        return
    }

    try {
        count := 0
        Loop Files, tempDir "\*.*" {
            ; 删除超过1天的临时文件
            if (A_LoopFileTimeModified < A_Now - 86400) {
                try {
                    FileDelete A_LoopFileFullPath
                    count++
                }
            }
        }
        Log(T("util.clean_temp_done", count))
    } catch as e {
        Log(T("util.clean_temp_fail", e.Message), "WARN")
    }
}

; === 日志文件清理 ===
CleanupLogFiles() {
    logFile := Rim.appDir "\Rim.log"
    if (!FileExist(logFile)) {
        return
    }

    try {
        ; 检查日志文件大小（超过5MB则清理）
        f := FileOpen(logFile, "r")
        size := f.Size
        f.Close()

        if (size > 5 * 1024 * 1024) {
            ; 保留最后1MB的内容
            f := FileOpen(logFile, "r")
            content := f.Read()
            f.Close()

            ; 找到最后1MB的起始位置
            startPos := StrLen(content) - 1024 * 1024
            if (startPos > 0) {
                newContent := SubStr(content, startPos)
                f := FileOpen(logFile, "w")
                f.Write(newContent)
                f.Close()
                Log(T("util.log_cleaned"))
            }
        }
    } catch as e {
        Log(T("util.clean_log_fail", e.Message), "WARN")
    }
}

; 文件尾注: PerfTimer / MemoryManager / FileWatcher / ConfigBackup 已切除
; (2026-09, 全仓零调用; 误删恢复见 git 历史)

