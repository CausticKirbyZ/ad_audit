####################################################################################
# Generate_AD_Last_Update_Report.ps1                                               #
# by Mike Hedlund                                                                  #
# github: https://github.com/caustickirbyz/ad_audit/Generate_AD_Last_Update_Report #
#                                                                                  #
# simple script using wmi to get the most recent update from computers in          #
# Active Directory.                                                                #
# Outputs to $Filepath and logs errors to error-log.txt                            #
####################################################################################

param(
    $dc="dc1",
    $exportpath = @(get-location), 
    $Filepath = "AD_Latest_Update_Report.csv"
)


function QueryComputers {
    param (
        $DomainController,
        $Path,
        $Like
    )
    $sb = {
        param($server, $exportpath, $path)

        $mtx = New-Object System.Threading.Mutex($false, "Mutex")
        $mtx_log = New-Object System.Threading.Mutex($false, "MutexLog")
        
        try {
            if (ping $server 2){
                $Server_Results = Get-WmiObject -ComputerName $server win32_quickfixengineering -ErrorAction Stop | Sort-Object InstalledOn -desc -ErrorAction SilentlyContinue | Select-Object -First 1 
                $mtx.WaitOne()
                $Server_Results | Export-Csv $exportpath\$path -Append
                $mtx.releaseMutex()
            }
            else {
                Write-Host -ForegroundColor red "Error on "$server"-> writing to log"
                $mtx_log.WaitOne()
                $server | Out-File $exportpath\error-log.txt -Append
                $mtx_log.ReleaseMutex()
            }
        }
        catch {
            Write-Host -ForegroundColor red "Error on "$server"-> writing to log"
            $mtx_log.WaitOne()
            $server | Out-File $exportpath\error-log.txt -Append
            $mtx_log.ReleaseMutex()            
        }
    }


    Write-Host -ForegroundColor Yellow "Getting `"$Like`" Machines..."
    $serverlist = Get-ADComputer -filter {OperatingSystem -Like $Like} -Properties name,operatingsystem -Server $DomainController | Select-Object Name | Sort-Object Name

    write-Host -ForegroundColor Green "'$Like' Total Count: "$serverlist.count

    Write-Host -ForegroundColor Yellow "Querying `"$Like`" Machines..."



    foreach ($server in $serverlist) {
        # Write-Host  -ForegroundColor Yellow "Querying: "$server.name
        start-job -scriptblock $sb -ArgumentList $server.name, $exportpath, $Path -Name $server.name
    }

    get-job | wait-job
    get-job | receive-job
}

#clear jobs
write-Host "Current Running Jobs: "(get-job).count
write-Host "Stoping Running Jobs..."
get-job | Stop-Job 
get-job | remove-job

write-Host "Clearing previous results..."
if(test-path $exportpath\$Filepath) {
    remove-item $Filepath
}
if(test-path $exportpath\error-log.txt) {
    remove-item error-log.txt 
}

write-Host -ForegroundColor green "CLEARED!"

write-Host -ForegroundColor green "Starting update enumeration: "


QueryComputers -domaincontroller $dc -Path $Filepath -Like "Windows Server*"
write-Host -ForegroundColor green "'Windows Server*' enumeration finished!"
pause

QueryComputers -domaincontroller $dc -Path $Filepath -Like "Windows xp*"
write-Host -ForegroundColor green "'Windows xp*' enumeration finished!"
pause

QueryComputers -domaincontroller $dc -Path $Filepath -Like "Windows vista*"
write-Host -ForegroundColor green "'Windows Vista*' enumeration finished!"
pause

QueryComputers -domaincontroller $dc -Path $Filepath -Like "Windows 7*"
write-Host -ForegroundColor green "'Windows 7*' enumeration finished!"
pause

QueryComputers -domaincontroller $dc -Path $Filepath -Like "Windows 8*"
write-Host -ForegroundColor green "'Windows 8*' enumeration finished!"
pause

QueryComputers -domaincontroller $dc -Path $Filepath -Like "Windows 10*"
write-Host -ForegroundColor green "'Windows 10*' enumeration finished!"
pause

