#!/bin/bash
# ds close - Close current workspace

source "$DS_ROOT/lib/core/state.sh"
source "$DS_ROOT/lib/core/spaces.sh"

cmd_close() {
    # Get current space from Hammerspoon
    local current_space=""
    if command -v hs &> /dev/null; then
        current_space=$(hs -c "return hs.spaces.focusedSpace()" 2>/dev/null)
    fi

    # Find workspace on current space
    local workspaces
    workspaces=$(state_get '.workspaces')

    if [[ "$workspaces" == "{}" ]] || [[ "$workspaces" == "null" ]]; then
        log_warn "No active workspaces"
        return 0
    fi

    # If we can't determine current space, ask user to specify
    if [[ -z "$current_space" ]]; then
        log_info "Active workspaces:"
        state_list_workspaces | while read -r ws; do
            local info
            info=$(state_get ".workspaces[\"$ws\"]")
            local space
            space=$(echo "$info" | jq -r '.space')
            echo "  - $ws (space $space)"
        done
        echo ""
        log_warn "Specify workspace to close: ds close <project> <branch>"
        return 1
    fi

    # Find and close workspace on current space
    local found=""
    while read -r ws; do
        local info
        info=$(state_get ".workspaces[\"$ws\"]")
        local space
        space=$(echo "$info" | jq -r '.space')
        if [[ "$space" == "$current_space" ]]; then
            found="$ws"
            break
        fi
    done < <(state_list_workspaces)

    if [[ -z "$found" ]]; then
        log_warn "No workspace on current space"
        return 0
    fi

    local project branch
    project=$(echo "$found" | cut -d: -f1)
    branch=$(echo "$found" | cut -d: -f2)

    spaces_release "$project" "$branch"
    log_success "Closed workspace: $found"
}
