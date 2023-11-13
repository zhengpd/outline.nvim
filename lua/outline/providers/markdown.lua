-- Our own markdown provider is used because legacy symbols-outline considered
-- the case where markdown does not have an LSP. However, it does, so as of now
-- this module is kept for use when user opens symbols outline before the
-- markdown LSP is ready. Please also see comment in providers/init.lua

local M = {}

---@return boolean ft_is_markdown
function M.should_use_provider(bufnr)
  return vim.api.nvim_buf_get_option(bufnr, 'ft') == 'markdown'
end

function M.hover_info(_, _, on_info)
  on_info(nil, {
    contents = {
      kind = 'markdown',
      contents = { 'No extra information availaible!' },
    },
  })
end

-- Parses markdown files and returns a table of SymbolInformation[] which is
-- used by the plugin to show the outline.
---@return table
function M.handle_markdown()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local level_symbols = { { children = {} } }
  local max_level = 1
  local is_inside_code_block = false

  for line, value in ipairs(lines) do
    if string.find(value, '^```') then
      is_inside_code_block = not is_inside_code_block
    end
    if is_inside_code_block then
      goto nextline
    end

    local next_value = lines[line+1]
    local is_emtpy_line = #value:gsub("^%s*(.-)%s*$", "%1") == 0

    local header, title = string.match(value, '^(#+)%s+(.+)$')
    if not header and next_value and not is_emtpy_line then
      if string.match(next_value, '^=+%s*$') then
        header = '#'
        title = value
      elseif string.match(next_value, '^-+%s*$') then
        header = '##'
        title = value
      end
    end
    if not header or not title then
      goto nextline
    end
    -- TODO: This is not needed and it works?
    -- if #header > 6 then
    --   goto nextline
    -- end

    local depth = #header + 1

    local parent
    for i = depth - 1, 1, -1 do
      if level_symbols[i] ~= nil then
        parent = level_symbols[i].children
        break
      end
    end

    for i = depth, max_level do
      if level_symbols[i] ~= nil then
        level_symbols[i].selectionRange['end'].line = line - 1
        level_symbols[i].range['end'].line = line - 1
        level_symbols[i] = nil
      end
    end
    max_level = depth

    local entry = {
      kind = 15,
      name = title,
      selectionRange = {
        start = { character = 1, line = line - 1 },
        ['end'] = { character = 1, line = line - 1 },
      },
      range = {
        start = { character = 1, line = line - 1 },
        ['end'] = { character = 1, line = line - 1 },
      },
      children = {},
    }

    parent[#parent + 1] = entry
    level_symbols[depth] = entry
    ::nextline::
  end

  for i = 2, max_level do
    if level_symbols[i] ~= nil then
      level_symbols[i].selectionRange['end'].line = #lines
      level_symbols[i].range['end'].line = #lines
    end
  end

  return level_symbols[1].children
end

---@param on_symbols function
---@param opts table
function M.request_symbols(on_symbols, opts)
  on_symbols(M.handle_markdown(), opts)
end

return M