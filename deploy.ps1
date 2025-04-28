# ===============================
# deploy.ps1
# Deploys full Windows Kernel Debugging Lab to Azure
# ===============================

# Variables
$resourceGroupName = "debug-rg"
$location = "eastus"
$deploymentName = "debug-deployment"

$containerName = "scripts"
$localScriptPath = "install-wdk-and-setup-debug.ps1"

# Prompt for admin username and password (plaintext)
$adminUsername = Read-Host "Enter admin username for VMs"
$adminPasswordPlain = Read-Host "Enter admin password for VMs (will show input)"

# Authenticate to Azure
Write-Host "🔑 Logging into Azure..."
az login

# Create Resource Group if needed
Write-Host "📦 Ensuring resource group exists..."
az group create --name $resourceGroupName --location $location

# Deploy Bicep Template
Write-Host "🚀 Deploying Bicep template..."
az deployment group create `
  --name $deploymentName `
  --resource-group $resourceGroupName `
  --template-file main.bicep `
  --parameters adminUsername=$adminUsername adminPassword=$adminPasswordPlain

# Find the Storage Account Name
Write-Host "🔎 Locating storage account..."
$storageAccountName = az storage account list `
  --resource-group $resourceGroupName `
  --query "[?contains(name, 'dbgstor')].name | [0]" `
  --output tsv

if (!$storageAccountName) {
  Write-Error "❌ Could not find Storage Account. Deployment may have failed."
  exit 1
}

# Get Storage Account Key
$storageKey = az storage account keys list `
  --resource-group $resourceGroupName `
  --account-name $storageAccountName `
  --query "[0].value" `
  --output tsv

# Upload PowerShell Script to Blob
Write-Host "📤 Uploading install script to Storage Account..."
az storage blob upload `
  --account-name $storageAccountName `
  --account-key $storageKey `
  --container-name $containerName `
  --name "install-wdk-and-setup-debug.ps1" `
  --file $localScriptPath `
  --overwrite

# Set container public access
Write-Host "🔓 Setting container public access..."
az storage container set-permission `
  --account-name $storageAccountName `
  --account-key $storageKey `
  --name $containerName `
  --public-access blob

Write-Host ""
Write-Host "✅ Deployment Complete! Your Windows Kernel Debug Lab is setting up now."
Write-Host "VMs will download the script, install WDK, configure debugging, and reboot automatically."

