param ( $logginglevel = 3, $DefaultLogOutputs = 3, $CloseOnExit="no", $script_lib = ".\script_lib.ps1", $globalloglevel = 3, $usr = "", $pwd = "", $skipemail = "", $ConfigLoc = "", $ConfigFileType = "")

$myversion = "v.1.0" # (12/11/16)
#v.1.0 (12/11/16)
#v.0.1 (05/05/16)
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
$scriptname = "j_serverinfo.ps1"
Verify-Configdata "mailto,mailfromuser,smtpport,smtpserver" $scriptname
$smtpport = Get-ConfigValue "smtpport" $scriptname
$smtpserver = Get-ConfigValue "smtpserver" $scriptname
$from = Get-ConfigValue "mailfromuser" $scriptname
$to = @(); $to += Get-ConfigValue "mailto" $scriptname
$cc = @(); $bcc = @(); $priority = ""; $mail_attachments = ""
$subject = @()

# get uptime
$w = Get-WmiObject -Class Win32_OperatingSystem
$bootdate = $w.ConvertToDateTime($w.LastBootUpTime)
$dateslice = $date - $bootdate
Log-Message ("Uptime: " + $dateslice.days + " days, " + $dateslice.Hours + " hours, " + $dateslice.Minutes + " minutes.")
$message += ("Uptime: " + $dateslice.days + " days, " + $dateslice.Hours + " hours, " + $dateslice.Minutes + " minutes.")
# get disk space


# Send status email. 
$subject = $subject += "j_servinfo daily: $compname."
If (-not($skipemail -match "yes") ) {
    sleep 10
    Try { Send-Mail $usr $pwd $from $to $cc $bcc $subject $priority $false $message $attachments $smtpport $smtpserver ; Log-Message "E-mail sent successfully." }
    Catch [system.exception] { 
        Log-Message ("Problem sending email message. Error is:`n" + $_.Exception.Message) "warn" 
        $ecode = 1; $edescription =  "Problem sending email message."
    }
}
Else { Log-Message "Skipping email" }

If ($ecode -eq 1) { Exit-Script "Script finished with errors." "error" } 
Else { Exit-Script ("Success. " + $message  ) "global" }


