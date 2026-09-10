vim.api.nvim_create_user_command("Altex", function(a)
  require("altex").list(a.args ~= "" and { pattern = a.args } or nil)
end, { nargs = "*", desc = "List commands and mappings" })

vim.api.nvim_create_user_command("AltexKey", function(a)
  require("altex").describe(a.args ~= "" and a.args or nil)
end, { nargs = "?", desc = "Describe a key sequence" })
