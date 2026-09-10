#!/usr/bin/env nvim -l
-- Run: nvim -l test/altex.lua
-- Smallest check that fails if discovery, the join, or key-sequence resolution breaks.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local E = require("altex.entries")

local function eq(got, want, what)
  assert(got == want, ("%s: got %s, want %s"):format(what, vim.inspect(got), vim.inspect(want)))
end

-- rhs -> command name
eq(E.rhs_command(":Foo<CR>"), "Foo", "r1")
eq(E.rhs_command("<Cmd>Bar<CR>"), "Bar", "r2")
eq(E.rhs_command(":<C-u>Baz<CR>"), "Baz", "r3")
eq(E.rhs_command(":silent! write<CR>"), "write", "r4")
eq(E.rhs_command(":'<,'>Sort<CR>"), "Sort", "r5")
eq(E.rhs_command(":!make<CR>"), nil, "r6")
eq(E.rhs_command(":lua vim.lsp.buf.definition()<CR>"), "lua", "r7")
eq(E.rhs_command(":A<bar>B<CR>"), nil, "r8")
eq(E.rhs_command(nil), nil, "r9")

-- normalization: typed text, stored lhs and leader all compare equal
vim.g.mapleader = "\\"
eq(E.norm("<C-x>"), E.norm("<c-x>"), "n1")
eq(E.norm("<leader>at"), E.norm("\\at"), "n2")

-- discovery + join
vim.api.nvim_create_user_command("AltexProbe", function() end, { desc = "probe" })
vim.keymap.set("n", "<leader>at", ":AltexProbe<CR>", { desc = "run probe" })
vim.keymap.set("n", "<leader>cb", function() end, { desc = "callback probe" })
vim.keymap.set("n", "<Plug>(altex-probe)", ":AltexProbe<CR>")

local all = E.all({ builtin = false })
local by = {}
for _, e in ipairs(all) do
  by[e.text] = e
end

local probe = by["AltexProbe"]
assert(probe, "AltexProbe missing from the index")
eq(probe.kind, "command", "k1")
eq(probe.desc, "probe", "k2")
eq(#probe.keys, 1, "k3")
eq(probe.keys[1].lhs, "\\at", "k4")
eq(probe.keys[1].modes, "n", "k5")
eq(probe.keys[1].command, "AltexProbe", "k6")

local cb = by["\\cb"]
assert(cb, "callback mapping missing")
eq(cb.kind, "mapping", "k7")
eq(cb.desc, "callback probe", "k8")

for _, e in ipairs(all) do
  assert(not e.text:match("^<Plug>"), "<Plug> mapping leaked into the index")
end
assert(not by["print"], "builtin leaked in with builtin=false")
local with_builtin = E.all({ builtin = true })
local seen_print = false
for _, e in ipairs(with_builtin) do
  if e.text == "print" then
    seen_print = true
  end
end
assert(seen_print, "builtin missing with builtin=true")

-- describe: exact and prefix
local exact = E.resolve("<leader>at")
assert(#exact >= 1, "exact resolve failed")
eq(exact[1].lhs, "\\at", "d1")
local noexact, pfx = E.resolve("<leader>a")
eq(#noexact, 0, "d1b")
eq(#pfx, 1, "d1c")
eq(pfx[1].lhs, "\\at", "d1d")

-- the same sequence on a callback mapping resolves without a command
local cbexact = E.resolve("<leader>cb")
eq(#cbexact, 1, "d2")
eq(cbexact[1].command, nil, "d3")

print("altex: all checks passed")
