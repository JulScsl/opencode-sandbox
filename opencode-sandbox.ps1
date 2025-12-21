#!/usr/bin/env pwsh
# opencode-sandbox.ps1

param(
    [string]$ImageName = "opencode-sandbox:latest",
    [string]$ContainerName = "opencode-sandbox-$(Split-Path -Leaf $PWD)",
    [string]$ProjectPath = $PWD
)

$ErrorActionPreference = "Stop"

# Get host timezone and convert to IANA format
$hostTz = Get-TimeZone
$ianaId = $null
$success = [System.TimeZoneInfo]::TryConvertWindowsIdToIanaId($hostTz.Id, [ref]$ianaId)

if ($success) {
    Write-Host "Using timezone: $ianaId"
    $containerTz = $ianaId
} else {
    Write-Host "Warning: Could not convert timezone $($hostTz.Id), defaulting to UTC"
    $containerTz = "UTC"
}

# Separate Paths für Container-Configs
$ConfigDir = "$env:USERPROFILE\.opencode-sandbox\config"
$AppDataDir = "$env:USERPROFILE\.opencode-sandbox\appdata"
$CacheVolume = "opencode-sandbox-cache"

# Ensure directories exist
@($ConfigDir, $AppDataDir) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
}

# Create OpenCode config if not exists
$configPath = Join-Path $ConfigDir "config.json"
if (-not (Test-Path $configPath)) {
    $config = @{
        '$schema' = "https://opencode.ai/config.json"
        mcp = @{
            serena = @{
                type = "remote"
                url = "http://localhost:9121/mcp"
                enabled = $true
            }
        }
    } | ConvertTo-Json -Depth 10

    Set-Content -Path $configPath -Value $config
    Write-Host "Created OpenCode config at $configPath"
}

# Check if container exists
$existing = podman ps -a --filter "name=^${ContainerName}$" --format "{{.Names}}"

if ($existing) {
    Write-Host "Removing existing container: $ContainerName"
    podman rm -f $ContainerName | Out-Null
}

# Create new container
Write-Host "Creating new container: $ContainerName"
Write-Host "Project path: $ProjectPath"

podman run -d `
    --name $ContainerName `
    --network bridge `
    --security-opt no-new-privileges `
    --cap-drop ALL `
    --cap-add CHOWN,DAC_OVERRIDE,SETGID,SETUID,FOWNER `
    -e TZ="${containerTz}" `
    -v "${ProjectPath}:/workspace" `
    -v "${ConfigDir}:/root/.config/opencode" `
    -v "${CacheVolume}:/root/.cache/opencode" `
    -v "${AppDataDir}:/root/.local/share/opencode" `
    -w /workspace `
    $ImageName `
    tail -f /dev/null `
    | Out-Null

# Poll until container is running (max 10 seconds)
$maxAttempts = 50
$attempt = 0
while ($attempt -lt $maxAttempts) {
    $state = podman inspect -f '{{.State.Running}}' $ContainerName 2>$null
    if ($state -eq "true") {
        break
    }
    Start-Sleep -Milliseconds 200
    $attempt++
}

if ($attempt -eq $maxAttempts) {
    Write-Error "Container failed to start within timeout"
    exit 1
}

Write-Host "Starting Serena MCP server..."
podman exec -d $ContainerName serena start-mcp-server --context claude-code --transport streamable-http --port 9121 | Out-Null

Write-Host "`Attaching to OpenCode in container...`n"

# Start OpenCode interactively
podman exec -it $ContainerName opencode

# Cleanup
Write-Host "`Removing container..."
podman rm -f -t 0 $ContainerName | Out-Null
