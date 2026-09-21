#Requires AutoHotkey v2.0

; === JSON 解析库 ===
; 简化的 JSON 解析器，用于解析 API 响应

class JSON {
    static Load(text) {
        text := Trim(text)
        if (text = "")
            return ""

        ; 尝试使用 JavaScript 引擎解析
        try {
            doc := ComObject("htmlfile")
            doc.write('<meta http-equiv="X-UA-Compatible" content="IE=9">')
            js := doc.parentWindow
            result := js.eval("(" text ")")
            return this.ConvertJsObject(result)
        }

        ; 回退到简单解析
        return this.SimpleParse(text)
    }

    static ConvertJsObject(obj) {
        try {
            ; 尝试转换为 Map
            map := Map()
            keys := obj.GetKeys()
            for key in keys {
                value := obj[key]
                map[key] := this.ConvertJsValue(value)
            }
            return map
        } catch {
            return obj
        }
    }

    static ConvertJsValue(value) {
        try {
            type := Type(value)
            if (type = "String" || type = "Integer" || type = "Float")
                return value
            if (type = "ComObject") {
                try {
                    return this.ConvertJsObject(value)
                } catch {
                    return String(value)
                }
            }
            return value
        } catch {
            return value
        }
    }

    static SimpleParse(text) {
        ; 简化的 JSON 解析
        result := Map()

        ; 移除外层大括号 (v2: 负长度会多吞, 必须显式长度)
        if (SubStr(text, 1, 1) = "{" && SubStr(text, -1) = "}") {
            text := SubStr(text, 2, StrLen(text) - 2)
        }

        ; 简单的键值对解析
        pos := 1
        while (pos <= StrLen(text)) {
            ; 跳过空白
            while (pos <= StrLen(text) && RegExMatch(SubStr(text, pos, 1), "\s"))
                pos++

            if (pos > StrLen(text))
                break

            ; 提取键
            if (SubStr(text, pos, 1) = '"') {
                keyEnd := InStr(text, '"', false, pos + 1)
                if (keyEnd > 0) {
                    key := SubStr(text, pos + 1, keyEnd - pos - 1)
                    pos := keyEnd + 1

                    ; 跳过冒号
                    while (pos <= StrLen(text) && RegExMatch(SubStr(text, pos, 1), "[\s:]"))
                        pos++

                    ; 提取值
                    if (SubStr(text, pos, 1) = '"') {
                        valEnd := InStr(text, '"', false, pos + 1)
                        if (valEnd > 0) {
                            value := SubStr(text, pos + 1, valEnd - pos - 1)
                            result[key] := value
                            pos := valEnd + 1
                        }
                    } else if (RegExMatch(SubStr(text, pos, 1), "[\d\-]")) {
                        ; 数字
                        valEnd := pos
                        while (valEnd <= StrLen(text) && RegExMatch(SubStr(text, valEnd, 1), "[\d\.eE\+\-]"))
                            valEnd++
                        value := SubStr(text, pos, valEnd - pos)
                        result[key] := Number(value)
                        pos := valEnd
                    } else if (SubStr(text, pos, 4) = "true") {
                        result[key] := true
                        pos += 4
                    } else if (SubStr(text, pos, 5) = "false") {
                        result[key] := false
                        pos += 5
                    } else if (SubStr(text, pos, 4) = "null") {
                        result[key] := ""
                        pos += 4
                    }
                }
            } else {
                pos++
            }
        }

        return result
    }

    static Dump(obj, indent := 0) {
        if (Type(obj) = "Map") {
            result := "{"
            first := true
            for key, value in obj {
                if (!first)
                    result .= ","
                result .= '`n' . Format("{:}", indent + 2) . '"' key '": ' . this.Dump(value, indent + 2)
                first := false
            }
            result .= '`n' . Format("{:}", indent) . "}"
            return result
        } else if (Type(obj) = "Array") {
            result := "["
            first := true
            for value in obj {
                if (!first)
                    result .= ","
                result .= '`n' . Format("{:}", indent + 2) . this.Dump(value, indent + 2)
                first := false
            }
            result .= '`n' . Format("{:}", indent) . "]"
            return result
        } else if (Type(obj) = "String") {
            return '"' obj '"'
        } else {
            return String(obj)
        }
    }
}
