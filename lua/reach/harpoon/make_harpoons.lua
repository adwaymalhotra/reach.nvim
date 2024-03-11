local Harpoon = require('reach.harpoon.harpoon')
local handles = require('reach.harpoon.handles')
local util = require('reach.util')
local sort = require('reach.harpoon.sort')
local harpoons = require("harpoon")

local function set_previous_markers(buffers, options)
  local current = vim.api.nvim_get_current_buf()

  local last_used = vim.tbl_filter(function(buffer)
    return buffer.lastused > 0 and buffer.bufnr ~= current
  end, buffers)

  table.sort(last_used, function(a, b)
    return a.lastused > b.lastused
  end)

  local chars = options.chars
  local groups = options.groups

  for i = 1, math.min(options.depth, #last_used) do
    last_used[i].previous_marker = { chars[i] or chars[#chars] or '•', groups[i] or groups[#groups] or 'Comment' }
  end
end

return function(options)
  local harpooned = {}
  local harpoons = harpoons:list().items
  local infos = {}
  foreach(harpoons, function(t,k,v)
    local name = v.value
    table.insert(infos, { bufnr = 0, name = name, changed = false, lastused = 0})
  end)

  for _, info in pairs(infos) do
    local harpoon = Harpoon:new(info)

    local force = util.any(function(v)
      return v == harpoon.buftype or v == harpoon.filetype
    end, options.force_delete)

    if harpoon.unnamed then
      harpoon.tail = #harpoon.filetype > 0 and harpoon.filetype or '[No name]'
      table.insert(harpooned, harpoon)
      goto continue
    end

    table.insert(harpooned, harpoon)

    ::continue::
  end

  if options.previous.enable then
    set_previous_markers(harpooned, options.previous)
  end

  if options.handle == 'auto' then
    harpooned = sort.sort_priority(harpooned, { sort = options.sort })
    handles.assign_auto_handles(
      harpooned,
      { auto_handles = options.auto_handles, auto_exclude_handles = options.auto_exclude_handles }
    )
  else
    harpooned = sort.sort_default(harpooned)
    handles.assign_dynamic_handles(harpooned, options)
  end

  return harpooned
end
