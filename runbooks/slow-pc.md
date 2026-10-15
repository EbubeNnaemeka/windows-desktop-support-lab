# Runbook: "My computer is slow"

**Tickets:** T08 · **Script:** `Get-SystemHealth.ps1`

1. Ask: since when, all apps or one, any recent change (new software, update, moved desks)?
2. Run `.\Get-SystemHealth.ps1 -ReportPath $env:TEMP\health.html` and attach the report to the ticket.
3. Work through the findings in this order (cheapest fix first):
   - **Uptime over 7 days or pending reboot:** restart, then re-test.
   - **Disk under 10% free:** follow [disk-full.md](disk-full.md).
   - **Memory over 90%:** check top processes. One browser with 60 tabs is a user conversation, not a fault.
   - **High CPU from one process:** look it up (Defender scan, Windows Update, indexing are normal and temporary).
   - **15+ startup programs:** Task Manager > Startup apps, disable the ones the user agrees they don't need.
   - **Repeated errors in the event summary:** search the event ID and source.
4. Confirm with the user that it's better, and close with what you changed.
5. **Escalate** if hardware is suspected (disk errors in the System log, SMART warnings, overheating) with the report attached.
