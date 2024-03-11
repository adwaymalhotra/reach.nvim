local Entry = require('reach.picker.entry')
local f = string.format

local module = {}

function module.parent_path(buffer)
  return vim.fn.fnamemodify(buffer.name, ':h')
end

function module.deduped_path(buffer)
  return table.concat(buffer.split_path, '/', #buffer.split_path - buffer.deduped)
end

function module.add_current()
  require('harpoon'):list():append()
end

function module.remove(file)
  local h = require('harpoon')
  local item = h:list():get_by_display(file)
  h:list():remove(item)
end

function module.open(buffer)
  vim.api.nvim_command(f('edit %s', buffer.name))
end

function module.split_buf(buffer, command)
  vim.api.nvim_command(f('%s %s', command, buffer.name))
end

function module.create_entries(options)
  local make_harpoons = require('reach.harpoon.make_harpoons')

  local bufs = make_harpoons(options)
  local count = #bufs

  if count < 1 then
    return vim.notify('Nothing Harpooned Ahab!')
  end

  local entries = vim.tbl_map(function(buffer)
    return Entry:new({
      component = require('reach.harpoon').component,
      data = buffer,
    })
  end, bufs)

  local max_handle_length = 0
  local marker_present = false

  for _, buffer in pairs(bufs) do
    if #buffer.handle > max_handle_length then
      max_handle_length = #buffer.handle
    end

    if buffer.previous_marker then
      marker_present = true
    end
  end

  return {
    entries = entries,
    max_handle_length = max_handle_length,
    marker_present = marker_present,
  }
end

return module
