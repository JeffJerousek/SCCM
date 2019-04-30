Function Get-SCCMCacheLoc
{
[CmdletBinding()]
 
Param(
 
[Parameter(Mandatory=$true,Position=1,HelpMessage="Package ID")]
 
[ValidateNotNullOrEmpty()]
 
[string]$PackageID
 
)
 

 
$CMObject = New-Object -ComObject 'UIResource.UIResourceMgr'
 
$CMCacheObjects = $CMObject.GetCacheInfo()
 
$OSUpgradeContent = $CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentID -eq "$PackageID"}
 
$ContentVersion = $OSUpgradeContent.ContentVersion
 
$HighestContentID = $ContentVersion | measure -Maximum
 
$NewestContent = $OSUpgradeContent | Where-Object {$_.ContentVersion -eq $HighestContentID.Maximum}
 
$NewestContent.Location
}