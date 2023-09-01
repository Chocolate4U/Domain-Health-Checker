#Requires -Version 7

<#
.SYNOPSIS
Check Domains Health
.DESCRIPTION
Checks a list of domains to see if they are available or not.
.EXAMPLE
.\Check-domains.ps1 -Mode TCP -Port 80 -Timeout 5 -Concurrency 20
.EXAMPLE
.\Check-domains.ps1 -Mode DNS -DNSServer 1.1.1.1 -Concurrency 10 -File otherdomains.txt
.EXAMPLE
.\Check-domains.ps1 -Mode DOH -DOHServer Cloudflare -Concurrency 10
.EXAMPLE
.\Check-domains.ps1 -Mode ICMP -Timeout 10 -Concurrency 5 -File "D:\domainlist\domains.txt"
.NOTES
This script is published under MIT license.
.LINK 
https://github.com/Chocolate4U/Domain-Health-Checker
.PARAMETER Mode
Specifies the working mode of script. Available options: TCP, DNS, DOH, ICMP
.PARAMETER Port
Specifies the port for TCP mode.
.PARAMETER DNSServer
Specifies the DNS Server for DNS mode. Only IPv4 is allowed.
.PARAMETER DOHServer
Specifies the DNS over HTTPS Server for DOH mode. Available options: Cloudflare, Google, Quad9
.PARAMETER Timeout
Specifies the timeout for each check. Only available in TCP and ICMP modes.
.PARAMETER Concurrency
Specifies how many Domains to get processed at the same time. Available in all modes.
.PARAMETER File
Specifies the path to the file which contains domain addresses. If not set, the script searches for domains.txt in current directory.
#>
[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter()]
    [ValidateSet('TCP', 'DNS', 'DOH', 'ICMP', ErrorMessage = "Mode '{0}' is invalid, It can only be one of: '{1}'")]
    [string]$Mode,

    [Parameter()]
    [ValidateSet(80, 443, ErrorMessage = "Port '{0}' is invalid, It can only be one of: '{1}'")]
    [int]$Port,

    [Parameter()]
    [ValidatePattern("^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$", ErrorMessage = "DNSServer '{0}' is invalid, It can only be a valid IPv4 Address.")]
    [string]$DNSServer,

    [Parameter()]
    [ValidateSet('Cloudflare', 'Google', 'Quad9', ErrorMessage = "DOHServer '{0}' is invalid, It can only be one of: '{1}'")]
    [string]$DOHServer,

    [Parameter()]
    [ValidateRange(1, 3600)]
    [int]$Timeout,

    [Parameter()]
    [ValidateRange(1, 10000)]
    [int]$Concurrency,

    [Parameter()]
    [string]$File
)
function Get-Mode {
    Write-Host ">> This Script will check Domains in a text file for availability." -ForegroundColor Cyan
    Write-Host ">> By default it searches for <domains.txt> in the current directory." -ForegroundColor Cyan
    Write-Host ">> For each prompt just press <Enter> to use default values." -ForegroundColor Cyan
    Write-Host ">> For help and documentation on CLI usage, please run 'Get-Help .\Check-domains.ps1'" -ForegroundColor Cyan
    Write-Host ">> IT can work in the following modes:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1.TCP [Makes a TCP connection to target Website's Webserver and checks for a response]" -ForegroundColor Green
    Write-Host "2.DNS [Check if target Website has a valid DNS record]" -ForegroundColor Green
    Write-Host "3.DOH [Check if target Website has a valid DNS record using DNS over HTTPS API]" -ForegroundColor Green
    Write-Host "4.ICMP [Send Ping requests to target Website's Webserver and checks for a response]" -ForegroundColor Green
    Write-Host ""
    $ModeInput = Read-Host ">> Please Enter operating Mode name or number: 1[TCP], 2[DNS], 3[DOH], 4[ICMP] [Default: TCP]"
    if (([string]$null -eq $ModeInput) -or ("1" -eq $ModeInput) -or ("TCP" -eq $ModeInput)) {
        $Mode = "1"
        Write-Host ">> Mode: TCP" -ForegroundColor Green
    }
    elseif ("2" -eq $ModeInput -or ("DNS" -eq $ModeInput)) {
        $Mode = "2"
        Write-Host ">> Mode: DNS" -ForegroundColor Green
    }
    elseif ("3" -eq $ModeInput -or ("DOH" -eq $ModeInput)) {
        $Mode = "3"
        Write-Host ">> Mode: DOH" -ForegroundColor Green
    }
    elseif ("4" -eq $ModeInput -or ("ICMP" -eq $ModeInput)) {
        $Mode = "4"
        Write-Host ">> Mode: ICMP" -ForegroundColor Green
    }
    else {
        Write-Host $ModeInput "!! is invalid, Please choose a valid option" -ForegroundColor Red
        Get-Mode
    }
    $Mode
}
function Get-Port {
    Write-Host ">> Please select the port to connect to target website: [Default: 80]"
    Write-Host "[1] 80" -ForegroundColor Green
    Write-Host "[2] 443" -ForegroundColor Green
    $PortInput = Read-Host "Please Enter"
    if (([string]$null -eq $PortInput) -or ("1" -eq $PortInput) -or ("80" -eq $PortInput)) {
        [int]$Port = 80
        Write-Host "80[HTTP]" -ForegroundColor Green
    }
    elseif (("2" -eq $PortInput) -or ("443" -eq $PortInput)) {
        [int]$Port = 443
        Write-Host "443[HTTPS]" -ForegroundColor Green
    }
    else {
        Write-Host $PortInput "!! is invalid, Please try again" -ForegroundColor Red
        Get-Port
    }
    $Port
}
function Get-Timeout {
    $TimeoutInput = Read-Host "Please Enter Timeout for each request in seconds: [Default: 5s]"
    if ([string]$null -eq $TimeoutInput) {
        [int]$Timeout = 5
    }
    else {
        try {
            $Timeout = [int]$TimeoutInput
        }
        catch {
            Write-Host $TimeoutInput "!! is invalid, Please input a number in seconds" -ForegroundColor Red
            Get-Timeout
        }
    }
    $Timeout
}
function Get-Concurrency {
    $InputConcurrency = Read-Host "How many domains do you want to process in parallel? [Default: 10]"
    if ([string]$null -eq $InputConcurrency) {
        [int]$Concurrency = 10
    }
    else {
        try {
            $Concurrency = [int]$InputConcurrency
        }
        catch {
            Write-Host $InputConcurrency "!! is invalid, Please input a number" -ForegroundColor Red
            Concurrency
        }
    }
    $Concurrency
}
function Test-Connectivity {
    Write-Host "* Checking Internet connectivity..." -ForegroundColor Cyan
    if ((Test-Connection -TargetName 8.8.8.8 -Quiet) -or (Test-Connection -TargetName 1.1.1.1 -Quiet)) {
        Write-Host "* Good, You have Internet connection" -ForegroundColor Cyan
    }
    else {
        Write-Host "* NO Internet connection detected, Please check your connection and try again" -ForegroundColor Red
        Read-Host -Prompt "Press Enter to exit"
        exit
    }
}
function Get-DNSServer {
    Write-Host ">> What DNS Server do you want to use? [Default: System]"
    Write-Host "[1] System"
    Write-Host "[2] CloudFlare"
    Write-Host "[3] Google"
    Write-Host "[4] Quad9"
    Write-Host "Or Enter Manually (Only IPv4)"
    $DNSInput = Read-Host "Please Enter"
    if ($IsWindows) {
        if (([string]$null -eq $DNSInput) -or (1 -eq $DNSInput) -or ("System" -eq $DNSInput)) {
            $DNSServer = $null
            Write-Host ">> DNS Server: System" -ForegroundColor Green
        }
        elseif ((2 -eq $DNSInput) -or ("CloudFlare" -eq $DNSInput)) {
            $DNSServer = "-Server 1.1.1.1"
            Write-Host ">> DNS Server: CloudFlare [1.1.1.1]" -ForegroundColor Green
        }
        elseif ((3 -eq $DNSInput) -or ("Google" -eq $DNSInput)) {
            $DNSServer = "-Server 8.8.8.8"
            Write-Host ">> DNS Server: Google [8.8.8.8]" -ForegroundColor Green
        }
        elseif ((4 -eq $DNSInput) -or ("Quad9" -eq $DNSInput)) {
            $DNSServer = "-Server 9.9.9.9"
            Write-Host ">> DNS Server: Quad9 [9.9.9.9]" -ForegroundColor Green
        }
        elseif ($DNSInput -match "^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$") {
            $DNSServer = "-Server " + $DNSInput
            Write-Host ">> DNS Server:"$DNSInput -ForegroundColor Green
        }
        else {
            Write-Host $DNSInput "!! is invalid, Please try again" -ForegroundColor Red
            Get-DNSServer
        }
        $DNSServer
    }
    else {
        if (([string]$null -eq $DNSInput) -or (1 -eq $DNSInput) -or ("System" -eq $DNSInput)) {
            $DNSServer = $null
            Write-Host ">> DNS Server: System" -ForegroundColor Green
        }
        elseif ((2 -eq $DNSInput) -or ("CloudFlare" -eq $DNSInput)) {
            $DNSServer = '"' + '@1.1.1.1' + '"'
            Write-Host ">> DNS Server: CloudFlare [1.1.1.1]" -ForegroundColor Green
        }
        elseif ((3 -eq $DNSInput) -or ("Google" -eq $DNSInput)) {
            $DNSServer = '"' + '@8.8.8.8' + '"'
            Write-Host ">> DNS Server: Google [8.8.8.8]" -ForegroundColor Green
        }
        elseif ((4 -eq $DNSInput) -or ("Quad9" -eq $DNSInput)) {
            $DNSServer = '"' + '@9.9.9.9' + '"'
            Write-Host ">> DNS Server: Quad9 [9.9.9.9]" -ForegroundColor Green
        }
        elseif ($DNSInput -match "^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$") {
            $DNSServer = '"' + '@' + $DNSInput + '"'
            Write-Host ">> DNS Server:"$DNSInput -ForegroundColor Green
        }
        else {
            Write-Host $DNSInput "!! is invalid, Please try again" -ForegroundColor Red
            Get-DNSServer
        }
        $DNSServer
    }
}
function Get-DOHServer {
    Write-Host ">> What DNS over HTTPS Server do you want to use? [Default: CloudFlare]"
    Write-Host "[1] CloudFlare"
    Write-Host "[2] Google"
    Write-Host "[3] Quad9"
    $DNSInput = Read-Host "Please Enter"
    if (([string]$null -eq $DNSInput) -or (1 -eq $DNSInput) -or ("CloudFlare" -eq $DNSInput)) {
        $DOHServer = 'https://cloudflare-dns.com/dns-query?name='
        $Type = '&type=A'
        $DOHInfo = 'CloudFlare[cloudflare-dns.com]'
        Write-Host ">> DOH Server:" $DOHInfo -ForegroundColor Green
    }
    elseif ((2 -eq $DNSInput) -or ("Google" -eq $DNSInput)) {
        $DOHServer = 'https://dns.google/resolve?name='
        $Type = '&type=A'
        $DOHInfo = 'Google[dns.google]'
        Write-Host ">> DOH Server:" $DOHInfo -ForegroundColor Green
    }
    elseif ((3 -eq $DNSInput) -or ("Quad9" -eq $DNSInput)) {
        $DOHServer = 'https://dns.quad9.net:5053/dns-query?name='
        $Type = $null
        $DOHInfo = 'Quad9[dns.quad9.net]'
        Write-Host ">> DOH Server:" $DOHInfo -ForegroundColor Green
    }
    else {
        Write-Host $DNSInput "!! is invalid, Please try again" -ForegroundColor Red
        Get-DOHServer
    }
    $DOHServer
    $Type
    $DOHInfo
}
function Test-Domains-TCP {
    if (!($Port)) {
        $Port = Get-Port
    }
    if (!($Timeout)) {
        $Timeout = Get-Timeout
        Write-Host $Timeout -ForegroundColor Green
    }
    if (!($Concurrency)) {
        $Concurrency = Get-Concurrency
        Write-Host $Concurrency -ForegroundColor Green
    }
    Write-Host "* Script started at >>" (Get-Date) -ForegroundColor Cyan
    Write-Host "* Selected Mode >> TCP" -ForegroundColor Cyan
    Write-Host "* Selected Port >> $Port" -ForegroundColor Cyan
    Write-Host "* Timeout >> $Timeout Seconds" -ForegroundColor Cyan
    Write-Host "* Concurrency >> $Concurrency" -ForegroundColor Cyan
    Test-Connectivity
    Write-Host "* Initializing TCP Test..., Please keep Internet Connected" -ForegroundColor Cyan
    Start-Sleep -Seconds 1
    if ($File) {
        $domains = Get-Content -Path $File | Sort-Object
    }
    else {
        $domains = Get-Content -Path "domains.txt" | Sort-Object
    }
    $output = @()
    $output += $domains | ForEach-Object -Parallel {
        $TestTCP = Test-Connection -IPv4 -TargetName $_ -TcpPort $using:Port -TimeoutSeconds $using:Timeout -ErrorAction Ignore
        if ($TestTCP) {
            Write-Host $_ ">> TCP Test Succeeded -> on Port $using:Port" -ForegroundColor Green
            $result = "OK"
        }
        else {
            Write-Host $_ "!! TCP Test Failed" -ForegroundColor Red
            $result = "DEAD"
        }
        [PSCustomObject]@{
            'Domain' = $_
            'Result' = $result
        }
    } -ThrottleLimit $Concurrency
    $output | Sort-Object -Property Domain | Export-Csv -Path ".\Results-TCP.csv"
}
function Test-Domains-DNS {
    if ($IsWindows) {
        if (!($DNSServer)) {
            $DNSServer = Get-DNSServer
        }
        else {
            $DNSServer = "-Server " + $DNSServer
        }
        if (!($Concurrency)) {
            $Concurrency = Get-Concurrency
            Write-Host $Concurrency -ForegroundColor Green
        }
        Write-Host "* Script started at >>" (Get-Date) -ForegroundColor Cyan
        Write-Host "* Selected Mode >> DNS" -ForegroundColor Cyan
        Write-Host "* Selected DNS Server >>" $DNSServer -ForegroundColor Cyan
        Write-Host "* Concurrency >>" $Concurrency -ForegroundColor Cyan
        Test-Connectivity
        Write-Host "* Initializing DNS Test..., Please keep Internet Connected" -ForegroundColor Cyan
        Clear-DnsClientCache
        Start-Sleep -Seconds 1
        if ($File) {
            $domains = Get-Content -Path $File | Sort-Object
        }
        else {
            $domains = Get-Content -Path "domains.txt" | Sort-Object
        }
        $output = @()
        $output += $domains | ForEach-Object -Parallel {
            $ResolveCommand = "Resolve-DnsName -DnsOnly -Name " + $_ + " -NoHostsFile " + $using:DNSServer + " -Type A -ErrorAction SilentlyContinue"
            $resolve = Invoke-Expression $ResolveCommand
            $ErrorMessage = (get-Error).Exception.Message
            if ($resolve) { 
                [string]$IP = $resolve.IP4Address
                Write-Host $_ ">> DNS Query Succeded ->" $IP -ForegroundColor Green
                $result = "OK"
            }
            else {
                $IP = "N/A"
                Write-Host $_ "!! DNS Query Failed ->" $ErrorMessage -ForegroundColor Red
                $result = "DEAD"
            }
            [PSCustomObject]@{
                'Domain' = $_
                'Result' = $result
                'IP'     = $IP
                'Error'  = $ErrorMessage
            }
            $Error.Clear()
        } -ThrottleLimit $Concurrency
    }
    else {
        if (!($DNSServer)) {
            $DNSServer = Get-DNSServer
        }
        else {
            $DNSServer = '"' + "@" + $DNSServer + '"'
        }
        if (!($Concurrency)) {
            $Concurrency = Get-Concurrency
            Write-Host $Concurrency -ForegroundColor Green
        }
        Write-Host "* Script started at >>" (Get-Date) -ForegroundColor Cyan
        Write-Host "* Selected Mode >> DNS" -ForegroundColor Cyan
        Write-Host "* Selected DNS Server >>" $DNSServer -ForegroundColor Cyan
        Write-Host "* Concurrency >>" $Concurrency -ForegroundColor Cyan
        Test-Connectivity
        Write-Host "* Initializing DNS Test..., Please keep Internet Connected" -ForegroundColor Cyan
        Start-Sleep -Seconds 1
        if ($File) {
            $domains = Get-Content -Path $File | Sort-Object
        }
        else {
            $domains = Get-Content -Path "domains.txt" | Sort-Object
        }
        $output = @()
        $output += $domains | ForEach-Object -Parallel {
            $ResolveCommand = "dig -t A " + $_ + " +short " + $using:DNSServer
            $resolve = Invoke-Expression $ResolveCommand
            [string]$IP = $resolve | select-string -raw -Pattern "^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$"
            if ($IP) {
                Write-Host $_ ">> DNS Query Succeded ->" $IP -ForegroundColor Green
                $result = "OK"
            }
            else {
                $IP = "N/A"
                Write-Host $_ "!! DNS Query Failed" -ForegroundColor Red
                $result = "DEAD"
            }
            [PSCustomObject]@{
                'Domain' = $_
                'Result' = $result
                'IP'     = $IP
            }
        } -ThrottleLimit $Concurrency
    }
    $output | Sort-Object -Property Domain | Export-Csv -Path ".\Results-DNS.csv"
}
function Test-Domains-DOH {
    if (!($DOHServer)) {
        $DOH = Get-DOHServer
        $URL = $DOH[0]
        $Type = $DOH[1]
        $DOHInfo = $DOH[2]

    }
    elseif ("cloudflare" -eq $DOHServer) {
        $URL = 'https://cloudflare-dns.com/dns-query?name='
        $Type = '&type=A'
        $DOHInfo = 'CloudFlare[cloudflare-dns.com]'
    }
    elseif ("Google" -eq $DOHServer) {
        $URL = 'https://dns.google/resolve?name='
        $Type = '&type=A'
        $DOHInfo = 'Google[dns.google]'
    }
    elseif ("Quad9" -eq $DOHServer) {
        $URL = 'https://dns.quad9.net:5053/dns-query?name='
        $Type = $null
        $DOHInfo = 'Quad9[dns.quad9.net]'
    }
    if (!($Concurrency)) {
        $Concurrency = Get-Concurrency
        Write-Host $Concurrency -ForegroundColor Green
    }
    Write-Host "* Script started at >>" (Get-Date) -ForegroundColor Cyan
    Write-Host "* Selected Mode >> DOH" -ForegroundColor Cyan
    Write-Host "* Selected DOH Server >>" $DOHInfo -ForegroundColor Cyan
    Write-Host "* Concurrency >>" $Concurrency -ForegroundColor Cyan
    Test-Connectivity
    Write-Host "* Initializing DNS Test..., Please keep Internet Connected" -ForegroundColor Cyan
    Start-Sleep -Seconds 1
    if ($File) {
        $domains = Get-Content -Path $File | Sort-Object
    }
    else {
        $domains = Get-Content -Path "domains.txt" | Sort-Object
    }
    $header = @{"accept" = "application/dns-json" }
    $output = @()
    $output += $domains | ForEach-Object -Parallel {
        $RequestURL = $using:URL + $_ + $using:Type
        $Response = Invoke-RestMethod -Uri $RequestURL -Method Get -Headers $using:header -SslProtocol Tls -SkipHttpErrorCheck
        if (0 -eq ($Response.Status)) { 
            [string]$IP = ($Response.Answer).data
            Write-Host $_ ">> DOH Query Succeded ->" $IP -ForegroundColor Green
            $result = "OK"
        }
        else {
            $IP = "N/A"
            Write-Host $_ "!! DOH Query Failed with Status Code" ($Response.Status) -ForegroundColor Red
            $result = "DEAD"
        }
        [PSCustomObject]@{
            'Domain'      = $_
            'Result'      = $result
            'Status Code' = ($Response.Status)
            'IP'          = $IP
        }
    } -ThrottleLimit $Concurrency
    $output | Sort-Object -Property Domain | Export-Csv -Path ".\Results-DOH.csv"
}
function Test-Domains-ICMP {
    if (!($Timeout)) {
        $Timeout = Get-Timeout
        Write-Host $Timeout -ForegroundColor Green
    }
    if (!($Concurrency)) {
        $Concurrency = Get-Concurrency
        Write-Host $Concurrency -ForegroundColor Green
    }
    Write-Host "* Script started at >>" (Get-Date) -ForegroundColor Cyan
    Write-Host "* Selected Mode >> ICMP/Ping" -ForegroundColor Cyan
    Write-Host "* Concurrency >>" $Concurrency -ForegroundColor Cyan
    Test-Connectivity
    Write-Host "* Initializing ICMP/Ping Test..., Please keep Internet Connected" -ForegroundColor Cyan
    Start-Sleep -Seconds 1
    if ($File) {
        $domains = Get-Content -Path $File | Sort-Object
    }
    else {
        $domains = Get-Content -Path "domains.txt" | Sort-Object
    }
    $output = @()
    $output += $domains | ForEach-Object -Parallel {
        $TestICMP = Test-Connection -IPv4 -TargetName $_ -TimeoutSeconds $using:Timeout -ErrorAction SilentlyContinue
        $LatencyResults = $TestICMP | Measure-Object -Property Latency -Minimum -Maximum -Average
        if ($TestICMP -and (0 -ne $LatencyResults.Average)) {
            Write-Host $_ ">> ICMP Test Succeeded -> Average Latency -> "$LatencyResults.Average -ForegroundColor Green
            $result = "OK"
            $IP = $TestICMP.DisplayAddress | Out-String -Stream | select-string -raw -Pattern "^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$" | Get-Unique
            $Ping1 = $TestICMP.Status[0]
            $Latency1 = $TestICMP.Latency[0]
            $Ping2 = $TestICMP.Status[1]
            $Latency2 = $TestICMP.Latency[1]
            $Ping3 = $TestICMP.Status[2]
            $Latency3 = $TestICMP.Latency[2]
            $Ping4 = $TestICMP.Status[3]
            $Latency4 = $TestICMP.Latency[3]
            $LatencyMin = $LatencyResults.Minimum
            $LatencyMax = $LatencyResults.Maximum
            $LatencyAvg = $LatencyResults.Average
        }
        else {
            Write-Host $_ "!! ICMP Test Failed" -ForegroundColor Red
            $result = "DEAD"
            $IP = "N/A"
            $Ping1 = "N/A"
            $Latency1 = "N/A"
            $Ping2 = "N/A"
            $Latency2 = "N/A"
            $Ping3 = "N/A"
            $Latency3 = "N/A"
            $Ping4 = "N/A"
            $Latency4 = "N/A"
            $LatencyMin = "N/A"
            $LatencyMax = "N/A"
            $LatencyAvg = "N/A"
        }
        [PSCustomObject]@{
            'Domain'           = $_
            'Result'           = $result
            'IP'               = $IP
            'Ping Status[1]'   = $Ping1
            'Latency[1]'       = $Latency1
            'Ping Status[2]'   = $Ping2
            'Latency[2]'       = $Latency2
            'Ping Status[3]'   = $Ping3
            'Latency[3]'       = $Latency3
            'Ping Status[4]'   = $Ping4
            'Latency[4]'       = $Latency4
            'Latency[Minimum]' = $LatencyMin
            'Latency[Maximum]' = $LatencyMax
            'Latency[Average]' = $LatencyAvg

        }
    } -ThrottleLimit $Concurrency
    $output | Sort-Object -Property Domain | Export-Csv -Path ".\Results-ICMP.csv"
}
function Invoke-Main {
    if (!($Mode)) {
        $Mode = Get-Mode
    }
    $duration = [System.Diagnostics.Stopwatch]::StartNew()
    if (("1" -eq $Mode) -or ("TCP" -eq $Mode)) {
        Test-Domains-TCP
    }
    elseif (("2" -eq $Mode) -or ("DNS" -eq $Mode)) {
        Test-Domains-DNS
    }
    elseif (("3" -eq $Mode) -or ("DOH" -eq $Mode)) {
        Test-Domains-DOH
    }
    elseif (("4" -eq $Mode) -or ("ICMP" -eq $Mode)) {
        Test-Domains-ICMP
    }
    $duration.stop()
    Write-Host "Script finished in" $duration.Elapsed.Hours "Hours" $duration.Elapsed.Minutes "Minutes" $duration.Elapsed.Seconds "Seconds" -ForegroundColor Green
    Read-Host -Prompt "Press Enter to exit..."
}

Write-Host "█▀▄ █▀█ █▀▄▀█ ▄▀█ █ █▄░█   █░█ █▀▀ ▄▀█ █░░ ▀█▀ █░█   █▀▀ █░█ █▀▀ █▀▀ █▄▀ █▀▀ █▀█ " -ForegroundColor DarkCyan
Write-Host "█▄▀ █▄█ █░▀░█ █▀█ █ █░▀█   █▀█ ██▄ █▀█ █▄▄ ░█░ █▀█   █▄▄ █▀█ ██▄ █▄▄ █░█ ██▄ █▀▄ " -ForegroundColor DarkCyan -NoNewline
Write-Host " v0.1" -ForegroundColor DarkCyan
Write-Host ""
Write-Host ""

Invoke-Main