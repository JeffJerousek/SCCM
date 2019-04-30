function Get-InstalledAppsSCCM {
[cmdletbinding()]  
Param(
    [Parameter(ValueFromPipeline=$True)]
    [string[]]$computerNames

    )

    Begin {
          if ($input -ne $null) 
          {get-
            $computerNames = $input
            }
            } # end Begin

    Process {

    foreach ($computerName in $computerNames) 
    {
        Get-WmiObject -Query "select * from CCM_Application" -ComputerName $computerName -Namespace root\ccm\clientsdk | select name, installstate #| Where-Object {$_.installstate -ne "Installed"}

        }
        }
        End 
        {
        }
        }