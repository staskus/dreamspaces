#!/bin/bash
# ds switch - Switch between active workspaces

source "$DS_ROOT/lib/core/state.sh"

cmd_switch() {
    local workspaces
    workspaces=$(state_list_workspaces 2>/dev/null)

    if [[ -z "$workspaces" ]]; then
        log_warn "No active workspaces"
        log_info "Open a workspace: ds open <project> [branch]"
        return 0
    fi

    # If Hammerspoon is available, use the picker
    if command -v hs &> /dev/null; then
        hs -c "dreamspaces.showPicker()"
        return 0
    fi

    # Fallback: list workspaces and let user choose
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
        local info
        info=$(state_get ".workspaces[\"$selected\"]")
        local space
        space=$(echo "$info" | jq -r '.space')
        log_info "Switching to space $space..."
        # Use AppleScript to switch spaces
        osascript -e "tell application \"System Events\" to key code $((17 + space)) using control down" 2>/dev/null || true
    else
        log_error "Invalid selection"
        return 1
    fi
}
