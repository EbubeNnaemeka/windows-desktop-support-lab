# Runbook: Temporary profile, missing mapped drive

## "Windows says I'm signed in with a temporary profile" (T19)

1. **Don't let the user save work** in the temporary profile; it's deleted at sign-out.
2. Event Viewer > Application: User Profile Service events **1511/1515** confirm it.
3. As admin, open `regedit` > `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList`. Find the user's SID; if there are two keys (one ending in `.bak`), the profile reference is broken.
4. Back up the registry key, then fix the duplicate (remove the one without `.bak`, rename the `.bak` one, set `State` to 0 and `RefCount` to 0), restart, sign the user in.
5. If the profile itself is corrupt: copy the user's data out of `C:\Users\<name>`, delete the profile through System Properties > User Profiles, sign in fresh, copy the data back. **Confirm the backup before deleting anything.**

## "My shared drive disappeared" (T05)

1. Is it just this user? Check group membership: `Get-ADPrincipalGroupMembership <user> | Select-Object Name`.
2. On their PC: `gpresult /r` shows whether the drive-map GPO applied; `gpupdate /force` and sign out/in.
3. Check the GPO's item-level targeting group and the share permissions (`Get-SmbShareAccess` on the file server).
4. Can they browse to `\\server\share` directly? If yes, it's the mapping; if no, it's permissions or the server.
