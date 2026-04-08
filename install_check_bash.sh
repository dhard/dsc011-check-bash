#!/usr/bin/env bash
# =============================================================================
# install_check_bash.sh — installer for check_bash v2.2
# DSC 011, UC Merced | https://github.com/dhard/dsc011-check-bash
#
# USAGE
#   Via just (recommended — from a cloned repo):
#     just install           # install to ~/bin
#     just install-system    # install to /usr/local/bin
#     just uninstall         # remove from ~/bin and/or /usr/local/bin
#
#   Via curl (no repo clone needed):
#     curl -fsSL https://raw.githubusercontent.com/dhard/dsc011-check-bash/main/install_check_bash.sh | bash
#     curl -fsSL https://raw.githubusercontent.com/dhard/dsc011-check-bash/main/install_check_bash.sh | bash -s -- --system
#     curl -fsSL https://raw.githubusercontent.com/dhard/dsc011-check-bash/main/install_check_bash.sh | bash -s -- --uninstall
#
#   Directly (from a cloned repo):
#     bash install_check_bash.sh [--user|--system|--uninstall]
#
# OPTIONS
#   --user        Install to ~/bin (default, no sudo required)
#   --system      Install to /usr/local/bin (sudo prompted if needed)
#   --uninstall   Remove from ~/bin and/or /usr/local/bin
# =============================================================================

set -euo pipefail

REPO="dhard/dsc011-check-bash"
BRANCH="main"
SCRIPT_NAME="check_bash"
SCRIPT_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/check_bash"

USER_DIR="$HOME/bin"
SYSTEM_DIR="/usr/local/bin"

# ---------------------------------------------------------------------------
# Parse arguments — default to user install
# ---------------------------------------------------------------------------
MODE="user"
case "${1:-}" in
    --user)      MODE="user" ;;
    --system)    MODE="system" ;;
    --uninstall) MODE="uninstall" ;;
    "")          MODE="user" ;;
    *)
        echo "ERROR: Unknown option: $1" >&2
        echo "Usage: $0 [--user|--system|--uninstall]" >&2
        exit 1 ;;
esac

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Download check_bash to a target path
_download() {
    local target="$1"
    if command -v curl &>/dev/null; then
        curl -fsSL "$SCRIPT_URL" -o "$target"
    elif command -v wget &>/dev/null; then
        wget -q "$SCRIPT_URL" -O "$target"
    else
        echo "ERROR: Neither curl nor wget found." >&2
        echo "Install one with: brew install curl  OR  sudo apt install curl" >&2
        exit 1
    fi
    chmod +x "$target"
}

# Detect if we are running from a local repo (check_bash exists alongside this script)
_local_source() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    [[ -f "$script_dir/check_bash" ]]
}

# Copy or download check_bash to a destination
_install_to() {
    local dest_dir="$1"
    local dest="$dest_dir/$SCRIPT_NAME"

    if _local_source; then
        local script_dir
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        cp "$script_dir/check_bash" "$dest"
        chmod +x "$dest"
        echo "Copied from local repo: $dest"
    else
        echo "Downloading $SCRIPT_NAME from GitHub..."
        _download "$dest"
        echo "Downloaded: $dest"
    fi
}

# Add a directory to PATH in the user's shell rc file
_add_to_path() {
    local dir="$1"
    local path_line="export PATH=\"$dir:\$PATH\""
    local shell_rc=""

    if [[ -n "${ZSH_VERSION:-}" ]]; then
        shell_rc="$HOME/.zshrc"
    elif [[ -n "${BASH_VERSION:-}" ]]; then
        if [[ "$(uname -s)" == "Darwin" ]]; then
            shell_rc="$HOME/.bash_profile"
        else
            shell_rc="$HOME/.bashrc"
        fi
    fi

    if [[ -n "$shell_rc" ]]; then
        if ! grep -qF "$dir" "$shell_rc" 2>/dev/null; then
            printf '\n# Added by DSC 011 check_bash installer\n%s\n' \
                "$path_line" >> "$shell_rc"
            echo "Added $dir to PATH in $shell_rc"
        else
            echo "$dir already on PATH in $shell_rc"
        fi
    fi
}

# Remove PATH entry added by this installer from shell rc files
_remove_from_path() {
    local dir="$1"
    local rc_files=(
        "$HOME/.zshrc"
        "$HOME/.bashrc"
        "$HOME/.bash_profile"
    )
    for rc in "${rc_files[@]}"; do
        if [[ -f "$rc" ]] && grep -qF "$dir" "$rc" 2>/dev/null; then
            # Remove the comment line and the export line together
            grep -v "# Added by DSC 011 check_bash installer" "$rc" | \
                grep -v "export PATH=\"$dir" > "${rc}.tmp" && \
                mv "${rc}.tmp" "$rc"
            echo "Removed $dir from PATH in $rc"
        fi
    done
}

# Run a self-test smoke test after install
_smoke_test() {
    local binary="$1"
    local hash
    hash=$(echo "DSC 011" | "$binary" --make-key 2>/dev/null || true)
    if [[ ${#hash} -eq 64 ]]; then
        local result
        result=$(echo "DSC 011" | "$binary" "$hash" 2>/dev/null || true)
        echo ""
        echo "Smoke test:"
        echo "  $result"
        echo ""
        echo "✓ Installation successful!"
        echo ""
        echo "$("$binary" --version) is ready. Open a new terminal or run:"
    else
        echo "WARNING: smoke test produced unexpected output." >&2
        echo "Please report at https://github.com/${REPO}/issues" >&2
    fi
}

# ---------------------------------------------------------------------------
# INSTALL — user mode (~/bin)
# ---------------------------------------------------------------------------
if [[ "$MODE" == "user" ]]; then
    mkdir -p "$USER_DIR"
    _install_to "$USER_DIR"
    _add_to_path "$USER_DIR"
    export PATH="$USER_DIR:$PATH"

    _smoke_test "$USER_DIR/$SCRIPT_NAME"

    # Determine which rc file was updated for the source hint
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        echo "  source $HOME/.zshrc"
    elif [[ "$(uname -s)" == "Darwin" ]]; then
        echo "  source $HOME/.bash_profile"
    else
        echo "  source $HOME/.bashrc"
    fi
    exit 0
fi

# ---------------------------------------------------------------------------
# INSTALL — system mode (/usr/local/bin)
# ---------------------------------------------------------------------------
if [[ "$MODE" == "system" ]]; then
    # Check if we need sudo
    if [[ -w "$SYSTEM_DIR" ]]; then
        SUDO=""
    else
        echo "Installing to $SYSTEM_DIR requires elevated privileges."
        SUDO="sudo"
    fi

    $SUDO mkdir -p "$SYSTEM_DIR"

    # Download to a temp file first, then move into place
    if _local_source; then
        local_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        $SUDO cp "$local_dir/check_bash" "$SYSTEM_DIR/$SCRIPT_NAME"
        $SUDO chmod +x "$SYSTEM_DIR/$SCRIPT_NAME"
        echo "Copied from local repo: $SYSTEM_DIR/$SCRIPT_NAME"
    else
        TMPFILE=$(mktemp -t check_bash.XXXXXX)
        trap 'rm -f "$TMPFILE"' EXIT
        echo "Downloading $SCRIPT_NAME from GitHub..."
        _download "$TMPFILE"
        $SUDO mv "$TMPFILE" "$SYSTEM_DIR/$SCRIPT_NAME"
        $SUDO chmod +x "$SYSTEM_DIR/$SCRIPT_NAME"
        echo "Installed: $SYSTEM_DIR/$SCRIPT_NAME"
    fi

    # Remove user install if it exists to avoid shadowing
    if [[ -f "$USER_DIR/$SCRIPT_NAME" ]]; then
        echo ""
        echo "Found existing user install at $USER_DIR/$SCRIPT_NAME."
        read -r -p "Remove it to avoid PATH conflicts? [y/N] " response
        if [[ "${response,,}" == "y" ]]; then
            rm -f "$USER_DIR/$SCRIPT_NAME"
            _remove_from_path "$USER_DIR"
            echo "Removed user install."
        fi
    fi

    _smoke_test "$SYSTEM_DIR/$SCRIPT_NAME"
    echo "  (No shell restart needed — $SYSTEM_DIR is on PATH by default)"
    exit 0
fi

# ---------------------------------------------------------------------------
# UNINSTALL — remove from both locations
# ---------------------------------------------------------------------------
if [[ "$MODE" == "uninstall" ]]; then
    REMOVED=0

    # User install
    if [[ -f "$USER_DIR/$SCRIPT_NAME" ]]; then
        rm -f "$USER_DIR/$SCRIPT_NAME"
        echo "Removed: $USER_DIR/$SCRIPT_NAME"
        _remove_from_path "$USER_DIR"
        REMOVED=$(( REMOVED + 1 ))
    fi

    # System install
    if [[ -f "$SYSTEM_DIR/$SCRIPT_NAME" ]]; then
        if [[ -w "$SYSTEM_DIR" ]]; then
            rm -f "$SYSTEM_DIR/$SCRIPT_NAME"
        else
            sudo rm -f "$SYSTEM_DIR/$SCRIPT_NAME"
        fi
        echo "Removed: $SYSTEM_DIR/$SCRIPT_NAME"
        REMOVED=$(( REMOVED + 1 ))
    fi

    if [[ "$REMOVED" -eq 0 ]]; then
        echo "check_bash not found in $USER_DIR or $SYSTEM_DIR — nothing to remove."
        exit 0
    fi

    echo ""
    echo "✓ check_bash uninstalled."
    exit 0
fi
