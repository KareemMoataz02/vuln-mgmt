# Enable audit policies for SOC telemetry (failed logons, PowerShell script block)
auditpol /set /subcategory:'Logon' /success:enable /failure:enable
auditpol /set /subcategory:'Logoff' /success:enable /failure:enable
auditpol /set /subcategory:'Other Logon/Logoff Events' /success:enable /failure:enable
auditpol /set /subcategory:'Process Creation' /success:enable /failure:enable
auditpol /set /subcategory:'PowerShell Script Block Logging' /success:enable /failure:enable

# Create scheduled task to simulate "bad behavior" (failed logons, suspicious PowerShell)
$script = @'
# Simulate failed logons (triggers 4625 events)
$users = @('baduser','admin','root','test')
foreach ($u in $users) { net use \\invalid\share /user:$u wrongpass 2>$null }
# Simulate suspicious PowerShell (encoded command)
$enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes('Write-Host "simulation"'))
powershell -EncodedCommand $enc 2>$null
'@
New-Item -Path C:\temp -ItemType Directory -Force | Out-Null
Set-Content -Path C:\temp\simulate.ps1 -Value $script -Force
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -WindowStyle Hidden -File C:\temp\simulate.ps1'
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(15) -RepetitionInterval (New-TimeSpan -Hours 2)
Register-ScheduledTask -TaskName 'SOC-Simulation' -Action $action -Trigger $trigger -Description 'Lab: generates telemetry' -Force
