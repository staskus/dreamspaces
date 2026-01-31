# Dreamspaces - Agent Instructions

## Commit Policy
- Every code change MUST generate a commit
- Run tests before committing: `./tests/run_tests.sh`
- Only commit if tests pass
- Use conventional commits: feat:, fix:, docs:, test:, chore:

## Code Style
- Shell scripts: Use shellcheck, no trailing whitespace
- Lua: 2-space indent
- Keep it simple - this is v0.1

## Testing
- Tests live in `tests/`
- Run all: `./tests/run_tests.sh`
- Each command should have basic tests
- Test before commit, CI runs on push

## Key Files
- `bin/ds` - CLI entry point
- `lib/commands/*.sh` - Command implementations
- `lib/core/*.sh` - Core logic
- `~/.config/dreamspaces/config.json` - User config
- `~/.config/dreamspaces/state.json` - Runtime state
