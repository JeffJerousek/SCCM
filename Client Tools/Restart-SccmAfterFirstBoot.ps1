$principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument '-command "start-sleep 10; restart-service ccmexec; Unregister-ScheduledTask -TaskName RestartSCCM -Confirm:$false"'
$trigger =  New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "RestartSCCM" -Description "Restart SCCM" -Principal $principal