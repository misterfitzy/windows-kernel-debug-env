# ===============================
# deploy-extensions.ps1
# FINAL Full Working Version
# ===============================

# Variables
$resourceGroupName = "debug-rg"
$vmHostName = "debug-host"
$vmTargetName = "debug-target"
$containerName = "scripts"
$scriptFileName = "install-wdk-and-setup-debug.ps1"
$location = "eastus"

# Authenticate to Azure
Write-Host "🔑 Logging into Azure..."
az login

# Find Storage Account Name
Write-Host "🔎 Locating storage account..."
$storageAccountName = az storage account list `
  --resource-group $resourceGroupName `
  --query "[?contains(name, 'dbgstor')].name | [0]" `
  --output tsv

if (!$storageAccountName) {
  Write-Error "❌ Could not find Storage Account. Make sure your infra is deployed first."
  exit 1
}

# Build script URL
$scriptUrl = "https://${storageAccountName}.blob.core.windows.net/${containerName}/${scriptFileName}"

Write-Host "📥 Using script URL: $scriptUrl"

# Build full JSON body for Host VM extension
$hostExtension = @{
  "location" = $location
  "properties" = @{
    "publisher" = "Microsoft.Compute"
    "type" = "CustomScriptExtension"
    "typeHandlerVersion" = "1.10"
    "autoUpgradeMinorVersion" = $true
    "settings" = @{
      "timestamp" = (Get-Date).ToFileTimeUtc()
    }
    "protectedSettings" = @{
      "fileUris" = @($scriptUrl)
      "commandToExecute" = "powershell -ExecutionPolicy Unrestricted -File install-wdk-and-setup-debug.ps1 -role host"
    }
  }
} | ConvertTo-Json -Depth 5 -Compress

# Build full JSON body for Target VM extension
$targetExtension = @{
  "location" = $location
  "properties" = @{
    "publisher" = "Microsoft.Compute"
    "type" = "CustomScriptExtension"
    "typeHandlerVersion" = "1.10"
    "autoUpgradeMinorVersion" = $true
    "settings" = @{
      "timestamp" = (Get-Date).ToFileTimeUtc()
    }
    "protectedSettings" = @{
      "fileUris" = @($scriptUrl)
      "commandToExecute" = "powershell -ExecutionPolicy Unrestricted -File install-wdk-and-setup-debug.ps1 -role target"
    }
  }
} | ConvertTo-Json -Depth 5 -Compress

# Save extension specs to temp files
$hostSettingsPath = "./extension-host.json"
$targetSettingsPath = "./extension-target.json"
$hostExtension | Out-File -Encoding utf8 $hostSettingsPath
$targetExtension | Out-File -Encoding utf8 $targetSettingsPath

# Deploy extension to Host VM
Write-Host "🚀 Adding extension to HOST VM..."
az resource create `
  --resource-group $resourceGroupName `
  --resource-type "Microsoft.Compute/virtualMachines/extensions" `
  --name "$vmHostName/install-script-2" `
  --properties @$hostSettingsPath `
  --location $location

# Deploy extension to Target VM
Write-Host "🚀 Adding extension to TARGET VM..."
az resource create `
  --resource-group $resourceGroupName `
  --resource-type "Microsoft.Compute/virtualMachines/extensions" `
  --name "$vmTargetName/install-script-2" `
  --properties @$targetSettingsPath `
  --location $location

Write-Host ""
Write-Host "✅ Extensions deployed! The VMs are now installing WDK and setting up kernel debugging!"

