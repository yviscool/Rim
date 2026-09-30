#Requires AutoHotkey v2.0

; === EasyIni 库 ===
; EasyIni: 段/键 ini 读写 (裸键行/转义/引号兼容)

class EasyIni {
    sections := Map()
    filePath := ""

    __New(filePath := "") {
        this.filePath := filePath
        if (filePath != "" && FileExist(filePath)) {
            this.Load(filePath)
        }
    }

    Load(filePath) {
        this.filePath := filePath
        this.sections := Map()
        currentSection := ""

        if !FileExist(filePath)
            return

        ; 显式 UTF-8 读取: 无 BOM 文件若行尾 CJK, `Loop read` 会吞换行丢键!
        try {
            content := FileRead(filePath, "UTF-8")
        } catch {
            return
        }
        if (SubStr(content, 1, 1) = Chr(0xFEFF))
            content := SubStr(content, 2)

        Loop Parse, content, "`n", "`r" {
            line := Trim(A_LoopField)

            ; 跳过空行和注释
            if (line = "" || SubStr(line, 1, 1) = ";" || (SubStr(line, 1, 1) = "#" && !InStr(line, "=")))
                continue

            ; 检测 section
            if (SubStr(line, 1, 1) = "[" && SubStr(line, -1) = "]") {
                currentSection := SubStr(line, 2, StrLen(line) - 2)
                if !this.sections.Has(currentSection)
                    this.sections[currentSection] := Map()
                continue
            }

            ; 检测 key=value, 同时兼容无 "=" 的裸键行 (FallbackCommand 格式).
            ; 键内 "=" 转义为 "\=" (Rank 键是整行命令, URL 查询串 ?q=/ ?wd= 必含 "=";
            ; 不转义则 Save→Load 回合键被截断, rank 丢失且误入排除表).
            if RegExMatch(line, "^((?:\\=|[^=])*)=(.*)", &match) {
                key := Trim(StrReplace(match[1], "\=", "="))
                value := Trim(match[2])

                ; 注意: 不做行内 ;/# 注释截断, 原版 EasyIni 保留完整值
                ; (URL 中的 # 和描述中的 ; 必须保留)
                ; 移除首尾配对引号 (v2: 负长度会多吞, 必须显式长度)
                if (StrLen(value) >= 2 && SubStr(value, 1, 1) = '"' && SubStr(value, -1) = '"')
                    value := SubStr(value, 2, StrLen(value) - 2)

                if (currentSection = "")
                    currentSection := "Auto"

                if !this.sections.Has(currentSection)
                    this.sections[currentSection] := Map()

                this.sections[currentSection][key] := value
            } else if (currentSection != "" && line != "") {
                ; 裸键行: key, value=""
                if !this.sections.Has(currentSection)
                    this.sections[currentSection] := Map()
                if !this.sections[currentSection].Has(line)
                    this.sections[currentSection][line] := ""
            }
        }
    }

    Save(filePath := "") {
        if (filePath = "")
            filePath := this.filePath

        if (filePath = "")
            return

        content := ""

        for sectionName, section in this.sections {
            content .= "[" sectionName "]`r`n"
            for key, value in section {
                ; 键内 "=" 转义 (与 Load 对称; 值不转义, 首 "=" 切分天然安全)
                content .= StrReplace(key, "=", "\=") "=" value "`r`n"
            }
            content .= "`r`n"
        }

        ; 原子落盘: 先写 tmp 再改名, 崩溃/断电只丢本次不丢整盘
        ; (此前截断直写, auto.ini 在退出/权重节流保存窗口期可被清空)
        tmpPath := filePath . ".easytmp"
        try {
            f := FileOpen(tmpPath, "w", "UTF-8-RAW")
            f.Write(content)
            f.Close()
            FileMove(tmpPath, filePath, 1)
        } catch {
            ; 保存失败只记日志不弹窗: 调用方 (SaveAutoConf/重启链) 靠 FileExist 自检,
            ; 弹窗会以模态卡死自动重启, 且用户在重启瞬间看不到它
            try FileAppend(A_Now . " WARN: EasyIni.Save failed: " filePath "`n", A_ScriptDir . "\Rim.error.log")
            catch {
            }
        }
        try FileDelete(tmpPath)
        catch {
        }
    }

    ; === 获取值 ===
    Get(section, key, default := "") {
        if this.sections.Has(section) && this.sections[section].Has(key)
            return this.sections[section][key]
        return default
    }

    ; === 设置值 ===
    Set(section, key, value) {
        if !this.sections.Has(section)
            this.sections[section] := Map()
        this.sections[section][key] := value
    }

    ; === 删除键 ===
    DeleteKey(section, key) {
        if this.sections.Has(section) && this.sections[section].Has(key)
            this.sections[section].Delete(key)
    }

    ; === 删除 section ===
    DeleteSection(section) {
        if this.sections.Has(section)
            this.sections.Delete(section)
    }

    ; === 添加 section ===
    AddSection(section) {
        if !this.sections.Has(section)
            this.sections[section] := Map()
    }

    ; === 添加键 ===
    AddKey(section, key, value) {
        this.Set(section, key, value)
    }

    ; === 检查 section 是否存在 ===
    HasSection(section) {
        return this.sections.Has(section)
    }

    ; === 检查 key 是否存在 ===
    HasKey(section, key) {
        return this.sections.Has(section) && this.sections[section].Has(key)
    }

    ; === 获取 section ===
    __Item[section] {
        get => this.GetSection(section)
    }

    ; === 获取 Section ===
    GetSection(section) {
        if this.sections.Has(section)
            return this.sections[section]
        return Map()
    }

    ; === 获取所有 Section ===
    GetSections() {
        return this.sections
    }
}
