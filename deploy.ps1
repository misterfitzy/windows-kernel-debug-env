# deploy.ps1
param(
  [Parameter(Mandatory=$true)]
  [string]$resourceGroupName,
  
  [Parameter(Mandatory=$true)]
  [string]$adminUsername,
  
  [Parameter(Mandatory=$true)]
  [securestring]$adminPassword
)

# Variables
$location = "eastus"
$templateFile = "./main.bicep"

# Convert secure password
$plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($adminPassword))

Write-Host "🔑 Logging into Azure..."
az login

Write-Host "📦 Creating resource group (if not exists)..."
az group create --name $resourceGroupName --location $location

Write-Host "🚀 Deploying Bicep template..."
$deploymentResult = az deployment group create `
  --resource-group $resourceGroupName `
  --template-file $templateFile `
  --parameters adminUsername=$adminUsername adminPassword=$plainPassword location=$location `
  --query "properties.outputs" `
  --output json | ConvertFrom-Json

# Extract public IPs from outputs
$hostIp = $deploymentResult.hostPublicIpAddress.value
$targetIp = $deploymentResult.targetPublicIpAddress.value

Write-Host ""
Write-Host "✅ Deployment Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "🖥️  Host VM Public IP: $hostIp" -ForegroundColor Cyan
Write-Host "🖥️  Target VM Public IP: $targetIp" -ForegroundColor Yellow
Write-Host ""
Write-Host "🔗 You can now RDP into your VMs!"

