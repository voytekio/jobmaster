param ( $logginglevel = 3, $DefaultLogOutputs = 3, $CloseOnExit="no", $script_lib = ".\script_lib.ps1", $globalloglevel = 3)

$myversion = "v.1.1" # (06/07/16)
#v.1.0 (06/07/2016)
#v.0.1 (05/2016)
#Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$WarningPreference = 'silentlyContinue'
$ProgressPreference = 'SilentlyContinue'
##### Libraries:
. $script_lib
#. c:\v\scripting\jobmaster\$script_lib

$date = get-date
$directorypath = split-path ((get-variable MyInvocation).Value).MyCommand.Path

$null = Open-Logfile 
$compname = $env:computername
Log-Message "Script starting on $compname" "global" 7
Log-Message ("PowerShell Version is: " + ($PSVersionTable.PSVersion.Major) + "." + ($PSVersionTable.PSVersion.Minor))
Log-Message "Script version is: $myversion"

# basics


$result = nslookup myip.opendns.com resolver1.opendns.com
Log-Message "nslookup result: $result"
Log-Message ("result4: " + $result[4])

Try { $ipaddress = $result[4].split(' ')[2] }
Catch [system.exception] { Exit-Script "Unable to obtain IP address from nslookup answer of: $result" "error" }

Log-Message "IP: $ipaddress"
Write-Host $ipaddress
Exit-Script "$ipaddress" "global"



Exit 0