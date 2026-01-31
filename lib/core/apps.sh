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
    open -a "$ide_app" "$full_path"
}

apps_launch_terminal() {
    local project="$1"
    local branch="$2"
    local project_config
    project_config=$(config_get_project "$project")

    local use_tmux
    local project_path
    use_tmux=$(echo "$project_config" | jq -r '.terminal.tmux // false')
    project_path=$(echo "$project_config" | jq -r '.path' | sed "s|^~|$HOME|")

    local session_name="${project}-${branch}"
    session_name=$(echo "$session_name" | tr '/' '-' | tr '.' '-')

    if [[ "$use_tmux" == "true" ]]; then
        if tmux has-session -t "$session_name" 2>/dev/null; then
            log_info "Attaching to tmux session: $session_name"
            osascript -e "tell application \"Terminal\" to do script \"tmux attach -t $session_name\""
        else
            log_info "Creating tmux session: $session_name"
            osascript -e "tell application \"Terminal\" to do script \"cd '$project_path' && tmux new-session -s $session_name\""
        fi
    else
        log_info "Opening Terminal in: $project_path"
        osascript -e "tell application \"Terminal\" to do script \"cd '$project_path'\""
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

    log_info "Opening Obsidian note: $note_path"
    open "obsidian://open?vault=${vault}&file=${note_path}"
}

apps_launch_urls() {
    local project="$1"
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
            open "$url"
        fi
    done <<< "$urls"
}

apps_launch_all() {
    local project="$1"
    local branch="$2"

    apps_launch_ide "$project"
    apps_launch_terminal "$project" "$branch"
    apps_launch_notes "$project" "$branch"
    apps_launch_urls "$project"
}
