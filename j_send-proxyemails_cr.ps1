param ( $logginglevel = 3, $DefaultLogOutputs = 3, $CloseOnExit="no", $script_lib = ".\script_lib.ps1", $globalloglevel = 3, $usr = "", $pwd = "" , $ConfigLoc = "", $ConfigFileType = "")

$myversion = "v.1.2" # (12/15/16)
#v.1.0 (06/01/2016)
#v.0.1 (05/2016)
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
$scriptname = "j_send-proxyemails_cr.ps1"
Verify-Configdata "skipemail,mailfromuser,mailto,smtpport,smtpserver,stalelogthreshold,resultlineverbage,endcode,pathlist,lognamefilter" $scriptname
$skipemail = Get-ConfigValue "skipemail" $scriptname
$stalelogthreshold = Get-ConfigValue "stalelogthreshold" $scriptname
$resultlineverbage = Get-ConfigValue "resultlineverbage" $scriptname
$endcode = Get-ConfigValue "endcode" $scriptname
$pathlist = Get-ConfigValue "pathlist" $scriptname
$lognamefilter = Get-ConfigValue "lognamefilter" $scriptname
$smtpport = Get-ConfigValue "smtpport" $scriptname
$smtpserver = Get-ConfigValue "smtpserver" $scriptname
$from = Get-ConfigValue "mailfromuser" $scriptname
$to = @(); $to += Get-ConfigValue "mailto" $scriptname
$cc = @(); $bcc = @(); $priority = ""; $mail_attachments = ""
$subject = @()


$workingpath = Verify-Pathaccess $pathlist
$logfiles = Get-ChildItem $workingpath
# get servername
Try { $oneservername = $workingpath.split("\")[2] }
Catch [system.exception] { Exit-Script "Unable to get servername from workingpath. workingpath is $workingpath" "error" }
Log-Message  "Servername is: $oneservername"

# check#1 - file with name located
$youngestlogfile = $logfiles | where {$_.name -match $lognamefilter } | sort -Property lastwritetime -Descending | select -First 1
If (-not($youngestlogfile)) { Exit-Script "Unable to locate any files with name $lognamefilter" "error" }
# check#2 - is the file stale?
If ($youngestlogfile.LastWriteTime -lt $date.AddHours(-($stalelogthreshold)) ) { Exit-Script ($youngestlogfile.name + " is stale as it's from: " + $youngestlogfile.LastWriteTime) "error" }
Log-Message ("File: " + $youngestlogfile.name + " is recent.")
# Read log to find the msg lines from start code to end code. 
$foundresultlinefound = 0
$foundendcode = 0
$message = ""
Foreach ($onelogline in ($youngestlogfile | Get-Content)) {
    #Log-Message ("ONELINE: " + $onelogline)
    If ($onelogline -match $endcode ) {
        Log-Message "Found endline: $onelogline"
        $foundresultlinefound = 0
    }
    If ($foundresultlinefound) { $message += ($onelogline+"`n") }
    If ($onelogline -match $resultlineverbage ) {
        Log-Message "Found resultline: $onelogline"
        $foundresultlinefound = 1
    }
}
If (-not($message) ) { Exit-Script ("Unable to find string -->$resultlineverbage<-- in file " + $youngestlogfile.name) "error" }
        
Log-Message "Message: $message"      

# email this msg line as proxy
$subject = $subject += ("JobMaster daily: " + ($oneservername.ToUpper().split('.')[0]) + " via proxy.")
# Send status email. 
If (-not($skipemail -match "yes") ) {
    sleep 10
    Try { Send-Mail $usr $pwd $from $to $cc $bcc $subject $priority $false $message $attachments $smtpport $smtpserver; Log-Message "E-mail sent successfully." }
    Catch [system.exception] { 
        Log-Message ("Problem sending email message. Error is:`n" + $_.Exception.Message) "warn"
        Exit-Script "Unable to send email." "error" 
    }
}
Else { Log-Message "Skipping email" }

Exit-Script "Script done" "global"

Write-host "ERROR: Should never get this line."
Exit 1