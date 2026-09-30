#Requires AutoHotkey v2.0

; === TotalCommander Plugin - TC深度集成 ===
; 移植自 VimDesktop 的 TC 插件（完整版）
; 子模块: TC.Menu (自造 Gui 菜单 + 新建文件对话框); 注册/映射/动作为主体留本文件

#Include TC.Menu.ahk
#Include TotalCommander.Maps.ahk
#Include TotalCommander.Actions.ahk

class TotalCommanderPlugin extends RimPlugin {
    static Name => "TotalCommander"
    static Title => "Total Commander Integration"
    static Description => "Total Commander 深度整合 (双栏文件管理、Vim 模式、标记系统、原生菜单联动)"

    static RegisterContext() {
        try RimContext.RegisterProvider("totalcommander", Map("capture", TC_ContextProvider,
            "canHandle", TC_CanHandle,
            "capabilities", Map("current_directory", "active-panel-path",
                "selected_files", "single-first-only", "selected_file", "first-only")))
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


TC_CanHandle(ctx) {
    try cls := String(ctx.Class)
    catch {
        return false
    }
    return cls = "TTOTAL_CMD"
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

    ; 1. 尝试从配置读取 (唯一真相 + Config 兜底, 见 TC_EffPath)
    tcPath := TC_EffPath()
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
