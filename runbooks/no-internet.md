# Runbook: "No internet"

**Tickets:** T09, T10, T17 · **Script:** `Test-NetworkBasics.ps1`

1. **One user or many?** If several people report it, it's a network incident: raise priority, tell the team, check the network side ([cisco-network-lab](https://github.com/EbubeNnaemeka/cisco-network-lab) scenarios).
2. Run `.\Test-NetworkBasics.ps1`. It stops at the first failing layer and says what it means:

| Fails at | Meaning | Next step |
|---|---|---|
| Adapter | Cable unplugged, Wi-Fi off, adapter disabled | Check physically; Device Manager |
| IP (169.254.x.x) | No DHCP reply | `ipconfig /release` / `/renew`; check switch port VLAN; is DHCP up for others? |
| Gateway | Local network fault | Port, VLAN, switch or router; escalate to network team |
| DNS | Names don't resolve | `ipconfig /flushdns`; check DNS servers in `ipconfig /all`; is DNS up for others? |
| HTTPS | Firewall/proxy/VPN | Is the site blocked by policy (T24)? VPN connected? |

3. Record the failing layer and fix in the ticket.
