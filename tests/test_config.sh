#!/bin/bash
# Tests for config.sh

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

cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Test: config_exists returns false when no config
assert_no_config() {
    if config_exists; then
        echo "FAIL: config_exists should return false"
        exit 1
    fi
}

# Test: config_create_default creates valid config
assert_create_default() {
    config_create_default
    if ! config_exists; then
        echo "FAIL: config_create_default should create config"
        exit 1
    fi
    if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
        echo "FAIL: config should be valid JSON"
        exit 1
    fi
}

# Test: config_get retrieves values
assert_config_get() {
    local version
    version=$(config_get '.version')
    if [[ "$version" != "0.1" ]]; then
        echo "FAIL: config_get should return version"
        exit 1
    fi
}

# Test: config_validate passes for valid config
assert_config_validate() {
    if ! config_validate; then
        echo "FAIL: config_validate should pass"
        exit 1
    fi
}

# Test: config_list_projects returns projects
assert_list_projects() {
    local projects
    projects=$(config_list_projects)
    if [[ -z "$projects" ]]; then
        echo "FAIL: config_list_projects should return projects"
        exit 1
    fi
}

# Run tests
assert_no_config
assert_create_default
assert_config_get
assert_config_validate
assert_list_projects

echo "All config tests passed"
