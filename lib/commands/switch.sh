#!/bin/bash
# ds switch - Switch between active workspaces

source "$DS_ROOT/lib/core/state.sh"
source "$DS_ROOT/lib/core/config.sh"
source "$DS_ROOT/lib/core/apps.sh"

restore_workspace() {
    local workspace_key="$1"
    local project branch

    project=$(echo "$workspace_key" | cut -d: -f1)
    branch=$(echo "$workspace_key" | cut -d: -f2-)

    log_info "Restoring workspace: $project:$branch"

    # Re-launch apps (will skip if already running for tmux sessions)
    apps_launch_all "$project" "$branch"

    # Re-arrange windows
    sleep 2
    if command -v hs &> /dev/null; then
        hs -c "dreamspaces.reload(); dreamspaces.arrangeWindows('$project')"
    fi
}

cmd_switch() {
    local workspaces
    workspaces=$(state_list_workspaces 2>/dev/null)

    if [[ -z "$workspaces" ]]; then
        log_warn "No active workspaces"
        log_info "Open a workspace: ds open <project> [branch]"
        return 0
    fi

    # If Hammerspoon is available and has picker, use it
    if command -v hs &> /dev/null; then
        # Use CLI picker instead since HS picker doesn't restore apps
        :
    fi

    # List workspaces and let user choose
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
        restore_workspace "$selected"
        log_success "Switched to $selected"
    else
        log_error "Invalid selection"
        return 1
    fi
}
