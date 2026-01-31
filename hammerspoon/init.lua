-- Dreamspaces Hammerspoon module
-- Handles window arrangement and space management

local M = {}

local spaces = require("dreamspaces.spaces")
local picker = require("dreamspaces.picker")
local state = require("dreamspaces.state")

local configFile = os.getenv("HOME") .. "/.config/dreamspaces/config.json"

-- Load config
local function loadConfig()
  local file = io.open(configFile, "r")
  if not file then return {} end
  local content = file:read("*all")
  file:close()
  local ok, config = pcall(hs.json.decode, content)
  if ok then return config end
  return {}
end

-- Setup hotkeys from config
local function setupHotkeys()
  local config = loadConfig()
  if not config.hotkeys then return end

  -- Switch workspace hotkey
  if config.hotkeys.switch then
    local hk = config.hotkeys.switch
    local mods = hk.mods or {"cmd", "alt"}
    local key = hk.key or "space"

    hs.hotkey.bind(mods, key, function()
      M.showSwitchPicker()
    end)
    hs.printf("Dreamspaces: bound switch hotkey to %s+%s", table.concat(mods, "+"), key)
  end
end

-- Show switch picker with restore functionality
function M.showSwitchPicker()
  local workspaces = state.listWorkspaces()

  if #workspaces == 0 then
    hs.alert.show("No active workspaces")
    return
  end

  local choices = {}
  for _, ws in ipairs(workspaces) do
    table.insert(choices, {
      text = ws.project .. ":" .. ws.branch,
      subText = "Space " .. ws.space,
      workspace = ws
    })
  end

  local chooser = hs.chooser.new(function(choice)
    if choice then
      -- Run ds switch restore in background
      local project = choice.workspace.project
      local branch = choice.workspace.branch
      local dsPath = os.getenv("HOME") .. "/Projects/Dreamspaces/bin/ds"

      -- Use hs.task to run ds open which handles restore
      hs.task.new("/bin/bash", function(exitCode, stdOut, stdErr)
        if exitCode == 0 then
          hs.alert.show("Switched to " .. project .. ":" .. branch)
        else
          hs.alert.show("Switch failed")
          hs.printf("ds switch error: %s", stdErr)
        end
      end, {"-c", dsPath .. " open " .. project .. " " .. branch}):start()
    end
  end)

  chooser:choices(choices)
  chooser:placeholderText("Switch workspace...")
  chooser:show()
end

-- Arrange windows for a workspace
function M.arrange(project, branch, spaceIndex)
  spaces.arrange(project, branch, spaceIndex)
end

-- Arrange windows without switching spaces
function M.arrangeWindows(project)
  spaces.arrangeWindows(project)
end

-- Show workspace picker (legacy)
function M.showPicker()
  picker.show()
end

-- Get current workspace info
function M.current()
  return state.current()
end

-- Reload state from disk
function M.reload()
  state.reload()
end

-- Initialize hotkeys
setupHotkeys()

-- Make globally available
_G.dreamspaces = M

return M
