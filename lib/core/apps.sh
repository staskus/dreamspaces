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

    local ide_app
    local ide_open
    local project_path
    ide_app=$(echo "$project_config" | jq -r '.ide.app // "Cursor"')
    ide_open=$(echo "$project_config" | jq -r '.ide.open // "."')
    project_path=$(echo "$project_config" | jq -r '.path' | sed "s|^~|$HOME|")

    if [[ ! -d "$project_path" ]]; then
        log_error "Project path not found: $project_path"
        return 1
    fi

    local full_path="$project_path/$ide_open"
    log_info "Opening $ide_app: $full_path"
    open -a "$ide_app" "$full_path" &
}

apps_launch_terminal() {
    local project="$1"
    local branch="$2"
    local project_config
    project_config=$(config_get_project "$project")

    local use_tmux
    local terminal_app
    local project_path
    use_tmux=$(echo "$project_config" | jq -r '.terminal.tmux // false')
    terminal_app=$(echo "$project_config" | jq -r '.terminal.app // "iTerm"')
    project_path=$(echo "$project_config" | jq -r '.path' | sed "s|^~|$HOME|")

    local session_name="${project}-${branch}"
    session_name=$(echo "$session_name" | tr '/' '-' | tr '.' '-')

    log_info "Opening $terminal_app with tmux session: $session_name"

    if [[ "$terminal_app" == "iTerm" ]] || [[ "$terminal_app" == "iTerm2" ]]; then
        # iTerm2 - create new window
        if [[ "$use_tmux" == "true" ]]; then
            osascript <<EOF
tell application "iTerm"
    activate
    set newWindow to (create window with default profile)
    tell current session of newWindow
        if "$use_tmux" is "true" then
            write text "cd '$project_path' && (tmux attach -t '$session_name' 2>/dev/null || tmux new-session -s '$session_name')"
        else
            write text "cd '$project_path'"
        end if
    end tell
end tell
EOF
        else
            osascript <<EOF
tell application "iTerm"
    activate
    set newWindow to (create window with default profile)
    tell current session of newWindow
        write text "cd '$project_path'"
    end tell
end tell
EOF
        fi
    else
        # Terminal.app fallback
        if [[ "$use_tmux" == "true" ]]; then
            osascript -e "tell application \"Terminal\" to do script \"cd '$project_path' && (tmux attach -t '$session_name' 2>/dev/null || tmux new-session -s '$session_name')\""
        else
            osascript -e "tell application \"Terminal\" to do script \"cd '$project_path'\""
        fi
    fi
}

apps_launch_notes() {
    local project="$1"
    local branch="$2"
    local project_config
    project_config=$(config_get_project "$project")

    local vault
    local folder
    vault=$(echo "$project_config" | jq -r '.notes.vault // empty')
    folder=$(echo "$project_config" | jq -r '.notes.folder // empty')

    if [[ -z "$vault" ]]; then
        return 0
    fi

    local note_name="${branch}.md"
    note_name=$(echo "$note_name" | tr '/' '-')
    local note_path="${folder}/${note_name}"

    # Find vault path and create note if it doesn't exist
    local vault_base="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/${vault}"
    if [[ ! -d "$vault_base" ]]; then
        vault_base="$HOME/Documents/${vault}"
    fi

    if [[ -d "$vault_base" ]]; then
        local full_note_path="${vault_base}/${folder}"
        mkdir -p "$full_note_path"

        local note_file="${full_note_path}/${note_name}"
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
    fi

    log_info "Opening Obsidian note: $note_path"
    open "obsidian://open?vault=${vault}&file=${note_path}" &
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

    # Open Chrome with new window for this workspace
    local workspace_name="${project}:${branch}"

    while IFS= read -r url; do
        if [[ -n "$url" ]]; then
            log_info "Opening URL in new Chrome window: $url"
            # Open in new Chrome window
            osascript <<EOF
tell application "Google Chrome"
    activate
    set newWindow to make new window
    set URL of active tab of newWindow to "$url"
end tell
EOF
        fi
    done <<< "$urls"
}

apps_launch_all() {
    local project="$1"
    local branch="$2"

    apps_launch_ide "$project"
    apps_launch_terminal "$project" "$branch"
    apps_launch_notes "$project" "$branch"
    apps_launch_urls "$project" "$branch"
}
