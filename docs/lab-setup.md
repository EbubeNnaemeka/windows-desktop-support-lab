# Lab setup

## Machines

| VM | OS | Role |
|---|---|---|
| DC01 | Windows Server 2022 | Domain controller from the [Active Directory lab](https://github.com/EbubeNnaemeka/active-directory-lab) (`corp.lab`), also the print server |
| WIN11-01 | Windows 11 Enterprise (evaluation) | The "user's" desktop: domain-joined, where tickets are reproduced and fixed |
| WIN11-02 | Windows 11 Enterprise (evaluation) | Second desktop, used as the remote-support target and for reference-image testing |

On Apple Silicon use the ARM64 builds of Windows 11 in UTM or Parallels; on x86 use Hyper-V or VirtualBox. Take a **clean snapshot** of each Windows 11 VM after joining the domain, so every scenario starts from a known state.

## 1. Join the desktops to the domain

```powershell
# On WIN11-01, as a local admin, with DNS pointing at DC01
Add-Computer -DomainName corp.lab -OUPath 'OU=Workstations,DC=corp,DC=lab' -Credential (Get-Credential CORP\Administrator) -Restart
```

## 2. Deploy a printer with Group Policy

1. On DC01: `Install-WindowsFeature Print-Services -IncludeManagementTools`, add a printer (a "Microsoft Print to PDF"-based or Generic / Text Only printer on a local port is enough for the lab) and share it as `\\DC01\Floor3-Printer`.
2. Group Policy Management > new GPO `WS - Printers - Floor 3`, linked to the Workstations OU.
3. User Configuration > Preferences > Control Panel Settings > Printers > New > Shared Printer: action **Update**, path `\\DC01\Floor3-Printer`, set as default. Use **item-level targeting** on the security group `Floor3 Staff` so only that group gets it.
4. On WIN11-01: `gpupdate /force`, sign out and in, confirm the printer appears. `gpresult /r` shows the GPO under "Applied Group Policy Objects".

## 3. Build a reference image

1. Install Windows 11 on WIN11-02, apply updates, install the standard apps (browser, PDF reader, Microsoft 365 Apps).
2. Snapshot it, then generalize: `C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown`.
3. Clone the VM (or capture with `dism /Capture-Image` on x86) to create new "laptops" from the image; time how long a new machine takes from power-on to ready.
4. On x86 hardware, the same reference image can be deployed over the network with WDS/MDT; in the cloud, Windows Autopilot does this job ([m365-intune-lab](https://github.com/EbubeNnaemeka/m365-intune-lab)).

## 4. Remote support

| Tool | Use | Setup |
|---|---|---|
| Quick Assist | Help a user who is at their desk, with their consent | Built into Windows 11 (Start > Quick Assist); the technician signs in and gives the user a code |
| Remote Desktop (RDP) | Admin access to a machine nobody is using | Allow via GPO: Computer Configuration > Policies > Administrative Templates > Windows Components > Remote Desktop Services > Allow users to connect remotely; restrict to the `Helpdesk` group, require Network Level Authentication |

Always tell the user before connecting, and never view personal files without asking.

## 5. Copy the scripts

Copy `scripts\` to `C:\HelpdeskTools` on each desktop. If scripts are blocked, run `Unblock-File C:\HelpdeskTools\*.ps1` and use an execution policy of `RemoteSigned`.
