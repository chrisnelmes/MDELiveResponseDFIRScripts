function Create-KapeScript {
    param (
        [Parameter(Mandatory = $true)]
        [string]$kapeString,
        [Parameter(Mandatory = $true)]
        [string]$outputPath,
        [Parameter(Mandatory = $true)]
        [string]$kapeZipUri,
        [Parameter(Mandatory = $true)]
        [string]$keyVaultUri,
        [Parameter(Mandatory = $true)]
        [string]$timeStampUri
    )
    $scriptContent = @'
    #This increases download/extract performance
    $ProgressPreference = 'SilentlyContinue'
    
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    if (!(test-path 'C:\temp\')) {
        mkdir 'C:\temp\'
    }
    #Remove old Kape Installs
    if (test-path 'C:\temp\kape') {
        Remove-item 'C:\temp\kape' -force -Recurse
    }
    if (test-path 'C:\temp\kape.zip') {
        Remove-item 'C:\temp\kape.zip' -force 
    }
    $url = "-----kapezipuriplaceholder----"
    $output = "C:\temp\kape.zip"
    (New-Object System.Net.WebClient).DownloadFile($url, $output)
    Expand-Archive -path "C:\temp\kape.zip" -DestinationPath "C:\temp\"
    $kapeString = "-----kapesstringsplaceholder----"
    
    $Kape = "C:\temp\KAPE\kape.exe"
    if (Test-Path $kape){
       Start-Process -FilePath $kape -Argumentlist $kapeString
    }
'@
    $scriptContent = $scriptcontent.replace('-----kapesstringsplaceholder----', $kapeString)
    $scriptContent = $scriptcontent.replace('-----kapezipuriplaceholder----', $kapeZipUri)
    #Write Script Output
    $scriptContent | Set-Content $outputPath
    #Sign Script - Key Vault Access Required and Azure Sign Tool Required
    $token = (Get-AzAccessToken -ResourceUrl 'https://vault.azure.net').Token
    azuresigntool sign -kvu $keyVaultUri --azure-key-vault-certificate CodeSigningCertificate  --azure-key-vault-accesstoken $token -fd sha256 -tr $timeStampUri   $outputPath
    Write-Host "Script is ready to deploy via Defender for Endpoint Live Response $outputPath"
}

# Determine the path of the currently executing script
$scriptPath = $PSScriptRoot

# Path to the configuration file, relative to the script
$configFilePath = Join-Path $scriptPath "Create-LiveResponseKapeScripts-Config.json"

# Read the configuration file
if (Test-Path $configFilePath) {
    $configContent = Get-Content $configFilePath | ConvertFrom-Json
}
else {
    throw "Configuration file not found at path: $configFilePath"
}

# Check for required variables and assign them
$scriptOutputLocation = $configContent.scriptOutputLocation
$keyVaultUri = $configContent.keyVaultUri
$timeStampUri = $configContent.timeStampUri
$kapeZipUri = $configContent.kapeZipUri
$azureSubscriptionName = $configContent.azureSubscriptionName
$storageAccounts = $configContent.storageAccounts
$KapeStringOptions = $configContent.KapeStringOptions

# Validate if all variables are present
if (-not $scriptOutputLocation -or
    -not $keyVaultUri -or
    -not $timeStampUri -or
    -not $kapeZipUri -or
    -not $azureSubscriptionName -or
    -not $storageAccounts -or
    -not $KapeStringOptions) {
    throw "One or more required configuration variables are missing in the configuration file."
}

Add-Type -AssemblyName 'System.Windows.Forms'
Add-Type -AssemblyName 'System.Drawing'

# Create a new form
$form = New-Object Windows.Forms.Form
$form.Text = "Script Configuration"
$form.Size = New-Object Drawing.Size(600, 400)

# Create a TableLayoutPanel
$tableLayoutPanel = New-Object Windows.Forms.TableLayoutPanel
$tableLayoutPanel.RowCount = 5
$tableLayoutPanel.ColumnCount = 3
$tableLayoutPanel.Size = New-Object Drawing.Size(600, 300)
$tableLayoutPanel.Location = New-Object Drawing.Point(0, 10)
$tableLayoutPanel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 25)))
$tableLayoutPanel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 55)))
$tableLayoutPanel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 20)))
$tableLayoutPanel.RowStyles.Add((New-Object Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
$tableLayoutPanel.RowStyles.Add((New-Object Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
$tableLayoutPanel.RowStyles.Add((New-Object Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
$tableLayoutPanel.RowStyles.Add((New-Object Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
$tableLayoutPanel.RowStyles.Add((New-Object Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
$form.Controls.Add($tableLayoutPanel)

# Create a label for the Script Output Path
$labelOutputPath = New-Object Windows.Forms.Label
$labelOutputPath.Text = "Script Output Path:"
$labelOutputPath.Size = New-Object Drawing.Size(200, 20)
$tableLayoutPanel.Controls.Add($labelOutputPath, 0, 0)

# Create a textbox for the output path
$textboxOutputPath = New-Object Windows.Forms.TextBox
$textboxOutputPath.Size = New-Object Drawing.Size(300, 20)
$textboxOutputPath.Text = $configContent.scriptOutputLocation
$tableLayoutPanel.Controls.Add($textboxOutputPath, 1, 0)

# Create a button to open folder dialog
$buttonBrowse = New-Object Windows.Forms.Button
$buttonBrowse.Text = "Browse"
$buttonBrowse.Add_Click({
        $folderBrowser = New-Object Windows.Forms.FolderBrowserDialog
        $result = $folderBrowser.ShowDialog()
        if ($result -eq [Windows.Forms.DialogResult]::OK) {
            $textboxOutputPath.Text = $folderBrowser.SelectedPath
        }
    })
$tableLayoutPanel.Controls.Add($buttonBrowse, 2, 0)

# Create a label for the ComboBox
$labelCollectionType = New-Object Windows.Forms.Label
$labelCollectionType.Text = "Collection Type:"
$tableLayoutPanel.Controls.Add($labelCollectionType, 0, 1)

# Create the ComboBox
$comboBox = New-Object System.Windows.Forms.ComboBox
$comboBox.Size = New-Object Drawing.Size(300, 20)
$tableLayoutPanel.Controls.Add($comboBox, 1, 1)
$tableLayoutPanel.SetColumnSpan($comboBox, 2)

# Populate the ComboBox with options
foreach ($KapeStringOption in $KapeStringOptions) {
    $comboBox.Items.Add($KapeStringOption.Title) | Out-Null
}

$comboBox.SelectedItem = $combobox.Items[0]

# Add event handler for ComboBox selection change
$comboBox.Add_SelectedIndexChanged({
        $selectedOption = $KapeStringOptions[$comboBox.SelectedIndex]
        $textboxkapeString.Text = $selectedOption.KapeString
    })

# Create a label for the ComboBox
$labelCollectionType = New-Object Windows.Forms.Label
$labelCollectionType.Text = "Storage Account:"
$tableLayoutPanel.Controls.Add($labelCollectionType, 0, 2)

# Create the ComboBox
$comboBox2 = New-Object System.Windows.Forms.ComboBox
$comboBox2.Size = New-Object Drawing.Size(300, 20)
$tableLayoutPanel.Controls.Add($comboBox2, 1, 2)
$tableLayoutPanel.SetColumnSpan($comboBox2, 2)

# Populate the ComboBox with options
foreach ($storageAccount in $storageAccounts) {
    $comboBox2.Items.Add($storageAccount.storageAccountName) | Out-Null
}

#Populate intial values
$comboBox2.SelectedItem = $combobox2.Items[0]

# Add event handler for ComboBox selection change
$comboBox2.Add_SelectedIndexChanged({
        $selectedOption = $storageAccounts[$comboBox2.SelectedIndex]
        $textboxStorageAccountName.Text = $selectedOption.storageAccountName
        $textboxStorageAccountResourceGroup.Text = $selectedOption.storageAccountResourceGroup
    })

# Create a label for Kape string output
$labelkapeString = New-Object Windows.Forms.Label
$labelkapeString.Text = "Kape String:"
$tableLayoutPanel.Controls.Add($labelkapeString, 0, 3)

# Create the TextBox object for Kape string output
$textboxkapeString = New-Object Windows.Forms.TextBox
$textboxkapeString.Size = New-Object Drawing.Size(300, 120)  # Height is adjusted for word wrapping
$textboxkapeString.WordWrap = $true
$textboxkapeString.Multiline = $true
$textboxkapeString.ScrollBars = [Windows.Forms.ScrollBars]::Vertical
$tableLayoutPanel.Controls.Add($textboxkapeString, 1, 3)
$tableLayoutPanel.SetColumnSpan($textboxkapeString, 1)

$labelStorageAccountName = New-Object Windows.Forms.Label
$labelStorageAccountName.Text = "Storage Account"
$labelStorageAccountName.Size = New-Object Drawing.Size(300, 20)
$tableLayoutPanel.Controls.Add($labelStorageAccountName, 0, 4)

$textboxStorageAccountName = New-Object Windows.Forms.TextBox
$textboxStorageAccountName.Size = New-Object Drawing.Size(300, 20)
$tableLayoutPanel.Controls.Add($textboxStorageAccountName, 1, 4)

$labelStorageAccountResourceGroup = New-Object Windows.Forms.Label
$labelStorageAccountResourceGroup.Text = "Resource Group"
$labelStorageAccountResourceGroup.Size = New-Object Drawing.Size(300, 20)
$tableLayoutPanel.Controls.Add($labelStorageAccountResourceGroup, 0, 5)

$textboxStorageAccountResourceGroup = New-Object Windows.Forms.TextBox
$textboxStorageAccountResourceGroup.Size = New-Object Drawing.Size(300, 20)
$tableLayoutPanel.Controls.Add($textboxStorageAccountResourceGroup, 1, 5)

#Intial Values
$textboxkapeString.Text = $KapeStringOptions[0].KapeString
$textboxStorageAccountName.Text = $storageAccounts[0].storageAccountName
$textboxStorageAccountResourceGroup.Text = $storageAccounts[0].storageAccountResourceGroup

# OK and Cancel buttons
$okButton = New-Object System.Windows.Forms.Button
$okButton.Location = New-Object System.Drawing.Point(200, 320)
$okButton.Size = New-Object System.Drawing.Size(75, 25)
$okButton.Text = 'OK'
$okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.AcceptButton = $okButton
$form.Controls.Add($okButton)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Location = New-Object System.Drawing.Point(315, 320)
$cancelButton.Size = New-Object System.Drawing.Size(75, 25)
$cancelButton.Text = 'Cancel'
$cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.CancelButton = $cancelButton
$form.Controls.Add($cancelButton)

$result = $form.ShowDialog()

if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    $kapeString = $textboxkapeString.Text
    $outputFolder = $textboxOutputPath.Text
    $storageAccountResourceGroup = $textboxStorageAccountResourceGroup.Text 
    $storageAccountName = $textboxStorageAccountName.Text
}

if ($result -eq [System.Windows.Forms.DialogResult]::Cancel) {
    Throw "Script Cancelled"
}


$context = Get-AzContext
if (!$context) {  
    Connect-AzAccount  
}   
else {  
    Write-Host " Already connected to Azure"  
}  

Set-AzContext $azureSubscriptionName  -ErrorAction SilentlyContinue -WarningAction Ignore | Out-Null

Write-host "Creating SAS Token and Container"
$date = (Get-date -Format yyyyMMdd-HHmmss)
$sasExpiry = (Get-Date).AddDays(1)
#Create Storage Container
$silent = Get-AzStorageAccount -name $storageAccountName -ResourceGroupName $storageAccountResourceGroup  | New-AzStorageContainer -name $date
#Create SAS Token
$sas = Get-AzStorageAccount -name $storageAccountName -ResourceGroupName $storageAccountResourceGroup | New-AzStorageContainerSASToken -name $date -Permission cw -FullUri -ExpiryTime $sasExpiry 

$outputFileName = "Kape-$date.ps1"
$outputPath = join-path $outputFolder $outputFileName
$kapeString = $kapeString.replace('-----sasplaceholder----', $sas)
$kapeString = $kapeString.replace('-----targetplaceholder----', $kapeCustomTargetString)

Create-KapeScript  -outputPath $outputPath -kapeString $kapeString -kapeZipUri $kapeZipUri -timeStampUri $timeStampUri -keyVaultUri $keyVaultUri

Write-Host "SAS token is avaliable until $sasExpiry"
Write-Host "Good luck, happy hunting"