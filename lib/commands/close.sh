#!/bin/bash
# ds close - Close current workspace

# Extract JSON from mixed Hammerspoon output (hs.printf debug messages + JSON)
extract_json() {
    grep -E '^\{.*\}$' | tail -1
}

cmd_close() {
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

    # Kill tmux session
    local session_name="${project}-${branch}"
    session_name=$(echo "$session_name" | tr '/' '-' | tr '.' '-')
    if tmux has-session -t "$session_name" 2>/dev/null; then
        log_info "Killing tmux session: $session_name"
        tmux kill-session -t "$session_name" 2>/dev/null
    fi

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
}
