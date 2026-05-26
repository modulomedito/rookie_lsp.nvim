local M = {}

function M.toggle_highlight_diagnostics()
    local bufnr = vim.api.nvim_get_current_buf()

    -- Toggle diagnostics
    local diagnostics_enabled = vim.diagnostic.is_enabled({ bufnr = bufnr })
    vim.diagnostic.enable(not diagnostics_enabled, { bufnr = bufnr })

    -- Toggle semantic tokens
    local semantic_enabled = false
    if vim.lsp.semantic_tokens and vim.lsp.semantic_tokens.is_enabled then
        semantic_enabled = vim.lsp.semantic_tokens.is_enabled({ bufnr = bufnr })
        vim.lsp.semantic_tokens.enable(not semantic_enabled, { bufnr = bufnr })
    else
        -- Fallback for older Neovim versions
        semantic_enabled = vim.b[bufnr].semantic_tokens_enabled == true
        local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients
        local clients = get_clients({ bufnr = bufnr })
        if semantic_enabled then
            for _, client in ipairs(clients) do
                if client.server_capabilities.semanticTokensProvider then
                    vim.lsp.semantic_tokens.stop(bufnr, client.id)
                end
            end
            vim.b[bufnr].semantic_tokens_enabled = false
        else
            for _, client in ipairs(clients) do
                if client.server_capabilities.semanticTokensProvider then
                    vim.lsp.semantic_tokens.start(bufnr, client.id)
                end
            end
            vim.b[bufnr].semantic_tokens_enabled = true
        end
    end

    local status = not diagnostics_enabled and "ON" or "OFF"
    print("LSP Highlights & Diagnostics: " .. status)
end

function M.stop_lsp(lsp_name)
    local clients = vim.lsp.get_clients({ name = lsp_name })
    for _, client in ipairs(clients) do
        client:stop()
    end
    print("Stopped " .. lsp_name)
end

function M.clean_undo_files()
    local undo_dir = vim.fn.expand(vim.o.undodir:split(",")[1])
    if vim.fn.isdirectory(undo_dir) == 0 then
        print("Undo directory not found: " .. undo_dir)
        return
    end

    local count = 0
    -- This is a bit aggressive but helps when files are corrupted
    local choice = vim.fn.confirm("Delete ALL undo files in " .. undo_dir .. "?", "&Yes\n&No", 2)
    if choice == 1 then
        local files = vim.fn.glob(undo_dir .. "/*", false, true)
        for _, file in ipairs(files) do
            vim.fn.delete(file)
            count = count + 1
        end
        print("Deleted " .. count .. " undo files.")
    end
end

function M.setup()
    -- Stop specific lsp
    vim.api.nvim_create_user_command("RkLspStop", function(opts)
        M.stop_lsp(opts.args)
    end, {
        nargs = 1,
        complete = function()
            local clients = vim.lsp.get_clients()
            local names = {}
            for _, client in ipairs(clients) do
                table.insert(names, client.name)
            end
            return names
        end,
        desc = "Stop a specific LSP client",
    })

    -- Clean undo files
    vim.api.nvim_create_user_command("RkLspCleanUndo", function()
        M.clean_undo_files()
    end, {
        desc = "Clean corrupted undo files in undodir",
    })
end

return M
