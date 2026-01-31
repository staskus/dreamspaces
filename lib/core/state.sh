#!/bin/bash
# State management for dreamspaces

state_exists() {
    [[ -f "$STATE_FILE" ]]
}

state_init() {
    ensure_config_dir
    if ! state_exists; then
        echo '{"workspaces": {}, "spacePool": []}' > "$STATE_FILE"
    fi
}

state_get() {
    local key="$1"
    if ! state_exists; then
        state_init
    fi
    jq -r "$key" "$STATE_FILE"
}

state_set() {
    local key="$1"
    local value="$2"
    if ! state_exists; then
        state_init
    fi
    local tmp
    tmp=$(mktemp)
    jq "$key = $value" "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
}

state_add_workspace() {
    local project="$1"
    local branch="$2"
    local space_index="$3"
    local workspace_key="${project}:${branch}"

    local workspace_data
    workspace_data=$(jq -n \
        --arg project "$project" \
        --arg branch "$branch" \
        --argjson space "$space_index" \
        --arg created "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{project: $project, branch: $branch, space: $space, created: $created}')

    state_set ".workspaces[\"$workspace_key\"]" "$workspace_data"
}

state_remove_workspace() {
    local project="$1"
    local branch="$2"
    local workspace_key="${project}:${branch}"

    if ! state_exists; then
        return 0
    fi
    local tmp
    tmp=$(mktemp)
    jq "del(.workspaces[\"$workspace_key\"])" "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
}

state_get_workspace() {
    local project="$1"
    local branch="$2"
    local workspace_key="${project}:${branch}"
    state_get ".workspaces[\"$workspace_key\"]"
}

state_list_workspaces() {
    state_get '.workspaces | keys[]'
}

state_workspace_exists() {
    local project="$1"
    local branch="$2"
    local result
    result=$(state_get_workspace "$project" "$branch")
    [[ "$result" != "null" ]]
}

state_claim_space() {
    local pool_size
    pool_size=$(config_get '.poolSize // 7')

    local used_spaces
    used_spaces=$(state_get '[.workspaces[].space] | sort')

    for ((i=2; i<=pool_size+1; i++)); do
        if ! echo "$used_spaces" | jq -e "index($i)" > /dev/null 2>&1; then
            echo "$i"
            return 0
        fi
    done

    log_error "No available spaces in pool"
    return 1
}

state_release_space() {
    local project="$1"
    local branch="$2"
    state_remove_workspace "$project" "$branch"
}
