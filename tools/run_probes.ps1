#Requires -Version 5.1
<#
.SYNOPSIS
  Rim 探针运行器: 自动枚举 tools/probe_*.ahk, 逐个 30s 超时执行, 独立临时目录, 汇总退出码/stdout/stderr.
  失败时保留现场文件.
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_probes.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_probes.ps1 -Filter "action_protocol,hist_replay"
#>
param(
    [string]$Filter = "",
    [int]$TimeoutSec = 30,
    [string]$Ahk = "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$toolsDir = Join-Path $root "tools"
$reportDir = Join-Path $root ("probe_report_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
New-Item -ItemType Directory -Path $reportDir | Out-Null

$probes = Get-ChildItem -Path $toolsDir -Filter "probe_*.ahk" | Sort-Object Name
if ($Filter -ne "") {
    $keys = $Filter -split ","
    $probes = $probes | Where-Object {
        $n = $_.Name
        foreach ($k in $keys) { if ($n -like "*$($k.Trim())*") { return $true } }
        return $false
    }
}

$pass = 0; $fail = 0; $timeout = 0
$rows = @()

foreach ($p in $probes) {
    $name = $p.BaseName
    $workDir = Join-Path ([System.IO.Path]::GetTempPath()) ("rim_probe_" + $name + "_" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8))
    New-Item -ItemType Directory -Path $workDir | Out-Null
    $outFile = Join-Path $reportDir ($name + ".stdout.txt")
    $errFile = Join-Path $reportDir ($name + ".stderr.txt")

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Ahk
    $psi.Arguments = "/ErrorStdOut `"$($p.FullName)`""
    $psi.WorkingDirectory = $root
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    # 独立临时目录: 探针经 TMP/TEMP 落盘现场文件时互不干扰
    $psi.EnvironmentVariables["TMP"] = $workDir
    $psi.EnvironmentVariables["TEMP"] = $workDir
    $psi.EnvironmentVariables["MSYS_NO_PATHCONV"] = "1"

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    try {
        [void]$proc.Start()
        $exited = $proc.WaitForExit($TimeoutSec * 1000)
        if (-not $exited) {
            try { $proc.Kill() } catch {}
            $timeout++
            $status = "TIMEOUT"
            "[TIMEOUT after ${TimeoutSec}s] $name" | Out-File -FilePath $outFile -Encoding utf8
            "" | Out-File -FilePath $errFile -Encoding utf8
        } else {
            $stdout = $proc.StandardOutput.ReadToEnd()
            $stderr = $proc.StandardError.ReadToEnd()
            $stdout | Out-File -FilePath $outFile -Encoding utf8
            $stderr | Out-File -FilePath $errFile -Encoding utf8
            if ($proc.ExitCode -eq 0) { $pass++; $status = "PASS" } else { $fail++; $status = "FAIL(exit=$($proc.ExitCode))" }
        }
    } catch {
        $fail++
        $status = "ERROR: $($_.Exception.Message)"
        $status | Out-File -FilePath $outFile -Encoding utf8
    } finally {
        # 成功且通过则清理临时目录; 失败/超时保留现场
        if ($status -eq "PASS") {
            Remove-Item -Recurse -Force $workDir -ErrorAction SilentlyContinue
        }
    }
    $rows += [pscustomobject]@{ Probe = $name; Status = $status }
    Write-Output ("[{0}] {1}" -f $status, $name)
}

$summary = Join-Path $reportDir "_summary.txt"
$total = $pass + $fail + $timeout
$lines = @()
$lines += "probes: $total  pass: $pass  fail: $fail  timeout: $timeout"
$lines += ""
foreach ($r in $rows) { $lines += ("[{0}] {1}" -f $r.Status, $r.Probe) }
$lines | Out-File -FilePath $summary -Encoding utf8
Write-Output "----"
Write-Output ($lines -join "`n")
Write-Output ("report: $reportDir")

if (($fail -gt 0) -or ($timeout -gt 0)) { exit 1 }
exit 0
