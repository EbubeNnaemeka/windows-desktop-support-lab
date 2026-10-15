# Runbook: Windows updates keep failing

**Tickets:** T12 · **Script:** `Reset-WindowsUpdate.ps1`

1. Note the **error code** (Settings > Windows Update > Update history). Search it: e.g. `0x80070002` = files missing, `0x800f0922` = not enough space in the system reserved partition or no connection to the update service.
2. Check basics: at least 20 GB free, restart pending (restart first), date and time correct.
3. Run `.\Reset-WindowsUpdate.ps1 -WhatIf` to preview, then `.\Reset-WindowsUpdate.ps1 -RepairImage` as administrator.
4. Restart and check for updates again.
5. Still failing: collect `C:\Windows\Logs\CBS\CBS.log` and the output of `Get-WindowsUpdateLog`, and escalate with the error code and what you've tried.
