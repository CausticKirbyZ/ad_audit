$servers = Get-ADComputer -Filter { operatingsystem -like 'windows server*' } -properties lastlogondate | Where-Object { $_.lastlogondate -gt (get-date).adddays(-30) }
write-host -ForegroundColor Green "Got Servers from Active Directory!"
foreach ($server in $servers) {
    try {
        if (ping -n 1 $server.name) {
            $disks = Get-WmiObject win32_logicaldisk -computername $server.name -ErrorAction Stop `
            | add-member -MemberType ScriptProperty -Name FreeGB -Value { [int]($this.freespace / 1GB) } -PassThru `
            | Add-Member -MemberType ScriptProperty -name SizeGB { [int]($this.size / 1GB) } -PassThru `
            | Add-Member -MemberType ScriptProperty -Name PercentFree -Value { [int]($this.freespace / $this.size * 100) } -PassThru | Where-Object { $_.drivetype -eq 3 }

            foreach ($disk in $disks) {
                if ($disk.FreeGB -lt 15 ) {
                    # "{0}'s Disk {1} is {2:#.0}% full: {3:#.0}GB free of {4:#.0}GB" -f ($disk.systemname),($disk.name),(($disk.size - $disk.freespace)/$disk.size*100),($disk.freespace/1GB),($disk.size/1GB) | Write-Host 
                    $disk | Select-Object SystemName, Name, SizeGB, FreeGB, PercentFree
                }
            }
        }
    }
    catch {
        "{0} IS UNAVAILABLE" -f $server.name | Write-Host -ForegroundColor Red 
    }
}