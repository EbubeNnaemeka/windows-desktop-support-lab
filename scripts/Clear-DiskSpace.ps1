<#
.SYNOPSIS
    Frees disk space from safe-to-delete locations. Reports only, unless -Apply is given.

.DESCRIPTION
    Only touches caches and temporary files Windows recreates on its own. Never touches
    Documents, Desktop, Downloads or other user data; for those, show the user the
    "largest folders" list and let them decide.

    Locations: user and Windows temp folders, Windows Update download cache, Delivery
    Optimization cache and Windows Error Reporting files. The Recycle Bin is only emptied
    with -IncludeRecycleBin, after asking the user (people do keep things there).
    Run as administrator to clean system locations. Works in PowerShell 5.1 and 7.

.EXAMPLE
    .\Clear-DiskSpace.ps1            # report what could be freed
.EXAMPLE
    .\Clear-DiskSpace.ps1 -Apply     # actually delete
.EXAMPLE
    .\Clear-DiskSpace.ps1 -Apply -IncludeRecycleBin
#>
[CmdletBinding()]
param(
    [switch] $Apply,
    [switch] $IncludeRecycleBin,
    [int] $OlderThanDays = 2
)

$cutoff = (Get-Date).AddDays(-$OlderThanDays)
$targets = @(
    @{ Name = 'User temp';                  Path = $env:TEMP },
    @{ Name = 'Windows temp';               Path = "$env:windir\Temp" },
    @{ Name = 'Windows Update downloads';   Path = "$env:windir\SoftwareDistribution\Download" },
    @{ Name = 'Delivery Optimization cache'; Path = "$env:windir\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache" },
    @{ Name = 'Error reports';              Path = "$env:ProgramData\Microsoft\Windows\WER\ReportArchive" }
)

$freeBefore = (Get-PSDrive -Name $env:SystemDrive.TrimEnd(':')).Free
$rows = foreach ($t in $targets) {
    if (-not (Test-Path $t.Path)) { continue }
    # Skip files in use and anything newer than the cutoff (an install may be using it).
    $files = Get-ChildItem -Path $t.Path -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff }
    $bytes = ($files | Measure-Object Length -Sum).Sum
    if ($Apply) {
        $files | Remove-Item -Force -ErrorAction SilentlyContinue
    }
    [pscustomobject]@{ Location = $t.Name; Files = @($files).Count; SizeMB = [math]::Round($bytes / 1MB, 1) }
}

if ($Apply -and $IncludeRecycleBin) { Clear-RecycleBin -Force -ErrorAction SilentlyContinue }

$rows | Format-Table -AutoSize
if ($Apply) {
    $freed = ((Get-PSDrive -Name $env:SystemDrive.TrimEnd(':')).Free - $freeBefore) / 1MB
    $note = if ($IncludeRecycleBin) { ' (Recycle Bin emptied)' } else { '' }
    Write-Host ("Freed {0:N0} MB{1}." -f $freed, $note) -ForegroundColor Green
} else {
    Write-Host ("Could free about {0:N0} MB. Re-run with -Apply to delete (add -IncludeRecycleBin if the user agrees)." -f ($rows | Measure-Object SizeMB -Sum).Sum) -ForegroundColor Cyan
}

# Largest folders in the user's profile, for a conversation with the user (nothing deleted).
Write-Host "`nLargest folders in $env:USERPROFILE (review with the user):" -ForegroundColor Cyan
Get-ChildItem $env:USERPROFILE -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
    $size = (Get-ChildItem $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    [pscustomobject]@{ Folder = $_.Name; SizeGB = [math]::Round($size / 1GB, 2) }
} | Sort-Object SizeGB -Descending | Select-Object -First 8 | Format-Table -AutoSize
