# Dieses Skript installiert KaliLinux
$vm = "KaliVM1" 
$imageUrl = "https://cdimage.kali.org/kali-2022.2/kali-linux-2022.2-installer-amd64.iso"
$image = "C:\\Users\User\HyperV\Kali.iso"
$vmswitch = "DefaultSwitch"
$port = "port1" 
$vlan = 2 
$cpu =  2 
$ram = 4GB 
$path_to_disk = "C:\\Users\User\HyperV\\" 
$disk="$disk"
$disk_size = 10GB 

# The following are the powershell commands
# Check if Image is there or download it
if ( ! (Test-Path -Path $image)  )
{
	Invoke-WebRequest -Uri $imageUrl -OutFile $image
}
# Elevate rights if nessesary.
# Get the ID and security principal of the current user account
$myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
#
# Get the security principal for the Administrator role
$adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator

# Check to see if we are currently running "as Administrator"
if ($myWindowsPrincipal.IsInRole($adminRole))
{
    	# We are running "as Administrator" - so change the title and background color to indicate this
    	$Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)"
	$Host.UI.RawUI.BackgroundColor = "DarkBlue"
	clear-host
}
else
{
	# We are not running "as Administrator" - so relaunch as administrator
	# Create a new process object that starts PowerShell
	$newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell";
	# Specify the current script path and name as a parameter
	$newProcess.Arguments = $myInvocation.MyCommand.Definition;
	# Indicate that the process should be elevated
	$newProcess.Verb = "runas";
	# Start the new process
	[System.Diagnostics.Process]::Start($newProcess);
	# Exit from the current, unelevated, process
	exit
}
# Run your code that needs to be elevated here
Write-Host -NoNewLine "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Create a new VM
New-VM  $vm
# Set the CPU and start-up RAM
Set-VM $vm -ProcessorCount $cpu -MemoryStartupBytes $ram 
# Create the new VHDX disk - the path and size.
New-VHD -Path $path_to_disk$vm-$disk.vhdx -SizeBytes $disk_size 
# Add the new disk to the VM
Add-VMHardDiskDrive -VMName $vm -Path $path_to_disk$vm-$disk.vhdx
# Assign the OS ISO file to the VM
Set-VMDvdDrive -VMName $vm -Path $image
# Remove the default VM NIC named 'Network Adapter'
Remove-VMNetworkAdapter -VMName $vm 
# Add a new NIC to the VM and set its name
Add-VMNetworkAdapter -VMName $vm -Name $port
# Configure the NIC as access and assign VLAN
Set-VMNetworkAdapterVlan -VMName $vm -VMNetworkAdapterName $port -Access -AccessVlanId $vlan
# Connect the NIC to the vswitch
Connect-VMNetworkAdapter -VMName $vm -Name $port -SwitchName $vmswitch
# Fire it up ??
Start-VM $vm

