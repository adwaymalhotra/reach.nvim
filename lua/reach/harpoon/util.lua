local f = string.format

local module = {}

function module.deduped_path(buffer)
  return table.concat(buffer.split_path, '/', #buffer.split_path - buffer.deduped)
end

function module.open(buffer)
  vim.api.nvim_command(f('edit %s', buffer.name))
end

function module.split_buf(buffer, command)
  vim.api.nvim_command(f('%s %s', command, buffer.bufnr))
end

return module
