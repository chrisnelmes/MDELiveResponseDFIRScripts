<#
Requires .NET SDK to install dotnet tool install --global AzureSignTool --version 5.0.0
Require Powershell 7.x to run
#>

function Upload-FileToLiveResponseLibrary {
    param (
        [string] $token,
        [string] $path
    )

    $Header = @{
        "Authorization" = "Bearer $token"
        "Content-Type"  = "application/json"
    }

    # Check if the file exists
    if (-not (Test-Path -Path $path)) {
        Write-Host "File does not exist at path: $path"
        return
    }

    $uri = "https://api.security.microsoft.com/api/libraryfiles"

    $form = @{
        File = Get-Item -Path $path
    }

    Invoke-RestMethod -Uri $uri -Method Post -Form $form -Headers $Header
}
if ((Get-AzContext) -eq $null) {
    Connect-AzAccount 
}

# Determine the path of the currently executing script
$scriptPath = $PSScriptRoot

# Path to the configuration file, relative to the script
$configFilePath = Join-Path $scriptPath "Upload-SignandUploadScriptToLiveResponse-Config.json"

# Read the configuration file
if (Test-Path $configFilePath) {
    $configContent = Get-Content $configFilePath | ConvertFrom-Json
}
else {
    throw "Configuration file not found at path: $configFilePath"
}

# Check for required variables and assign them
$keyVaultUri = $configContent.keyVaultUri
$codeSigningCertName = $configContent.codeSigningCertName

# Validate if all variables are present
if (-not $keyVaultUri) {
    throw "One or more required configuration variables are missing in the configuration file."
}

#Render UI to get script path
Add-Type -AssemblyName 'System.Windows.Forms'
Add-Type -AssemblyName System.Drawing

$pathButtonClick2 =
{
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ InitialDirectory = [Environment]::GetFolderPath('Desktop') }
    $null = $FileBrowser.ShowDialog((New-Object System.Windows.Forms.Form -Property @{TopMost = $true; TopLevel = $true }))
    $powershellpath = $FileBrowser.filename
    $FileBrowser = $null
    $textBox2.Text = $powershellpath
    $textBox2.Refresh()
}

#Draw UI
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Sign and Upload Script to Live Response'
$form.Size = New-Object System.Drawing.Size(500, 200)
$form.StartPosition = 'CenterScreen'

$okButton = New-Object System.Windows.Forms.Button
$okButton.Location = New-Object System.Drawing.Point(75, 120)
$okButton.Size = New-Object System.Drawing.Size(75, 23)
$okButton.Text = 'OK'
$okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.AcceptButton = $okButton
$form.Controls.Add($okButton)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Location = New-Object System.Drawing.Point(150, 120)
$cancelButton.Size = New-Object System.Drawing.Size(75, 23)
$cancelButton.Text = 'Cancel'
$cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.CancelButton = $cancelButton
$form.Controls.Add($cancelButton)


$label2 = New-Object System.Windows.Forms.Label
$label2.Location = New-Object System.Drawing.Point(10, 60)
$label2.Size = New-Object System.Drawing.Size(500, 20)
$label2.Text = 'Path to file to sign'
$form.Controls.Add($label2)

$textBox2 = New-Object System.Windows.Forms.TextBox
$textBox2.Location = New-Object System.Drawing.Point(10, 80)
$textBox2.Size = New-Object System.Drawing.Size(380, 20)
$form.Controls.Add($textBox2)

$pathButton2 = New-Object System.Windows.Forms.Button
$pathButton2.Location = New-Object System.Drawing.Point(420, 80)
$pathButton2.Size = New-Object System.Drawing.Size(40, 23)
$pathButton2.Text = '...'
$pathButton2.Add_Click($pathButtonClick2)
$form.Controls.Add($pathButton2)

$form.Topmost = $true

$result = $form.ShowDialog()

#Set variables 
if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    $powershellpath = $textBox2.Text
}

if (!(test-path($powershellpath))) {
    Throw 'Path Invalid'
}

$token = (Get-AzAccessToken -ResourceUrl 'https://vault.azure.net').Token
azuresigntool sign -kvu $keyVaultUri --azure-key-vault-certificate $codeSigningCertName  --azure-key-vault-accesstoken $token -fd sha256 -tr http://timestamp.digicert.com  $powershellpath

$token = (Get-AzAccessToken -ResourceUrl "https://api.securitycenter.microsoft.com").Token

Upload-FileToLiveResponseLibrary -path $powershellpath -token $token
