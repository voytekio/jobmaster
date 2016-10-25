# Managed script exit
Function Exit-Script #v1.5h
{
    param ($exitmessage,$exitlevel)
    
    #cleanup VI sessions
    #skipping
    
    If (-not($CloseOnExit)) { $CloseOnExit = "no" }
    Log-Message "Close Powershell window on exit: $CloseOnExit" "global" 7
    
    switch ($exitlevel) {
        "global" { $exitcode = 0 }
        "info" { $exitcode = 0 }
        "warn" { $exitcode = 2 }
        "error" { $exitcode = 1 }
        default { $exitcode = 2 }
    }
    Log-Message "script exiting with code: $exitcode" "global" 7
    Log-Message $exitmessage "global" 7 #output to log file, console and add to blob
    #$exitmessage = $exitmessage.Replace("\", "--").Replace("`n", " ") #remove backslash and CRLF which are likely illegal in Nagios.
    #If ($exitmessage.Lenght -gt 120) { $exitmessage = $exitmessage.Substring(0,120) } #trim large output to first 120 chars.
    
    Log-Message ( $MyInvocation.PSCommandPath + " script exiting. Summary output:`n--------------------------------------`n" + $eventlogblob) $exitlevel 8 # Publish blob to event viewer.
    If ($CloseOnExit -match "yes") { $Host.SetShouldExit($exitcode); Exit $exitcode }
    Else { Exit $exitcode }
}

# Function that opens a log file
Function Open-Logfile #v1.3h
{
    param ($lognameprefix, $logfilepath)
    $date = Get-Date
    If (-not($logfilepath)) { $logfilepath = $MyInvocation.PSScriptRoot }
    
    If (-not($logfilepath)) { Log-Message "Logfilepath still empty. Let's use script dir." "warn"; $logfilepath = "."}
    
    If (-not(Test-Path ([STRING]$logfilepath + "\Logs"))) {
        Log-Message "creating logs dir"
        Try { $null = New-Item ([STRING]$logfilepath + "\Logs") -type directory }
        Catch [system.exception] { Exit-Script ("Unable to create Logs Directory in $logfilepath. Error is:`n" + $_.Exception.Message) "error" }
    } 
        
    Try { $scriptnamepathlevels = ($MyInvocation.PSCommandPath).Split("\"); $logfilename = $scriptnamepathlevels[$scriptnamepathlevels.count -1] }
    Catch [system.exception] { 
        Log-Message ("Issues with MyInvocation object. You may be using older powershell w/o support for MyInvocation.PSCommandPath object. Error is:`n" + $_.Exception.Message) "warn" 
        $logfilename = "script"
    }
        
    If ($lognameprefix) { 
        $script:logfile = ([STRING]$logfilepath + "\Logs\Log-" + ($logfilename.split(".")[0]) + "--" + $lognameprefix+ "--" + [string]$date.month+"-"+[string]$date.day+"-"+[string]$date.year+"--"+[string]$date.hour+"-"+[string]$date.minute+"-"+[string]$date.second+".txt") 
    }
    Else { $script:logfile = ([STRING]$logfilepath + "\Logs\Log-" + ($logfilename.split(".")[0]) + "--" + [string]$date.month+"-"+[string]$date.day+"-"+[string]$date.year+"--"+[string]$date.hour+"-"+[string]$date.minute+"-"+[string]$date.second+".txt") }
    Log-Message "Full logfile is: $logfile"
    $script:logfileopen = 1
}

# Logging components that write output to screen, logfile and event log.
Function Log-Message #v1.4h
{
    param ($logmessage, $msgloglevel="info", $msgoutputs=3)
    If (-not($msgloglevel)) {$msgloglevel="info" } # in case someone passed blank ("") which will not use default value, we reset back to default value
    If (-not($msgoutputs)) {$msgoutputs=3 } # in case someone passed blank ("") which will not use default value, we reset back to default value
    
    $msgprefix = $msgloglevel.toUpper()
    If ($msgprefix -match "warn") {$msgprefix = "WARNING"}
    switch ($msgloglevel) {
        "debug" { $msgloglevel = 4 }
        "info" { $msgloglevel = 3 }
        "warn" { $msgloglevel = 2 }
        "error" { $msgloglevel = 1 }
        "global" { $msgloglevel = 0 }
        default { $msgloglevel = 3 }
    }
    
    # Log to file regardless of severity:
    $date = get-date
    $logmessage = [string]$date + " " + [string]$msgprefix + ": " + [string]$logmessage
    If (($msgoutputs -bAND 1) -and ($script:logfileopen -eq 1 )) {
        Try { $logmessage | out-file $logfile -append }
        Catch [system.exception] { Log-Message ("Unable to write to log file $logfile. Error is:`n" + $_.Exception.Message) "error" 10 ; Exit 1 } # !!! do NOT try to write to log file here, only console and event viewer; otherwise endless loop
    }
    
    # Check severity and log only if more severe or equal to $globalloglevel
    If ($msgloglevel -le $globalloglevel ) { # we will log message
        If ($msgoutputs -bAND 2) {Write-Host $logmessage}
    }
}
    
  
Function Send-Mail($usr, $pwd, $from,$to,$cc,$bcc,$subject,$priority,$html,$message,$mail_attachments,$emailSmtpServerPort = 587,$smtp_server = "smtp.office365.com") #v1.2
{
	$mail_message = New-Object System.Net.Mail.MailMessage
	$mail_message.From = $from
    
	foreach($person in $to) {
		$mail_message.To.Add($person)
	}
    
	if($cc -ne $null) {
		foreach($person in $cc) {
			$mail_message.CC.Add($person)
		}
	}
	if($bcc -ne $null) {
		foreach($person in $bcc) {
			$mail_message.BCC.Add($person)
		}
	}
	if($priority -eq "Normal" -or $priority -eq "Low" -or $priority -eq "High") {
		$mail_message.Priority = $Priority
	} else {
		$mail_message.Priority = "Normal"
	}

	$mail_message.Subject = $subject
	$mail_message.Body = ($message | Out-String)
	$mail_message.IsBodyHTML = $html
	if($mail_attachments.count -gt 0) {
		foreach($mail_attachment in $mail_attachments) {
			if(Test-Path -Path $mail_attachment) {
				$attachment = New-Object System.Net.Mail.Attachment $mail_attachment
				$mail_message.Attachments.Add($attachment)
			}
		}
	}
	
	$smtp_object = New-Object Net.Mail.SmtpClient($smtp_server, $emailSmtpServerPort)
	$smtp_object.EnableSsl = $true
	$smtp_object.Credentials = New-Object System.Net.NetworkCredential( $usr , $pwd )
	$smtp_object.Send($mail_message)
	$smtp_object.Dispose
}

Function Verify-Pathaccess  #v1.4
{
    param ($pathlist, $reorderstyle = "pickfirst")
    $pathlistarray = @()
    Try { $pathlistarray = $pathlist.split("|") }
    Catch [system.exception] { Exit-Script "Unable to obtain list of paths. Templist is $pathlist" "error" }
    $pathcount = $pathlistarray.Count
    Log-Message ("Paths count: " + $pathcount )
    $goodpathcount = 0

    If ($pathcount -lt 2) { Log-Message "No more than 1 path given"; $reorderstyle = "pickfirst"}
    Switch ($reorderstyle) {
        "oddeven" {  
            Log-Message "Chose odd/even as re-order method"
            $pathaccessdate = get-date
            If (($pathaccessdate.day) % 2 -eq 0) {
                Log-Message "Even day - picking first path in array."
                $preferredpath = $pathlistarray[0]
            }
            Else { Log-Message "Odd day - picking second path in array."; $preferredpath = $pathlistarray[1] }
        }
        "random" { 
            Log-Message "Chose random as re-order method"
            Log-Message "Currently not implemented. Defaulting to first path in array" "warn"
            $preferredpath = $pathlistarray[0]
        }
        default {  
            Log-Message "Chose pick-first as re-order method"
            $preferredpath = $pathlistarray[0]
        }
    }
    # now get a new array with 1st member as the preferred member
    $sortedpatharray = @()
    $sortedpatharray += $preferredpath
    Log-Message "Preferred path: $preferredpath"
    Foreach ($onepath in $pathlistarray ) {
        $modifiedonepath = [regex]::Escape($onepath) #this escapes magic regex chars for regex comparison used in -match
        $modifiedpreferredpath = [regex]::Escape($preferredpath) #this escapes magic regex chars for regex comparison used in -match
        If ($modifiedonepath -match $modifiedpreferredpath) { Log-Message "Skipping $onepath" }
        Else { Log-Message "Adding $onepath" ; $sortedpatharray += $onepath } 
    }

    Foreach ( $onepath in $sortedpatharray ) {
        Try { $parentfolder = Get-ChildItem $onepath ; $goodpathcount = 1}
        Catch [system.exception] { Log-Message ("Unable to connect to $onepath. Error is:`n" + $_.Exception.Message) "warning" }
        If ( $goodpathcount) { Log-Message ("Successfully connected to path $onepath."); Break }
    }
    If (-not($goodpathcount -eq 1)) { Exit-Script "Unable to connect to at least one path." "error" }
    Return $onepath
}