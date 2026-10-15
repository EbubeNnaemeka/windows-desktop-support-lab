# Runbook: "Disk is full / can't save files"

**Tickets:** T11 · **Script:** `Clear-DiskSpace.ps1`

1. Run `.\Clear-DiskSpace.ps1` (report only) to see what can be safely removed.
2. Run `.\Clear-DiskSpace.ps1 -Apply` as administrator. Ask before adding `-IncludeRecycleBin`.
3. Review the "largest folders" list **with the user**. Common culprits: Downloads, old Outlook data files (`.ost` for removed accounts), video files. Suggest moving personal files to OneDrive or the user's network drive. **Never delete user files yourself.**
4. Turn on Storage Sense (Settings > System > Storage) so temp files clean themselves.
5. Record space freed in the ticket. Escalate for a larger disk if under 15% free after cleanup.
