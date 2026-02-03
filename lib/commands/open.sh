#!/bin/bash
# ds open <project> [branch] - Open workspace for project+branch

source "$DS_ROOT/lib/core/config.sh"
source "$DS_ROOT/lib/core/apps.sh"

check_hammerspoon_accessibility() {
    if ! command -v hs &> /dev/null; then
        log_error "Hammerspoon CLI (hs) not available"
        log_info "Run 'ds setup' and ensure Hammerspoon has accessibility permissions"
        return 1
    fi

    local has_access
    has_access=$(hs -c "return hs.accessibilityState()" 2>/dev/null)
    if [[ "$has_access" != "true" ]]; then
        log_warn "Hammerspoon accessibility issue - restarting..."
        pkill -x Hammerspoon
        sleep 1
        open -a Hammerspoon
        sleep 2

        has_access=$(hs -c "return hs.accessibilityState()" 2>/dev/null)
        if [[ "$has_access" != "true" ]]; then
            log_error "Hammerspoon does not have accessibility permissions"
            log_info "Enable in: System Settings > Privacy & Security > Accessibility"
            return 1
        fi
    fi

    return 0
}

cmd_open() {
    local project="${1:-}"
    local branch="${2:-main}"

    if [[ -z "$project" ]]; then
        log_error "Usage: ds open <project> [branch]"
        echo ""
        log_info "Available projects:"
        config_list_projects | while read -r p; do
            echo "  - $p"
        done
        exit 1
    fi

    if ! check_hammerspoon_accessibility; then
        exit 1
    fi

    local project_config
    project_config=$(config_get_project "$project")
    if [[ "$project_config" == "null" ]]; then
        log_error "Project not found: $project"
        echo ""
        log_info "Available projects:"
        config_list_projects | while read -r p; do
            echo "  - $p"
        done
        exit 1
    fi

    log_info "Opening workspace: ${project}:${branch}"

    # Create/claim space via Hammerspoon (single source of truth)
    local raw_result result
    raw_result=$(hs -c "return hs.json.encode(dreamspaces.open('$project', '$branch'))" 2>/dev/null)
    # Extract only the JSON line (hs.printf outputs debug messages before it)
    result=$(echo "$raw_result" | grep -E '^\{.*\}$' | tail -1)

    if [[ -z "$result" ]]; then
        log_error "Failed to get response from Hammerspoon"
        log_error "Raw output: $raw_result"
        exit 1
    fi

    local success
    success=$(echo "$result" | jq -r '.success' 2>/dev/null)
    if [[ "$success" != "true" ]]; then
        local error
        error=$(echo "$result" | jq -r '.error // "Unknown error"')
        log_error "Failed to create space: $error"
        exit 1
    fi

    local space_id reused
    space_id=$(echo "$result" | jq -r '.spaceId')
    reused=$(echo "$result" | jq -r '.reused // false')

    if [[ "$reused" == "true" ]]; then
        log_success "Switched to existing workspace (space ID: $space_id)"
    else
        log_success "Created new space (ID: $space_id)"

        # Launch apps (only for new workspaces)
        sleep 0.5
        apps_launch_all "$project" "$branch"

        # Move windows to this space and arrange
        log_info "Arranging windows..."
        sleep 2
        hs -c "dreamspaces.moveWindowsToCurrentSpace(); dreamspaces.arrangeWindows('$project')"
    fi

    log_success "Workspace opened: ${project}:${branch}"
}
