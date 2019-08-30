$servers = (Get-ADComputer -Filter { operatingsystem -like "windows server*" } | Where-Object { $_.lastlogondate -ge (Get-Date).AddDays(-6).name }).name

foreach ($server in $servers) {
    try {
        if (ping -t 1 $server) {
            Get-WmiObject -class win32_networkadapterconfiguration -ComputerName $server -ErrorAction Stop `
            | Where-Object { $_.ipenabled -eq $true } | Select-Object __server, DHCPEnabled, IPAddress, IpSubnet, DefaultIPGateway
        }
        else {
            Write-Host -ForegroundColor RED "$server could not ping"
        }
    }
    catch {
        write-host -ForegroundColor RED "$server rpc not responding..."
    }
}