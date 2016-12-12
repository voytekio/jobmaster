param ( $logginglevel = 3, $DefaultLogOutputs = 3, $CloseOnExit="no", $script_lib = ".\script_lib.ps1", $globalloglevel = 3, $usr = "", $pwd = "", $ConfigLoc = ".\jobmaster.cfg", $ConfigFileType = "json")

$myversion = "v.1.12" # (12/11/16)
#v.1.0 (04/2016)
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
$scriptname = "jobmaster.ps1"
Verify-Configdata "mailto,jobsdir,mailfromuser,smtpport,smtpserver,skipemail" $scriptname
$skipemail = Get-ConfigValue "skipemail" $scriptname
$smtpport = Get-ConfigValue "smtpport" $scriptname
$smtpserver = Get-ConfigValue "smtpserver" $scriptname
$from = Get-ConfigValue "mailfromuser" $scriptname
$to = @(); $to += Get-ConfigValue "mailto" $scriptname
$cc = @(); $bcc = @(); $priority = ""; $mail_attachments = ""
$subject = @()


# get all jobs
$jobsdir = Get-ConfigValue "jobsdir" $scriptname
Log-Message "Running all jobs in $jobsdir directory."
$jobs = Get-ChildItem -Filter "j_*"
$jobcounter = 0
$jobname = @()
$jobstatus = @()
$joboutput = @()
$jobcounter = 0

# run all jobs
Foreach ($onejob in $jobs) {
    sleep 1 #so each log filename is unique
    Log-Message ("running onejob: " + $onejob.name + "." )
    $perscriptskipemail = Get-ConfigValue "skipemail" $onejob
    $res = powershell.exe ($onejob.FullName) -script_lib:$script_lib -skipemail:$perscriptskipemail -usr $usr -pwd $pwd -ConfigLoc:$ConfigLoc -ConfigFileType $ConfigFileType; $excode = $LastExitCode
    <#
    If ( (-not($onejob.name) -match "_cr") -or ($perscriptskipemail -match "yes") ) {
        $res = powershell.exe ($onejob.FullName) -skipemail:"yes" -script_lib:$script_lib; $excode = $LastExitCode
    }
    Else { 
        $res = powershell.exe ($onejob.FullName) -script_lib:$script_lib -usr $usr -pwd $pwd; $excode = $LastExitCode
    }
    #>
    Log-Message ("Exit code was: " + $excode)
    $jobname += $onejob.name
    $jobstatus += $excode

    # get output
    #write-host "res is: $res`n`n`n"
    $emptylinecount = 0
    If ( $res.gettype().isarray ) # got multiline output
    {
        #write-host "got multiline"
        foreach ($oneline in $res) { 
            #write-host "onelineis: $oneline" 
            if (-not($oneline)) { 
                #write-host "im an empty line"
                $emptylinecount ++  
            }
            Else {
                #write-host "not empty"
                $emptylinecount = 0 #reset emptylinecount
            }
        }
        #Write-host "FOUND $emptylinecount empty lines at end."
        $emptylinecount ++ # will use in | select below so incrementing by 1. 
        If ( ($res | select -last $emptylinecount).Length -gt 80) { $joboutput += (($res | select -last $emptylinecount).Substring(0,80)) } #trim large output to first 120 chars.
        Else { $joboutput += ($res | select -last $emptylinecount) }
    }
    Else {
        #write-host "got single-line"
        If ( $res.Length -gt 80) { $joboutput += ($res.Substring(0,80)) } #trim large output to first 120 chars.
        Else {$joboutput += $res }
    }
    $jobcounter++
}


# Enumerate status for all jobs:
$message = "Job Master script finished and reported the following status for $jobcounter jobs:`n"
$jobcounter = 0
Foreach ($onejob in $jobs) {
    $message += ("`n" + ($jobcounter+1) +": " + $jobname[$jobcounter] + ".`tStatus: " + $jobstatus[$jobcounter] + ". Output: " + $joboutput[$jobcounter])
    $jobcounter ++
}
Log-Message "---s"
Log-Message $message
Log-Message "---e"

# Send status email. 
$subject = $subject += "JobMaster daily: $compname."
If (-not($skipemail -match "yes") ) {
    sleep 5
    Try { Send-Mail $usr $pwd $from $to $cc $bcc $subject $priority $false $message $attachments $smtpport $smtpserver; Log-Message "E-mail sent successfully." }
    Catch [system.exception] { 
        Log-Message ("Problem sending email message. Error is:`n" + $_.Exception.Message) "warn" 
    }
}
Else { Log-Message "Skipping email" }

Exit-Script "Script done" "global"

Write-host "ERROR: Should never get this line."
Exit 1