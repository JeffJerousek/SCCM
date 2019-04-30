Function Get-ServiceWindowsInfo {
<#GARYTOWN.COM 
Twitter: @gwblok
Get Service Windows Info, Delete if you like
2018.09.02

This Script will Return all Service Windows, Allow you to specifiy if you want to delete 
Local or Remote, as well as let you know if there are any mentions in the execmgr log that 
service windows are too restrictive to run a deployment.

Logs locally (ccm\logs\scriptsnode.log and on Server if you set ScriptLogging to True (Which is the Default)

#>

[CmdletBinding()]
Param (
    #Logs to Network (Make sure you update the Server Share info)
    [Parameter(Mandatory=$false)][ValidateSet("True","False")][string] $ScriptLogging = "True",
    #Delete SWs that are Local, Type 1-5 (not 6)
    [Parameter(Mandatory=$false)][ValidateSet("True","False")][string] $DeleteLocalWindows = "False",
    #Delete SWs that are Collection (Server) Created
    [Parameter(Mandatory=$false)][ValidateSet("True","False")][string] $DeleteServerWindows = "False",
    #Deletes them all, big hammer approach, get windows and delete ALL
    [Parameter(Mandatory=$false)][ValidateSet("True","False")][string] $DeleteEverything = "False",
    #Deletes the Windows ONLY if an Error was found
    [Parameter(Mandatory=$false)][ValidateSet("True","False")][string] $DeleteOnlyIfErrorFound = "True"
      )


#region: CMTraceLog Function formats logging in CMTrace style (If Running as System, write to Network Share)
if ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name -eq "NT AUTHORITY\SYSTEM"){$RunningAsSystem = "True"}


#If Parameter for Logging Enabled, setup variables for where to log to
if ($ScriptLogging -eq "True")
    {
    $TargetRootLocal = 'C:\windows\ccm\logs'
    $LocalLogFile = "$TargetRootLocal\ScriptsNode.log"
    $TargetRoot = '\\src\src$\Logs'
    $LogID = "ScriptsNodeLogs\GeneralScripts\$env:ComputerName"
    $ServerLogFile = "$TargetRoot\$LogID\ScriptsNode-$env:ComputerName.log"
    }

#If Logging enabled & script running in System Context, make sure Log folder on Server is there, or make it.
if ($RunningAsSystem -eq "True" -and $ScriptLogging -eq "True")
    {
    write-verbose "Create Target $TargetRoot\$LogID"
    new-item -itemtype Directory -Path $TargetRoot\$LogID -force -erroraction SilentlyContinue | out-null 
    }

#region: CMTraceLog Function formats logging in CMTrace style (but to Server) 
#CMTraceLog Function stolen from @EphingPosh https://www.ephingadmin.com/powershell-cmtrace-log-function/
   function CMTraceLog {
         [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)]
		    $Message,
 
		    [Parameter(Mandatory=$false)]
		    $ErrorMessage,
 
		    [Parameter(Mandatory=$false)]
		    $Component = $env:computername,
 
		    [Parameter(Mandatory=$false)]
		    [int]$Type,
		
		    [Parameter(Mandatory=$true)]
		    $ServerLogFile

            #[Parameter(Mandatory=$true)]
		    #$LocalLogFile
	    )
    <#
    Type: 1 = Normal, 2 = Warning (yellow), 3 = Error (red)
    #>
	    $Time = Get-Date -Format "HH:mm:ss.ffffff"
	    $Date = Get-Date -Format "MM-dd-yyyy"
 
	    if ($ErrorMessage -ne $null) {$Type = 3}
	    if ($Component -eq $null) {$Component = " "}
	    if ($Type -eq $null) {$Type = 1}
 
	    $LogMessage = "<![LOG[$Message $ErrorMessage" + "]LOG]!><time=`"$Time`" date=`"$Date`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"`" file=`"`">"
        Write-Host "$Message $ErrorMessage"
        if ($RunningAsSystem -eq "True" -and $ScriptLogging -eq "True"){$LogMessage | Out-File -Append -Encoding UTF8 -FilePath $ServerLogFile}
        if ($ScriptLogging -eq "True"){$LogMessage | Out-File -Append -Encoding UTF8 -FilePath $LocalLogFile}
         
    }


function FindServiceWindowRestrictions
{
    #Check execmgr.log file for the string about Service Window Restrictions.  
    
    $errorTable = @(
    [pscustomobject]@{ Name = 'Service Window restrictions'; File = 'c:\windows\ccm\Logs\execmgr*.log'; Search = 'The program may never run because of Service Window restrictions.' }
    )

    foreach ( $ErrorItem in $ErrorTable ) {

        if ($ScriptLogging -eq "True"){CMTraceLog -Message  "Check for $($ErrorItem.Name)" -Type 1 -ServerLogFile $ServerLogFile}
        if ( test-path $errorItem.File ) { 
            if ($ScriptLogging -eq "True"){CMTraceLog -Message  "Check for $($errorItem.File)" -Type 1 -ServerLogFile $ServerLogFile}
            type $errorItem.File |
                Select-String -Pattern $ErrorItem.Search |
                % { Write-Warning "[$env:ComputerName] Found Error $($ErrorItem.Name) : [$_]" }
            type $errorItem.File |
                Select-String -Pattern $ErrorItem.Search |
                % { if ($ScriptLogging -eq "True"){CMTraceLog -Message  "Found Error $($ErrorItem.Name) : [$_]" -Type 2 -ServerLogFile $ServerLogFile} }
            type $errorItem.File |
                Select-String -Pattern $ErrorItem.Search |
                % { $global:ErrorFound="True" }

        }

    }
}    
 


if ($ScriptLogging -eq "True"){CMTraceLog -Message  "----------Starting Delete Local Service Windows Script on: $env:computername----------" -Type 1 -ServerLogFile $ServerLogFile}

$OutputText = "Script was run in modes: `n     Logging: $ScriptLogging `n     Reporting Windows: $ReportWindows `n     Delete Local Windows: $DeleteLocalWindows `n     Delete Collection Windows: $DeleteServerWindows `n     Delete All SWs: $DeleteEverything `n     Delete Only if Error Fund: $DeleteOnlyIfErrorFound"
if ($RunningAsSystem -eq "True" -and $ScriptLogging -eq "True"){CMTraceLog -Message  $OutputText -Type 1 -ServerLogFile $ServerLogFile}

FindServiceWindowRestrictions

$LocalServiceWindows = Get-WMIObject -Namespace 'ROOT\ccm\Policy\Machine\RequestedConfig' -Query 'SELECT * FROM CCM_ServiceWindow WHERE PolicySource = "Local" '
foreach ($LocalSW in $LocalServiceWindows)
    {      
    $LocalServiceWindowID = ("ID: " + ($LocalSW).ServiceWindowID + "  Type: " + ($LocalSW).ServiceWindowType)
    $OutputText = "Machine has Local Service Windows: $LocalServiceWindowID"
    if ($ScriptLogging -eq "True"){CMTraceLog -Message  $OutputText -Type 1 -ServerLogFile $ServerLogFile}    
    }    
$ServerServiceWindows = Get-WMIObject -Namespace 'ROOT\ccm\Policy\Machine\RequestedConfig' -Query 'SELECT * FROM CCM_ServiceWindow WHERE (ServiceWindowType = "1") or (ServiceWindowType = "5") AND PolicySource <> "Local" '
foreach ($ServerSW in $ServerServiceWindows)
    {
    $ServerServiceWindowsID = ("ID: " + ($ServerSW).ServiceWindowID + "  Type: " + ($ServerSW).ServiceWindowType)
    $OutputText = "Machine has Server Service Windows: $ServerServiceWindowsID"
    if ($ScriptLogging -eq "True"){CMTraceLog -Message  $OutputText -Type 1 -ServerLogFile $ServerLogFile}    
        }        
    if ($ErrorFound -eq "True")
    {
    $OutputText= "Machine has too restrictive of MWs to run Deployments (According to current execmgr logs)"
    if ($ScriptLogging -eq "True"){CMTraceLog -Message  $OutputText -Type 2 -ServerLogFile $ServerLogFile}    
    }
Else
    {
    $OutputText = "Machine has no SWs that are too restrictive (According to current execmgr logs)"
    
    if ($ScriptLogging -eq "True"){CMTraceLog -Message  $OutputText -Type 1 -ServerLogFile $ServerLogFile}    
    }       
     
                       

if ($ErrorFound -eq "True" -and $DeleteOnlyIfErrorFound -eq "True")
    {
    $OutputText = "Machine has too restrictive of MWs, Moving ahead with Delete Section of Script"
    if ($ScriptLogging -eq "True"){CMTraceLog -Message  $OutputText -Type 1 -ServerLogFile $ServerLogFile}    
    
    if ($DeleteLocalWindows -eq "True")
        {
        $LocalServiceWindows = Get-WMIObject -Namespace 'ROOT\ccm\Policy\Machine\RequestedConfig' -Query 'SELECT * FROM CCM_ServiceWindow WHERE (ServiceWindowType = "1") or (ServiceWindowType = "2") or (ServiceWindowType = "3") or (ServiceWindowType = "4") or (ServiceWindowType = "5") AND PolicySource = "Local" '
        if ($LocalServiceWindows -ne $Null)
            {
            foreach ($LocalSW in $LocalServiceWindows)
                {
                    $LocalServiceWindowID = ("ID: " + ($LocalSW).ServiceWindowID + "  Type: " + ($LocalSW).ServiceWindowType)
                    $OutputText = "Machine has Local Service Windows: $LocalServiceWindowID"
                    if ($ScriptLogging -eq "True"){CMTraceLog -Message $OutputText -Type 1 -ServerLogFile $ServerLogFile}    
                }
            $LocalServiceWindows | Remove-WmiObject
            #Confirm They are Gone
            $LocalServiceWindows = Get-WMIObject -Namespace 'ROOT\ccm\Policy\Machine\RequestedConfig' -Query 'SELECT * FROM CCM_ServiceWindow WHERE (ServiceWindowType = "1") or (ServiceWindowType = "2") or (ServiceWindowType = "3") or (ServiceWindowType = "4") or (ServiceWindowType = "5") AND PolicySource = "Local" '
            if ($LocalServiceWindows -eq $Null)
                {
                $OutputText = "Confirmed all Local Services Windows are Gone"
                if ($ScriptLogging -eq "True"){CMTraceLog -Message $OutputText -Type 1 -ServerLogFile $ServerLogFile} 
                }
            }
        }

    if ($DeleteServerWindows -eq "True")
        {
        $ServerServiceWindows = Get-WMIObject -Namespace 'ROOT\ccm\Policy\Machine\RequestedConfig' -Query 'SELECT * FROM CCM_ServiceWindow WHERE (ServiceWindowType = "1") or (ServiceWindowType = "5") AND PolicySource <> "Local" '
        if ($ServerServiceWindows -ne $Null)
            {
                foreach ($ServerSW in $ServerServiceWindows)
                {
                $ServerServiceWindowsID = ("ID: " + ($ServerSW).ServiceWindowID + "  Type: " + ($ServerSW).ServiceWindowType)
                $OutputText = "Machine has Server Service Windows: $ServerServiceWindowsID"
                if ($ScriptLogging -eq "True"){CMTraceLog -Message  $OutputText -Type 1 -ServerLogFile $ServerLogFile}  
                }
            $ServerServiceWindows | Remove-WmiObject    
            #Confirm They are Gone
            $ServerServiceWindows = Get-WMIObject -Namespace 'ROOT\ccm\Policy\Machine\RequestedConfig' -Query 'SELECT * FROM CCM_ServiceWindow WHERE (ServiceWindowType = "1") or (ServiceWindowType = "5") AND PolicySource <> "Local" '
            if ($ServerServiceWindows -eq $Null)
                {
                $OutputText = "Confirmed all Local Services Windows are Gone" 
                if ($ScriptLogging -eq "True"){CMTraceLog -Message  $OutputText -Type 1 -ServerLogFile $ServerLogFile} 
                }
    
            }
        }


    if ($DeleteEverything -eq "True")
        {
        $AllServiceWindows = Get-WMIObject -Namespace 'ROOT\ccm\Policy\Machine\RequestedConfig' -Query 'SELECT * FROM CCM_ServiceWindow'
        if ($AllServiceWindows  -ne $Null)
            {
            foreach ($AllSW in $AllServiceWindows)
                {
                $AllServiceWindowsID = ("ID: " + ($AllServiceWindows).ServiceWindowID + "  Type: " + ($AllServiceWindows).ServiceWindowType)
                $OutputText = "Machine has Local & Server Service Windows: $ServerServiceWindowsID"
                if ($ScriptLogging -eq "True"){CMTraceLog -Message  $OutputText -Type 1 -ServerLogFile $ServerLogFile}  
                }
            $AllServiceWindows | Remove-WmiObject
            #Confirm They are Gone
            $AllServiceWindows = Get-WMIObject -Namespace 'ROOT\ccm\Policy\Machine\RequestedConfig' -Query 'SELECT * FROM CCM_ServiceWindow'
            if ($AllServiceWindows -eq $Null)
                {
                $OutputText = "Confirmed all Local Services Windows are Gone"
                if ($ScriptLogging -eq "True"){CMTraceLog -Message $OutputText -Type 1 -ServerLogFile $ServerLogFile} 
                }
            }
        }
}
if ($DeleteOnlyIfErrorFound -ne "True")
    {
    $OutputText = "User Chose to Delete MWs (if Restriction exist or not) via Params, Moving ahead with Delete Section of Script and will delete any applicable MWs"
    
    if ($ScriptLogging -eq "True"){CMTraceLog -Message $OutputText -Type 1 -ServerLogFile $ServerLogFile}    
    
    if ($DeleteLocalWindows -eq "True")
        {
        $LocalServiceWindows = Get-WMIObject -Namespace 'ROOT\ccm\Policy\Machine\RequestedConfig' -Query 'SELECT * FROM CCM_ServiceWindow WHERE (ServiceWindowType = "1") or (ServiceWindowType = "2") or (ServiceWindowType = "3") or (ServiceWindowType = "4") or (ServiceWindowType = "5") AND PolicySource = "Local" '
        if ($LocalServiceWindows -ne $Null)
            {
            foreach ($LocalSW in $LocalServiceWindows)
                {
                $LocalServiceWindowID = ("ID: " + ($LocalSW).ServiceWindowID + "  Type: " + ($LocalSW).ServiceWindowType)
                $OutputText = "Machine has Local Service Windows: $LocalServiceWindowID"
                if ($ScriptLogging -eq "True"){CMTraceLog -Message $OutputText -Type 1 -ServerLogFile $ServerLogFile}    
                }
            $LocalServiceWindows | Remove-WmiObject
            #Confirm They are Gone
            $LocalServiceWindows = Get-WMIObject -Namespace 'ROOT\ccm\Policy\Machine\RequestedConfig' -Query 'SELECT * FROM CCM_ServiceWindow WHERE (ServiceWindowType = "1") or (ServiceWindowType = "2") or (ServiceWindowType = "3") or (ServiceWindowType = "4") or (ServiceWindowType = "5") AND PolicySource = "Local" '
            if ($LocalServiceWindows -eq $Null)
                {
                $OutputText = "Confirmed all Local Services Windows are Gone"
                if ($ScriptLogging -eq "True"){CMTraceLog -Message $OutputText -Type 1 -ServerLogFile $ServerLogFile} 
                }
            }
        }

    if ($DeleteServerWindows -eq "True")
        {
        $ServerServiceWindows = Get-WMIObject -Namespace 'ROOT\ccm\Policy\Machine\RequestedConfig' -Query 'SELECT * FROM CCM_ServiceWindow WHERE (ServiceWindowType = "1") or (ServiceWindowType = "5") AND PolicySource <> "Local" '
        if ($ServerServiceWindows -ne $Null)
            {
                foreach ($ServerSW in $ServerServiceWindows)
                {
                $ServerServiceWindowsID = ("ID: " + ($ServerSW).ServiceWindowID + "  Type: " + ($ServerSW).ServiceWindowType)
                $OutputText = "Machine has Server Service Windows: $ServerServiceWindowsID"
                if ($ScriptLogging -eq "True"){CMTraceLog -Message  $OutputText -Type 1 -ServerLogFile $ServerLogFile}  
                }
            $ServerServiceWindows | Remove-WmiObject    
            #Confirm They are Gone
            $ServerServiceWindows = Get-WMIObject -Namespace 'ROOT\ccm\Policy\Machine\RequestedConfig' -Query 'SELECT * FROM CCM_ServiceWindow WHERE (ServiceWindowType = "1") or (ServiceWindowType = "5") AND PolicySource <> "Local" '
            if ($ServerServiceWindows -eq $Null)
                {
                $OutputText = "Confirmed all Local Services Windows are Gone"
                if ($ScriptLogging -eq "True"){CMTraceLog -Message  $OutputText -Type 1 -ServerLogFile $ServerLogFile} 
                }
            }
        }


    if ($DeleteEverything -eq "True")
        {
        $AllServiceWindows = Get-WMIObject -Namespace 'ROOT\ccm\Policy\Machine\RequestedConfig' -Query 'SELECT * FROM CCM_ServiceWindow'
        if ($AllServiceWindows  -ne $Null)
            {
            foreach ($AllSW in $AllServiceWindows)
                {
                $AllServiceWindowsID = ("ID: " + ($AllServiceWindows).ServiceWindowID + "  Type: " + ($AllServiceWindows).ServiceWindowType)
                $OutputText = "Machine has Local & Server Service Windows: $ServerServiceWindowsID"
                if ($ScriptLogging -eq "True"){CMTraceLog -Message  $OutputText -Type 1 -ServerLogFile $ServerLogFile}  
                }
            $AllServiceWindows | Remove-WmiObject
            #Confirm They are Gone
            $AllServiceWindows = Get-WMIObject -Namespace 'ROOT\ccm\Policy\Machine\RequestedConfig' -Query 'SELECT * FROM CCM_ServiceWindow'
            if ($AllServiceWindows -eq $Null)
                {
                $OutputText = "Confirmed all Local Services Windows are Gone"
                if ($ScriptLogging -eq "True"){CMTraceLog -Message $OutputText -Type 1 -ServerLogFile $ServerLogFile} 
                }
            }
        }
}    

if ($ScriptLogging -eq "True"){CMTraceLog -Message  "----------Finished Delete Local Service Windows Script on: $env:computername----------" -Type 1 -ServerLogFile $ServerLogFile}

}
