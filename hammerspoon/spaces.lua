-- Dreamspaces space management (ID-based)
local M = {}

local hs = _G.hs
local configFile = os.getenv("HOME") .. "/.config/dreamspaces/config.json"

local function defaultLayout()
  return {
    ide = { x = 0, y = 0, w = 0.5, h = 0.6 },
    notes = { x = 0, y = 0.6, w = 0.5, h = 0.4 },
    terminal = { x = 0.5, y = 0, w = 0.5, h = 0.6 },
    browser = { x = 0.5, y = 0.6, w = 0.5, h = 0.4 }
  }
end

local function loadLayout()
  local file = io.open(configFile, "r")
  if not file then
    return defaultLayout()
  end

  local content = file:read("*all")
  file:close()

  if not content or content == "" then
    return defaultLayout()
  end

  local ok, config = pcall(hs.json.decode, content)
  if ok and config and config.layout then
    return config.layout
  end

  return defaultLayout()
end

-- Get main screen info
function M.getScreenInfo()
  local mainScreen = hs.screen.mainScreen()
  if not mainScreen then
    return nil, nil, "No main screen"
  end

  local screenUUID = mainScreen:getUUID()
  local allSpaces = hs.spaces.allSpaces()
  local screenSpaces = allSpaces[screenUUID] or {}

  return screenSpaces, screenUUID, nil
end

-- Create a new space and return its ID
function M.createSpace()
  local screenSpaces, screenUUID, err = M.getScreenInfo()
  if err then
    return nil, err
  end

  local countBefore = #screenSpaces
  hs.spaces.addSpaceToScreen(screenUUID)

  -- Wait for space creation and get new ID
  hs.timer.usleep(500000)

  local newSpaces = hs.spaces.allSpaces()[screenUUID] or {}
  if #newSpaces > countBefore then
    local newSpaceId = newSpaces[#newSpaces]
    hs.printf("Dreamspaces: created space with ID %d (index %d)", newSpaceId, #newSpaces)
    return newSpaceId, nil
  end

  return nil, "Failed to create space"
end

-- Go to space by ID
function M.gotoSpaceById(spaceId)
  if not spaceId then
    return false, "No space ID provided"
  end

  local screenSpaces, _, err = M.getScreenInfo()
  if err then
    return false, err
  end

  local found = false
  for _, sid in ipairs(screenSpaces) do
    if sid == spaceId then
      found = true
      break
    end
  end

  if not found then
    return false, "Space ID " .. spaceId .. " not found"
  end

  hs.spaces.gotoSpace(spaceId)
  return true, nil
end

-- Go to space by index (legacy compatibility)
function M.gotoSpace(spaceIndex)
  local screenSpaces, _, err = M.getScreenInfo()
  if err then
    return false
  end

  -- Ensure space exists
  if not M.ensureSpaceExists(spaceIndex) then
    return false
  end

  screenSpaces = hs.spaces.allSpaces()[hs.screen.mainScreen():getUUID()] or {}
  if spaceIndex <= #screenSpaces then
    hs.spaces.gotoSpace(screenSpaces[spaceIndex])
    return true
  end

  return false
end

-- Ensure we have enough spaces
function M.ensureSpaceExists(spaceIndex)
  local screenSpaces, screenUUID, err = M.getScreenInfo()
  if err then
    return false
  end

  local currentCount = #screenSpaces
  while currentCount < spaceIndex do
    hs.spaces.addSpaceToScreen(screenUUID)
    currentCount = currentCount + 1
    hs.printf("Dreamspaces: created space %d", currentCount)
  end

  return true
end

-- Remove space by ID
function M.removeSpaceById(spaceId)
  if not spaceId then
    return false, "No space ID provided"
  end

  local screenSpaces, _, err = M.getScreenInfo()
  if err then
    return false, err
  end

  if #screenSpaces <= 1 then
    return false, "Cannot remove last space"
  end

  local found = false
  local foundIndex = 0
  for i, sid in ipairs(screenSpaces) do
    if sid == spaceId then
      found = true
      foundIndex = i
      break
    end
  end

  if not found then
    -- Space already removed
    return true, nil
  end

  -- Switch away first if we're still on this space
  local focusedSpace = hs.spaces.focusedSpace()
  if focusedSpace == spaceId then
    local targetId = screenSpaces[1]
    if targetId == spaceId and #screenSpaces > 1 then
      targetId = screenSpaces[2]
    end
    hs.spaces.gotoSpace(targetId)
    hs.timer.usleep(500000)
  end

  -- Remove the space
  local ok, removeErr = pcall(function()
    hs.spaces.removeSpace(spaceId)
  end)

  if ok then
    hs.printf("Dreamspaces: removed space ID %d (was at index %d)", spaceId, foundIndex)
    return true, nil
  else
    hs.printf("Dreamspaces: failed to remove space - %s", tostring(removeErr))
    return false, tostring(removeErr)
  end
end

-- Get windows on a specific space ID
function M.getWindowsOnSpace(spaceId)
  local windowIds = hs.spaces.windowsForSpace(spaceId) or {}
  local windows = {}

  for _, winId in ipairs(windowIds) do
    local win = hs.window.get(winId)
    if win and win:isStandard() then
      table.insert(windows, win)
    end
  end

  return windows
end

-- Close windows for specific apps on a space
function M.closeWindowsOnSpace(spaceId, appNames)
  local windows = M.getWindowsOnSpace(spaceId)
  local closed = 0

  for _, win in ipairs(windows) do
    local app = win:application()
    if app then
      local appName = app:name()
      for _, target in ipairs(appNames) do
        if appName == target then
          win:close()
          closed = closed + 1
          break
        end
      end
    end
  end

  return closed
end

-- Move windows from specified apps to current space
function M.moveWindowsToCurrentSpace()
  local currentSpaceId = hs.spaces.focusedSpace()
  local ideApps = { "Xcode", "Android Studio", "Cursor", "Visual Studio Code", "VSCode", "Code" }
  local terminalApps = { "iTerm2", "iTerm", "Terminal" }
  local notesApps = { "Obsidian" }
  local browserApps = { "Google Chrome", "Chrome" }

  local allTargetApps = {}
  for _, apps in ipairs({ideApps, terminalApps, notesApps, browserApps}) do
    for _, app in ipairs(apps) do
      allTargetApps[app] = true
    end
  end

  local moved = 0
  for _, win in ipairs(hs.window.allWindows()) do
    if win:isStandard() then
      local app = win:application()
      if app and allTargetApps[app:name()] then
        -- Check if window is already on current space
        local winSpaces = hs.spaces.windowSpaces(win)
        local onCurrentSpace = false
        for _, sid in ipairs(winSpaces or {}) do
          if sid == currentSpaceId then
            onCurrentSpace = true
            break
          end
        end

        if not onCurrentSpace then
          hs.spaces.moveWindowToSpace(win, currentSpaceId)
          moved = moved + 1
          hs.printf("Dreamspaces: moved %s window to space %d", app:name(), currentSpaceId)
        end
      end
    end
  end

  return moved
end

-- Arrange windows on current space (only windows ON this space)
function M.arrangeWindows(project)
  local screen = hs.screen.mainScreen()
  if not screen then
    hs.alert.show("No main screen found")
    return
  end

  local frame = screen:frame()
  local layout = loadLayout()

  local ideApps = { "Xcode", "Android Studio", "Cursor", "Visual Studio Code", "VSCode", "Code" }
  local terminalApps = { "iTerm2", "iTerm", "Terminal" }
  local notesApps = { "Obsidian" }
  local browserApps = { "Google Chrome", "Chrome" }

  local ideWindow = nil
  local terminalWindow = nil
  local notesWindow = nil
  local browserWindow = nil

  -- Get current space ID and only look at windows on THIS space
  local currentSpaceId = hs.spaces.focusedSpace()
  local windowIdsOnSpace = hs.spaces.windowsForSpace(currentSpaceId) or {}
  local windowsOnSpace = {}
  for _, winId in ipairs(windowIdsOnSpace) do
    windowsOnSpace[winId] = true
  end

  for _, win in ipairs(hs.window.orderedWindows()) do
    -- Only consider windows on the current space
    if win:isStandard() and windowsOnSpace[win:id()] then
      local app = win:application()
      if app then
        local appName = app:name()

        if not ideWindow then
          for _, name in ipairs(ideApps) do
            if appName == name then
              ideWindow = win
              break
            end
          end
        end

        if not terminalWindow then
          for _, name in ipairs(terminalApps) do
            if appName == name then
              terminalWindow = win
              break
            end
          end
        end

        if not notesWindow then
          for _, name in ipairs(notesApps) do
            if appName == name then
              notesWindow = win
              break
            end
          end
        end

        if not browserWindow then
          for _, name in ipairs(browserApps) do
            if appName == name then
              browserWindow = win
              break
            end
          end
        end
      end
    end
  end

  if ideWindow and layout.ide then
    local l = layout.ide
    ideWindow:setFrame({
      x = frame.x + frame.w * l.x,
      y = frame.y + frame.h * l.y,
      w = frame.w * l.w,
      h = frame.h * l.h
    })
  end

  if terminalWindow and layout.terminal then
    local l = layout.terminal
    terminalWindow:setFrame({
      x = frame.x + frame.w * l.x,
      y = frame.y + frame.h * l.y,
      w = frame.w * l.w,
      h = frame.h * l.h
    })
  end

  if notesWindow and layout.notes then
    local l = layout.notes
    notesWindow:setFrame({
      x = frame.x + frame.w * l.x,
      y = frame.y + frame.h * l.y,
      w = frame.w * l.w,
      h = frame.h * l.h
    })
  end

  if browserWindow and layout.browser then
    local l = layout.browser
    browserWindow:setFrame({
      x = frame.x + frame.w * l.x,
      y = frame.y + frame.h * l.y,
      w = frame.w * l.w,
      h = frame.h * l.h
    })
  end

  if ideWindow then
    ideWindow:focus()
  end

  hs.alert.show("Windows arranged")
end

-- Legacy function for backward compatibility
function M.arrange(project, branch, spaceIndex)
  if not M.ensureSpaceExists(spaceIndex) then
    return false
  end

  hs.timer.doAfter(3, function()
    M.arrangeWindows(project)
  end)

  return true
end

return M
