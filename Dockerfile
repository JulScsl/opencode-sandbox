FROM python:3.13-slim

# System dependencies
RUN apt update && apt install -y \
    curl \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install uv (Python package manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# Configure uv to use .venv-opencode instead of .venv
ENV UV_PROJECT_ENVIRONMENT=.venv-opencode

# Install OpenCode
RUN curl -fsSL https://opencode.ai/install | bash
ENV PATH="/root/.opencode/bin:$PATH"

# Install Serena via uvx
RUN uv tool install git+https://github.com/oraios/serena.git

# Verify installations
RUN echo "Checking installations..." \
    && (node --version > /dev/null 2>&1 && echo "✓ node installed" || echo "✗ node not installed") \
    && (npm --version > /dev/null 2>&1 && echo "✓ npm installed" || echo "✗ npm not installed") \
    && (python --version > /dev/null 2>&1 && echo "✓ python installed" || echo "✗ python not installed") \
    && (uv --version > /dev/null 2>&1 && echo "✓ uv installed" || echo "✗ uv not installed") \
    && (opencode --version > /dev/null 2>&1 && echo "✓ opencode installed" || echo "✗ opencode not installed") \
    && (serena --help > /dev/null 2>&1 && echo "✓ serena installed" || echo "✗ serena not installed")

WORKDIR /workspace

# Keep container running
CMD ["tail", "-f", "/dev/null"]
