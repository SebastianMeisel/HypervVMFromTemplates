# Create External Switch(es) for HyperV

$SwitchName = 'External'
$SwitchType = 'Internal'

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

function New-LabSwitch
{
	param(
		[Parameter(Mandatory)]
		[string]$Name,

		[Parameter()]
		[string]$Type = 'External'
	)

	if( -not (Get-VMSwitch `
			-Name $Name `
			-SwitchType $Type `
			-ErrorAction SilentlyContinue))
	{
		Write-Verbose `
			-Message "Creating switch [$Name]..."
		if ( $Type -eq 'External' )
		{
			$null = New-VMSwitch `
				-name $Name  `
				-NetAdapterName Ethernet `
				-AllowManagementOS $true
		}
		else
		{
			$null = New-VMSwitch `
				-Name $Name `
				-SwitchType $Type
		}

		Write-Verbose `
			-Message "Switch [$Name] created."
	}
	else
	{
		Write-Verbose `
			-Message "Switch [$Name] has already been created!"
	}
}

New-LabSwitch -Name $SwitchName -Type $SwitchType -Verbose

# Create Route
New-NetRoute -DestinationPrefix 10.10.10.0/24  -NextHop 192.168.178.1 -InterfaceIndex 24

# Abschluss bestätigen
Write-Host -NoNewLine "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

