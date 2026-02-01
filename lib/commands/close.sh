#!/bin/bash
# ds close - Close current workspace

cmd_close() {
    if ! command -v hs &> /dev/null; then
        log_error "Hammerspoon CLI not available"
        exit 1
    fi

    # Get current workspace info before closing
    local current
    current=$(hs -c "local ws = dreamspaces.current(); if ws then return hs.json.encode(ws) else return 'null' end" 2>/dev/null)

    if [[ "$current" == "null" ]] || [[ -z "$current" ]]; then
        log_warn "No workspace on current space"
        return 0
    fi

    local project branch
    project=$(echo "$current" | jq -r '.project')
    branch=$(echo "$current" | jq -r '.branch')

    log_info "Closing workspace: ${project}:${branch}"

    # Kill tmux session
    local session_name="${project}-${branch}"
    session_name=$(echo "$session_name" | tr '/' '-' | tr '.' '-')
    if tmux has-session -t "$session_name" 2>/dev/null; then
        log_info "Killing tmux session: $session_name"
        tmux kill-session -t "$session_name" 2>/dev/null
    fi

    # Close workspace via Hammerspoon (handles windows + space removal)
    local result
    result=$(hs -c "return hs.json.encode(dreamspaces.close())" 2>/dev/null)

    local success
    success=$(echo "$result" | jq -r '.success')
    if [[ "$success" == "true" ]]; then
        log_success "Closed workspace: ${project}:${branch}"
    else
        local error
        error=$(echo "$result" | jq -r '.error // "Unknown error"')
        log_error "Failed to close: $error"
        exit 1
    fi
}
