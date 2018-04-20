param ( $logginglevel = 3, $DefaultLogOutputs = 3, $CloseOnExit="no", $script_lib = ".\script_lib.ps1", $globalloglevel = 3,
     $usr = "", $pwd = "" , $ConfigLoc = "", $ConfigFileType = "")


$myversion = "v.1.2" # (04/19/18) # old script, improved to use config file instead of cmd arguments. This is on par with other job_master scripts.
#v.1.0 (10/12/16)
#v.0.1 (10/11/16)
$ErrorActionPreference = 'Stop'
$WarningPreference = 'silentlyContinue'
$ProgressPreference = 'SilentlyContinue'
##### Libraries:
. $script_lib

$null = Open-Logfile 
$compname = $env:computername
$date = get-date
Log-Message "Script starting on $compname" "global" 7
Log-Message ("PowerShell Version is: " + ($PSVersionTable.PSVersion.Major) + "." + ($PSVersionTable.PSVersion.Minor))
Log-Message "Script version is: $myversion"
Log-Message "Script_lib location is: $script_lib"

Get-Configdata $ConfigLoc $ConfigFileType
$scriptname = "j_logtrimmer.ps1"
Verify-Configdata "Confirm,WorkingLogsPath,NamePrefix,NameSuffix,DaysToKeep" $scriptname
$Confirm = Get-ConfigValue "Confirm" $scriptname
$WorkingLogsPath = Get-ConfigValue "WorkingLogsPath" $scriptname
$NamePrefix = Get-ConfigValue "NamePrefix" $scriptname
$NameSuffix = Get-ConfigValue "NameSuffix" $scriptname
$DaysToKeep = Get-ConfigValue "DaysToKeep" $scriptname


Log-Message "Looking to delete log files from path: $WorkingLogsPath, older than: $DaysToKeep days, having prefix of: $NamePrefix and suffix: $NameSuffix"
Log-Message "Name suffix and prefix are CASE SENSITIVE" "warn"

#verify path
$workingpath = Verify-Pathaccess $WorkingLogsPath 
$logfiles = Get-ChildItem $workingpath

# get files with match
    # line below filters on lastwritetime, and name.startswith and name.endswith
$filestodelete = $logfiles | where { ($_.LastWriteTime -lt ($date.AddDays(-1*$DaysToKeep))) -and ($_.Name.StartsWith($NamePrefix)) -and ($_.Name.EndsWith($NameSuffix))  } 
If (-not ($filestodelete)) { Exit-Script "No Files to delete older than $DaysToKeep days." "warn" }

# output and count them:
Log-Message "Listing files about to be deleted:"
Foreach ($onefile in ($filestodelete | sort -Property LastWriteTime -Descending) ) { Log-Message ([string]$onefile.LastWriteTime + "`t" + [string]$onefile.Length + "`t" + [string]$onefile.Name) }
$filecount = $filestodelete.count
Log-Message "Listed $filecount file(s)"

#delete files
If ($Confirm -match "yes") { 
    Log-Message "Will actually delete files as -confirm is set to yes" "warn"
    Log-Message "YOU HAVE 10 SECONDS TO CTRL-C BEFORE DELETIONS" "warn"
    Sleep 10
    $Failuredetected = $false
    Foreach ($onefile in $filestodelete) {
        Try { $onefile.delete() }
        Catch [system.exception] { 
            Log-Message ("Error while deleting $onefile. Error is:`n" + $_.Exception.Message) "warning" 
            $Failuredetected = $true
        }
    }
    If ($Failuredetected) { Exit-Script "Encountered errors while deleting" "error" }
    Else { Exit-Script "Successfully deleted $filecount log files" "global" }
}
Else { 
    Log-Message "Read-only mode; use -confirm:yes to perform actual delete" 
    Exit-Script "Script ending. Would've deleted $filecount log files" "global"
}




Write-host "ERROR: Should never get this line."
Exit 1
