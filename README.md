# Domain-Health-Checker
 A simple and Cross-Platform script to check a list of domains for availability.

 # Requirements
 You need Powershell 7 to be installed on your system. You can get it for your platform from here [Install PowerShell on Windows, Linux, and macOS](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell).  
 Also for linux based systems, you need `dig` from `bind-utils` package.

 # Usage
 Either run the script and it will promp you for input or provide parameters via CLI.  
 By default, the script will look for `domains.txt` in the current directory. You can provide custom path via `-File` parameter in CLI.  
 To run the script, open Powershell 7 in the script directory and run `.\Check-Domains.ps1`  
 For full documentaion run `Get-Help .\Check-Domains.ps1`  

 # CLI Usage
 You can also provide inputs via CLI.

 ## For TCP Mode
 `.\Check-Domains.ps1 -Mode TCP -Port 80 -Timeout 5 -Concurrency 20`

 ## For DNS Mode
 `.\Check-Domains.ps1 -Mode DNS -DNSServer 1.1.1.1 -Concurrency 10 -File domains.txt`

 ## For DOH Mode
 `.\Check-Domains.ps1 -Mode DOH -DOHServer Cloudflare -Concurrency 10`

 ## For ICMP Mode
 `.\Check-Domains.ps1 -Mode ICMP -Timeout 10 -Concurrency 5 -File "path\to\domains.txt"`
 