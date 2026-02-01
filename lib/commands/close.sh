#!/bin/bash
# ds close - Close current workspace

source "$DS_ROOT/lib/core/config.sh"

# Extract JSON from mixed Hammerspoon output (hs.printf debug messages + JSON)
extract_json() {
    grep -E '^\{.*\}$' | tail -1
}

# Get worktree path for a branch (same logic as apps.sh)
get_worktree_path() {
    local project_path="$1"
    local branch="$2"
    local parent_dir
    parent_dir=$(dirname "$project_path")
    local repo_name
    repo_name=$(basename "$project_path")
    local branch_dir
    branch_dir=$(echo "$branch" | tr '/' '-')
    echo "${parent_dir}/${repo_name}-${branch_dir}"
}

# Check if worktree has uncommitted changes
worktree_has_uncommitted_changes() {
    local worktree_path="$1"
    if [[ ! -d "$worktree_path" ]]; then
        return 1
    fi
    local status
    status=$(git -C "$worktree_path" status --porcelain 2>/dev/null)
    [[ -n "$status" ]]
}

# Check if worktree has unpushed commits
worktree_has_unpushed_commits() {
    local worktree_path="$1"
    if [[ ! -d "$worktree_path" ]]; then
        return 1
    fi
    local unpushed
    unpushed=$(git -C "$worktree_path" log @{u}.. --oneline 2>/dev/null)
    [[ -n "$unpushed" ]]
}

# Remove worktree for a project+branch
remove_worktree() {
    local project="$1"
    local branch="$2"

    local project_config
    project_config=$(config_get_project "$project")

    if [[ "$project_config" == "null" ]]; then
        log_warn "Project config not found: $project"
        return 1
    fi

    local use_worktree project_path
    use_worktree=$(echo "$project_config" | jq -r '.useWorktree // false')
    project_path=$(echo "$project_config" | jq -r '.path' | sed "s|^~|$HOME|")

    if [[ "$use_worktree" != "true" ]]; then
        log_info "Project does not use worktrees, skipping cleanup"
        return 0
    fi

    local worktree_path
    worktree_path=$(get_worktree_path "$project_path" "$branch")

    if [[ ! -d "$worktree_path" ]]; then
        log_info "Worktree not found: $worktree_path"
        return 0
    fi

    # Safety checks
    if worktree_has_uncommitted_changes "$worktree_path"; then
        log_error "Worktree has uncommitted changes: $worktree_path"
        log_info "Commit or stash changes before cleanup"
        return 1
    fi

    if worktree_has_unpushed_commits "$worktree_path"; then
        log_error "Worktree has unpushed commits: $worktree_path"
        log_info "Push commits before cleanup"
        return 1
    fi

    log_info "Removing worktree: $worktree_path"

    # Try wt remove first, fall back to git worktree remove
    if command -v wt &> /dev/null; then
        if (cd "$project_path" && wt remove "$branch" 2>/dev/null); then
            log_success "Removed worktree via wt"
            return 0
        fi
    fi

    # Fallback to git worktree remove
    if git -C "$project_path" worktree remove "$worktree_path" 2>/dev/null; then
        log_success "Removed worktree via git"
        return 0
    fi

    # Force remove if regular remove failed
    log_warn "Standard removal failed, trying force remove..."
    if git -C "$project_path" worktree remove --force "$worktree_path" 2>/dev/null; then
        log_success "Force removed worktree"
        return 0
    fi

    log_error "Failed to remove worktree"
    return 1
}

cmd_close() {
    local cleanup=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --cleanup|-c)
                cleanup=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                log_info "Usage: ds close [--cleanup]"
                exit 1
                ;;
        esac
    done

    if ! command -v hs &> /dev/null; then
        log_error "Hammerspoon CLI not available"
        exit 1
    fi

    # Get current workspace info before closing
    local raw_current current
    raw_current=$(hs -c "local ws = dreamspaces.current(); if ws then return hs.json.encode(ws) else return 'null' end" 2>/dev/null)
    current=$(echo "$raw_current" | extract_json)

    # Handle null or empty
    if [[ -z "$current" ]] || [[ "$current" == "null" ]] || [[ "$raw_current" == "null" ]]; then
        log_warn "No workspace on current space"
        return 0
    fi

    local project branch
    project=$(echo "$current" | jq -r '.project' 2>/dev/null)
    branch=$(echo "$current" | jq -r '.branch' 2>/dev/null)

    if [[ -z "$project" ]] || [[ "$project" == "null" ]]; then
        log_warn "No workspace on current space"
        return 0
    fi

    log_info "Closing workspace: ${project}:${branch}"

    # Session name for tmux (used later if cleanup requested)
    local session_name="${project}-${branch}"
    session_name=$(echo "$session_name" | tr '/' '-' | tr '.' '-')

    # Close workspace via Hammerspoon (handles windows + space removal)
    local raw_result result
    raw_result=$(hs -c "return hs.json.encode(dreamspaces.close())" 2>/dev/null)
    result=$(echo "$raw_result" | extract_json)

    local success
    success=$(echo "$result" | jq -r '.success' 2>/dev/null)
    if [[ "$success" == "true" ]]; then
        log_success "Closed workspace: ${project}:${branch}"
    else
        local error
        error=$(echo "$result" | jq -r '.error // "Unknown error"' 2>/dev/null)
        log_error "Failed to close: $error"
        exit 1
    fi

    # Cleanup worktree and tmux session if requested
    if [[ "$cleanup" == "true" ]]; then
        # Kill tmux session
        if tmux has-session -t "$session_name" 2>/dev/null; then
            log_info "Killing tmux session: $session_name"
            tmux kill-session -t "$session_name" 2>/dev/null
        fi

        log_info "Cleaning up worktree..."
        remove_worktree "$project" "$branch"
    fi
}
