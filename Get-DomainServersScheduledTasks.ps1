$servers = Get-ADComputer -Filter {operatingsystem -like 'windows server*'}

foreach ($server in $servers){
    Write-Host "Querying"$server.name
    if (Test-Connection -ComputerName $server.name -Count 1 -Quiet)
    {
        $hostname = $server.name
        schtasks /query /s $hostname /V /FO csv | ConvertFrom-csv `
            | Select-Object HostName,TaskName,'Logon Mode','Author','Task To Run', 'Run As User',Comment `
            # | Export-Csv "Scheduled_Tasks.csv" -Append
    }
    else {
        write-host -ForegroundColor RED $server.name"Is Not Available."
    }
}
