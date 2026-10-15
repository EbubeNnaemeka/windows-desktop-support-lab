# Runbook: Printer not printing

**Tickets:** T06, T23 · **Script:** `Reset-PrintSpooler.ps1`

1. **One person or everyone on that printer?**
   - Everyone: problem is the printer or print server. Check the printer's own panel (paper, toner, error), then the queue on the print server (`\\DC01`), and restart the spooler **on the server**.
   - One person: problem is their PC.
2. On the PC: does **Microsoft Print to PDF** work?
   - No: the local spooler is stuck. Run `.\Reset-PrintSpooler.ps1` as administrator.
   - Yes: the problem is that one printer: remove and re-add it, or `gpupdate /force` if it's deployed by GPO, and check `gpresult /r` shows the printer GPO.
3. Print a test page and confirm with the user.
4. If the spooler keeps crashing, check Event Viewer for PrintService errors (often a bad driver) and escalate with the event IDs.
