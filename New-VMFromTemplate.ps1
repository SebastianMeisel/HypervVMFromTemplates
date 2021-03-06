#requires -version 7.0

<#
.SYNOPSIS
Provision a new Hyper-V virtual machine based on a template
.DESCRIPTION
This script will create a new Hyper-V virtual machine based on a template or
hardware profile. You can create a Small, Medium or Large virtual machine. All
virtual machines will use the same virtual switch and the same paths for the 
virtual machine and VHDX file. You can provide an ansible-playbook to configure
the Server. You can also enable a second (internal) switch.

This script requires the Hyper-V-module 2.0 for PowerShell 7 or newer.
.PARAMETER Name
   A Name used for the VM.

.PARAMETER VMConfiguration
You can choose between three configurations:
Small (default)
        MemoryStartup=512MB
        ProcCount=1
        MemoryMinimum=512MB
        MemoryMaximum=1GB

Medium
        MemoryStartup=512MB
        ProcCount=2
        MemoryMinimum=512MB
        MemoryMaximum=2GB

Large
        MemoryStartup=1GB
        ProcCount=4
        MemoryMinimum=512MB
        MemoryMaximum=4GB
.PARAMETER VMTemplate
   Name of one of the templates in the templates-subdirectory without the
   `_tmp.vhdx` extension.       
.PARAMETER Playbooks
   List of playbooks in the templates-subdirectory without the `yaml`-extensions,
   that you want to apply.
.PARAMETER LAN
  By default the VM is connected to the external virtual switch named "WAN".
  With this switch you can add an additional, internal switch named "LAN".
  All virtual switches must be configured beforehand.
.PARAMETER PRIV
  By default the VM is connected to the external virtual switch named "WAN".
  With this switch you can add an additional, private switch named "LAN".
  All virtual switches must be configured beforehand.
.PARAMETER Reboot
  Set this switch, when the VM shall reboot at the end of the installation process.
.PARAMETER Passthru
  With this switch set, the process is send to the background. You can do diffent
  things in the Powershell.
.EXAMPLE
PS C:\Scripts\> .\New-VMFromTemplate WEB2012-01 -VMTemplate Ubuntu -VMType Small -passthru

Name       State CPUUsage(%) MemoryAssigned(M) Uptime   Status
----       ----- ----------- ----------------- ------   ------
WEB2012-01 Off   0           0                 00:00:00 Operating normally
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
[ValidateSet("Small","Medium","Large")]
[string]$VMConfiguration = "Small",
[ArgumentCompleter( {
    param ($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
    $Completions = @()
    $Candidates = $(Get-ChildItem -Path '.\Templates\*_tmp.vhdx' -File | Select-Object -Property Name | Where-Object {$_.Name -like "*$($WordToComplete)*" })
    ForEach ( $Candidate in $Candidates ){
        $Completions += $Candidate.Name.Split('_')[0]
    }
    return $Completions
} )]
[string]$VMTemplate,
[ArgumentCompleter( {
    param ($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
    $Completions = @()
    $Candidates = $(Get-ChildItem -Path '.\ansible\*.yml' -File | Select-Object -Property Name | Where-Object {$_.Name -like "*$($WordToComplete)*"  -and ! ($_.Name.contains("update") -or $_.Name.contains("vault"))})
    ForEach ( $Candidate in $Candidates ){
        $Completions += $Candidate.Name.Split('.')[0]
    }
    return $Completions
} )]
[array]$Playbooks,
[switch]$LAN,
[switch]$PRIV,
[switch]$Reboot,
[switch]$Passthru
)

Write-Verbose "Creating new $VMConfiguration virtual machine"

# Path-Pr??fix
$Pre="C:\\Users\User\HyperV"

# allgemeine VM Parameter
$Switch = "WAN"
$Path = "$($Pre)\VM"
$TemplatePath = "$($Pre)\Templates\$($VMTemplate)_tmp.vhdx"
$VHDPath = "$($Pre)\VHD\$($name).vhdx"

# ansible Dateien 
$Ansible = "$($Pre)/ansible"

Switch ($VMConfiguration) {
"Small" {
$MemoryStartup=512MB
$ProcCount=1
$MemoryMinimum=512MB
$MemoryMaximum=1GB
}

"Medium" {
$MemoryStartup=512MB
$ProcCount=2
$MemoryMinimum=512MB
$MemoryMaximum=2GB
}

"Large" {
$MemoryStartup=1GB
$ProcCount=2
$MemoryMinimum=512MB
$MemoryMaximum=4GB
}
}

#define a hash table of parameters for New-VM
$newParam = @{
 Name=$Name
 SwitchName=$Switch
 MemoryStartupBytes=$MemoryStartup
 Path=$Path
 ErrorAction="Stop"
}

#define a hash table of parameters for Set-VM
$setParam = @{
 ProcessorCount=$ProcCount
 DynamicMemory=$True
 MemoryMinimumBytes=$MemoryMinimum
 MemoryMaximumBytes=$MemoryMaximum
 ErrorAction="Stop"
}

if ($Passthru) {
    $setParam.Add("Passthru",$True)
}
Try {
    Write-Verbose "Creating new virtual machine"
    Write-Verbose ($newParam | out-string)
    $VM = New-VM @newparam -NoVHD
}
Catch {
    Write-Warning "Failed to create virtual machine $Name"
    Write-Warning $_.Exception.Message
    Write-Host -NoNewLine "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    #bail out
    Return
}

if ($VM){
  Try {
    Write-Verbose "Copy $TemplatePath to $VHDPATH."
    Copy-Item $TemplatePath $VHDPath
    ADD-VMHardDiskDrive -VMName $Name -Path $VHDPath
  }
  Catch {
    Write-Warning "Failed to add virtual harddisk $Name"
    Write-Warning $_.Exception.Message
    Write-Host -NoNewLine "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    #bail out
    Return
  }
}

if ($VM) {
    Try {
        Write-Verbose "Configuring new virtual machine"
        Write-Verbose ($setParam | out-string)
        $VM | Set-VM @setparam
    }
    Catch {
    Write-Warning "Failed to configure virtual machine $Name"
    Write-Warning $_.Exception.Message
    Write-Host -NoNewLine "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    #bail out
    Return
    }
}

Try{
  if ($LAN) {
    Add-VMNetworkAdapter -SwitchName "LAN" -VMName $Name -Name "LAN"
  }
}
Catch{
    Write-Warning "Failed to add internal Switch."
    Write-Warning $_.Exception.Message
    #bail out
    Write-Host -NoNewLine "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Return
}

Try{
  if ($PRIV) {
    Add-VMNetworkAdapter -SwitchName "PRIV" -VMName $Name -Name "PRIV"
  }
}
Catch{
    Write-Warning "Failed to add private Switch."
    Write-Warning $_.Exception.Message
    #bail out
    Write-Host -NoNewLine "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Return
}

Try{
  Start-VM -Name $Name
  Wait-VM -Name $Name
}
Catch{
    Write-Warning "Failed to start virtual machine $Name."
    Write-Warning $_.Exception.Message
    #bail out
    Write-Host -NoNewLine "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Return
}

Try{
    $Adapters=(Get-VM $Name | Get-VMNetworkAdapter)
    Write-Host -NoNewline "Waiting for IP from VM"
    While ( !$Adapters[0].IPAddresses[0] ) {
      $Adapters = (Get-VMNetworkAdapter -VMName $Name)  && 
      Start-Sleep 1  &&
      $count++
      Write-Host -NoNewline "."
      if ($count -ge 100 ) {return}
    }
    While ( !$Adapters[0].IPAddresses[0].contains("192.") ) {
      $Adapters = (Get-VMNetworkAdapter -VMName $Name)  && 
      Start-Sleep 1  &&
      $count++
      Write-Host -NoNewline "."
      if ($count -ge 100 ) {return}
    }
    Write-Host "" && Start-Sleep 5
    Write-Verbose "Looking for Adapter connected to Switch 'WAN' "
    ForEach ($Adapter in $Adapters) {
      if ($Adapter.SwitchName -eq 'WAN'){
        Write-Verbose "Found Adapter connected to Switch 'WAN' " 
        $IP=$Adapter.IPAddresses[0] 
        Write-Verbose "Setting hostname to $IP." 
        wsl sed -i "/template/,+1s/HostName.*$/HostName           $IP/" ~/.ssh/config &&
        wsl cat ~/.ssh/config
        Write-Verbose "Write hostkey for $IP to ~/.ssh/known-hosts"
        wsl bash ./allowHost.sh $IP
      }
    }
}  
Catch{
    Write-Warning "Failed to configure Open-SSH with $IP."
    Write-Warning $_.Exception.Message
    #bail out
    Write-Host -NoNewLine "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Set-Location "$($Pre)"
    Return
}

Try{
   # need to be in ansible subdirectory
   Set-Location $Ansible
   ForEach ($Playbook in $Playbooks){
     Write-Verbose "Playing playbook $Playbook."
     wsl ansible-playbook -i hosts --vault-id=/etc/ansible/password.txt "$($Playbook).yml"
   }
}
Catch{
    Write-Warning "Failed to run playbook $Playbook."
    Write-Warning $_.Exception.Message
    #bail out
    Write-Host -NoNewLine "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Set-Location "$($Pre)"
    Return
}

Try{
   wsl ansible-playbook -i hosts --vault-id=/etc/ansible/password.txt -e "new_hostname=$Name" "hostname.yml"
}
Catch{
    Write-Warning "Failed to rename virtual machines hostname to $Name."
    Write-Warning $_.Exception.Message
    #bail out
    Write-Host -NoNewLine "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Set-Location "$($Pre)"
    Return
}

if ($Reboot) {
  Try{
     Restart-VM $Name -Force
  }
  Catch{
      Write-Warning "Failed to restart virtual machines hostname to $Name."
      Write-Warning $_.Exception.Message
      #bail out
      Write-Host -NoNewLine "Press any key to continue..."
      $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
      Set-Location "$($Pre)"
      Return
  }
}
Set-Location "$($Pre)"
Write-Host -NoNewLine "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
