-- Dreamspaces space management
local M = {}

local hs = _G.hs

-- Arrange windows for a workspace on a specific space
function M.arrange(project, branch, spaceIndex)
  -- Get all spaces
  local allSpaces = hs.spaces.allSpaces()
  local mainScreen = hs.screen.mainScreen()
  local screenSpaces = allSpaces[mainScreen:getUUID()] or {}

  -- Validate space index
  if spaceIndex > #screenSpaces then
    hs.alert.show("Space " .. spaceIndex .. " does not exist")
    return false
  end

  local targetSpace = screenSpaces[spaceIndex]

  -- Focus the target space
  hs.spaces.gotoSpace(targetSpace)

  -- Give apps time to launch and settle
  hs.timer.doAfter(1, function()
    M.arrangeWindows(project)
  end)

  return true
end

-- Arrange windows based on project config
function M.arrangeWindows(project)
  local screen = hs.screen.mainScreen()
  local frame = screen:frame()

  -- Find windows by app
  local ideWindow = nil
  local terminalWindow = nil
  local notesWindow = nil

  for _, win in ipairs(hs.window.allWindows()) do
    local app = win:application()
    if app then
      local appName = app:name()
      if appName == "Cursor" or appName == "Xcode" or appName == "VSCode" then
        ideWindow = win
      elseif appName == "Terminal" or appName == "iTerm2" then
        terminalWindow = win
      elseif appName == "Obsidian" then
        notesWindow = win
      end
    end
  end

  -- Default layout: IDE left 60%, terminal right 40%
  if ideWindow then
    ideWindow:setFrame({
      x = frame.x,
      y = frame.y,
      w = frame.w * 0.6,
      h = frame.h
    })
    ideWindow:focus()
  end

  if terminalWindow then
    terminalWindow:setFrame({
      x = frame.x + frame.w * 0.6,
      y = frame.y,
      w = frame.w * 0.4,
      h = frame.h * 0.6
    })
  end

  if notesWindow then
    notesWindow:setFrame({
      x = frame.x + frame.w * 0.6,
      y = frame.y + frame.h * 0.6,
      w = frame.w * 0.4,
      h = frame.h * 0.4
    })
  end
end

-- Move window to specific space
function M.moveToSpace(window, spaceIndex)
  local allSpaces = hs.spaces.allSpaces()
  local mainScreen = hs.screen.mainScreen()
  local screenSpaces = allSpaces[mainScreen:getUUID()] or {}

  if spaceIndex <= #screenSpaces then
    hs.spaces.moveWindowToSpace(window, screenSpaces[spaceIndex])
    return true
  end
  return false
end

return M
