# OpenCode Sandbox for Windows

Run OpenCode in a sandboxed container environment on Windows using Podman or Docker. This project provides a secure, isolated development environment that protects your host system from potential issues while working with AI-assisted coding tools.

## What is This?

This project allows you to run [OpenCode](https://opencode.ai) (an AI coding assistant CLI) inside a container on Windows. The container is configured with security best practices and includes all necessary dependencies:

- Python 3.13
- OpenCode CLI
- Serena MCP, an MCP server that provides powerful code navigation, symbol-aware editing, and intelligent refactoring capabilities
- npm with npx to run additional MCP servers
- uv with uvx to run additional MCP servers

## Why Use a Sandbox?

Running OpenCode in a container provides:

- **Isolation**: Your host system is protected from potentially destructive operations
- **Security**: Container runs with minimal privileges (no-new-privileges, dropped capabilities)
- **Clean Environment**: Fresh development environment for each project
- **Consistency**: Same environment across different machines

## Prerequisites

- **Windows** (Windows 10/11 or Windows Server)
- **Podman** or **Docker** installed (Podman is preferred)
  - Podman: https://podman.io/getting-started/installation
  - Docker Desktop: https://www.docker.com/products/docker-desktop
- **PowerShell** (pre-installed on Windows)

## Installation

1. Clone or download this repository
2. Build the container image using Podman or Docker:

**With Podman:**
```bash
podman build -t opencode-sandbox:latest .
```

**With Docker:**
```bash
docker build -t opencode-sandbox:latest .
```

This will create a container image with all dependencies pre-installed.

3. Add the repository directory to your system PATH so you can run `opencode-sandbox` from anywhere

## Usage

### Quick Start

1. Navigate to the directory of the project you want to work on
2. Run the command:

```bash
opencode-sandbox
```

This works from any shell (CMD, PowerShell, Git Bash, etc.) as long as the scripts are on your PATH

### What Happens

When you run the script:

1. Detects available container runtime (prefers Podman, falls back to Docker)
2. Creates/removes any existing container for the current project
3. Starts a new container with:
   - Your current directory mounted as `/workspace`
   - Security restrictions applied
   - Host timezone configured
   - Serena MCP server running
4. Launches OpenCode interactively inside the container
5. Automatically cleans up the container when you exit

### Advanced Usage

You can customize the script with parameters:

```powershell
pwsh opencode-sandbox.ps1 -ImageName "custom-image:tag" -ContainerName "my-sandbox" -ProjectPath "C:\path\to\project"
```

**Parameters:**
- `ImageName`: Container image to use (default: `opencode-sandbox:latest`)
- `ContainerName`: Name for the container (default: `opencode-sandbox-<current-folder>`)
- `ProjectPath`: Path to mount as workspace (default: current directory)

## Configuration

### OpenCode Configuration

The first time you run the script, it creates a configuration file at:

```
%USERPROFILE%\.opencode-sandbox\config\config.json
```

This config enables the Serena MCP integration automatically.

### Persistent Storage

The following directories/volumes are used for persistence:

- `%USERPROFILE%\.opencode-sandbox\config` - OpenCode configuration
- `%USERPROFILE%\.opencode-sandbox\appdata` - Application data
- `opencode-sandbox-cache` - Podman volume for cache files

Your project files in the workspace are directly mounted, so all changes are immediately reflected on your host system.

## Security Features

The container runs with enhanced security:

- `--security-opt no-new-privileges` - Prevents privilege escalation
- `--cap-drop ALL` - Drops all Linux capabilities
- `--cap-add CHOWN,DAC_OVERRIDE,SETGID,SETUID,FOWNER` - Only adds essential capabilities
- Isolated network (bridge mode)
- Non-root user operations where possible

## Troubleshooting

### Neither Podman nor Docker found

If you see an error about missing container runtime, ensure either Podman or Docker is installed and available in your PATH.

### Container fails to start

Check if your container runtime is running:
```bash
podman ps
# or
docker ps
```

### Timezone warnings

If timezone conversion fails, the container defaults to UTC. This doesn't affect functionality but timestamps may differ.

### Permission issues

Ensure the project directory is accessible and not protected by Windows security policies.

## How It Works

1. **Dockerfile**: Defines the container image with Python, Node.js, uv, OpenCode, and Serena
2. **opencode-sandbox.ps1**: PowerShell script that manages container lifecycle
3. **opencode-sandbox.cmd**: Windows batch wrapper for easy execution
4. **opencode-sandbox**: Bash wrapper for Git Bash/WSL environments

The PowerShell script handles:
- Container runtime detection (Podman preferred, Docker as fallback)
- Container creation and cleanup
- Volume mounting for project files and configs
- Timezone synchronization
- Security configuration
- Serena MCP server startup
- Interactive OpenCode session

## License

This project is provided as-is for running OpenCode in a sandboxed environment.

## Contributing

Feel free to submit issues or pull requests to improve the sandbox configuration or documentation.
