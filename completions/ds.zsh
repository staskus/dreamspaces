#compdef ds

# Zsh completion for dreamspaces (ds)

_ds() {
    local -a commands
    commands=(
        'setup:Install dependencies and create config'
        'open:Open workspace for project+branch'
        'close:Close current workspace'
        'switch:Switch between active workspaces'
        'list:List active workspaces'
        'config:Open config file in editor'
        '--help:Show help'
        '--version:Show version'
    )

    _arguments -C \
        '1: :->command' \
        '2: :->arg1' \
        '3: :->arg2' \
        && return 0

    case "$state" in
        command)
            _describe -t commands 'ds commands' commands
            ;;
        arg1)
            case "$words[2]" in
                open)
                    local config_file="$HOME/.config/dreamspaces/config.json"
                    if [[ -f "$config_file" ]]; then
                        local -a projects
                        projects=(${(f)"$(jq -r '.projects | keys[]' "$config_file" 2>/dev/null)"})
                        _describe -t projects 'projects' projects
                    fi
                    ;;
            esac
            ;;
        arg2)
            case "$words[2]" in
                open)
                    # Could complete branch names from git, but keep it simple for now
                    _message 'branch name'
                    ;;
            esac
            ;;
    esac
}

_ds "$@"
