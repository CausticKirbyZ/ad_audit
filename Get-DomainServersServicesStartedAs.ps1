$hosts = Get-ADComputer -filter {operatingsystem -like 'windows server*'} 
# Remove-Item "Enviornment_Services.csv"
foreach($hostname in $hosts)
{
    Get-WmiObject -Class win32_service -ComputerName $hostname.name -ErrorAction Ignore  |  Select-Object SystemName,Name,StartName,StartMode `
    # | where {$_.StartName -like ''}`
    # | export-csv "Enviornment_Services.csv" -Append
}
