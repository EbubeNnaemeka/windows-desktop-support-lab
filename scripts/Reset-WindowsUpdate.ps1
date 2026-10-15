<#
.SYNOPSIS
    Repairs Windows Update when installs keep failing or rolling back.

.DESCRIPTION
    The standard escalation path for update errors such as 0x80070002 and 0x800f0922:
      1. Stop the Windows Update, BITS, Cryptographic and Installer services.
      2. Rename the SoftwareDistribution and catroot2 caches (kept as .bak, not deleted).
      3. Start the services again.
      4. With -RepairImage, run DISM /RestoreHealth then SFC /scannow (can take 15-30 minutes).
    Requires administrator. Supports -WhatIf. Works in Windows PowerShell 5.1 and PowerShell 7.

.EXAMPLE
    .\Reset-WindowsUpdate.ps1 -WhatIf
.EXAMPLE
    .\Reset-WindowsUpdate.ps1 -RepairImage
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch] $RepairImage
)

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this from an elevated PowerShell window (Run as administrator).'
}

$services = 'wuauserv', 'bits', 'cryptsvc', 'msiserver'
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$caches = @("$env:windir\SoftwareDistribution", "$env:windir\System32\catroot2")

if ($PSCmdlet.ShouldProcess(($services -join ', '), 'Stop services')) {
    foreach ($s in $services) { Stop-Service -Name $s -Force -ErrorAction SilentlyContinue }
}

foreach ($c in $caches) {
    if ((Test-Path $c) -and $PSCmdlet.ShouldProcess($c, "Rename to $(Split-Path $c -Leaf).$stamp.bak")) {
        Rename-Item -Path $c -NewName "$(Split-Path $c -Leaf).$stamp.bak"
        Write-Host "Renamed $c" -ForegroundColor Green
    }
}

if ($PSCmdlet.ShouldProcess(($services -join ', '), 'Start services')) {
    foreach ($s in $services) { Start-Service -Name $s -ErrorAction SilentlyContinue }
    Get-Service -Name $services | Select-Object Name, Status | Format-Table -AutoSize
}

if ($RepairImage -and $PSCmdlet.ShouldProcess('Windows image', 'DISM /RestoreHealth and SFC /scannow')) {
    Write-Host 'Running DISM (this can take a while)...' -ForegroundColor Cyan
    & dism.exe /Online /Cleanup-Image /RestoreHealth
    Write-Host 'Running SFC...' -ForegroundColor Cyan
    & sfc.exe /scannow
}

Write-Host 'Done. Restart the PC, then Settings > Windows Update > Check for updates.' -ForegroundColor Cyan
Write-Host "If it still fails, note the error code and check $env:windir\Logs\CBS\CBS.log before escalating."
