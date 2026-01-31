#!/bin/bash
# ds switch - Switch between active workspaces

source "$DS_ROOT/lib/core/state.sh"
source "$DS_ROOT/lib/core/config.sh"

cmd_switch() {
    local workspaces
    workspaces=$(state_list_workspaces 2>/dev/null)

    if [[ -z "$workspaces" ]]; then
        log_warn "No active workspaces"
        log_info "Open a workspace: ds open <project> [branch]"
        return 0
    fi

    # Use Hammerspoon picker if available (better UX)
    if command -v hs &> /dev/null; then
        hs -c "dreamspaces.showSwitchPicker()"
        return 0
    fi

    # Fallback: CLI picker
    log_info "Active workspaces:"
    local i=1
    local ws_array=()
    while read -r ws; do
        local info
        info=$(state_get ".workspaces[\"$ws\"]")
        local space
        space=$(echo "$info" | jq -r '.space')
        echo "  $i) $ws (space $space)"
        ws_array+=("$ws")
        ((i++))
    done <<< "$workspaces"

    echo ""
    read -rp "Select workspace (1-$((i-1))): " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice < i)); then
        local selected="${ws_array[$((choice-1))]}"
        local info project branch space
        info=$(state_get ".workspaces[\"$selected\"]")
        project=$(echo "$info" | jq -r '.project')
        space=$(echo "$info" | jq -r '.space')

        log_info "Switching to $selected (space $space)..."

        # Use Hammerspoon to switch space and arrange
        if command -v hs &> /dev/null; then
            hs -c "dreamspaces.reload()"
            hs -c "hs.spaces.gotoSpace(hs.spaces.allSpaces()[hs.screen.mainScreen():getUUID()][$space])"
            sleep 0.5
            hs -c "dreamspaces.arrangeWindows('$project')"
        fi

        log_success "Switched to $selected"
    else
        log_error "Invalid selection"
        return 1
    fi
}
