
    param (
        $ComputerName = $env:COMPUTERNAME,
        $StartDate=((get-date).AddDays(-1)).date,
        $EndDate=(get-date).date,
        $OutFile="$env:COMPUTERNAME`_Login_events.csv"
    )

    # Set-Item WSMan:\localhost\Shell\MaxMemoryPerShellMB 4000

    # Grab the events
    write-host -ForegroundColor green "Getting Events..."
    $Events = Get-WinEvent -ComputerName $ComputerName -FilterHashtable @{Logname='Security';StartTime=$StartDate;EndTime=$EndDate}
    Write-Host -ForegroundColor green "Got Events!!"

    Write-Host -ForegroundColor green "Now Parsing..."
    # Parse out the event message data        
    ForEach ($Event in $Events) {            
    # Convert the event to XML     
    $eventXML = [xml]$Event.ToXml()
    # Iterate through each one of the XML message properties            
    For ($i=0; $i -lt $eventXML.Event.EventData.Data.Count; $i++) {
        # Append these as object properties            
        Add-Member -InputObject $Event -MemberType NoteProperty -Force `
            -Name  $eventXML.Event.EventData.Data[$i].name `
            -Value $eventXML.Event.EventData.Data[$i].'#text'
        }
    }
    Write-Host -ForegroundColor green "Parsing Complete!!"
    # Write-Host -ForegroundColor green "Writeing to $OutFile"
    # $Events | select TimeCreated,TargetUserName,WorkstationName,LogonType,Id,ProcessName,IpPort,IpAddress | Export-csv "OutFile"
    $Events  | Select-Object TimeCreated,TargetUserName,WorkstationName,LogonType,Id,ProcessName,IpPort,IpAddress | Where-Object LogonType -in (2,7,10) | Format-Table
    # $Events | select -last 1