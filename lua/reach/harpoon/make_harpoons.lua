local Harpoon = require('reach.harpoon.harpoon')
local handles = require('reach.harpoon.handles')
local util = require('reach.util')
local sort = require('reach.harpoon.sort')
local harpoon = require("harpoon")

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
  local buffers = {}
  local harpoons = harpoon:list().items
  local infos = {}
  foreach(harpoons, function(t,k,v)
    local name = v.value
    table.insert(infos, { bufnr = 0, name = name, changed = false, lastused = 0})
  end)

  for _, info in pairs(infos) do
    local buffer = Harpoon:new(info)

    local force = util.any(function(v)
      return v == buffer.buftype or v == buffer.filetype
    end, options.force_delete)

    if force then
      buffer.delete_command = 'bdelete! ' .. buffer.bufnr
    end

    if buffer.unnamed then
      buffer.tail = #buffer.filetype > 0 and buffer.filetype or '[No name]'
      table.insert(buffers, buffer)
      goto continue
    end

    table.insert(buffers, buffer)

    ::continue::
  end

  if options.previous.enable then
    set_previous_markers(buffers, options.previous)
  end

  if options.handle == 'auto' then
    buffers = sort.sort_priority(buffers, { sort = options.sort })
    handles.assign_auto_handles(
      buffers,
      { auto_handles = options.auto_handles, auto_exclude_handles = options.auto_exclude_handles }
    )
  else
    if type(options.sort) == 'function' then
      table.sort(buffers, function(b1, b2)
        return options.sort(b1.bufnr, b2.bufnr)
      end)
    else
      buffers = sort.sort_default(buffers)
    end

    if options.handle == 'bufnr' then
      handles.assign_bufnr_handles(buffers)
    else
      handles.assign_dynamic_handles(buffers, options)
    end
  end

  return buffers
end
