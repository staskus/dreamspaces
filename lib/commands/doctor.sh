#!/bin/bash
# ds doctor - Check system health and diagnose issues

cmd_doctor() {
    local issues=0

    echo "Dreamspaces Health Check"
    echo "========================"
    echo ""

    # Check Hammerspoon
    echo -n "Hammerspoon installed: "
    if [[ -d "/Applications/Hammerspoon.app" ]] || [[ -d "$HOME/Applications/Hammerspoon.app" ]]; then
        echo "OK"
    else
        echo "MISSING"
        issues=$((issues + 1))
    fi

    # Check Hammerspoon CLI
    echo -n "Hammerspoon CLI (hs): "
    if command -v hs &> /dev/null; then
        echo "OK"
    else
        echo "MISSING - Enable in Hammerspoon preferences"
        issues=$((issues + 1))
    fi

    # Check accessibility
    echo -n "Hammerspoon accessibility: "
    local access
    access=$(hs -c "return hs.accessibilityState()" 2>/dev/null)
    if [[ "$access" == "true" ]]; then
        echo "OK"
    else
        echo "NOT GRANTED - Enable in System Settings > Privacy > Accessibility"
        issues=$((issues + 1))
    fi

    # Check dreamspaces module loaded
    echo -n "Dreamspaces module loaded: "
    local loaded
    loaded=$(hs -c "return dreamspaces ~= nil" 2>/dev/null)
    if [[ "$loaded" == "true" ]]; then
        echo "OK"
    else
        echo "NOT LOADED - Add require('dreamspaces') to ~/.hammerspoon/init.lua"
        issues=$((issues + 1))
    fi

    # Check tmux
    echo -n "tmux installed: "
    if command -v tmux &> /dev/null; then
        echo "OK ($(tmux -V))"
    else
        echo "MISSING"
        issues=$((issues + 1))
    fi

    # Check jq
    echo -n "jq installed: "
    if command -v jq &> /dev/null; then
        echo "OK"
    else
        echo "MISSING"
        issues=$((issues + 1))
    fi

    # Check config file
    echo -n "Config file: "
    if [[ -f "$CONFIG_FILE" ]]; then
        if jq empty "$CONFIG_FILE" 2>/dev/null; then
            echo "OK ($CONFIG_FILE)"
        else
            echo "INVALID JSON"
            issues=$((issues + 1))
        fi
    else
        echo "MISSING ($CONFIG_FILE)"
        issues=$((issues + 1))
    fi

    # Check state file
    echo -n "State file: "
    local state_file="$HOME/.config/dreamspaces/state.json"
    if [[ -f "$state_file" ]]; then
        if jq empty "$state_file" 2>/dev/null; then
            local workspace_count
            workspace_count=$(jq '.workspaces | length' "$state_file")
            echo "OK ($workspace_count active workspaces)"
        else
            echo "INVALID JSON - run 'ds cleanup'"
            issues=$((issues + 1))
        fi
    else
        echo "OK (no state yet)"
    fi

    # Check worktree-cli
    echo -n "worktree-cli (wt): "
    if command -v wt &> /dev/null; then
        echo "OK"
    else
        echo "NOT INSTALLED (optional, for git worktrees)"
    fi

    # Check Obsidian Advanced URI plugin
    echo -n "Obsidian Advanced URI plugin: "
    local found_plugin=false
    local vault_paths=(
        "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents"
        "$HOME/Documents"
        "$HOME/Obsidian"
    )
    for vault_base in "${vault_paths[@]}"; do
        if [[ -d "$vault_base" ]]; then
            while IFS= read -r -d '' plugin_dir; do
                found_plugin=true
                break
            done < <(find "$vault_base" -maxdepth 4 -path "*/.obsidian/plugins/obsidian-advanced-uri" -type d -print0 2>/dev/null)
        fi
        [[ "$found_plugin" == "true" ]] && break
    done
    if [[ "$found_plugin" == "true" ]]; then
        echo "OK"
    else
        echo "NOT FOUND - run 'ds setup' to install"
    fi

    # Validate workspace state
    echo ""
    echo "Workspace State Validation"
    echo "--------------------------"
    local validation
    validation=$(hs -c "
        local state = require('dreamspaces.state')
        state.reload()
        local workspaces = state.listWorkspaces()
        local valid = 0
        local orphaned = 0
        for _, ws in ipairs(workspaces) do
            if ws.space then
                valid = valid + 1
            else
                orphaned = orphaned + 1
            end
        end
        return string.format('valid=%d orphaned=%d', valid, orphaned)
    " 2>/dev/null)

    if [[ -n "$validation" ]]; then
        local valid orphaned
        valid=$(echo "$validation" | grep -oE 'valid=[0-9]+' | cut -d= -f2)
        orphaned=$(echo "$validation" | grep -oE 'orphaned=[0-9]+' | cut -d= -f2)
        echo "Valid workspaces: $valid"
        echo "Orphaned workspaces: $orphaned"
        if [[ "$orphaned" -gt 0 ]]; then
            echo "  Run 'ds cleanup' to remove orphaned entries"
            issues=$((issues + 1))
        fi
    else
        echo "Could not validate (Hammerspoon not responding)"
        issues=$((issues + 1))
    fi

    echo ""
    echo "========================"
    if [[ $issues -eq 0 ]]; then
        log_success "All checks passed!"
    else
        log_warn "$issues issue(s) found"
    fi

    return $issues
}
