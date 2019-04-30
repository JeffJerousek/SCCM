 $ErrorActionPreference = "Stop"   #Make all errors terminating
 $fail = $false

#Logging function
function Log 
{ param([string]$strMessage)
#$LogDir = [environment]::GetEnvironmentVariable("TEMP")
$LogDir = "C:"
$Logfile = "\BitLocker.txt"
$Path = $logdir + $logfile
[string]$strDate = get-date
add-content -path $Path -value ($strDate + "`t:`t"+ $strMessage)
}



try { 
#Make sure BitLocker is installed
Get-WmiObject -Namespace root\CIMV2\Security\MicrosoftVolumeEncryption -Query "SELECT * FROM Win32_EncryptableVolume Where DriveLetter='C:'"
}

catch {
 $fail = $true 
 Log ("Bitlocker software missing")
 EXIT 1
}


#check for TPM, isActivated, isEnabled -- TRue
$tpm = Get-WmiObject -Namespace root\CIMV2\Security\MicrosoftTPM -Query "SELECT * FROM Win32_TPM"
$IsActivated = $tpm.IsActivated().IsActivated
$IsEnabled = $tpm.IsEnabled().IsEnabled
$IsOwned = $tpm.IsOwned().IsOwned
$IsEndorsementKeyPairPresent = $tpm.IsEndorsementKeyPairPresent().IsEndorsementKeyPairPresent


if ($IsActivated -and $IsEnabled) 
{
Log("TPM is activated and enabled")
}
else 
{
        $fail = $true
        Log("TPM not active or not enabled")
        EXIT 1
        }

if ($IsEndorsementKeyPairPresent -eq $false)
{
$EndorsementResult = $tpm.CreateEndorsementKeyPair().ReturnValue
            Log ("Endorsement Key Pair does not exist....creating : " + (ErrDescription($EndorsementResult)))
}
else
{ 

Log ("Endorsement Key Pair exists....continuing")

    }


#start MBAM
$MBAM = Get-WmiObject -Namespace root\CIMV2 -Query "Select * from Win32_Service where name='MBAMAgent'"
#$b.StopService()
$MBAM.StartService()

Log ("Starting MBAM")

Start-Sleep -s 60 #wait for MBAM to start encryption



$loop = 0

Do 
{
    $status = Get-WmiObject -Namespace root\CIMV2\Security\MicrosoftVolumeEncryption -Query "SELECT * FROM Win32_EncryptableVolume Where DriveLetter='C:'"

    Log ("Encryption Percentage " + $status.GetConversionStatus().EncryptionPercentage)
    
    $loop++
    
    if ($loop -gt 300) {
    
    Log ("Encryption timedout")
    EXIT 1
    
    break}

    

    }

    while ($status.GetConversionStatus().ConversionStatus -ne 1)


  #  log("Adding tpm protector")
   # cmd /c manage-bde -protectors -add -tpm  C: 
    #cmd /c manage-bde -protectors -add -recoverypassword  C: 
    log("Starting BitLocker")
    cmd /c manage-bde -on C:
    log("Bitlocker Started")

Do {
        $escrow = get-winevent -LogName "microsoft-windows-MBAM/Operational" | Where-Object { $_.ID -eq 29 } | select -Last 1
            
        Start-Sleep -s 10 #wait for MBAM to escrow key
        }

while ( $escrow -eq $null)


$ErrorActionPreference = "Continue" #Make all errors back to normal 