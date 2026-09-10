# altex

`M-x` for Neovim: one list of every command and mapping, with the key sequence shown next to the commands that have one.

- Lists user, plugin and (opt-in) builtin ex-commands, plus every mapping — including Lua callbacks, which have no command at all.
- Joins the two: a mapping appears next to the command its rhs invokes.
- `:AltexKey <seq>` describes a key sequence: what it runs, or what it is a prefix of.
- No registration. The index is built from Neovim runtime state at the moment you open the list.

Requires Neovim 0.10+ and [snacks.nvim](https://github.com/folke/snacks.nvim) for the picker.

## Install

```lua
{ "you/altex", dependencies = { "folke/snacks.nvim" }, opts = {} }
```

## Usage

```
:Altex                 list everything
:Altex lsp             list, pre-filtered
:AltexKey <leader>ff   describe a key sequence
```

```lua
require("altex").list()
require("altex").describe("<C-w>w")
require("altex").entries()      -- the raw index, no UI
```

| Key | Action |
| --- | --- |
| `<CR>` | Run the command, or press the mapping's keys. Commands that take arguments get `:Cmd ` prefilled instead of executed. |
| `<a-k>` | Show details without running anything. |
| `<Esc>` | Close. |

## Options

```lua
require("altex").setup({
  builtin = false,   -- include the ~557 builtin ex-commands
  ["local"] = true,  -- include buffer-local mappings
})
```

## What it will not tell you

- A mapping is attached to a command only when its rhs is a bare `:Cmd<CR>` or `<Cmd>Cmd<CR>`. Callbacks, `<Plug>` chains and `:A<bar>B` never attach, so those commands show no key sequence. See [docs/adr/0002](docs/adr/0002-one-join-rule-one-backend.md).
- Neovim's API exposes no `desc` for ex-commands. For a callback-defined user command the string you passed as `desc` comes back as `definition`; for a string-defined command you get the command body instead and the description is unrecoverable. The list shows `definition` and does not pretend otherwise.
- Builtin ex-commands have no description at all, which is part of why they are off by default.

## Development

There is no build step. [mise](https://mise.jdx.dev) pins the toolchain and defines the commands, so pre-commit and CI call the same thing:

```sh
mise install        # neovim 0.12.5 + stylua 2.5.2
mise run test       # nvim -l test/altex.lua
mise run fmt        # stylua lua plugin test
pre-commit install  # wire the git hook (needs a git repo)
```

`.pre-commit-config.yaml` runs stylua, luacheck and the self-check. The luacheck hook builds its own environment, but needs `lua` and `luarocks` on `PATH` — mise's `lua` plugin provides both.

Vocabulary lives in [CONTEXT.md](CONTEXT.md); decisions in [docs/adr](docs/adr).
