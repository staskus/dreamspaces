#!/bin/bash
# ds setup - Install dependencies and create config

source "$DS_ROOT/lib/core/config.sh"

cmd_setup() {
    log_info "Setting up Dreamspaces..."

    # Check for Homebrew
    if ! check_dependency brew; then
        log_error "Homebrew is required. Install from https://brew.sh"
        exit 1
    fi
    log_success "Homebrew found"

    # Install/check tmux
    if check_dependency tmux; then
        log_success "tmux already installed"
    else
        log_info "Installing tmux..."
        brew install tmux
        log_success "tmux installed"
    fi

    # Install/check jq
    if check_dependency jq; then
        log_success "jq already installed"
    else
        log_info "Installing jq..."
        brew install jq
        log_success "jq installed"
    fi

    # Check for Hammerspoon
    if [[ -d "/Applications/Hammerspoon.app" ]] || [[ -d "$HOME/Applications/Hammerspoon.app" ]]; then
        log_success "Hammerspoon found"
    else
        log_info "Installing Hammerspoon..."
        brew install --cask hammerspoon
        log_success "Hammerspoon installed"
    fi

    # Create config directory and file
    ensure_config_dir
    if config_exists; then
        log_success "Config file exists: $CONFIG_FILE"
    else
        log_info "Creating default config..."
        config_create_default
        log_success "Created config: $CONFIG_FILE"
    fi

    # Setup Hammerspoon module
    local hs_config_dir="$HOME/.hammerspoon"
    local hs_ds_dir="$hs_config_dir/dreamspaces"
    if [[ ! -d "$hs_config_dir" ]]; then
        mkdir -p "$hs_config_dir"
    fi

    if [[ -d "$hs_ds_dir" ]] || [[ -L "$hs_ds_dir" ]]; then
        log_success "Hammerspoon module already linked"
    else
        ln -s "$DS_ROOT/hammerspoon" "$hs_ds_dir"
        log_success "Linked Hammerspoon module: $hs_ds_dir"
    fi

    # Check if dreamspaces is loaded in Hammerspoon init
    local hs_init="$hs_config_dir/init.lua"
    if [[ -f "$hs_init" ]] && grep -q "dreamspaces" "$hs_init"; then
        log_success "Hammerspoon init already loads dreamspaces"
    else
        log_warn "Add this to your $hs_init:"
        echo "    require('dreamspaces')"
    fi

    # Add to PATH hint
    echo ""
    log_info "Add to your shell profile (~/.zshrc or ~/.bashrc):"
    echo "    export PATH=\"\$PATH:$DS_ROOT/bin\""
    echo ""

    log_success "Setup complete!"
    log_info "Edit your projects: ds config"
}

cmd_setup
