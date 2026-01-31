#!/bin/bash
# App launching for dreamspaces

source "$DS_ROOT/lib/core/config.sh"

# URL encode a string
urlencode() {
    local string="$1"
    python3 -c "import urllib.parse; print(urllib.parse.quote('$string', safe=''))"
}

# Get worktree path for a branch
# worktree-cli creates worktrees as siblings with format: {repo-name}-{branch-name}
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

apps_launch_ide() {
    local project="$1"
    local branch="$2"
    local work_path="$3"
    local project_config
    project_config=$(config_get_project "$project")

    if [[ "$project_config" == "null" ]]; then
        log_error "Project not found: $project"
        return 1
    fi

    local ide_app ide_open
    ide_app=$(echo "$project_config" | jq -r '.ide.app // "Cursor"')
    ide_open=$(echo "$project_config" | jq -r '.ide.open // "."')

    if [[ ! -d "$work_path" ]]; then
        log_error "Work path not found: $work_path"
        return 1
    fi

    local full_path="$work_path/$ide_open"
    log_info "Opening $ide_app: $full_path"
    if ! open -a "$ide_app" "$full_path"; then
        log_error "Failed to open $ide_app"
        return 1
    fi
}

apps_launch_terminal() {
    local project="$1"
    local branch="$2"
    local work_path="$3"
    local project_config
    project_config=$(config_get_project "$project")

    local use_tmux terminal_app
    use_tmux=$(echo "$project_config" | jq -r '.terminal.tmux // false')
    terminal_app=$(echo "$project_config" | jq -r '.terminal.app // "iTerm"')

    local session_name="${project}-${branch}"
    session_name=$(echo "$session_name" | tr '/' '-' | tr '.' '-')

    log_info "Opening $terminal_app (tmux=$use_tmux, session=$session_name)"

    # Check if tmux session already exists
    local session_exists="false"
    if tmux has-session -t "$session_name" 2>/dev/null; then
        session_exists="true"
        log_info "Restoring existing tmux session: $session_name"
    fi

    if [[ "$terminal_app" == "iTerm" ]] || [[ "$terminal_app" == "iTerm2" ]]; then
        if [[ "$use_tmux" == "true" ]]; then
            if [[ "$session_exists" == "true" ]]; then
                # Just attach to existing session in new window
                osascript - "$session_name" <<'APPLESCRIPT'
on run argv
    set sessionName to item 1 of argv
    tell application "iTerm"
        set newWindow to (create window with profile "Default")
        tell current session of newWindow
            write text "tmux attach -t '" & sessionName & "'"
        end tell
    end tell
end run
APPLESCRIPT
            else
                # Create new tmux session in work path
                osascript - "$work_path" "$session_name" <<'APPLESCRIPT'
on run argv
    set workPath to item 1 of argv
    set sessionName to item 2 of argv
    tell application "iTerm"
        set newWindow to (create window with profile "Default")
        tell current session of newWindow
            write text "cd '" & workPath & "' && tmux new-session -s '" & sessionName & "'"
        end tell
    end tell
end run
APPLESCRIPT
            fi
        else
            osascript - "$work_path" <<'APPLESCRIPT'
on run argv
    set workPath to item 1 of argv
    tell application "iTerm"
        set newWindow to (create window with profile "Default")
        tell current session of newWindow
            write text "cd '" & workPath & "'"
        end tell
    end tell
end run
APPLESCRIPT
        fi
    else
        # Terminal.app fallback - escape single quotes
        local work_path_escaped="${work_path//\'/\'\\\'\'}"
        local session_name_escaped="${session_name//\'/\'\\\'\'}"
        if [[ "$use_tmux" == "true" ]]; then
            if [[ "$session_exists" == "true" ]]; then
                osascript -e "tell application \"Terminal\" to do script \"tmux attach -t '$session_name_escaped'\""
            else
                osascript -e "tell application \"Terminal\" to do script \"cd '$work_path_escaped' && tmux new-session -s '$session_name_escaped'\""
            fi
        else
            osascript -e "tell application \"Terminal\" to do script \"cd '$work_path_escaped'\""
        fi
    fi
}

apps_launch_notes() {
    local project="$1"
    local branch="$2"
    local project_config
    project_config=$(config_get_project "$project")

    local vault folder vault_path
    vault=$(echo "$project_config" | jq -r '.notes.vault // empty')
    folder=$(echo "$project_config" | jq -r '.notes.folder // empty')
    vault_path=$(echo "$project_config" | jq -r '.notes.path // empty' | sed "s|^~|$HOME|")

    if [[ -z "$vault" ]]; then
        return 0
    fi

    local note_name="${branch}.md"
    note_name=$(echo "$note_name" | tr '/' '-')

    # Use explicit path if provided, otherwise search common locations
    local vault_base=""
    if [[ -n "$vault_path" ]] && [[ -d "$vault_path" ]]; then
        vault_base="$vault_path"
    else
        local search_paths=(
            "$HOME/Documents/$vault"
            "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/$vault"
            "$HOME/Obsidian/$vault"
        )
        for path in "${search_paths[@]}"; do
            if [[ -d "$path" ]]; then
                vault_base="$path"
                break
            fi
        done
    fi

    if [[ -n "$vault_base" ]]; then
        local full_note_dir="${vault_base}/${folder}"
        mkdir -p "$full_note_dir"

        local note_file="${full_note_dir}/${note_name}"
        if [[ ! -f "$note_file" ]]; then
            log_info "Creating note: $note_file"
            cat > "$note_file" << EOF
# ${branch}

**Project**: ${project}
**Created**: $(date +%Y-%m-%d)

## Goals

- [ ]

## Notes

## Log

### $(date +%Y-%m-%d)
- Started work on ${branch}
EOF
        fi

        local note_path="${folder}/${note_name}"
        log_info "Opening Obsidian note: $note_path in vault $vault"
        # Use proper URL encoding
        local vault_encoded file_encoded
        vault_encoded=$(urlencode "$vault")
        file_encoded=$(urlencode "$note_path")
        open "obsidian://open?vault=${vault_encoded}&file=${file_encoded}"
    else
        log_warn "Obsidian vault not found: $vault (specify notes.path in config)"
    fi
}

apps_launch_urls() {
    local project="$1"
    local branch="$2"
    local project_config
    project_config=$(config_get_project "$project")

    local urls
    urls=$(echo "$project_config" | jq -r '.urls[]? // empty')

    if [[ -z "$urls" ]]; then
        return 0
    fi

    while IFS= read -r url; do
        if [[ -n "$url" ]]; then
            log_info "Opening URL: $url"
            osascript - "$url" <<'APPLESCRIPT'
on run argv
    set theURL to item 1 of argv
    tell application "Google Chrome"
        activate
        make new window
        set URL of active tab of front window to theURL
    end tell
end run
APPLESCRIPT
        fi
    done <<< "$urls"
}

apps_launch_all() {
    local project="$1"
    local branch="$2"
    local project_config
    project_config=$(config_get_project "$project")

    if [[ "$project_config" == "null" ]]; then
        log_error "Project not found: $project"
        return 1
    fi

    local project_path use_worktree base_branch work_path
    project_path=$(echo "$project_config" | jq -r '.path' | sed "s|^~|$HOME|")
    use_worktree=$(echo "$project_config" | jq -r '.useWorktree // false')
    base_branch=$(echo "$project_config" | jq -r '.baseBranch // "trunk"')

    # Determine working path
    if [[ "$use_worktree" == "true" ]]; then
        work_path=$(get_worktree_path "$project_path" "$branch")

        # Check if worktree exists, if not create it
        if [[ ! -d "$work_path" ]]; then
            log_info "Creating worktree for $branch..."
            if ! command -v wt &> /dev/null; then
                log_error "worktree-cli (wt) not installed"
                log_info "Install with: npm install -g @johnlindquist/worktree"
                return 1
            fi
            (cd "$project_path" && wt new "$branch" --checkout --editor none) || {
                log_error "Failed to create worktree"
                return 1
            }
        fi
    else
        work_path="$project_path"
    fi

    log_info "Working path: $work_path"

    apps_launch_ide "$project" "$branch" "$work_path"
    sleep 1
    apps_launch_terminal "$project" "$branch" "$work_path"
    sleep 1
    apps_launch_notes "$project" "$branch"
    sleep 1
    apps_launch_urls "$project" "$branch"
}
