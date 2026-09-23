#Requires AutoHotkey v2.0
#Warn All, Off

; === VimDConfig Plugin - 按键/插件浏览器 (VimDesktop core/VimDConfig.ahk 移植) ===
; 插件一览 (左插件右动作, 过滤, 双击定位源码) + 按键一览 (窗/模式/映射三栏)

RegisterPlugin_VimDConfig() {
    RegisterAction("<VimDConfig_Plugin>", T("act.VimDConfig.VimDConfig_Plugin"))
    RegisterAction("<VimDConfig_Keymap>", T("act.VimDConfig.VimDConfig_Keymap"))
    RegisterAction("<VimDConfig_EditConfig>", T("act.VimDConfig.VimDConfig_EditConfig"))
    RegisterCommand("VimPlugins", "function", "VimDConfig_ShowPlugin", T("cmd.VimDConfig.VimPlugins"))
    RegisterCommand("VimKeymap", "function", "VimDConfig_ShowKeymap", T("cmd.VimDConfig.VimKeymap"))
}

; ==================== 插件浏览器 ====================
VimDConfig_ShowPlugin(*) {
    st := Map("plugin", "", "file", "", "lines", [], "lv", "", "ed", "")
    g := Gui("+Resize", T("vmd.plugin_title"))
    g.SetFont("s10", "Microsoft YaHei")
    g.Add("GroupBox", "x10 y10 w170 h440", T("vmd.group_plugins"))
    names := VimDConfig_PluginNames()
    lb := g.Add("ListBox", "x20 y35 w150 h400", names)
    g.Add("GroupBox", "x190 y10 w650 h520", T("vmd.group_actions"))
    lv := g.Add("ListView", "x200 y35 w630 h482 grid", [T("vmd.col_idx"), T("vmd.col_action"), T("vmd.col_desc")])
    lv.ModifyCol(1, 60)
    lv.ModifyCol(2, 250)
    lv.ModifyCol(3, 320)
    g.Add("GroupBox", "x10 y460 w170 h70", T("vmd.group_filter"))
    ed := g.Add("Edit", "x20 y490 w150 h25")
    st["lv"] := lv
    st["ed"] := ed
    st["gui"] := g
    lb.OnEvent("Change", (*) => VimDConfig_PluginPick(lb, st))
    ed.OnEvent("Change", (*) => VimDConfig_PluginFilter(st))
    lv.OnEvent("DoubleClick", (c, row) => VimDConfig_PluginGoto(c, row, st))
    g.OnEvent("Close", VimDConfig_Close)
    g.OnEvent("Escape", VimDConfig_Close)
    if (names.Length > 0) {
        lb.Choose(1)
        VimDConfig_PluginPick(lb, st)
    }
    g.Show("w850 h540")
}

; 浏览器窗统一关闭: 默认 Close 只是 Hide, 留僵尸窗, 显式 Destroy
VimDConfig_Close(guiObj, *) {
    try guiObj.Destroy()
    catch {
    }
    return true
}

VimDConfig_PluginNames() {
    names := []
    Loop Files, A_ScriptDir "\Plugins\*.ahk" {
        SplitPath(A_LoopFileName, , , , &pname)
        if (pname != "")
            names.Push(pname)
    }
    return names
}

VimDConfig_PluginPick(lb, st) {
    name := lb.Text
    if (name = "")
        return
    st["plugin"] := name
    st["file"] := A_ScriptDir "\Plugins\" name ".ahk"
    st["ed"].Value := ""
    lines := []
    if FileExist(st["file"]) {
        for _line in ReadFileLines(st["file"]) {
            if RegExMatch(_line, 'RegisterAction\("([^"]+)"(?:\s*,\s*(?:"([^"]*)"|T\("([^"]+)"\)))?', &mm) {
                desc := mm[2]
                if (desc = "" && mm[3] != "")
                    desc := T(mm[3])
                lines.Push(Map("action", mm[1], "desc", desc))
            } else if RegExMatch(_line, '(?:Host\s*\(\s*"RegisterCommand"\s*,\s*|RegisterCommand\s*\(\s*)"([^"]+)"\s*,\s*"([^"]+)"(?:\s*,\s*"[^"]*")?(?:\s*,\s*(?:"([^"]*)"|T\("([^"]+)"\)))?', &mc) {
                desc := mc[3]
                if (desc = "" && mc[4] != "")
                    desc := T(mc[4])
                lines.Push(Map("action", mc[1] " [" mc[2] "]", "desc", desc))
            }
        }
    }
    st["lines"] := lines
    VimDConfig_PluginFilter(st)
}

VimDConfig_PluginFilter(st) {
    lv := st["lv"]
    needle := Trim(st["ed"].Value)
    lv.Delete()
    idx := 1
    for item in st["lines"] {
        text := item["action"] " " item["desc"]
        if (needle = "" || InStr(text, needle)) {
            lv.Add("", idx, item["action"], item["desc"])
            idx++
        }
    }
}

VimDConfig_PluginGoto(ctrl, row, st) {
    if (row < 1)
        return
    action := ctrl.GetText(row, 2)
    if (action = "")
        return
    action := RegExReplace(action, " \[.*\]$", "")
    VimDConfig_SearchFileForEdit(action, "", false, st["file"])
}

; ==================== 按键浏览器 ====================
VimDConfig_ShowKeymap(*) {
    global g_VimEngine
    st := Map("win", "", "mode", "", "lines", [], "lv", "", "ed", "", "lbm", "")
    g := Gui("+Resize", T("vmd.keymap_title"))
    g.SetFont("s10", "Microsoft YaHei")
    g.Add("GroupBox", "x10 y10 w200 h269", T("vmd.group_windows"))
    wins := [""]
    if IsObject(g_VimEngine) {
        for wname, wobj in g_VimEngine.WinList {
            if (wname = "__global__")
                continue
            wins.Push(wname)
        }
    }
    lbw := g.Add("ListBox", "x20 y35 w180 R12", wins)
    g.Add("GroupBox", "x10 y290 w200 h135", T("vmd.group_modes"))
    lbm := g.Add("ListBox", "x20 y315 w180 R5", [])
    g.Add("GroupBox", "x10 y435 w200 h61", T("vmd.group_filter"))
    ed := g.Add("Edit", "x20 y460 w180 h25")
    g.Add("GroupBox", "x225 y10 w650 h486", T("vmd.group_map"))
    lv := g.Add("ListView", "x235 y36 w630 h450 grid", [T("vmd.col_hotkey"), T("vmd.col_action"), T("vmd.col_desc")])
    lv.ModifyCol(1, 100)
    lv.ModifyCol(2, 250)
    lv.ModifyCol(3, 259)
    st["lv"] := lv
    st["ed"] := ed
    st["lbm"] := lbm
    st["gui"] := g
    lbw.OnEvent("Change", (*) => VimDConfig_KeymapPickWin(lbw, st))
    lbm.OnEvent("Change", (*) => VimDConfig_KeymapPickMode(lbm, st))
    ed.OnEvent("Change", (*) => VimDConfig_KeymapFilter(st))
    lv.OnEvent("DoubleClick", (c, row) => VimDConfig_KeymapGoto(c, row, st))
    g.OnEvent("Close", VimDConfig_Close)
    g.OnEvent("Escape", VimDConfig_Close)
    if (wins.Length > 1) {
        lbw.Choose(2)
        VimDConfig_KeymapPickWin(lbw, st)
    }
    g.Show("w885 h506")
}

VimDConfig_WinModes(winName) {
    global g_VimEngine
    modes := []
    if !IsObject(g_VimEngine)
        return modes
    w := g_VimEngine.GetWin(winName)
    if !IsObject(w)
        return modes
    for mname, mobj in w.modeList
        modes.Push(mname)
    return modes
}

VimDConfig_KeymapPickWin(lbw, st) {
    wname := lbw.Text
    if (wname = "")
        return
    st["win"] := wname
    st["ed"].Value := ""
    modes := VimDConfig_WinModes(wname)
    lbm := st["lbm"]
    lbm.Delete()
    for m in modes
        lbm.Add([m])
    st["mode"] := ""
    st["lines"] := []
    VimDConfig_KeymapFilter(st)
    if (modes.Length > 0) {
        lbm.Choose(1)
        VimDConfig_KeymapPickMode(lbm, st)
    }
}

VimDConfig_KeymapPickMode(lbm, st) {
    mname := lbm.Text
    if (mname = "")
        return
    st["mode"] := mname
    VimDConfig_LoadHotkey(st)
}

VimDConfig_LoadHotkey(st) {
    global g_VimEngine
    st["lines"] := []
    wname := st["win"]
    mname := st["mode"]
    if (wname = "" || mname = "" || !IsObject(g_VimEngine))
        return
    w := g_VimEngine.GetWin(wname)
    if !IsObject(w)
        return
    if !w.modeList.Has(mname)
        return
    modeObj := w.modeList[mname]
    lines := []
    for key, action in modeObj.keymapList {
        desc := ""
        try {
            if (g_VimEngine.ActionList.Has(action))
                desc := g_VimEngine.ActionList[action].Comment
        }
        if (desc = "")
            desc := action
        dispKey := RegExReplace(key, "<S-(.*)>", "$1")
        lines.Push(Map("key", dispKey, "rawkey", key, "action", action, "desc", desc))
    }
    st["lines"] := lines
    st["ed"].Value := ""
    VimDConfig_KeymapFilter(st)
}

VimDConfig_KeymapFilter(st) {
    lv := st["lv"]
    needle := Trim(st["ed"].Value)
    lv.Delete()
    for item in st["lines"] {
        text := item["key"] " " item["action"] " " item["desc"]
        if (needle = "" || InStr(text, needle))
            lv.Add("", item["key"], item["action"], item["desc"])
    }
}

VimDConfig_KeymapGoto(ctrl, row, st) {
    if (row < 1)
        return
    key := ctrl.GetText(row, 1)
    action := ctrl.GetText(row, 2)
    if (action = "")
        return
    VimDConfig_SearchFileForEdit(action, key, false, "")
}

; ==================== 定位与编辑 ====================
VimDConfig_SearchFileForEdit(action, desc, editKeymap, pluginFile) {
    if (SubStr(action, 1, 1) = "<" || editKeymap) {
        found := false
        if (pluginFile != "" && FileExist(pluginFile)) {
            n := 0
            for _line in ReadFileLines(pluginFile) {
                n++
                if InStr(_line, action) {
                    VimDConfig_EditFile(pluginFile, n)
                    found := true
                    break
                }
            }
        }
        if (!found) {
            Loop Files, A_ScriptDir "\Plugins\*.ahk" {
                n := 0
                for _line in ReadFileLines(A_LoopFileFullPath) {
                    n++
                    if InStr(_line, action) {
                        VimDConfig_EditFile(A_LoopFileFullPath, n)
                        return
                    }
                }
            }
            Loop Files, A_ScriptDir "\Core\*.ahk" {
                n := 0
                for _line in ReadFileLines(A_LoopFileFullPath) {
                    n++
                    if InStr(_line, action) {
                        VimDConfig_EditFile(A_LoopFileFullPath, n)
                        return
                    }
                }
            }
        }
        return
    }
    g_ConfFile := A_ScriptDir . "\Conf\rim.ini"
    needle := "=" . action
    n := 0
    for _line in ReadFileLines(g_ConfFile) {
        n++
        if InStr(_line, needle) {
            VimDConfig_EditFile(g_ConfFile, n)
            return
        }
    }
    VimDConfig_EditFile(g_ConfFile, 1)
}

VimDConfig_EditFile(editPath, line := 1) {
    global g_Conf
    editorArgs := Map("notepad", "/g $line $file", "notepad2", "/g $line $file"
        , "sublime_text", "$file:$line", "vim", "+$line $file", "gvim", "--remote-silent-tab +$line $file"
        , "everedit", "-n$line $file", "notepad++", "-n$line $file", "EmEditor", "-l $line $file"
        , "uedit32", "$file/$line", "Editplus", "$file -cursor $line", "textpad", "$file($line)"
        , "pspad", "$file /$line", "ConTEXT", "$file /g1:$line", "scite", "$file -goto:$line")
    editor := ""
    try {
        editor := g_Conf.Get("Config", "Editor", "")
    }
    if (editor = "" || !FileExist(editor)) {
        try {
            Run(editPath)
        }
        return
    }
    SplitPath(editor, , , &ext, &nameNoExt)
    args := editorArgs.Has(nameNoExt) ? editorArgs[nameNoExt] : "$file"
    args := StrReplace(args, "$line", line)
    args := StrReplace(args, "$file", '"' . editPath . '"')
    try {
        Run('"' . editor . '" ' . args)
    }
}
