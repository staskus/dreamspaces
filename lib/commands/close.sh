#!/bin/bash
# ds close - Close current workspace

source "$DS_ROOT/lib/core/state.sh"
source "$DS_ROOT/lib/core/spaces.sh"
source "$DS_ROOT/lib/core/config.sh"

close_workspace_windows() {
    local project="$1"
    local branch="$2"
    local space_index="$3"

    local project_config
    project_config=$(config_get_project "$project")

    local ide_app terminal_app
    ide_app=$(echo "$project_config" | jq -r '.ide.app // "Cursor"')
    terminal_app=$(echo "$project_config" | jq -r '.terminal.app // "iTerm"')

    local session_name="${project}-${branch}"
    session_name=$(echo "$session_name" | tr '/' '-' | tr '.' '-')

    log_info "Closing windows on space $space_index..."

    # Close windows on the target space via Hammerspoon
    hs -c "
        local spaceIndex = $space_index
        local mainScreen = hs.screen.mainScreen()
        if not mainScreen then return end
        local allSpaces = hs.spaces.allSpaces()
        local screenSpaces = allSpaces[mainScreen:getUUID()] or {}
        if spaceIndex > #screenSpaces then return end
        local targetSpaceId = screenSpaces[spaceIndex]

        -- Get windows on target space
        local windowsOnSpace = hs.spaces.windowsForSpace(targetSpaceId)
        for _, winId in ipairs(windowsOnSpace or {}) do
            local win = hs.window.get(winId)
            if win then
                local app = win:application()
                if app then
                    local appName = app:name()
                    -- Close windows for workspace apps
                    if appName == '$ide_app' or appName == '$terminal_app' or appName == 'iTerm2' or appName == 'Obsidian' then
                        win:close()
                    end
                end
            end
        end
    " 2>/dev/null

    # Kill tmux session if exists
    if tmux has-session -t "$session_name" 2>/dev/null; then
        log_info "Killing tmux session: $session_name"
        tmux kill-session -t "$session_name" 2>/dev/null
    fi
}

remove_macos_space() {
    local space_index="$1"

    log_info "Removing macOS space $space_index..."

    # Switch to space 1 first, then remove target space
    hs -c "
        local spaceIndex = $space_index
        local mainScreen = hs.screen.mainScreen()
        if not mainScreen then return 'no screen' end
        local screenUUID = mainScreen:getUUID()
        local allSpaces = hs.spaces.allSpaces()
        local screenSpaces = allSpaces[screenUUID] or {}

        if spaceIndex > #screenSpaces then return 'space not found' end
        if #screenSpaces <= 1 then return 'cannot remove last space' end

        local targetSpaceId = screenSpaces[spaceIndex]

        -- Switch to space 1 first
        hs.spaces.gotoSpace(screenSpaces[1])

        -- Small delay then remove target space
        hs.timer.doAfter(0.5, function()
            hs.spaces.removeSpace(targetSpaceId)
        end)
        return 'ok'
    " 2>/dev/null
}

cmd_close() {
    # Get current space INDEX from Hammerspoon (convert space ID to index)
    local current_space_index=""
    if command -v hs &> /dev/null; then
        current_space_index=$(hs -c "
            local focusedSpace = hs.spaces.focusedSpace()
            local mainScreen = hs.screen.mainScreen()
            if not mainScreen then return '' end
            local spaces = hs.spaces.allSpaces()[mainScreen:getUUID()] or {}
            for i, spaceId in ipairs(spaces) do
                if spaceId == focusedSpace then return i end
            end
            return ''
        " 2>/dev/null)
    fi

    # Find workspace on current space
    local workspaces
    workspaces=$(state_get '.workspaces')

    if [[ "$workspaces" == "{}" ]] || [[ "$workspaces" == "null" ]]; then
        log_warn "No active workspaces"
        return 0
    fi

    # If we can't determine current space, ask user to specify
    if [[ -z "$current_space_index" ]]; then
        log_info "Active workspaces:"
        state_list_workspaces | while read -r ws; do
            local info
            info=$(state_get ".workspaces[\"$ws\"]")
            local space
            space=$(echo "$info" | jq -r '.space')
            echo "  - $ws (space $space)"
        done
        echo ""
        log_warn "Specify workspace to close: ds close <project> <branch>"
        return 1
    fi

    # Find and close workspace on current space
    local found=""
    local found_space=""
    while read -r ws; do
        local info
        info=$(state_get ".workspaces[\"$ws\"]")
        local space
        space=$(echo "$info" | jq -r '.space')
        if [[ "$space" == "$current_space_index" ]]; then
            found="$ws"
            found_space="$space"
            break
        fi
    done < <(state_list_workspaces)

    if [[ -z "$found" ]]; then
        log_warn "No workspace on current space"
        return 0
    fi

    local project branch
    project=$(echo "$found" | cut -d: -f1)
    branch=$(echo "$found" | cut -d: -f2)

    # Close windows associated with this workspace
    close_workspace_windows "$project" "$branch" "$found_space"

    # Release state first
    spaces_release "$project" "$branch"

    # Remove macOS space
    sleep 0.5
    remove_macos_space "$found_space"

    log_success "Closed workspace: $found"
}
