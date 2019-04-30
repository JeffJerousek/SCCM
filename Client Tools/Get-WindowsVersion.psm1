function Get-WindowsVersion {  
<#    
.SYNOPSIS    
    List Windows Version from computer.  
    
.DESCRIPTION  
    List Windows Version from computer. 
     
.PARAMETER ComputerName 
    Name of server to list Windows Version from remote computer.

.PARAMETER SearchBase 
    AD-SearchBase of server to list Windows Version from remote computer.
                         
.NOTES    
    Name: Get-WindowsVersion.psm1 
    Author: Johannes Sebald
    Version: 1.2.1
    DateCreated: 2016-09-13
    DateEdit: 2016-09-14
            
.LINK    
    http://www.dertechblog.de

.EXAMPLE    
    Get-WindowsVersion
    List Windows Version on local computer.
.EXAMPLE    
    Get-WindowsVersion -ComputerName pc1
    List Windows Version on remote computer.   
.EXAMPLE    
    Get-WindowsVersion -ComputerName pc1,pc2
    List Windows Version on multiple remote computer.  
.EXAMPLE    
    Get-WindowsVersion -SearchBase "OU=Computers,DC=comodo,DC=com"
    List Windows Version on Active Directory SearchBase computer. 
.EXAMPLE    
    Get-WindowsVersion -ComputerName pc1,pc2 -Force
    List Windows Version on multiple remote computer and disable the built-in Format-Table and Sort-Object by ComputerName.                         
#>  
    [cmdletbinding()]
    param (
    [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
    [string[]]$ComputerName = "localhost",
    [string]$SearchBase,
    [switch]$Force
    )

    if($SearchBase)
    {
        if(Get-Command Get-AD* -ErrorAction SilentlyContinue)
            {
                if(Get-ADOrganizationalUnit -Filter "distinguishedName -eq '$SearchBase'" -ErrorAction SilentlyContinue)
                    {
                        $Table = Get-ADComputer -SearchBase $SearchBase -Filter *
                        $ComputerName = $Table.Name
                    }
                else{Write-Warning "No SearchBase found"}
            }
        else{Write-Warning "No Active Directory cmdlets found"}
    }

    # Parameter Force
    if(-not($Force)){$tmp = New-TemporaryFile}

    foreach ($Computer in $ComputerName) 
        {
            if(Test-Connection -ComputerName $Computer -Count 1 -ea 0)
                { 
                    if(Get-Item -Path "\\$Computer\c$" -ErrorAction SilentlyContinue)
                        {                    
                            # Variables
                            $WMI = [WmiClass]"\\$Computer\root\default:stdRegProv"
                            $HKLM = 2147483650
                            $Key = "SOFTWARE\Microsoft\Windows NT\CurrentVersion"

                            $ValueName = "CurrentMajorVersionNumber"
                            $Major = $WMI.GetDWordValue($HKLM,$Key,$ValueName).UValue

                            $ValueName = "CurrentMinorVersionNumber"
                            $Minor = $WMI.GetDWordValue($HKLM,$Key,$ValueName).UValue

                            $ValueName = "CurrentBuildNumber"
                            $Build = $WMI.GetStringValue($HKLM,$Key,$ValueName).sValue

                            $ValueName = "UBR"
                            $UBR = $WMI.GetDWordValue($HKLM,$Key,$ValueName).UValue

                            $ValueName = "ReleaseId"
                            $ReleaseId = $WMI.GetStringValue($HKLM,$Key,$ValueName).sValue

                            $ValueName = "ProductName"
                            $ProductName = $WMI.GetStringValue($HKLM,$Key,$ValueName).sValue

                            $ValueName = "ProductId"
                            $ProductId = $WMI.GetStringValue($HKLM,$Key,$ValueName).sValue

                            # Variables for Windows 6.x
                            if($Major.Length -le 0)
                                {
                                    $ValueName = "CurrentVersion"
                                    $Major = $WMI.GetStringValue($HKLM,$Key,$ValueName).sValue 
                                }
                            
                            if($ReleaseId.Length -le 0)
                                {
                                    $ValueName = "CSDVersion"
                                    $ReleaseId = $WMI.GetStringValue($HKLM,$Key,$ValueName).sValue 
                                }

                            # Add Points
                            if(-not($Major.Length -le 0)){$Major = "$Major."}
                            if(-not($Minor.Length -le 0)){$Minor = "$Minor."}
                            if(-not($UBR.Length -le 0)){$UBR = ".$UBR"}

                            # Table Output
                            $OutputObj = New-Object -TypeName PSobject
                            $OutputObj | Add-Member -MemberType NoteProperty -Name ComputerName -Value $Computer.toUpper()
                            $OutputObj | Add-Member -MemberType NoteProperty -Name ProductName -Value $ProductName
                            $OutputObj | Add-Member -MemberType NoteProperty -Name WindowsVersion -Value $ReleaseId
                            $OutputObj | Add-Member -MemberType NoteProperty -Name WindowsBuild -Value "$Major$Minor$Build$UBR"
                            $OutputObj | Add-Member -MemberType NoteProperty -Name ProductId -Value $ProductId
                            
                            # Parameter Force
                            if(-not($Force)){$OutputObj | Export-Csv -Path $tmp -Append}else{$OutputObj}
                        }
                    else
                        {            
                            Write-Warning "$Computer no access"       
                        } 
                }
            else
                {            
                    Write-Warning "$Computer not reachable"       
                } 
        }

        # Parameter Force
        if(-not($Force))
            {                            
                Import-Csv -Path $tmp | Sort-Object -Property ComputerName | Format-Table -AutoSize
                Remove-Item $tmp -Force -ErrorAction SilentlyContinue
            }
    }