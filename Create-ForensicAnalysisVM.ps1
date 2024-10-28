# Determine the path of the currently executing script
$scriptPath = $PSScriptRoot

# Path to the configuration file, relative to the script
$configFilePath = Join-Path $scriptPath "Create-ForensicAnalysisVM-config.json"

# Read the configuration file
if (Test-Path $configFilePath) {
    $configContent = Get-Content $configFilePath | ConvertFrom-Json
}
else {
    throw "Configuration file not found at path: $configFilePath"
}

# Determine the path of the currently executing script
$scriptPath = $PSScriptRoot

# Path to the configuration file, relative to the script
$configFilePath = Join-Path $scriptPath "Create-ForensicAnalysisVM-config.json"

# Read the configuration file
if (Test-Path $configFilePath) {
    $configContent = Get-Content $configFilePath | ConvertFrom-Json
}
else {
    throw "Configuration file not found at path: $configFilePath"
}

# Check for required variables and assign them
$SubscriptionId = $configContent.SubscriptionId
$ResourceGroupName = $configContent.ResourceGroupName
$Location = $configContent.Location
$StandardSize = $configContent.StandardSize
$Vnet = $configContent.Vnet
$Subnet = $configContent.Subnet
$Nsg = $configContent.Nsg
$GalleryName = $configContent.GalleryName
$ImageName = $configContent.ImageName
$SubscriptionName = $configContent.SubscriptionName
$VMNamePrefix = $configContent.VMNamePrefix

# Validate if all required variables are present
if (-not $SubscriptionId) { throw "Missing required configuration variable: SubscriptionId" }
if (-not $ResourceGroupName) { throw "Missing required configuration variable: ResourceGroupName" }
if (-not $Location) { throw "Missing required configuration variable: Location" }
if (-not $StandardSize) { throw "Missing required configuration variable: StandardSize" }
if (-not $Vnet) { throw "Missing required configuration variable: Vnet" }
if (-not $Subnet) { throw "Missing required configuration variable: Subnet" }
if (-not $Nsg) { throw "Missing required configuration variable: Nsg" }
if (-not $GalleryName) { throw "Missing required configuration variable: GalleryName" }
if (-not $ImageName) { throw "Missing required configuration variable: ImageName" }
if (-not $SubscriptionName) { throw "Missing required configuration variable: SubscriptionName" }
if (-not $VMNamePrefix) { throw "Missing required configuration variable: VMNamePrefix" }

#Connect to Azure Management
if ((Get-AzContext) -eq $null) {
    Connect-AzAccount -SubscriptionId $SubscriptionId 
}

#Ensure context is correct
Set-AzContext $subscriptionname -ErrorAction SilentlyContinue -WarningAction Ignore | Out-Null

$ExistingVMs = Get-AzVM -ResourceGroupName $ResourceGroupName | where-object { $_.Name -like "$VMNamePrefix*" }

if ($ExistingVMs.count -eq 0) {
    $VMName = "$VMNamePrefix0"
}
else {
    $ExistingVMNumbers = $ExistingVMs.Name -replace $VMNamePrefix, '' | Where-Object { $_ -match '\d+' } | ForEach-Object { [int]$_ }
    # Find the highest number
    $HighestNumber = ($ExistingVMNumbers | Measure-Object -Maximum).Maximum
    # Create the next name in the sequence
    $VMName = "$VMNamePrefix$($HighestNumber + 1)"
}
Write-Host "New VM Name $VMName"

$ip = @{
    Name              = "$VMName-pip"
    ResourceGroupName = $ResourceGroupName
    Location          = $Location
    Sku               = 'Standard'
    AllocationMethod  = 'Static'
    IpAddressVersion  = 'IPv4'
    Zone              = 1, 2, 3
    Confirm           = $true
}
$ip = New-AzPublicIpAddress @ip
Write-Host "New Public IP $($ip.IpAddress)"

$imageDefinition = Get-AzGalleryImageDefinition `
    -GalleryName $GalleryName `
    -ResourceGroupName $ResourceGroupName `
    -Name $ImageName

# Create user object
$cred = Get-Credential -Message "Enter a username and password for the virtual machine."

#Create VM
New-AzVm `
    -ResourceGroupName $ResourceGroupName `
    -Name $VMName `
    -Location $Location `
    -VirtualNetworkName $vnet `
    -SubnetName $subnet `
    -SecurityGroupName $nsg `
    -PublicIpAddressName $ip.Name `
    -size $StandardSize `
    -Image $imageDefinition.Id `
    -Credential $cred `
    -SecurityType "TrustedLaunch"  -ErrorAction SilentlyContinue | Out-Null

Write-Host "VM Deployed"