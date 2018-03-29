<#
.SYNOPSIS
    Clears all Packages from the Configuration Manager Client Cache.
.DESCRIPTION
    Clears all Packages from the Configuration Manager Client Cache.
.EXAMPLE
    Clear-SCCMClientCache -computer CMP1
.NOTES
    Author: David O'Brien, david.obrien@sepago.de
    Version: 1.0
    Change history
        07.02.2013 - first release
        Requirements: installed ConfigMgr Agent on local machine
        v2 - Added computer and verbose(support) parameters
#>
function Clear-SCCMClientCache
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
        #Computer with SCCM client 
        [Parameter(ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $computer = $env:COMPUTERNAME
    )

    function Test-Verbose {
[CmdletBinding()]
param()
#https://www.briantist.com/how-to/test-for-verbose-in-powershell/
	[System.Management.Automation.ActionPreference]::SilentlyContinue -ne $VerbosePreference
}

$scriptBlock =
{
        $VerbosePreference='Continue'
        $UIResourceMgr = New-Object -ComObject UIResource.UIResourceMgr
        $Cache = $UIResourceMgr.GetCacheInfo()
        $free = $Cache.FreeSize
        $total = $Cache.TotalSize
        $CacheElements = $Cache.GetCacheElements()
        foreach ($Element in $CacheElements)
            {
                Write-Verbose "Deleting PackageID $($Element.ContentID) in $($Element.Location)" 4>&1
                $Cache.DeleteCacheElement($Element.CacheElementID)
            }

         $Cache = $UIResourceMgr.GetCacheInfo()
         $newFree = $Cache.FreeSize
         Write-Verbose "$(([system.math]::Round($total - ($free - $total / 1MB)))) MB cleared" 4>&1
          
    }


$out = Invoke-Command -ComputerName $computer -ScriptBlock $scriptBlock
    if (Test-Verbose)
        {
            $out 
        }

} #end of function 