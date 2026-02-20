#!/bin/bash
# t4a installer - idempotent, upgrades existing installs
# Usage: curl -sSL https://raw.githubusercontent.com/alexlitz/t4a/main/install.sh | bash

set -e

INSTALL_DIR="${T4A_INSTALL_DIR:-$HOME/.local/bin}"
CONFIG_DIR="${T4A_CONFIG_DIR:-$HOME/.config}"

echo "Installing t4a..."

# Create directories
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR/opencode"
mkdir -p "$CONFIG_DIR/claude"

# Check for existing install
T4A_BIN="$INSTALL_DIR/t4a"
if [ -x "$T4A_BIN" ]; then
    OLD_VERSION=$("$T4A_BIN" --version 2>/dev/null || echo "unknown")
    echo "Upgrading existing t4a installation..."
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

# Setup systemd service for auto-restart (Linux only)
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
    systemctl --user enable t4a.service t4a-monitor.service 2>/dev/null || true
    systemctl --user start t4a.service t4a-monitor.service 2>/dev/null || true
    echo "Enabled and started systemd services"
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
