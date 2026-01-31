#!/bin/bash
# Tests for state.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Setup test environment
TEST_DIR=$(mktemp -d)
export CONFIG_DIR="$TEST_DIR"
export CONFIG_FILE="$TEST_DIR/config.json"
export STATE_FILE="$TEST_DIR/state.json"

source "$DS_ROOT/lib/utils/common.sh"
source "$DS_ROOT/lib/core/config.sh"
source "$DS_ROOT/lib/core/state.sh"

cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Create config for pool size
config_create_default

# Test: state_init creates state file
assert_state_init() {
    state_init
    if ! state_exists; then
        echo "FAIL: state_init should create state file"
        exit 1
    fi
}

# Test: state_add_workspace adds workspace
assert_add_workspace() {
    state_add_workspace "test-project" "main" 2
    local ws
    ws=$(state_get_workspace "test-project" "main")
    if [[ "$ws" == "null" ]]; then
        echo "FAIL: state_add_workspace should add workspace"
        exit 1
    fi
    local space
    space=$(echo "$ws" | jq -r '.space')
    if [[ "$space" != "2" ]]; then
        echo "FAIL: workspace should have space 2"
        exit 1
    fi
}

# Test: state_workspace_exists returns true
assert_workspace_exists() {
    if ! state_workspace_exists "test-project" "main"; then
        echo "FAIL: state_workspace_exists should return true"
        exit 1
    fi
}

# Test: state_list_workspaces returns workspaces
assert_list_workspaces() {
    local workspaces
    workspaces=$(state_list_workspaces)
    if [[ -z "$workspaces" ]]; then
        echo "FAIL: state_list_workspaces should return workspaces"
        exit 1
    fi
}

# Test: state_claim_space returns next available
assert_claim_space() {
    local space
    space=$(state_claim_space)
    if [[ "$space" != "3" ]]; then
        echo "FAIL: state_claim_space should return 3 (next after 2)"
        exit 1
    fi
}

# Test: state_remove_workspace removes workspace
assert_remove_workspace() {
    state_remove_workspace "test-project" "main"
    if state_workspace_exists "test-project" "main"; then
        echo "FAIL: state_remove_workspace should remove workspace"
        exit 1
    fi
}

# Run tests
assert_state_init
assert_add_workspace
assert_workspace_exists
assert_list_workspaces
assert_claim_space
assert_remove_workspace

echo "All state tests passed"
