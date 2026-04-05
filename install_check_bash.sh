#!/usr/bin/env bash
# =============================================================================
# install_check_bash.sh
# One-time installer for the check_bash DSC 011 answer-checking tool.
#
# Run once in Terminal (macOS) or WSL2 bash shell (Windows 11):
#   bash install_check_bash.sh
#
# Or install directly without downloading this file first:
#   bash <(curl -fsSL https://raw.githubusercontent.com/dhard/check-bash-install-test/main/install_check_bash.sh)
# =============================================================================

set -euo pipefail

INSTALL_DIR="$HOME/bin"
SCRIPT_NAME="check_bash"
SCRIPT_URL="https://raw.githubusercontent.com/dhard/check-bash-install-test/main/check_bash"

# ---------------------------------------------------------------------------
# Create ~/bin if it doesn't exist
# ---------------------------------------------------------------------------
if [[ ! -d "$INSTALL_DIR" ]]; then
    mkdir -p "$INSTALL_DIR"
    echo "Created $INSTALL_DIR"
fi

# ---------------------------------------------------------------------------
# Download the script
# ---------------------------------------------------------------------------
echo "Downloading check_bash..."
if command -v curl &>/dev/null; then
    curl -fsSL "$SCRIPT_URL" -o "$INSTALL_DIR/$SCRIPT_NAME"
elif command -v wget &>/dev/null; then
    wget -q "$SCRIPT_URL" -O "$INSTALL_DIR/$SCRIPT_NAME"
else
    echo "ERROR: Neither curl nor wget found." >&2
    echo "macOS:  brew install curl" >&2
    echo "Ubuntu: sudo apt install curl" >&2
    exit 1
fi

chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
echo "Installed: $INSTALL_DIR/$SCRIPT_NAME"

# ---------------------------------------------------------------------------
# Ensure ~/bin is on PATH in shell startup file
# ---------------------------------------------------------------------------
PATH_LINE='export PATH="$HOME/bin:$PATH"'
SHELL_RC=""

if [[ -n "${ZSH_VERSION:-}" ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ -n "${BASH_VERSION:-}" ]]; then
    # macOS bash lands in .bash_profile; Linux/WSL2 in .bashrc
    if [[ "$(uname -s)" == "Darwin" ]]; then
        SHELL_RC="$HOME/.bash_profile"
    else
        SHELL_RC="$HOME/.bashrc"
    fi
fi

if [[ -n "$SHELL_RC" ]]; then
    if ! grep -qF 'HOME/bin' "$SHELL_RC" 2>/dev/null; then
        {
            echo ""
            echo "# Added by DSC 011 check_bash installer"
            echo "$PATH_LINE"
        } >> "$SHELL_RC"
        echo "Added PATH entry to $SHELL_RC"
    else
        echo "$INSTALL_DIR already on PATH in $SHELL_RC"
    fi
fi

# Make available immediately in this session
export PATH="$INSTALL_DIR:$PATH"

# ---------------------------------------------------------------------------
# Verify installation
# ---------------------------------------------------------------------------
echo ""
if command -v check_bash &>/dev/null; then
    echo "✓ Installation successful!"
    echo ""
    echo "Smoke test:"
    HASH=$(echo "DSC 011" | check_bash --make-key)
    echo "DSC 011" | check_bash "$HASH"
    echo ""
    echo "check_bash is ready. Open a new terminal or run:"
    echo "  source $SHELL_RC"
else
    echo "Installed, but check_bash not yet on PATH in this shell."
    echo "Run:  source $SHELL_RC"
    echo "Or open a new terminal window and try: check_bash --help"
fi
