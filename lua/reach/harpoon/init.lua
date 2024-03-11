local Entry = require('reach.picker.entry')
local Picker = require('reach.picker.picker')
local Machine = require('reach.machine')
local helpers = require('reach.helpers')
local read = require('reach.harpoon.read')
local util = require('reach.util')
local hutil = require('reach.harpoon.util')
local make_harpoons = require('reach.harpoon.make_harpoons')

local read_one = read.read_one
local notify = helpers.notify

local insert = table.insert
local f = string.format

local module = {}

module.options = require('reach.harpoon.options')

local state_to_handle_hl = setmetatable({
  ['DELETING'] = 'ReachHandleDelete',
  ['SPLITTING'] = 'ReachHandleSplit',
}, {
  __index = function()
    return 'ReachHandleBuffer'
  end,
})

function module.show(options)
  options = module.options.extend(options)

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

  if not entries then
    return vim.notify('Error creating View!')
  end

  local picker = Picker:new(entries)

  picker:set_ctx({
    options = options,
    marker_present = marker_present,
    max_handle_length = max_handle_length,
  })

  local machine = Machine:new(module.machine)

  machine.ctx = {
    picker = picker,
    options = options,
  }

  machine:init()
end

function module.component(state)
  local buffer = state.data
  local ctx = state.ctx
  local is_current = buffer.bufnr == vim.api.nvim_get_current_buf()

  local parts = {}

  if ctx.marker_present then
    local marker = buffer.previous_marker or { ' ', 'Normal' }

    insert(parts, { f(' %s', marker[1]), marker[2] })
  end

  local pad = string.rep(' ', ctx.max_handle_length - #buffer.handle + 1)

  insert(parts, { f(' %s%s', buffer.handle, pad), state_to_handle_hl[ctx.state] })

  if ctx.state == 'SETTING_PRIORITY' then
    insert(parts, { f('%s ', buffer.priority or ' '), 'ReachPriority' })
  end

  if ctx.options.show_icons and buffer.icon then
    insert(parts, { f('%s ', buffer.icon[1]), buffer.icon[2] })
  end

  local tail_hl = 'ReachTail'

  if state.exact then
    tail_hl = 'ReachMatchExact'
  elseif is_current then
    tail_hl = 'ReachCurrent'
  end

  insert(parts, { f('%s ', buffer.tail), tail_hl })

  if ctx.options.show_modified and buffer.modified then
    insert(parts, { f('%s ', ctx.options.modified_icon), 'ReachModifiedIndicator' })
  end

  -- insert the full path of the file
  insert(parts, { f(' %s ', hutil.parent_path(buffer)), 'ReachDirectory' })

  if state.grayout or (is_current and ctx.options.grayout_current and ctx.state == 'OPEN') then
    for _, part in pairs(parts) do
      part[2] = 'ReachGrayOut'
    end
  end

  return parts
end

local function target_state(input, actions)
  local r = util.replace_termcodes

  if input == r(actions.adding) then
    return 'ADDING'
  end

  if input == r(actions.delete) then
    return 'DELETING'
  end

  if vim.tbl_contains({ r(actions.split), r(actions.vertsplit), r(actions.tabsplit) }, input) then
    return 'SPLITTING'
  end

  return 'SWITCHING'
end

local function set_grayout(entries, matches)
  matches = vim.tbl_map(function(entry)
    return entry.data.bufnr
  end, matches)

  util.for_each(function(entry)
    entry:set_state({ grayout = not vim.tbl_contains(matches, entry.data.bufnr) })
  end, entries)
end

local function hide_current()
  local current = vim.api.nvim_get_current_buf()

  return function(entry)
    return entry.data.bufnr ~= current
  end
end

module.machine = {
  initial = 'OPEN',
  state = {
    CLOSED = {
      hooks = {
        on_enter = function(self)
          self.ctx.picker:close()
        end,
      },
    },
    OPEN = {
      hooks = {
        on_enter = function(self)
          local picker = self.ctx.picker

          picker:set_ctx({ state = self.current })
          picker:render(not self.ctx.options.show_current and hide_current() or nil)

          local input = util.pgetcharstr()

          if not input then
            return self:transition('CLOSED')
          end

          self.ctx.state = {
            input = input,
          }

          self:transition(target_state(self.ctx.state.input, self.ctx.options.actions))
        end,
      },
      targets = { 'SWITCHING', 'ADDING', 'DELETING', 'SPLITTING', 'CLOSED' },
    },
    ADDING = {
      hooks = {
        on_enter = function(self)
          local picker = self.ctx.picker
          picker:set_ctx({ state = self.current })

          hutil.add_current()
          notify('Harpooned!')

          self:transition('CLOSED')
        end,
      },
      targets = { 'CLOSED' },
    },
    DELETING = {
      hooks = {
        on_enter = function(self)
          local picker = self.ctx.picker

          picker:set_ctx({ state = self.current })
          picker:render()

          local match

          repeat
            local input = util.pgetcharstr()

            if not input then
              return self:transition('CLOSED')
            end

            match = read_one(picker.entries, { input = input })

            if match then
              hutil.remove(match.data.name)
              picker:remove('name', match.data.name)

              if #picker.entries == 0 then
                break
              end

              picker:render()
            end

          until not match
          self:transition('OPEN')
        end,
      },
      targets = { 'OPEN' },
    },
    SPLITTING = {
      hooks = {
        on_enter = function(self)
          local picker = self.ctx.picker

          picker:set_ctx({ state = self.current })
          picker:render()

          local match = read_one(picker.entries, {
            on_input = function(matches, exact)
              if exact then
                exact:set_state({ exact = true })
              end

              if self.ctx.options.grayout then
                set_grayout(picker.entries, matches)
              end

              picker:render()
            end,
          })

          if match then
            local action_to_command = {
              split = 'split',
              vertsplit = 'vsplit',
              tabsplit = 'tab sbuffer',
            }

            local action = util.find_key(function(value)
              return self.ctx.state.input == util.replace_termcodes(value)
            end, self.ctx.options.actions)

            hutil.split_buf(match.data, action_to_command[action])
          end

          self:transition('CLOSED')
        end,
      },
      targets = { 'CLOSED' },
    },
    SWITCHING = {
      hooks = {
        on_enter = function(self)
          local picker = self.ctx.picker

          local match = read_one(picker.entries, {
            input = self.ctx.state.input,
            on_input = function(matches, exact)
              if exact then
                exact:set_state({ exact = true })
              end

              if self.ctx.options.grayout then
                set_grayout(picker.entries, matches)
              end

              picker:render(not self.ctx.options.show_current and hide_current() or nil)
            end,
          })

          if match then
            hutil.open(match.data)
          end
          self:transition('CLOSED')
        end,
      },
      targets = { 'CLOSED' },
    },
  },
}

return module
