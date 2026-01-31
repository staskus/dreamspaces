# Bash completion for dreamspaces (ds)

_ds_completions() {
    local cur prev commands
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    commands="setup open close switch list config --help --version"

    case "$prev" in
        ds)
            COMPREPLY=($(compgen -W "$commands" -- "$cur"))
            return 0
            ;;
        open)
            # Complete with project names from config
            local config_file="$HOME/.config/dreamspaces/config.json"
            if [[ -f "$config_file" ]]; then
                local projects
                projects=$(jq -r '.projects | keys[]' "$config_file" 2>/dev/null)
                COMPREPLY=($(compgen -W "$projects" -- "$cur"))
            fi
            return 0
            ;;
    esac

    COMPREPLY=()
}

complete -F _ds_completions ds
