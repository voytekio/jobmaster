param ( $logginglevel = 3, $DefaultLogOutputs = 3, $CloseOnExit="no", $script_lib = ".\script_lib.ps1", $globalloglevel = 3,
    $usr = "", $pwd = "", $skipemail = "", $ConfigLoc = "", $ConfigFileType = "")
    #usr/pwd arguments needed if connecting to a file server where you can't use pass-through or domain auth. (ex laptop to file server)

$myversion = "v.1.2" # (03/20/2017)
#v.1.0 (06/29/2016)
#v.0.1 (06/2016)
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
$scriptname = "backupscript.ps1"
Verify-Configdata "BackupType,IncludeSystemState,successstring,bkpdestinationlist,sourcelist,SkipVerify" $scriptname
$BackupType = Get-ConfigValue "BackupType" $scriptname
$IncludeSystemState = Get-ConfigValue "IncludeSystemState" $scriptname
$successstring = Get-ConfigValue "successstring" $scriptname
$bkpdestinationlist = Get-ConfigValue "bkpdestinationlist" $scriptname
$sourcelist = Get-ConfigValue "sourcelist" $scriptname
$SkipVerify = Get-ConfigValue "SkipVerify" $scriptname

Log-Message  "successstring is: $successstring"
Log-Message  "bkpdestinationlist is: $bkpdestinationlist"
Log-Message  "sourcelist is: $sourcelist"

$workingpath = Verify-Pathaccess $bkpdestinationlist "oddeven" $SkipVerify

# get servername
If ($pathlist -match ":") { $oneservername = "Localhost" }
Else {
    Try { $oneservername = $workingpath.split("\")[2] }
    Catch [system.exception] { Exit-Script "Unable to get servername from workingpath. workingpath is $workingpath" "error" }
}
Log-Message  "Servername is: $oneservername"

#Exit-Script "Temp exit" "warn"

Switch ($BackupType) {
    "wbadmin" {
        Log-Message "wbadmin backup type requested."
        # prepare bkp cmd:
        If ($usr) { $bkpcmd = "wbadmin start backup -backupTarget:" + $workingpath + " -user:" + $usr + " -password:" + $pwd + " -include:`"" + $sourcelist + "`" -quiet" }
        Else {
            $bkpcmd = "wbadmin start backup -backupTarget:" + $workingpath + " -include:`"" + $sourcelist + "`" -quiet"
            Log-Message "Backup cmd is: $bkpcmd"
        }
        Try { $res = Invoke-Expression $bkpcmd }
        Catch [system.exception] { 
            Log-Message ("Error while running bkp command. Error is:`n" + $_.Exception.Message) "warning"
            Exit-Script "Failure during backup" "error"
            }
        Log-Message "Cmd output was: $res"
        If ($res -match $successstring) {
            Log-Message ("Found success line in cmd output")
            Exit-Script "Script done" "global"
        }
        Else {
            Log-Message ("Unable to find success line in output ") "warn"
            Exit-Script "Script done but unable to confirm success" "warn"
        }
    }
    default {
        Exit-Script "Unknown backup type requested. " "error"
    }
}


Exit-Script "Should not get to this line" "error"


Write-host "ERROR: Should never get this line."
Exit 1