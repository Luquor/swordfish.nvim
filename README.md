# swordfish.nvim

Toggle native Neovim strikethrough annotations without changing buffer text.

Swordfish uses extmarks and the UI-native `strikethrough` highlight attribute.
The annotation follows its text as the buffer changes, and works with normal,
visual-line, visual-character, and visual-block selections.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "luquor/swordfish.nvim",
  opts = {},
}
```

The default mapping is `<leader>co` (`co` means “cross off”):

- Normal mode: toggle the current line
- Visual mode: toggle the selected text

When a selection contains any struck text, the complete selection is converted
to normal text. Buffer contents are never rewritten.

## Commands

```vim
:SwordfishStrike
:SwordfishUnstrike
:SwordfishStrikeSelected
:SwordfishUnstrikeSelected
:SwordfishWrite [file]
```

`SwordfishStrike` and `SwordfishUnstrike` operate on the current line. The
selected commands use the last visual selection, including visual-block
selections, so they also work when entered after pressing `:` from visual mode.

`SwordfishWrite` writes a text version to a file without changing the buffer.
It uses the combining long stroke overlay (`U+0336`) used by the original ASCII
style implementation. Use `:SwordfishWrite! file` to overwrite an existing file.

## Configuration

```lua
require("swordfish").setup({
  highlight = "SwordfishStrikeThrough",
  highlight_opts = {
    -- Additional highlight attributes can be added here.
    fg = "#888888",
  },
  commands = true,
  keymaps = {
    normal = "<leader>co",
    visual = "<leader>co",
  },
})
```

Set `keymaps = false` to disable the default mappings. Set `commands = false`
to disable the commands above.

The Lua API is available for custom mappings:

```lua
local swordfish = require("swordfish")

vim.keymap.set("n", "<leader>x", swordfish.toggle_line, {
  desc = "Toggle strikethrough",
})
vim.keymap.set("x", "<leader>x", swordfish.toggle_visual, {
  desc = "Toggle strikethrough",
})
```

## License

Apache-2.0. See [LICENSE](LICENSE).
