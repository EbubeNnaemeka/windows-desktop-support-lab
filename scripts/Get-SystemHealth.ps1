<#
.SYNOPSIS
    First-look health check for a "my PC is slow / acting up" ticket.

.DESCRIPTION
    Collects the facts a technician checks first and flags anything outside normal:
    uptime and pending reboot, free disk space, memory pressure, top processes, last
    successful Windows Update, BitLocker and Defender status, and recent critical/error
    events. Read-only: changes nothing. Works in Windows PowerShell 5.1 and PowerShell 7.

.PARAMETER ReportPath
    Optional path for an HTML copy of the report to attach to the ticket.

.EXAMPLE
    .\Get-SystemHealth.ps1
.EXAMPLE
    .\Get-SystemHealth.ps1 -ReportPath "$env:USERPROFILE\Desktop\health.html"
#>
[CmdletBinding()]
param(
    [string] $ReportPath
)

$findings = New-Object System.Collections.Generic.List[string]
function Flag([string] $Message) { $findings.Add($Message) }

$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem

# Uptime and pending reboot
$uptime = (Get-Date) - $os.LastBootUpTime
if ($uptime.TotalDays -gt 7) { Flag "Not restarted for $([int]$uptime.TotalDays) days. Restart first." }

$rebootKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
)
$pendingReboot = [bool]($rebootKeys | Where-Object { Test-Path $_ })
if ($pendingReboot) { Flag 'A restart is pending to finish updates.' }

# Disk
$disks = Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
    $pct = if ($_.Size) { [math]::Round($_.FreeSpace / $_.Size * 100, 1) } else { 0 }
    if ($pct -lt 10) { Flag "Drive $($_.DeviceID) has only $pct% free. See Clear-DiskSpace.ps1." }
    [pscustomobject]@{ Drive = $_.DeviceID; SizeGB = [math]::Round($_.Size / 1GB, 1); FreeGB = [math]::Round($_.FreeSpace / 1GB, 1); FreePct = $pct }
}

# Memory
$memUsedPct = [math]::Round((1 - $os.FreePhysicalMemory / $os.TotalVisibleMemorySize) * 100, 1)
if ($memUsedPct -gt 90) { Flag "Memory is $memUsedPct% used. Check the top processes below." }

$topCpu = Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 Name, Id,
    @{ n = 'CPUSeconds'; e = { [math]::Round($_.CPU, 0) } }
$topMem = Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 5 Name, Id,
    @{ n = 'MemoryMB'; e = { [math]::Round($_.WorkingSet64 / 1MB, 0) } }

# Startup programs
$startup = Get-CimInstance Win32_StartupCommand | Select-Object Name, Location
if (@($startup).Count -gt 15) { Flag "$(@($startup).Count) startup programs. Disable the ones the user doesn't need." }

# Windows Update: most recent installed hotfix
$lastPatch = Get-HotFix | Where-Object InstalledOn | Sort-Object InstalledOn -Descending | Select-Object -First 1
if ($lastPatch -and ((Get-Date) - $lastPatch.InstalledOn).TotalDays -gt 45) {
    Flag "Last update installed $($lastPatch.InstalledOn.ToShortDateString()). Updates may be failing (see runbooks/windows-update-failing.md)."
}

# BitLocker (needs admin; skipped quietly if not available)
$bitlocker = try {
    (Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop).ProtectionStatus
} catch { 'Unknown (run as administrator)' }
if ("$bitlocker" -eq 'Off') { Flag 'BitLocker is off on the system drive.' }

# Defender
$defender = try { Get-MpComputerStatus -ErrorAction Stop } catch { $null }
if ($defender) {
    if (-not $defender.RealTimeProtectionEnabled) { Flag 'Microsoft Defender real-time protection is OFF.' }
    if ($defender.AntivirusSignatureAge -gt 3) { Flag "Defender signatures are $($defender.AntivirusSignatureAge) days old." }
}

# Recent critical and error events (last 24 hours)
$events = Get-WinEvent -FilterHashtable @{ LogName = 'System', 'Application'; Level = 1, 2; StartTime = (Get-Date).AddDays(-1) } -MaxEvents 200 -ErrorAction SilentlyContinue
$eventSummary = $events | Group-Object ProviderName, Id | Sort-Object Count -Descending | Select-Object -First 10 Count,
    @{ n = 'Source'; e = { $_.Group[0].ProviderName } }, @{ n = 'EventId'; e = { $_.Group[0].Id } },
    @{ n = 'Message'; e = { ($_.Group[0].Message -split "`n")[0] } }

$summary = [pscustomobject]@{
    Computer        = $env:COMPUTERNAME
    User            = "$env:USERDOMAIN\$env:USERNAME"
    OS              = "$($os.Caption) $($os.Version)"
    Model           = "$($cs.Manufacturer) $($cs.Model)"
    UptimeDays      = [math]::Round($uptime.TotalDays, 1)
    PendingReboot   = $pendingReboot
    MemoryUsedPct   = $memUsedPct
    LastUpdate      = if ($lastPatch) { $lastPatch.InstalledOn.ToShortDateString() } else { 'Unknown' }
    BitLocker       = "$bitlocker"
    DefenderRealTime = if ($defender) { $defender.RealTimeProtectionEnabled } else { 'Unknown' }
}

Write-Host "`n=== Findings ===" -ForegroundColor Cyan
if ($findings.Count) { $findings | ForEach-Object { Write-Host " ! $_" -ForegroundColor Yellow } }
else { Write-Host ' No problems found in the basic checks.' -ForegroundColor Green }

$summary | Format-List
$disks | Format-Table -AutoSize
Write-Host 'Top CPU' -ForegroundColor Cyan;     $topCpu | Format-Table -AutoSize
Write-Host 'Top memory' -ForegroundColor Cyan;  $topMem | Format-Table -AutoSize
Write-Host 'Errors in the last 24h' -ForegroundColor Cyan; $eventSummary | Format-Table -AutoSize -Wrap

if ($ReportPath) {
    $html = @(
        "<h1>Health report: $env:COMPUTERNAME</h1><p>Generated $(Get-Date)</p>",
        '<h2>Findings</h2><ul>' + (($findings | ForEach-Object { "<li>$([System.Net.WebUtility]::HtmlEncode($_))</li>" }) -join '') + '</ul>',
        ($summary | ConvertTo-Html -Fragment -As List),
        '<h2>Disks</h2>' + ($disks | ConvertTo-Html -Fragment),
        '<h2>Top CPU</h2>' + ($topCpu | ConvertTo-Html -Fragment),
        '<h2>Top memory</h2>' + ($topMem | ConvertTo-Html -Fragment),
        '<h2>Errors (24h)</h2>' + ($eventSummary | ConvertTo-Html -Fragment)
    ) -join "`n"
    ConvertTo-Html -Body $html -Title "Health $env:COMPUTERNAME" | Set-Content -Path $ReportPath -Encoding UTF8
    Write-Host "Report saved to $ReportPath"
}
