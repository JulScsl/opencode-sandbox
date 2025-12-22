#!/usr/bin/env pwsh
# opencode-sandbox.ps1

param(
    [string]$ImageName = "opencode-sandbox:latest",
    [string]$ContainerName = "opencode-sandbox-$(Split-Path -Leaf $PWD)",
    [string]$ProjectPath = $PWD
)

$ErrorActionPreference = "Stop"

# Detect container runtime (prefer Podman over Docker)
$containerRuntime = $null
if (Get-Command podman -ErrorAction SilentlyContinue) {
    $containerRuntime = "podman"
    Write-Host "Using Podman as container runtime"
} elseif (Get-Command docker -ErrorAction SilentlyContinue) {
    $containerRuntime = "docker"
    Write-Host "Using Docker as container runtime"
} else {
    Write-Error "Neither Podman nor Docker found. Please install one of them."
    exit 1
}

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

# Use host's OpenCode directories
$ConfigDir = "$env:USERPROFILE\.config\opencode"
$AppDataDir = "$env:USERPROFILE\.local\share\opencode"
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
                type = "local"
                command = @(
                    "uvx",
                    "--from",
                    "git+https://github.com/oraios/serena",
                    "serena",
                    "start-mcp-server",
                    "--context",
                    "claude-code"
                )
                enabled = $true
            }
        }
        formatter = @{
            prettier_markdown = @{
                command = @("prettier", "--write", "`$FILE")
                extensions = @(".md", ".mdx", ".markdown")
            }
        }
    } | ConvertTo-Json -Depth 10

    Set-Content -Path $configPath -Value $config
    Write-Host "Created OpenCode config at $configPath"
}

# Check if container exists
$existing = & $containerRuntime ps -a --filter "name=^${ContainerName}$" --format "{{.Names}}"

if ($existing) {
    Write-Host "Removing existing container: $ContainerName"
    & $containerRuntime rm -f $ContainerName | Out-Null
}

# Create new container
Write-Host "Creating new container: $ContainerName"
Write-Host "Project path: $ProjectPath"

& $containerRuntime run -d `
    --name $ContainerName `
    --network bridge `
    --security-opt no-new-privileges `
    --cap-drop ALL `
    --cap-add CHOWN,DAC_OVERRIDE,SETGID,SETUID,FOWNER `
    -e TZ="${containerTz}" `
    -p 24282:24282 `
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
    $state = & $containerRuntime inspect -f '{{.State.Running}}' $ContainerName 2>$null
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

Write-Host "`Attaching to OpenCode in container...`n"

# Start OpenCode interactively
& $containerRuntime exec -it $ContainerName opencode

# Cleanup
Write-Host "`Removing container..."
& $containerRuntime rm -f -t 0 $ContainerName | Out-Null
