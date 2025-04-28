# Windows Kernel Debug Lab on Azure

This project fully automates the deployment of a two-VM setup for Windows kernel network debugging on Azure.

## Project Structure

| File | Purpose |
|:-----|:--------|
| `main.bicep` | Defines Azure resources: VNet, VMs, Storage Account, Blob container, Custom Script Extensions |
| `install-wdk-and-setup-debug.ps1` | Installs Windows Driver Kit (WDK), configures KDNET (kernel debugging over network), reboots |
| `deploy.ps1` | One-command deploy script: deploys infra + uploads script automatically |

---

## Requirements

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- Access to an Azure subscription
- PowerShell 5.x or 7.x+

---

## How to Deploy

1. Clone this repository locally.
2. Open a PowerShell terminal.
3. Run:

   ```bash
   ./deploy.ps1

