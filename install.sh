#!/bin/bash
# claude-factory install.sh
# Installs the software factory toolchain into ~/.claude/bin
# Run from the bundle directory: bash install.sh

set -e

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
BIN_DIR="$CLAUDE_DIR/bin"

echo "Installing claude-factory..."
echo "  Bundle : $BUNDLE_DIR"
echo "  Target : $BIN_DIR"
echo ""

# Create bin dir
mkdir -p "$BIN_DIR"

# Copy and chmod all scripts
for f in "$BUNDLE_DIR/bin/"*; do
  fname=$(basename "$f")
  cp "$f" "$BIN_DIR/$fname"
  chmod +x "$BIN_DIR/$fname"
  echo "  ✓ $fname"
done

# Copy HANDOFF template
cp "$BUNDLE_DIR/templates/HANDOFF-template.md" "$CLAUDE_DIR/HANDOFF-template.md"
echo "  ✓ HANDOFF-template.md"

# Add bin to PATH in .bashrc if not already there
if ! grep -q "\.claude/bin" "$HOME/.bashrc" 2>/dev/null; then
  echo '' >> "$HOME/.bashrc"
  echo 'export PATH="$HOME/.claude/bin:$PATH"' >> "$HOME/.bashrc"
  echo "  ✓ Added ~/.claude/bin to PATH in ~/.bashrc"
else
  echo "  ✓ PATH already includes ~/.claude/bin"
fi

echo ""
echo "Manual steps required:"
echo ""
echo "1. Add SessionStart hook to ~/.claude/settings.json:"
echo "   See config/settings-patch.json — replace YOUR_USERNAME with: $(whoami)"
echo ""
echo "2. Add factory rules to ~/.claude/CLAUDE.md:"
echo "   Append the contents of config/CLAUDE-global-additions.md"
echo ""
echo "3. Add output rules to your project CLAUDE.md:"
echo "   Append the contents of config/CLAUDE-project-additions.md"
echo ""
echo "4. Create factory.json in your project root:"
echo "   Copy config/factory.json.example and fill in your repo paths"
echo ""
echo "5. Reload your shell:"
echo "   source ~/.bashrc"
echo ""
echo "Done. Open Claude Code in a directory with factory.json to activate coordinator mode."
