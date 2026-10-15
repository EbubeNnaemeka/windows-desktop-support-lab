<#
.SYNOPSIS
    Fixes stuck print queues: stops the spooler, clears stuck jobs, starts it again.

.DESCRIPTION
    The fix for "nothing prints, even Print to PDF" and "jobs sit in the queue". Lists the
    jobs that will be removed, clears the spool folder, restarts the Print Spooler service
    and shows the printers afterwards. Requires administrator. Supports -WhatIf.
    Works in Windows PowerShell 5.1 and PowerShell 7.

.EXAMPLE
    .\Reset-PrintSpooler.ps1 -WhatIf
.EXAMPLE
    .\Reset-PrintSpooler.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param()

$spoolDir = Join-Path $env:windir 'System32\spool\PRINTERS'

$jobs = Get-Printer -ErrorAction SilentlyContinue | ForEach-Object { Get-PrintJob -PrinterName $_.Name -ErrorAction SilentlyContinue }
if ($jobs) {
    Write-Host 'Jobs that will be cleared:' -ForegroundColor Cyan
    $jobs | Select-Object PrinterName, DocumentName, UserName, JobStatus, SubmittedTime | Format-Table -AutoSize
}

if ($PSCmdlet.ShouldProcess('Print Spooler', 'Stop, clear stuck jobs and restart')) {
    Stop-Service -Name Spooler -Force
    Get-ChildItem -Path $spoolDir -File -ErrorAction SilentlyContinue | Remove-Item -Force
    Start-Service -Name Spooler

    $svc = Get-Service -Name Spooler
    Write-Host "Spooler is $($svc.Status)." -ForegroundColor $(if ($svc.Status -eq 'Running') { 'Green' } else { 'Red' })
    if ($svc.Status -ne 'Running') {
        Write-Host 'Spooler did not start. Check Event Viewer > Windows Logs > System for source "Service Control Manager" or "PrintService".'
    }
    Get-Printer | Select-Object Name, PrinterStatus, PortName, Shared | Format-Table -AutoSize
}
