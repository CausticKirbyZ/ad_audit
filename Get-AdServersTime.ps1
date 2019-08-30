<#
    .SYNOPSIS
        Queries Domain Servers for their time.

    .DESCRIPTION 
        This Command queries all computers in the domain that are a "windos server OS" for their time
        and compares it to the PDC's time.
    
    .PARAMETER AutoHeal
        Autoheal will atempt to resync a server to the domain.
    
    .PARAMETER RunAdvancedFixes
        Must be run with -AutoHeal.
        This will set the target servers time source to the PDC and attempt to resync time to the domain.

    .PARAMETER Email
        This will send emails out to the email list when a server is discovered to be out of sync.
        This will send individual emails per server BE CAREFUL if run in a large enviornment this could generate alot of emails.

    .PARAMETER NOPing
        Do not ping before attempting to query server. 
        This may slow your script down some as the w32tm command may have to time out before it moves to the next server.

    .NOTES
        This script will attempt to ping a host first before querying their time. This is designed to speed up the script.
        if this is not desired you can edit the script yourself to take it out.

    .EXAMPLE
        ./ServerTimeCheck.ps1 -AutoHeal -Email
    .EXAMPLE
        ./ServerTimeCheck.ps1 -AutoHeal -RunAdvancedFixes -Email
    .EXAMPLE
        ./ServerTimeCheck.ps1 -Email -NOPing
    .EXAMPLE
        ./ServerTimeCheck.ps1 -NOPing

#>



param(
    [switch]$RunAdvancedFixes = $false,
    [switch]$AutoHeal         = $false,
    [switch]$NOPing           = $false,
    [switch]$Email            = $false,
    [switch]$emailtargets     = "Email@Domain.com"
)

$pdc          = (nltest /dclist:$env:USERDOMAIN | findstr PDC).tostring().split(' ')[7]
$dnsroot      = (Get-ADDomain).dnsroot
$servers      = Get-ADComputer -Filter { operatingsystem -like 'windows server*' } -properties lastlogondate `
 | Where-Object { $_.lastlogondate -gt (get-date).adddays(-14) }

write-host -ForegroundColor Green "Got Servers from Active Directory!"


function autoHeal {
    param(
        $server,
        $OOS
    )
    Write-Host -ForegroundColor Yellow "Attempting to fix time..."

    w32tm /resync /Computer:$server 

    $stime  = (net time \\$($server) | findstr Current).tostring().split(' ')[6]
    $pdctm  = (net time \\$pdc | findstr Current).tostring().split(' ')[6]

    $tmdiff = [math]::Abs(((get-date $pdctm) - (get-date $stime) ).totalseconds)
    
    if (($tmdiff -lt 60) -and ($RunAdvancedFixes)) {
        Write-Host -ForegroundColor Yellow "Simple Sync didnt fix it moving on to advanced fix.."
        if ($server + $dnsroot -eq $pdc) {
            #this should never trigger but just in case...
            Write-Host -ForegroundColor BLUE "this is your PDC... you need to fix this manually..."
            return
        }

        $syncserv = w32tm /query /computer:$server /source

        if ($syncserv -ne $pdc) {
            Write-Host -ForegroundColor Yellow "Setting $server NTP source to $pdc"
            w32tm /config /computer:$server /syncfromflags:manual /manualpeerlist:"$pdc" /update
            Write-Host -ForegroundColor Green "Time Server: $(w32tm /query /computer:$server /source)"
        }
        Write-Host -ForegroundColor GREEN "Sending Resync command now..."
        w32tm /resync /Computer:$server    
    }


    $stime = (net time \\$($server) | findstr Current).tostring().split(' ')[6]
    $pdctm = (net time \\$pdc | findstr Current).tostring().split(' ')[6]

    $tmdiff = [math]::Abs(((get-date $pdctm) - (get-date $stime) ).totalseconds)
    
    if ($tmdiff -lt 60 ) {
        write-host -ForegroundColor Green "$server Time Fixed"
        if ($Email) {
            blat -subject "$($server) Time Was Out of Sync" -body "$server time was out of sync by $OOS seconds from $pdc
This has been fixed automatically!
Current $($server) time: $stime
Current $pdc time: $pdctm

Have a nice Day!
" -to $emailtargets
        }
    }
    else {
        write-host -ForegroundColor RED "$server Time Fix FAILED. Please fix manually"
        if ($Email) {
            blat -subject "$($server) Time Out of Sync" -body "$server time is out of sync by $tmdiff seconds from $pdc
This could NOT be fixed automatically!

Current $($server) time: $stime
Current $pdc time: $pdctm
" -to $emailtargets
        }
    }

    Write-Host -ForegroundColor Green "Email Sent"
    
}


foreach ($server in $servers) {
    try {
        $pings = $false
        if ($NOPing -eq $true) { $pings = $true }
        else {
            $pings = Test-Connection -ComputerName $server.name -Count 1 -ErrorAction Stop
        }

        if ($pings) {
            $stime = (net time \\$($server.name) | findstr Current).tostring().split(' ')[6]
            $pdctm = (net time \\$pdc | findstr Current).tostring().split(' ')[6]

            [pscustomobject]@{
                Computer = "$($server.name)"
                Time     = "$stime"
                PDC      = "$pdctm"
            }
            $tmdiff = [math]::Abs(((get-date $stime) - (get-date $pdctm) ).totalseconds)
            if (  $tmdiff -gt 60) {
                Write-Host -ForegroundColor YELLOW "$($server.name) Out of Sync with $pdc by $tmdiff Seconds."
                if ($AutoHeal) { autoHeal -server $server.name -OOS $tmdiff }
                elseif ($Email) {
                    blat -subject "$($server.name) Time Out of Sync" -to $emailtargets -body "$($server.name) Time is Out of Sync with $pdc by $tmdiff seconds.

This was an automated email. 
AutoHeal was not enabled when this script ran. To enable it use command with -Email flag. 
"
                }
            }


        }
    }
    catch {
        [pscustomobject]@{
            Computer = "$($server.name)"
            Time     = "UNAVAILABLE"
        }
    }
}


Write-Host -ForegroundColor GREEN "DC stats: "
w32tm /monitor