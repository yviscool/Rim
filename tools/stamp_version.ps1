# Rim 版本烫印: tag 是唯一真源, 只改构建工作区, 永不回写仓库
# 用法: .\stamp_version.ps1 -Version "1.4.0" -Sha "a07917d" -Date "20250101"
#       .\stamp_version.ps1 -Version "0.9.0-dev.20250101.a07917d" -Sha "a07917d" -Date "20250101"
param(
    [Parameter(Mandatory = $true)][string]$Version,
    [Parameter(Mandatory = $true)][string]$Sha,
    [Parameter(Mandatory = $true)][string]$Date
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

# 1. Rim.ahk 构建号 (关于页/报错日志 BUILD 行同源)
$entry = Join-Path $root "Rim.ahk"
$text = Get-Content $entry -Raw -Encoding UTF8
$buildTag = "$Version+$Sha.$Date"
$newText = $text -replace 'global g_BuildTag := "[^"]*"', "global g_BuildTag := `"$buildTag`""
if ($newText -eq $text) {
    throw "stamp failed: g_BuildTag pattern not found in Rim.ahk"
}
# 无 BOM 写回 (与仓库既有编码一致)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($entry, $newText, $utf8NoBom)
Write-Host "stamped g_BuildTag=$buildTag"

# 2. Conf/VERSION (包内版本凭证, 无 BOM, 与仓库既有编码一致)
$verFile = Join-Path $root "Conf\VERSION"
$utf8NoBom2 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($verFile, "RIM_VERSION=$Version`nRIM_SHA=$Sha`nRIM_DATE=$Date`n", $utf8NoBom2)
Write-Host "wrote Conf/VERSION"
