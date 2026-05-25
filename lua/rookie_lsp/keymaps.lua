local M = {}

function M.setup()
    -- Global mappings
    vim.keymap.set(
        "n",
        "<leader>e",
        vim.diagnostic.open_float,
        { desc = "LSP: Show diagnostic error" }
    )
    vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "LSP: Goto previous diagnostic" })
    vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "LSP: Goto next diagnostic" })
    vim.keymap.set(
        "n",
        "<leader>q",
        vim.diagnostic.setloclist,
        { desc = "LSP: Set diagnostic location list" }
    )

    -- Toggle semantic highlight and diagnostics
    vim.keymap.set("n", "<leader>hld", function()
        require("rookie_lsp.commands").toggle_highlight_diagnostics()
    end, {
        desc = "Toggle [h]igh[l]ighting semantic & [d]iagnostics",
        silent = true,
    })
end

function M.on_attach(client, bufnr)
    local map = function(keys, func, desc, mode)
        mode = mode or "n"
        vim.keymap.set(mode, keys, func, {
            buffer = bufnr,
            desc = "LSP: " .. desc,
        })
    end

    -- From lspcfg.lua
    map("grn", vim.lsp.buf.rename, "[R]e[n]ame")
    map("gra", vim.lsp.buf.code_action, "[G]oto Code [A]ction", { "n", "x" })
    map("grD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")

    -- From lspcfg2.lua (adding unique ones or alternatives)
    map("gD", vim.lsp.buf.declaration, "Goto [D]eclaration")
    map("gd", vim.lsp.buf.definition, "Goto [d]efinition")
    map("gh", vim.lsp.buf.hover, "[H]over documentation")
    map("gi", vim.lsp.buf.implementation, "Goto [i]mplementation")
    map("gS", vim.lsp.buf.signature_help, "[S]ignature help")
    map("<leader>wa", vim.lsp.buf.add_workspace_folder, "Workspace [A]dd folder")
    map("<leader>wr", vim.lsp.buf.remove_workspace_folder, "Workspace [R]emove folder")
    map("<leader>wl", function()
        print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, "Workspace [L]ist folders")
    map("<leader>D", vim.lsp.buf.type_definition, "Type [D]efinition")
    map("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame symbol")
    map("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction", { "n", "v" })
    map("gr", vim.lsp.buf.references, "[G]oto [R]eferences")

    map("<leader>f", function()
        local ok, conform = pcall(require, "conform")
        if ok then
            conform.format({ lsp_fallback = true, async = true })
        else
            vim.lsp.buf.format({ async = true })
        end
    end, "Format buffer")

    if client and client:supports_method("textDocument/inlayHint", bufnr) then
        map("<leader>th", function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }))
        end, "[T]oggle Inlay [H]ints")
    end
end

return M
