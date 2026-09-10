# altex

A Neovim plugin that lists every command and mapping discoverable at runtime, joins commands to the mappings that invoke them, and answers "what does this key sequence do?" — with no registration step. (Name provisional, see naming question.)

## Language

**Mapping**:
A key sequence bound in one or more modes to either a string rhs or a Lua callback.
_Avoid_: keybind, keybinding, shortcut, hotkey

**Key sequence**:
The left-hand side of a mapping: what the user presses, such as `gd` or `<leader>ff`.
_Avoid_: keybind, keystroke, chord

**Command**:
Anything invocable as `:Name`: a user command, a plugin command, or a builtin ex-command.
_Avoid_: action, ex-command (precise only for the builtin case)

**Entry**:
One row in the list. Either a **command entry** (a command, with zero or more mappings attached) or a **mapping entry** (a mapping that is its own action, because nothing in its rhs names a command).
_Avoid_: item, result, match

**Mapping entry**:
A mapping that is its own action rather than an invocation of a command: a Lua callback, `<Nop>`, or any rhs that does not parse to a command name.
_Avoid_: callback entry, anonymous mapping

**Attached mapping**:
A mapping whose rhs invokes a command entry's command. Only a string rhs can attach; a callback mapping is never an attached mapping.
_Avoid_: keybind, bound key

**Describe**:
The key-sequence → entry direction: given a key sequence, report the mapping it resolves to, or report that it is a prefix of others.
_Avoid_: lookup, resolve

**Discovery**:
Building the index from Neovim runtime state only. The plugin never asks the user to declare keymaps or commands.
_Avoid_: registration, sync, ETL
