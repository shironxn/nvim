# nvim

Personal Neovim configuration based on modern **Kickstart.nvim**, focused on speed, transparency, and a clean workflow.

## Stack & Features

- **Plugin Manager:** [`lazy.nvim`](https://github.com/folke/lazy.nvim)
- **Completion & Snippets:** [`blink.cmp`](https://github.com/saghen/blink.cmp) + [`LuaSnip`](https://github.com/L3MON4D3/LuaSnip) + [`friendly-snippets`](https://github.com/rafamadriz/friendly-snippets)
- **LSP & Tooling:** Built-in Neovim LSP + [`mason.nvim`](https://github.com/williamboman/mason.nvim) (TS/JS, Python, C/C++, Bash, JSON, Lua)
- **Formatting:** [`conform.nvim`](https://github.com/stevearc/conform.nvim) (`prettierd`, `stylua`)
- **Fuzzy Finder:** [`telescope.nvim`](https://github.com/nvim-telescope/telescope.nvim)
- **Syntax Highlighting:** [`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter)
- **File Explorer:** [`nvim-tree.lua`](https://github.com/nvim-tree/nvim-tree.lua)
- **Git Integration:** [`gitsigns.nvim`](https://github.com/lewis6991/gitsigns.nvim) with inline blame & hunk navigation
- **AI Completion:** [`supermaven-nvim`](https://github.com/supermaven-inc/supermaven-nvim)
- **Time Tracking:** [`vim-wakatime`](https://github.com/wakatime/vim-wakatime)
- **Theme:** Dynamic Pywal (`~/.cache/wal/colors.json`) with seamless terminal background

## Essential Keymaps

Leader key is set to `<Space>`.

### General & Navigation
- `<leader>e` : Toggle file tree explorer
- `<C-s>` : Save file
- `<S-h>` / `<S-l>` : Previous / Next buffer
- `<leader>bd` : Delete current buffer

### Find & Search (Telescope)
- `<leader>ff` : Find files
- `<leader>fg` : Live grep text
- `<leader>fb` : Existing buffers
- `<leader>fr` : Recent files

### Git
- `<leader>gs` : Git status
- `<leader>gc` : Git commits
- `<leader>gb` : Git branches
- `]c` / `[c` : Next / Previous git change
- `<leader>hp` : Preview hunk
- `<leader>hs` / `<leader>hr` : Stage / Reset hunk

### LSP & Code
- `grd` : Goto definition
- `grr` : References
- `gri` : Implementation
- `grn` : Rename symbol
- `gra` : Code action
- `<leader>f` : Format buffer
