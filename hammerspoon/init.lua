-- Dreamspaces Hammerspoon module
-- Handles workspace management, window arrangement, and space control

local M = {}

local spaces = require("dreamspaces.spaces")
local state = require("dreamspaces.state")

local configFile = os.getenv("HOME") .. "/.config/dreamspaces/config.json"

-- Visual overlay for workspace indicator
local workspaceOverlay = nil

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

-- Show a nice visual indicator for the current workspace
local function showWorkspaceIndicator(project, branch)
  -- Clean up previous overlay
  if workspaceOverlay then
    workspaceOverlay:delete()
    workspaceOverlay = nil
  end

  local screen = hs.screen.mainScreen()
  local frame = screen:frame()

  -- Create a canvas overlay at top center
  local width = 400
  local height = 60
  local x = frame.x + (frame.w - width) / 2
  local y = frame.y + 80

  workspaceOverlay = hs.canvas.new({ x = x, y = y, w = width, h = height })

  -- Background with rounded corners
  workspaceOverlay:appendElements({
    {
      type = "rectangle",
      action = "fill",
      roundedRectRadii = { xRadius = 12, yRadius = 12 },
      fillColor = { red = 0.1, green = 0.1, blue = 0.1, alpha = 0.9 },
    },
    {
      type = "rectangle",
      action = "stroke",
      roundedRectRadii = { xRadius = 12, yRadius = 12 },
      strokeColor = { red = 0.3, green = 0.6, blue = 1.0, alpha = 0.8 },
      strokeWidth = 2,
    },
    {
      type = "text",
      text = project .. ":" .. branch,
      textSize = 24,
      textColor = { white = 1, alpha = 1 },
      textAlignment = "center",
      frame = { x = 0, y = 12, w = width, h = 40 },
    },
  })

  workspaceOverlay:level(hs.canvas.windowLevels.overlay)
  workspaceOverlay:show()

  -- Fade out after 1.5 seconds
  hs.timer.doAfter(1.5, function()
    if workspaceOverlay then
      workspaceOverlay:delete()
      workspaceOverlay = nil
    end
  end)
end

local function setupHotkeys()
  local config = loadConfig()
  if not config.hotkeys then return end

  if config.hotkeys.switch then
    local hk = config.hotkeys.switch
    local mods = hk.mods or {"alt"}
    local key = hk.key or "tab"

    hs.hotkey.bind(mods, key, function()
      M.showSwitchPicker()
    end)
    hs.printf("Dreamspaces: bound switch hotkey to %s+%s", table.concat(mods, "+"), key)
  end
end

-- Arrange windows that are already on this space (don't move from other spaces)
local function arrangeWorkspaceWindows(workspace)
  -- Just arrange windows that are already on this space
  spaces.arrangeWindows(workspace.project)
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
      -- Wait for space switch to complete
      local maxWait = 20
      local waited = 0
      while hs.spaces.focusedSpace() ~= existing.spaceId and waited < maxWait do
        hs.timer.usleep(100000)
        waited = waited + 1
      end

      hs.printf("Dreamspaces: reusing existing space %d for %s", existing.spaceId, key)
      hs.timer.doAfter(0.5, function()
        arrangeWorkspaceWindows(existing)
        showWorkspaceIndicator(project, branch)
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

  -- Go to the new space and wait for switch to complete
  spaces.gotoSpaceById(newSpaceId)

  -- Wait for space switch to complete (macOS space switching is async)
  local maxWait = 20 -- 2 seconds max
  local waited = 0
  while hs.spaces.focusedSpace() ~= newSpaceId and waited < maxWait do
    hs.timer.usleep(100000) -- 100ms
    waited = waited + 1
  end

  if hs.spaces.focusedSpace() ~= newSpaceId then
    hs.printf("Dreamspaces: warning - space switch may not have completed")
  end

  -- Save to state
  state.addWorkspace(project, branch, newSpaceId)

  hs.printf("Dreamspaces: created space %d for %s", newSpaceId, key)
  showWorkspaceIndicator(project, branch)

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

  local appsToClose = { ideApp, terminalApp, "iTerm2", "iTerm", "Google Chrome" }

  -- Close windows on this space
  local closed = spaces.closeWindowsOnSpace(spaceId, appsToClose)
  hs.printf("Dreamspaces: closed %d windows", closed)

  -- Close Obsidian note window by matching title (pop-out windows may not be on space)
  local noteName = workspace.branch:gsub("/", "-") .. ".md"
  local obsidianApp = hs.application.get("Obsidian")
  if obsidianApp then
    for _, win in ipairs(obsidianApp:allWindows()) do
      local title = win:title() or ""
      if title:find(noteName, 1, true) or title:find(workspace.branch:gsub("/", "-"), 1, true) then
        hs.printf("Dreamspaces: closing Obsidian window: %s", title)
        win:close()
        closed = closed + 1
      end
    end
  end

  -- Remove from state first
  state.removeWorkspace(workspace.project, workspace.branch)

  -- Find closest workspace to switch to, or space 1
  local targetSpaceId = nil
  local targetWorkspace = nil
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
      targetWorkspace = closestWs
      hs.printf("Dreamspaces: switching to closest workspace %s:%s", closestWs.project, closestWs.branch)
    end
  end

  -- Switch to target or space 1
  if targetSpaceId then
    spaces.gotoSpaceById(targetSpaceId)
    hs.timer.doAfter(0.5, function()
      if targetWorkspace then
        arrangeWorkspaceWindows(targetWorkspace)
        showWorkspaceIndicator(targetWorkspace.project, targetWorkspace.branch)
      end
    end)
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

-- Switch to a workspace - ensures apps are present and arranged
function M.switchToWorkspace(workspace)
  local ok, err = spaces.gotoSpaceById(workspace.spaceId)
  if not ok then
    hs.alert.show("Failed: " .. (err or "unknown"))
    return false
  end

  -- Ensure apps are on this space and arrange them
  hs.timer.doAfter(0.3, function()
    arrangeWorkspaceWindows(workspace)
    showWorkspaceIndicator(workspace.project, workspace.branch)
  end)

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

  -- Check which workspace we're currently on
  local currentWs = state.current()
  local currentKey = currentWs and (currentWs.project .. ":" .. currentWs.branch) or nil

  local choices = {}
  for _, ws in ipairs(workspaces) do
    local wsKey = ws.project .. ":" .. ws.branch
    local isCurrent = (wsKey == currentKey)
    table.insert(choices, {
      text = ws.project .. ":" .. ws.branch .. (isCurrent and " (current)" or ""),
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

-- Check if Obsidian note window is already open
function M.isObsidianNoteOpen(branch)
  local noteName = branch:gsub("/", "-")
  local obsidianApp = hs.application.get("Obsidian")
  if not obsidianApp then
    return false
  end
  for _, win in ipairs(obsidianApp:allWindows()) do
    local title = win:title() or ""
    if title:find(noteName, 1, true) then
      return true
    end
  end
  return false
end

-- Open Chrome with URL on current space
function M.openBrowser(url)
  local currentSpaceId = hs.spaces.focusedSpace()

  -- Get existing Chrome windows before opening
  local chromeApp = hs.application.get("Google Chrome")
  local existingWindows = {}
  if chromeApp then
    for _, win in ipairs(chromeApp:allWindows()) do
      existingWindows[win:id()] = true
    end
  end

  -- Open Chrome with new window
  hs.execute('open -na "Google Chrome" --args --new-window "' .. url .. '"')

  -- Wait for new window and move it to current space
  hs.timer.doAfter(1, function()
    local chrome = hs.application.get("Google Chrome")
    if chrome then
      for _, win in ipairs(chrome:allWindows()) do
        if not existingWindows[win:id()] then
          -- This is a new window, move it to current space
          hs.spaces.moveWindowToSpace(win, currentSpaceId)
          hs.printf("Dreamspaces: moved Chrome window to space %d", currentSpaceId)
        end
      end
    end
  end)

  return true
end

-- Open Obsidian note on current space
function M.openNote(obsidianUrl)
  local currentSpaceId = hs.spaces.focusedSpace()

  -- Get existing Obsidian windows before opening
  local obsidianApp = hs.application.get("Obsidian")
  local existingWindows = {}
  if obsidianApp then
    for _, win in ipairs(obsidianApp:allWindows()) do
      existingWindows[win:id()] = true
    end
  end

  -- Open note via URL scheme
  hs.execute('open "' .. obsidianUrl .. '"')

  -- Wait for new window and move it to current space
  hs.timer.doAfter(1.5, function()
    local obsidian = hs.application.get("Obsidian")
    if obsidian then
      for _, win in ipairs(obsidian:allWindows()) do
        if not existingWindows[win:id()] then
          -- This is a new window, move it to current space
          hs.spaces.moveWindowToSpace(win, currentSpaceId)
          hs.printf("Dreamspaces: moved Obsidian window to space %d", currentSpaceId)
        end
      end
    end
  end)

  return true
end

-- Initialize on load
local function init()
  -- Setup hotkeys
  setupHotkeys()

  -- Validate and cleanup stale state (e.g., after reboot)
  state.reload()
  local cleaned = state.cleanup()
  if cleaned > 0 then
    hs.printf("Dreamspaces: cleaned up %d orphaned workspaces on init", cleaned)
  end

  hs.printf("Dreamspaces: initialized")
end

init()

-- Make globally available
_G.dreamspaces = M

return M
