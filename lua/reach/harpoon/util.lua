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

return module
