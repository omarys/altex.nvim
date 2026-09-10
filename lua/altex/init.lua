--- altex — list every command and mapping, joined, and describe a key sequence.
--- Discovery only: nothing to register. See CONTEXT.md and docs/adr/.
local Entries = require("altex.entries")

local M = {}

local DEFAULTS = {
  builtin = false, -- include builtin ex-commands (557 of them, undescribed)
  ["local"] = true, -- include buffer-local mappings
}

function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", DEFAULTS, opts or {})
end

local function cfg(extra)
  return vim.tbl_deep_extend("force", M.opts or DEFAULTS, extra or {})
end

--- snacks.picker.format: entry -> Highlight[]
local function format(entry)
  local out = {}
  local function add(text, hl)
    if text and text ~= "" then
      out[#out + 1] = { text, hl }
    end
  end
  add(entry.label, entry.kind == "command" and "Identifier" or "Special")
  if entry.kind == "command" and #entry.keys > 0 then
    local keys = {}
    for _, k in ipairs(entry.keys) do
      keys[#keys + 1] = k.modes .. " " .. k.lhs
    end
    add("  " .. table.concat(keys, ", "), "Special")
  end
  add("  " .. entry.desc:gsub("%s+", " "):sub(1, 120), "Comment")
  return out
end

local function details(entry)
  local lines = { entry.label }
  if entry.kind == "command" then
    lines[#lines + 1] = ("command  nargs=%s%s%s"):format(
      tostring(entry.nargs or "0"),
      entry.bang and " bang" or "",
      entry.builtin and " builtin" or ""
    )
    if entry.definition ~= "" then
      lines[#lines + 1] = "definition  " .. entry.definition
    end
    if #entry.keys > 0 then
      lines[#lines + 1] = "mappings:"
      for _, k in ipairs(entry.keys) do
        lines[#lines + 1] = ("  %s  %s  %s"):format(k.modes, k.lhs, k.desc or "")
      end
    end
  else
    lines[#lines + 1] = ("mapping  modes=%s%s"):format(entry.keys[1].modes, entry.buffer and " buffer-local" or "")
    if entry.rhs then
      lines[#lines + 1] = "rhs  " .. entry.rhs
    end
    if entry.callback then
      lines[#lines + 1] = "callback  " .. (entry.desc or "?")
    end
  end
  return lines
end

--- <CR>: run the entry. Argument-taking commands get their cmdline prefilled
--- instead of executed (legendary does the same); mappings are fed as keys.
local function confirm(picker, item)
  if not item or not item.kind then
    return
  end
  picker:close()
  vim.schedule(function()
    if item.kind == "command" then
      if not item.builtin and (item.nargs or "0") == "0" and not item.bang then
        vim.cmd(item.command)
      else
        vim.api.nvim_input(":")
        vim.schedule(function()
          vim.fn.setcmdline(item.command .. (item.bang and "!" or "") .. ((item.nargs or "0") ~= "0" and " " or ""))
        end)
      end
    else
      local lhs = item.keys[1].lhs
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(lhs, true, false, true), "m", false)
    end
  end)
end

local function source()
  return {
    finder = function(o)
      return Entries.all(cfg(o))
    end,
    format = format,
    preview = "preview",
    title = "Altex",
    confirm = confirm,
    actions = {
      altex_details = function(_, item)
        if item then
          vim.notify(table.concat(details(item), "\n"), vim.log.levels.INFO, { title = "Altex" })
        end
      end,
    },
    win = {
      input = { keys = { ["<a-k>"] = { "altex_details", mode = { "i", "n" } } } },
      list = { keys = { ["<a-k>"] = "altex_details" } },
    },
  }
end

--- Open the list. `extra` is snacks.picker.Config, e.g. { pattern = "lsp" }.
function M.list(extra)
  local ok, Picker = pcall(require, "snacks.picker")
  if not ok then
    vim.notify("altex: snacks.picker is required (see README)", vim.log.levels.ERROR)
    return
  end
  Picker.sources.altex = vim.tbl_deep_extend("force", Picker.sources.altex or {}, source(), extra or {})
  return Picker.pick("altex", extra)
end

--- Describe a key sequence: exact matches, or what it is a prefix of.
function M.describe(seq, opts)
  if seq == nil or seq == "" then
    seq = vim.fn.input("Key sequence: ")
  end
  if not seq or seq == "" then
    return
  end
  local exact, prefixes = Entries.resolve(seq, cfg(opts))
  if #exact == 0 and #prefixes == 0 then
    vim.notify(("altex: %s is not mapped"):format(seq), vim.log.levels.WARN, { title = "Altex" })
    return
  end
  local by_name = {}
  for _, e in ipairs(Entries.all(cfg(opts))) do
    if e.kind == "command" then
      by_name[e.text] = e
    end
  end
  local lines = {}
  for _, g in ipairs(exact) do
    local what = g.command and ("→ :" .. g.command) or (g.desc or g.rhs or "callback")
    local e = g.command and by_name[g.command]
    if e and e.desc ~= "" then
      what = what .. "  — " .. e.desc:gsub("%s+", " ")
    end
    lines[#lines + 1] = ("%s  (%s)%s\n  %s"):format(g.lhs, g.modes, g.buffer and "  buffer-local" or "", what)
    if g.rhs and g.command then
      lines[#lines + 1] = "  rhs: " .. g.rhs
    end
  end
  if #prefixes > 0 then
    local lhs = {}
    for _, g in ipairs(prefixes) do
      lhs[#lhs + 1] = g.lhs
    end
    lines[#lines + 1] = ("prefix of %d mappings: %s"):format(#prefixes, table.concat(lhs, "  "))
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Altex: " .. seq })
end

return M
