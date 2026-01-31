#!/bin/bash
# App launching for dreamspaces

source "$DS_ROOT/lib/core/config.sh"

apps_launch_ide() {
    local project="$1"
    local project_config
    project_config=$(config_get_project "$project")

    if [[ "$project_config" == "null" ]]; then
        log_error "Project not found: $project"
        return 1
    fi

    local ide_app ide_open project_path
    ide_app=$(echo "$project_config" | jq -r '.ide.app // "Cursor"')
    ide_open=$(echo "$project_config" | jq -r '.ide.open // "."')
    project_path=$(echo "$project_config" | jq -r '.path' | sed "s|^~|$HOME|")

    if [[ ! -d "$project_path" ]]; then
        log_error "Project path not found: $project_path"
        return 1
    fi

    local full_path="$project_path/$ide_open"
    log_info "Opening $ide_app: $full_path"
    open -a "$ide_app" "$full_path"
}

apps_launch_terminal() {
    local project="$1"
    local branch="$2"
    local project_config
    project_config=$(config_get_project "$project")

    local use_tmux terminal_app project_path base_branch
    use_tmux=$(echo "$project_config" | jq -r '.terminal.tmux // false')
    terminal_app=$(echo "$project_config" | jq -r '.terminal.app // "iTerm"')
    project_path=$(echo "$project_config" | jq -r '.path' | sed "s|^~|$HOME|")
    base_branch=$(echo "$project_config" | jq -r '.baseBranch // "trunk"')

    local session_name="${project}-${branch}"
    session_name=$(echo "$session_name" | tr '/' '-' | tr '.' '-')

    # Git commands to checkout branch from latest base
    local git_cmds="git fetch origin && git checkout $base_branch && git pull origin $base_branch && (git checkout $branch 2>/dev/null || git checkout -b $branch)"

    log_info "Opening $terminal_app (tmux=$use_tmux, session=$session_name, base=$base_branch)"

    if [[ "$terminal_app" == "iTerm" ]] || [[ "$terminal_app" == "iTerm2" ]]; then
        if [[ "$use_tmux" == "true" ]]; then
            osascript - "$project_path" "$session_name" "$git_cmds" <<'APPLESCRIPT'
on run argv
    set projectPath to item 1 of argv
    set sessionName to item 2 of argv
    set gitCmds to item 3 of argv
    tell application "iTerm"
        activate
        set newWindow to (create window with default profile)
        tell current session of newWindow
            write text "cd '" & projectPath & "' && " & gitCmds & " && (tmux attach -t '" & sessionName & "' 2>/dev/null || tmux new-session -s '" & sessionName & "')"
        end tell
    end tell
end run
APPLESCRIPT
        else
            osascript - "$project_path" "$git_cmds" <<'APPLESCRIPT'
on run argv
    set projectPath to item 1 of argv
    set gitCmds to item 2 of argv
    tell application "iTerm"
        activate
        set newWindow to (create window with default profile)
        tell current session of newWindow
            write text "cd '" & projectPath & "' && " & gitCmds
        end tell
    end tell
end run
APPLESCRIPT
        fi
    else
        # Terminal.app fallback
        if [[ "$use_tmux" == "true" ]]; then
            osascript -e "tell application \"Terminal\" to do script \"cd '$project_path' && $git_cmds && (tmux attach -t '$session_name' 2>/dev/null || tmux new-session -s '$session_name')\""
        else
            osascript -e "tell application \"Terminal\" to do script \"cd '$project_path' && $git_cmds\""
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
        open "obsidian://open?vault=$(echo "$vault" | sed 's/ /%20/g')&file=$(echo "$note_path" | sed 's/ /%20/g')"
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

    apps_launch_ide "$project"
    sleep 1
    apps_launch_terminal "$project" "$branch"
    sleep 1
    apps_launch_notes "$project" "$branch"
    sleep 1
    apps_launch_urls "$project" "$branch"
}
