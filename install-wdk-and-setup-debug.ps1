param(
  [string]$role
)

Write-Host "🚀 Starting setup for role: $role"

# Install Windows Driver Kit
Write-Host "📥 Installing Windows Driver Kit..."

try {
  # Try using winget (preferred on newer Windows)
  winget install --id Microsoft.WindowsDriverKit.10 --accept-package-agreements --accept-source-agreements
} catch {
  Write-Host "⚠️ Winget not available. Falling back to manual download..."

  # Manual download of WDK installer
  $wdkUrl = "https://go.microsoft.com/fwlink/?linkid=2128854"  # Confirm latest link if needed
  $installerPath = "$env:TEMP\\wdksetup.exe"

  Invoke-WebRequest -Uri $wdkUrl -OutFile $installerPath -UseBasicParsing
  Start-Process -FilePath $installerPath -ArgumentList "/quiet" -Wait
}

# Gather own IP address (assuming 10.x.x.x private range)
$myIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like '10.*' }).IPAddress
Write-Host "🔎 Detected this machine's IP address: $myIP"

# Determine peer IP (hardcoded logic for simplicity)
if ($role -eq 'host') {
  $peerIP = '10.0.0.5'   # Target
} elseif ($role -eq 'target') {
  $peerIP = '10.0.0.4'   # Host
} else {
  Write-Error "❌ Unknown role specified. Must be 'host' or 'target'. Exiting."
  exit 1
}

# Configure Kernel Debugging
Write-Host "⚙️ Configuring kernel debugging settings..."

# Enable debugging
bcdedit /debug on

# Set debugger settings for network debugging
bcdedit /dbgsettings net hostip=$peerIP port=50000

# Open firewall for KDNET
Write-Host "🛡 Configuring firewall rules for KDNET (port 50000)..."
New-NetFirewallRule -DisplayName "Allow KDNET TCP 50000" `
  -Direction Inbound `
  -Protocol TCP `
  -LocalPort 50000 `
  -Action Allow

# Show final message and reboot
Write-Host "♻️ Rebooting system to apply debugging settings..."
Restart-Computer -Force

