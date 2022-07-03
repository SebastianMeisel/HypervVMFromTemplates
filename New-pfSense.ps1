#requires -version 7.0

<#
.SYNOPSIS
Provision of a new Hyper-V virtual machine running pfSense.
.DESCRIPTION
This script will create a new Hyper-V virtual machine running pfSense.
It will download the ISO (gzipped) from the official source or use an
ISO you provide (after downlading it yourself).
images.

This script requires the Hyper-V-module 2.0 for PowerShell 7 or newer.
.PARAMETER Name
   A Name used for the VM.

.PARAMETER ComputerName
   You may specify the machine of the Hyper-V-server. It defaults to the local machine.
.EXAMPLE
   PS C:\Scripts\> .\New-VMFromISO FW1 
.NOTES
   Author: Sebastian Meisel
   Contact: sebastian.meisel@gmail.com
   Licence: GPLv3 (https://www.gnu.org/licenses/gpl-3.0.en.html)

.LINK
New-VM
Set-VM
https:\\pfsense.org
#>
[cmdletbinding(SupportsShouldProcess)]

Param(
[Parameter(Position=0,Mandatory)]
[string]$Name,
[Alias('cn')]
[System.String[]]$ComputerName=$env:COMPUTERNAME
)

$HV_path = "C:\\Users\User\HyperV"
$Url = "https://frafiles.netgate.com/mirror/downloads/pfSense-CE-2.6.0-RELEASE-amd64.iso.gz"
$image = "$($HV_path)\ISO\pfSense.iso"
$vmswitch1 = "WAN"
$vmswitch2 = "LAN"
$disk="$($HV_path)/VHD/$($Name).vhdx"
$disk_size = 10GB 
$cpu = 1 
$ram = 2GB

if ( ! $(Test-Path $($image))   )
{
  Try{
	Invoke-WebRequest -Uri $Url -OutFile $image && Write-Verbose '.'
  }
  Catch{
    Write-Warning "Failed to Download $image from $Url."
    Write-Warning $_.Exception.Message
    #bail out
    Write-Host -NoNewLine "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Return
  }
}

Try{
  New-VM  $Name -SwitchName $vmswitch1
}
Catch{
  Write-Warning "Failed to create VM $Name and/or connect it to Switch $vmswitch."
  Write-Warning $_.Exception.Message
  #bail out
  Write-Host -NoNewLine "Press any key to continue..."
  $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
  Return
}

Try{
  Set-VM $Name -ProcessorCount $cpu -MemoryStartupBytes $ram 
}
Catch{
  Write-Warning "Failed to allocate $cpu CPU-Cores and/or $ram of RAM to $Name."
  Write-Warning $_.Exception.Message
  #bail out
  Write-Host -NoNewLine "Press any key to continue..."
  $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
  Return
}

Try{
    Add-VMNetworkAdapter -SwitchName $($vmswitch2) -VMName $Name -Name "Second"
}
Catch{
    Write-Warning "Failed to add second Switch $($vmswitch2)."
    Write-Warning $_.Exception.Message
    #bail out
    Write-Host -NoNewLine "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Return
}

Try{
  if ( ! $(Test-Path $disk) ){
      New-VHD -Path $disk -SizeBytes $disk_size
  }
  Add-VMHardDiskDrive -VMName $Name -Path $disk
}  
Catch{
  Write-Warning "Failed to create $disk or to add it to $Name."
  Write-Warning $_.Exception.Message
  #bail out
  Write-Host -NoNewLine "Press any key to continue..."
  $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
  Return
}

Try{
  Set-VMDvdDrive -VMName $Name -Path $image
}
Catch{
  Write-Warning "Failed to allocate ISO $image."
  Write-Warning $_.Exception.Message
  #bail out
  Write-Host -NoNewLine "Press any key to continue..."
  $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
  Return
}

Try{
  Start-VM $Name
}
Catch{
  Write-Warning "Failed to start $Name."
  Write-Warning $_.Exception.Message
  #bail out
  Write-Host -NoNewLine "Press any key to continue..."
  $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
  Return
}
Try{
  $VM = Get-VM $Name
  vmconnect.exe $ComputerName $Name 
}
Catch{
  Write-Warning "Failed to connect to $Name."
  Write-Warning $_.Exception.Message
  #bail out
  Write-Host -NoNewLine "Press any key to continue..."
  $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
  Return
}
Write-Host -NoNewLine "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Return
