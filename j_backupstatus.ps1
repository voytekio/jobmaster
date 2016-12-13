param ( $logginglevel = 3, $DefaultLogOutputs = 3, $CloseOnExit="no", $script_lib = ".\script_lib.ps1", $globalloglevel = 3, $usr = "", $pwd = "", $ConfigLoc = "", $ConfigFileType = "")

$myversion = "v.1.0" # (12/12/16)
#v.1.0 (12/12/2016)
#v.0.1 (06/30/2016)
#Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$WarningPreference = 'silentlyContinue'
$ProgressPreference = 'SilentlyContinue'
##### Libraries:
. $script_lib

$date = get-date
$directorypath = split-path ((get-variable MyInvocation).Value).MyCommand.Path

$null = Open-Logfile 
$compname = $env:computername
Log-Message "Script starting on $compname" "global" 7
Log-Message ("PowerShell Version is: " + ($PSVersionTable.PSVersion.Major) + "." + ($PSVersionTable.PSVersion.Minor))
Log-Message "Script version is: $myversion"
Log-Message "Script_lib location is: $script_lib"

Get-Configdata $ConfigLoc $ConfigFileType
$scriptname = "j_backupstatus.ps1"
Verify-Configdata "successstring,stalelogthreshold,pathlist,filenamematch" $scriptname
$successstring = Get-ConfigValue "successstring" $scriptname
$stalelogthreshold = Get-ConfigValue "stalelogthreshold" $scriptname
$pathlist = Get-ConfigValue "pathlist" $scriptname
$filenamematch = Get-ConfigValue "filenamematch" $scriptname

#basics
$workingpath = Verify-Pathaccess $pathlist
$logfiles = Get-ChildItem $workingpath

# check#1 - file with name located
$youngestlogfile = $logfiles | where {$_.name -match $filenamematch} | sort -Property lastwritetime -Descending | select -First 1
If (-not($youngestlogfile)) { Exit-Script "Unable to locate any files with name $filenamematch" "error" }
# check#2 - is the file stale?
If ($youngestlogfile.LastWriteTime -lt $date.AddHours(-($stalelogthreshold)) ) { Exit-Script ($youngestlogfile.name + " is stale as it's from: " + $youngestlogfile.LastWriteTime) "error" }
Log-Message ("File: " + $youngestlogfile.name + " is recent.")

# Read log to find the msg lines from start code to end code. 
$foundresultlinefound = 0
$foundendcode = 0
Foreach ($onelogline in ($youngestlogfile | Get-Content)) {
    #Log-Message ("ONELINE: " + $onelogline)
    If ($onelogline -match $successstring ) {
        Log-Message "Found resultline: $onelogline"
        $foundresultlinefound = 1
    }
}
If (-not($foundresultlinefound) ) { Exit-Script ("Unable to find string -->$successstring<-- in file " + $youngestlogfile.name) "error" }
Else { Exit-Script "Backup completed successfully." "global" }

Exit-Script "Should not get to this line" "error"

Write-host "ERROR: Should never get this line."
Exit 1