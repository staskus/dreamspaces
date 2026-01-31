#!/bin/bash
# Space claiming and releasing for dreamspaces

source "$DS_ROOT/lib/core/state.sh"
source "$DS_ROOT/lib/core/config.sh"

spaces_claim() {
    local project="$1"
    local branch="$2"

    if state_workspace_exists "$project" "$branch"; then
        local existing
        existing=$(state_get_workspace "$project" "$branch")
        echo "$existing" | jq -r '.space'
        return 0
    fi

    local space_index
    space_index=$(state_claim_space)
    if [[ -z "$space_index" ]]; then
        return 1
    fi

    state_add_workspace "$project" "$branch" "$space_index"
    echo "$space_index"
}

spaces_release() {
    local project="$1"
    local branch="$2"

    if ! state_workspace_exists "$project" "$branch"; then
        log_warn "Workspace ${project}:${branch} not found"
        return 0
    fi

    state_release_space "$project" "$branch"
    log_success "Released workspace ${project}:${branch}"
}

spaces_list_active() {
    state_list_workspaces
}

spaces_get_info() {
    local project="$1"
    local branch="$2"
    state_get_workspace "$project" "$branch"
}
