# One join rule, and only one picker backend

Two decisions that were taken together because both are about refusing scope:

- A mapping counts as attached to a command only when its `rhs` is a bare `:Cmd<CR>` or `<Cmd>Cmd<CR>` (ranges and command modifiers allowed). Callbacks, `<Plug>` chains, chained `<bar>` commands and shell escapes never attach.
- `altex` ships exactly one UI backend: `snacks.picker`.

## Considered Options

- Fuzzy matching of `desc` against command names, or `<Plug>` chain resolution: both produce confident wrong answers, which is worse than an empty key column.
- Multi-backend support (telescope, fzf-lua, mini.pick): each adapter is surface to keep working that adds nothing to the feature itself.

## Consequences

`snacks.picker` is a hard dependency and the plugin is unusable on a telescope/fzf-lua-only config. The join logic in `lua/altex/entries.lua` is UI-agnostic, so a second adapter is additive rather than a rewrite if that changes.
