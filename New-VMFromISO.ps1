#requires -version 7.0

<#
.SYNOPSIS
Provision a new Hyper-V virtual machine based on a ISO-image
.DESCRIPTION
This script will create a new Hyper-V virtual machine based on a ISO-image.
You may offer an url to download a new Version or use the already downloaded
images.

This script requires the Hyper-V-module 2.0 for PowerShell 7 or newer.
.PARAMETER Name
   A Name used for the VM.
.PARAMETER ISO
   Name of the ISO-image in the ISO-subdirectory.
   If Url is given, it's the (short) name by which the ISO-image is saved.
.PARAMETER Url
   Url of the ISO-image to download. Once you have downloaded it, you can reuse it.
.PARAMETER ChkSum
   You may provide a sha-256-checksum to verify the ISO-image.
.PARAMETER ComputerName
   You may specify the machine of the Hyper-V-server. It defaults to the local machine.
.EXAMPLE
   PS C:\Scripts\> .\New-VMFromISO Ubuntu1 -ISO Ubuntu
.NOTES
   Author: Sebastian Meisel
   Contact: sebastian.meisel@gmail.com
   Licence: GPLv3 (https://www.gnu.org/licenses/gpl-3.0.en.html)

.LINK
New-VM
Set-VM
#>
[cmdletbinding(SupportsShouldProcess)]

Param(
[Parameter(Position=0,Mandatory)]
[string]$Name,
[ArgumentCompleter( {
    param ($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
    $Completions = @()
    $Candidates = $(Get-ChildItem -Path '.\ISO\*.iso' -File | Select-Object -Property Name | Where-Object {$_.Name -like "*$($WordToComplete)*" })
    ForEach ( $Candidate in $Candidates ){
        $Completions += $Candidate.Name.Split('_')[0]
    }
    return $Completions
} )][string]$ISO,
[string]$Url,
#[Parameter(HelpMessage="Sha-256 Checksumme (Hash) für einen ISO-Download")]
[string]$ChkSum,
[Alias('cn')]
[System.String[]]$ComputerName=$env:COMPUTERNAME
)

$HV_path = "C:\\Users\User\HyperV"
$image = "$($HV_path)\ISO\$($ISO).iso"
$vmswitch = "WAN" 
$disk="$($HV_path)/VHD/$($Name).vhdx"
$disk_size = 10GB 
$cpu = 1 
$ram = 2GB

# Check if Image is there or download it
if ( $Url  )
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

# Check if Image is there or download it
if ( $ChkSum  )
{
  Try{
	return $(Get-FileHash $image -Algorithm SHA256).Hash.ToUpper() `
                             -eq "$($ChkSum).ToUpper()" 
  }
  Catch{
    Write-Warning "Failed to verify $image from $Url."
    Write-Warning $_.Exception.Message
    #bail out
    Write-Host -NoNewLine "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Return
  }
}

Try{
  New-VM  $Name -SwitchName $vmswitch
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
  vmconnect.exe $ComputerName $Name -G $VM.Id 
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
