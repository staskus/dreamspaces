-- Dreamspaces state management (v2 - uses space IDs, not indexes)
local M = {}

local hs = _G.hs
local stateFile = os.getenv("HOME") .. "/.config/dreamspaces/state.json"
local cachedState = nil

function M.reload()
  local file = io.open(stateFile, "r")
  if not file then
    cachedState = { version = 2, workspaces = {} }
    return cachedState
  end

  local content = file:read("*all")
  file:close()

  if not content or content == "" then
    cachedState = { version = 2, workspaces = {} }
    return cachedState
  end

  local ok, result = pcall(hs.json.decode, content)
  if ok and result then
    cachedState = result
    -- Migrate v1 state (space indexes) to v2 (space IDs)
    if not result.version or result.version < 2 then
      M.migrateToSpaceIds()
    end
  else
    cachedState = { version = 2, workspaces = {} }
  end

  return cachedState
end

function M.save()
  local file = io.open(stateFile, "w")
  if not file then
    hs.printf("Dreamspaces: failed to write state file")
    return false
  end

  local content = hs.json.encode(cachedState, true)
  file:write(content)
  file:close()
  return true
end

function M.get()
  if not cachedState then
    M.reload()
  end
  return cachedState
end

-- Add a workspace with macOS space ID
function M.addWorkspace(project, branch, spaceId)
  local state = M.get()
  local key = project .. ":" .. branch

  state.workspaces[key] = {
    project = project,
    branch = branch,
    spaceId = spaceId,
    created = os.date("!%Y-%m-%dT%H:%M:%SZ")
  }

  return M.save()
end

-- Remove a workspace
function M.removeWorkspace(project, branch)
  local state = M.get()
  local key = project .. ":" .. branch
  state.workspaces[key] = nil
  return M.save()
end

-- Get workspace by project:branch
function M.getWorkspace(project, branch)
  local state = M.get()
  local key = project .. ":" .. branch
  return state.workspaces[key]
end

-- Get workspace for a specific macOS space ID
function M.getWorkspaceBySpaceId(spaceId)
  local state = M.get()
  for _, ws in pairs(state.workspaces or {}) do
    if ws.spaceId == spaceId then
      return ws
    end
  end
  return nil
end

-- Get workspace for current focused space
function M.current()
  local currentSpaceId = hs.spaces.focusedSpace()
  return M.getWorkspaceBySpaceId(currentSpaceId)
end

-- Convert space ID to current index (for display only)
function M.spaceIdToIndex(spaceId)
  local mainScreen = hs.screen.mainScreen()
  if not mainScreen then return nil end

  local screenSpaces = hs.spaces.allSpaces()[mainScreen:getUUID()] or {}
  for i, sid in ipairs(screenSpaces) do
    if sid == spaceId then
      return i
    end
  end
  return nil
end

-- List all workspaces with current display index
function M.listWorkspaces()
  local state = M.get()
  local workspaces = {}

  for key, ws in pairs(state.workspaces or {}) do
    local currentIndex = M.spaceIdToIndex(ws.spaceId)
    -- Only include workspaces whose space still exists
    if currentIndex then
      table.insert(workspaces, {
        key = key,
        project = ws.project,
        branch = ws.branch,
        spaceId = ws.spaceId,
        space = currentIndex,
        created = ws.created
      })
    end
  end

  table.sort(workspaces, function(a, b)
    return (a.space or 999) < (b.space or 999)
  end)

  return workspaces
end

-- Migrate from v1 (space indexes) to v2 (space IDs)
function M.migrateToSpaceIds()
  hs.printf("Dreamspaces: migrating state to v2 (space IDs)")
  local state = cachedState
  local mainScreen = hs.screen.mainScreen()
  if not mainScreen then return end

  local screenSpaces = hs.spaces.allSpaces()[mainScreen:getUUID()] or {}

  for key, ws in pairs(state.workspaces or {}) do
    if ws.space and not ws.spaceId then
      local index = ws.space
      if index <= #screenSpaces then
        ws.spaceId = screenSpaces[index]
        hs.printf("Dreamspaces: migrated %s from index %d to ID %d", key, index, ws.spaceId)
      end
      ws.space = nil
    end
  end

  state.version = 2
  M.save()
end

-- Clean up orphaned workspaces (space no longer exists)
function M.cleanup()
  local state = M.get()
  local mainScreen = hs.screen.mainScreen()
  if not mainScreen then return 0 end

  local screenSpaces = hs.spaces.allSpaces()[mainScreen:getUUID()] or {}
  local spaceIdSet = {}
  for _, sid in ipairs(screenSpaces) do
    spaceIdSet[sid] = true
  end

  local removed = 0
  for key, ws in pairs(state.workspaces or {}) do
    if not spaceIdSet[ws.spaceId] then
      hs.printf("Dreamspaces: removing orphaned workspace %s (space %d gone)", key, ws.spaceId or 0)
      state.workspaces[key] = nil
      removed = removed + 1
    end
  end

  if removed > 0 then
    M.save()
  end

  return removed
end

return M
