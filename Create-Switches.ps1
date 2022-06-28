$Switches = [ordered]@{ 'WAN' = 'External' ; 'LAN' = 'Internal' ; 'PRIV' = 'Private'; }

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

ForEach ($pair in $Switches.GetEnumerator()) {
   New-LabSwitch -Name "$($pair.key)" -Type "$($pair.value)" -Verbose
}
# Abschluss bestätigen
Write-Host -NoNewLine "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
