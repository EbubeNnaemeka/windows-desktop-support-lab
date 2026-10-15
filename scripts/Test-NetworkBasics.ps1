<#
.SYNOPSIS
    Bottom-up network check for "no internet" tickets, with a plain-English verdict.

.DESCRIPTION
    Runs the same checks a technician does by hand, in order, and stops at the first layer
    that fails: adapter up -> valid IP (not APIPA) -> gateway reachable -> DNS resolves ->
    HTTPS to the internet. Read-only. Works in Windows PowerShell 5.1 and PowerShell 7.

.EXAMPLE
    .\Test-NetworkBasics.ps1
.EXAMPLE
    .\Test-NetworkBasics.ps1 -TestHost www.microsoft.com
#>
[CmdletBinding()]
param(
    [string] $TestHost = 'www.microsoft.com'
)

function Result([string] $Check, [bool] $Ok, [string] $Detail) {
    [pscustomobject]@{ Check = $Check; Result = $(if ($Ok) { 'PASS' } else { 'FAIL' }); Detail = $Detail }
}

$results = New-Object System.Collections.Generic.List[object]
$verdict = $null

# 1. Adapter
$adapter = Get-NetAdapter -Physical | Where-Object Status -EQ 'Up' | Select-Object -First 1
$results.Add((Result 'Network adapter up' ([bool]$adapter) $(if ($adapter) { "$($adapter.Name) ($($adapter.InterfaceDescription), $($adapter.LinkSpeed))" } else { 'No physical adapter is connected' })))
if (-not $adapter) { $verdict = 'No connected adapter: check the cable or Wi-Fi switch, or that the adapter is enabled in Device Manager.' }

# 2. IP address
if (-not $verdict) {
    $ipConfig = Get-NetIPConfiguration -InterfaceIndex $adapter.ifIndex
    $ip = $ipConfig.IPv4Address.IPAddress | Select-Object -First 1
    $apipa = $ip -like '169.254.*'
    $results.Add((Result 'Valid IPv4 address' ($ip -and -not $apipa) "IP $ip"))
    if (-not $ip -or $apipa) { $verdict = 'No address from DHCP (169.254.x.x). Check the switch port/VLAN, then whether the DHCP server is answering. Try: ipconfig /release; ipconfig /renew' }
}

# 3. Gateway
if (-not $verdict) {
    $gateway = $ipConfig.IPv4DefaultGateway.NextHop | Select-Object -First 1
    $gwOk = $gateway -and (Test-Connection -ComputerName $gateway -Count 2 -Quiet)
    $results.Add((Result 'Default gateway reachable' ([bool]$gwOk) "Gateway $gateway"))
    if (-not $gwOk) { $verdict = "Can't reach the gateway ($gateway). Local network problem: port, VLAN or gateway device." }
}

# 4. DNS
if (-not $verdict) {
    $dnsServers = ($ipConfig.DNSServer | Where-Object AddressFamily -EQ 2).ServerAddresses -join ', '
    $resolved = try { Resolve-DnsName -Name $TestHost -Type A -ErrorAction Stop | Where-Object IPAddress | Select-Object -First 1 } catch { $null }
    $results.Add((Result 'DNS resolves names' ([bool]$resolved) "DNS servers $dnsServers; $TestHost -> $($resolved.IPAddress)"))
    if (-not $resolved) { $verdict = "Network works but names don't resolve. DNS problem: check DNS servers ($dnsServers). Try: ipconfig /flushdns" }
}

# 5. Internet over HTTPS
if (-not $verdict) {
    $https = Test-NetConnection -ComputerName $TestHost -Port 443 -WarningAction SilentlyContinue
    $results.Add((Result 'HTTPS to the internet' $https.TcpTestSucceeded "$TestHost`:443"))
    if (-not $https.TcpTestSucceeded) { $verdict = 'DNS works but HTTPS is blocked: firewall, proxy or VPN policy. Check whether other users are affected.' }
}

if (-not $verdict) { $verdict = 'All basic checks passed. If one site or app still fails, the problem is with that service, not this PC''s connection.' }

$results | Format-Table -AutoSize -Wrap
Write-Host "Verdict: $verdict" -ForegroundColor Cyan
