#!/bin/bash
# Setup script for claude-code-ui daemon hooks
# Installs hooks for accurate session state detection:
# - PermissionRequest: detect when waiting for user approval
# - Stop: detect when Claude finishes responding
# - SessionEnd: detect when session closes

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SETTINGS_FILE="$HOME/.claude/settings.json"
SIGNALS_DIR="$HOME/.claude/session-signals"

echo "Setting up claude-code-ui hooks..."

# Create signals directory
mkdir -p "$SIGNALS_DIR"
echo "Created $SIGNALS_DIR"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed."
    echo "Install with: brew install jq (macOS) or apt install jq (Linux)"
    exit 1
fi

# Check if settings.json exists
if [ ! -f "$SETTINGS_FILE" ]; then
    echo "Creating new settings.json..."
    echo '{}' > "$SETTINGS_FILE"
fi

# Backup settings
cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"
echo "Backed up settings to $SETTINGS_FILE.backup"

# Build the hooks configuration
# PermissionRequest: write pending permission file
PERMISSION_HOOK="$SCRIPT_DIR/hooks/permission-request.sh"
# Stop: write turn-ended signal
STOP_HOOK="$SCRIPT_DIR/hooks/stop.sh"
# SessionEnd: write session-ended signal
SESSION_END_HOOK="$SCRIPT_DIR/hooks/session-end.sh"

# Add all hooks
jq --arg perm "$PERMISSION_HOOK" \
   --arg stop "$STOP_HOOK" \
   --arg end "$SESSION_END_HOOK" '
  .hooks.PermissionRequest = [{"matcher": "", "hooks": [{"type": "command", "command": $perm}]}] |
  .hooks.Stop = [{"matcher": "", "hooks": [{"type": "command", "command": $stop}]}] |
  .hooks.SessionEnd = [{"matcher": "", "hooks": [{"type": "command", "command": $end}]}]
' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

echo "Added hooks to $SETTINGS_FILE:"
echo "  - PermissionRequest (detect approval needed)"
echo "  - Stop (detect turn ended)"
echo "  - SessionEnd (detect session closed)"
echo ""
echo "Setup complete! The daemon will now accurately track session states."
echo ""
echo "Note: You may need to restart any running Claude Code sessions for hooks to take effect."
