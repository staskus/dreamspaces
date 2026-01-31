-- Dreamspaces state management for Hammerspoon
local M = {}

local hs = _G.hs

local stateFile = os.getenv("HOME") .. "/.config/dreamspaces/state.json"
local cachedState = nil

-- Read state from disk
function M.reload()
  local file = io.open(stateFile, "r")
  if not file then
    cachedState = { workspaces = {} }
    return cachedState
  end

  local content = file:read("*all")
  file:close()

  local ok, result = pcall(hs.json.decode, content)
  if ok and result then
    cachedState = result
  else
    cachedState = { workspaces = {} }
  end

  return cachedState
end

-- Get current state (uses cache, call reload() to refresh)
function M.get()
  if not cachedState then
    M.reload()
  end
  return cachedState
end

-- List all workspaces
function M.listWorkspaces()
  local state = M.get()
  local workspaces = {}

  if state.workspaces then
    for key, ws in pairs(state.workspaces) do
      table.insert(workspaces, {
        key = key,
        project = ws.project,
        branch = ws.branch,
        space = ws.space,
        created = ws.created
      })
    end
  end

  -- Sort by space index
  table.sort(workspaces, function(a, b)
    return a.space < b.space
  end)

  return workspaces
end

-- Get workspace for current space
function M.current()
  local currentSpace = hs.spaces.focusedSpace()
  local allSpaces = hs.spaces.allSpaces()
  local mainScreen = hs.screen.mainScreen()
  local screenSpaces = allSpaces[mainScreen:getUUID()] or {}

  -- Find space index
  local spaceIndex = nil
  for i, space in ipairs(screenSpaces) do
    if space == currentSpace then
      spaceIndex = i
      break
    end
  end

  if not spaceIndex then
    return nil
  end

  -- Find workspace at this space
  local state = M.get()
  if state.workspaces then
    for _, ws in pairs(state.workspaces) do
      if ws.space == spaceIndex then
        return ws
      end
    end
  end

  return nil
end

return M
