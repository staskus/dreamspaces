# Dreamspaces

![Tests](https://github.com/staskus/dreamspaces/actions/workflows/test.yml/badge.svg)

macOS workspace automation - launch IDE, terminal, and notes per project+branch.

## Install

```bash
git clone https://github.com/staskus/dreamspaces.git
cd dreamspaces
./install.sh
```

## Quick Start

```bash
# Setup dependencies and config
ds setup

# Edit your project presets
ds config

# Open a workspace
ds open woocommerce-ios feature/login

# Switch between workspaces
ds switch

# Close current workspace
ds close
```

## How It Works

1. Define project presets in `~/.config/dreamspaces/config.json`
2. Run `ds open <project> [branch]` to launch workspace
3. Dreamspaces claims a macOS Space from the pool
4. Launches your IDE, terminal (with tmux), notes, and browser
5. Arranges windows and focuses the space
6. Switch between workspaces with `ds switch`

## Configuration

Edit `~/.config/dreamspaces/config.json`:

```json
{
  "version": "0.1",
  "poolSize": 7,
  "projects": {
    "my-project": {
      "path": "~/Projects/my-project",
      "ide": { "app": "Cursor", "open": "." },
      "terminal": { "tmux": true },
      "notes": { "vault": "MyVault", "folder": "Projects/my-project" },
      "urls": ["https://github.com/user/my-project"]
    }
  }
}
```

## Commands

| Command | Description |
|---------|-------------|
| `ds setup` | Install dependencies and create config |
| `ds open <project> [branch]` | Open workspace for project+branch |
| `ds close` | Close current workspace |
| `ds switch` | Switch between active workspaces |
| `ds list` | List active workspaces |
| `ds config` | Open config in editor |

## Shell Completion

Completions are installed automatically by `./install.sh`.

Manual setup:

**Zsh** - Add to `~/.zshrc`:
```bash
fpath=(/path/to/dreamspaces/completions $fpath)
autoload -Uz compinit && compinit
```

**Bash** - Add to `~/.bashrc`:
```bash
source /path/to/dreamspaces/completions/ds.bash
```

## Requirements

- macOS
- Hammerspoon (installed by `ds setup`)
- tmux (installed by `ds setup`)
- jq (installed by `ds setup`)

## License

MIT
