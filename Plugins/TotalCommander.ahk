#Requires AutoHotkey v2.0

; === TotalCommander Plugin - TC深度集成 ===
; 移植自 VimDesktop 的 TC 插件（完整版）
; 子模块: TC.Menu (自造 Gui 菜单 + 新建文件对话框); 注册/映射/动作为主体留本文件

#Include TC.Menu.ahk

class TotalCommanderPlugin extends RimPlugin {
    static Name => "TotalCommander"
    static Title => "Total Commander Integration"
    static Description => "Total Commander 深度整合 (双栏文件管理、Vim 模式、标记系统、原生菜单联动)"

    static RegisterContext() {
        try RimContext.RegisterProvider("totalcommander", TC_ContextProvider)
    }

    static RegisterCommands() {
        try {
            RimCommand.Register("tc.open", T("cmdtitle.tc.open"), (*) => TC_Open(), Map(
                "Category", "Tool",
                "Description", "启动或激活 Total Commander",
                "Keywords", "tc totalcommander filemanager"
            ))
            RimCommand.Register("tc.reopen", T("cmdtitle.tc.reopen"), (*) => TC_ReOpen(), Map(
                "Category", "Tool",
                "Description", "重启 Total Commander 进程",
                "Keywords", "tc restart reload"
            ))
        }
    }

    static RegisterGestures() {
        if (!IsSet(GestureRegistry) || !IsObject(GestureRegistry))
            return
        GestureRegistry.Register("U", (*) => TC_SendPos(2002), "ahk_class TTOTAL_CMD", {
            description: "TC: 打开父目录 (cm_GoToParent)",
            pluginName: "TotalCommander"
        })
        GestureRegistry.Register("D_R", (*) => TC_SendPos(3001), "ahk_class TTOTAL_CMD", {
            description: "TC: 新建标签页 (cm_OpenNewTab)",
            pluginName: "TotalCommander"
        })
        GestureRegistry.Register("D_L", (*) => TC_SendPos(3007), "ahk_class TTOTAL_CMD", {
            description: "TC: 关闭当前标签页 (cm_CloseCurrentTab)",
            pluginName: "TotalCommander"
        })
    }

    static RegisterKeymaps(engine) {
        TotalCommander_Keymaps(engine)
    }
}

if (IsSet(RimPluginManager) && IsObject(RimPluginManager))
    RimPluginManager.Register(TotalCommanderPlugin)

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

; 统一处理以 cm_ 开头的动作 (由 Rim.vim.RegisterPrefixActionHandler 挂载)
TC_HandleCmAction(funcName) {
    if (SubStr(funcName, 1, 1) = "<" && SubStr(funcName, -1) = ">")
        funcName := SubStr(funcName, 2, StrLen(funcName) - 2)
    cmNum := TC_GetCommandNumber(funcName)
    if (cmNum > 0) {
        TC_SendPos(cmNum)
        return true
    }
    return false
}

; 校验 cm_ 动作是否合法 (由 Rim.vim.RegisterActionValidator 挂载)
TC_ValidateCmAction(action) {
    if RegExMatch(action, "^<cm_(.+)>$", &_cm) {
        num := TC_GetCommandNumber("cm_" _cm[1])
        return num > 0
    }
    return true
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
    ; v2 自家菜单是 Xaml_WindowedPopupClass (不是 #32768, 探针实测),
    ; 不认它则 F/S/上下/回车/Esc 全被钩子吞掉, 菜单变死菜单
    menuOpen := WinExist("ahk_class #32768") || WinExist("ahk_class Xaml_WindowedPopupClass")
    if (menuOpen && g_TCLastCmd != 572)
        return true

    ; 焦点在列表框 → 执行动作 (v2 取焦点类名, 不是 HWND 比串)
    focused := FocusedClassNN("ahk_class TTOTAL_CMD")
    if InStr(focused, "LCLListBox") || InStr(focused, "TMyListBox")
        return false
    return true
}

; === TC 窗口级按键拦截/预过滤 (从核心引擎解耦) ===
; 1) 原生/XAML弹出菜单开着: 全键提前透传 (F/S 等是多键前缀, 走不到 BeforeActionDo,
;    会被 KeyTemp 吞掉致菜单键盘全死; 对齐原版"菜单开着就透传")
; 2) 自家 TCMenu Gui 菜单开着但还没抢到焦点: 直接路由到菜单, 不经 Send
TC_PreKeyFilter(vimKey, win) {
    global g_TCLastCmd
    tcMenuOpen := WinExist("ahk_class #32768") || WinExist("ahk_class Xaml_WindowedPopupClass")
    if (tcMenuOpen && g_TCLastCmd != 572) {
        Send(Rim.vim.ConvertFromVim(vimKey, true))
        win.KeyTemp := ""
        win.Count := 0
        win.HideMore()
        return true
    }

    try {
        if WinExist("TCMenu ahk_class AutoHotkeyGUI") {
            routed := false
            try routed := TC_MenuRouteKey(vimKey)
            if (routed) {
                win.KeyTemp := ""
                win.Count := 0
                win.HideMore()
                return true
            }
            ; 路由不消费 (数字/符号等非菜单键): 仍激活菜单再透传, 避免键落错窗
            if !WinActive("TCMenu ahk_class AutoHotkeyGUI") {
                try WinActivate("TCMenu ahk_class AutoHotkeyGUI")
            }
            Send(Rim.vim.ConvertFromVim(vimKey, true))
            win.KeyTemp := ""
            win.Count := 0
            win.HideMore()
            return true
        }
    }
    return false
}

TotalCommander_Keymaps(engine) {
    ; 检测 TC 路径
    DetectTCPath()

    ; 修复 64 位控件 ID
    FixTCEditId()


    ; 中文注释表 (517 条, 抽自原版 vim.Comment, 供 g 提示面板显示; 后续特化注册可覆盖措辞)
    engine.SetAction("<cm_100Percent>", T("act.TotalCommander.cm_100Percent"))
    engine.SetAction("<cm_50Percent>", T("act.TotalCommander.cm_50Percent"))
    engine.SetAction("<cm_About>", T("act.TotalCommander.cm_About"))
    engine.SetAction("<cm_AddPathToCmdline>", T("act.TotalCommander.cm_AddPathToCmdline"))
    engine.SetAction("<cm_AdministerServer>", T("act.TotalCommander.cm_AdministerServer"))
    engine.SetAction("<cm_Associate>", T("act.TotalCommander.cm_Associate"))
    engine.SetAction("<cm_ButtonConfig>", T("act.TotalCommander.cm_ButtonConfig"))
    engine.SetAction("<cm_CDtree>", T("act.TotalCommander.cm_CDtree"))
    engine.SetAction("<cm_ChangeStartMenu>", T("act.TotalCommander.cm_ChangeStartMenu"))
    engine.SetAction("<cm_ClearAll>", T("act.TotalCommander.cm_ClearAll"))
    engine.SetAction("<cm_ClearAllCfg>", T("act.TotalCommander.cm_ClearAllCfg"))
    engine.SetAction("<cm_ClearAllFiles>", T("act.TotalCommander.cm_ClearAllFiles"))
    engine.SetAction("<cm_ClearAllFolders>", T("act.TotalCommander.cm_ClearAllFolders"))
    engine.SetAction("<cm_ClearCmdLine>", T("act.TotalCommander.cm_ClearCmdLine"))
    engine.SetAction("<cm_ClearFiles>", T("act.TotalCommander.cm_ClearFiles"))
    engine.SetAction("<cm_ClearFolders>", T("act.TotalCommander.cm_ClearFolders"))
    engine.SetAction("<cm_ClearSelCfg>", T("act.TotalCommander.cm_ClearSelCfg"))
    engine.SetAction("<cm_CloseAllTabs>", T("act.TotalCommander.cm_CloseAllTabs"))
    engine.SetAction("<cm_CloseCurrentTab>", T("act.TotalCommander.cm_CloseCurrentTab"))
    engine.SetAction("<cm_ColorConfig>", T("act.TotalCommander.cm_ColorConfig"))
    engine.SetAction("<cm_Combine>", T("act.TotalCommander.cm_Combine"))
    engine.SetAction("<cm_CommandBrowser>", T("act.TotalCommander.cm_CommandBrowser"))
    engine.SetAction("<cm_CompareDirs>", T("act.TotalCommander.cm_CompareDirs"))
    engine.SetAction("<cm_CompareDirsWithSubdirs>", T("act.TotalCommander.cm_CompareDirsWithSubdirs"))
    engine.SetAction("<cm_CompareFilesByContent>", T("act.TotalCommander.cm_CompareFilesByContent"))
    engine.SetAction("<cm_Config>", T("act.TotalCommander.cm_Config"))
    engine.SetAction("<cm_Config2>", T("act.TotalCommander.cm_Config2"))
    engine.SetAction("<cm_ConfigChangeIniFiles>", T("act.TotalCommander.cm_ConfigChangeIniFiles"))
    engine.SetAction("<cm_ConfigSaveDirHistory>", T("act.TotalCommander.cm_ConfigSaveDirHistory"))
    engine.SetAction("<cm_ConfigSavePos>", T("act.TotalCommander.cm_ConfigSavePos"))
    engine.SetAction("<cm_ConfigSaveSettings>", T("act.TotalCommander.cm_ConfigSaveSettings"))
    engine.SetAction("<cm_Confirmation>", T("act.TotalCommander.cm_Confirmation"))
    engine.SetAction("<cm_ConfTabChange>", T("act.TotalCommander.cm_ConfTabChange"))
    engine.SetAction("<cm_ContentStopLoadFields>", T("act.TotalCommander.cm_ContentStopLoadFields"))
    engine.SetAction("<cm_ContextMenu>", T("act.TotalCommander.cm_ContextMenu"))
    engine.SetAction("<cm_ContextMenuInternal>", T("act.TotalCommander.cm_ContextMenuInternal"))
    engine.SetAction("<cm_ContextMenuInternalCursor>", T("act.TotalCommander.cm_ContextMenuInternalCursor"))
    engine.SetAction("<cm_Copy>", T("act.TotalCommander.cm_Copy"))
    engine.SetAction("<cm_CopyConfig>", T("act.TotalCommander.cm_CopyConfig"))
    engine.SetAction("<cm_CopyFileDetailsToClip>", T("act.TotalCommander.cm_CopyFileDetailsToClip"))
    engine.SetAction("<cm_CopyFpFileDetailsToClip>", T("act.TotalCommander.cm_CopyFpFileDetailsToClip"))
    engine.SetAction("<cm_CopyFullNamesToClip>", T("act.TotalCommander.cm_CopyFullNamesToClip"))
    engine.SetAction("<cm_CopyNamesToClip>", T("act.TotalCommander.cm_CopyNamesToClip"))
    engine.SetAction("<cm_CopyNetFileDetailsToClip>", T("act.TotalCommander.cm_CopyNetFileDetailsToClip"))
    engine.SetAction("<cm_CopyNetNamesToClip>", T("act.TotalCommander.cm_CopyNetNamesToClip"))
    engine.SetAction("<cm_CopyOtherpanel>", T("act.TotalCommander.cm_CopyOtherpanel"))
    engine.SetAction("<cm_CopySamepanel>", T("act.TotalCommander.cm_CopySamepanel"))
    engine.SetAction("<cm_CopySrcPathToClip>", T("act.TotalCommander.cm_CopySrcPathToClip"))
    engine.SetAction("<cm_CopyToClipboard>", T("act.TotalCommander.cm_CopyToClipboard"))
    engine.SetAction("<cm_CopyTrgPathToClip>", T("act.TotalCommander.cm_CopyTrgPathToClip"))
    engine.SetAction("<cm_CountDirContent>", T("act.TotalCommander.cm_CountDirContent"))
    engine.SetAction("<cm_CRCcheck>", T("act.TotalCommander.cm_CRCcheck"))
    engine.SetAction("<cm_CRCcreate>", T("act.TotalCommander.cm_CRCcreate"))
    engine.SetAction("<cm_CreateShortcut>", T("act.TotalCommander.cm_CreateShortcut"))
    engine.SetAction("<cm_CustomColumnConfig>", T("act.TotalCommander.cm_CustomColumnConfig"))
    engine.SetAction("<cm_CustomColumnDlg>", T("act.TotalCommander.cm_CustomColumnDlg"))
    engine.SetAction("<cm_CutToClipboard>", T("act.TotalCommander.cm_CutToClipboard"))
    engine.SetAction("<cm_Decode>", T("act.TotalCommander.cm_Decode"))
    engine.SetAction("<cm_Delete>", T("act.TotalCommander.cm_Delete"))
    engine.SetAction("<cm_DirBranch>", T("act.TotalCommander.cm_DirBranch"))
    engine.SetAction("<cm_DirBranchSel>", T("act.TotalCommander.cm_DirBranchSel"))
    engine.SetAction("<cm_DirectCableConnect>", T("act.TotalCommander.cm_DirectCableConnect"))
    engine.SetAction("<cm_DirectoryHistory>", T("act.TotalCommander.cm_DirectoryHistory"))
    engine.SetAction("<cm_DirectoryHotlist>", T("act.TotalCommander.cm_DirectoryHotlist"))
    engine.SetAction("<cm_DirMatch>", T("act.TotalCommander.cm_DirMatch"))
    engine.SetAction("<cm_DirTabsConfig>", T("act.TotalCommander.cm_DirTabsConfig"))
    engine.SetAction("<cm_DirTabsShowMenu>", T("act.TotalCommander.cm_DirTabsShowMenu"))
    engine.SetAction("<cm_DisplayConfig>", T("act.TotalCommander.cm_DisplayConfig"))
    engine.SetAction("<cm_Edit>", T("act.TotalCommander.cm_Edit"))
    engine.SetAction("<cm_EditAuditInfo>", T("act.TotalCommander.cm_EditAuditInfo"))
    engine.SetAction("<cm_EditComment>", T("act.TotalCommander.cm_EditComment"))
    engine.SetAction("<cm_EditConfig>", T("act.TotalCommander.cm_EditConfig"))
    engine.SetAction("<cm_EditOwnerInfo>", T("act.TotalCommander.cm_EditOwnerInfo"))
    engine.SetAction("<cm_EditPath>", T("act.TotalCommander.cm_EditPath"))
    engine.SetAction("<cm_EditPermissionInfo>", T("act.TotalCommander.cm_EditPermissionInfo"))
    engine.SetAction("<cm_Encode>", T("act.TotalCommander.cm_Encode"))
    engine.SetAction("<cm_Exchange>", T("act.TotalCommander.cm_Exchange"))
    engine.SetAction("<cm_ExchangeSelBoth>", T("act.TotalCommander.cm_ExchangeSelBoth"))
    engine.SetAction("<cm_ExchangeSelection>", T("act.TotalCommander.cm_ExchangeSelection"))
    engine.SetAction("<cm_ExchangeSelFiles>", T("act.TotalCommander.cm_ExchangeSelFiles"))
    engine.SetAction("<cm_ExchangeSelFolders>", T("act.TotalCommander.cm_ExchangeSelFolders"))
    engine.SetAction("<cm_ExchangeWithTabs>", T("act.TotalCommander.cm_ExchangeWithTabs"))
    engine.SetAction("<cm_ExecuteDOS>", T("act.TotalCommander.cm_ExecuteDOS"))
    engine.SetAction("<cm_Exit>", T("act.TotalCommander.cm_Exit"))
    engine.SetAction("<cm_FileSync>", T("act.TotalCommander.cm_FileSync"))
    engine.SetAction("<cm_FocusButtonBar>", T("act.TotalCommander.cm_FocusButtonBar"))
    engine.SetAction("<cm_FocusCmdLine>", T("act.TotalCommander.cm_FocusCmdLine"))
    engine.SetAction("<cm_FocusLeft>", T("act.TotalCommander.cm_FocusLeft"))
    engine.SetAction("<cm_FocusRight>", T("act.TotalCommander.cm_FocusRight"))
    engine.SetAction("<cm_FocusSrc>", T("act.TotalCommander.cm_FocusSrc"))
    engine.SetAction("<cm_FocusTrg>", T("act.TotalCommander.cm_FocusTrg"))
    engine.SetAction("<cm_FontConfig>", T("act.TotalCommander.cm_FontConfig"))
    engine.SetAction("<cm_FtpAbort>", T("act.TotalCommander.cm_FtpAbort"))
    engine.SetAction("<cm_FtpAddToList>", T("act.TotalCommander.cm_FtpAddToList"))
    engine.SetAction("<cm_FtpConfig>", T("act.TotalCommander.cm_FtpConfig"))
    engine.SetAction("<cm_FtpConnect>", T("act.TotalCommander.cm_FtpConnect"))
    engine.SetAction("<cm_FtpDisconnect>", T("act.TotalCommander.cm_FtpDisconnect"))
    engine.SetAction("<cm_FtpDownloadList>", T("act.TotalCommander.cm_FtpDownloadList"))
    engine.SetAction("<cm_FtpHiddenFiles>", T("act.TotalCommander.cm_FtpHiddenFiles"))
    engine.SetAction("<cm_FtpNew>", T("act.TotalCommander.cm_FtpNew"))
    engine.SetAction("<cm_FtpResumeDownload>", T("act.TotalCommander.cm_FtpResumeDownload"))
    engine.SetAction("<cm_FtpSelectTransferMode>", T("act.TotalCommander.cm_FtpSelectTransferMode"))
    engine.SetAction("<cm_GetFileSpace>", T("act.TotalCommander.cm_GetFileSpace"))
    engine.SetAction("<cm_GoToDir>", T("act.TotalCommander.cm_GoToDir"))
    engine.SetAction("<cm_GotoDriveA>", T("act.TotalCommander.cm_GotoDriveA"))
    engine.SetAction("<cm_GotoDriveC>", T("act.TotalCommander.cm_GotoDriveC"))
    engine.SetAction("<cm_GotoDriveD>", T("act.TotalCommander.cm_GotoDriveD"))
    engine.SetAction("<cm_GotoDriveE>", T("act.TotalCommander.cm_GotoDriveE"))
    engine.SetAction("<cm_GotoDriveF>", T("act.TotalCommander.cm_GotoDriveF"))
    engine.SetAction("<cm_GotoDriveZ>", T("act.TotalCommander.cm_GotoDriveZ"))
    engine.SetAction("<cm_GoToFirstEntry>", T("act.TotalCommander.cm_GoToFirstEntry"))
    engine.SetAction("<cm_GoToFirstFile>", T("act.TotalCommander.cm_GoToFirstFile"))
    engine.SetAction("<cm_GoToLockedDir>", T("act.TotalCommander.cm_GoToLockedDir"))
    engine.SetAction("<cm_GotoNextDir>", T("act.TotalCommander.cm_GotoNextDir"))
    engine.SetAction("<cm_GotoNextDrive>", T("act.TotalCommander.cm_GotoNextDrive"))
    engine.SetAction("<cm_GotoNextLocalDir>", T("act.TotalCommander.cm_GotoNextLocalDir"))
    engine.SetAction("<cm_GotoNextSelected>", T("act.TotalCommander.cm_GotoNextSelected"))
    engine.SetAction("<cm_GoToParent>", T("act.TotalCommander.cm_GoToParent"))
    engine.SetAction("<cm_GotoPreviousDir>", T("act.TotalCommander.cm_GotoPreviousDir"))
    engine.SetAction("<cm_GotoPreviousDrive>", T("act.TotalCommander.cm_GotoPreviousDrive"))
    engine.SetAction("<cm_GotoPreviousLocalDir>", T("act.TotalCommander.cm_GotoPreviousLocalDir"))
    engine.SetAction("<cm_GotoPrevSelected>", T("act.TotalCommander.cm_GotoPrevSelected"))
    engine.SetAction("<cm_GoToRoot>", T("act.TotalCommander.cm_GoToRoot"))
    engine.SetAction("<cm_HelpIndex>", T("act.TotalCommander.cm_HelpIndex"))
    engine.SetAction("<cm_IconConfig>", T("act.TotalCommander.cm_IconConfig"))
    engine.SetAction("<cm_IgnoreConfig>", T("act.TotalCommander.cm_IgnoreConfig"))
    engine.SetAction("<cm_IntCompareFilesByContent>", T("act.TotalCommander.cm_IntCompareFilesByContent"))
    engine.SetAction("<cm_InternalAssociate>", T("act.TotalCommander.cm_InternalAssociate"))
    engine.SetAction("<cm_Keyboard>", T("act.TotalCommander.cm_Keyboard"))
    engine.SetAction("<cm_LanguageConfig>", T("act.TotalCommander.cm_LanguageConfig"))
    engine.SetAction("<cm_LeftActivateTab1>", T("act.TotalCommander.cm_LeftActivateTab1"))
    engine.SetAction("<cm_LeftActivateTab10>", T("act.TotalCommander.cm_LeftActivateTab10"))
    engine.SetAction("<cm_LeftActivateTab2>", T("act.TotalCommander.cm_LeftActivateTab2"))
    engine.SetAction("<cm_LeftActivateTab3>", T("act.TotalCommander.cm_LeftActivateTab3"))
    engine.SetAction("<cm_LeftActivateTab4>", T("act.TotalCommander.cm_LeftActivateTab4"))
    engine.SetAction("<cm_LeftActivateTab5>", T("act.TotalCommander.cm_LeftActivateTab5"))
    engine.SetAction("<cm_LeftActivateTab6>", T("act.TotalCommander.cm_LeftActivateTab6"))
    engine.SetAction("<cm_LeftActivateTab7>", T("act.TotalCommander.cm_LeftActivateTab7"))
    engine.SetAction("<cm_LeftActivateTab8>", T("act.TotalCommander.cm_LeftActivateTab8"))
    engine.SetAction("<cm_LeftActivateTab9>", T("act.TotalCommander.cm_LeftActivateTab9"))
    engine.SetAction("<cm_LeftAllFiles>", T("act.TotalCommander.cm_LeftAllFiles"))
    engine.SetAction("<cm_LeftByDateTime>", T("act.TotalCommander.cm_LeftByDateTime"))
    engine.SetAction("<cm_LeftByExt>", T("act.TotalCommander.cm_LeftByExt"))
    engine.SetAction("<cm_LeftByName>", T("act.TotalCommander.cm_LeftByName"))
    engine.SetAction("<cm_LeftBySize>", T("act.TotalCommander.cm_LeftBySize"))
    engine.SetAction("<cm_LeftComments>", T("act.TotalCommander.cm_LeftComments"))
    engine.SetAction("<cm_LeftCustomView1>", T("act.TotalCommander.cm_LeftCustomView1"))
    engine.SetAction("<cm_LeftCustomView10>", T("act.TotalCommander.cm_LeftCustomView10"))
    engine.SetAction("<cm_LeftCustomView2>", T("act.TotalCommander.cm_LeftCustomView2"))
    engine.SetAction("<cm_LeftCustomView3>", T("act.TotalCommander.cm_LeftCustomView3"))
    engine.SetAction("<cm_LeftCustomView4>", T("act.TotalCommander.cm_LeftCustomView4"))
    engine.SetAction("<cm_LeftCustomView5>", T("act.TotalCommander.cm_LeftCustomView5"))
    engine.SetAction("<cm_LeftCustomView6>", T("act.TotalCommander.cm_LeftCustomView6"))
    engine.SetAction("<cm_LeftCustomView7>", T("act.TotalCommander.cm_LeftCustomView7"))
    engine.SetAction("<cm_LeftCustomView8>", T("act.TotalCommander.cm_LeftCustomView8"))
    engine.SetAction("<cm_LeftCustomView9>", T("act.TotalCommander.cm_LeftCustomView9"))
    engine.SetAction("<cm_LeftCustomViewMenu>", T("act.TotalCommander.cm_LeftCustomViewMenu"))
    engine.SetAction("<cm_LeftDirBranch>", T("act.TotalCommander.cm_LeftDirBranch"))
    engine.SetAction("<cm_LeftDirBranchSel>", T("act.TotalCommander.cm_LeftDirBranchSel"))
    engine.SetAction("<cm_LeftExecs>", T("act.TotalCommander.cm_LeftExecs"))
    engine.SetAction("<cm_LeftHideQuickview>", T("act.TotalCommander.cm_LeftHideQuickview"))
    engine.SetAction("<cm_LeftLong>", T("act.TotalCommander.cm_LeftLong"))
    engine.SetAction("<cm_LeftNegOrder>", T("act.TotalCommander.cm_LeftNegOrder"))
    engine.SetAction("<cm_LeftNextCustomView>", T("act.TotalCommander.cm_LeftNextCustomView"))
    engine.SetAction("<cm_LeftOpenDrives>", T("act.TotalCommander.cm_LeftOpenDrives"))
    engine.SetAction("<cm_LeftPathFocus>", T("act.TotalCommander.cm_LeftPathFocus"))
    engine.SetAction("<cm_LeftPrevCustomView>", T("act.TotalCommander.cm_LeftPrevCustomView"))
    engine.SetAction("<cm_LeftQuickInternalOnly>", T("act.TotalCommander.cm_LeftQuickInternalOnly"))
    engine.SetAction("<cm_LeftQuickview>", T("act.TotalCommander.cm_LeftQuickview"))
    engine.SetAction("<cm_LeftShort>", T("act.TotalCommander.cm_LeftShort"))
    engine.SetAction("<cm_LeftSortByCol1>", T("act.TotalCommander.cm_LeftSortByCol1"))
    engine.SetAction("<cm_LeftSortByCol10>", T("act.TotalCommander.cm_LeftSortByCol10"))
    engine.SetAction("<cm_LeftSortByCol2>", T("act.TotalCommander.cm_LeftSortByCol2"))
    engine.SetAction("<cm_LeftSortByCol3>", T("act.TotalCommander.cm_LeftSortByCol3"))
    engine.SetAction("<cm_LeftSortByCol4>", T("act.TotalCommander.cm_LeftSortByCol4"))
    engine.SetAction("<cm_LeftSortByCol5>", T("act.TotalCommander.cm_LeftSortByCol5"))
    engine.SetAction("<cm_LeftSortByCol6>", T("act.TotalCommander.cm_LeftSortByCol6"))
    engine.SetAction("<cm_LeftSortByCol7>", T("act.TotalCommander.cm_LeftSortByCol7"))
    engine.SetAction("<cm_LeftSortByCol8>", T("act.TotalCommander.cm_LeftSortByCol8"))
    engine.SetAction("<cm_LeftSortByCol9>", T("act.TotalCommander.cm_LeftSortByCol9"))
    engine.SetAction("<cm_LeftThumbs>", T("act.TotalCommander.cm_LeftThumbs"))
    engine.SetAction("<cm_LeftTree>", T("act.TotalCommander.cm_LeftTree"))
    engine.SetAction("<cm_LeftUnsorted>", T("act.TotalCommander.cm_LeftUnsorted"))
    engine.SetAction("<cm_LeftUserDef>", T("act.TotalCommander.cm_LeftUserDef"))
    engine.SetAction("<cm_LeftUserSpec>", T("act.TotalCommander.cm_LeftUserSpec"))
    engine.SetAction("<cm_List>", T("act.TotalCommander.cm_List"))
    engine.SetAction("<cm_ListInternalOnly>", T("act.TotalCommander.cm_ListInternalOnly"))
    engine.SetAction("<cm_LoadAllOnDemandFields>", T("act.TotalCommander.cm_LoadAllOnDemandFields"))
    engine.SetAction("<cm_LoadSelectionFromClip>", T("act.TotalCommander.cm_LoadSelectionFromClip"))
    engine.SetAction("<cm_LoadSelectionFromFile>", T("act.TotalCommander.cm_LoadSelectionFromFile"))
    engine.SetAction("<cm_LoadSelOnDemandFields>", T("act.TotalCommander.cm_LoadSelOnDemandFields"))
    engine.SetAction("<cm_LogConfig>", T("act.TotalCommander.cm_LogConfig"))
    engine.SetAction("<cm_MatchSrc>", T("act.TotalCommander.cm_MatchSrc"))
    engine.SetAction("<cm_Maximize>", T("act.TotalCommander.cm_Maximize"))
    engine.SetAction("<cm_Minimize>", T("act.TotalCommander.cm_Minimize"))
    engine.SetAction("<cm_MkDir>", T("act.TotalCommander.cm_MkDir"))
    engine.SetAction("<cm_MoveOnly>", T("act.TotalCommander.cm_MoveOnly"))
    engine.SetAction("<cm_MultiRenameFiles>", T("act.TotalCommander.cm_MultiRenameFiles"))
    engine.SetAction("<cm_NetConnect>", T("act.TotalCommander.cm_NetConnect"))
    engine.SetAction("<cm_NetDisconnect>", T("act.TotalCommander.cm_NetDisconnect"))
    engine.SetAction("<cm_NetShareDir>", T("act.TotalCommander.cm_NetShareDir"))
    engine.SetAction("<cm_NetUnshareDir>", T("act.TotalCommander.cm_NetUnshareDir"))
    engine.SetAction("<cm_NextCommand>", T("act.TotalCommander.cm_NextCommand"))
    engine.SetAction("<cm_NTinstallDriver>", T("act.TotalCommander.cm_NTinstallDriver"))
    engine.SetAction("<cm_NTremoveDriver>", T("act.TotalCommander.cm_NTremoveDriver"))
    engine.SetAction("<cm_OpenAsUser>", T("act.TotalCommander.cm_OpenAsUser"))
    engine.SetAction("<cm_OpenControls>", T("act.TotalCommander.cm_OpenControls"))
    engine.SetAction("<cm_OpenDesktop>", T("act.TotalCommander.cm_OpenDesktop"))
    engine.SetAction("<cm_OpenDirInNewTab>", T("act.TotalCommander.cm_OpenDirInNewTab"))
    engine.SetAction("<cm_OpenDirInNewTabOther>", T("act.TotalCommander.cm_OpenDirInNewTabOther"))
    engine.SetAction("<cm_OpenDrives>", T("act.TotalCommander.cm_OpenDrives"))
    engine.SetAction("<cm_OpenFonts>", T("act.TotalCommander.cm_OpenFonts"))
    engine.SetAction("<cm_OpenNetwork>", T("act.TotalCommander.cm_OpenNetwork"))
    engine.SetAction("<cm_OpenNewTab>", T("act.TotalCommander.cm_OpenNewTab"))
    engine.SetAction("<cm_OpenNewTabBg>", T("act.TotalCommander.cm_OpenNewTabBg"))
    engine.SetAction("<cm_OpenPrinters>", T("act.TotalCommander.cm_OpenPrinters"))
    engine.SetAction("<cm_OpenRecycled>", T("act.TotalCommander.cm_OpenRecycled"))
    engine.SetAction("<cm_OpenTransferManager>", T("act.TotalCommander.cm_OpenTransferManager"))
    engine.SetAction("<cm_PackerConfig>", T("act.TotalCommander.cm_PackerConfig"))
    engine.SetAction("<cm_PackFiles>", T("act.TotalCommander.cm_PackFiles"))
    engine.SetAction("<cm_PasteFromClipboard>", T("act.TotalCommander.cm_PasteFromClipboard"))
    engine.SetAction("<cm_PluginsConfig>", T("act.TotalCommander.cm_PluginsConfig"))
    engine.SetAction("<cm_PrevCommand>", T("act.TotalCommander.cm_PrevCommand"))
    engine.SetAction("<cm_PrintDir>", T("act.TotalCommander.cm_PrintDir"))
    engine.SetAction("<cm_PrintDirSub>", T("act.TotalCommander.cm_PrintDirSub"))
    engine.SetAction("<cm_PrintFile>", T("act.TotalCommander.cm_PrintFile"))
    engine.SetAction("<cm_Properties>", T("act.TotalCommander.cm_Properties"))
    engine.SetAction("<cm_QuickSearchConfig>", T("act.TotalCommander.cm_QuickSearchConfig"))
    engine.SetAction("<cm_RefreshConfig>", T("act.TotalCommander.cm_RefreshConfig"))
    engine.SetAction("<cm_Register>", T("act.TotalCommander.cm_Register"))
    engine.SetAction("<cm_ReloadSelThumbs>", T("act.TotalCommander.cm_ReloadSelThumbs"))
    engine.SetAction("<cm_RenameOnly>", T("act.TotalCommander.cm_RenameOnly"))
    engine.SetAction("<cm_RenameSingleFile>", T("act.TotalCommander.cm_RenameSingleFile"))
    engine.SetAction("<cm_RenMov>", T("act.TotalCommander.cm_RenMov"))
    engine.SetAction("<cm_RereadSource>", T("act.TotalCommander.cm_RereadSource"))
    engine.SetAction("<cm_Restore>", T("act.TotalCommander.cm_Restore"))
    engine.SetAction("<cm_RestoreSelection>", T("act.TotalCommander.cm_RestoreSelection"))
    engine.SetAction("<cm_Return>", T("act.TotalCommander.cm_Return"))
    engine.SetAction("<cm_RightActivateTab1>", T("act.TotalCommander.cm_RightActivateTab1"))
    engine.SetAction("<cm_RightActivateTab10>", T("act.TotalCommander.cm_RightActivateTab10"))
    engine.SetAction("<cm_RightActivateTab2>", T("act.TotalCommander.cm_RightActivateTab2"))
    engine.SetAction("<cm_RightActivateTab3>", T("act.TotalCommander.cm_RightActivateTab3"))
    engine.SetAction("<cm_RightActivateTab4>", T("act.TotalCommander.cm_RightActivateTab4"))
    engine.SetAction("<cm_RightActivateTab5>", T("act.TotalCommander.cm_RightActivateTab5"))
    engine.SetAction("<cm_RightActivateTab6>", T("act.TotalCommander.cm_RightActivateTab6"))
    engine.SetAction("<cm_RightActivateTab7>", T("act.TotalCommander.cm_RightActivateTab7"))
    engine.SetAction("<cm_RightActivateTab8>", T("act.TotalCommander.cm_RightActivateTab8"))
    engine.SetAction("<cm_RightActivateTab9>", T("act.TotalCommander.cm_RightActivateTab9"))
    engine.SetAction("<cm_RightAllFile>", T("act.TotalCommander.cm_RightAllFile"))
    engine.SetAction("<cm_RightByDateTim>", T("act.TotalCommander.cm_RightByDateTim"))
    engine.SetAction("<cm_RightByEx>", T("act.TotalCommander.cm_RightByEx"))
    engine.SetAction("<cm_RightByNam>", T("act.TotalCommander.cm_RightByNam"))
    engine.SetAction("<cm_RightBySiz>", T("act.TotalCommander.cm_RightBySiz"))
    engine.SetAction("<cm_RightComments>", T("act.TotalCommander.cm_RightComments"))
    engine.SetAction("<cm_RightCustomView1>", T("act.TotalCommander.cm_RightCustomView1"))
    engine.SetAction("<cm_RightCustomView10>", T("act.TotalCommander.cm_RightCustomView10"))
    engine.SetAction("<cm_RightCustomView2>", T("act.TotalCommander.cm_RightCustomView2"))
    engine.SetAction("<cm_RightCustomView3>", T("act.TotalCommander.cm_RightCustomView3"))
    engine.SetAction("<cm_RightCustomView4>", T("act.TotalCommander.cm_RightCustomView4"))
    engine.SetAction("<cm_RightCustomView5>", T("act.TotalCommander.cm_RightCustomView5"))
    engine.SetAction("<cm_RightCustomView6>", T("act.TotalCommander.cm_RightCustomView6"))
    engine.SetAction("<cm_RightCustomView7>", T("act.TotalCommander.cm_RightCustomView7"))
    engine.SetAction("<cm_RightCustomView8>", T("act.TotalCommander.cm_RightCustomView8"))
    engine.SetAction("<cm_RightCustomView9>", T("act.TotalCommander.cm_RightCustomView9"))
    engine.SetAction("<cm_RightCustomViewMen>", T("act.TotalCommander.cm_RightCustomViewMen"))
    engine.SetAction("<cm_RightDirBranch>", T("act.TotalCommander.cm_RightDirBranch"))
    engine.SetAction("<cm_RightDirBranchSel>", T("act.TotalCommander.cm_RightDirBranchSel"))
    engine.SetAction("<cm_RightExec>", T("act.TotalCommander.cm_RightExec"))
    engine.SetAction("<cm_RightHideQuickvie>", T("act.TotalCommander.cm_RightHideQuickvie"))
    engine.SetAction("<cm_RightLong>", T("act.TotalCommander.cm_RightLong"))
    engine.SetAction("<cm_RightNegOrde>", T("act.TotalCommander.cm_RightNegOrde"))
    engine.SetAction("<cm_RightNextCustomView>", T("act.TotalCommander.cm_RightNextCustomView"))
    engine.SetAction("<cm_RightOpenDrives>", T("act.TotalCommander.cm_RightOpenDrives"))
    engine.SetAction("<cm_RightPathFocu>", T("act.TotalCommander.cm_RightPathFocu"))
    engine.SetAction("<cm_RightPrevCustomView>", T("act.TotalCommander.cm_RightPrevCustomView"))
    engine.SetAction("<cm_RightQuickInternalOnl>", T("act.TotalCommander.cm_RightQuickInternalOnl"))
    engine.SetAction("<cm_RightQuickvie>", T("act.TotalCommander.cm_RightQuickvie"))
    engine.SetAction("<cm_RightShort>", T("act.TotalCommander.cm_RightShort"))
    engine.SetAction("<cm_RightSortByCol1>", T("act.TotalCommander.cm_RightSortByCol1"))
    engine.SetAction("<cm_RightSortByCol10>", T("act.TotalCommander.cm_RightSortByCol10"))
    engine.SetAction("<cm_RightSortByCol2>", T("act.TotalCommander.cm_RightSortByCol2"))
    engine.SetAction("<cm_RightSortByCol3>", T("act.TotalCommander.cm_RightSortByCol3"))
    engine.SetAction("<cm_RightSortByCol4>", T("act.TotalCommander.cm_RightSortByCol4"))
    engine.SetAction("<cm_RightSortByCol5>", T("act.TotalCommander.cm_RightSortByCol5"))
    engine.SetAction("<cm_RightSortByCol6>", T("act.TotalCommander.cm_RightSortByCol6"))
    engine.SetAction("<cm_RightSortByCol7>", T("act.TotalCommander.cm_RightSortByCol7"))
    engine.SetAction("<cm_RightSortByCol8>", T("act.TotalCommander.cm_RightSortByCol8"))
    engine.SetAction("<cm_RightSortByCol9>", T("act.TotalCommander.cm_RightSortByCol9"))
    engine.SetAction("<cm_RightThumb>", T("act.TotalCommander.cm_RightThumb"))
    engine.SetAction("<cm_RightTree>", T("act.TotalCommander.cm_RightTree"))
    engine.SetAction("<cm_RightUnsorte>", T("act.TotalCommander.cm_RightUnsorte"))
    engine.SetAction("<cm_RightUserDe>", T("act.TotalCommander.cm_RightUserDe"))
    engine.SetAction("<cm_RightUserSpe>", T("act.TotalCommander.cm_RightUserSpe"))
    engine.SetAction("<cm_SaveDetailsToFile>", T("act.TotalCommander.cm_SaveDetailsToFile"))
    engine.SetAction("<cm_SaveDetailsToFileA>", T("act.TotalCommander.cm_SaveDetailsToFileA"))
    engine.SetAction("<cm_SaveDetailsToFileW>", T("act.TotalCommander.cm_SaveDetailsToFileW"))
    engine.SetAction("<cm_SaveSelection>", T("act.TotalCommander.cm_SaveSelection"))
    engine.SetAction("<cm_SaveSelectionToFile>", T("act.TotalCommander.cm_SaveSelectionToFile"))
    engine.SetAction("<cm_SaveSelectionToFileA>", T("act.TotalCommander.cm_SaveSelectionToFileA"))
    engine.SetAction("<cm_SaveSelectionToFileW>", T("act.TotalCommander.cm_SaveSelectionToFileW"))
    engine.SetAction("<cm_SearchFor>", T("act.TotalCommander.cm_SearchFor"))
    engine.SetAction("<cm_SearchStandalone>", T("act.TotalCommander.cm_SearchStandalone"))
    engine.SetAction("<cm_SelectAll>", T("act.TotalCommander.cm_SelectAll"))
    engine.SetAction("<cm_SelectAllBoth>", T("act.TotalCommander.cm_SelectAllBoth"))
    engine.SetAction("<cm_SelectAllFiles>", T("act.TotalCommander.cm_SelectAllFiles"))
    engine.SetAction("<cm_SelectAllFolders>", T("act.TotalCommander.cm_SelectAllFolders"))
    engine.SetAction("<cm_SelectBoth>", T("act.TotalCommander.cm_SelectBoth"))
    engine.SetAction("<cm_SelectCurrentExtension>", T("act.TotalCommander.cm_SelectCurrentExtension"))
    engine.SetAction("<cm_SelectCurrentName>", T("act.TotalCommander.cm_SelectCurrentName"))
    engine.SetAction("<cm_SelectCurrentNameExt>", T("act.TotalCommander.cm_SelectCurrentNameExt"))
    engine.SetAction("<cm_SelectCurrentPath>", T("act.TotalCommander.cm_SelectCurrentPath"))
    engine.SetAction("<cm_SelectFiles>", T("act.TotalCommander.cm_SelectFiles"))
    engine.SetAction("<cm_SelectFolders>", T("act.TotalCommander.cm_SelectFolders"))
    engine.SetAction("<cm_SeparateTree1>", T("act.TotalCommander.cm_SeparateTree1"))
    engine.SetAction("<cm_SeparateTree2>", T("act.TotalCommander.cm_SeparateTree2"))
    engine.SetAction("<cm_SeparateTreeOff>", T("act.TotalCommander.cm_SeparateTreeOff"))
    engine.SetAction("<cm_SetAttrib>", T("act.TotalCommander.cm_SetAttrib"))
    engine.SetAction("<cm_ShowFileUser>", T("act.TotalCommander.cm_ShowFileUser"))
    engine.SetAction("<cm_ShowHint>", T("act.TotalCommander.cm_ShowHint"))
    engine.SetAction("<cm_ShowOnlySelected>", T("act.TotalCommander.cm_ShowOnlySelected"))
    engine.SetAction("<cm_ShowQuickSearch>", T("act.TotalCommander.cm_ShowQuickSearch"))
    engine.SetAction("<cm_ShowRemoteMenu>", T("act.TotalCommander.cm_ShowRemoteMenu"))
    engine.SetAction("<cm_ShrinkSelection>", T("act.TotalCommander.cm_ShrinkSelection"))
    engine.SetAction("<cm_Split>", T("act.TotalCommander.cm_Split"))
    engine.SetAction("<cm_SpreadSelection>", T("act.TotalCommander.cm_SpreadSelection"))
    engine.SetAction("<cm_SrcActivateTab1>", T("act.TotalCommander.cm_SrcActivateTab1"))
    engine.SetAction("<cm_SrcActivateTab10>", T("act.TotalCommander.cm_SrcActivateTab10"))
    engine.SetAction("<cm_SrcActivateTab2>", T("act.TotalCommander.cm_SrcActivateTab2"))
    engine.SetAction("<cm_SrcActivateTab3>", T("act.TotalCommander.cm_SrcActivateTab3"))
    engine.SetAction("<cm_SrcActivateTab4>", T("act.TotalCommander.cm_SrcActivateTab4"))
    engine.SetAction("<cm_SrcActivateTab5>", T("act.TotalCommander.cm_SrcActivateTab5"))
    engine.SetAction("<cm_SrcActivateTab6>", T("act.TotalCommander.cm_SrcActivateTab6"))
    engine.SetAction("<cm_SrcActivateTab7>", T("act.TotalCommander.cm_SrcActivateTab7"))
    engine.SetAction("<cm_SrcActivateTab8>", T("act.TotalCommander.cm_SrcActivateTab8"))
    engine.SetAction("<cm_SrcActivateTab9>", T("act.TotalCommander.cm_SrcActivateTab9"))
    engine.SetAction("<cm_SrcAllFiles>", T("act.TotalCommander.cm_SrcAllFiles"))
    engine.SetAction("<cm_SrcByDateTime>", T("act.TotalCommander.cm_SrcByDateTime"))
    engine.SetAction("<cm_SrcByExt>", T("act.TotalCommander.cm_SrcByExt"))
    engine.SetAction("<cm_SrcByName>", T("act.TotalCommander.cm_SrcByName"))
    engine.SetAction("<cm_SrcBySize>", T("act.TotalCommander.cm_SrcBySize"))
    engine.SetAction("<cm_SrcComments>", T("act.TotalCommander.cm_SrcComments"))
    engine.SetAction("<cm_SrcCustomView1>", T("act.TotalCommander.cm_SrcCustomView1"))
    engine.SetAction("<cm_SrcCustomView10>", T("act.TotalCommander.cm_SrcCustomView10"))
    engine.SetAction("<cm_SrcCustomView2>", T("act.TotalCommander.cm_SrcCustomView2"))
    engine.SetAction("<cm_SrcCustomView3>", T("act.TotalCommander.cm_SrcCustomView3"))
    engine.SetAction("<cm_SrcCustomView4>", T("act.TotalCommander.cm_SrcCustomView4"))
    engine.SetAction("<cm_SrcCustomView5>", T("act.TotalCommander.cm_SrcCustomView5"))
    engine.SetAction("<cm_SrcCustomView6>", T("act.TotalCommander.cm_SrcCustomView6"))
    engine.SetAction("<cm_SrcCustomView7>", T("act.TotalCommander.cm_SrcCustomView7"))
    engine.SetAction("<cm_SrcCustomView8>", T("act.TotalCommander.cm_SrcCustomView8"))
    engine.SetAction("<cm_SrcCustomView9>", T("act.TotalCommander.cm_SrcCustomView9"))
    engine.SetAction("<cm_SrcCustomViewMenu>", T("act.TotalCommander.cm_SrcCustomViewMenu"))
    engine.SetAction("<cm_SrcExecs>", T("act.TotalCommander.cm_SrcExecs"))
    engine.SetAction("<cm_SrcHideQuickview>", T("act.TotalCommander.cm_SrcHideQuickview"))
    engine.SetAction("<cm_SrcLong>", T("act.TotalCommander.cm_SrcLong"))
    engine.SetAction("<cm_SrcNegOrder>", T("act.TotalCommander.cm_SrcNegOrder"))
    engine.SetAction("<cm_SrcNextCustomView>", T("act.TotalCommander.cm_SrcNextCustomView"))
    engine.SetAction("<cm_SrcOpenDrives>", T("act.TotalCommander.cm_SrcOpenDrives"))
    engine.SetAction("<cm_SrcPathFocus>", T("act.TotalCommander.cm_SrcPathFocus"))
    engine.SetAction("<cm_SrcPrevCustomView>", T("act.TotalCommander.cm_SrcPrevCustomView"))
    engine.SetAction("<cm_SrcQuickInternalOnly>", T("act.TotalCommander.cm_SrcQuickInternalOnly"))
    engine.SetAction("<cm_SrcQuickview>", T("act.TotalCommander.cm_SrcQuickview"))
    engine.SetAction("<cm_SrcShort>", T("act.TotalCommander.cm_SrcShort"))
    engine.SetAction("<cm_SrcSortByCol1>", T("act.TotalCommander.cm_SrcSortByCol1"))
    engine.SetAction("<cm_SrcSortByCol10>", T("act.TotalCommander.cm_SrcSortByCol10"))
    engine.SetAction("<cm_SrcSortByCol2>", T("act.TotalCommander.cm_SrcSortByCol2"))
    engine.SetAction("<cm_SrcSortByCol3>", T("act.TotalCommander.cm_SrcSortByCol3"))
    engine.SetAction("<cm_SrcSortByCol4>", T("act.TotalCommander.cm_SrcSortByCol4"))
    engine.SetAction("<cm_SrcSortByCol5>", T("act.TotalCommander.cm_SrcSortByCol5"))
    engine.SetAction("<cm_SrcSortByCol6>", T("act.TotalCommander.cm_SrcSortByCol6"))
    engine.SetAction("<cm_SrcSortByCol7>", T("act.TotalCommander.cm_SrcSortByCol7"))
    engine.SetAction("<cm_SrcSortByCol8>", T("act.TotalCommander.cm_SrcSortByCol8"))
    engine.SetAction("<cm_SrcSortByCol9>", T("act.TotalCommander.cm_SrcSortByCol9"))
    engine.SetAction("<cm_SrcThumbs>", T("act.TotalCommander.cm_SrcThumbs"))
    engine.SetAction("<cm_SrcTree>", T("act.TotalCommander.cm_SrcTree"))
    engine.SetAction("<cm_SrcUnsorted>", T("act.TotalCommander.cm_SrcUnsorted"))
    engine.SetAction("<cm_SrcUserDef>", T("act.TotalCommander.cm_SrcUserDef"))
    engine.SetAction("<cm_SrcUserSpec>", T("act.TotalCommander.cm_SrcUserSpec"))
    engine.SetAction("<cm_Switch83Names>", T("act.TotalCommander.cm_Switch83Names"))
    engine.SetAction("<cm_SwitchDirSort>", T("act.TotalCommander.cm_SwitchDirSort"))
    engine.SetAction("<cm_SwitchHidSys>", T("act.TotalCommander.cm_SwitchHidSys"))
    engine.SetAction("<cm_SwitchIgnoreList>", T("act.TotalCommander.cm_SwitchIgnoreList"))
    engine.SetAction("<cm_SwitchLongNames>", T("act.TotalCommander.cm_SwitchLongNames"))
    engine.SetAction("<cm_SwitchOverlayIcons>", T("act.TotalCommander.cm_SwitchOverlayIcons"))
    engine.SetAction("<cm_SwitchSeparateTree>", T("act.TotalCommander.cm_SwitchSeparateTree"))
    engine.SetAction("<cm_SwitchToNextTab>", T("act.TotalCommander.cm_SwitchToNextTab"))
    engine.SetAction("<cm_SwitchToPreviousTab>", T("act.TotalCommander.cm_SwitchToPreviousTab"))
    engine.SetAction("<cm_SwitchWatchDirs>", T("act.TotalCommander.cm_SwitchWatchDirs"))
    engine.SetAction("<cm_SwitchX64Redirection>", T("act.TotalCommander.cm_SwitchX64Redirection"))
    engine.SetAction("<cm_SyncChangeDir>", T("act.TotalCommander.cm_SyncChangeDir"))
    engine.SetAction("<cm_SysInfo>", T("act.TotalCommander.cm_SysInfo"))
    engine.SetAction("<cm_TestArchive>", T("act.TotalCommander.cm_TestArchive"))
    engine.SetAction("<cm_ThumbnailsConfig>", T("act.TotalCommander.cm_ThumbnailsConfig"))
    engine.SetAction("<cm_ToggleLockCurrentTab>", T("act.TotalCommander.cm_ToggleLockCurrentTab"))
    engine.SetAction("<cm_ToggleLockDcaCurrentTab>", T("act.TotalCommander.cm_ToggleLockDcaCurrentTab"))
    engine.SetAction("<cm_ToggleSeparateTree1>", T("act.TotalCommander.cm_ToggleSeparateTree1"))
    engine.SetAction("<cm_ToggleSeparateTree2>", T("act.TotalCommander.cm_ToggleSeparateTree2"))
    engine.SetAction("<cm_TransferLeft>", T("act.TotalCommander.cm_TransferLeft"))
    engine.SetAction("<cm_TransferRight>", T("act.TotalCommander.cm_TransferRight"))
    engine.SetAction("<cm_TrgActivateTab1>", T("act.TotalCommander.cm_TrgActivateTab1"))
    engine.SetAction("<cm_TrgActivateTab10>", T("act.TotalCommander.cm_TrgActivateTab10"))
    engine.SetAction("<cm_TrgActivateTab2>", T("act.TotalCommander.cm_TrgActivateTab2"))
    engine.SetAction("<cm_TrgActivateTab3>", T("act.TotalCommander.cm_TrgActivateTab3"))
    engine.SetAction("<cm_TrgActivateTab4>", T("act.TotalCommander.cm_TrgActivateTab4"))
    engine.SetAction("<cm_TrgActivateTab5>", T("act.TotalCommander.cm_TrgActivateTab5"))
    engine.SetAction("<cm_TrgActivateTab6>", T("act.TotalCommander.cm_TrgActivateTab6"))
    engine.SetAction("<cm_TrgActivateTab7>", T("act.TotalCommander.cm_TrgActivateTab7"))
    engine.SetAction("<cm_TrgActivateTab8>", T("act.TotalCommander.cm_TrgActivateTab8"))
    engine.SetAction("<cm_TrgActivateTab9>", T("act.TotalCommander.cm_TrgActivateTab9"))
    engine.SetAction("<cm_TrgNextCustomView>", T("act.TotalCommander.cm_TrgNextCustomView"))
    engine.SetAction("<cm_TrgPrevCustomView>", T("act.TotalCommander.cm_TrgPrevCustomView"))
    engine.SetAction("<cm_TrgSortByCol1>", T("act.TotalCommander.cm_TrgSortByCol1"))
    engine.SetAction("<cm_TrgSortByCol10>", T("act.TotalCommander.cm_TrgSortByCol10"))
    engine.SetAction("<cm_TrgSortByCol2>", T("act.TotalCommander.cm_TrgSortByCol2"))
    engine.SetAction("<cm_TrgSortByCol3>", T("act.TotalCommander.cm_TrgSortByCol3"))
    engine.SetAction("<cm_TrgSortByCol4>", T("act.TotalCommander.cm_TrgSortByCol4"))
    engine.SetAction("<cm_TrgSortByCol5>", T("act.TotalCommander.cm_TrgSortByCol5"))
    engine.SetAction("<cm_TrgSortByCol6>", T("act.TotalCommander.cm_TrgSortByCol6"))
    engine.SetAction("<cm_TrgSortByCol7>", T("act.TotalCommander.cm_TrgSortByCol7"))
    engine.SetAction("<cm_TrgSortByCol8>", T("act.TotalCommander.cm_TrgSortByCol8"))
    engine.SetAction("<cm_TrgSortByCol9>", T("act.TotalCommander.cm_TrgSortByCol9"))
    engine.SetAction("<cm_UnloadPlugins>", T("act.TotalCommander.cm_UnloadPlugins"))
    engine.SetAction("<cm_UnpackFiles>", T("act.TotalCommander.cm_UnpackFiles"))
    engine.SetAction("<cm_UnselectCurrentExtension>", T("act.TotalCommander.cm_UnselectCurrentExtension"))
    engine.SetAction("<cm_UnselectCurrentName>", T("act.TotalCommander.cm_UnselectCurrentName"))
    engine.SetAction("<cm_UnselectCurrentNameExt>", T("act.TotalCommander.cm_UnselectCurrentNameExt"))
    engine.SetAction("<cm_UnselectCurrentPath>", T("act.TotalCommander.cm_UnselectCurrentPath"))
    engine.SetAction("<cm_UserMenu1>", T("act.TotalCommander.cm_UserMenu1"))
    engine.SetAction("<cm_UserMenu10>", T("act.TotalCommander.cm_UserMenu10"))
    engine.SetAction("<cm_UserMenu2>", T("act.TotalCommander.cm_UserMenu2"))
    engine.SetAction("<cm_UserMenu3>", T("act.TotalCommander.cm_UserMenu3"))
    engine.SetAction("<cm_UserMenu4>", T("act.TotalCommander.cm_UserMenu4"))
    engine.SetAction("<cm_UserMenu5>", T("act.TotalCommander.cm_UserMenu5"))
    engine.SetAction("<cm_UserMenu6>", T("act.TotalCommander.cm_UserMenu6"))
    engine.SetAction("<cm_UserMenu7>", T("act.TotalCommander.cm_UserMenu7"))
    engine.SetAction("<cm_UserMenu8>", T("act.TotalCommander.cm_UserMenu8"))
    engine.SetAction("<cm_UserMenu9>", T("act.TotalCommander.cm_UserMenu9"))
    engine.SetAction("<cm_VersionInfo>", T("act.TotalCommander.cm_VersionInfo"))
    engine.SetAction("<cm_VerticalPanels>", T("act.TotalCommander.cm_VerticalPanels"))
    engine.SetAction("<cm_VisBreadCrumbs>", T("act.TotalCommander.cm_VisBreadCrumbs"))
    engine.SetAction("<cm_VisButtonbar>", T("act.TotalCommander.cm_VisButtonbar"))
    engine.SetAction("<cm_VisCmdLine>", T("act.TotalCommander.cm_VisCmdLine"))
    engine.SetAction("<cm_VisCurDir>", T("act.TotalCommander.cm_VisCurDir"))
    engine.SetAction("<cm_VisDirTabs>", T("act.TotalCommander.cm_VisDirTabs"))
    engine.SetAction("<cm_VisDriveButtons>", T("act.TotalCommander.cm_VisDriveButtons"))
    engine.SetAction("<cm_VisDriveCombo>", T("act.TotalCommander.cm_VisDriveCombo"))
    engine.SetAction("<cm_VisFlatDriveButtons>", T("act.TotalCommander.cm_VisFlatDriveButtons"))
    engine.SetAction("<cm_VisFlatInterface>", T("act.TotalCommander.cm_VisFlatInterface"))
    engine.SetAction("<cm_VisHistHotButtons>", T("act.TotalCommander.cm_VisHistHotButtons"))
    engine.SetAction("<cm_VisitHomepage>", T("act.TotalCommander.cm_VisitHomepage"))
    engine.SetAction("<cm_VisKeyButtons>", T("act.TotalCommander.cm_VisKeyButtons"))
    engine.SetAction("<cm_VisStatusbar>", T("act.TotalCommander.cm_VisStatusbar"))
    engine.SetAction("<cm_VisTabHeader>", T("act.TotalCommander.cm_VisTabHeader"))
    engine.SetAction("<cm_VisTwoDriveButtons>", T("act.TotalCommander.cm_VisTwoDriveButtons"))
    engine.SetAction("<cm_VisXPThemeBackground>", T("act.TotalCommander.cm_VisXPThemeBackground"))
    engine.SetAction("<cm_VolumeId>", T("act.TotalCommander.cm_VolumeId"))
    engine.SetAction("<cm_ZipPackerConfig>", T("act.TotalCommander.cm_ZipPackerConfig"))
    engine.SetAction("<TC_AlwayOnTop>", T("act.TotalCommander.TC_AlwayOnTop"))
    engine.SetAction("<TC_azHistory>", T("act.TotalCommander.TC_azHistory"))
    engine.SetAction("<TC_ClearTitle>", T("act.TotalCommander.TC_ClearTitle"))
    engine.SetAction("<TC_CopyDirectoryHotlist>", T("act.TotalCommander.TC_CopyDirectoryHotlist"))
    engine.SetAction("<TC_CopyFileContents>", T("act.TotalCommander.TC_CopyFileContents"))
    engine.SetAction("<TC_CopyNameOnly>", T("act.TotalCommander.TC_CopyNameOnly"))
    engine.SetAction("<TC_CopyUseQueues>", T("act.TotalCommander.TC_CopyUseQueues"))
    engine.SetAction("<TC_CreateBlankFile>", T("act.TotalCommander.TC_CreateBlankFile"))
    engine.SetAction("<TC_CreateBlankFileNoExt>", T("act.TotalCommander.TC_CreateBlankFileNoExt"))
    engine.SetAction("<TC_CreateFileShortcut>", T("act.TotalCommander.TC_CreateFileShortcut"))
    engine.SetAction("<TC_CreateFileShortcutToDesktop>", T("act.TotalCommander.TC_CreateFileShortcutToDesktop"))
    engine.SetAction("<TC_CreateFileShortcutToStartup>", T("act.TotalCommander.TC_CreateFileShortcutToStartup"))
    engine.SetAction("<TC_CreateNewFile>", T("act.TotalCommander.TC_CreateNewFile"))
    engine.SetAction("<TC_DownSelect>", T("act.TotalCommander.TC_DownSelect"))
    engine.SetAction("<TC_FileCopyForBak>", T("act.TotalCommander.TC_FileCopyForBak"))
    engine.SetAction("<TC_FileMoveForBak>", T("act.TotalCommander.TC_FileMoveForBak"))
    engine.SetAction("<TC_FilterSearchFNsuffix_exe>", T("act.TotalCommander.TC_FilterSearchFNsuffix_exe"))
    engine.SetAction("<TC_FocusTCCmd>", T("act.TotalCommander.TC_FocusTCCmd"))
    engine.SetAction("<TC_ForceDelete>", T("act.TotalCommander.TC_ForceDelete"))
    engine.SetAction("<TC_GoLastTab>", T("act.TotalCommander.TC_GoLastTab"))
    engine.SetAction("<TC_GotoLine>", T("act.TotalCommander.TC_GotoLine"))
    engine.SetAction("<TC_GotoNextDirOther>", T("act.TotalCommander.TC_GotoNextDirOther"))
    engine.SetAction("<TC_GoToParentEx>", T("act.TotalCommander.TC_GoToParentEx"))
    engine.SetAction("<TC_GotoPreviousDirOther>", T("act.TotalCommander.TC_GotoPreviousDirOther"))
    engine.SetAction("<TC_Half>", T("act.TotalCommander.TC_Half"))
    engine.SetAction("<TC_InsertMode>", T("act.TotalCommander.TC_InsertMode"))
    engine.SetAction("<TC_LastLine>", T("act.TotalCommander.TC_LastLine"))
    engine.SetAction("<TC_ListMark>", T("act.TotalCommander.TC_ListMark"))
    engine.SetAction("<TC_Mark>", T("act.TotalCommander.TC_Mark"))
    engine.SetAction("<TC_MarkFile>", T("act.TotalCommander.TC_MarkFile"))
    engine.SetAction("<TC_MoveAllFilesToPrevFolder>", T("act.TotalCommander.TC_MoveAllFilesToPrevFolder"))
    engine.SetAction("<TC_MoveDirectoryHotlist>", T("act.TotalCommander.TC_MoveDirectoryHotlist"))
    engine.SetAction("<TC_MoveSelectedFilesToPrevFolder>", T("act.TotalCommander.TC_MoveSelectedFilesToPrevFolder"))
    engine.SetAction("<TC_MoveUseQueues>", T("act.TotalCommander.TC_MoveUseQueues"))
    engine.SetAction("<TC_MultiFilePersistOpen>", T("act.TotalCommander.TC_MultiFilePersistOpen"))
    engine.SetAction("<TC_NormalMode>", T("act.TotalCommander.TC_NormalMode"))
    engine.SetAction("<TC_OpenDirAndPaste>", T("act.TotalCommander.TC_OpenDirAndPaste"))
    engine.SetAction("<TC_OpenDirsInFile>", T("act.TotalCommander.TC_OpenDirsInFile"))
    engine.SetAction("<TC_OpenDriveThat>", T("act.TotalCommander.TC_OpenDriveThat"))
    engine.SetAction("<TC_OpenDriveThis>", T("act.TotalCommander.TC_OpenDriveThis"))
    engine.SetAction("<TC_OpenWithAlternateViewer>", T("act.TotalCommander.TC_OpenWithAlternateViewer"))
    engine.SetAction("<TC_PasteFileEx>", T("act.TotalCommander.TC_PasteFileEx"))
    engine.SetAction("<TC_ReOpenTab>", T("act.TotalCommander.TC_ReOpenTab"))
    engine.SetAction("<TC_Restart>", T("act.TotalCommander.TC_Restart"))
    engine.SetAction("<TC_SearchMode>", T("act.TotalCommander.TC_SearchMode"))
    engine.SetAction("<TC_SelectCmd>", T("act.TotalCommander.TC_SelectCmd"))
    engine.SetAction("<TC_SrcQuickViewAndTab>", T("act.TotalCommander.TC_SrcQuickViewAndTab"))
    engine.SetAction("<TC_SuperReturn>", T("act.TotalCommander.TC_SuperReturn"))
    engine.SetAction("<TC_ThumbsView>", T("act.TotalCommander.TC_ThumbsView"))
    engine.SetAction("<TC_Toggle_50_100Percent_V>", T("act.TotalCommander.TC_Toggle_50_100Percent_V"))
    engine.SetAction("<TC_Toggle_50_100Percent>", T("act.TotalCommander.TC_Toggle_50_100Percent"))
    engine.SetAction("<TC_ToggleMenu>", T("act.TotalCommander.TC_ToggleMenu"))
    engine.SetAction("<TC_ToggleShowInfo>", T("act.TotalCommander.TC_ToggleShowInfo"))
    engine.SetAction("<TC_ToggleTC>", T("act.TotalCommander.TC_ToggleTC"))
    engine.SetAction("<TC_TwoFileExchangeName>", T("act.TotalCommander.TC_TwoFileExchangeName"))
    engine.SetAction("<TC_UnMarkFile>", T("act.TotalCommander.TC_UnMarkFile"))
    engine.SetAction("<TC_UpSelect>", T("act.TotalCommander.TC_UpSelect"))
    engine.SetAction("<TC_ViewFileUnderCursor>", T("act.TotalCommander.TC_ViewFileUnderCursor"))
    engine.SetAction("<TC_WinMaxLeft>", T("act.TotalCommander.TC_WinMaxLeft"))
    engine.SetAction("<TC_WinMaxRight>", T("act.TotalCommander.TC_WinMaxRight"))
    ; 注册窗口 (类名匹配, 不绑死进程名: 32 位 TOTALCMD.EXE / 64 位 TOTALCMD64.EXE 通吃)
    engine.SetWin("TTOTAL_CMD", "TTOTAL_CMD", "")
    engine.SetWin("TCQuickSearch", "TQUICKSEARCH", "")

    ; 注册模式
    engine.SetMode("normal", "TTOTAL_CMD")
    engine.SetMode("insert", "TTOTAL_CMD")
    engine.SetMode("search", "TTOTAL_CMD")
    engine.SetMode("normal", "TCQuickSearch")

    ; 设置 BeforeActionDo 回调 (仅 TTOTAL_CMD 窗, 对齐原版; 全局注册会误伤其它窗口)
    Rim.vim.SetBeforeActionDoForWin("TTOTAL_CMD", TC_BeforeActionDo)
    Rim.vim.SetPreKeyFilterForWin("TTOTAL_CMD", TC_PreKeyFilter)
    Rim.vim.RegisterPrefixActionHandler("cm_", TC_HandleCmAction)
    Rim.vim.RegisterActionValidator("cm_", TC_ValidateCmAction)
    Rim.vim.RegisterPrefixActionHandler("tccmd|", (action) => (TC_Run(SubStr(action, 7)), true))

    ; === 基础动作 ===
    engine.SetAction("<TC_NormalMode>", T("act.TotalCommander.TC_NormalMode"))
    engine.SetAction("<TC_InsertMode>", T("act.TotalCommander.TC_InsertMode"))
    engine.SetAction("<TC_ToggleTC>", T("act.TotalCommander.TC_ToggleTC"))
    engine.SetAction("<TC_Restart>", T("act.TotalCommander.TC_Restart_2"))

    ; === 导航 ===
    engine.SetAction("<TC_GoToParentEx>", T("act.TotalCommander.TC_GoToParentEx_2"))
    engine.SetAction("<cm_GotoRoot>", T("act.TotalCommander.cm_GotoRoot"))
    engine.SetAction("<cm_GotoPreviousDir>", T("act.TotalCommander.cm_GotoPreviousDir"))
    engine.SetAction("<cm_GotoNextDir>", T("act.TotalCommander.cm_GotoNextDir"))
    engine.SetAction("<TC_DownSelect>", T("act.TotalCommander.TC_DownSelect"))
    engine.SetAction("<TC_UpSelect>", T("act.TotalCommander.TC_UpSelect"))
    engine.SetAction("<TC_GotoLine>", T("act.TotalCommander.TC_GotoLine_2"))
    engine.SetAction("<TC_LastLine>", T("act.TotalCommander.TC_LastLine_2"))
    engine.SetAction("<TC_Half>", T("act.TotalCommander.TC_Half_2"))

    ; === 文件操作 ===
    engine.SetAction("<cm_CopyOtherpanel>", T("act.TotalCommander.cm_CopyOtherpanel_2"))
    engine.SetAction("<cm_MoveOnly>", T("act.TotalCommander.cm_MoveOnly_2"))
    engine.SetAction("<cm_CopyToClipboard>", T("act.TotalCommander.cm_CopyToClipboard_2"))
    engine.SetAction("<cm_CutToClipboard>", T("act.TotalCommander.cm_CutToClipboard_2"))
    engine.SetAction("<cm_PasteFromClipboard>", T("act.TotalCommander.cm_PasteFromClipboard_2"))
    engine.SetAction("<cm_Delete>", T("act.TotalCommander.cm_Delete"))
    engine.SetAction("<cm_RenameOnly>", T("act.TotalCommander.cm_RenameOnly_2"))
    engine.SetAction("<cm_MultiRenameFiles>", T("act.TotalCommander.cm_MultiRenameFiles"))
    engine.SetAction("<cm_MkDir>", T("act.TotalCommander.cm_MkDir"))
    engine.SetAction("<cm_Edit>", T("act.TotalCommander.cm_Edit_2"))
    engine.SetAction("<cm_View>", T("act.TotalCommander.cm_View"))
    engine.SetAction("<cm_PackFiles>", T("act.TotalCommander.cm_PackFiles"))
    engine.SetAction("<cm_UnpackFiles>", T("act.TotalCommander.cm_UnpackFiles"))
    engine.SetAction("<cm_CopyNamesToClip>", T("act.TotalCommander.cm_CopyNamesToClip"))
    engine.SetAction("<cm_CopyFullNamesToClip>", T("act.TotalCommander.cm_CopyFullNamesToClip_2"))
    engine.SetAction("<cm_CopySrcPathToClip>", T("act.TotalCommander.cm_CopySrcPathToClip_2"))
    engine.SetAction("<cm_CopyFileContents>", T("act.TotalCommander.cm_CopyFileContents"))

    ; === 搜索 ===
    engine.SetAction("<cm_SearchFor>", T("act.TotalCommander.cm_SearchFor_2"))
    engine.SetAction("<cm_ShowQuickSearch>", T("act.TotalCommander.cm_ShowQuickSearch_2"))

    ; === 比较 ===
    engine.SetAction("<cm_CompareDirs>", T("act.TotalCommander.cm_CompareDirs_2"))
    engine.SetAction("<cm_CompareByContent>", T("act.TotalCommander.cm_CompareByContent"))
    engine.SetAction("<cm_SyncDirs>", T("act.TotalCommander.cm_SyncDirs"))

    ; === 选择 ===
    engine.SetAction("<cm_SelectAll>", T("act.TotalCommander.cm_SelectAll_2"))
    engine.SetAction("<cm_ExchangeSelection>", T("act.TotalCommander.cm_ExchangeSelection_2"))
    engine.SetAction("<cm_ProperCase>", T("act.TotalCommander.cm_ProperCase"))
    engine.SetAction("<cm_LowerCase>", T("act.TotalCommander.cm_LowerCase"))
    engine.SetAction("<cm_UpperCase>", T("act.TotalCommander.cm_UpperCase"))

    ; === 刷新 ===
    engine.SetAction("<cm_Refresh>", T("act.TotalCommander.cm_Refresh"))

    ; === 标签页 ===
    engine.SetAction("<cm_OpenNewTab>", T("act.TotalCommander.cm_OpenNewTab"))
    engine.SetAction("<cm_OpenNewTabBg>", T("act.TotalCommander.cm_OpenNewTabBg_2"))
    engine.SetAction("<cm_SwitchToNextTab>", T("act.TotalCommander.cm_SwitchToNextTab_2"))
    engine.SetAction("<cm_SwitchToPreviousTab>", T("act.TotalCommander.cm_SwitchToPreviousTab_2"))
    engine.SetAction("<cm_CloseCurrentTab>", T("act.TotalCommander.cm_CloseCurrentTab"))
    engine.SetAction("<cm_CloseAllTabs>", T("act.TotalCommander.cm_CloseAllTabs"))
    engine.SetAction("<cm_SrcGoToLastTab>", T("act.TotalCommander.cm_SrcGoToLastTab"))

    ; === 排序 ===
    engine.SetAction("<cm_SrcByName>", T("act.TotalCommander.cm_SrcByName_2"))
    engine.SetAction("<cm_SrcByExt>", T("act.TotalCommander.cm_SrcByExt_2"))
    engine.SetAction("<cm_SrcBySize>", T("act.TotalCommander.cm_SrcBySize_2"))
    engine.SetAction("<cm_SrcByDateTime>", T("act.TotalCommander.cm_SrcByDateTime_2"))
    engine.SetAction("<cm_SrcByAttr>", T("act.TotalCommander.cm_SrcByAttr"))
    engine.SetAction("<cm_SrcNegSort>", T("act.TotalCommander.cm_SrcNegSort"))

    ; === 视图 ===
    engine.SetAction("<cm_SrcShort>", T("act.TotalCommander.cm_SrcShort_2"))
    engine.SetAction("<cm_SrcLong>", T("act.TotalCommander.cm_SrcLong_2"))
    engine.SetAction("<cm_SrcTree>", T("act.TotalCommander.cm_SrcTree_2"))
    engine.SetAction("<cm_SrcThumbs>", T("act.TotalCommander.cm_SrcThumbs_2"))
    engine.SetAction("<cm_SrcQuickView>", T("act.TotalCommander.cm_SrcQuickView"))
    engine.SetAction("<cm_ToggleTreeView>", T("act.TotalCommander.cm_ToggleTreeView"))

    ; === 窗口 ===
    engine.SetAction("<cm_MaximizePanel1>", T("act.TotalCommander.cm_MaximizePanel1"))
    engine.SetAction("<cm_MaximizePanel2>", T("act.TotalCommander.cm_MaximizePanel2"))
    engine.SetAction("<cm_Exchange>", T("act.TotalCommander.cm_Exchange_2"))
    engine.SetAction("<cm_Minimize>", T("act.TotalCommander.cm_Minimize_2"))
    engine.SetAction("<cm_Maximize>", T("act.TotalCommander.cm_Maximize_2"))
    engine.SetAction("<cm_Restore>", T("act.TotalCommander.cm_Restore_2"))

    ; === 其他 ===
    engine.SetAction("<cm_ContextMenu>", T("act.TotalCommander.cm_ContextMenu_2"))
    engine.SetAction("<cm_ExecuteDOS>", T("act.TotalCommander.cm_ExecuteDOS_2"))
    engine.SetAction("<cm_FocusCmdLine>", T("act.TotalCommander.cm_FocusCmdLine_2"))
    engine.SetAction("<cm_DirectoryHotlist>", T("act.TotalCommander.cm_DirectoryHotlist"))
    engine.SetAction("<cm_LeftOpenDrives>", T("act.TotalCommander.cm_LeftOpenDrives_2"))
    engine.SetAction("<cm_RightOpenDrives>", T("act.TotalCommander.cm_RightOpenDrives_2"))
    engine.SetAction("<cm_SrcHome>", T("act.TotalCommander.cm_SrcHome"))
    engine.SetAction("<cm_DirHome>", T("act.TotalCommander.cm_DirHome"))
    engine.SetAction("<cm_Config>", T("act.TotalCommander.cm_Config_2"))
    engine.SetAction("<cm_Exit>", T("act.TotalCommander.cm_Exit_2"))

    ; === 高级功能 ===
    engine.SetAction("<TC_Mark>", T("act.TotalCommander.TC_Mark"))
    engine.SetAction("<TC_ListMark>", T("act.TotalCommander.TC_ListMark"))
    engine.SetAction("<TC_azHistory>", T("act.TotalCommander.TC_azHistory"))
    engine.SetAction("<TC_CreateNewFile>", T("act.TotalCommander.TC_CreateNewFile_2"))
    engine.SetAction("<TC_ForceDelete>", T("act.TotalCommander.TC_ForceDelete"))
    engine.SetAction("<TC_Toggle_50_100Percent>", T("act.TotalCommander.TC_Toggle_50_100Percent_2"))
    engine.SetAction("<TC_AlwayOnTop>", T("act.TotalCommander.TC_AlwayOnTop_2"))
    engine.SetAction("<TC_ToggleShowInfo>", T("act.TotalCommander.TC_ToggleShowInfo_2"))
    engine.SetAction("<TC_SelectCmd>", T("act.TotalCommander.TC_SelectCmd_2"))
    engine.SetAction("<TC_OpenDriveThis>", T("act.TotalCommander.TC_OpenDriveThis_2"))
    engine.SetAction("<TC_OpenDriveThat>", T("act.TotalCommander.TC_OpenDriveThat_2"))
    engine.SetAction("<TC_ToggleMenu>", T("act.TotalCommander.TC_ToggleMenu_2"))
    engine.SetAction("<TC_ToggleToolbar>", T("act.TotalCommander.TC_ToggleToolbar"))
    engine.SetAction("<TC_ToggleStatusBar>", T("act.TotalCommander.TC_ToggleStatusBar"))
    engine.SetAction("<TC_WinMaxLeft>", T("act.TotalCommander.cm_MaximizePanel1"))
    engine.SetAction("<TC_WinMaxRight>", T("act.TotalCommander.cm_MaximizePanel2"))
    engine.SetAction("<TC_FileCopyForBak>", T("act.TotalCommander.TC_FileCopyForBak_2"))
    engine.SetAction("<TC_FileMoveForBak>", T("act.TotalCommander.TC_FileMoveForBak_2"))
    engine.SetAction("<TC_CreateFileShortcut>", T("act.TotalCommander.cm_CreateShortcut"))
    engine.SetAction("<TC_CreateFileShortcutToDesktop>", T("act.TotalCommander.TC_CreateFileShortcutToDesktop_2"))
    engine.SetAction("<TC_CreateBlankFile>", T("act.TotalCommander.TC_CreateBlankFile"))

    ; === 高级功能 ===
    engine.SetAction("<TC_CopyUseQueues>", T("act.TotalCommander.TC_CopyUseQueues_2"))
    engine.SetAction("<TC_MoveUseQueues>", T("act.TotalCommander.TC_MoveUseQueues_2"))
    engine.SetAction("<TC_CopyDirectoryHotlist>", T("act.TotalCommander.TC_CopyDirectoryHotlist"))
    engine.SetAction("<TC_MoveDirectoryHotlist>", T("act.TotalCommander.TC_MoveDirectoryHotlist"))
    engine.SetAction("<TC_GotoPreviousDirOther>", T("act.TotalCommander.TC_GotoPreviousDirOther_2"))
    engine.SetAction("<TC_GotoNextDirOther>", T("act.TotalCommander.TC_GotoNextDirOther_2"))
    engine.SetAction("<TC_SearchMode>", T("act.TotalCommander.TC_SearchMode_2"))
    engine.SetAction("<TC_ReOpenTab>", T("act.TotalCommander.TC_ReOpenTab_2"))
    engine.SetAction("<TC_GoLastTab>", T("act.TotalCommander.TC_GoLastTab_2"))
    engine.SetAction("<TC_Toggle_50_100Percent_V>", T("act.TotalCommander.TC_Toggle_50_100Percent_V_2"))
    engine.SetAction("<TC_SuperReturn>", T("act.TotalCommander.TC_SuperReturn_2"))
    engine.SetAction("<TC_MultiFilePersistOpen>", T("act.TotalCommander.TC_MultiFilePersistOpen_2"))
    engine.SetAction("<TC_CopyFileContents>", T("act.TotalCommander.cm_CopyFileContents"))
    engine.SetAction("<TC_OpenDirAndPaste>", T("act.TotalCommander.TC_OpenDirAndPaste_2"))
    engine.SetAction("<TC_MoveSelectedFilesToPrevFolder>", T("act.TotalCommander.TC_MoveSelectedFilesToPrevFolder_2"))
    engine.SetAction("<TC_MoveAllFilesToPrevFolder>", T("act.TotalCommander.TC_MoveAllFilesToPrevFolder_2"))
    engine.SetAction("<TC_SrcQuickViewAndTab>", T("act.TotalCommander.TC_SrcQuickViewAndTab_2"))
    engine.SetAction("<TC_CreateFileShortcutToStartup>", T("act.TotalCommander.TC_CreateFileShortcutToStartup_2"))
    engine.SetAction("<TC_FilterSearchFNsuffix_exe>", T("act.TotalCommander.TC_FilterSearchFNsuffix_exe_2"))
    engine.SetAction("<TC_TwoFileExchangeName>", T("act.TotalCommander.TC_TwoFileExchangeName_2"))
    engine.SetAction("<TC_MarkFile>", T("act.TotalCommander.TC_MarkFile_2"))
    engine.SetAction("<TC_UnMarkFile>", T("act.TotalCommander.TC_UnMarkFile_2"))
    engine.SetAction("<TC_ClearTitle>", T("act.TotalCommander.TC_ClearTitle_2"))
    engine.SetAction("<TC_OpenDirsInFile>", T("act.TotalCommander.TC_OpenDirsInFile_2"))
    engine.SetAction("<TC_CreateBlankFileNoExt>", T("act.TotalCommander.TC_CreateBlankFileNoExt_2"))
    engine.SetAction("<TC_PasteFileEx>", T("act.TotalCommander.TC_PasteFileEx_2"))
    engine.SetAction("<TC_ThumbsView>", T("act.TotalCommander.TC_ThumbsView_2"))
    engine.SetAction("<TC_SrcActivateTab1>", T("act.TotalCommander.TC_SrcActivateTab1"))
    engine.SetAction("<TC_SrcActivateTab2>", T("act.TotalCommander.TC_SrcActivateTab2"))
    engine.SetAction("<TC_SrcActivateTab3>", T("act.TotalCommander.TC_SrcActivateTab3"))
    engine.SetAction("<TC_SrcActivateTab4>", T("act.TotalCommander.TC_SrcActivateTab4"))
    engine.SetAction("<TC_SrcActivateTab5>", T("act.TotalCommander.TC_SrcActivateTab5"))
    engine.SetAction("<TC_SrcActivateTab6>", T("act.TotalCommander.TC_SrcActivateTab6"))
    engine.SetAction("<TC_SrcActivateTab7>", T("act.TotalCommander.TC_SrcActivateTab7"))
    engine.SetAction("<TC_SrcActivateTab8>", T("act.TotalCommander.TC_SrcActivateTab8"))
    engine.SetAction("<TC_SrcActivateTab9>", T("act.TotalCommander.TC_SrcActivateTab9"))

    ; === 映射热键 - normal 模式 (1:1 对原版 vim.map, 顺序同原版) ===

    ; 复制/移动 f=file (原版 fqc/fqx, 非移植版 fq/fQ)
    engine.MapKey("fc", "<cm_CopyOtherpanel>", "TTOTAL_CMD", "normal")
    engine.MapKey("fx", "<cm_MoveOnly>", "TTOTAL_CMD", "normal")
    engine.MapKey("fqc", "<TC_CopyUseQueues>", "TTOTAL_CMD", "normal")
    engine.MapKey("fqx", "<TC_MoveUseQueues>", "TTOTAL_CMD", "normal")
    engine.MapKey("ff", "<cm_CopyToClipboard>", "TTOTAL_CMD", "normal")
    engine.MapKey("fz", "<cm_CutToClipboard>", "TTOTAL_CMD", "normal")
    engine.MapKey("fv", "<cm_PasteFromClipboard>", "TTOTAL_CMD", "normal")
    engine.MapKey("fb", "<TC_CopyDirectoryHotlist>", "TTOTAL_CMD", "normal")
    engine.MapKey("fd", "<TC_MoveDirectoryHotlist>", "TTOTAL_CMD", "normal")
    engine.MapKey("fg", "<cm_CopySrcPathToClip>", "TTOTAL_CMD", "normal")
    engine.MapKey("ft", "<cm_SyncChangeDir>", "TTOTAL_CMD", "normal")
    engine.MapKey("F", "<TC_SearchMode>", "TTOTAL_CMD", "normal")
    engine.MapKey("gh", "<TC_GotoPreviousDirOther>", "TTOTAL_CMD", "normal")
    engine.MapKey("gl", "<TC_GotoNextDirOther>", "TTOTAL_CMD", "normal")
    engine.MapKey("Vh", "<cm_SwitchIgnoreList>", "TTOTAL_CMD", "normal")

    ; 数字键 (原版 <TC_0-9> 只清 count 不打字; v2 空函数复刻, 不用 <Pass> 透传)
    engine.MapKey("0", "<TC_0>", "TTOTAL_CMD", "normal")
    engine.MapKey("1", "<TC_1>", "TTOTAL_CMD", "normal")
    engine.MapKey("2", "<TC_2>", "TTOTAL_CMD", "normal")
    engine.MapKey("3", "<TC_3>", "TTOTAL_CMD", "normal")
    engine.MapKey("4", "<TC_4>", "TTOTAL_CMD", "normal")
    engine.MapKey("5", "<TC_5>", "TTOTAL_CMD", "normal")
    engine.MapKey("6", "<TC_6>", "TTOTAL_CMD", "normal")
    engine.MapKey("7", "<TC_7>", "TTOTAL_CMD", "normal")
    engine.MapKey("8", "<TC_8>", "TTOTAL_CMD", "normal")
    engine.MapKey("9", "<TC_9>", "TTOTAL_CMD", "normal")

    ; 基础导航 (与原版一致)
    engine.MapKey("j", "<down>", "TTOTAL_CMD", "normal")
    engine.MapKey("k", "<up>", "TTOTAL_CMD", "normal")
    engine.MapKey("h", "<left>", "TTOTAL_CMD", "normal")
    engine.MapKey("l", "<right>", "TTOTAL_CMD", "normal")
    engine.MapKey("J", "<TC_DownSelect>", "TTOTAL_CMD", "normal")
    engine.MapKey("K", "<TC_UpSelect>", "TTOTAL_CMD", "normal")
    engine.MapKey("M", "<TC_Half>", "TTOTAL_CMD", "normal")
    engine.MapKey("gg", "<TC_GoToLine>", "TTOTAL_CMD", "normal")
    engine.MapKey("G", "<TC_LastLine>", "TTOTAL_CMD", "normal")
    engine.MapKey("H", "<cm_GotoPreviousDir>", "TTOTAL_CMD", "normal")
    engine.MapKey("L", "<cm_GotoNextDir>", "TTOTAL_CMD", "normal")
    engine.MapKey("u", "<TC_GoToParentEx>", "TTOTAL_CMD", "normal")
    engine.MapKey("U", "<cm_GotoRoot>", "TTOTAL_CMD", "normal")
    engine.MapKey("<Esc>", "<TC_NormalMode>", "TTOTAL_CMD", "insert")

    ; 文件操作 (与原版一致; w=cm_List 非 cm_View; I/i 不动)
    engine.MapKey("x", "<cm_Delete>", "TTOTAL_CMD", "normal")
    engine.MapKey("X", "<TC_ForceDelete>", "TTOTAL_CMD", "normal")
    engine.MapKey("r", "<cm_RenameOnly>", "TTOTAL_CMD", "normal")
    engine.MapKey("R", "<cm_MultiRenameFiles>", "TTOTAL_CMD", "normal")
    engine.MapKey("n", "<TC_azHistory>", "TTOTAL_CMD", "normal")
    engine.MapKey("I", "<TC_CreateNewFile>", "TTOTAL_CMD", "normal")
    engine.MapKey("e", "<cm_ContextMenu>", "TTOTAL_CMD", "normal")
    engine.MapKey("E", "<cm_ExecuteDOS>", "TTOTAL_CMD", "normal")
    engine.MapKey("i", "<TC_InsertMode>", "TTOTAL_CMD", "normal")
    engine.MapKey(":", "<cm_FocusCmdLine>", "TTOTAL_CMD", "normal")

    ; 复制/移动 (上部 f 系列已对原版; fa 归 ini, fp/fq 系移植版自创已 drop, 后续按需加回)

    ; 查看/搜索 (w=cm_List 对原版, 非 cm_View)
    engine.MapKey("w", "<cm_List>", "TTOTAL_CMD", "normal")
    engine.MapKey("q", "<cm_SrcQuickView>", "TTOTAL_CMD", "normal")
    engine.MapKey("/", "<cm_ShowQuickSearch>", "TTOTAL_CMD", "normal")
    engine.MapKey("?", "<cm_SearchFor>", "TTOTAL_CMD", "normal")

    ; 复制信息
    engine.MapKey("y", "<cm_CopyNamesToClip>", "TTOTAL_CMD", "normal")
    engine.MapKey("Y", "<cm_CopyFullNamesToClip>", "TTOTAL_CMD", "normal")

    ; 压缩/解压
    engine.MapKey("P", "<cm_PackFiles>", "TTOTAL_CMD", "normal")
    engine.MapKey("p", "<cm_UnpackFiles>", "TTOTAL_CMD", "normal")

    ; 选择 (原版全量: [ ] { } \ | ; a 走 ini)
    engine.MapKey("[", "<cm_SelectCurrentName>", "TTOTAL_CMD", "normal")
    engine.MapKey("{", "<cm_UnselectCurrentName>", "TTOTAL_CMD", "normal")
    engine.MapKey("]", "<cm_SelectCurrentExtension>", "TTOTAL_CMD", "normal")
    engine.MapKey("}", "<cm_UnSelectCurrentExtension>", "TTOTAL_CMD", "normal")
    engine.MapKey("\", "<cm_ExchangeSelection>", "TTOTAL_CMD", "normal")
    engine.MapKey("|", "<cm_ClearAll>", "TTOTAL_CMD", "normal")

    ; 符号键 (原版: -/=/~/` ; . 归 ini/custom, 不在硬编码)
    engine.MapKey("-", "<cm_SwitchSeparateTree>", "TTOTAL_CMD", "normal")
    engine.MapKey("=", "<cm_MatchSrc>", "TTOTAL_CMD", "normal")
    engine.MapKey("~", "<cm_SysInfo>", "TTOTAL_CMD", "normal")
    engine.MapKey("``", "<TC_ToggleShowInfo>", "TTOTAL_CMD", "normal")
    engine.MapKey(",", "<cm_SrcThumbs>", "TTOTAL_CMD", "normal")
    engine.MapKey(";", "<cm_DirectoryHotlist>", "TTOTAL_CMD", "normal")

    ; 驱动器 (与原版一致)
    engine.MapKey("o", "<cm_LeftOpenDrives>", "TTOTAL_CMD", "normal")
    engine.MapKey("O", "<cm_RightOpenDrives>", "TTOTAL_CMD", "normal")
    engine.MapKey("d", "<cm_DirectoryHotlist>", "TTOTAL_CMD", "normal")
    engine.MapKey("D", "<cm_OpenDesktop>", "TTOTAL_CMD", "normal")

    ; 标签页 (原版: g1-9=cm_SrcActivateTab, g0=TC_GoLastTab, 无 Gen_Tab*)
    engine.MapKey("t", "<cm_OpenNewTab>", "TTOTAL_CMD", "normal")
    engine.MapKey("T", "<cm_OpenNewTabBg>", "TTOTAL_CMD", "normal")
    engine.MapKey("g0", "<TC_GoLastTab>", "TTOTAL_CMD", "normal")
    engine.MapKey("g1", "<cm_SrcActivateTab1>", "TTOTAL_CMD", "normal")
    engine.MapKey("g2", "<cm_SrcActivateTab2>", "TTOTAL_CMD", "normal")
    engine.MapKey("g3", "<cm_SrcActivateTab3>", "TTOTAL_CMD", "normal")
    engine.MapKey("g4", "<cm_SrcActivateTab4>", "TTOTAL_CMD", "normal")
    engine.MapKey("g5", "<cm_SrcActivateTab5>", "TTOTAL_CMD", "normal")
    engine.MapKey("g6", "<cm_SrcActivateTab6>", "TTOTAL_CMD", "normal")
    engine.MapKey("g7", "<cm_SrcActivateTab7>", "TTOTAL_CMD", "normal")
    engine.MapKey("g8", "<cm_SrcActivateTab8>", "TTOTAL_CMD", "normal")
    engine.MapKey("g9", "<cm_SrcActivateTab9>", "TTOTAL_CMD", "normal")

    ; 标签页管理 (原版: gb=对侧新标签, gw=带标签交换, gr=重开)
    engine.MapKey("ga", "<cm_CloseAllTabs>", "TTOTAL_CMD", "normal")
    engine.MapKey("gc", "<cm_CloseCurrentTab>", "TTOTAL_CMD", "normal")
    engine.MapKey("gt", "<cm_SwitchToNextTab>", "TTOTAL_CMD", "normal")
    engine.MapKey("gT", "<cm_SwitchToPreviousTab>", "TTOTAL_CMD", "normal")
    engine.MapKey("ge", "<cm_Exchange>", "TTOTAL_CMD", "normal")
    engine.MapKey("gb", "<cm_OpenDirInNewTabOther>", "TTOTAL_CMD", "normal")
    engine.MapKey("gr", "<TC_ReOpenTab>", "TTOTAL_CMD", "normal")
    engine.MapKey("gw", "<cm_ExchangeWithTabs>", "TTOTAL_CMD", "normal")
    engine.MapKey("g$", "<TC_LastLine>", "TTOTAL_CMD", "normal")

    ; 排序 (原版: sr=NegOrder, s1-9=按列, s0=无序)
    engine.MapKey("sn", "<cm_SrcByName>", "TTOTAL_CMD", "normal")
    engine.MapKey("se", "<cm_SrcByExt>", "TTOTAL_CMD", "normal")
    engine.MapKey("ss", "<cm_SrcBySize>", "TTOTAL_CMD", "normal")
    engine.MapKey("sd", "<cm_SrcByDateTime>", "TTOTAL_CMD", "normal")
    engine.MapKey("sr", "<cm_SrcNegOrder>", "TTOTAL_CMD", "normal")
    engine.MapKey("s1", "<cm_SrcSortByCol1>", "TTOTAL_CMD", "normal")
    engine.MapKey("s2", "<cm_SrcSortByCol2>", "TTOTAL_CMD", "normal")
    engine.MapKey("s3", "<cm_SrcSortByCol3>", "TTOTAL_CMD", "normal")
    engine.MapKey("s4", "<cm_SrcSortByCol4>", "TTOTAL_CMD", "normal")
    engine.MapKey("s5", "<cm_SrcSortByCol5>", "TTOTAL_CMD", "normal")
    engine.MapKey("s6", "<cm_SrcSortByCol6>", "TTOTAL_CMD", "normal")
    engine.MapKey("s7", "<cm_SrcSortByCol7>", "TTOTAL_CMD", "normal")
    engine.MapKey("s8", "<cm_SrcSortByCol8>", "TTOTAL_CMD", "normal")
    engine.MapKey("s9", "<cm_SrcSortByCol9>", "TTOTAL_CMD", "normal")
    engine.MapKey("s0", "<cm_SrcUnsorted>", "TTOTAL_CMD", "normal")

    ; 视图 (原版 V 系=界面显隐开关, 非移植版重构版)
    engine.MapKey("v", "<cm_SrcCustomViewMenu>", "TTOTAL_CMD", "normal")
    engine.MapKey("Vb", "<cm_VisButtonbar>", "TTOTAL_CMD", "normal")
    engine.MapKey("Vm", "<TC_ToggleMenu>", "TTOTAL_CMD", "normal")
    engine.MapKey("Vd", "<cm_VisDriveButtons>", "TTOTAL_CMD", "normal")
    engine.MapKey("Vo", "<cm_VisTwoDriveButtons>", "TTOTAL_CMD", "normal")
    engine.MapKey("Vr", "<cm_VisDriveCombo>", "TTOTAL_CMD", "normal")
    engine.MapKey("Vc", "<cm_VisDriveCombo>", "TTOTAL_CMD", "normal")
    engine.MapKey("Vt", "<cm_VisTabHeader>", "TTOTAL_CMD", "normal")
    engine.MapKey("Vs", "<cm_VisStatusbar>", "TTOTAL_CMD", "normal")
    engine.MapKey("Vn", "<cm_VisCmdLine>", "TTOTAL_CMD", "normal")
    engine.MapKey("Vf", "<cm_VisKeyButtons>", "TTOTAL_CMD", "normal")
    engine.MapKey("Vw", "<cm_VisDirTabs>", "TTOTAL_CMD", "normal")
    engine.MapKey("Ve", "<cm_CommandBrowser>", "TTOTAL_CMD", "normal")

    ; 窗口 (原版: zz/zh=50/100切换, zi/zo=左右最大化, zn/zm/zr=最小/大/还原, zv=纵向)
    engine.MapKey("zz", "<TC_Toggle_50_100Percent>", "TTOTAL_CMD", "normal")
    engine.MapKey("zh", "<TC_Toggle_50_100Percent_V>", "TTOTAL_CMD", "normal")
    engine.MapKey("zi", "<TC_WinMaxLeft>", "TTOTAL_CMD", "normal")
    engine.MapKey("zo", "<TC_WinMaxRight>", "TTOTAL_CMD", "normal")
    engine.MapKey("zt", "<TC_AlwayOnTop>", "TTOTAL_CMD", "normal")
    engine.MapKey("zn", "<cm_Minimize>", "TTOTAL_CMD", "normal")
    engine.MapKey("zm", "<cm_Maximize>", "TTOTAL_CMD", "normal")
    engine.MapKey("zr", "<cm_Restore>", "TTOTAL_CMD", "normal")
    engine.MapKey("zv", "<cm_VerticalPanels>", "TTOTAL_CMD", "normal")

    ; 高级 (与原版一致)
    engine.MapKey("m", "<TC_Mark>", "TTOTAL_CMD", "normal")
    engine.MapKey("'", "<TC_ListMark>", "TTOTAL_CMD", "normal")
    engine.MapKey("``", "<TC_ToggleShowInfo>", "TTOTAL_CMD", "normal")
    engine.MapKey("-", "<TC_Toggle_50_100Percent>", "TTOTAL_CMD", "normal")
    engine.MapKey(";", "<cm_DirectoryHotlist>", "TTOTAL_CMD", "normal")

    ; (原版硬编码到此结束; 以下移植版自创键已移除, 回归原版:
    ;  F10/fB/fM/fs/fS/fi/fI/fq/fQ/fD/fa/ft/fe/fw/fm/fu/gv/gU/gA/gI/z;/Enter/go/gO,
    ;  其中 fa 归 ini 所有, F/gt 与上部重复不再列出)

    ; insert 模式映射
    engine.MapKey("<enter>", "<enter>", "TTOTAL_CMD", "insert")
    engine.MapKey("<bs>", "<bs>", "TTOTAL_CMD", "insert")
    engine.MapKey("<tab>", "<tab>", "TTOTAL_CMD", "insert")
    engine.MapKey("<space>", "<space>", "TTOTAL_CMD", "insert")
    engine.MapKey("<del>", "<del>", "TTOTAL_CMD", "insert")

    ; 快速搜索窗口
    engine.MapKey("j", "<down>", "TCQuickSearch", "normal")
    engine.MapKey("k", "<up>", "TCQuickSearch", "normal")

    ; 菜单字母直达键启动时一次注册常驻 (HotIf 限定 TCMenu 作用域, 平时休眠):
    ; 原先每弹一次绑 36 个热键, 钩子抖动窗口内 arriving 的快速第二键可能丢失,
    ; 且弹出路径变长. 弹/关不再绑/解 (TC_MenuBindKeys/UnbindKeys 保留备用)
    TC_MenuBindKeys()

    ; 注册上下文提供者
    try {
        RimContext.RegisterProvider("totalcommander", TC_ContextProvider)
    }
}

TC_ContextProvider(ctx) {
    try {
        dir := TC_GetCurrentDir()
        if (dir != "")
            ctx.CurrentDir := dir
    } catch {
    }
    try {
        file := TC_GetSelectedFile()
        if (file != "") {
            ctx.SelectedFile := file
            ctx.SelectedFiles := [file]
        }
    } catch {
    }
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
        MsgBox(T("tc.pick_file_first"), T("tc.mark_title"))
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

    ; 创建菜单 (drill-in 子级, 见 TC_PopupMenu)
    setItems := []
    loop 26 {
        letter := Chr(96 + A_Index)  ; a-z
        setItems.Push({label: letter, run: MakeMenuCb("TC_SetMark", filePath, letter)})
    }
    items := [{label: T("tc.mark_set"), sub: setItems}]

    ; 跳转/删除子菜单
    if (marks.Count > 0) {
        gotoItems := []
        for path, char in marks {
            ; 提取文件名
            fileName := SubStr(path, InStr(path, "\", 0, -1) + 1)
            if (StrLen(fileName) > 30)
                fileName := SubStr(fileName, 1, 27) "..."
            gotoItems.Push({label: "[" char "] " fileName, run: MakeMenuCb("TC_GotoMark", path)})
        }
        items.Push({label: T("tc.mark_goto"), sub: gotoItems})

        delItems := []
        for path, char in marks {
            fileName := SubStr(path, InStr(path, "\", 0, -1) + 1)
            if (StrLen(fileName) > 30)
                fileName := SubStr(fileName, 1, 27) "..."
            delItems.Push({label: "[" char "] " fileName, run: MakeMenuCb("TC_DeleteMark", path)})
        }
        items.Push({label: T("tc.mark_del"), sub: delItems})

        ; 清除所有标记
        items.Push({label: T("tc.mark_clear"), run: (*) => TC_ClearAllMarks()})
    }

    ; 显示菜单 (原版弹列表处)
    TC_MenuPos(&mxn, &myn)
    TC_PopupMenu(items, mxn, myn)
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
        MsgBox(T("tc.no_marks_file"), T("tc.mark_list_title"))
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
        MsgBox(T("tc.no_marks"), T("tc.mark_list_title"))
        return
    }

    ; 创建菜单
    items := []
    for path, char in marks {
        fileName := SubStr(path, InStr(path, "\", 0, -1) + 1)
        if (StrLen(fileName) > 40)
            fileName := SubStr(fileName, 1, 37) "..."
        items.Push({label: "[" char "] " fileName, run: MakeMenuCb("TC_GotoMark", path)})
    }
    items.Push({label: T("tc.mark_clear2"), run: (*) => TC_ClearAllMarks()})

    TC_MenuPos(&lxn, &lyn)
    TC_PopupMenu(items, lxn, lyn)
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
        MsgBox(T("tc.no_tc_conf"), T("tc.hist_nav_title"))
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
        MsgBox(T("tc.no_history"), T("tc.az_hist_title"))
        return
    }

    ; 创建菜单
    items := []

    ; 左面板历史
    if (leftHistory.Length > 0) {
        leftItems := []
        maxCount := Min(leftHistory.Length, 26)
        loop maxCount {
            idx := A_Index
            letter := Chr(96 + idx)  ; a, b, c...
            path := leftHistory[idx]
            ; 截断过长的路径
            displayPath := path
            if (StrLen(displayPath) > 50)
                displayPath := "..." SubStr(displayPath, -47)
            leftItems.Push({label: "[" letter "] " displayPath, run: MakeMenuCb("TC_GotoHistory", path, "left")})
        }
        items.Push({label: T("tc.hist_left"), sub: leftItems})
    }

    ; 右面板历史
    if (rightHistory.Length > 0) {
        rightItems := []
        maxCount := Min(rightHistory.Length, 26)
        loop maxCount {
            idx := A_Index
            letter := Chr(64 + idx)  ; A, B, C...
            path := rightHistory[idx]
            displayPath := path
            if (StrLen(displayPath) > 50)
                displayPath := "..." SubStr(displayPath, -47)
            rightItems.Push({label: "[" letter "] " displayPath, run: MakeMenuCb("TC_GotoHistory", path, "right")})
        }
        items.Push({label: T("tc.hist_right"), sub: rightItems})
    }

    ; 清除历史
    items.Push({label: T("tc.hist_clear_left"), run: (*) => TC_ClearHistory("LeftHistory")})
    items.Push({label: T("tc.hist_clear_right"), run: (*) => TC_ClearHistory("RightHistory")})
    items.Push({label: T("tc.hist_clear_all"), run: (*) => TC_ClearHistory("all")})

    ; 显示菜单
    TC_MenuPos(&hxn, &hyn)
    TC_PopupMenu(items, hxn, hyn)
}

TC_ResolveHistoryPath(path) {
    ; 解析历史路径，处理特殊位置
    ; 特殊位置映射
    specialPaths := Map(
        "::{20D04FE0-3AEA-1069-A2D8-08002B30309D}", T("tc.hist_thispc"),
        "::{645FF040-5081-101B-9F08-00AA002F954E}", T("tc.hist_recycle"),
        "::{B4BFCC3A-DB2C-424C-B029-7FE99A8CEC6C}", T("tc.hist_desktop"),
        "::{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}", T("tc.hist_network")
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
        MsgBox(T("tc.no_tc_conf"), T("tc.menu_toggle_title"))
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
        MsgBox(T("tc.pick_file_first"), T("tc.title_copybak"))
        return
    }

    bakPath := filePath ".bak"
    try {
        FileCopy(filePath, bakPath)
        Log("TC: Copied " filePath " to " bakPath)
    } catch as e {
        MsgBox(T("tc.copy_failed", e.Message), T("tc.err_title"))
    }
}

TC_FileMoveForBak() {
    ; 重命名文件加 .bak 后缀
    filePath := TC_GetSelectedFile()
    if (filePath = "") {
        MsgBox(T("tc.pick_file_first"), T("tc.title_movebak"))
        return
    }

    bakPath := filePath ".bak"
    try {
        FileMove(filePath, bakPath)
        Log("TC: Moved " filePath " to " bakPath)
    } catch as e {
        MsgBox(T("tc.rename_failed", e.Message), T("tc.err_title"))
    }
}

TC_CreateFileShortcut() {
    ; 创建快捷方式
    filePath := TC_GetSelectedFile()
    if (filePath = "") {
        MsgBox(T("tc.pick_file_first"), T("tc.title_shortcut"))
        return
    }

    ; 获取当前目录
    currentDir := TC_GetCurrentDir()
    if (currentDir = "") {
        MsgBox(T("tc.no_curdir"), T("tc.title_shortcut"))
        return
    }

    ; 创建快捷方式
    shortcutPath := currentDir "\" SubStr(filePath, InStr(filePath, "\", 0, -1) + 1) ".lnk"
    try {
        FileCreateShortcut(filePath, shortcutPath)
        Log("TC: Created shortcut " shortcutPath)
    } catch as e {
        MsgBox(T("tc.shortcut_failed", e.Message), T("tc.err_title"))
    }
}

TC_CreateFileShortcutToDesktop() {
    ; 创建快捷方式到桌面
    filePath := TC_GetSelectedFile()
    if (filePath = "") {
        MsgBox(T("tc.pick_file_first"), T("tc.title_shortcut_desktop"))
        return
    }

    desktopPath := A_Desktop "\" SubStr(filePath, InStr(filePath, "\", 0, -1) + 1) ".lnk"
    try {
        FileCreateShortcut(filePath, desktopPath)
        Log("TC: Created shortcut to desktop " desktopPath)
    } catch as e {
        MsgBox(T("tc.shortcut_failed", e.Message), T("tc.err_title"))
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
        commands["cm_CopyOtherpanel (" . T("act.TotalCommander.cm_CopyOtherpanel_2") . ")"] := 2001
        commands["cm_MoveOnly (" . T("act.TotalCommander.cm_MoveOnly_2") . ")"] := 2002
        commands["cm_Delete (" . T("act.TotalCommander.cm_Delete") . ")"] := 2003
        commands["cm_Edit (" . T("act.TotalCommander.cm_Edit_2") . ")"] := 2004
        commands["cm_View (" . T("act.TotalCommander.cm_View") . ")"] := 2005
        commands["cm_PackFiles (" . T("act.TotalCommander.cm_PackFiles") . ")"] := 2006
        commands["cm_UnpackFiles (" . T("act.TotalCommander.cm_UnpackFiles") . ")"] := 2007
        commands["cm_CopyToClipboard (" . T("act.TotalCommander.cm_CopyToClipboard_2") . ")"] := 2009
        commands["cm_CutToClipboard (" . T("act.TotalCommander.cm_CutToClipboard_2") . ")"] := 2010
        commands["cm_PasteFromClipboard (" . T("act.TotalCommander.cm_PasteFromClipboard_2") . ")"] := 2011
        commands["cm_MkDir (" . T("act.TotalCommander.cm_MkDir") . ")"] := 2012
        commands["cm_RenameOnly (" . T("act.TotalCommander.cm_RenameOnly_2") . ")"] := 2013
        commands["cm_MultiRenameFiles (" . T("act.TotalCommander.cm_MultiRenameFiles") . ")"] := 2014
        commands["cm_SrcByName (" . T("act.TotalCommander.cm_SrcByName_2") . ")"] := 2015
        commands["cm_SrcByExt (" . T("act.TotalCommander.cm_SrcByExt_2") . ")"] := 2016
        commands["cm_SrcBySize (" . T("act.TotalCommander.cm_SrcBySize_2") . ")"] := 2017
        commands["cm_SrcByDateTime (" . T("act.TotalCommander.cm_SrcByDateTime_2") . ")"] := 2018
        commands["cm_SrcNegSort (" . T("act.TotalCommander.cm_SrcNegSort") . ")"] := 2020
        commands["cm_SrcShort (" . T("act.TotalCommander.cm_SrcShort_2") . ")"] := 2021
        commands["cm_SrcLong (" . T("act.TotalCommander.cm_SrcLong_2") . ")"] := 2022
        commands["cm_SrcTree (" . T("act.TotalCommander.cm_SrcTree_2") . ")"] := 2023
        commands["cm_SrcThumbs (" . T("act.TotalCommander.cm_SrcThumbs_2") . ")"] := 2024
        commands["cm_SrcQuickView (" . T("act.TotalCommander.cm_SrcQuickView") . ")"] := 2025
        commands["cm_ToggleTreeView (" . T("act.TotalCommander.cm_ToggleTreeView") . ")"] := 2026
        commands["cm_Refresh (" . T("act.TotalCommander.cm_Refresh") . ")"] := 2027
        commands["cm_CopySrcPathToClip (" . T("act.TotalCommander.cm_CopySrcPathToClip_2") . ")"] := 2029
        commands["cm_SelectAll (" . T("act.TotalCommander.cm_SelectAll_2") . ")"] := 2030
        commands["cm_ExchangeSelection (" . T("act.TotalCommander.cm_ExchangeSelection_2") . ")"] := 2031
        commands["cm_MaximizePanel1 (" . T("act.TotalCommander.cm_MaximizePanel1") . ")"] := 2032
        commands["cm_MaximizePanel2 (" . T("act.TotalCommander.cm_MaximizePanel2") . ")"] := 2033
        commands["cm_Exchange (" . T("act.TotalCommander.cm_Exchange_2") . ")"] := 2034
        commands["cm_Minimize (" . T("act.TotalCommander.cm_Minimize_2") . ")"] := 2035
        commands["cm_Maximize (" . T("act.TotalCommander.cm_Maximize_2") . ")"] := 2036
        commands["cm_Restore (" . T("act.TotalCommander.cm_Restore_2") . ")"] := 2037
        commands["cm_DirectoryHotlist (" . T("act.TotalCommander.cm_DirectoryHotlist") . ")"] := 2039
        commands["cm_CopyNamesToClip (" . T("act.TotalCommander.cm_CopyNamesToClip") . ")"] := 2040
        commands["cm_CopyFullNamesToClip (" . T("act.TotalCommander.cm_CopyFullNamesToClip_2") . ")"] := 2041
        commands["cm_SearchFor (" . T("act.TotalCommander.cm_SearchFor_2") . ")"] := 2042
        commands["cm_ShowQuickSearch (" . T("act.TotalCommander.cm_ShowQuickSearch_2") . ")"] := 2043
        commands["cm_CompareDirs (" . T("act.TotalCommander.cm_CompareDirs_2") . ")"] := 2044
        commands["cm_SyncDirs (" . T("act.TotalCommander.cm_SyncDirs") . ")"] := 2045
        commands["cm_CompareByContent (" . T("act.TotalCommander.cm_CompareByContent") . ")"] := 2046
        commands["cm_ContextMenu (" . T("act.TotalCommander.cm_ContextMenu_2") . ")"] := 2047
        commands["cm_ExecuteDOS (" . T("act.TotalCommander.cm_ExecuteDOS_2") . ")"] := 2048
        commands["cm_FocusCmdLine (" . T("act.TotalCommander.cm_FocusCmdLine_2") . ")"] := 2049
        commands["cm_LeftOpenDrives (" . T("act.TotalCommander.cm_LeftOpenDrives_2") . ")"] := 2050
        commands["cm_RightOpenDrives (" . T("act.TotalCommander.cm_RightOpenDrives_2") . ")"] := 2051
        commands["cm_Config (" . T("act.TotalCommander.cm_Config_2") . ")"] := 2052
        commands["cm_DirHome (" . T("act.TotalCommander.cm_DirHome") . ")"] := 2053
        commands["cm_GotoRoot (" . T("act.TotalCommander.cm_GotoRoot") . ")"] := 2054
        commands["cm_GotoPreviousDir (" . T("act.TotalCommander.cm_GotoPreviousDir") . ")"] := 2055
        commands["cm_GotoNextDir (" . T("act.TotalCommander.cm_GotoNextDir") . ")"] := 2056
        commands["cm_OpenDesktop (" . T("act.TotalCommander.cm_OpenDesktop") . ")"] := 2057
        commands["cm_OpenNewTab (" . T("act.TotalCommander.cm_OpenNewTab") . ")"] := 3001
        commands["cm_OpenNewTabBg (" . T("act.TotalCommander.cm_OpenNewTabBg_2") . ")"] := 3002
        commands["cm_SwitchToNextTab (" . T("act.TotalCommander.cm_SwitchToNextTab_2") . ")"] := 3003
        commands["cm_SwitchToPreviousTab (" . T("act.TotalCommander.cm_SwitchToPreviousTab_2") . ")"] := 3004
        commands["cm_CloseCurrentTab (" . T("act.TotalCommander.cm_CloseCurrentTab") . ")"] := 3005
        commands["cm_CloseAllTabs (" . T("act.TotalCommander.cm_CloseAllTabs") . ")"] := 3006
        commands["cm_Exit (" . T("act.TotalCommander.cm_Exit_2") . ")"] := 2063
    }

    ; 创建菜单 (drill-in 列表, 见 TC_PopupMenu; 循环变量经 MakeMenuCb 工厂固化)
    items := []
    for name, cmdNum in commands {
        items.Push({label: name, run: MakeMenuCb("TC_SendPos", cmdNum)})
    }

    ; 显示菜单
    TC_MenuPos(&cxn, &cyn)
    TC_PopupMenu(items, cxn, cyn)
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
            MsgBox(T("tc.read_failed", e.Message), T("tc.err_title"))
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
        MsgBox(T("tc.pick_file_first"), T("tc.title_shortcut"))
        return
    }

    startupPath := A_Startup "\" SubStr(filePath, InStr(filePath, "\", 0, -1) + 1) ".lnk"
    try {
        FileCreateShortcut(filePath, startupPath)
        Log("TC: Created shortcut to startup " startupPath)
    } catch as e {
        MsgBox(T("tc.shortcut_failed", e.Message), T("tc.err_title"))
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
        MsgBox(T("tc.pick_first_file"), T("tc.swap_title"))
        return
    }

    ; 提示选择第二个文件
    MsgBox(T("tc.swap_remember"), T("tc.swap_title"))
    Send "{Down}"  ; 移动到下一个文件
    Sleep 100

    file2 := TC_GetSelectedFile()
    if (file2 = "") {
        MsgBox(T("tc.swap_no_second"), T("tc.swap_title"))
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
        MsgBox(T("tc.swap_failed", e.Message), T("tc.err_title"))
    }
}

TC_MarkFile() {
    ; 通过文件备注标记
    filePath := TC_GetSelectedFile()
    if (filePath = "") {
        MsgBox(T("tc.pick_file_first"), T("tc.title_markfile"))
        return
    }

    try {
        ibox3 := InputBox(T("tc.mark_prompt", filePath), T("tc.title_markfile"))
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
        MsgBox(T("tc.pick_file_first"), T("tc.title_unmark"))
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
        MsgBox(T("tc.pick_dirfile"), T("tc.title_opendir"))
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
        MsgBox(T("tc.read_failed", e.Message), T("tc.err_title"))
    }
}

TC_CreateBlankFileNoExt() {
    ; 创建无扩展名空文件 (对原版 NewFile("创建空文件", True, ""): 同一对话框走空文件分支)
    TC_NewFileDialog("", "", true)
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
        engine.MapKey("h", "<left>", "TTOTAL_CMD", "normal")
        engine.MapKey("l", "<right>", "TTOTAL_CMD", "normal")
    } else {
        engine.MapKey("h", "<TC_GoToParentEx>", "TTOTAL_CMD", "normal")
        engine.MapKey("l", "<TC_SuperReturn>", "TTOTAL_CMD", "normal")
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
