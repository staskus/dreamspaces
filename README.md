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

# Switch between workspaces (or use Shift+Space hotkey)
ds switch

# Close current workspace
ds close
```

## How It Works

1. Define project presets in `~/.config/dreamspaces/config.json`
2. Run `ds open <project> [branch]` to launch workspace
3. Dreamspaces creates a new macOS Space for your workspace
4. Launches your IDE, terminal (with tmux session), and notes
5. Arranges windows according to your layout config
6. Switch between workspaces with `ds switch` or the hotkey
7. `ds close` closes windows, kills tmux session, and removes the space

## Configuration

Edit `~/.config/dreamspaces/config.json`:

```json
{
  "version": "0.1",
  "hotkeys": {
    "switch": { "mods": ["shift"], "key": "space" }
  },
  "layout": {
    "ide": { "x": 0, "y": 0, "w": 0.5, "h": 0.6 },
    "notes": { "x": 0, "y": 0.6, "w": 0.5, "h": 0.4 },
    "terminal": { "x": 0.5, "y": 0, "w": 0.5, "h": 1.0 }
  },
  "projects": {
    "my-project": {
      "path": "~/Projects/my-project",
      "baseBranch": "main",
      "useWorktree": true,
      "ide": { "app": "Xcode", "open": "MyProject.xcworkspace" },
      "terminal": { "app": "iTerm", "tmux": true },
      "notes": {
        "vault": "MyVault",
        "path": "~/Library/Mobile Documents/iCloud~md~obsidian/Documents/MyVault",
        "folder": "Projects/my-project/branches"
      }
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

## Hotkeys

Configure hotkeys in `config.json`:

```json
{
  "hotkeys": {
    "switch": { "mods": ["shift"], "key": "space" }
  }
}
```

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

## Built With

Dreamspaces is made possible by these open source projects:

### Core Dependencies

- **[Hammerspoon](https://www.hammerspoon.org/)** (MIT License)
  macOS desktop automation with Lua scripting. Hammerspoon provides the window management, space control, and hotkey functionality that powers Dreamspaces.
  Copyright (c) 2014-2017 Steven Skoczen, Chris Jones, and contributors

- **[tmux](https://github.com/tmux/tmux)** (ISC License)
  Terminal multiplexer for persistent terminal sessions. Each workspace gets its own tmux session that persists across switches.
  Copyright (c) 2007 Nicholas Marriott

- **[jq](https://github.com/jqlang/jq)** (MIT License)
  Lightweight JSON processor used for parsing configuration and state files.
  Copyright (c) 2012 Stephen Dolan

### Optional Dependencies

- **[worktree-cli](https://github.com/johnlindquist/worktree-cli)** (MIT License)
  Git worktree management CLI. When `useWorktree: true` is set, Dreamspaces uses this to create isolated branch directories.
  Copyright (c) John Lindquist

### Integrated Apps

Dreamspaces is designed to work with:
- **Xcode / Cursor / VS Code** - IDE window management
- **iTerm2 / Terminal** - Terminal window management
- **Obsidian** - Notes integration with vault/folder structure
- **Google Chrome** - URL opening in new windows

## Requirements

- macOS (tested on macOS 14+)
- Hammerspoon (installed by `ds setup`)
- tmux (installed by `ds setup`)
- jq (installed by `ds setup`)
- For git worktree support: `npm install -g @johnlindquist/worktree`

## Architecture

```
ds (CLI)
    │
    ├── Hammerspoon (Lua)
    │   ├── Space creation/removal (hs.spaces)
    │   ├── Window arrangement (hs.window)
    │   ├── Hotkey handling (hs.hotkey)
    │   └── State management (JSON file)
    │
    ├── tmux
    │   └── Persistent terminal sessions per workspace
    │
    └── AppleScript
        └── App-specific automation (iTerm, Obsidian, Chrome)
```

## License

MIT

## Acknowledgments

Special thanks to the Hammerspoon community for their excellent documentation and the `hs.spaces` module that makes macOS space management possible from scripts.
