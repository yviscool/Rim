#Requires AutoHotkey v2.0

; === TotalCommander Plugin - TC深度集成 ===
; 移植自 VimDesktop 的 TC 插件（完整版）

; TC 全局变量
TCPath := ""
TCINI := ""
isTC64 := false
; 最近一次发出的 cm_ 编号 (对原版 TC_SendPos<>572 菜单判断)
global g_TCLastCmd := 0
TCListBox := "TMyListBox"
TCPanel := "Window1"
TCListBox1 := "TMyListBox"  ; 左面板列表框
TCListBox2 := "TMyListBox"  ; 右面板列表框

; === TC 命令系统 ===
; 通过 PostMessage 1075 (WM_USER+51) 发送 TC 内置命令 (原版同值, 移植曾误写 0x0442)
; v2 注意: PostMessage 第 4 位置参数是 Control, WinTitle 是第 5 个!
; 误写 PostMessage(1075, n, 0, "ahk_class TTOTAL_CMD") 会把类名当 Control, 抛 "Target control not found",
; 经 VimKeyTrampoline 吞掉后表现为 q/e/o 等全部失灵 (见 Rim.error.log VIMKEY-ERR)
TC_SendPos(Number) {
    global g_TCLastCmd
    g_TCLastCmd := Number
    PostMessage(1075, Number, 0, , "ahk_class TTOTAL_CMD")
}

; === TC 命令编号映射 ===
TC_GetCommandNumber(cmdName) {
    ; cm_ → 编号对照表, 逐条抽自原版 VimDesktop 同名插件内联 SendPos (D:\software\VimDesktop).
    ; 注意: 早期移植版手填的表多处错位 (如 q 发 2025=对侧打开而非预览), 已整体替换, 以此表为准.
    static cmdMap := Map(
        "cm_SrcComments", 300,
        "cm_SrcShort", 301,
        "cm_SrcLong", 302,
        "cm_SrcTree", 303,
        "cm_SrcQuickview", 304,
        "cm_VerticalPanels", 305,
        "cm_SrcQuickInternalOnly", 306,
        "cm_SrcHideQuickview", 307,
        "cm_SrcExecs", 311,
        "cm_SrcAllFiles", 312,
        "cm_SrcUserSpec", 313,
        "cm_SrcUserDef", 314,
        "cm_SrcByName", 321,
        "cm_SrcByExt", 322,
        "cm_SrcBySize", 323,
        "cm_SrcByDateTime", 324,
        "cm_SrcUnsorted", 325,
        "cm_SrcNegOrder", 330,
        "cm_SrcOpenDrives", 331,
        "cm_SrcThumbs", 269,
        "cm_SrcCustomViewMenu", 270,
        "cm_SrcPathFocus", 332,
        "cm_LeftComments", 100,
        "cm_LeftShort", 101,
        "cm_LeftLong", 102,
        "cm_LeftTree", 103,
        "cm_LeftQuickview", 104,
        "cm_LeftQuickInternalOnly", 106,
        "cm_LeftHideQuickview", 107,
        "cm_LeftExecs", 111,
        "cm_LeftAllFiles", 112,
        "cm_LeftUserSpec", 113,
        "cm_LeftUserDef", 114,
        "cm_LeftByName", 121,
        "cm_LeftByExt", 122,
        "cm_LeftBySize", 123,
        "cm_LeftByDateTime", 124,
        "cm_LeftUnsorted", 125,
        "cm_LeftNegOrder", 130,
        "cm_LeftOpenDrives", 131,
        "cm_LeftPathFocus", 132,
        "cm_LeftDirBranch", 2034,
        "cm_LeftDirBranchSel", 2047,
        "cm_LeftThumbs", 69,
        "cm_LeftCustomViewMenu", 70,
        "cm_RightComments", 200,
        "cm_RightShort", 201,
        "cm_RightLong", 202,
        "cm_RightTree", 203,
        "cm_RightQuickvie", 204,
        "cm_RightQuickInternalOnl", 206,
        "cm_RightHideQuickvie", 207,
        "cm_RightExec", 211,
        "cm_RightAllFile", 212,
        "cm_RightUserSpe", 213,
        "cm_RightUserDe", 214,
        "cm_RightByNam", 221,
        "cm_RightByEx", 222,
        "cm_RightBySiz", 223,
        "cm_RightByDateTim", 224,
        "cm_RightUnsorte", 225,
        "cm_RightNegOrde", 230,
        "cm_RightOpenDrives", 231,
        "cm_RightPathFocu", 232,
        "cm_RightDirBranch", 2035,
        "cm_RightDirBranchSel", 2048,
        "cm_RightThumb", 169,
        "cm_RightCustomViewMen", 170,
        "cm_List", 903,
        "cm_ListInternalOnly", 1006,
        "cm_Edit", 904,
        "cm_Copy", 905,
        "cm_CopySamepanel", 3100,
        "cm_CopyOtherpanel", 3101,
        "cm_RenMov", 906,
        "cm_MkDir", 907,
        "cm_Delete", 908,
        "cm_TestArchive", 518,
        "cm_PackFiles", 508,
        "cm_UnpackFiles", 509,
        "cm_RenameOnly", 1002,
        "cm_RenameSingleFile", 1007,
        "cm_MoveOnly", 1005,
        "cm_Properties", 1003,
        "cm_CreateShortcut", 1004,
        "cm_Return", 1001,
        "cm_OpenAsUser", 2800,
        "cm_Split", 560,
        "cm_Combine", 561,
        "cm_Encode", 562,
        "cm_Decode", 563,
        "cm_CRCcreate", 564,
        "cm_CRCcheck", 565,
        "cm_SetAttrib", 502,
        "cm_Config", 490,
        "cm_DisplayConfig", 486,
        "cm_IconConfig", 477,
        "cm_FontConfig", 492,
        "cm_ColorConfig", 494,
        "cm_ConfTabChange", 497,
        "cm_DirTabsConfig", 488,
        "cm_CustomColumnConfig", 483,
        "cm_CustomColumnDlg", 2920,
        "cm_LanguageConfig", 499,
        "cm_Config2", 516,
        "cm_EditConfig", 496,
        "cm_CopyConfig", 487,
        "cm_RefreshConfig", 478,
        "cm_QuickSearchConfig", 479,
        "cm_FtpConfig", 489,
        "cm_PluginsConfig", 484,
        "cm_ThumbnailsConfig", 482,
        "cm_LogConfig", 481,
        "cm_IgnoreConfig", 480,
        "cm_PackerConfig", 491,
        "cm_ZipPackerConfig", 485,
        "cm_Confirmation", 495,
        "cm_ConfigSavePos", 493,
        "cm_ButtonConfig", 498,
        "cm_ConfigSaveSettings", 580,
        "cm_ConfigChangeIniFiles", 581,
        "cm_ConfigSaveDirHistory", 582,
        "cm_ChangeStartMenu", 700,
        "cm_NetConnect", 512,
        "cm_NetDisconnect", 513,
        "cm_NetShareDir", 514,
        "cm_NetUnshareDir", 515,
        "cm_AdministerServer", 2204,
        "cm_ShowFileUser", 2203,
        "cm_GetFileSpace", 503,
        "cm_VolumeId", 505,
        "cm_VersionInfo", 510,
        "cm_ExecuteDOS", 511,
        "cm_CompareDirs", 533,
        "cm_CompareDirsWithSubdirs", 536,
        "cm_ContextMenu", 2500,
        "cm_ContextMenuInternal", 2927,
        "cm_ContextMenuInternalCursor", 2928,
        "cm_ShowRemoteMenu", 2930,
        "cm_SyncChangeDir", 2600,
        "cm_EditComment", 2700,
        "cm_FocusLeft", 4001,
        "cm_FocusRight", 4002,
        "cm_FocusCmdLine", 4003,
        "cm_FocusButtonBar", 4004,
        "cm_CountDirContent", 2014,
        "cm_UnloadPlugins", 2913,
        "cm_DirMatch", 534,
        "cm_Exchange", 531,
        "cm_MatchSrc", 532,
        "cm_ReloadSelThumbs", 2918,
        "cm_DirectCableConnect", 2300,
        "cm_NTinstallDriver", 2301,
        "cm_NTremoveDriver", 2302,
        "cm_PrintDir", 2027,
        "cm_PrintDirSub", 2028,
        "cm_PrintFile", 504,
        "cm_SpreadSelection", 521,
        "cm_SelectBoth", 3311,
        "cm_SelectFiles", 3312,
        "cm_SelectFolders", 3313,
        "cm_ShrinkSelection", 522,
        "cm_ClearFiles", 3314,
        "cm_ClearFolders", 3315,
        "cm_ClearSelCfg", 3316,
        "cm_SelectAll", 523,
        "cm_SelectAllBoth", 3301,
        "cm_SelectAllFiles", 3302,
        "cm_SelectAllFolders", 3303,
        "cm_ClearAll", 524,
        "cm_ClearAllFiles", 3304,
        "cm_ClearAllFolders", 3305,
        "cm_ClearAllCfg", 3306,
        "cm_ExchangeSelection", 525,
        "cm_ExchangeSelBoth", 3321,
        "cm_ExchangeSelFiles", 3322,
        "cm_ExchangeSelFolders", 3323,
        "cm_SelectCurrentExtension", 527,
        "cm_UnselectCurrentExtension", 528,
        "cm_SelectCurrentName", 541,
        "cm_UnselectCurrentName", 542,
        "cm_SelectCurrentNameExt", 543,
        "cm_UnselectCurrentNameExt", 544,
        "cm_SelectCurrentPath", 537,
        "cm_UnselectCurrentPath", 538,
        "cm_RestoreSelection", 529,
        "cm_SaveSelection", 530,
        "cm_SaveSelectionToFile", 2031,
        "cm_SaveSelectionToFileA", 2041,
        "cm_SaveSelectionToFileW", 2042,
        "cm_SaveDetailsToFile", 2039,
        "cm_SaveDetailsToFileA", 2043,
        "cm_SaveDetailsToFileW", 2044,
        "cm_LoadSelectionFromFile", 2032,
        "cm_LoadSelectionFromClip", 2033,
        "cm_EditPermissionInfo", 2200,
        "cm_EditAuditInfo", 2201,
        "cm_EditOwnerInfo", 2202,
        "cm_CutToClipboard", 2007,
        "cm_CopyToClipboard", 2008,
        "cm_PasteFromClipboard", 2009,
        "cm_CopyNamesToClip", 2017,
        "cm_CopyFullNamesToClip", 2018,
        "cm_CopyNetNamesToClip", 2021,
        "cm_CopySrcPathToClip", 2029,
        "cm_CopyTrgPathToClip", 2030,
        "cm_CopyFileDetailsToClip", 2036,
        "cm_CopyFpFileDetailsToClip", 2037,
        "cm_CopyNetFileDetailsToClip", 2038,
        "cm_FtpConnect", 550,
        "cm_FtpNew", 551,
        "cm_FtpDisconnect", 552,
        "cm_FtpHiddenFiles", 553,
        "cm_FtpAbort", 554,
        "cm_FtpResumeDownload", 555,
        "cm_FtpSelectTransferMode", 556,
        "cm_FtpAddToList", 557,
        "cm_FtpDownloadList", 558,
        "cm_GotoPreviousDir", 570,
        "cm_GotoNextDir", 571,
        "cm_DirectoryHistory", 572,
        "cm_GotoPreviousLocalDir", 573,
        "cm_GotoNextLocalDir", 574,
        "cm_DirectoryHotlist", 526,
        "cm_GoToRoot", 2001,
        "cm_GoToParent", 2002,
        "cm_GoToDir", 2003,
        "cm_OpenDesktop", 2121,
        "cm_OpenDrives", 2122,
        "cm_OpenControls", 2123,
        "cm_OpenFonts", 2124,
        "cm_OpenNetwork", 2125,
        "cm_OpenPrinters", 2126,
        "cm_OpenRecycled", 2127,
        "cm_CDtree", 500,
        "cm_TransferLeft", 2024,
        "cm_TransferRight", 2025,
        "cm_EditPath", 2912,
        "cm_GoToFirstFile", 2050,
        "cm_GotoNextDrive", 2051,
        "cm_GotoPreviousDrive", 2052,
        "cm_GotoNextSelected", 2053,
        "cm_GotoPrevSelected", 2054,
        "cm_GotoDriveA", 2061,
        "cm_GotoDriveC", 2063,
        "cm_GotoDriveD", 2064,
        "cm_GotoDriveE", 2065,
        "cm_GotoDriveF", 2066,
        "cm_GotoDriveZ", 2086,
        "cm_HelpIndex", 610,
        "cm_Keyboard", 620,
        "cm_Register", 630,
        "cm_VisitHomepage", 640,
        "cm_About", 690,
        "cm_Exit", 24340,
        "cm_Minimize", 2000,
        "cm_Maximize", 2015,
        "cm_Restore", 2016,
        "cm_ClearCmdLine", 2004,
        "cm_NextCommand", 2005,
        "cm_PrevCommand", 2006,
        "cm_AddPathToCmdline", 2019,
        "cm_MultiRenameFiles", 2400,
        "cm_SysInfo", 506,
        "cm_OpenTransferManager", 559,
        "cm_SearchFor", 501,
        "cm_SearchStandalone", 545,
        "cm_FileSync", 2020,
        "cm_Associate", 507,
        "cm_InternalAssociate", 519,
        "cm_CompareFilesByContent", 2022,
        "cm_IntCompareFilesByContent", 2040,
        "cm_CommandBrowser", 2924,
        "cm_VisButtonbar", 2901,
        "cm_VisDriveButtons", 2902,
        "cm_VisTwoDriveButtons", 2903,
        "cm_VisFlatDriveButtons", 2904,
        "cm_VisFlatInterface", 2905,
        "cm_VisDriveCombo", 2906,
        "cm_VisCurDir", 2907,
        "cm_VisBreadCrumbs", 2926,
        "cm_VisTabHeader", 2908,
        "cm_VisStatusbar", 2909,
        "cm_VisCmdLine", 2910,
        "cm_VisKeyButtons", 2911,
        "cm_ShowHint", 2914,
        "cm_ShowQuickSearch", 2915,
        "cm_SwitchLongNames", 2010,
        "cm_RereadSource", 540,
        "cm_ShowOnlySelected", 2023,
        "cm_SwitchHidSys", 2011,
        "cm_Switch83Names", 2013,
        "cm_SwitchDirSort", 2012,
        "cm_DirBranch", 2026,
        "cm_DirBranchSel", 2046,
        "cm_50Percent", 909,
        "cm_100Percent", 910,
        "cm_VisDirTabs", 2916,
        "cm_VisXPThemeBackground", 2923,
        "cm_SwitchOverlayIcons", 2917,
        "cm_VisHistHotButtons", 2919,
        "cm_SwitchWatchDirs", 2921,
        "cm_SwitchIgnoreList", 2922,
        "cm_SwitchX64Redirection", 2925,
        "cm_SeparateTreeOff", 3200,
        "cm_SeparateTree1", 3201,
        "cm_SeparateTree2", 3202,
        "cm_SwitchSeparateTree", 3203,
        "cm_ToggleSeparateTree1", 3204,
        "cm_ToggleSeparateTree2", 3205,
        "cm_UserMenu1", 701,
        "cm_UserMenu2", 702,
        "cm_UserMenu3", 703,
        "cm_UserMenu4", 704,
        "cm_UserMenu5", 70,
        "cm_UserMenu6", 70,
        "cm_UserMenu7", 70,
        "cm_UserMenu8", 70,
        "cm_UserMenu9", 70,
        "cm_UserMenu10", 710,
        "cm_OpenNewTab", 3001,
        "cm_OpenNewTabBg", 3002,
        "cm_OpenDirInNewTab", 3003,
        "cm_OpenDirInNewTabOther", 3004,
        "cm_SwitchToNextTab", 3005,
        "cm_SwitchToPreviousTab", 3006,
        "cm_CloseCurrentTab", 3007,
        "cm_CloseAllTabs", 3008,
        "cm_DirTabsShowMenu", 3009,
        "cm_ToggleLockCurrentTab", 3010,
        "cm_ToggleLockDcaCurrentTab", 3012,
        "cm_ExchangeWithTabs", 535,
        "cm_GoToLockedDir", 3011,
        "cm_SrcActivateTab1", 5001,
        "cm_SrcActivateTab2", 5002,
        "cm_SrcActivateTab3", 5003,
        "cm_SrcActivateTab4", 5004,
        "cm_SrcActivateTab5", 5005,
        "cm_SrcActivateTab6", 5006,
        "cm_SrcActivateTab7", 5007,
        "cm_SrcActivateTab8", 5008,
        "cm_SrcActivateTab9", 5009,
        "cm_SrcActivateTab10", 5010,
        "cm_TrgActivateTab1", 5101,
        "cm_TrgActivateTab2", 5102,
        "cm_TrgActivateTab3", 5103,
        "cm_TrgActivateTab4", 5104,
        "cm_TrgActivateTab5", 5105,
        "cm_TrgActivateTab6", 5106,
        "cm_TrgActivateTab7", 5107,
        "cm_TrgActivateTab8", 5108,
        "cm_TrgActivateTab9", 5109,
        "cm_TrgActivateTab10", 5110,
        "cm_LeftActivateTab1", 5201,
        "cm_LeftActivateTab2", 5202,
        "cm_LeftActivateTab3", 5203,
        "cm_LeftActivateTab4", 5204,
        "cm_LeftActivateTab5", 5205,
        "cm_LeftActivateTab6", 5206,
        "cm_LeftActivateTab7", 5207,
        "cm_LeftActivateTab8", 5208,
        "cm_LeftActivateTab9", 5209,
        "cm_LeftActivateTab10", 5210,
        "cm_RightActivateTab1", 5301,
        "cm_RightActivateTab2", 5302,
        "cm_RightActivateTab3", 5303,
        "cm_RightActivateTab4", 5304,
        "cm_RightActivateTab5", 5305,
        "cm_RightActivateTab6", 5306,
        "cm_RightActivateTab7", 5307,
        "cm_RightActivateTab8", 5308,
        "cm_RightActivateTab9", 5309,
        "cm_RightActivateTab10", 5310,
        "cm_SrcSortByCol1", 6001,
        "cm_SrcSortByCol2", 6002,
        "cm_SrcSortByCol3", 6003,
        "cm_SrcSortByCol4", 6004,
        "cm_SrcSortByCol5", 6005,
        "cm_SrcSortByCol6", 6006,
        "cm_SrcSortByCol7", 6007,
        "cm_SrcSortByCol8", 6008,
        "cm_SrcSortByCol9", 6009,
        "cm_SrcSortByCol10", 6010,
        "cm_SrcSortByCol99", 6099,
        "cm_TrgSortByCol1", 6101,
        "cm_TrgSortByCol2", 6102,
        "cm_TrgSortByCol3", 6103,
        "cm_TrgSortByCol4", 6104,
        "cm_TrgSortByCol5", 6105,
        "cm_TrgSortByCol6", 6106,
        "cm_TrgSortByCol7", 6107,
        "cm_TrgSortByCol8", 6108,
        "cm_TrgSortByCol9", 6109,
        "cm_TrgSortByCol10", 6110,
        "cm_TrgSortByCol99", 6199,
        "cm_LeftSortByCol1", 6201,
        "cm_LeftSortByCol2", 6202,
        "cm_LeftSortByCol3", 6203,
        "cm_LeftSortByCol4", 6204,
        "cm_LeftSortByCol5", 6205,
        "cm_LeftSortByCol6", 6206,
        "cm_LeftSortByCol7", 6207,
        "cm_LeftSortByCol8", 6208,
        "cm_LeftSortByCol9", 6209,
        "cm_LeftSortByCol10", 6210,
        "cm_LeftSortByCol99", 6299,
        "cm_RightSortByCol1", 6301,
        "cm_RightSortByCol2", 6302,
        "cm_RightSortByCol3", 6303,
        "cm_RightSortByCol4", 6304,
        "cm_RightSortByCol5", 6305,
        "cm_RightSortByCol6", 6306,
        "cm_RightSortByCol7", 6307,
        "cm_RightSortByCol8", 6308,
        "cm_RightSortByCol9", 6309,
        "cm_RightSortByCol10", 6310,
        "cm_RightSortByCol99", 6399,
        "cm_SrcCustomView1", 271,
        "cm_SrcCustomView2", 272,
        "cm_SrcCustomView3", 273,
        "cm_SrcCustomView4", 274,
        "cm_SrcCustomView5", 275,
        "cm_SrcCustomView6", 276,
        "cm_SrcCustomView7", 277,
        "cm_SrcCustomView8", 278,
        "cm_SrcCustomView9", 279,
        "cm_LeftCustomView1", 710,
        "cm_LeftCustomView2", 72,
        "cm_LeftCustomView3", 73,
        "cm_LeftCustomView4", 74,
        "cm_LeftCustomView5", 75,
        "cm_LeftCustomView6", 76,
        "cm_LeftCustomView7", 77,
        "cm_LeftCustomView8", 78,
        "cm_LeftCustomView9", 79,
        "cm_RightCustomView1", 171,
        "cm_RightCustomView2", 172,
        "cm_RightCustomView3", 173,
        "cm_RightCustomView4", 174,
        "cm_RightCustomView5", 175,
        "cm_RightCustomView6", 176,
        "cm_RightCustomView7", 177,
        "cm_RightCustomView8", 178,
        "cm_RightCustomView9", 179,
        "cm_SrcNextCustomView", 5501,
        "cm_SrcPrevCustomView", 5502,
        "cm_TrgNextCustomView", 5503,
        "cm_TrgPrevCustomView", 5504,
        "cm_LeftNextCustomView", 5505,
        "cm_LeftPrevCustomView", 5506,
        "cm_RightNextCustomView", 5507,
        "cm_RightPrevCustomView", 5508,
        "cm_LoadAllOnDemandFields", 5512,
        "cm_LoadSelOnDemandFields", 5513,
        "cm_ContentStopLoadFields", 5514,
        "cm_GoToFirstEntry", 2049,
        "cm_FocusSrc", 4005,
        "cm_FocusTrg", 4006
    )

    if cmdMap.Has(cmdName)
        return cmdMap[cmdName]
    ; Map 字符串键区分大小写, 但 ini 里常见 <cm_edit>/<cm_config> 等小写写法 (原版不敏感):
    ; 降级为不敏感查找, 找不到才返回 0 (否则回落调不存在的函数, 按键静默死亡)
    lower := StrLower(cmdName)
    for k, v in cmdMap {
        if (StrLower(k) = lower)
            return v
    }
    return 0
}

; === TC 64位支持 ===
FixTCEditId() {
    global TCListBox, TCListBox1, TCListBox2, isTC64

    if isTC64 {
        TCListBox := "LCLListBox"
        TCListBox1 := "LCLListBox1"
        TCListBox2 := "LCLListBox2"
    } else {
        TCListBox := "TMyListBox"
        TCListBox1 := "TMyListBox1"
        TCListBox2 := "TMyListBox2"
    }
}

; === 面板检测 ===
; 通过控件位置判断当前活动面板是左侧还是右侧
TC_LeftRight() {
    global TCListBox1, TCListBox2

    try {
        ; 获取两个列表框的位置
        ControlGetPos(&x1, &y1, &w1, &h1, TCListBox1, "ahk_class TTOTAL_CMD")
        ControlGetPos(&x2, &y2, &w2, &h2, TCListBox2, "ahk_class TTOTAL_CMD")

        ; 获取当前焦点控件 (类名, v2 原生返回 HWND)
        focused := ""
        try focused := FocusedClassNN("ahk_class TTOTAL_CMD")

        ; 判断焦点在哪个面板
        if InStr(focused, TCListBox1) {
            return "left"
        } else if InStr(focused, TCListBox2) {
            return "right"
        }

        ; 备用：通过鼠标位置判断
        MouseGetPos(&mx, &my, &mWin)
        if (mWin = WinExist("ahk_class TTOTAL_CMD")) {
            midX := x1 + w1 + (x2 - (x1 + w1)) // 2
            if (mx < midX)
                return "left"
            else
                return "right"
        }
    }
    return "left"  ; 默认左侧
}

; === TC 预检查 (1:1 对原版 TC_BeforeActionDo: 菜单开+上次非 572→透传; 列表内执行, 其余透传) ===
; 原版: Ifinstring ctrl TCListBox (64 位 "LCLListBox" 含 1/2 后缀) → False(执行)
TC_BeforeActionDo(actionName, win) {
    global g_TCLastCmd
    ; 有弹出菜单 → 透传 (除非上次发的就是 572 目录历史类, 对原版 TC_SendPos<>572)
    if WinExist("ahk_class #32768") && g_TCLastCmd != 572
        return true

    ; 焦点在列表框 → 执行动作 (v2 取焦点类名, 不是 HWND 比串)
    focused := FocusedClassNN("ahk_class TTOTAL_CMD")
    if InStr(focused, "LCLListBox") || InStr(focused, "TMyListBox")
        return false
    return true
}

RegisterPlugin_TotalCommander() {
    ; 检测 TC 路径
    DetectTCPath()

    ; 修复 64 位控件 ID
    FixTCEditId()


    ; 中文注释表 (517 条, 抽自原版 vim.Comment, 供 g 提示面板显示; 后续特化注册可覆盖措辞)
    RegisterAction("<cm_100Percent>", "窗口分隔栏位于 100% TC 8.0+")
    RegisterAction("<cm_50Percent>", "窗口分隔栏位于 50%")
    RegisterAction("<cm_About>", "关于 Total Commander")
    RegisterAction("<cm_AddPathToCmdline>", "将路径复制到命令行")
    RegisterAction("<cm_AdministerServer>", "显示系统共享文件夹")
    RegisterAction("<cm_Associate>", "文件关联")
    RegisterAction("<cm_ButtonConfig>", "更改工具栏")
    RegisterAction("<cm_CDtree>", "更改文件夹")
    RegisterAction("<cm_ChangeStartMenu>", "更改开始菜单")
    RegisterAction("<cm_ClearAll>", "全部取消: 文件和文件夹")
    RegisterAction("<cm_ClearAllCfg>", "全部取消: 文件和/或文件夹(视配置而定)")
    RegisterAction("<cm_ClearAllFiles>", "全部取消: 仅文件")
    RegisterAction("<cm_ClearAllFolders>", "全部取消: 仅文件夹")
    RegisterAction("<cm_ClearCmdLine>", "清除命令行")
    RegisterAction("<cm_ClearFiles>", "不选一组: 仅文件")
    RegisterAction("<cm_ClearFolders>", "不选一组: 仅文件夹")
    RegisterAction("<cm_ClearSelCfg>", "不选一组: 文件和/或文件夹(视配置而定)")
    RegisterAction("<cm_CloseAllTabs>", "关闭所有标签")
    RegisterAction("<cm_CloseCurrentTab>", "关闭当前标签")
    RegisterAction("<cm_ColorConfig>", "配置: 颜色")
    RegisterAction("<cm_Combine>", "合并文件")
    RegisterAction("<cm_CommandBrowser>", "浏览内部命令")
    RegisterAction("<cm_CompareDirs>", "比较文件夹")
    RegisterAction("<cm_CompareDirsWithSubdirs>", "比较文件夹(同时标出另一窗口没有的子文件夹)")
    RegisterAction("<cm_CompareFilesByContent>", "比较文件内容")
    RegisterAction("<cm_Config>", "配置: 布局")
    RegisterAction("<cm_Config2>", "配置: 操作方式")
    RegisterAction("<cm_ConfigChangeIniFiles>", "直接修改配置文件")
    RegisterAction("<cm_ConfigSaveDirHistory>", "保存文件夹历史记录")
    RegisterAction("<cm_ConfigSavePos>", "保存位置")
    RegisterAction("<cm_ConfigSaveSettings>", "保存设置")
    RegisterAction("<cm_Confirmation>", "配置: 其他/确认")
    RegisterAction("<cm_ConfTabChange>", "配置: 制表符")
    RegisterAction("<cm_ContentStopLoadFields>", "停止后台加载备注")
    RegisterAction("<cm_ContextMenu>", "显示快捷菜单")
    RegisterAction("<cm_ContextMenuInternal>", "显示快捷菜单(内部关联)")
    RegisterAction("<cm_ContextMenuInternalCursor>", "显示光标处文件的内部关联快捷菜单")
    RegisterAction("<cm_Copy>", "复制")
    RegisterAction("<cm_CopyConfig>", "配置: 复制/删除")
    RegisterAction("<cm_CopyFileDetailsToClip>", "复制文件详细信息")
    RegisterAction("<cm_CopyFpFileDetailsToClip>", "复制文件详细信息及完整路径")
    RegisterAction("<cm_CopyFullNamesToClip>", "复制文件名及完整路径")
    RegisterAction("<cm_CopyNamesToClip>", "复制文件名")
    RegisterAction("<cm_CopyNetFileDetailsToClip>", "复制文件详细信息及网络路径")
    RegisterAction("<cm_CopyNetNamesToClip>", "复制文件名及网络路径")
    RegisterAction("<cm_CopyOtherpanel>", "复制到另一窗口(F5)")
    RegisterAction("<cm_CopySamepanel>", "复制到当前窗口")
    RegisterAction("<cm_CopySrcPathToClip>", "复制来源路径")
    RegisterAction("<cm_CopyToClipboard>", "复制选中的文件到剪贴板")
    RegisterAction("<cm_CopyTrgPathToClip>", "复制目标路径")
    RegisterAction("<cm_CountDirContent>", "计算所有文件夹占用的空间")
    RegisterAction("<cm_CRCcheck>", "验证校验和")
    RegisterAction("<cm_CRCcreate>", "创建校验文件")
    RegisterAction("<cm_CreateShortcut>", "创建快捷方式")
    RegisterAction("<cm_CustomColumnConfig>", "配置: 自定义列")
    RegisterAction("<cm_CustomColumnDlg>", "更改当前自定义列")
    RegisterAction("<cm_CutToClipboard>", "剪切选中的文件到剪贴板")
    RegisterAction("<cm_Decode>", "解码文件(MIME/UUE/XXE/BinHex 格式)")
    RegisterAction("<cm_Delete>", "删除")
    RegisterAction("<cm_DirBranch>", "展开所有文件夹")
    RegisterAction("<cm_DirBranchSel>", "只展开选中的文件夹")
    RegisterAction("<cm_DirectCableConnect>", "直接电缆连接")
    RegisterAction("<cm_DirectoryHistory>", "文件夹历史记录")
    RegisterAction("<cm_DirectoryHotlist>", "常用文件夹")
    RegisterAction("<cm_DirMatch>", "标出新文件, 隐藏相同者")
    RegisterAction("<cm_DirTabsConfig>", "配置: 文件夹标签")
    RegisterAction("<cm_DirTabsShowMenu>", "显示标签菜单")
    RegisterAction("<cm_DisplayConfig>", "配置: 显示")
    RegisterAction("<cm_Edit>", "编辑")
    RegisterAction("<cm_EditAuditInfo>", "审核文件(NTFS)")
    RegisterAction("<cm_EditComment>", "编辑文件备注")
    RegisterAction("<cm_EditConfig>", "配置: 编辑/查看")
    RegisterAction("<cm_EditOwnerInfo>", "获取所有权(NTFS)")
    RegisterAction("<cm_EditPath>", "编辑来源窗口的路径")
    RegisterAction("<cm_EditPermissionInfo>", "设置权限(NTFS)")
    RegisterAction("<cm_Encode>", "编码文件(MIME/UUE/XXE 格式)")
    RegisterAction("<cm_Exchange>", "交换左右窗口")
    RegisterAction("<cm_ExchangeSelBoth>", "反向选择: 文件和文件夹")
    RegisterAction("<cm_ExchangeSelection>", "反向选择")
    RegisterAction("<cm_ExchangeSelFiles>", "反向选择: 仅文件")
    RegisterAction("<cm_ExchangeSelFolders>", "反向选择: 仅文件夹")
    RegisterAction("<cm_ExchangeWithTabs>", "交换左右窗口及其标签")
    RegisterAction("<cm_ExecuteDOS>", "打开命令提示符窗口")
    RegisterAction("<cm_Exit>", "退出 Total Commander")
    RegisterAction("<cm_FileSync>", "同步文件夹")
    RegisterAction("<cm_FocusButtonBar>", "焦点置于工具栏")
    RegisterAction("<cm_FocusCmdLine>", "焦点置于命令行")
    RegisterAction("<cm_FocusLeft>", "焦点置于左窗口")
    RegisterAction("<cm_FocusRight>", "焦点置于右窗口")
    RegisterAction("<cm_FocusSrc>", "光标切换至源面板")
    RegisterAction("<cm_FocusTrg>", "光标切换至目标面板")
    RegisterAction("<cm_FontConfig>", "配置: 字体")
    RegisterAction("<cm_FtpAbort>", "中止当前 FTP 命令")
    RegisterAction("<cm_FtpAddToList>", "添加到下载列表")
    RegisterAction("<cm_FtpConfig>", "配置: FTP")
    RegisterAction("<cm_FtpConnect>", "FTP 连接")
    RegisterAction("<cm_FtpDisconnect>", "断开 FTP 连接")
    RegisterAction("<cm_FtpDownloadList>", "按列表下载")
    RegisterAction("<cm_FtpHiddenFiles>", "显示隐藏文件")
    RegisterAction("<cm_FtpNew>", "新建 FTP 连接")
    RegisterAction("<cm_FtpResumeDownload>", "续传")
    RegisterAction("<cm_FtpSelectTransferMode>", "选择传输模式")
    RegisterAction("<cm_GetFileSpace>", "计算占用空间")
    RegisterAction("<cm_GoToDir>", "打开光标处的文件夹或压缩包")
    RegisterAction("<cm_GotoDriveA>", "转到驱动器 A")
    RegisterAction("<cm_GotoDriveC>", "转到驱动器 C")
    RegisterAction("<cm_GotoDriveD>", "转到驱动器 D")
    RegisterAction("<cm_GotoDriveE>", "转到驱动器 E")
    RegisterAction("<cm_GotoDriveF>", "可自定义其他驱动器")
    RegisterAction("<cm_GotoDriveZ>", "最多 26 个")
    RegisterAction("<cm_GoToFirstEntry>", "光标移到列表中的第一个文件或目录")
    RegisterAction("<cm_GoToFirstFile>", "光标移到列表中的第一个文件")
    RegisterAction("<cm_GoToLockedDir>", "转到锁定标签的根文件夹")
    RegisterAction("<cm_GotoNextDir>", "前进")
    RegisterAction("<cm_GotoNextDrive>", "转到下一个驱动器")
    RegisterAction("<cm_GotoNextLocalDir>", "前进(非 FTP)")
    RegisterAction("<cm_GotoNextSelected>", "转到下一个选中的文件")
    RegisterAction("<cm_GoToParent>", "转到上层文件夹")
    RegisterAction("<cm_GotoPreviousDir>", "后退")
    RegisterAction("<cm_GotoPreviousDrive>", "转到上一个驱动器")
    RegisterAction("<cm_GotoPreviousLocalDir>", "后退(非 FTP)")
    RegisterAction("<cm_GotoPrevSelected>", "转到上一个选中的文件")
    RegisterAction("<cm_GoToRoot>", "转到根文件夹")
    RegisterAction("<cm_HelpIndex>", "帮助索引")
    RegisterAction("<cm_IconConfig>", "配置: 图标")
    RegisterAction("<cm_IgnoreConfig>", "配置: 隐藏文件")
    RegisterAction("<cm_IntCompareFilesByContent>", "使用内部比较程序")
    RegisterAction("<cm_InternalAssociate>", "定义内部关联")
    RegisterAction("<cm_Keyboard>", "快捷键列表")
    RegisterAction("<cm_LanguageConfig>", "配置: 语言")
    RegisterAction("<cm_LeftActivateTab1>", "左窗口: 激活标签 1")
    RegisterAction("<cm_LeftActivateTab10>", "左窗口: 激活标签 10")
    RegisterAction("<cm_LeftActivateTab2>", "左窗口: 激活标签 2")
    RegisterAction("<cm_LeftActivateTab3>", "左窗口: 激活标签 3")
    RegisterAction("<cm_LeftActivateTab4>", "左窗口: 激活标签 4")
    RegisterAction("<cm_LeftActivateTab5>", "左窗口: 激活标签 5")
    RegisterAction("<cm_LeftActivateTab6>", "左窗口: 激活标签 6")
    RegisterAction("<cm_LeftActivateTab7>", "左窗口: 激活标签 7")
    RegisterAction("<cm_LeftActivateTab8>", "左窗口: 激活标签 8")
    RegisterAction("<cm_LeftActivateTab9>", "左窗口: 激活标签 9")
    RegisterAction("<cm_LeftAllFiles>", "左窗口: 所有文件")
    RegisterAction("<cm_LeftByDateTime>", "左窗口: 按日期时间排序")
    RegisterAction("<cm_LeftByExt>", "左窗口: 按扩展名排序")
    RegisterAction("<cm_LeftByName>", "左窗口: 按文件名排序")
    RegisterAction("<cm_LeftBySize>", "左窗口: 按大小排序")
    RegisterAction("<cm_LeftComments>", "左窗口: 显示文件备注")
    RegisterAction("<cm_LeftCustomView1>", "左窗口: 自定义列视图 1")
    RegisterAction("<cm_LeftCustomView10>", "左窗口: 自定义列视图 10")
    RegisterAction("<cm_LeftCustomView2>", "左窗口: 自定义列视图 2")
    RegisterAction("<cm_LeftCustomView3>", "左窗口: 自定义列视图 3")
    RegisterAction("<cm_LeftCustomView4>", "左窗口: 自定义列视图 4")
    RegisterAction("<cm_LeftCustomView5>", "左窗口: 自定义列视图 5")
    RegisterAction("<cm_LeftCustomView6>", "左窗口: 自定义列视图 6")
    RegisterAction("<cm_LeftCustomView7>", "左窗口: 自定义列视图 7")
    RegisterAction("<cm_LeftCustomView8>", "左窗口: 自定义列视图 8")
    RegisterAction("<cm_LeftCustomView9>", "左窗口: 自定义列视图 9")
    RegisterAction("<cm_LeftCustomViewMenu>", "窗口: 自定义视图菜单")
    RegisterAction("<cm_LeftDirBranch>", "左窗口: 展开所有文件夹")
    RegisterAction("<cm_LeftDirBranchSel>", "左窗口: 只展开选中的文件夹")
    RegisterAction("<cm_LeftExecs>", "左窗口: 可执行文件")
    RegisterAction("<cm_LeftHideQuickview>", "左窗口: 关闭快速查看窗口")
    RegisterAction("<cm_LeftLong>", "左窗口: 详细信息")
    RegisterAction("<cm_LeftNegOrder>", "左窗口: 反向排序")
    RegisterAction("<cm_LeftNextCustomView>", "左窗口: 下一个自定义视图")
    RegisterAction("<cm_LeftOpenDrives>", "左窗口: 打开驱动器列表")
    RegisterAction("<cm_LeftPathFocus>", "左窗口: 焦点置于路径上")
    RegisterAction("<cm_LeftPrevCustomView>", "左窗口: 上一个自定义视图")
    RegisterAction("<cm_LeftQuickInternalOnly>", "左窗口: 快速查看(不用插件)")
    RegisterAction("<cm_LeftQuickview>", "左窗口: 快速查看")
    RegisterAction("<cm_LeftShort>", "左窗口: 列表")
    RegisterAction("<cm_LeftSortByCol1>", "左窗口: 按第 1 列排序")
    RegisterAction("<cm_LeftSortByCol10>", "左窗口: 按第 10 列排序")
    RegisterAction("<cm_LeftSortByCol2>", "左窗口: 按第 2 列排序")
    RegisterAction("<cm_LeftSortByCol3>", "左窗口: 按第 3 列排序")
    RegisterAction("<cm_LeftSortByCol4>", "左窗口: 按第 4 列排序")
    RegisterAction("<cm_LeftSortByCol5>", "左窗口: 按第 5 列排序")
    RegisterAction("<cm_LeftSortByCol6>", "左窗口: 按第 6 列排序")
    RegisterAction("<cm_LeftSortByCol7>", "左窗口: 按第 7 列排序")
    RegisterAction("<cm_LeftSortByCol8>", "左窗口: 按第 8 列排序")
    RegisterAction("<cm_LeftSortByCol9>", "左窗口: 按第 9 列排序")
    RegisterAction("<cm_LeftThumbs>", "窗口: 缩略图")
    RegisterAction("<cm_LeftTree>", "左窗口: 文件夹树")
    RegisterAction("<cm_LeftUnsorted>", "左窗口: 不排序")
    RegisterAction("<cm_LeftUserDef>", "左窗口: 自定义类型")
    RegisterAction("<cm_LeftUserSpec>", "左窗口: 上次选中的文件")
    RegisterAction("<cm_List>", "查看(用查看程序)")
    RegisterAction("<cm_ListInternalOnly>", "查看(用查看程序, 但不用插件/多媒体)")
    RegisterAction("<cm_LoadAllOnDemandFields>", "所有文件都按需加载备注")
    RegisterAction("<cm_LoadSelectionFromClip>", "导入选择列表(从剪贴板)")
    RegisterAction("<cm_LoadSelectionFromFile>", "导入选择列表(从文件)")
    RegisterAction("<cm_LoadSelOnDemandFields>", "仅选中的文件按需加载备注")
    RegisterAction("<cm_LogConfig>", "配置: 日志文件")
    RegisterAction("<cm_MatchSrc>", "目标 = 来源")
    RegisterAction("<cm_Maximize>", "最大化 Total Commander")
    RegisterAction("<cm_Minimize>", "最小化 Total Commander")
    RegisterAction("<cm_MkDir>", "新建文件夹")
    RegisterAction("<cm_MoveOnly>", "移动到另一个窗口(F6)")
    RegisterAction("<cm_MultiRenameFiles>", "批量重命名")
    RegisterAction("<cm_NetConnect>", "映射网络驱动器")
    RegisterAction("<cm_NetDisconnect>", "断开网络驱动器")
    RegisterAction("<cm_NetShareDir>", "共享当前文件夹")
    RegisterAction("<cm_NetUnshareDir>", "取消文件夹共享")
    RegisterAction("<cm_NextCommand>", "下一条命令")
    RegisterAction("<cm_NTinstallDriver>", "加载 NT 并口驱动程序")
    RegisterAction("<cm_NTremoveDriver>", "卸载 NT 并口驱动程序")
    RegisterAction("<cm_OpenAsUser>", "以其他用户身份运行光标处的程序")
    RegisterAction("<cm_OpenControls>", "控制面板")
    RegisterAction("<cm_OpenDesktop>", "桌面")
    RegisterAction("<cm_OpenDirInNewTab>", "新建标签(并打开光标处的文件夹)")
    RegisterAction("<cm_OpenDirInNewTabOther>", "新建标签(在另一窗口打开文件夹)")
    RegisterAction("<cm_OpenDrives>", "我的电脑")
    RegisterAction("<cm_OpenFonts>", "字体")
    RegisterAction("<cm_OpenNetwork>", "网上邻居")
    RegisterAction("<cm_OpenNewTab>", "新建标签")
    RegisterAction("<cm_OpenNewTabBg>", "新建标签(在后台)")
    RegisterAction("<cm_OpenPrinters>", "打印机")
    RegisterAction("<cm_OpenRecycled>", "回收站")
    RegisterAction("<cm_OpenTransferManager>", "后台传输管理器")
    RegisterAction("<cm_PackerConfig>", "配置: 压缩程序")
    RegisterAction("<cm_PackFiles>", "压缩文件")
    RegisterAction("<cm_PasteFromClipboard>", "从剪贴板粘贴到当前文件夹")
    RegisterAction("<cm_PluginsConfig>", "配置: 插件")
    RegisterAction("<cm_PrevCommand>", "上一条命令")
    RegisterAction("<cm_PrintDir>", "打印文件列表")
    RegisterAction("<cm_PrintDirSub>", "打印文件列表(含子文件夹)")
    RegisterAction("<cm_PrintFile>", "打印文件内容")
    RegisterAction("<cm_Properties>", "显示属性")
    RegisterAction("<cm_QuickSearchConfig>", "配置: 快速搜索")
    RegisterAction("<cm_RefreshConfig>", "配置: 刷新")
    RegisterAction("<cm_Register>", "注册信息")
    RegisterAction("<cm_ReloadSelThumbs>", "刷新选中文件的缩略图")
    RegisterAction("<cm_RenameOnly>", "重命名(Shift+F6)")
    RegisterAction("<cm_RenameSingleFile>", "重命名当前文件")
    RegisterAction("<cm_RenMov>", "重命名/移动")
    RegisterAction("<cm_RereadSource>", "刷新来源窗口")
    RegisterAction("<cm_Restore>", "恢复正常大小")
    RegisterAction("<cm_RestoreSelection>", "恢复选择列表")
    RegisterAction("<cm_Return>", "模仿按 ENTER 键")
    RegisterAction("<cm_RightActivateTab1>", "右窗口: 激活标签 1")
    RegisterAction("<cm_RightActivateTab10>", "右窗口: 激活标签 10")
    RegisterAction("<cm_RightActivateTab2>", "右窗口: 激活标签 2")
    RegisterAction("<cm_RightActivateTab3>", "右窗口: 激活标签 3")
    RegisterAction("<cm_RightActivateTab4>", "右窗口: 激活标签 4")
    RegisterAction("<cm_RightActivateTab5>", "右窗口: 激活标签 5")
    RegisterAction("<cm_RightActivateTab6>", "右窗口: 激活标签 6")
    RegisterAction("<cm_RightActivateTab7>", "右窗口: 激活标签 7")
    RegisterAction("<cm_RightActivateTab8>", "右窗口: 激活标签 8")
    RegisterAction("<cm_RightActivateTab9>", "右窗口: 激活标签 9")
    RegisterAction("<cm_RightAllFile>", "右窗口: 所有文件")
    RegisterAction("<cm_RightByDateTim>", "右窗口: 按日期时间排序")
    RegisterAction("<cm_RightByEx>", "右窗口: 按扩展名排序")
    RegisterAction("<cm_RightByNam>", "右窗口: 按文件名排序")
    RegisterAction("<cm_RightBySiz>", "右窗口: 按大小排序")
    RegisterAction("<cm_RightComments>", "右窗口: 显示文件备注")
    RegisterAction("<cm_RightCustomView1>", "右窗口: 自定义列视图 1")
    RegisterAction("<cm_RightCustomView10>", "右窗口: 自定义列视图 10")
    RegisterAction("<cm_RightCustomView2>", "右窗口: 自定义列视图 2")
    RegisterAction("<cm_RightCustomView3>", "右窗口: 自定义列视图 3")
    RegisterAction("<cm_RightCustomView4>", "右窗口: 自定义列视图 4")
    RegisterAction("<cm_RightCustomView5>", "右窗口: 自定义列视图 5")
    RegisterAction("<cm_RightCustomView6>", "右窗口: 自定义列视图 6")
    RegisterAction("<cm_RightCustomView7>", "右窗口: 自定义列视图 7")
    RegisterAction("<cm_RightCustomView8>", "右窗口: 自定义列视图 8")
    RegisterAction("<cm_RightCustomView9>", "右窗口: 自定义列视图 9")
    RegisterAction("<cm_RightCustomViewMen>", "右窗口: 自定义视图菜单")
    RegisterAction("<cm_RightDirBranch>", "右窗口: 展开所有文件夹")
    RegisterAction("<cm_RightDirBranchSel>", "右窗口: 只展开选中的文件夹")
    RegisterAction("<cm_RightExec>", "右窗口: 可执行文件")
    RegisterAction("<cm_RightHideQuickvie>", "右窗口: 关闭快速查看窗口")
    RegisterAction("<cm_RightLong>", "详细信息")
    RegisterAction("<cm_RightNegOrde>", "右窗口: 反向排序")
    RegisterAction("<cm_RightNextCustomView>", "右窗口: 下一个自定义视图")
    RegisterAction("<cm_RightOpenDrives>", "右窗口: 打开驱动器列表")
    RegisterAction("<cm_RightPathFocu>", "右窗口: 焦点置于路径上")
    RegisterAction("<cm_RightPrevCustomView>", "右窗口: 上一个自定义视图")
    RegisterAction("<cm_RightQuickInternalOnl>", "右窗口: 快速查看(不用插件)")
    RegisterAction("<cm_RightQuickvie>", "右窗口: 快速查看")
    RegisterAction("<cm_RightShort>", "右窗口: 列表")
    RegisterAction("<cm_RightSortByCol1>", "右窗口: 按第 1 列排序")
    RegisterAction("<cm_RightSortByCol10>", "右窗口: 按第 10 列排序")
    RegisterAction("<cm_RightSortByCol2>", "右窗口: 按第 2 列排序")
    RegisterAction("<cm_RightSortByCol3>", "右窗口: 按第 3 列排序")
    RegisterAction("<cm_RightSortByCol4>", "右窗口: 按第 4 列排序")
    RegisterAction("<cm_RightSortByCol5>", "右窗口: 按第 5 列排序")
    RegisterAction("<cm_RightSortByCol6>", "右窗口: 按第 6 列排序")
    RegisterAction("<cm_RightSortByCol7>", "右窗口: 按第 7 列排序")
    RegisterAction("<cm_RightSortByCol8>", "右窗口: 按第 8 列排序")
    RegisterAction("<cm_RightSortByCol9>", "右窗口: 按第 9 列排序")
    RegisterAction("<cm_RightThumb>", "右窗口: 缩略图")
    RegisterAction("<cm_RightTree>", "右窗口: 文件夹树")
    RegisterAction("<cm_RightUnsorte>", "右窗口: 不排序")
    RegisterAction("<cm_RightUserDe>", "右窗口: 自定义类型")
    RegisterAction("<cm_RightUserSpe>", "右窗口: 上次选中的文件")
    RegisterAction("<cm_SaveDetailsToFile>", "导出详细信息")
    RegisterAction("<cm_SaveDetailsToFileA>", "导出详细信息(ANSI)")
    RegisterAction("<cm_SaveDetailsToFileW>", "导出详细信息(Unicode)")
    RegisterAction("<cm_SaveSelection>", "保存选择列表")
    RegisterAction("<cm_SaveSelectionToFile>", "导出选择列表")
    RegisterAction("<cm_SaveSelectionToFileA>", "导出选择列表(ANSI)")
    RegisterAction("<cm_SaveSelectionToFileW>", "导出选择列表(Unicode)")
    RegisterAction("<cm_SearchFor>", "搜索文件")
    RegisterAction("<cm_SearchStandalone>", "在单独进程搜索文件")
    RegisterAction("<cm_SelectAll>", "全部选择: 文件和/或文件夹(视配置而定)")
    RegisterAction("<cm_SelectAllBoth>", "全部选择: 文件和文件夹")
    RegisterAction("<cm_SelectAllFiles>", "全部选择: 仅文件")
    RegisterAction("<cm_SelectAllFolders>", "全部选择: 仅文件夹")
    RegisterAction("<cm_SelectBoth>", "选择一组: 文件和文件夹")
    RegisterAction("<cm_SelectCurrentExtension>", "选择扩展名相同的文件")
    RegisterAction("<cm_SelectCurrentName>", "选择文件名相同的文件")
    RegisterAction("<cm_SelectCurrentNameExt>", "选择文件名和扩展名相同的文件")
    RegisterAction("<cm_SelectCurrentPath>", "选择同一路径下的文件(展开文件夹+搜索文件)")
    RegisterAction("<cm_SelectFiles>", "选择一组: 仅文件")
    RegisterAction("<cm_SelectFolders>", "选择一组: 仅文件夹")
    RegisterAction("<cm_SeparateTree1>", "一个独立文件夹树面板")
    RegisterAction("<cm_SeparateTree2>", "两个独立文件夹树面板")
    RegisterAction("<cm_SeparateTreeOff>", "关闭独立文件夹树面板")
    RegisterAction("<cm_SetAttrib>", "更改属性")
    RegisterAction("<cm_ShowFileUser>", "显示本地文件的远程用户")
    RegisterAction("<cm_ShowHint>", "显示文件提示")
    RegisterAction("<cm_ShowOnlySelected>", "仅显示选中的文件")
    RegisterAction("<cm_ShowQuickSearch>", "显示快速搜索窗口")
    RegisterAction("<cm_ShowRemoteMenu>", "媒体中心遥控器播放/暂停键快捷菜单")
    RegisterAction("<cm_ShrinkSelection>", "不选一组文件")
    RegisterAction("<cm_Split>", "分割文件")
    RegisterAction("<cm_SpreadSelection>", "选择一组文件")
    RegisterAction("<cm_SrcActivateTab1>", "来源窗口: 激活标签 1")
    RegisterAction("<cm_SrcActivateTab10>", "来源窗口: 激活标签 10")
    RegisterAction("<cm_SrcActivateTab2>", "来源窗口: 激活标签 2")
    RegisterAction("<cm_SrcActivateTab3>", "来源窗口: 激活标签 3")
    RegisterAction("<cm_SrcActivateTab4>", "来源窗口: 激活标签 4")
    RegisterAction("<cm_SrcActivateTab5>", "来源窗口: 激活标签 5")
    RegisterAction("<cm_SrcActivateTab6>", "来源窗口: 激活标签 6")
    RegisterAction("<cm_SrcActivateTab7>", "来源窗口: 激活标签 7")
    RegisterAction("<cm_SrcActivateTab8>", "来源窗口: 激活标签 8")
    RegisterAction("<cm_SrcActivateTab9>", "来源窗口: 激活标签 9")
    RegisterAction("<cm_SrcAllFiles>", "来源窗口: 所有文件")
    RegisterAction("<cm_SrcByDateTime>", "来源窗口: 按日期时间排序")
    RegisterAction("<cm_SrcByExt>", "来源窗口: 按扩展名排序")
    RegisterAction("<cm_SrcByName>", "来源窗口: 按文件名排序")
    RegisterAction("<cm_SrcBySize>", "来源窗口: 按大小排序")
    RegisterAction("<cm_SrcComments>", "来源窗口: 显示文件备注")
    RegisterAction("<cm_SrcCustomView1>", "来源窗口: 自定义列视图 1")
    RegisterAction("<cm_SrcCustomView10>", "来源窗口: 自定义列视图 10")
    RegisterAction("<cm_SrcCustomView2>", "来源窗口: 自定义列视图 2")
    RegisterAction("<cm_SrcCustomView3>", "来源窗口: 自定义列视图 3")
    RegisterAction("<cm_SrcCustomView4>", "来源窗口: 自定义列视图 4")
    RegisterAction("<cm_SrcCustomView5>", "来源窗口: 自定义列视图 5")
    RegisterAction("<cm_SrcCustomView6>", "来源窗口: 自定义列视图 6")
    RegisterAction("<cm_SrcCustomView7>", "来源窗口: 自定义列视图 7")
    RegisterAction("<cm_SrcCustomView8>", "来源窗口: 自定义列视图 8")
    RegisterAction("<cm_SrcCustomView9>", "来源窗口: 自定义列视图 9")
    RegisterAction("<cm_SrcCustomViewMenu>", "来源窗口: 自定义视图菜单")
    RegisterAction("<cm_SrcExecs>", "来源窗口: 可执行文件")
    RegisterAction("<cm_SrcHideQuickview>", "来源窗口: 关闭快速查看窗口")
    RegisterAction("<cm_SrcLong>", "来源窗口: 详细信息")
    RegisterAction("<cm_SrcNegOrder>", "来源窗口: 反向排序")
    RegisterAction("<cm_SrcNextCustomView>", "来源窗口: 下一个自定义视图")
    RegisterAction("<cm_SrcOpenDrives>", "来源窗口: 打开驱动器列表")
    RegisterAction("<cm_SrcPathFocus>", "来源窗口: 焦点置于路径上")
    RegisterAction("<cm_SrcPrevCustomView>", "来源窗口: 上一个自定义视图")
    RegisterAction("<cm_SrcQuickInternalOnly>", "来源窗口: 快速查看(不用插件)")
    RegisterAction("<cm_SrcQuickview>", "来源窗口: 快速查看")
    RegisterAction("<cm_SrcShort>", "来源窗口: 列表")
    RegisterAction("<cm_SrcSortByCol1>", "来源窗口: 按第 1 列排序")
    RegisterAction("<cm_SrcSortByCol10>", "来源窗口: 按第 10 列排序")
    RegisterAction("<cm_SrcSortByCol2>", "来源窗口: 按第 2 列排序")
    RegisterAction("<cm_SrcSortByCol3>", "来源窗口: 按第 3 列排序")
    RegisterAction("<cm_SrcSortByCol4>", "来源窗口: 按第 4 列排序")
    RegisterAction("<cm_SrcSortByCol5>", "来源窗口: 按第 5 列排序")
    RegisterAction("<cm_SrcSortByCol6>", "来源窗口: 按第 6 列排序")
    RegisterAction("<cm_SrcSortByCol7>", "来源窗口: 按第 7 列排序")
    RegisterAction("<cm_SrcSortByCol8>", "来源窗口: 按第 8 列排序")
    RegisterAction("<cm_SrcSortByCol9>", "来源窗口: 按第 9 列排序")
    RegisterAction("<cm_SrcThumbs>", "来源窗口: 缩略图")
    RegisterAction("<cm_SrcTree>", "来源窗口: 文件夹树")
    RegisterAction("<cm_SrcUnsorted>", "来源窗口: 不排序")
    RegisterAction("<cm_SrcUserDef>", "来源窗口: 自定义类型")
    RegisterAction("<cm_SrcUserSpec>", "来源窗口: 上次选中的文件")
    RegisterAction("<cm_Switch83Names>", "开启/关闭: 8.3 式文件名小写显示")
    RegisterAction("<cm_SwitchDirSort>", "开启/关闭: 文件夹按名称排序")
    RegisterAction("<cm_SwitchHidSys>", "开启/关闭: 隐藏或系统文件显示")
    RegisterAction("<cm_SwitchIgnoreList>", "启用/禁用: 自定义隐藏文件")
    RegisterAction("<cm_SwitchLongNames>", "开启/关闭: 长文件名显示")
    RegisterAction("<cm_SwitchOverlayIcons>", "开启/关闭: 叠置图标显示")
    RegisterAction("<cm_SwitchSeparateTree>", "切换独立文件夹树面板状态")
    RegisterAction("<cm_SwitchToNextTab>", "下一个标签(Ctrl+Tab)")
    RegisterAction("<cm_SwitchToPreviousTab>", "上一个标签(Ctrl+Shift+Tab)")
    RegisterAction("<cm_SwitchWatchDirs>", "启用/禁用: 文件夹自动刷新")
    RegisterAction("<cm_SwitchX64Redirection>", "开启/关闭: 32 位 system32 目录重定向(64 位 Windows)")
    RegisterAction("<cm_SyncChangeDir>", "两边窗口同步更改文件夹")
    RegisterAction("<cm_SysInfo>", "系统信息")
    RegisterAction("<cm_TestArchive>", "测试压缩包")
    RegisterAction("<cm_ThumbnailsConfig>", "配置: 缩略图")
    RegisterAction("<cm_ToggleLockCurrentTab>", "锁定/解锁当前标签")
    RegisterAction("<cm_ToggleLockDcaCurrentTab>", "锁定/解锁当前标签(可更改文件夹)")
    RegisterAction("<cm_ToggleSeparateTree1>", "开启/关闭: 一个独立文件夹树面板")
    RegisterAction("<cm_ToggleSeparateTree2>", "开启/关闭: 两个独立文件夹树面板")
    RegisterAction("<cm_TransferLeft>", "在左窗口打开光标处的文件夹或压缩包")
    RegisterAction("<cm_TransferRight>", "在右窗口打开光标处的文件夹或压缩包")
    RegisterAction("<cm_TrgActivateTab1>", "目标窗口: 激活标签 1")
    RegisterAction("<cm_TrgActivateTab10>", "目标窗口: 激活标签 10")
    RegisterAction("<cm_TrgActivateTab2>", "目标窗口: 激活标签 2")
    RegisterAction("<cm_TrgActivateTab3>", "目标窗口: 激活标签 3")
    RegisterAction("<cm_TrgActivateTab4>", "目标窗口: 激活标签 4")
    RegisterAction("<cm_TrgActivateTab5>", "目标窗口: 激活标签 5")
    RegisterAction("<cm_TrgActivateTab6>", "目标窗口: 激活标签 6")
    RegisterAction("<cm_TrgActivateTab7>", "目标窗口: 激活标签 7")
    RegisterAction("<cm_TrgActivateTab8>", "目标窗口: 激活标签 8")
    RegisterAction("<cm_TrgActivateTab9>", "目标窗口: 激活标签 9")
    RegisterAction("<cm_TrgNextCustomView>", "目标窗口: 下一个自定义视图")
    RegisterAction("<cm_TrgPrevCustomView>", "目标窗口: 上一个自定义视图")
    RegisterAction("<cm_TrgSortByCol1>", "目标窗口: 按第 1 列排序")
    RegisterAction("<cm_TrgSortByCol10>", "目标窗口: 按第 10 列排序")
    RegisterAction("<cm_TrgSortByCol2>", "目标窗口: 按第 2 列排序")
    RegisterAction("<cm_TrgSortByCol3>", "目标窗口: 按第 3 列排序")
    RegisterAction("<cm_TrgSortByCol4>", "目标窗口: 按第 4 列排序")
    RegisterAction("<cm_TrgSortByCol5>", "目标窗口: 按第 5 列排序")
    RegisterAction("<cm_TrgSortByCol6>", "目标窗口: 按第 6 列排序")
    RegisterAction("<cm_TrgSortByCol7>", "目标窗口: 按第 7 列排序")
    RegisterAction("<cm_TrgSortByCol8>", "目标窗口: 按第 8 列排序")
    RegisterAction("<cm_TrgSortByCol9>", "目标窗口: 按第 9 列排序")
    RegisterAction("<cm_UnloadPlugins>", "卸载所有插件")
    RegisterAction("<cm_UnpackFiles>", "解压文件")
    RegisterAction("<cm_UnselectCurrentExtension>", "不选扩展名相同的文件")
    RegisterAction("<cm_UnselectCurrentName>", "不选文件名相同的文件")
    RegisterAction("<cm_UnselectCurrentNameExt>", "不选文件名和扩展名相同的文件")
    RegisterAction("<cm_UnselectCurrentPath>", "不选同一路径下的文件(展开文件夹+搜索文件)")
    RegisterAction("<cm_UserMenu1>", "用户菜单 1")
    RegisterAction("<cm_UserMenu10>", "可定义其他用户菜单")
    RegisterAction("<cm_UserMenu2>", "用户菜单 2")
    RegisterAction("<cm_UserMenu3>", "用户菜单 3")
    RegisterAction("<cm_UserMenu4>", "用户菜单 4")
    RegisterAction("<cm_UserMenu5>", "用户菜单 5")
    RegisterAction("<cm_UserMenu6>", "用户菜单 6")
    RegisterAction("<cm_UserMenu7>", "用户菜单 7")
    RegisterAction("<cm_UserMenu8>", "用户菜单 8")
    RegisterAction("<cm_UserMenu9>", "用户菜单 9")
    RegisterAction("<cm_VersionInfo>", "版本信息")
    RegisterAction("<cm_VerticalPanels>", "纵向/横向排列")
    RegisterAction("<cm_VisBreadCrumbs>", "显示/隐藏: 路径导航栏")
    RegisterAction("<cm_VisButtonbar>", "显示/隐藏: 工具栏")
    RegisterAction("<cm_VisCmdLine>", "显示/隐藏: 命令行")
    RegisterAction("<cm_VisCurDir>", "显示/隐藏: 当前文件夹")
    RegisterAction("<cm_VisDirTabs>", "显示/隐藏: 文件夹标签")
    RegisterAction("<cm_VisDriveButtons>", "显示/隐藏: 驱动器按钮")
    RegisterAction("<cm_VisDriveCombo>", "显示/隐藏: 驱动器列表")
    RegisterAction("<cm_VisFlatDriveButtons>", "切换: 平坦/立体驱动器按钮")
    RegisterAction("<cm_VisFlatInterface>", "切换: 平坦/立体用户界面")
    RegisterAction("<cm_VisHistHotButtons>", "显示/隐藏: 文件夹历史记录和常用文件夹按钮")
    RegisterAction("<cm_VisitHomepage>", "访问 Totalcmd 网站")
    RegisterAction("<cm_VisKeyButtons>", "显示/隐藏: 功能键按钮")
    RegisterAction("<cm_VisStatusbar>", "显示/隐藏: 状态栏")
    RegisterAction("<cm_VisTabHeader>", "显示/隐藏: 排序制表符")
    RegisterAction("<cm_VisTwoDriveButtons>", "显示/隐藏: 两个驱动器按钮栏")
    RegisterAction("<cm_VisXPThemeBackground>", "显示/隐藏: XP 主题背景")
    RegisterAction("<cm_VolumeId>", "设置卷标")
    RegisterAction("<cm_ZipPackerConfig>", "配置: ZIP 压缩程序")
    RegisterAction("<TC_AlwayOnTop>", "设置 TC 顶置")
    RegisterAction("<TC_azHistory>", "a-z历史导航")
    RegisterAction("<TC_ClearTitle>", "将 TC 标题栏字符串设置为空")
    RegisterAction("<TC_CopyDirectoryHotlist>", "复制到常用文件夹")
    RegisterAction("<TC_CopyFileContents>", "不打开文件就复制文件内容")
    RegisterAction("<TC_CopyNameOnly>", "只复制文件名，不含扩展名")
    RegisterAction("<TC_CopyUseQueues>", "无需确认，使用队列拷贝文件至另一窗口")
    RegisterAction("<TC_CreateBlankFile>", "创建空文件")
    RegisterAction("<TC_CreateBlankFileNoExt>", "创建无扩展名空文件")
    RegisterAction("<TC_CreateFileShortcut>", "创建当前光标下文件的快捷方式")
    RegisterAction("<TC_CreateFileShortcutToDesktop>", "创建当前光标下文件的快捷方式并发送到桌面")
    RegisterAction("<TC_CreateFileShortcutToStartup>", "创建当前光标下文件的快捷方式并发送到启动文件里")
    RegisterAction("<TC_CreateNewFile>", "文件模板")
    RegisterAction("<TC_DownSelect>", "向下选择")
    RegisterAction("<TC_FileCopyForBak>", "将当前光标下的文件复制一份作为作为备份")
    RegisterAction("<TC_FileMoveForBak>", "将当前光标下的文件重命名为备份")
    RegisterAction("<TC_FilterSearchFNsuffix_exe>", "在当前目录里快速过滤 exe 扩展名的文件")
    RegisterAction("<TC_FocusTCCmd>", "激活TC，定位到命令行")
    RegisterAction("<TC_ForceDelete>", "强制删除")
    RegisterAction("<TC_GoLastTab>", "切换到最后一个标签")
    RegisterAction("<TC_GotoLine>", "移动到 [count] 行，默认第一行")
    RegisterAction("<TC_GotoNextDirOther>", "前进另一侧")
    RegisterAction("<TC_GoToParentEx>", "返回到上层文件夹，可返回到我的电脑")
    RegisterAction("<TC_GotoPreviousDirOther>", "后退另一侧")
    RegisterAction("<TC_Half>", "移动到窗口中间行")
    RegisterAction("<TC_InsertMode>", "进入插入模式")
    RegisterAction("<TC_LastLine>", "移动到 [count] 行，默认最后一行")
    RegisterAction("<TC_ListMark>", "显示标记")
    RegisterAction("<TC_Mark>", "标记功能")
    RegisterAction("<TC_MarkFile>", "标记文件，将文件注释改成m")
    RegisterAction("<TC_MoveAllFilesToPrevFolder>", "将当前文件夹下的全部文件移动到上层目录中")
    RegisterAction("<TC_MoveDirectoryHotlist>", "移动到常用文件夹")
    RegisterAction("<TC_MoveSelectedFilesToPrevFolder>", "将当前文件夹下的选定文件移动到上层目录中")
    RegisterAction("<TC_MoveUseQueues>", "无需确认，使用队列移动文件至另一窗口")
    RegisterAction("<TC_MultiFilePersistOpen>", "多个文件一次性连续打开")
    RegisterAction("<TC_NormalMode>", "返回正常模式")
    RegisterAction("<TC_OpenDirAndPaste>", "不打开目录，直接把复制的文件贴进去")
    RegisterAction("<TC_OpenDirsInFile>", "将光标所在的文件内容中的文件夹在新标签页依次打开")
    RegisterAction("<TC_OpenDriveThat>", "打开驱动器列表:另侧")
    RegisterAction("<TC_OpenDriveThis>", "打开驱动器列表:本侧")
    RegisterAction("<TC_OpenWithAlternateViewer>", "使用外部查看器打开（alt + f3）")
    RegisterAction("<TC_PasteFileEx>", "粘贴文件，如果光标下为目录则粘贴进该目录")
    RegisterAction("<TC_ReOpenTab>", "重新打开之前关闭的标签页")
    RegisterAction("<TC_Restart>", "重启 TC")
    RegisterAction("<TC_SearchMode>", "连续搜索")
    RegisterAction("<TC_SelectCmd>", "选择命令来执行")
    RegisterAction("<TC_SrcQuickViewAndTab>", "预览文件时,光标自动移到对侧窗口里")
    RegisterAction("<TC_SuperReturn>", "同回车键，但定位到第一个文件")
    RegisterAction("<TC_ThumbsView>", "缩略图试图，并且修改 h 和 l 为方向键")
    RegisterAction("<TC_Toggle_50_100Percent_V>", "切换当前（纵向）窗口显示状态 50% ~ 100%")
    RegisterAction("<TC_Toggle_50_100Percent>", "切换当前窗口显示状态 50% ~ 100% ")
    RegisterAction("<TC_ToggleMenu>", "显示/隐藏: 菜单栏")
    RegisterAction("<TC_ToggleShowInfo>", "显示/隐藏: 按键提示")
    RegisterAction("<TC_ToggleTC>", "打开/激活TC")
    RegisterAction("<TC_TwoFileExchangeName>", "两个文件互换文件名")
    RegisterAction("<TC_UnMarkFile>", "取消文件标记，将文件注释清空")
    RegisterAction("<TC_UpSelect>", "向上选择")
    RegisterAction("<TC_ViewFileUnderCursor>", "使用查看器打开光标所在文件（shift + f3）")
    RegisterAction("<TC_WinMaxLeft>", "最大化左侧窗口")
    RegisterAction("<TC_WinMaxRight>", "最大化右侧窗口")
    ; 注册窗口 (类名匹配, 不绑死进程名: 32 位 TOTALCMD.EXE / 64 位 TOTALCMD64.EXE 通吃)
    RegisterWin("TTOTAL_CMD", "TTOTAL_CMD", "")
    RegisterWin("TCQuickSearch", "TQUICKSEARCH", "")

    ; 注册模式
    RegisterMode("normal", "TTOTAL_CMD")
    RegisterMode("insert", "TTOTAL_CMD")
    RegisterMode("search", "TTOTAL_CMD")
    RegisterMode("normal", "TCQuickSearch")

    ; 设置 BeforeActionDo 回调 (仅 TTOTAL_CMD 窗, 对齐原版; 全局注册会误伤其它窗口)
    Rim.vim.SetBeforeActionDoForWin("TTOTAL_CMD", TC_BeforeActionDo)

    ; === 基础动作 ===
    RegisterAction("<TC_NormalMode>", "返回正常模式")
    RegisterAction("<TC_InsertMode>", "进入插入模式")
    RegisterAction("<TC_ToggleTC>", "打开/激活TC")
    RegisterAction("<TC_Restart>", "重启TC")

    ; === 导航 ===
    RegisterAction("<TC_GoToParentEx>", "返回上层文件夹")
    RegisterAction("<cm_GotoRoot>", "转到根目录")
    RegisterAction("<cm_GotoPreviousDir>", "后退")
    RegisterAction("<cm_GotoNextDir>", "前进")
    RegisterAction("<TC_DownSelect>", "向下选择")
    RegisterAction("<TC_UpSelect>", "向上选择")
    RegisterAction("<TC_GotoLine>", "跳转到第N行")
    RegisterAction("<TC_LastLine>", "跳转到最后一行")
    RegisterAction("<TC_Half>", "跳到中间行")

    ; === 文件操作 ===
    RegisterAction("<cm_CopyOtherpanel>", "复制到对侧")
    RegisterAction("<cm_MoveOnly>", "移动到对侧")
    RegisterAction("<cm_CopyToClipboard>", "复制到剪贴板")
    RegisterAction("<cm_CutToClipboard>", "剪切到剪贴板")
    RegisterAction("<cm_PasteFromClipboard>", "粘贴")
    RegisterAction("<cm_Delete>", "删除")
    RegisterAction("<cm_RenameOnly>", "重命名")
    RegisterAction("<cm_MultiRenameFiles>", "批量重命名")
    RegisterAction("<cm_MkDir>", "新建文件夹")
    RegisterAction("<cm_Edit>", "编辑文件")
    RegisterAction("<cm_View>", "查看文件")
    RegisterAction("<cm_PackFiles>", "压缩文件")
    RegisterAction("<cm_UnpackFiles>", "解压文件")
    RegisterAction("<cm_CopyNamesToClip>", "复制文件名")
    RegisterAction("<cm_CopyFullNamesToClip>", "复制完整路径")
    RegisterAction("<cm_CopySrcPathToClip>", "复制源路径")
    RegisterAction("<cm_CopyFileContents>", "复制文件内容")

    ; === 搜索 ===
    RegisterAction("<cm_SearchFor>", "搜索")
    RegisterAction("<cm_ShowQuickSearch>", "快速搜索")

    ; === 比较 ===
    RegisterAction("<cm_CompareDirs>", "比较目录")
    RegisterAction("<cm_CompareByContent>", "按内容比较")
    RegisterAction("<cm_SyncDirs>", "同步目录")

    ; === 选择 ===
    RegisterAction("<cm_SelectAll>", "全选")
    RegisterAction("<cm_ExchangeSelection>", "反选")
    RegisterAction("<cm_ProperCase>", "首字母大写")
    RegisterAction("<cm_LowerCase>", "转小写")
    RegisterAction("<cm_UpperCase>", "转大写")

    ; === 刷新 ===
    RegisterAction("<cm_Refresh>", "刷新")

    ; === 标签页 ===
    RegisterAction("<cm_OpenNewTab>", "新建标签")
    RegisterAction("<cm_OpenNewTabBg>", "后台新建标签")
    RegisterAction("<cm_SwitchToNextTab>", "下一个标签")
    RegisterAction("<cm_SwitchToPreviousTab>", "上一个标签")
    RegisterAction("<cm_CloseCurrentTab>", "关闭当前标签")
    RegisterAction("<cm_CloseAllTabs>", "关闭所有标签")
    RegisterAction("<cm_SrcGoToLastTab>", "跳到最后一个标签")

    ; === 排序 ===
    RegisterAction("<cm_SrcByName>", "按名称排序")
    RegisterAction("<cm_SrcByExt>", "按扩展名排序")
    RegisterAction("<cm_SrcBySize>", "按大小排序")
    RegisterAction("<cm_SrcByDateTime>", "按日期排序")
    RegisterAction("<cm_SrcByAttr>", "按属性排序")
    RegisterAction("<cm_SrcNegSort>", "反向排序")

    ; === 视图 ===
    RegisterAction("<cm_SrcShort>", "短列表")
    RegisterAction("<cm_SrcLong>", "长列表")
    RegisterAction("<cm_SrcTree>", "目录树")
    RegisterAction("<cm_SrcThumbs>", "缩略图")
    RegisterAction("<cm_SrcQuickView>", "快速预览")
    RegisterAction("<cm_ToggleTreeView>", "切换目录树")

    ; === 窗口 ===
    RegisterAction("<cm_MaximizePanel1>", "最大化左面板")
    RegisterAction("<cm_MaximizePanel2>", "最大化右面板")
    RegisterAction("<cm_Exchange>", "交换面板")
    RegisterAction("<cm_Minimize>", "最小化")
    RegisterAction("<cm_Maximize>", "最大化")
    RegisterAction("<cm_Restore>", "还原")

    ; === 其他 ===
    RegisterAction("<cm_ContextMenu>", "右键菜单")
    RegisterAction("<cm_ExecuteDOS>", "命令提示符")
    RegisterAction("<cm_FocusCmdLine>", "焦点到命令行")
    RegisterAction("<cm_DirectoryHotlist>", "常用文件夹")
    RegisterAction("<cm_LeftOpenDrives>", "左侧驱动器")
    RegisterAction("<cm_RightOpenDrives>", "右侧驱动器")
    RegisterAction("<cm_SrcHome>", "回到源目录首页")
    RegisterAction("<cm_DirHome>", "回到目标目录首页")
    RegisterAction("<cm_Config>", "配置")
    RegisterAction("<cm_Exit>", "退出TC")

    ; === 高级功能 ===
    RegisterAction("<TC_Mark>", "标记功能")
    RegisterAction("<TC_ListMark>", "显示标记")
    RegisterAction("<TC_azHistory>", "a-z历史导航")
    RegisterAction("<TC_CreateNewFile>", "创建新文件")
    RegisterAction("<TC_ForceDelete>", "强制删除")
    RegisterAction("<TC_Toggle_50_100Percent>", "切换窗口大小")
    RegisterAction("<TC_AlwayOnTop>", "TC置顶")
    RegisterAction("<TC_ToggleShowInfo>", "显示/隐藏按键提示")
    RegisterAction("<TC_SelectCmd>", "选择命令")
    RegisterAction("<TC_OpenDriveThis>", "驱动器列表(本侧)")
    RegisterAction("<TC_OpenDriveThat>", "驱动器列表(另侧)")
    RegisterAction("<TC_ToggleMenu>", "切换菜单栏")
    RegisterAction("<TC_ToggleToolbar>", "切换工具栏")
    RegisterAction("<TC_ToggleStatusBar>", "切换状态栏")
    RegisterAction("<TC_WinMaxLeft>", "最大化左面板")
    RegisterAction("<TC_WinMaxRight>", "最大化右面板")
    RegisterAction("<TC_FileCopyForBak>", "复制并加.bak")
    RegisterAction("<TC_FileMoveForBak>", "重命名并加.bak")
    RegisterAction("<TC_CreateFileShortcut>", "创建快捷方式")
    RegisterAction("<TC_CreateFileShortcutToDesktop>", "创建快捷方式到桌面")
    RegisterAction("<TC_CreateBlankFile>", "创建空文件")

    ; === 高级功能 ===
    RegisterAction("<TC_CopyUseQueues>", "队列复制")
    RegisterAction("<TC_MoveUseQueues>", "队列移动")
    RegisterAction("<TC_CopyDirectoryHotlist>", "复制到常用文件夹")
    RegisterAction("<TC_MoveDirectoryHotlist>", "移动到常用文件夹")
    RegisterAction("<TC_GotoPreviousDirOther>", "另侧后退")
    RegisterAction("<TC_GotoNextDirOther>", "另侧前进")
    RegisterAction("<TC_SearchMode>", "连续搜索模式")
    RegisterAction("<TC_ReOpenTab>", "重新打开关闭标签")
    RegisterAction("<TC_GoLastTab>", "跳到最后标签")
    RegisterAction("<TC_Toggle_50_100Percent_V>", "纵向切换窗口大小")
    RegisterAction("<TC_SuperReturn>", "回车后定位到第一个文件")
    RegisterAction("<TC_MultiFilePersistOpen>", "多文件连续打开")
    RegisterAction("<TC_CopyFileContents>", "复制文件内容")
    RegisterAction("<TC_OpenDirAndPaste>", "不打开目录直接粘贴")
    RegisterAction("<TC_MoveSelectedFilesToPrevFolder>", "移动选中文件到上级")
    RegisterAction("<TC_MoveAllFilesToPrevFolder>", "移动所有文件到上级")
    RegisterAction("<TC_SrcQuickViewAndTab>", "预览时移到对侧")
    RegisterAction("<TC_CreateFileShortcutToStartup>", "快捷方式到启动目录")
    RegisterAction("<TC_FilterSearchFNsuffix_exe>", "快速过滤exe")
    RegisterAction("<TC_TwoFileExchangeName>", "两文件互换名称")
    RegisterAction("<TC_MarkFile>", "文件备注标记")
    RegisterAction("<TC_UnMarkFile>", "取消文件标记")
    RegisterAction("<TC_ClearTitle>", "清空标题栏")
    RegisterAction("<TC_OpenDirsInFile>", "按文件内容打开目录")
    RegisterAction("<TC_CreateBlankFileNoExt>", "创建无扩展名文件")
    RegisterAction("<TC_PasteFileEx>", "粘贴到光标下目录")
    RegisterAction("<TC_ThumbsView>", "缩略图视图切换")
    RegisterAction("<TC_SrcActivateTab1>", "激活标签1")
    RegisterAction("<TC_SrcActivateTab2>", "激活标签2")
    RegisterAction("<TC_SrcActivateTab3>", "激活标签3")
    RegisterAction("<TC_SrcActivateTab4>", "激活标签4")
    RegisterAction("<TC_SrcActivateTab5>", "激活标签5")
    RegisterAction("<TC_SrcActivateTab6>", "激活标签6")
    RegisterAction("<TC_SrcActivateTab7>", "激活标签7")
    RegisterAction("<TC_SrcActivateTab8>", "激活标签8")
    RegisterAction("<TC_SrcActivateTab9>", "激活标签9")

    ; === 映射热键 - normal 模式 (1:1 对原版 vim.map, 顺序同原版) ===

    ; 复制/移动 f=file (原版 fqc/fqx, 非移植版 fq/fQ)
    MapKey("fc", "<cm_CopyOtherpanel>", "TTOTAL_CMD", "normal")
    MapKey("fx", "<cm_MoveOnly>", "TTOTAL_CMD", "normal")
    MapKey("fqc", "<TC_CopyUseQueues>", "TTOTAL_CMD", "normal")
    MapKey("fqx", "<TC_MoveUseQueues>", "TTOTAL_CMD", "normal")
    MapKey("ff", "<cm_CopyToClipboard>", "TTOTAL_CMD", "normal")
    MapKey("fz", "<cm_CutToClipboard>", "TTOTAL_CMD", "normal")
    MapKey("fv", "<cm_PasteFromClipboard>", "TTOTAL_CMD", "normal")
    MapKey("fb", "<TC_CopyDirectoryHotlist>", "TTOTAL_CMD", "normal")
    MapKey("fd", "<TC_MoveDirectoryHotlist>", "TTOTAL_CMD", "normal")
    MapKey("fg", "<cm_CopySrcPathToClip>", "TTOTAL_CMD", "normal")
    MapKey("ft", "<cm_SyncChangeDir>", "TTOTAL_CMD", "normal")
    MapKey("F", "<TC_SearchMode>", "TTOTAL_CMD", "normal")
    MapKey("gh", "<TC_GotoPreviousDirOther>", "TTOTAL_CMD", "normal")
    MapKey("gl", "<TC_GotoNextDirOther>", "TTOTAL_CMD", "normal")
    MapKey("Vh", "<cm_SwitchIgnoreList>", "TTOTAL_CMD", "normal")

    ; 数字键 (原版 <TC_0-9> 只清 count 不打字; v2 空函数复刻, 不用 <Pass> 透传)
    MapKey("0", "<TC_0>", "TTOTAL_CMD", "normal")
    MapKey("1", "<TC_1>", "TTOTAL_CMD", "normal")
    MapKey("2", "<TC_2>", "TTOTAL_CMD", "normal")
    MapKey("3", "<TC_3>", "TTOTAL_CMD", "normal")
    MapKey("4", "<TC_4>", "TTOTAL_CMD", "normal")
    MapKey("5", "<TC_5>", "TTOTAL_CMD", "normal")
    MapKey("6", "<TC_6>", "TTOTAL_CMD", "normal")
    MapKey("7", "<TC_7>", "TTOTAL_CMD", "normal")
    MapKey("8", "<TC_8>", "TTOTAL_CMD", "normal")
    MapKey("9", "<TC_9>", "TTOTAL_CMD", "normal")

    ; 基础导航 (与原版一致)
    MapKey("j", "<down>", "TTOTAL_CMD", "normal")
    MapKey("k", "<up>", "TTOTAL_CMD", "normal")
    MapKey("h", "<left>", "TTOTAL_CMD", "normal")
    MapKey("l", "<right>", "TTOTAL_CMD", "normal")
    MapKey("J", "<TC_DownSelect>", "TTOTAL_CMD", "normal")
    MapKey("K", "<TC_UpSelect>", "TTOTAL_CMD", "normal")
    MapKey("M", "<TC_Half>", "TTOTAL_CMD", "normal")
    MapKey("gg", "<TC_GoToLine>", "TTOTAL_CMD", "normal")
    MapKey("G", "<TC_LastLine>", "TTOTAL_CMD", "normal")
    MapKey("H", "<cm_GotoPreviousDir>", "TTOTAL_CMD", "normal")
    MapKey("L", "<cm_GotoNextDir>", "TTOTAL_CMD", "normal")
    MapKey("u", "<TC_GoToParentEx>", "TTOTAL_CMD", "normal")
    MapKey("U", "<cm_GotoRoot>", "TTOTAL_CMD", "normal")
    MapKey("<Esc>", "<TC_NormalMode>", "TTOTAL_CMD", "insert")

    ; 文件操作 (与原版一致; w=cm_List 非 cm_View; I/i 不动)
    MapKey("x", "<cm_Delete>", "TTOTAL_CMD", "normal")
    MapKey("X", "<TC_ForceDelete>", "TTOTAL_CMD", "normal")
    MapKey("r", "<cm_RenameOnly>", "TTOTAL_CMD", "normal")
    MapKey("R", "<cm_MultiRenameFiles>", "TTOTAL_CMD", "normal")
    MapKey("n", "<TC_azHistory>", "TTOTAL_CMD", "normal")
    MapKey("I", "<TC_CreateNewFile>", "TTOTAL_CMD", "normal")
    MapKey("e", "<cm_ContextMenu>", "TTOTAL_CMD", "normal")
    MapKey("E", "<cm_ExecuteDOS>", "TTOTAL_CMD", "normal")
    MapKey("i", "<TC_InsertMode>", "TTOTAL_CMD", "normal")
    MapKey(":", "<cm_FocusCmdLine>", "TTOTAL_CMD", "normal")

    ; 复制/移动 (上部 f 系列已对原版; fa 归 ini, fp/fq 系移植版自创已 drop, 后续按需加回)

    ; 查看/搜索 (w=cm_List 对原版, 非 cm_View)
    MapKey("w", "<cm_List>", "TTOTAL_CMD", "normal")
    MapKey("q", "<cm_SrcQuickView>", "TTOTAL_CMD", "normal")
    MapKey("/", "<cm_ShowQuickSearch>", "TTOTAL_CMD", "normal")
    MapKey("?", "<cm_SearchFor>", "TTOTAL_CMD", "normal")

    ; 复制信息
    MapKey("y", "<cm_CopyNamesToClip>", "TTOTAL_CMD", "normal")
    MapKey("Y", "<cm_CopyFullNamesToClip>", "TTOTAL_CMD", "normal")

    ; 压缩/解压
    MapKey("P", "<cm_PackFiles>", "TTOTAL_CMD", "normal")
    MapKey("p", "<cm_UnpackFiles>", "TTOTAL_CMD", "normal")

    ; 选择 (原版全量: [ ] { } \ | ; a 走 ini)
    MapKey("[", "<cm_SelectCurrentName>", "TTOTAL_CMD", "normal")
    MapKey("{", "<cm_UnselectCurrentName>", "TTOTAL_CMD", "normal")
    MapKey("]", "<cm_SelectCurrentExtension>", "TTOTAL_CMD", "normal")
    MapKey("}", "<cm_UnSelectCurrentExtension>", "TTOTAL_CMD", "normal")
    MapKey("\", "<cm_ExchangeSelection>", "TTOTAL_CMD", "normal")
    MapKey("|", "<cm_ClearAll>", "TTOTAL_CMD", "normal")

    ; 符号键 (原版: -/=/~/` ; . 归 ini/custom, 不在硬编码)
    MapKey("-", "<cm_SwitchSeparateTree>", "TTOTAL_CMD", "normal")
    MapKey("=", "<cm_MatchSrc>", "TTOTAL_CMD", "normal")
    MapKey("~", "<cm_SysInfo>", "TTOTAL_CMD", "normal")
    MapKey("``", "<TC_ToggleShowInfo>", "TTOTAL_CMD", "normal")
    MapKey(",", "<cm_SrcThumbs>", "TTOTAL_CMD", "normal")
    MapKey(";", "<cm_DirectoryHotlist>", "TTOTAL_CMD", "normal")

    ; 驱动器 (与原版一致)
    MapKey("o", "<cm_LeftOpenDrives>", "TTOTAL_CMD", "normal")
    MapKey("O", "<cm_RightOpenDrives>", "TTOTAL_CMD", "normal")
    MapKey("d", "<cm_DirectoryHotlist>", "TTOTAL_CMD", "normal")
    MapKey("D", "<cm_OpenDesktop>", "TTOTAL_CMD", "normal")

    ; 标签页 (原版: g1-9=cm_SrcActivateTab, g0=TC_GoLastTab, 无 Gen_Tab*)
    MapKey("t", "<cm_OpenNewTab>", "TTOTAL_CMD", "normal")
    MapKey("T", "<cm_OpenNewTabBg>", "TTOTAL_CMD", "normal")
    MapKey("g0", "<TC_GoLastTab>", "TTOTAL_CMD", "normal")
    MapKey("g1", "<cm_SrcActivateTab1>", "TTOTAL_CMD", "normal")
    MapKey("g2", "<cm_SrcActivateTab2>", "TTOTAL_CMD", "normal")
    MapKey("g3", "<cm_SrcActivateTab3>", "TTOTAL_CMD", "normal")
    MapKey("g4", "<cm_SrcActivateTab4>", "TTOTAL_CMD", "normal")
    MapKey("g5", "<cm_SrcActivateTab5>", "TTOTAL_CMD", "normal")
    MapKey("g6", "<cm_SrcActivateTab6>", "TTOTAL_CMD", "normal")
    MapKey("g7", "<cm_SrcActivateTab7>", "TTOTAL_CMD", "normal")
    MapKey("g8", "<cm_SrcActivateTab8>", "TTOTAL_CMD", "normal")
    MapKey("g9", "<cm_SrcActivateTab9>", "TTOTAL_CMD", "normal")

    ; 标签页管理 (原版: gb=对侧新标签, gw=带标签交换, gr=重开)
    MapKey("ga", "<cm_CloseAllTabs>", "TTOTAL_CMD", "normal")
    MapKey("gc", "<cm_CloseCurrentTab>", "TTOTAL_CMD", "normal")
    MapKey("gt", "<cm_SwitchToNextTab>", "TTOTAL_CMD", "normal")
    MapKey("gT", "<cm_SwitchToPreviousTab>", "TTOTAL_CMD", "normal")
    MapKey("ge", "<cm_Exchange>", "TTOTAL_CMD", "normal")
    MapKey("gb", "<cm_OpenDirInNewTabOther>", "TTOTAL_CMD", "normal")
    MapKey("gr", "<TC_ReOpenTab>", "TTOTAL_CMD", "normal")
    MapKey("gw", "<cm_ExchangeWithTabs>", "TTOTAL_CMD", "normal")
    MapKey("g$", "<TC_LastLine>", "TTOTAL_CMD", "normal")

    ; 排序 (原版: sr=NegOrder, s1-9=按列, s0=无序)
    MapKey("sn", "<cm_SrcByName>", "TTOTAL_CMD", "normal")
    MapKey("se", "<cm_SrcByExt>", "TTOTAL_CMD", "normal")
    MapKey("ss", "<cm_SrcBySize>", "TTOTAL_CMD", "normal")
    MapKey("sd", "<cm_SrcByDateTime>", "TTOTAL_CMD", "normal")
    MapKey("sr", "<cm_SrcNegOrder>", "TTOTAL_CMD", "normal")
    MapKey("s1", "<cm_SrcSortByCol1>", "TTOTAL_CMD", "normal")
    MapKey("s2", "<cm_SrcSortByCol2>", "TTOTAL_CMD", "normal")
    MapKey("s3", "<cm_SrcSortByCol3>", "TTOTAL_CMD", "normal")
    MapKey("s4", "<cm_SrcSortByCol4>", "TTOTAL_CMD", "normal")
    MapKey("s5", "<cm_SrcSortByCol5>", "TTOTAL_CMD", "normal")
    MapKey("s6", "<cm_SrcSortByCol6>", "TTOTAL_CMD", "normal")
    MapKey("s7", "<cm_SrcSortByCol7>", "TTOTAL_CMD", "normal")
    MapKey("s8", "<cm_SrcSortByCol8>", "TTOTAL_CMD", "normal")
    MapKey("s9", "<cm_SrcSortByCol9>", "TTOTAL_CMD", "normal")
    MapKey("s0", "<cm_SrcUnsorted>", "TTOTAL_CMD", "normal")

    ; 视图 (原版 V 系=界面显隐开关, 非移植版重构版)
    MapKey("v", "<cm_SrcCustomViewMenu>", "TTOTAL_CMD", "normal")
    MapKey("Vb", "<cm_VisButtonbar>", "TTOTAL_CMD", "normal")
    MapKey("Vm", "<TC_ToggleMenu>", "TTOTAL_CMD", "normal")
    MapKey("Vd", "<cm_VisDriveButtons>", "TTOTAL_CMD", "normal")
    MapKey("Vo", "<cm_VisTwoDriveButtons>", "TTOTAL_CMD", "normal")
    MapKey("Vr", "<cm_VisDriveCombo>", "TTOTAL_CMD", "normal")
    MapKey("Vc", "<cm_VisDriveCombo>", "TTOTAL_CMD", "normal")
    MapKey("Vt", "<cm_VisTabHeader>", "TTOTAL_CMD", "normal")
    MapKey("Vs", "<cm_VisStatusbar>", "TTOTAL_CMD", "normal")
    MapKey("Vn", "<cm_VisCmdLine>", "TTOTAL_CMD", "normal")
    MapKey("Vf", "<cm_VisKeyButtons>", "TTOTAL_CMD", "normal")
    MapKey("Vw", "<cm_VisDirTabs>", "TTOTAL_CMD", "normal")
    MapKey("Ve", "<cm_CommandBrowser>", "TTOTAL_CMD", "normal")

    ; 窗口 (原版: zz/zh=50/100切换, zi/zo=左右最大化, zn/zm/zr=最小/大/还原, zv=纵向)
    MapKey("zz", "<TC_Toggle_50_100Percent>", "TTOTAL_CMD", "normal")
    MapKey("zh", "<TC_Toggle_50_100Percent_V>", "TTOTAL_CMD", "normal")
    MapKey("zi", "<TC_WinMaxLeft>", "TTOTAL_CMD", "normal")
    MapKey("zo", "<TC_WinMaxRight>", "TTOTAL_CMD", "normal")
    MapKey("zt", "<TC_AlwayOnTop>", "TTOTAL_CMD", "normal")
    MapKey("zn", "<cm_Minimize>", "TTOTAL_CMD", "normal")
    MapKey("zm", "<cm_Maximize>", "TTOTAL_CMD", "normal")
    MapKey("zr", "<cm_Restore>", "TTOTAL_CMD", "normal")
    MapKey("zv", "<cm_VerticalPanels>", "TTOTAL_CMD", "normal")

    ; 高级 (与原版一致)
    MapKey("m", "<TC_Mark>", "TTOTAL_CMD", "normal")
    MapKey("'", "<TC_ListMark>", "TTOTAL_CMD", "normal")
    MapKey("``", "<TC_ToggleShowInfo>", "TTOTAL_CMD", "normal")
    MapKey("-", "<TC_Toggle_50_100Percent>", "TTOTAL_CMD", "normal")
    MapKey(";", "<cm_DirectoryHotlist>", "TTOTAL_CMD", "normal")

    ; (原版硬编码到此结束; 以下移植版自创键已移除, 回归原版:
    ;  F10/fB/fM/fs/fS/fi/fI/fq/fQ/fD/fa/ft/fe/fw/fm/fu/gv/gU/gA/gI/z;/Enter/go/gO,
    ;  其中 fa 归 ini 所有, F/gt 与上部重复不再列出)

    ; insert 模式映射
    MapKey("<enter>", "<enter>", "TTOTAL_CMD", "insert")
    MapKey("<bs>", "<bs>", "TTOTAL_CMD", "insert")
    MapKey("<tab>", "<tab>", "TTOTAL_CMD", "insert")
    MapKey("<space>", "<space>", "TTOTAL_CMD", "insert")
    MapKey("<del>", "<del>", "TTOTAL_CMD", "insert")

    ; 快速搜索窗口
    MapKey("j", "<down>", "TCQuickSearch", "normal")
    MapKey("k", "<up>", "TCQuickSearch", "normal")
}

; === TC 路径检测 ===
DetectTCPath() {
    global TCPath, TCINI, isTC64

    ; 1. 尝试从配置读取
    tcPath := Rim.config.Get("TotalCommander_Config", "TCPath", "")
    if (tcPath != "" && FileExist(tcPath)) {
        TCPath := tcPath
        isTC64 := RegExMatch(tcPath, "i)totalcmd64\.exe$")
        TCINI := Rim.config.Get("TotalCommander_Config", "TCINI", "")
        return
    }

    ; 2. 从运行中的进程获取 (v2: WinGetProcessPath 直接返回值, 不再用 & 输出)
    path := ""
    try {
        if ProcessExist("totalcmd.exe") {
            path := WinGetProcessPath("ahk_exe totalcmd.exe")
            TCPath := path
            isTC64 := false
        } else if ProcessExist("totalcmd64.exe") {
            path := WinGetProcessPath("ahk_exe totalcmd64.exe")
            TCPath := path
            isTC64 := true
        }
        if (TCPath != "") {
            TCINI := SubStr(TCPath, 1, InStr(TCPath, "\", 0, -1)) "wincmd.ini"
            return
        }
    }

    ; 3. 从注册表读取 (v2: RegRead 直接返回值, 缺键抛错由外层 try 兜住)
    regPath := ""
    try {
        regPath := RegRead("HKEY_CURRENT_USER\Software\Ghisler\Total Commander", "InstallDir")
        if FileExist(regPath "\totalcmd.exe") {
            TCPath := regPath "\totalcmd.exe"
            isTC64 := false
            TCINI := regPath "\wincmd.ini"
        } else if FileExist(regPath "\totalcmd64.exe") {
            TCPath := regPath "\totalcmd64.exe"
            isTC64 := true
            TCINI := regPath "\wincmd.ini"
        }
    }
}

; === TC 动作函数 ===
TC_NormalMode() {
    win := Rim.vim.GetWin("TTOTAL_CMD")
    if IsObject(win)
        win.currentMode := "normal"
}

TC_InsertMode() {
    win := Rim.vim.GetWin("TTOTAL_CMD")
    if IsObject(win)
        win.currentMode := "insert"
}

; <TC_0>-<TC_9>: 对原版 (Vim_HotKeyCount:=, 只清 count 不打字); v2 空函数复刻.
; 注意数字正常走引擎 Count 累加, 落到这里的只有孤零等边界.
TC_0() {
}
TC_1() {
}
TC_2() {
}
TC_3() {
}
TC_4() {
}
TC_5() {
}
TC_6() {
}
TC_7() {
}
TC_8() {
}
TC_9() {
}

TC_ToggleTC() {
    global TCPath
    if WinExist("ahk_class TTOTAL_CMD") {
        if WinActive("ahk_class TTOTAL_CMD")
            WinMinimize "ahk_class TTOTAL_CMD"
        else
            WinActivate "ahk_class TTOTAL_CMD"
    } else if (TCPath != "") {
        Run TCPath
    }
}

TC_DownSelect() {
    Send "+{Down}"
}

TC_UpSelect() {
    Send "+{Up}"
}

; <TC_LastLine>: 转到[count]行, 缺省末行
TC_LastLine() {
    if (TC_GetWinCount() > 1)
        TC_GotoLineDo(TC_GetWinCount())
    else
        TC_GotoLineDo(0)
}

; 转到指定行 (对齐原版: LB_GETCOUNT 取行数 + LB_SETCARETINDEX 直跳;
;  注意 ControlGetText 读 ListBox 恒为空, 必须用消息取数; Index=0 表末行)
TC_GotoLineDo(Index) {
    focused := ""
    try focused := FocusedClassNN("ahk_class TTOTAL_CMD")
    if (focused = "")
        return
    cnt := 0
    try cnt := SendMessage(0x18B, 0, 0, focused, "ahk_class TTOTAL_CMD")
    if (!cnt || cnt = "")
        return
    last := cnt - 1
    if (Index > 0) {
        if (Index > last)
            Index := last
        PostMessage(0x19E, Index, 1, focused, "ahk_class TTOTAL_CMD")
    } else {
        PostMessage(0x19E, last, 1, focused, "ahk_class TTOTAL_CMD")
    }
}

; 取当前窗 Count (对齐原版 vim.GetCount)
TC_GetWinCount() {
    try {
        global g_VimEngine
        if !IsObject(g_VimEngine)
            return 0
        name := g_VimEngine.CheckWin()
        w := g_VimEngine.GetWin(name)
        if IsObject(w)
            return w.Count
    }
    return 0
}

; <TC_GoToLine>: 转到[count]行, 缺省第一行
TC_GoToLine() {
    if (TC_GetWinCount() > 1)
        TC_GotoLineDo(TC_GetWinCount())
    else
        TC_GotoLineDo(1)
}

TC_Half() {
    ; 精确跳到中间行
    try {
        ; 获取可见行数
        WinGetPos(, , &w, &h, "ahk_class TTOTAL_CMD")
        rowHeight := 18  ; 大约行高
        visibleRows := h // rowHeight
        targetRow := visibleRows // 2

        ; 跳到第一行
        Send "^{Home}"
        Sleep 50

        ; 向下移动到中间
        loop targetRow {
            Send "{Down}"
        }
    }
}

TC_CopySrcPathToClip() {
    TC_SendPos(2029)  ; cm_CopySrcPathToClip
}

TC_CopyNameOnly() {
    ; 复制文件名（不含扩展名）
    try {
        ; 获取当前选中文件名 (v2: WinGetText 直接返回值; 该变量实际未使用, 保留仅为兼容)
        text := WinGetText("ahk_class TTOTAL_CMD")
        ; 简化实现：复制后处理
        Send "^c"
        Sleep 50
        clipText := A_Clipboard

        ; 处理文件名
        if RegExMatch(clipText, "^(.*?)\.[^.]+$", &match) {
            A_Clipboard := match[1]
        }
    }
}

TC_ViewFileUnderCursor() {
    Send "{F3}"
}

TC_OpenWithAlternateViewer() {
    Send "!{F3}"
}

TC_CreateNewFile() {
    ; 文件模板系统 - 从注册表扫描 ShellNew 模板
    ; 支持创建各种类型的新文件

    ; 扫描 ShellNew 模板
    templates := TC_ScanShellNewTemplates()

    ; 添加自定义模板
    templates.Push({name: "空文件", ext: "", template: ""})
    templates.Push({name: "文本文件", ext: ".txt", template: ""})
    templates.Push({name: "批处理文件", ext: ".bat", template: "@echo off`r`n"})
    templates.Push({name: "AHK 脚本", ext: ".ahk", template: "#Requires AutoHotkey v2.0`r`n`r`n"})
    templates.Push({name: "Python 脚本", ext: ".py", template: "# -*- coding: utf-8 -*-`r`n`r`n"})
    templates.Push({name: "Markdown 文件", ext: ".md", template: "# 标题`r`n`r`n"})

    ; 创建菜单
    menu := Menu()
    for tmpl in templates {
        display := tmpl.name
        if (tmpl.ext != "")
            display .= " (" tmpl.ext ")"
        menu.Add(display, MakeMenuCb("TC_CreateFileWithTemplate", tmpl))
    }

    menu.Show()
}

TC_ScanShellNewTemplates() {
    ; 从注册表扫描 ShellNew 模板
    templates := []

    try {
        ; 扫描 HKEY_CLASSES_ROOT 的 ShellNew 键
        Loop Reg, "HKEY_CLASSES_ROOT", "K"
        {
            ext := A_LoopRegName
            if (SubStr(ext, 1, 1) != ".")
                continue

            ; 检查是否有 ShellNew 子键 (v2: 键不存在即抛错, catch 后跳过)
            try {
                shellNew := RegRead("HKEY_CLASSES_ROOT\" ext "\ShellNew")
                if (shellNew != "") {
                    ; 获取类型名称
                    typeName := ""
                    try {
                        typeName := RegRead("HKEY_CLASSES_ROOT\" ext)
                    } catch {
                    }

                    templates.Push({
                        name: typeName != "" ? typeName : ext,
                        ext: ext,
                        template: ""
                    })
                }
            } catch {
            }
        }
    }

    return templates
}

TC_CreateFileWithTemplate(tmpl, *) {
    ; 获取当前目录
    currentDir := TC_GetCurrentDir()
    if (currentDir = "") {
        MsgBox "无法获取当前目录", "创建文件"
        return
    }

    ; 输入文件名 (v2: InputBox 返回 {Value, Result} 对象, 且 Prompt 在前 Title 在后)
    defaultName := "new" (tmpl.ext != "" ? tmpl.ext : "")
    try {
        ibox := InputBox("输入文件名:`n`n默认: " defaultName, "创建文件")
        fileName := ibox.Value
    } catch {
        return
    }
    if (fileName = "")
        fileName := defaultName

    ; 确保有正确的扩展名
    if (tmpl.ext != "" && !InStr(fileName, "."))
        fileName .= tmpl.ext

    ; 完整路径
    filePath := currentDir "\" fileName

    ; 检查文件是否已存在
    if FileExist(filePath) {
        result := MsgBox("文件已存在: " fileName "`n是否覆盖?", "确认", "YesNo")
        if (result != "Yes")
            return
    }

    ; 创建文件
    try {
        f := FileOpen(filePath, "w")
        if (tmpl.template != "")
            f.Write(tmpl.template)
        f.Close()

        Log("TC: Created file " filePath)
    } catch as e {
        MsgBox "创建文件失败: " e.Message, "错误"
    }
}

; 兼容别名: ini [TTOTAL_CMD] 引用的 VimDesktop 旧名, 指向现实现
; (ini 恢复编译后 i/. 键需要它们, 否则直调缺失函数导致按键变砖)
TC_CreateNewFileNewStyle() {
    TC_CreateNewFile()
}

; 对原版 TC_Run: 把命令打进 TC 下方命令行并回车执行 (64 位 Edit1; 非直接 Run)
TC_Run(cmd := "") {
    if (cmd = "")
        return
    try {
        ControlSetText(cmd, "Edit1", "ahk_class TTOTAL_CMD")
        ControlSend("{Enter}", "Edit1", "ahk_class TTOTAL_CMD")
    } catch {
        Run(cmd)
    }
}

TC_GetCurrentDir() {
    ; 获取 TC 当前目录 (v2: WinGetTitle/ControlGetText 直接返回值)
    try {
        title := WinGetTitle("ahk_class TTOTAL_CMD")
        ; 从标题栏提取路径
        if RegExMatch(title, "([A-Z]:\\[^\s]*)", &match) {
            return match[1]
        }
    } catch {
    }

    ; 备用：尝试从控件获取
    try {
        ; 获取左侧路径
        text1 := ControlGetText("Edit1", "ahk_class TTOTAL_CMD")
        if (text1 != "" && RegExMatch(text1, "^([A-Z]:\\)", &pathMatch))
            return pathMatch[1]
    } catch {
    }

    return ""
}

TC_CreateBlankFile() {
    ; 创建空文件
    currentDir := TC_GetCurrentDir()
    if (currentDir = "") {
        MsgBox "无法获取当前目录", "创建文件"
        return
    }

    try {
        ibox2 := InputBox("输入文件名:", "创建空文件")
        fileName := ibox2.Value
    } catch {
        return
    }
    if (fileName = "")
        return

    filePath := currentDir "\" fileName
    try {
        f := FileOpen(filePath, "w")
        f.Close()
        Log("TC: Created blank file " filePath)
    } catch as e {
        MsgBox "创建文件失败: " e.Message, "错误"
    }
}

TC_GoToParentEx() {
    ; 智能返回上层目录
    try {
        title := WinGetTitle("ahk_class TTOTAL_CMD")
        ; 检查是否在根目录
        if RegExMatch(title, "^([A-Z]:\\)$") {
            ; 在根目录，打开我的电脑
            Send "^l"  ; 聚焦地址栏
            Sleep 100
            Send "::{20D04FE0-3AEA-1069-A2D8-08002B30309D}"  ; 我的电脑
            Send "{Enter}"
        } else {
            Send "{Backspace}"
        }
    } catch {
    }
}

TC_AlwayOnTop() {
    static isTop := false
    if !isTop {
        WinSetAlwaysOnTop(1, "ahk_class TTOTAL_CMD")
        isTop := true
    } else {
        WinSetAlwaysOnTop(0, "ahk_class TTOTAL_CMD")
        isTop := false
    }
}

TC_ToggleShowInfo() {
    ; 切换按键提示显示
    static showInfo := true
    showInfo := !showInfo
    if showInfo
        Log("TC Info: ON")
    else
        Log("TC Info: OFF")
}

TC_Restart() {
    global TCPath
    if (TCPath != "") {
        try ProcessClose "totalcmd.exe"
        try ProcessClose "totalcmd64.exe"
        Sleep 500
        Run TCPath
    }
}

TC_Mark() {
    ; 标记功能 - 通过命令行输入 m + 字母来标记文件
    ; 支持: 设置标记(a-z), 跳转到标记('a), 删除标记(使用菜单)
    ; 标记持久化到 TCMark.ini

    ; 获取当前选中文件路径
    filePath := TC_GetSelectedFile()
    if (filePath = "") {
        MsgBox "请先选择一个文件", "标记"
        return
    }

    ; 显示标记菜单
    TC_ShowMarkMenu(filePath)
}

TC_ShowMarkMenu(filePath := "") {
    ; 显示标记管理菜单
    global TCINI
    markFile := Rim.appDir "\Conf\TCMark.ini"

    ; 读取现有标记 (ReadFileLines: 显式 UTF-8 + 去 BOM; Loop Read 读无 BOM 中文文件会吞行)
    marks := Map()
    for _mline in ReadFileLines(markFile) {
        line := Trim(_mline)
        if RegExMatch(line, "^(.*?)=(.*)$", &match) {
            marks[match[1]] := match[2]
        }
    }

    ; 创建菜单
    menu := Menu()

    ; 添加设置标记子菜单 (循环变量经工厂固化)
    setMarkMenu := Menu()
    loop 26 {
        idx := A_Index
        letter := Chr(96 + idx)  ; a-z
        setMarkMenu.Add(letter, MakeMenuCb("TC_SetMark", filePath, letter))
    }
    menu.Add("设置标记 (&S)", setMarkMenu)

    ; 添加跳转到标记子菜单
    if (marks.Count > 0) {
        gotoMenu := Menu()
        for path, char in marks {
            ; 提取文件名
            fileName := SubStr(path, InStr(path, "\", 0, -1) + 1)
            if (StrLen(fileName) > 30)
                fileName := SubStr(fileName, 1, 27) "..."
            gotoMenu.Add("[" char "] " fileName, MakeMenuCb("TC_GotoMark", path))
        }
        menu.Add("跳转到标记 (&G)", gotoMenu)

        ; 添加删除标记子菜单
        deleteMenu := Menu()
        for path, char in marks {
            fileName := SubStr(path, InStr(path, "\", 0, -1) + 1)
            if (StrLen(fileName) > 30)
                fileName := SubStr(fileName, 1, 27) "..."
            deleteMenu.Add("[" char "] " fileName, MakeMenuCb("TC_DeleteMark", path))
        }
        menu.Add("删除标记 (&D)", deleteMenu)

        ; 清除所有标记
        menu.Add()
        menu.Add("清除所有标记 (&C)", (*) => TC_ClearAllMarks())
    }

    ; 显示菜单
    menu.Show()
}

TC_SetMark(filePath, markChar) {
    ; 设置标记
    markFile := Rim.appDir "\Conf\TCMark.ini"

    ; 读取现有标记 (同上, 防吞行)
    marks := Map()
    for _mline in ReadFileLines(markFile) {
        line := Trim(_mline)
        if RegExMatch(line, "^(.*?)=(.*)$", &match) {
            marks[match[1]] := match[2]
        }
    }

    ; 添加或更新标记
    marks[filePath] := markChar

    ; 写入文件
    TC_WriteMarks(marks)

    Log("TC: Marked file " filePath " with: " markChar)
}

TC_GotoMark(filePath) {
    ; 跳转到标记的目录
    if DirExist(filePath) {
        ; 如果是目录，直接在 TC 中打开
        if WinExist("ahk_class TTOTAL_CMD") {
            ; 使用 cm_OpenDir 命令
            A_Clipboard := filePath
            Sleep 100
            Send "^v"
            Sleep 100
            Send "{Enter}"
        }
    } else if FileExist(filePath) {
        ; 如果是文件，打开文件所在目录
        dir := SubStr(filePath, 1, InStr(filePath, "\", 0, -1))
        if WinExist("ahk_class TTOTAL_CMD") {
            A_Clipboard := dir
            Sleep 100
            Send "^v"
            Sleep 100
            Send "{Enter}"
        }
    }
}

TC_DeleteMark(filePath) {
    ; 删除标记
    markFile := Rim.appDir "\Conf\TCMark.ini"

    ; 读取现有标记 (同上, 防吞行)
    marks := Map()
    for _mline in ReadFileLines(markFile) {
        line := Trim(_mline)
        if RegExMatch(line, "^(.*?)=(.*)$", &match) {
            marks[match[1]] := match[2]
        }
    }

    ; 删除标记
    if marks.Has(filePath)
        marks.Delete(filePath)

    ; 写入文件
    TC_WriteMarks(marks)

    Log("TC: Unmarked file " filePath)
}

TC_ClearAllMarks() {
    ; 清除所有标记
    markFile := Rim.appDir "\Conf\TCMark.ini"
    if FileExist(markFile)
        FileDelete markFile
    Log("TC: Cleared all marks")
}

TC_WriteMarks(marks) {
    ; 写入标记到文件
    markFile := Rim.appDir "\Conf\TCMark.ini"
    content := ""
    for path, char in marks {
        content .= path "=" char "`n"
    }
    if (content != "") {
        try {
            f := FileOpen(markFile, "w")
            f.Write(content)
            f.Close()
        }
    } else if FileExist(markFile) {
        FileDelete markFile
    }
}

TC_ListMark() {
    ; 显示标记列表 - 带交互菜单
    markFile := Rim.appDir "\Conf\TCMark.ini"

    if !FileExist(markFile) {
        MsgBox "暂无标记文件", "标记列表"
        return
    }

    ; 读取标记 (同上, 防吞行)
    marks := Map()
    for _mline in ReadFileLines(markFile) {
        line := Trim(_mline)
        if RegExMatch(line, "^(.*?)=(.*)$", &match) {
            marks[match[1]] := match[2]
        }
    }

    if (marks.Count = 0) {
        MsgBox "暂无标记", "标记列表"
        return
    }

    ; 创建菜单
    menu := Menu()
    for path, char in marks {
        fileName := SubStr(path, InStr(path, "\", 0, -1) + 1)
        if (StrLen(fileName) > 40)
            fileName := SubStr(fileName, 1, 37) "..."
        menu.Add("[" char "] " fileName, MakeMenuCb("TC_GotoMark", path))
    }
    menu.Add()
    menu.Add("清除所有标记", (*) => TC_ClearAllMarks())

    menu.Show()
}

TC_GetSelectedFile() {
    ; 获取 TC 当前选中的文件路径
    try {
        ; 尝试通过剪贴板获取
        clipBackup := A_Clipboard
        A_Clipboard := ""
        Send "^c"  ; 复制
        Sleep 100
        filePath := A_Clipboard
        A_Clipboard := clipBackup

        if (filePath != "" && FileExist(filePath))
            return filePath
    }
    return ""
}

TC_azHistory() {
    ; a-z 历史导航 - 完整交互式实现
    ; 读取 wincmd.ini 的左右面板历史
    ; 支持: 按字母跳转, 重定向, 特殊位置处理
    global TCINI

    if (TCINI = "" || !FileExist(TCINI)) {
        MsgBox "无法读取 TC 配置文件", "历史导航"
        return
    }

    ; 读取左面板历史
    leftHistory := []
    rightHistory := []

    try {
        ; 读取左面板历史
        i := 1
        loop {
            path := IniRead(TCINI, "LeftHistory", "Dir" i, "")
            if (path = "")
                break
            leftHistory.Push(TC_ResolveHistoryPath(path))
            i++
        }

        ; 读取右面板历史
        i := 1
        loop {
            path := IniRead(TCINI, "RightHistory", "Dir" i, "")
            if (path = "")
                break
            rightHistory.Push(TC_ResolveHistoryPath(path))
            i++
        }
    }

    if (leftHistory.Length = 0 && rightHistory.Length = 0) {
        MsgBox "暂无历史记录", "a-z 历史导航"
        return
    }

    ; 创建菜单
    menu := Menu()

    ; 左面板历史
    if (leftHistory.Length > 0) {
        leftMenu := Menu()
        maxCount := Min(leftHistory.Length, 26)
        loop maxCount {
            idx := A_Index
            letter := Chr(96 + idx)  ; a, b, c...
            path := leftHistory[idx]
            ; 截断过长的路径
            displayPath := path
            if (StrLen(displayPath) > 50)
                displayPath := "..." SubStr(displayPath, -47)
            leftMenu.Add("[" letter "] " displayPath, MakeMenuCb("TC_GotoHistory", path, "left"))
        }
        menu.Add("左面板历史 (&L)", leftMenu)
    }

    ; 右面板历史
    if (rightHistory.Length > 0) {
        rightMenu := Menu()
        maxCount := Min(rightHistory.Length, 26)
        loop maxCount {
            idx := A_Index
            letter := Chr(64 + idx)  ; A, B, C...
            path := rightHistory[idx]
            displayPath := path
            if (StrLen(displayPath) > 50)
                displayPath := "..." SubStr(displayPath, -47)
            rightMenu.Add("[" letter "] " displayPath, MakeMenuCb("TC_GotoHistory", path, "right"))
        }
        menu.Add("右面板历史 (&R)", rightMenu)
    }

    ; 清除历史
    menu.Add()
    menu.Add("清除左面板历史", (*) => TC_ClearHistory("LeftHistory"))
    menu.Add("清除右面板历史", (*) => TC_ClearHistory("RightHistory"))
    menu.Add("清除所有历史", (*) => TC_ClearHistory("all"))

    ; 显示菜单
    menu.Show()
}

TC_ResolveHistoryPath(path) {
    ; 解析历史路径，处理特殊位置
    ; 特殊位置映射
    specialPaths := Map(
        "::{20D04FE0-3AEA-1069-A2D8-08002B30309D}", "此电脑",
        "::{645FF040-5081-101B-9F08-00AA002F954E}", "回收站",
        "::{B4BFCC3A-DB2C-424C-B029-7FE99A8CEC6C}", "桌面",
        "::{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}", "网络"
    )

    if specialPaths.Has(path)
        return specialPaths[path]

    return path
}

TC_GotoHistory(path, panel) {
    ; 跳转到历史目录
    if !WinExist("ahk_class TTOTAL_CMD")
        return

    ; 激活 TC
    WinActivate("ahk_class TTOTAL_CMD")
    Sleep 100

    ; 切换到对应面板
    if (panel = "right") {
        Send "{Tab}"  ; 切换到右面板
        Sleep 50
    }

    ; 使用命令行导航
    ; 按 Alt+Left 打开路径输入框
    Send "!{Left}"
    Sleep 200

    ; 清空并输入路径
    Send "^a"
    Sleep 50
    A_Clipboard := path
    Send "^v"
    Sleep 100
    Send "{Enter}"
}

TC_ClearHistory(section) {
    ; 清除历史记录
    global TCINI

    if (TCINI = "" || !FileExist(TCINI))
        return

    if (section = "all") {
        ; 清除所有历史
        try {
            IniDelete(TCINI, "LeftHistory")
            IniDelete(TCINI, "RightHistory")
        }
        Log("TC: Cleared all history")
    } else {
        try {
            IniDelete(TCINI, section)
        }
        Log("TC: Cleared " section)
    }
}

TC_ToggleMenu() {
    ; 切换菜单栏显示/隐藏
    ; 通过修改 wincmd.ini 的 RestrictInterface 值
    global TCINI

    if (TCINI = "" || !FileExist(TCINI)) {
        MsgBox "无法读取 TC 配置文件", "菜单切换"
        return
    }

    ; 读取当前设置
    restrict := IniRead(TCINI, "Configuration", "RestrictInterface", "0")
    if (restrict = "")
        restrict := "0"

    ; 切换菜单栏
    if InStr(restrict, "1") {
        ; 隐藏菜单栏
        restrict := StrReplace(restrict, "1", "0")
        state := "隐藏"
    } else {
        ; 显示菜单栏
        restrict := "1" restrict
        state := "显示"
    }

    ; 保存设置
    IniWrite(restrict, TCINI, "Configuration", "RestrictInterface")

    ; 刷新 TC 界面
    TC_Refresh界面()
    Log("TC: Menu bar toggled to " state)
}

TC_ToggleToolbar() {
    ; 切换工具栏显示/隐藏
    global TCINI

    if (TCINI = "" || !FileExist(TCINI)) {
        return
    }

    ; 读取当前设置
    restrict := IniRead(TCINI, "Configuration", "RestrictInterface", "0")
    if (restrict = "")
        restrict := "0"

    ; 切换工具栏
    if InStr(restrict, "2") {
        restrict := StrReplace(restrict, "2", "0")
        state := "隐藏"
    } else {
        restrict := restrict "2"
        state := "显示"
    }

    IniWrite(restrict, TCINI, "Configuration", "RestrictInterface")
    TC_Refresh界面()
    Log("TC: Toolbar toggled to " state)
}

TC_ToggleStatusBar() {
    ; 切换状态栏显示/隐藏
    global TCINI

    if (TCINI = "" || !FileExist(TCINI)) {
        return
    }

    ; 读取当前设置
    restrict := IniRead(TCINI, "Configuration", "RestrictInterface", "0")
    if (restrict = "")
        restrict := "0"

    ; 切换状态栏
    if InStr(restrict, "4") {
        restrict := StrReplace(restrict, "4", "0")
        state := "隐藏"
    } else {
        restrict := restrict "4"
        state := "显示"
    }

    IniWrite(restrict, TCINI, "Configuration", "RestrictInterface")
    TC_Refresh界面()
    Log("TC: Status bar toggled to " state)
}

TC_Refresh界面() {
    ; 刷新 TC 界面（通过发送消息）
    if WinExist("ahk_class TTOTAL_CMD") {
        PostMessage(1075, 540, 0, , "ahk_class TTOTAL_CMD")  ; cm_RereadSource 刷新 (原版 540; 移植版误写 2027=打印目录)
    }
}

TC_WinMaxLeft() {
    ; 最大化左面板（通过移动分隔条）
    try {
        WinGetPos(&x, &y, &w, &h, "ahk_class TTOTAL_CMD")

        ; 获取分隔条位置（大约在中间）
        midX := x + w // 2

        ; 移动分隔条到最右边
        ControlMove(midX - 10, , , , "TMySplitter", "ahk_class TTOTAL_CMD")
    }
}

TC_WinMaxRight() {
    ; 最大化右面板（通过移动分隔条）
    try {
        WinGetPos(&x, &y, &w, &h, "ahk_class TTOTAL_CMD")

        ; 移动分隔条到最左边
        ControlMove(x + 10, , , , "TMySplitter", "ahk_class TTOTAL_CMD")
    }
}

TC_FileCopyForBak() {
    ; 复制文件并加 .bak 后缀
    filePath := TC_GetSelectedFile()
    if (filePath = "") {
        MsgBox "请先选择一个文件", "复制备份"
        return
    }

    bakPath := filePath ".bak"
    try {
        FileCopy(filePath, bakPath)
        Log("TC: Copied " filePath " to " bakPath)
    } catch as e {
        MsgBox "复制失败: " e.Message, "错误"
    }
}

TC_FileMoveForBak() {
    ; 重命名文件加 .bak 后缀
    filePath := TC_GetSelectedFile()
    if (filePath = "") {
        MsgBox "请先选择一个文件", "重命名备份"
        return
    }

    bakPath := filePath ".bak"
    try {
        FileMove(filePath, bakPath)
        Log("TC: Moved " filePath " to " bakPath)
    } catch as e {
        MsgBox "重命名失败: " e.Message, "错误"
    }
}

TC_CreateFileShortcut() {
    ; 创建快捷方式
    filePath := TC_GetSelectedFile()
    if (filePath = "") {
        MsgBox "请先选择一个文件", "创建快捷方式"
        return
    }

    ; 获取当前目录
    currentDir := TC_GetCurrentDir()
    if (currentDir = "") {
        MsgBox "无法获取当前目录", "创建快捷方式"
        return
    }

    ; 创建快捷方式
    shortcutPath := currentDir "\" SubStr(filePath, InStr(filePath, "\", 0, -1) + 1) ".lnk"
    try {
        FileCreateShortcut(filePath, shortcutPath)
        Log("TC: Created shortcut " shortcutPath)
    } catch as e {
        MsgBox "创建快捷方式失败: " e.Message, "错误"
    }
}

TC_CreateFileShortcutToDesktop() {
    ; 创建快捷方式到桌面
    filePath := TC_GetSelectedFile()
    if (filePath = "") {
        MsgBox "请先选择一个文件", "创建快捷方式到桌面"
        return
    }

    desktopPath := A_Desktop "\" SubStr(filePath, InStr(filePath, "\", 0, -1) + 1) ".lnk"
    try {
        FileCreateShortcut(filePath, desktopPath)
        Log("TC: Created shortcut to desktop " desktopPath)
    } catch as e {
        MsgBox "创建快捷方式失败: " e.Message, "错误"
    }
}

TC_ForceDelete() {
    Send "+{Del}"
}

TC_Toggle_50_100Percent() {
    ; 切换窗口大小 50%/100%
    static isHalf := false
    WinGetPos(&x, &y, &w, &h, "ahk_class TTOTAL_CMD")

    if !isHalf {
        newW := w // 2
        newH := h // 2
        newX := x + (w - newW) // 2
        newY := y + (h - newH) // 2
        WinMove(newX, newY, newW, newH, "ahk_class TTOTAL_CMD")
        isHalf := true
    } else {
        WinMove(x, y, w * 2, h * 2, "ahk_class TTOTAL_CMD")
        isHalf := false
    }
}

TC_SelectCmd() {
    ; TC 命令浏览器 - 显示常用命令列表
    static commands := Map()

    ; 初始化命令列表 (编号与 cmdMap 一致)
    if (commands.Count = 0) {
        commands["cm_CopyOtherpanel (复制到对侧)"] := 2001
        commands["cm_MoveOnly (移动到对侧)"] := 2002
        commands["cm_Delete (删除)"] := 2003
        commands["cm_Edit (编辑文件)"] := 2004
        commands["cm_View (查看文件)"] := 2005
        commands["cm_PackFiles (压缩文件)"] := 2006
        commands["cm_UnpackFiles (解压文件)"] := 2007
        commands["cm_CopyToClipboard (复制到剪贴板)"] := 2009
        commands["cm_CutToClipboard (剪切到剪贴板)"] := 2010
        commands["cm_PasteFromClipboard (粘贴)"] := 2011
        commands["cm_MkDir (新建文件夹)"] := 2012
        commands["cm_RenameOnly (重命名)"] := 2013
        commands["cm_MultiRenameFiles (批量重命名)"] := 2014
        commands["cm_SrcByName (按名称排序)"] := 2015
        commands["cm_SrcByExt (按扩展名排序)"] := 2016
        commands["cm_SrcBySize (按大小排序)"] := 2017
        commands["cm_SrcByDateTime (按日期排序)"] := 2018
        commands["cm_SrcNegSort (反向排序)"] := 2020
        commands["cm_SrcShort (短列表)"] := 2021
        commands["cm_SrcLong (长列表)"] := 2022
        commands["cm_SrcTree (目录树)"] := 2023
        commands["cm_SrcThumbs (缩略图)"] := 2024
        commands["cm_SrcQuickView (快速预览)"] := 2025
        commands["cm_ToggleTreeView (切换目录树)"] := 2026
        commands["cm_Refresh (刷新)"] := 2027
        commands["cm_CopySrcPathToClip (复制源路径)"] := 2029
        commands["cm_SelectAll (全选)"] := 2030
        commands["cm_ExchangeSelection (反选)"] := 2031
        commands["cm_MaximizePanel1 (最大化左面板)"] := 2032
        commands["cm_MaximizePanel2 (最大化右面板)"] := 2033
        commands["cm_Exchange (交换面板)"] := 2034
        commands["cm_Minimize (最小化)"] := 2035
        commands["cm_Maximize (最大化)"] := 2036
        commands["cm_Restore (还原)"] := 2037
        commands["cm_DirectoryHotlist (常用文件夹)"] := 2039
        commands["cm_CopyNamesToClip (复制文件名)"] := 2040
        commands["cm_CopyFullNamesToClip (复制完整路径)"] := 2041
        commands["cm_SearchFor (搜索)"] := 2042
        commands["cm_ShowQuickSearch (快速搜索)"] := 2043
        commands["cm_CompareDirs (比较目录)"] := 2044
        commands["cm_SyncDirs (同步目录)"] := 2045
        commands["cm_CompareByContent (按内容比较)"] := 2046
        commands["cm_ContextMenu (右键菜单)"] := 2047
        commands["cm_ExecuteDOS (命令提示符)"] := 2048
        commands["cm_FocusCmdLine (焦点到命令行)"] := 2049
        commands["cm_LeftOpenDrives (左侧驱动器)"] := 2050
        commands["cm_RightOpenDrives (右侧驱动器)"] := 2051
        commands["cm_Config (配置)"] := 2052
        commands["cm_DirHome (回到目标目录首页)"] := 2053
        commands["cm_GotoRoot (转到根目录)"] := 2054
        commands["cm_GotoPreviousDir (后退)"] := 2055
        commands["cm_GotoNextDir (前进)"] := 2056
        commands["cm_OpenDesktop (桌面)"] := 2057
        commands["cm_OpenNewTab (新建标签)"] := 3001
        commands["cm_OpenNewTabBg (后台新建标签)"] := 3002
        commands["cm_SwitchToNextTab (下一个标签)"] := 3003
        commands["cm_SwitchToPreviousTab (上一个标签)"] := 3004
        commands["cm_CloseCurrentTab (关闭当前标签)"] := 3005
        commands["cm_CloseAllTabs (关闭所有标签)"] := 3006
        commands["cm_Exit (退出TC)"] := 2063
    }

    ; 创建菜单 (循环变量经 MakeMenuCb 工厂固化: 闭包直捕越界, .Bind 叠参, 两坑全避)
    menu := Menu()
    for name, cmdNum in commands {
        menu.Add(name, MakeMenuCb("TC_SendPos", cmdNum))
    }

    ; 显示菜单
    menu.Show()
}

TC_OpenDriveThis() {
    ; 打开驱动器列表（本侧）
    TC_SendPos(2050)  ; cm_LeftOpenDrives
}

TC_OpenDriveThat() {
    ; 打开驱动器列表（另侧）
    TC_SendPos(2051)  ; cm_RightOpenDrives
}

; === 高级功能 ===

TC_CopyUseQueues() {
    ; 对原版: 无需确认, 使用队列拷贝文件至另一窗口 (F5 复制 + F2 进队列)
    Send "{F5}"
    Sleep 100
    Send "{F2}"
}

TC_MoveUseQueues() {
    ; 对原版: 无需确认, 使用队列移动文件至另一窗口 (F6 移动 + F2 进队列)
    Send "{F6}"
    Sleep 100
    Send "{F2}"
}

TC_CopyDirectoryHotlist() {
    ; 复制到常用文件夹 (对原版 526; 移植版误写 2039=存详细信息)
    TC_SendPos(526)  ; cm_DirectoryHotlist
}

TC_MoveDirectoryHotlist() {
    ; 移动到常用文件夹
    TC_SendPos(526)  ; cm_DirectoryHotlist
    Sleep 200
    Send "{Tab}{Tab}{Enter}"  ; 切换到目标面板
}

TC_GotoPreviousDirOther() {
    ; 另一侧后退 (对原版: Tab 切对侧 + 570, 非 F12+2055)
    Send "{Tab}"
    Sleep 100
    TC_SendPos(570)  ; cm_GotoPreviousDir
    Sleep 100
    Send "{Tab}"
}

TC_GotoNextDirOther() {
    ; 另一侧前进 (对原版: Tab 切对侧 + 571)
    Send "{Tab}"
    Sleep 100
    TC_SendPos(571)  ; cm_GotoNextDir
    Sleep 100
    Send "{Tab}"
}

TC_SearchMode() {
    ; 连续搜索模式
    Send "{F3}"  ; 打开查看器
    Sleep 100
    Send "{Tab}"  ; 切换到搜索标签
}

TC_ReOpenTab() {
    ; 重新打开关闭的标签
    Send "^+{t}"
}

TC_GoLastTab() {
    ; 跳到最后一个标签
    Send "^{End}"
}

TC_Toggle_50_100Percent_V() {
    ; 纵向切换窗口大小
    static isHalf := false
    WinGetPos(&x, &y, &w, &h, "ahk_class TTOTAL_CMD")

    if !isHalf {
        newH := h // 2
        newY := y + (h - newH) // 2
        WinMove(x, newY, w, newH, "ahk_class TTOTAL_CMD")
        isHalf := true
    } else {
        WinMove(x, y, w, h * 2, "ahk_class TTOTAL_CMD")
        isHalf := false
    }
}

TC_SuperReturn() {
    ; 回车后定位到第一个文件
    Send "{Enter}"
    Sleep 100
    Send "{Home}"
}

TC_MultiFilePersistOpen() {
    ; 多文件连续打开
    Loop {
        if !GetKeyState("Enter", "P")
            break
        Send "{Enter}"
        Sleep 50
    }
}

TC_CopyFileContents() {
    ; 复制文件内容（不打开文件）
    filePath := TC_GetSelectedFile()
    if (filePath != "" && FileExist(filePath)) {
        try {
            f := FileOpen(filePath, "r")
            content := f.Read()
            f.Close()
            A_Clipboard := content
            Log("TC: Copied file contents from " filePath)
        } catch as e {
            MsgBox "读取文件失败: " e.Message, "错误"
        }
    }
}

TC_OpenDirAndPaste() {
    ; 不打开目录直接粘贴
    filePath := TC_GetSelectedFile()
    if (filePath != "") {
        dir := SubStr(filePath, 1, InStr(filePath, "\", 0, -1))
        Run "explorer.exe " dir
        Sleep 300
        Send "^v"  ; 粘贴
    }
}

TC_MoveSelectedFilesToPrevFolder() {
    ; 移动选中文件到上级目录
    Send "^{Up}"
    Sleep 100
    Send "{F6}"  ; 移动
}

TC_MoveAllFilesToPrevFolder() {
    ; 移动所有文件到上级目录
    Send "^a"  ; 全选
    Sleep 100
    Send "^{Up}"
    Sleep 100
    Send "{F6}"  ; 移动
}

TC_SrcQuickViewAndTab() {
    ; 预览文件时光标移到对侧
    Send "{F3}"  ; 快速预览
    Sleep 100
    Send "{F12}"  ; 切换到另一侧
}

TC_CreateFileShortcutToStartup() {
    ; 创建快捷方式到启动目录
    filePath := TC_GetSelectedFile()
    if (filePath = "") {
        MsgBox "请先选择一个文件", "创建快捷方式"
        return
    }

    startupPath := A_Startup "\" SubStr(filePath, InStr(filePath, "\", 0, -1) + 1) ".lnk"
    try {
        FileCreateShortcut(filePath, startupPath)
        Log("TC: Created shortcut to startup " startupPath)
    } catch as e {
        MsgBox "创建快捷方式失败: " e.Message, "错误"
    }
}

TC_FilterSearchFNsuffix_exe() {
    ; 快速过滤 exe 文件
    Send "!{F7}"  ; 打开搜索
    Sleep 200
    Send "*.exe"
    Sleep 100
    Send "{Enter}"
}

TC_TwoFileExchangeName() {
    ; 两个文件互换名称
    file1 := TC_GetSelectedFile()
    if (file1 = "") {
        MsgBox "请先选择第一个文件", "互换名称"
        return
    }

    ; 提示选择第二个文件
    MsgBox "请记住第一个文件名，然后选择第二个文件并点击确定", "互换名称"
    Send "{Down}"  ; 移动到下一个文件
    Sleep 100

    file2 := TC_GetSelectedFile()
    if (file2 = "") {
        MsgBox "未选择第二个文件", "互换名称"
        return
    }

    ; 获取两个文件的路径和名称
    dir1 := SubStr(file1, 1, InStr(file1, "\", 0, -1))
    dir2 := SubStr(file2, 1, InStr(file2, "\", 0, -1))
    name1 := SubStr(file1, InStr(file1, "\", 0, -1) + 1)
    name2 := SubStr(file2, InStr(file2, "\", 0, -1) + 1)

    ; 临时文件名
    tempName := name1 ".temp_rename"

    ; 执行重命名
    try {
        FileMove(dir1 name1, dir1 tempName)
        FileMove(dir2 name2, dir1 name1)
        FileMove(dir1 tempName, dir2 name2)
        Log("TC: Exchanged names " name1 " <-> " name2)
    } catch as e {
        MsgBox "互换名称失败: " e.Message, "错误"
    }
}

TC_MarkFile() {
    ; 通过文件备注标记
    filePath := TC_GetSelectedFile()
    if (filePath = "") {
        MsgBox "请先选择一个文件", "标记文件"
        return
    }

    try {
        ibox3 := InputBox("输入标记文本:`n`n文件: " filePath, "标记文件")
        markText := ibox3.Value
    } catch {
        return
    }
    if (markText = "")
        return

    ; 保存标记
    markFile := Rim.appDir "\Conf\TCFileMarks.ini"
    IniWrite(markText, markFile, "marks", filePath)
    Log("TC: Marked file " filePath " with: " markText)
}

TC_UnMarkFile() {
    ; 取消文件标记
    filePath := TC_GetSelectedFile()
    if (filePath = "") {
        MsgBox "请先选择一个文件", "取消标记"
        return
    }

    markFile := Rim.appDir "\Conf\TCFileMarks.ini"
    try {
        IniDelete(markFile, "marks", filePath)
        Log("TC: Unmarked file " filePath)
    }
}

TC_ClearTitle() {
    ; 清空标题栏
    WinSetTitle("Total Commander", "ahk_class TTOTAL_CMD")
}

TC_OpenDirsInFile() {
    ; 从文件内容批量打开目录
    filePath := TC_GetSelectedFile()
    if (filePath = "" || !FileExist(filePath)) {
        MsgBox "请选择一个包含目录列表的文件", "打开目录"
        return
    }

    try {
        f := FileOpen(filePath, "r")
        content := f.Read()
        f.Close()

        ; 按行分割
        Loop Parse, content, "`n", "`r" {
            line := Trim(A_LoopField)
            if (line = "")
                continue

            ; 检查是否是目录
            if DirExist(line) {
                Run "explorer.exe " line
                Sleep 200
            }
        }
    } catch as e {
        MsgBox "读取文件失败: " e.Message, "错误"
    }
}

TC_CreateBlankFileNoExt() {
    ; 创建无扩展名空文件
    currentDir := TC_GetCurrentDir()
    if (currentDir = "") {
        MsgBox "无法获取当前目录", "创建文件"
        return
    }

    try {
        ibox4 := InputBox("输入文件名:", "创建无扩展名文件")
        fileName := ibox4.Value
    } catch {
        return
    }
    if (fileName = "")
        return

    ; 移除可能的扩展名
    if InStr(fileName, ".")
        fileName := SubStr(fileName, 1, InStr(fileName, ".", 0, -1) - 1)

    filePath := currentDir "\" fileName
    try {
        f := FileOpen(filePath, "w")
        f.Close()
        Log("TC: Created blank file without extension " filePath)
    } catch as e {
        MsgBox "创建文件失败: " e.Message, "错误"
    }
}

TC_PasteFileEx() {
    ; 粘贴到光标下的目录 (v2: ControlGetFocus/ControlGetText 直接返回值)
    ; 注意 ControlGetText 读 ListBox 恒为空, 这里只做目录/文件存在性分支
    try {
        ; 获取光标下的文件/目录名
        hwnd := ControlGetFocus("ahk_class TTOTAL_CMD")
        focused := ControlGetClassNN(hwnd, "ahk_class TTOTAL_CMD")

        if InStr(focused, "ListBox") {
            ; 获取当前选中项
            text := ControlGetText(focused, "ahk_class TTOTAL_CMD")
            if DirExist(text) {
                ; 如果是目录，进入并粘贴
                Send "{Enter}"
                Sleep 100
                Send "^v"
            } else {
                ; 如果是文件，粘贴到上级目录
                Send "^{Up}"
                Sleep 100
                Send "^v"
            }
        }
    } catch {
    }
}

TC_ThumbsView() {
    ; 对原版: 进缩略图 + h/l 临时变左右方向键; 再按 m 切回 (else 分支即 ini 值)
    static isThumbs := false
    TC_SendPos(269)  ; cm_SrcThumbs (移植版误写 2024=对侧打开/2022=比较, 已纠正)
    isThumbs := !isThumbs
    if (isThumbs) {
        MapKey("h", "<left>", "TTOTAL_CMD", "normal")
        MapKey("l", "<right>", "TTOTAL_CMD", "normal")
    } else {
        MapKey("h", "<TC_GoToParentEx>", "TTOTAL_CMD", "normal")
        MapKey("l", "<TC_SuperReturn>", "TTOTAL_CMD", "normal")
    }
}

TC_SrcActivateTab1() {
    ; 激活第一个标签
    Send "^1"
}

TC_SrcActivateTab2() {
    ; 激活第二个标签
    Send "^2"
}

TC_SrcActivateTab3() {
    ; 激活第三个标签
    Send "^3"
}

TC_SrcActivateTab4() {
    ; 激活第四个标签
    Send "^4"
}

TC_SrcActivateTab5() {
    ; 激活第五个标签
    Send "^5"
}

TC_SrcActivateTab6() {
    ; 激活第六个标签
    Send "^6"
}

TC_SrcActivateTab7() {
    ; 激活第七个标签
    Send "^7"
}

TC_SrcActivateTab8() {
    ; 激活第八个标签
    Send "^8"
}

TC_SrcActivateTab9() {
    ; 激活第九个标签
    Send "^9"
}
