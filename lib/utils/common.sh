#!/bin/bash
# Common utilities for dreamspaces

CONFIG_DIR="${CONFIG_DIR:-${HOME}/.config/dreamspaces}"
CONFIG_FILE="${CONFIG_FILE:-${CONFIG_DIR}/config.json}"
STATE_FILE="${STATE_FILE:-${CONFIG_DIR}/state.json}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[info]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[ok]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[warn]${NC} $1"
}

log_error() {
    echo -e "${RED}[error]${NC} $1" >&2
}

show_help() {
    cat << 'EOF'
Dreamspaces - macOS workspace automation

Usage: ds <command> [options]

Commands:
  setup              Install dependencies and create config
  open <project> [branch]  Open workspace for project+branch
  close [--cleanup]  Close current workspace (--cleanup removes worktree)
  switch             Switch between active workspaces
  list               List active workspaces
  arrange            Re-arrange windows on current space
  doctor             Check system health and diagnose issues
  cleanup            Remove orphaned workspace entries
  config             Open config file in editor

Options:
  --help, -h         Show this help
  --version, -v      Show version

Examples:
  ds setup
  ds open woocommerce-ios feature/login
  ds switch
  ds close
EOF
}

ensure_config_dir() {
    if [[ ! -d "$CONFIG_DIR" ]]; then
        mkdir -p "$CONFIG_DIR"
    fi
}

check_dependency() {
    local cmd="$1"
    local name="${2:-$1}"
    if command -v "$cmd" &> /dev/null; then
        return 0
    else
        return 1
    fi
}
