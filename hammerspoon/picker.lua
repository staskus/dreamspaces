-- Dreamspaces workspace picker
local M = {}

local hs = _G.hs
local state = require("dreamspaces.state")

local chooser = nil

-- Show workspace picker
function M.show()
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

  chooser = hs.chooser.new(function(choice)
    if choice then
      M.switchTo(choice.workspace)
    end
  end)

  chooser:choices(choices)
  chooser:placeholderText("Switch workspace...")
  chooser:show()
end

-- Switch to a workspace
function M.switchTo(workspace)
  local allSpaces = hs.spaces.allSpaces()
  local mainScreen = hs.screen.mainScreen()
  local screenSpaces = allSpaces[mainScreen:getUUID()] or {}

  if workspace.space <= #screenSpaces then
    hs.spaces.gotoSpace(screenSpaces[workspace.space])
    hs.alert.show(workspace.project .. ":" .. workspace.branch)
  else
    hs.alert.show("Space " .. workspace.space .. " not found")
  end
end

return M
