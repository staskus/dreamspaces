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
| `ds close` | Close current workspace (keeps tmux session) |
| `ds close --cleanup` | Close and remove worktree + tmux session |
| `ds switch` | Switch between active workspaces |
| `ds list` | List active workspaces |
| `ds doctor` | Check system health and diagnose issues |
| `ds cleanup` | Remove orphaned workspace entries |
| `ds config` | Open config in editor |

## Supported Apps

Dreamspaces integrates with macOS applications to create development workspaces. Each category has supported apps with different requirements.

### IDE

| App | Status | Notes |
|-----|--------|-------|
| **Cursor** | ✅ Default | |
| **Xcode** | ✅ Supported | Use `.xcworkspace` path |
| **VS Code** | ✅ Supported | App name: `Visual Studio Code` |

```json
"ide": { "app": "Cursor", "open": "." }
"ide": { "app": "Xcode", "open": "MyProject.xcworkspace" }
```

### Terminal

| App | Status | Notes |
|-----|--------|-------|
| **iTerm** | ✅ Default | Full AppleScript support |
| **Terminal.app** | ✅ Supported | macOS built-in |
| Warp, Alacritty, Kitty | ❌ Not yet | PRs welcome |

```json
"terminal": { "app": "iTerm", "tmux": true }
```

- `tmux: true` creates persistent sessions that survive workspace switches
- Sessions named `{project}-{branch}` (with `/` → `-`)

### Notes

| App | Status | Notes |
|-----|--------|-------|
| **Obsidian** | ✅ Supported | Requires Advanced URI plugin |
| Notion, LogSeq, Apple Notes | ❌ Not yet | PRs welcome |

```json
"notes": {
  "vault": "MyVault",
  "folder": "Projects/my-project/branches",
  "path": "~/Library/Mobile Documents/iCloud~md~obsidian/Documents/MyVault"
}
```

**Requirements:**
- Install **Advanced URI** plugin in Obsidian (Settings → Community Plugins → Browse → "Advanced URI")
- `ds setup` can install this automatically

**Features:**
- Notes open in separate pop-out windows per workspace
- Auto-creates note file on first open with template
- Note files: `{branch}.md` in the specified folder

### Browser

| App | Status | Notes |
|-----|--------|-------|
| **Google Chrome** | ✅ Hardcoded | Opens URLs in new windows |
| Safari, Firefox, Arc | ❌ Not yet | PRs welcome |

```json
"urls": ["https://github.com/org/repo", "https://linear.app/team"]
```

### Adding New App Support

To add support for a new app:

1. **IDE**: Edit `lib/core/apps.sh` → `apps_launch_ide()` and add to `ideApps` in `hammerspoon/spaces.lua`
2. **Terminal**: Add AppleScript handling in `apps_launch_terminal()`
3. **Notes**: Check if app has URL scheme support, add launcher function
4. **Browser**: Currently hardcoded; submit PR to make configurable

Or [open an issue](https://github.com/staskus/dreamspaces/issues) to request support.

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

See [Supported Apps](#supported-apps) for the full list. Currently:
- **IDE**: Cursor, Xcode, VS Code
- **Terminal**: iTerm, Terminal.app (with optional tmux)
- **Notes**: Obsidian (with Advanced URI plugin)
- **Browser**: Google Chrome

## Requirements

- macOS (tested on macOS 14+)
- Hammerspoon (installed by `ds setup`)
- tmux (installed by `ds setup`)
- jq (installed by `ds setup`)
- For git worktree support: `npm install -g @johnlindquist/worktree`
- For Obsidian notes in separate windows: Install the **Advanced URI** plugin
  - Obsidian > Settings > Community Plugins > Browse > "Advanced URI" > Install & Enable

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
