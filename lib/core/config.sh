#!/bin/bash
# Config file handling for dreamspaces

config_exists() {
    [[ -f "$CONFIG_FILE" ]]
}

config_create_default() {
    ensure_config_dir
    cat > "$CONFIG_FILE" << 'EOF'
{
  "version": "0.1",
  "staticSpace": {
    "apps": ["Slack", "Mail"]
  },
  "poolSize": 7,
  "projects": {
    "example-project": {
      "path": "~/Projects/example-project",
      "ide": { "app": "Cursor", "open": "." },
      "terminal": { "tmux": true },
      "notes": { "vault": "Obsidian Vault", "folder": "Projects/example/branches" },
      "urls": []
    }
  }
}
EOF
}

config_get() {
    local key="$1"
    if ! config_exists; then
        log_error "Config file not found: $CONFIG_FILE"
        return 1
    fi
    jq -r "$key" "$CONFIG_FILE"
}

config_get_project() {
    local project="$1"
    config_get ".projects[\"$project\"]"
}

config_list_projects() {
    config_get '.projects | keys[]'
}

config_validate() {
    if ! config_exists; then
        return 1
    fi
    if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
        log_error "Invalid JSON in config file"
        return 1
    fi
    local version
    version=$(config_get '.version')
    if [[ "$version" == "null" ]]; then
        log_error "Missing version in config"
        return 1
    fi
    return 0
}
