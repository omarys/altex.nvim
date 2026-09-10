# The row is the action, not the mapping

A list row is either a **command entry** (a command, with zero or more mappings attached) or a **mapping entry** (a mapping that is its own action). A mapping-centric list was rejected because it loses commands with no key bound to them, which is half the point; a single unified row type was rejected because Neovim gives no common identity to join on — a Lua-callback mapping has no `rhs` at all, so there is nothing to attach it to.

## Considered Options

- Command entries only: loses callback mappings, which are most of a modern config.
- Mapping entries only: loses unmapped commands.
- One flattened "action" type: nothing in `nvim_get_keymap`/`nvim_get_commands` supports the abstraction.

## Consequences

The join is one-directional. A mapping attaches to a command only when its string rhs names one (the join rule is ADR 0002), and a callback mapping can never acquire a command. Commands whose mappings are all callbacks therefore render with no key sequence. That is the honest answer, not a gap to paper over.
