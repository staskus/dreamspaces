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

-- Switch to a workspace's space and arrange windows (no app launching)
function M.switchToWorkspace(workspace)
  local spaceIndex = workspace.space
  local project = workspace.project

  -- Get all spaces
  local mainScreen = hs.screen.mainScreen()
  if not mainScreen then
    hs.alert.show("No main screen")
    return false
  end

  local allSpaces = hs.spaces.allSpaces()
  local screenSpaces = allSpaces[mainScreen:getUUID()] or {}

  if spaceIndex > #screenSpaces then
    hs.alert.show("Space " .. spaceIndex .. " does not exist")
    return false
  end

  -- Switch to the space
  local targetSpace = screenSpaces[spaceIndex]
  hs.spaces.gotoSpace(targetSpace)

  -- Arrange windows after a short delay
  hs.timer.doAfter(0.5, function()
    M.arrangeWindows(project)
  end)

  hs.alert.show(project .. ":" .. workspace.branch)
  return true
end

-- Show switch picker - just switches space, doesn't re-launch apps
function M.showSwitchPicker()
  state.reload()
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
      M.switchToWorkspace(choice.workspace)
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
