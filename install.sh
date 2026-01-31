#!/bin/bash
# Quick install script for dreamspaces

set -e

DS_ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "Installing Dreamspaces..."
echo ""

# Make scripts executable
chmod +x "$DS_ROOT/bin/ds"
chmod +x "$DS_ROOT/tests/run_tests.sh"
chmod +x "$DS_ROOT/tests/"test_*.sh 2>/dev/null || true

# Add to PATH
SHELL_RC=""
if [[ -f "$HOME/.zshrc" ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ -f "$HOME/.bashrc" ]]; then
    SHELL_RC="$HOME/.bashrc"
fi

PATH_LINE="export PATH=\"\$PATH:$DS_ROOT/bin\""

if [[ -n "$SHELL_RC" ]]; then
    if grep -q "dreamspaces" "$SHELL_RC" 2>/dev/null; then
        echo "PATH already configured in $SHELL_RC"
    else
        echo "" >> "$SHELL_RC"
        echo "# Dreamspaces" >> "$SHELL_RC"
        echo "$PATH_LINE" >> "$SHELL_RC"

        # Add completion
        if [[ "$SHELL_RC" == *"zshrc"* ]]; then
            echo "fpath=($DS_ROOT/completions \$fpath)" >> "$SHELL_RC"
            echo "autoload -Uz compinit && compinit" >> "$SHELL_RC"
        else
            echo "source $DS_ROOT/completions/ds.bash" >> "$SHELL_RC"
        fi

        echo "Added to PATH in $SHELL_RC (with completions)"
    fi
else
    echo "Add this to your shell profile:"
    echo "  $PATH_LINE"
fi

echo ""
echo "Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Restart your terminal or run: source $SHELL_RC"
echo "  2. Run: ds setup"
echo "  3. Edit your projects: ds config"
echo ""
