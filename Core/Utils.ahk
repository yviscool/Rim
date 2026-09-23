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
FileReadLines(filePath) {
    lines := []
    if FileExist(filePath) {
        loop read, filePath {
            lines.Push(A_LoopReadLine)
        }
    }
    return lines
}

FileWriteLines(filePath, lines) {
    content := ""
    for line in lines
        content .= line "`r`n"
    try {
        f := FileOpen(filePath, "w")
        f.Write(content)
        f.Close()
    }
}

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

; === 热键格式转换 ===
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
        this.logLevel := Rim.config.GetConfig("log_level", "INFO")
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
        if (Rim.config.GetConfig("enable_log", "0") = "1") {
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
            OutputDebug "日志写入失败: " e.Message
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
        Log("清理了 " count " 个临时文件")
    } catch as e {
        Log("清理临时文件失败: " e.Message, "WARN")
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
                Log("日志文件已清理")
            }
        }
    } catch as e {
        Log("清理日志文件失败: " e.Message, "WARN")
    }
}

; === 性能优化 ===
class PerfTimer {
    static timers := Map()

    static Start(name) {
        this.timers[name] := A_TickCount
    }

    static Stop(name) {
        if this.timers.Has(name) {
            elapsed := A_TickCount - this.timers[name]
            this.timers.Delete(name)
            return elapsed
        }
        return 0
    }

    static Log(name) {
        elapsed := this.Stop(name)
        if (elapsed > 0) {
            Log("性能 [" name "]: " elapsed "ms")
        }
    }
}

; === 内存管理 ===
class MemoryManager {
    static GetUsage() {
        try {
            pid := DllCall("kernel32\GetCurrentProcessId", "UInt")
            hProc := DllCall("kernel32\OpenProcess", "UInt", 0x1000, "Int", 0, "UInt", pid, "Ptr")
            if (!hProc)
                return 0
            try {
                pmc := Buffer(72, 0)
                NumPut("UInt", 72, pmc, 0)
                if DllCall("psapi\GetProcessMemoryInfo", "Ptr", hProc, "Ptr", pmc, "UInt", 72)
                    return NumGet(pmc, 8, "Ptr") // 1048576
            } finally {
                DllCall("kernel32\CloseHandle", "Ptr", hProc)
            }
        } catch {
        }
        return 0
    }

    static ForceGC() {
        ; AutoHotkey v2 没有公开 GC 控制接口; 不再用 WMI 伪造一次昂贵查询.
        return false
    }
}

; === 文件监控增强 ===
class FileWatcher {
    static watchers := Map()

    static Watch(filePath, callback, interval := 1000) {
        this.watchers[filePath] := Map(
            "callback", callback,
            "lastTime", FileExist(filePath) ? FileGetTime(filePath) : "",
            "interval", interval
        )
    }

    static Check() {
        for filePath, info in this.watchers {
            if !FileExist(filePath)
                continue

            currentTime := FileGetTime(filePath)
            if (currentTime != info["lastTime"]) {
                info["lastTime"] := currentTime
                try {
                    info["callback"].Call(filePath)
                }
            }
        }
    }

    static Stop(filePath) {
        if this.watchers.Has(filePath)
            this.watchers.Delete(filePath)
    }

    static StopAll() {
        this.watchers.Clear()
    }
}

; === 配置备份增强 ===
class ConfigBackup {
    static backupDir := ""

    static Init(appDir) {
        this.backupDir := appDir "\Backup"
        if !DirExist(this.backupDir)
            DirCreate this.backupDir
    }

    static CreateBackup(name := "") {
        if (name = "")
            name := FormatTime(, "yyyyMMddHHmmss")

        backupFile := this.backupDir "\rim_" name ".ini"
        configFile := Rim.config.configFile

        if FileExist(configFile) {
            try {
                FileCopy configFile, backupFile, 1
                Log("配置备份已创建: " backupFile)
                return true
            } catch as e {
                Log("配置备份失败: " e.Message, "ERROR")
            }
        }
        return false
    }

    static RestoreBackup(name) {
        backupFile := this.backupDir "\rim_" name ".ini"
        if FileExist(backupFile) {
            try {
                FileCopy backupFile, Rim.config.configFile, 1
                Log("配置已恢复: " backupFile)
                return true
            } catch as e {
                Log("配置恢复失败: " e.Message, "ERROR")
            }
        }
        return false
    }

    static ListBackups() {
        backups := []
        Loop Files, this.backupDir "\rim_*.ini" {
            backups.Push(A_LoopFileName)
        }
        return backups
    }

    static CleanupOldBackups(keepCount := 10) {
        backups := this.ListBackups()
        if (backups.Length > keepCount) {
            Loop backups.Length - keepCount {
                backupFile := this.backupDir "\" backups[A_Index]
                try {
                    FileDelete backupFile
                }
            }
        }
    }
}
