--- altex.entries — build the index from Neovim runtime state.
--- Vocabulary: CONTEXT.md. The join rule: docs/adr/0001.
local M = {}

--- Modes queried. "v" is deliberately absent: nvim_get_keymap("v") already
--- returns the union of x and s, so querying it would duplicate every visual map.
local MODES = { "n", "i", "x", "s", "o", "t", "c", "l" }

--- Command modifiers that may precede the command name in a rhs.
local MODIFIERS = {
  aboveleft = true,
  belowright = true,
  botright = true,
  browse = true,
  confirm = true,
  hide = true,
  horizontal = true,
  keepalt = true,
  keepjumps = true,
  keepmarks = true,
  keeppatterns = true,
  leftabove = true,
  lockmarks = true,
  noautocmd = true,
  noswapfile = true,
  rightbelow = true,
  sandbox = true,
  silent = true,
  tab = true,
  topleft = true,
  unsilent = true,
  verbose = true,
  vertical = true,
}

--- Normalize a key sequence so `<C-x>`, `gd` and typed text compare equal.
--- <leader> is expanded by hand: Neovim does not expand it inside <...>.
function M.norm(seq)
  if type(seq) ~= "string" then
    return ""
  end
  local s = seq:gsub("<[Ll]eader>", vim.g.mapleader or "\\"):gsub("<[Ll]ocalleader>", vim.g.maplocalleader or "\\")
  return vim.fn.keytrans(vim.api.nvim_replace_termcodes(s, true, true, true))
end

--- The command name a rhs invokes, or nil.
--- Only `:Cmd<CR>` and `<Cmd>Cmd<CR>` count, with ranges and modifiers allowed.
--- Callbacks, <Plug> chains, chained <bar> commands and shell escapes return nil.
function M.rhs_command(rhs)
  if type(rhs) ~= "string" or rhs == "" then
    return nil
  end
  local body = rhs:match("^%s*<[Cc][Mm][Dd]>%s*(.-)%s*<[Cc][Rr]>%s*$") or rhs:match("^%s*:(.-)<[Cc][Rr]>%s*$")
  if not body or body:find("<[Bb][Aa][Rr]>") then
    return nil
  end
  body = body:gsub("^%s*<[^>]*>%s*", "") -- leading <C-u> etc.
  local rest = body:gsub("^[%d%%,;%.%$%+%-%'<>%[%]]*", ""):gsub("^%s+", "")
  if rest:match("^[!&]") then
    return nil -- :!shell, :&  — not a command name
  end
  while true do
    rest = rest:gsub("^%s*!?%s*", "")
    local word, tail = rest:match("^([%a][%w_]*)(.*)$")
    if not word then
      return nil
    end
    if MODIFIERS[word] then
      rest = tail
    else
      return word
    end
  end
end

--- @return altex.Keymap[] one entry per distinct (lhs, buffer, target), modes collapsed
function M.keymaps(opts)
  opts = opts or {}
  local groups, order = {}, {}

  local function add(km)
    if km.lhs:match("^<[Pp]lug>") or km.lhs:match("^<[Ss][Nn][Rr]>") then
      return
    end
    if not km.callback and (not km.rhs or km.rhs == "" or km.rhs:lower() == "<nop>") then
      return
    end
    local target = km.callback and ("cb:" .. tostring(km.callback)) or ("rhs:" .. tostring(km.rhs))
    local id = table.concat({ tostring(km.buffer), km.lhs, target }, "\1")
    local g = groups[id]
    if not g then
      g = {
        lhs = km.lhs,
        rhs = km.rhs,
        callback = km.callback,
        desc = km.desc,
        buffer = km.buffer ~= 0,
        modes = {},
        raw = {},
      }
      groups[id] = g
      order[#order + 1] = id
    end
    g.modes[km.mode] = true
    g.desc = g.desc or km.desc
    g.raw[#g.raw + 1] = km
  end

  for _, mode in ipairs(MODES) do
    for _, km in ipairs(vim.api.nvim_get_keymap(mode)) do
      add(km)
    end
    if opts["local"] ~= false then
      for _, km in ipairs(vim.api.nvim_buf_get_keymap(0, mode)) do
        add(km)
      end
    end
  end

  local out = {}
  for _, id in ipairs(order) do
    local g = groups[id]
    if g.modes.x and g.modes.s then -- same thing to the user: Neovim's mapmode-v
      g.modes.x, g.modes.s, g.modes.v = nil, nil, true
    end
    local modes = vim.tbl_keys(g.modes)
    table.sort(modes)
    g.modes = table.concat(modes)
    if g.callback and not g.desc then
      local info = debug.getinfo(g.callback, "S")
      if info and info.what == "Lua" and info.source then
        local line = info.linedefined
        g.desc = (line and line > 0) and (info.source:sub(2) .. ":" .. line) or info.source:sub(2)
      end
    end
    out[#out + 1] = g
  end
  return out
end

--- The full index: command entries and mapping entries, sorted by name/sequence.
function M.all(opts)
  opts = opts or {}
  local groups = M.keymaps(opts)
  local by_command = {}
  for _, g in ipairs(groups) do
    g.command = M.rhs_command(g.rhs)
    if g.command then
      by_command[g.command] = by_command[g.command] or {}
      table.insert(by_command[g.command], g)
    end
  end

  local entries, seen = {}, {}
  local cmds = vim.api.nvim_get_commands({})
  for k, v in pairs(vim.api.nvim_buf_get_commands(0, {})) do
    if type(k) == "string" and not cmds[k] then
      cmds[k] = v
    end
  end

  local function add_command(name, def, builtin)
    if seen[name] then
      return
    end
    seen[name] = true
    entries[#entries + 1] = {
      kind = "command",
      text = name,
      label = ":" .. name,
      desc = (def and def.definition) or "",
      command = name,
      builtin = builtin,
      bang = (def and def.bang) or false,
      nargs = def and def.nargs,
      definition = (def and def.definition) or "",
      keys = by_command[name] or {},
      preview = { text = vim.inspect(def or { name = name, builtin = true }), ft = "lua" },
    }
  end

  for name, def in pairs(cmds) do
    add_command(name, def, false)
  end
  if opts.builtin then
    for _, name in ipairs(vim.fn.getcompletion("", "command")) do
      if not cmds[name] then
        add_command(name, nil, true)
      end
    end
  end

  for _, g in ipairs(groups) do
    -- A mapping whose rhs invokes a command that is not in the index (a hidden
    -- builtin, say) stays visible as a mapping entry rather than disappearing.
    if not g.command or not seen[g.command] then
      entries[#entries + 1] = {
        kind = "mapping",
        text = g.lhs,
        label = g.lhs,
        desc = g.desc or (g.command and ("→ :" .. g.command)) or (g.rhs and ("→ " .. g.rhs:gsub("%s+", " "))) or "",
        keys = { g },
        buffer = g.buffer,
        rhs = g.rhs,
        callback = g.callback,
        preview = { text = vim.inspect(g.raw), ft = "lua" },
      }
    end
  end

  table.sort(entries, function(a, b)
    return a.text < b.text
  end)
  return entries
end

--- Exact and prefix resolution of a key sequence. @return altex.Keymap[], altex.Keymap[]
function M.resolve(seq, opts)
  local want = M.norm(seq)
  local exact, prefixes = {}, {}
  for _, g in ipairs(M.keymaps(opts)) do
    local have = M.norm(g.lhs)
    if have == want then
      exact[#exact + 1] = g
    elseif #have > #want and have:sub(1, #want) == want then
      prefixes[#prefixes + 1] = g
    end
  end
  return exact, prefixes
end

return M
