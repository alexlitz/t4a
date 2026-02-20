#!/bin/bash
# t4a installer - idempotent, upgrades existing installs
# Usage: 
#   curl -sSL https://raw.githubusercontent.com/alexlitz/t4a/main/install.sh | bash
#   t4a self-update  # Update t4a to latest version

set -e

INSTALL_DIR="${T4A_INSTALL_DIR:-$HOME/.local/bin}"
CONFIG_DIR="${T4A_CONFIG_DIR:-$HOME/.config}"
T4A_BIN="$INSTALL_DIR/t4a"
REPO_URL="https://raw.githubusercontent.com/alexlitz/t4a/main/t4a"
INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/alexlitz/t4a/main/install.sh"

# Self-update: if t4a is running and first arg is 'self-update'
if [ "$1" = "self-update" ]; then
    echo "Updating t4a..."
    mkdir -p "$INSTALL_DIR"
    curl -sSL "$REPO_URL" -o "$T4A_BIN"
    chmod +x "$T4A_BIN"
    NEW_VERSION=$("$T4A_BIN" --version 2>/dev/null || echo "unknown")
    echo "Updated to $NEW_VERSION"
    exit 0
fi

# If t4a exists and has self-update, delegate to it for 'self-update'
if [ -x "$T4A_BIN" ] && command -v "$T4A_BIN" >/dev/null 2>&1; then
    if [ "$1" = "self-update" ] || [ "$1" = "update" ]; then
        exec "$T4A_BIN" self-update
    fi
fi

echo "Installing t4a..."

# Create directories
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR/opencode"
mkdir -p "$CONFIG_DIR/claude"

# Check for existing install
if [ -x "$T4A_BIN" ]; then
    OLD_VERSION=$("$T4A_BIN" --version 2>/dev/null || echo "unknown")
    echo "Upgrading existing t4a installation ($OLD_VERSION)..."
else
    echo "Fresh installation..."
fi

# Download t4a (overwrites existing)
curl -sSL https://raw.githubusercontent.com/alexlitz/t4a/main/t4a -o "$T4A_BIN"
chmod +x "$T4A_BIN"

# Verify
if ! "$T4A_BIN" status >/dev/null 2>&1; then
    echo "Error: t4a installation failed"
    exit 1
fi
echo "Installed t4a to $T4A_BIN"

# Configure opencode (idempotent)
OPENCODE_CFG="$CONFIG_DIR/opencode/AGENTS.md"
if ! grep -q '# T4A_TASK_QUEUE' "$OPENCODE_CFG" 2>/dev/null; then
    cat >> "$OPENCODE_CFG" << 'EOF'

# T4A_TASK_QUEUE

Before starting work, check for queued tasks:

    t4a peek

If tasks exist, work on them:

    t4a work --command "opencode --print"

Or claim manually:

    JOB=$(t4a claim)
    t4a status $JOB

To add tasks for later:

    t4a add "Task description" --priority 80
EOF
    echo "Configured opencode"
else
    echo "Opencode already configured"
fi

# Configure claude (idempotent)
CLAUDE_CFG="$CONFIG_DIR/../.claude/CLAUDE.md"
mkdir -p "$(dirname "$CLAUDE_CFG")"
if ! grep -q '# T4A_TASK_QUEUE' "$CLAUDE_CFG" 2>/dev/null; then
    cat >> "$CLAUDE_CFG" << 'EOF'

# T4A_TASK_QUEUE

Before starting work, check for queued tasks:

    t4a peek

If tasks exist, work on them:

    t4a work --command "claude --print"

Or claim manually:

    JOB=$(t4a claim)
    t4a status $JOB

To add tasks for later:

    t4a add "Task description" --priority 80
EOF
    echo "Configured claude"
else
    echo "Claude already configured"
fi

# Setup systemd service files (Linux only) - but don't auto-start
if command -v systemctl >/dev/null 2>&1; then
    SYSTEMD_DIR="$HOME/.config/systemd/user"
    mkdir -p "$SYSTEMD_DIR"
    
    cat > "$SYSTEMD_DIR/t4a.service" << 'EOF'
[Unit]
Description=t4a task queue worker
After=network.target

[Service]
Type=simple
ExecStart=%h/.local/bin/t4a work --daemon
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
EOF
    
    cat > "$SYSTEMD_DIR/t4a-monitor.service" << 'EOF'
[Unit]
Description=t4a monitor and auto-recovery
After=network.target

[Service]
Type=simple
ExecStart=%h/.local/bin/t4a monitor --auto-recover
Restart=always
RestartSec=30

[Install]
WantedBy=default.target
EOF
    
    systemctl --user daemon-reload 2>/dev/null || true
    echo "Created systemd service files (not enabled)"
    echo ""
    echo "To enable auto-start on login (optional):"
    echo "  systemctl --user enable --now t4a-monitor.service  # Just monitor"
    echo "  systemctl --user enable --now t4a.service          # Worker (dispatches agents)"
fi

# Ensure PATH includes install dir
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
    echo ""
    echo "NOTE: Add $INSTALL_DIR to your PATH:"
    echo "  echo 'export PATH=\"\$PATH:$INSTALL_DIR\"' >> ~/.bashrc"
    echo "  source ~/.bashrc"
fi

echo ""
echo "Installation complete!"
echo ""
echo "Quick start:"
echo "  t4a add \"My first task\""
echo "  t4a list"
echo "  t4a work"
