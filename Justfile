# =============================================================================
# Justfile — dsc011-check-bash
# https://github.com/dhard/dsc011-check-bash
#
# Prerequisites:
#   macOS:        brew install just
#   WSL2/Ubuntu:  sudo apt install just
#
# Recipes:
#   just install          install to ~/bin (no sudo)
#   just install-system   install to /usr/local/bin (sudo if needed)
#   just uninstall        remove from ~/bin and/or /usr/local/bin
#   just test             run the full test suite
#   just check            run ShellCheck (requires: brew/apt install shellcheck)
#   just version          print current check_bash version
# =============================================================================

# Default — list available recipes
default:
    @just --list

# ---------------------------------------------------------------------------
# Install to ~/bin (no sudo required)
# ---------------------------------------------------------------------------
install:
    @bash install_check_bash.sh --user

# ---------------------------------------------------------------------------
# Install to /usr/local/bin (sudo prompted if needed)
# ---------------------------------------------------------------------------
install-system:
    @bash install_check_bash.sh --system

# ---------------------------------------------------------------------------
# Remove from ~/bin and/or /usr/local/bin (whichever exist)
# ---------------------------------------------------------------------------
uninstall:
    @bash install_check_bash.sh --uninstall

# ---------------------------------------------------------------------------
# Run the full test suite against the local copy of check_bash
# ---------------------------------------------------------------------------
test:
    @bash test_check_bash.sh ./check_bash

# ---------------------------------------------------------------------------
# Run ShellCheck static analysis on all scripts
# Requires: brew install shellcheck  OR  sudo apt install shellcheck
# ---------------------------------------------------------------------------
check:
    @shellcheck -S warning check_bash install_check_bash.sh test_check_bash.sh

# ---------------------------------------------------------------------------
# Print the current version of check_bash
# ---------------------------------------------------------------------------
version:
    @./check_bash --version
