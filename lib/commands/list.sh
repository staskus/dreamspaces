#!/bin/bash
# ds list - List active workspaces

source "$DS_ROOT/lib/core/state.sh"

cmd_list() {
    local workspaces
    workspaces=$(state_list_workspaces 2>/dev/null)

    if [[ -z "$workspaces" ]]; then
        log_info "No active workspaces"
        return 0
    fi

    echo "Active workspaces:"
    echo ""
    printf "%-30s %-10s %-20s\n" "WORKSPACE" "SPACE" "CREATED"
    printf "%-30s %-10s %-20s\n" "---------" "-----" "-------"

    while read -r ws; do
        local info
        info=$(state_get ".workspaces[\"$ws\"]")
        local space created
        space=$(echo "$info" | jq -r '.space')
        created=$(echo "$info" | jq -r '.created')
        printf "%-30s %-10s %-20s\n" "$ws" "$space" "$created"
    done <<< "$workspaces"
}
