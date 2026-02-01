#!/bin/bash
# ds setup - Install dependencies and create config

source "$DS_ROOT/lib/core/config.sh"

# Install Obsidian Advanced URI plugin to a vault
install_obsidian_plugin() {
    local vault_path="$1"
    local plugin_id="obsidian-advanced-uri"
    local plugin_dir="$vault_path/.obsidian/plugins/$plugin_id"
    local community_plugins="$vault_path/.obsidian/community-plugins.json"

    # Check if .obsidian exists (valid vault)
    if [[ ! -d "$vault_path/.obsidian" ]]; then
        return 1
    fi

    # Check if already installed
    if [[ -f "$plugin_dir/manifest.json" ]]; then
        log_success "Advanced URI plugin already installed in: $(basename "$vault_path")"
        return 0
    fi

    log_info "Installing Advanced URI plugin to: $(basename "$vault_path")"

    # Create plugin directory
    mkdir -p "$plugin_dir"

    # Download latest release files from GitHub
    local base_url="https://github.com/Vinzent03/obsidian-advanced-uri/releases/latest/download"

    if curl -sL "$base_url/manifest.json" -o "$plugin_dir/manifest.json" && \
       curl -sL "$base_url/main.js" -o "$plugin_dir/main.js"; then

        # Enable the plugin in community-plugins.json
        if [[ -f "$community_plugins" ]]; then
            # Add to existing list if not already there
            if ! grep -q "$plugin_id" "$community_plugins"; then
                local content
                content=$(cat "$community_plugins")
                # Insert into array
                echo "$content" | jq ". + [\"$plugin_id\"]" > "$community_plugins"
            fi
        else
            # Create new file with just this plugin
            echo "[\"$plugin_id\"]" > "$community_plugins"
        fi

        log_success "Advanced URI plugin installed in: $(basename "$vault_path")"
        return 0
    else
        log_warn "Failed to download plugin files"
        rm -rf "$plugin_dir"
        return 1
    fi
}

# Find and setup Obsidian vaults
setup_obsidian_plugins() {
    log_info "Setting up Obsidian Advanced URI plugin..."

    local vaults_found=0

    # Common vault locations
    local search_paths=(
        "$HOME/Documents"
        "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents"
        "$HOME/Obsidian"
    )

    # Find vaults (directories containing .obsidian)
    for search_path in "${search_paths[@]}"; do
        if [[ -d "$search_path" ]]; then
            while IFS= read -r -d '' vault; do
                local vault_path
                vault_path=$(dirname "$vault")
                install_obsidian_plugin "$vault_path"
                vaults_found=$((vaults_found + 1))
            done < <(find "$search_path" -maxdepth 2 -name ".obsidian" -type d -print0 2>/dev/null)
        fi
    done

    if [[ $vaults_found -eq 0 ]]; then
        log_warn "No Obsidian vaults found. Install Advanced URI plugin manually if needed."
    fi
}

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

    # Setup Obsidian Advanced URI plugin
    setup_obsidian_plugins

    # Add to PATH hint
    echo ""
    log_info "Add to your shell profile (~/.zshrc or ~/.bashrc):"
    echo "    export PATH=\"\$PATH:$DS_ROOT/bin\""
    echo ""

    log_success "Setup complete!"
    log_info "Edit your projects: ds config"
}

cmd_setup
