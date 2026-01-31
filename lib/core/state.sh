#!/bin/bash
# State management for dreamspaces

STATE_LOCK="${STATE_FILE}.lock"

state_exists() {
    [[ -f "$STATE_FILE" ]]
}

state_init() {
    ensure_config_dir
    if ! state_exists; then
        echo '{"workspaces": {}}' > "$STATE_FILE"
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
    tmp=$(mktemp) || { log_error "Failed to create temp file"; return 1; }
    trap 'rm -f "$tmp"' RETURN
    if jq "$key = $value" "$STATE_FILE" > "$tmp"; then
        mv "$tmp" "$STATE_FILE"
    else
        log_error "Failed to update state"
        return 1
    fi
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
    tmp=$(mktemp) || { log_error "Failed to create temp file"; return 1; }
    trap 'rm -f "$tmp"' RETURN
    if jq "del(.workspaces[\"$workspace_key\"])" "$STATE_FILE" > "$tmp"; then
        mv "$tmp" "$STATE_FILE"
    else
        log_error "Failed to remove workspace from state"
        return 1
    fi
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

# Acquire lock using mkdir (atomic on all systems)
state_lock() {
    local max_attempts=50
    local attempt=0
    while ! mkdir "$STATE_LOCK" 2>/dev/null; do
        attempt=$((attempt + 1))
        if [[ $attempt -ge $max_attempts ]]; then
            log_error "Failed to acquire state lock after $max_attempts attempts"
            return 1
        fi
        sleep 0.1
    done
    # Set trap to release lock on exit
    trap 'rmdir "$STATE_LOCK" 2>/dev/null' EXIT
    return 0
}

state_unlock() {
    rmdir "$STATE_LOCK" 2>/dev/null
    trap - EXIT
}

# Claim a space with locking to prevent race conditions
state_claim_space() {
    state_lock || return 1

    local pool_size
    pool_size=$(config_get '.poolSize // 7')

    local used_spaces
    used_spaces=$(state_get '[.workspaces[].space] | sort')

    # Spaces start at 2 (Space 1 is reserved for static apps)
    for ((i=2; i<=pool_size+1; i++)); do
        if ! echo "$used_spaces" | jq -e "index($i)" > /dev/null 2>&1; then
            state_unlock
            echo "$i"
            return 0
        fi
    done

    state_unlock
    log_error "No available spaces in pool (pool size: $pool_size)"
    return 1
}

state_release_space() {
    local project="$1"
    local branch="$2"
    state_remove_workspace "$project" "$branch"
}
