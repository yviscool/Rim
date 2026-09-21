#Requires AutoHotkey v2.0

; === MD5 哈希库 ===
; 使用 Windows CryptoAPI 计算 MD5

class MD5 {
    static Hash(str) {
        ; 使用 CryptoAPI 计算 MD5
        hModule := DllCall("LoadLibrary", "Str", "advapi32.dll", "Ptr")
        if (!hModule)
            return this.HashSimple(str)

        ; 初始化 crypto provider
        hProv := 0
        DllCall("advapi32\CryptAcquireContext", "Ptr*", &hProv, "Ptr", 0, "Ptr", 0, "UInt", 1, "UInt", 0xF0000000)
        if (!hProv) {
            DllCall("FreeLibrary", "Ptr", hModule)
            return this.HashSimple(str)
        }

        ; 创建 hash 对象
        hHash := 0
        DllCall("advapi32\CryptCreateHash", "Ptr", hProv, "UInt", 0x8003, "Ptr", 0, "UInt", 0, "Ptr*", &hHash)

        ; 添加数据
        strPtr := Buffer(StrPut(str, "UTF-8"))
        StrPut(str, strPtr, "UTF-8")
        DllCall("advapi32\CryptHashData", "Ptr", hHash, "Ptr", strPtr, "UInt", strPtr.Size, "UInt", 0)

        ; 获取哈希值
        hashSize := 16
        hashBuf := Buffer(hashSize)
        DllCall("advapi32\CryptGetHashParam", "Ptr", hHash, "UInt", 2, "Ptr", hashBuf, "UInt*", &hashSize, "UInt", 0)

        ; 清理
        DllCall("advapi32\CryptDestroyHash", "Ptr", hHash)
        DllCall("advapi32\CryptReleaseContext", "Ptr", hProv, "UInt", 0)
        DllCall("FreeLibrary", "Ptr", hModule)

        ; 转换为十六进制字符串
        result := ""
        Loop hashSize {
            byte := NumGet(hashBuf, A_Index - 1, "UChar")
            result .= Format("{:02x}", byte)
        }

        return result
    }

    ; 简单的 MD5 实现（备用）
    static HashSimple(str) {
        ; 使用 certutil 作为备用方案
        tempFile := A_Temp "\md5_input.txt"
        resultFile := A_Temp "\md5_output.txt"

        FileDelete tempFile
        FileDelete resultFile

        FileAppend str, tempFile, "UTF-8"

        try {
            Run 'cmd /c certutil -hashfile "' tempFile '" MD5 > "' resultFile '"', , "Hide"
            Sleep 100

            if FileExist(resultFile) {
                Loop read, resultFile {
                    line := Trim(A_LoopReadLine)
                    if (RegExMatch(line, "^[0-9a-f]{32}$")) {
                        FileDelete tempFile
                        FileDelete resultFile
                        return line
                    }
                }
            }
        }

        FileDelete tempFile
        FileDelete resultFile

        ; 如果都失败，返回空字符串
        return ""
    }
}
