#!/bin/bash
# ds open <project> [branch] - Open workspace for project+branch

source "$DS_ROOT/lib/core/config.sh"
source "$DS_ROOT/lib/core/spaces.sh"
source "$DS_ROOT/lib/core/apps.sh"

cmd_open() {
    local project="${1:-}"
    local branch="${2:-main}"

    if [[ -z "$project" ]]; then
        log_error "Usage: ds open <project> [branch]"
        echo ""
        log_info "Available projects:"
        config_list_projects | while read -r p; do
            echo "  - $p"
        done
        exit 1
    fi

    # Validate project exists
    local project_config
    project_config=$(config_get_project "$project")
    if [[ "$project_config" == "null" ]]; then
        log_error "Project not found: $project"
        echo ""
        log_info "Available projects:"
        config_list_projects | while read -r p; do
            echo "  - $p"
        done
        exit 1
    fi

    log_info "Opening workspace: ${project}:${branch}"

    # Claim a space
    local space_index
    space_index=$(spaces_claim "$project" "$branch")
    if [[ -z "$space_index" ]]; then
        log_error "Failed to claim space"
        exit 1
    fi
    log_success "Claimed space: $space_index"

    # Launch apps
    apps_launch_all "$project" "$branch"

    # Notify Hammerspoon to reload state and arrange windows
    if command -v hs &> /dev/null; then
        log_info "Arranging windows via Hammerspoon..."
        hs -c "dreamspaces.reload(); dreamspaces.arrange('$project', '$branch', $space_index)"
    else
        log_warn "Hammerspoon CLI not available - windows won't be arranged"
    fi

    log_success "Workspace opened: ${project}:${branch} on space $space_index"
}
