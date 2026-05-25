# rookie_lsp.nvim

A modular LSP configuration plugin for Neovim.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "modulomedito/rookie_lsp.nvim", -- Replace with actual repo path if needed
    dependencies = {
        "neovim/nvim-lspconfig",
        {
            "williamboman/mason.nvim",
            opts = {},
        },
        "williamboman/mason-lspconfig.nvim",
        "WhoIsSethDaniel/mason-tool-installer.nvim",
        {
            "j-hui/fidget.nvim",
            opts = {},
        },
        -- Optional: for formatting
        "stevearc/conform.nvim",
    },
    config = function()
        require("rookie_lsp").setup()
    end,
}
```

## Features

- **Automatic Server Installation**: Uses Mason to manage LSP servers.
- **Optimized for Neovim 0.11+**: Supports the new `vim.lsp.config` and `vim.lsp.enable` APIs while maintaining backward compatibility with `nvim-lspconfig`.
- **Toggleable Diagnostics**: Use `<leader>hld` to toggle semantic highlighting and diagnostics.
- **Smart Highlighting**: Automatically highlights references under the cursor.
- **Custom Commands**:
    - `RkLspStop <name>`: Stop a specific LSP client.

## Keymaps

- `gd`: Goto definition
- `gr`: Goto references
- `gh`: Hover documentation
- `gi`: Goto implementation
- `<leader>rn`: Rename symbol
- `<leader>ca`: Code action
- `<leader>f`: Format buffer
- `<leader>hld`: Toggle diagnostics & semantic tokens
- `<leader>th`: Toggle inlay hints
