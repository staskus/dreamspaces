-- Dreamspaces Hammerspoon module
-- Handles workspace management, window arrangement, and space control

local M = {}

local spaces = require("dreamspaces.spaces")
local state = require("dreamspaces.state")

local configFile = os.getenv("HOME") .. "/.config/dreamspaces/config.json"

local function loadConfig()
  local file = io.open(configFile, "r")
  if not file then return {} end
  local content = file:read("*all")
  file:close()
  local ok, config = pcall(hs.json.decode, content)
  if ok then return config end
  return {}
end

local function getProjectConfig(projectName)
  local config = loadConfig()
  if config.projects and config.projects[projectName] then
    return config.projects[projectName]
  end
  return nil
end

local function setupHotkeys()
  local config = loadConfig()
  if not config.hotkeys then return end

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

-- Open a workspace (create space, save state)
-- Apps are launched by CLI, this just handles space management
function M.open(project, branch)
  branch = branch or "main"
  local key = project .. ":" .. branch

  hs.printf("Dreamspaces: opening workspace %s", key)

  state.reload()

  -- Check if workspace already exists
  local existing = state.getWorkspace(project, branch)
  if existing and existing.spaceId then
    local ok, err = spaces.gotoSpaceById(existing.spaceId)
    if ok then
      hs.printf("Dreamspaces: reusing existing space %d for %s", existing.spaceId, key)
      hs.timer.doAfter(0.5, function()
        spaces.arrangeWindows(project)
      end)
      return { success = true, spaceId = existing.spaceId, reused = true }
    else
      hs.printf("Dreamspaces: stale workspace %s, space gone - %s", key, err or "")
      state.removeWorkspace(project, branch)
    end
  end

  -- Create new space
  local newSpaceId, err = spaces.createSpace()
  if not newSpaceId then
    return { success = false, error = err or "Failed to create space" }
  end

  -- Go to the new space
  spaces.gotoSpaceById(newSpaceId)

  -- Save to state
  state.addWorkspace(project, branch, newSpaceId)

  hs.printf("Dreamspaces: created space %d for %s", newSpaceId, key)

  return { success = true, spaceId = newSpaceId }
end

-- Close current workspace
function M.close()
  state.reload()

  local workspace = state.current()
  if not workspace then
    return { success = false, error = "No workspace on current space" }
  end

  local key = workspace.project .. ":" .. workspace.branch
  hs.printf("Dreamspaces: closing workspace %s", key)

  local spaceId = workspace.spaceId
  local currentIndex = state.spaceIdToIndex(spaceId)

  -- Get project config for app names
  local projectConfig = getProjectConfig(workspace.project)
  local ideApp = projectConfig and projectConfig.ide and projectConfig.ide.app or "Cursor"
  local terminalApp = projectConfig and projectConfig.terminal and projectConfig.terminal.app or "iTerm"

  local appsToClose = { ideApp, terminalApp, "iTerm2", "iTerm", "Obsidian" }

  -- Close windows on this space
  local closed = spaces.closeWindowsOnSpace(spaceId, appsToClose)
  hs.printf("Dreamspaces: closed %d windows", closed)

  -- Remove from state first
  state.removeWorkspace(workspace.project, workspace.branch)

  -- Find closest workspace to switch to, or space 1
  local targetSpaceId = nil
  local otherWorkspaces = state.listWorkspaces()

  if #otherWorkspaces > 0 then
    -- Find closest workspace by index
    local closestWs = nil
    local closestDist = 999
    for _, ws in ipairs(otherWorkspaces) do
      if ws.spaceId ~= spaceId then
        local dist = math.abs((ws.space or 999) - (currentIndex or 1))
        if dist < closestDist then
          closestDist = dist
          closestWs = ws
        end
      end
    end
    if closestWs then
      targetSpaceId = closestWs.spaceId
      hs.printf("Dreamspaces: switching to closest workspace %s:%s", closestWs.project, closestWs.branch)
    end
  end

  -- Switch to target or space 1
  if targetSpaceId then
    spaces.gotoSpaceById(targetSpaceId)
  else
    -- Go to space 1
    local screenSpaces, _, _ = spaces.getScreenInfo()
    if screenSpaces and #screenSpaces > 0 then
      local space1 = screenSpaces[1]
      if space1 ~= spaceId then
        hs.spaces.gotoSpace(space1)
      elseif #screenSpaces > 1 then
        hs.spaces.gotoSpace(screenSpaces[2])
      end
    end
  end

  -- Remove the macOS space after switching
  hs.timer.doAfter(0.5, function()
    local ok, err = spaces.removeSpaceById(spaceId)
    if not ok then
      hs.printf("Dreamspaces: could not remove space - %s", err or "unknown")
    end
    -- Clean up any orphaned state entries
    state.cleanup()
  end)

  return { success = true, key = key }
end

-- Switch to a workspace
function M.switchToWorkspace(workspace)
  local ok, err = spaces.gotoSpaceById(workspace.spaceId)
  if not ok then
    hs.alert.show("Failed: " .. (err or "unknown"))
    return false
  end

  hs.timer.doAfter(0.3, function()
    spaces.arrangeWindows(workspace.project)
  end)

  hs.alert.show(workspace.project .. ":" .. workspace.branch)
  return true
end

-- Show switch picker
function M.showSwitchPicker()
  state.reload()
  state.cleanup() -- Remove any orphaned workspaces

  local workspaces = state.listWorkspaces()

  if #workspaces == 0 then
    hs.alert.show("No active workspaces")
    return
  end

  local choices = {}
  for _, ws in ipairs(workspaces) do
    table.insert(choices, {
      text = ws.project .. ":" .. ws.branch,
      subText = "Space " .. (ws.space or "?"),
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

-- Arrange windows for current workspace
function M.arrange(project, branch, spaceIndex)
  spaces.arrange(project, branch, spaceIndex)
end

function M.arrangeWindows(project)
  spaces.arrangeWindows(project)
end

-- Get current workspace
function M.current()
  state.reload()
  return state.current()
end

-- Reload state
function M.reload()
  state.reload()
end

-- List workspaces
function M.list()
  state.reload()
  return state.listWorkspaces()
end

-- Initialize
setupHotkeys()

-- Make globally available
_G.dreamspaces = M

return M
