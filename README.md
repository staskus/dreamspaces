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

## Requirements

- macOS
- Hammerspoon (installed by `ds setup`)
- tmux (installed by `ds setup`)

## License

MIT
