-- Dreamspaces Hammerspoon module
-- Handles window arrangement and space management

local M = {}

local spaces = require("dreamspaces.spaces")
local picker = require("dreamspaces.picker")
local state = require("dreamspaces.state")

-- Arrange windows for a workspace (with space switching)
function M.arrange(project, branch, spaceIndex)
  spaces.arrange(project, branch, spaceIndex)
end

-- Arrange windows without switching spaces
function M.arrangeWindows(project)
  spaces.arrangeWindows(project)
end

-- Show workspace picker
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

-- Make globally available
_G.dreamspaces = M

return M
