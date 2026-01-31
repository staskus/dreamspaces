-- Dreamspaces space management
local M = {}

local hs = _G.hs

local configFile = os.getenv("HOME") .. "/.config/dreamspaces/config.json"

-- Load layout from config
local function loadLayout()
  local file = io.open(configFile, "r")
  if not file then
    return {
      ide = { x = 0, y = 0, w = 0.5, h = 0.6 },
      notes = { x = 0, y = 0.6, w = 0.5, h = 0.4 },
      terminal = { x = 0.5, y = 0, w = 0.5, h = 1.0 }
    }
  end

  local content = file:read("*all")
  file:close()

  if not content or content == "" then
    return {
      ide = { x = 0, y = 0, w = 0.5, h = 0.6 },
      notes = { x = 0, y = 0.6, w = 0.5, h = 0.4 },
      terminal = { x = 0.5, y = 0, w = 0.5, h = 1.0 }
    }
  end

  local ok, config = pcall(hs.json.decode, content)
  if ok and config and config.layout then
    return config.layout
  end

  return {
    ide = { x = 0, y = 0, w = 0.5, h = 0.6 },
    notes = { x = 0, y = 0.6, w = 0.5, h = 0.4 },
    terminal = { x = 0.5, y = 0, w = 0.5, h = 1.0 }
  }
end

-- Get screen spaces info
function M.getScreenSpaces()
  local mainScreen = hs.screen.mainScreen()
  if not mainScreen then
    return nil, nil, "No main screen"
  end

  local allSpaces = hs.spaces.allSpaces()
  local screenUUID = mainScreen:getUUID()
  local screenSpaces = allSpaces[screenUUID] or {}

  return screenSpaces, screenUUID, nil
end

-- Ensure we have enough spaces, create if needed
function M.ensureSpaceExists(spaceIndex)
  local screenSpaces, screenUUID, err = M.getScreenSpaces()
  if err then
    hs.alert.show(err)
    return false
  end

  local currentCount = #screenSpaces

  -- Create spaces if needed
  while currentCount < spaceIndex do
    hs.spaces.addSpaceToScreen(screenUUID)
    currentCount = currentCount + 1
    hs.printf("Dreamspaces: created space %d", currentCount)
  end

  return true
end

-- Switch to a space by index
function M.gotoSpace(spaceIndex)
  -- Ensure space exists first
  if not M.ensureSpaceExists(spaceIndex) then
    return false
  end

  local screenSpaces, _, err = M.getScreenSpaces()
  if err then
    hs.alert.show(err)
    return false
  end

  if spaceIndex <= #screenSpaces then
    local targetSpace = screenSpaces[spaceIndex]
    hs.spaces.gotoSpace(targetSpace)
    return true
  end

  return false
end

-- Arrange windows for a workspace on a specific space
function M.arrange(project, branch, spaceIndex)
  -- Ensure space exists
  if not M.ensureSpaceExists(spaceIndex) then
    return false
  end

  -- Give apps time to launch and settle, then arrange
  hs.timer.doAfter(3, function()
    M.arrangeWindows(project)
  end)

  return true
end

-- Arrange windows based on layout config
-- Uses orderedWindows() to get the most recently focused windows
function M.arrangeWindows(project)
  local screen = hs.screen.mainScreen()
  if not screen then
    hs.alert.show("No main screen found")
    return
  end

  local frame = screen:frame()
  local layout = loadLayout()

  -- App name mappings
  local ideApps = { "Xcode", "Cursor", "Visual Studio Code", "VSCode", "Code" }
  local terminalApps = { "iTerm2", "iTerm", "Terminal" }
  local notesApps = { "Obsidian" }

  -- Find windows using orderedWindows for most recent first
  local ideWindow = nil
  local terminalWindow = nil
  local notesWindow = nil

  for _, win in ipairs(hs.window.orderedWindows()) do
    -- Skip non-standard windows (fullscreen, etc.)
    if win:isStandard() then
      local app = win:application()
      if app then
        local appName = app:name()

        -- Only assign if not already found (gets most recent)
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
      end
    end
  end

  -- Apply layout
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

  -- Focus IDE last so it's on top
  if ideWindow then
    ideWindow:focus()
  end

  hs.alert.show("Windows arranged")
end

-- Move window to specific space
function M.moveToSpace(window, spaceIndex)
  if not M.ensureSpaceExists(spaceIndex) then
    return false
  end

  local screenSpaces, _, err = M.getScreenSpaces()
  if err then
    return false
  end

  if spaceIndex <= #screenSpaces then
    hs.spaces.moveWindowToSpace(window, screenSpaces[spaceIndex])
    return true
  end
  return false
end

return M
