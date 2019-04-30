function Invoke-CmAppAction
{
    param(
        [string]$ComputerName = $env:COMPUTERNAME,
        [ValidateSet('Install','Uninstall')][string]$Action = 'Install'
    )

    [hashtable]$params = @{
        ComputerName = $ComputerName
        Namespace = 'root\CCM\ClientSDK'
        Class = 'CCM_Application'
    }

    [array]$apps = @(Get-WmiObject @params -Filter "ApplicabilityState = 'Applicable'" -ErrorAction Stop)

    if ($apps.Length -eq 0) {
        throw 'No apps available.'
    }
    else {
        $selection = $apps |select Publisher,Name,SoftwareVersion,InstallState,@{Name='ReleaseDate';Expression={$_.ConvertToDateTime($_.ReleaseDate).ToShortDateString()}},Id -Unique `
        |sort Name | Out-GridView -Title "$ComputerName`: Select App to $Action" -PassThru

        if (-not $selection) {
            Write-Error  "No selection made."
        }
        elseif ($selection -is [array]) {
            throw 'Only one selection is allowed.'
        }
        else {
            [psobject]$app = $apps | where { $_.Id -eq $selection.Id } | select Id,Name,Revision,IsMachineTarget -First 1

            [int]$code = Invoke-WmiMethod @params -Name $Action -ArgumentList @(0, $app.Id, $app.IsMachineTarget, $false, 'High', $app.Revision) | select -ExpandProperty ReturnValue

            $action = $action.ToLower()
            if ($code -ne 0) {
                throw "Error invoking $action of '$($app.Name)' ($code)."
            }
            else {
                "Successfully invoked $action of '$($app.Name)'."
            }
        }
    }
}

