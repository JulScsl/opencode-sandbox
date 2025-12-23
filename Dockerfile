FROM python:3.13-slim

# System dependencies
RUN apt update && apt install -y \
    curl \
    git \
    ca-certificates \
    wget \
    zip \
    unzip \
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

# Install Prettier globally
RUN npm install -g prettier

# Install OpenCode
RUN curl -fsSL https://opencode.ai/install | bash
ENV PATH="/root/.opencode/bin:$PATH"

# Verify installations
RUN echo "Checking installations..." \
    && (node --version > /dev/null 2>&1 && echo "✓ node installed" || echo "✗ node not installed") \
    && (npm --version > /dev/null 2>&1 && echo "✓ npm installed" || echo "✗ npm not installed") \
    && (python --version > /dev/null 2>&1 && echo "✓ python installed" || echo "✗ python not installed") \
    && (uv --version > /dev/null 2>&1 && echo "✓ uv installed" || echo "✗ uv not installed") \
    && (prettier --version > /dev/null 2>&1 && echo "✓ prettier installed" || echo "✗ prettier not installed") \
    && (opencode --version > /dev/null 2>&1 && echo "✓ opencode installed" || echo "✗ opencode not installed")

# Download Serena via uvx to reduce container start-up time
RUN uvx --from git+https://github.com/oraios/serena serena start-mcp-server --help > /dev/null 2>&1 && echo "✓ serena cached with uvx" || echo "✗ caching serena with uvx failed"

# Create Serena configuration
ENV SERENA_HOME=/serena
RUN mkdir -p $SERENA_HOME && \
    cat > $SERENA_HOME/serena_config.yml << 'EOF'
gui_log_window: False
web_dashboard: True
web_dashboard_listen_address: 0.0.0.0
web_dashboard_open_on_launch: False
projects: []
EOF

# Configure git with safe directory for mounted workspace
RUN git config --global --add safe.directory '/workspace'

WORKDIR /workspace

# Keep container running
CMD ["tail", "-f", "/dev/null"]
