param location string = resourceGroup().location
param adminUsername string
@secure()
param adminPassword string

var vmSize = 'Standard_D2s_v5'
var addressPrefix = '10.0.0.0/16'
var subnetPrefix = '10.0.0.0/24'
var vnetName = 'debug-vnet'
var subnetName = 'debug-subnet'
var vmHostName = 'debug-host'
var vmTargetName = 'debug-target'

var storageAccountName = toLower('dbgstor${uniqueString(resourceGroup().id)}')
var containerName = 'scripts'

// Create Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [addressPrefix]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
        }
      }
    ]
  }
}

// Create Storage Account and Blob Container
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: true
  }
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${storageAccount.name}/default/${containerName}'
  properties: {
    publicAccess: 'Blob'
  }
}

// Create Public IP for Host
resource publicIpHost 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: '${vmHostName}-pip'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

// Create Public IP for Target
resource publicIpTarget 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: '${vmTargetName}-pip'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

// Create NIC for Host
resource nicHost 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: '${vmHostName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIpHost.id
          }
        }
      }
    ]
  }
}

// Create NIC for Target
resource nicTarget 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: '${vmTargetName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIpTarget.id
          }
        }
      }
    ]
  }
}

// Create Host VM
resource vmHost 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmHostName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmHostName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicHost.id
        }
      ]
    }
  }
}

// Create Target VM
resource vmTarget 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmTargetName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmTargetName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicTarget.id
        }
      ]
    }
  }
}

// Install Script Extension on Host
resource scriptHost 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
  name: '${vmHostName}/install-script'
  location: location
  dependsOn: [
    vmHost
    container
  ]
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://${storageAccount.name}.blob.core.windows.net/${containerName}/install-wdk-and-setup-debug.ps1'
      ]
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File install-wdk-and-setup-debug.ps1 -role host'
    }
  }
}

// Install Script Extension on Target
resource scriptTarget 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
  name: '${vmTargetName}/install-script'
  location: location
  dependsOn: [
    vmTarget
    container
  ]
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://${storageAccount.name}.blob.core.windows.net/${containerName}/install-wdk-and-setup-debug.ps1'
      ]
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File install-wdk-and-setup-debug.ps1 -role target'
    }
  }
}

// Output Public IP addresses
output hostPublicIpAddress string = publicIpHost.properties.ipAddress
output targetPublicIpAddress string = publicIpTarget.properties.ipAddress

