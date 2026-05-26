local M = {}

function M.setup(opts)
    opts = opts or {}

    -- Global variable to control enabling LSP
    if vim.g.rookie_toys_lsp_enable == false then
        return
    end

    -- 1. Setup Commands & Keymaps
    require("rookie_lsp.commands").setup()
    require("rookie_lsp.keymaps").setup()

    -- Globally suppress clangd -32602 errors for documentHighlight
    local orig_highlight_handler = vim.lsp.handlers["textDocument/documentHighlight"]
    vim.lsp.handlers["textDocument/documentHighlight"] = function(err, result, ctx, config)
        if err and err.code == -32602 then
            return
        end
        if orig_highlight_handler then
            return orig_highlight_handler(err, result, ctx, config)
        end
        return vim.lsp.with(vim.lsp.handlers.document_highlight, {})(err, result, ctx, config)
    end

    -- Globally suppress E824 (Incompatible undo file) for jump-to-definition methods
    -- This happens when jumping to a file that has a stale/corrupt undo file in the undo directory.
    local jump_methods = {
        "textDocument/definition",
        "textDocument/typeDefinition",
        "textDocument/implementation",
        "textDocument/declaration",
    }

    for _, method in ipairs(jump_methods) do
        vim.lsp.handlers[method] = function(err, result, ctx, config)
            if err then
                vim.notify(err.message, vim.log.levels.ERROR)
                return
            end
            if result == nil or vim.tbl_isempty(result) then
                vim.notify("rookie_lsp: No location found.", vim.log.levels.INFO)
                return
            end

            -- Ensure result is a list
            if not vim.islist(result) then
                result = { result }
            end

            local client = vim.lsp.get_client_by_id(ctx.client_id)
            if not client then
                return
            end

            local offset_encoding = client.offset_encoding

            if #result == 1 then
                -- Safely jump to the first location by turning off undofile temporarily around the edit command
                local item = result[1]
                local uri = item.uri or item.targetUri
                if not uri then return end

                local bufnr = vim.uri_to_bufnr(uri)
                vim.fn.bufload(bufnr)

                -- The crucial part: jump manually without using `cfirst` which triggers the strict undo checks
                local range = item.range or item.targetSelectionRange
                local row = range.start.line + 1
                local col = vim.lsp.util._get_line_byte_from_position(bufnr, range.start, offset_encoding)

                local orig_undo = vim.o.undofile
                vim.o.undofile = false

                -- Use pcall to catch E824 if it still somehow happens during buffer switch
                pcall(function()
                    vim.cmd("buffer " .. bufnr)
                    vim.api.nvim_win_set_cursor(0, { row, col })
                    -- Push to jumplist
                    vim.cmd("normal! m'")
                end)

                vim.o.undofile = orig_undo
            else
                -- Multiple results, fallback to standard behavior but try to catch errors
                local title = "LSP locations"
                local items = vim.lsp.util.locations_to_items(result, offset_encoding)

                local orig_undo = vim.o.undofile
                vim.o.undofile = false

                pcall(function()
                    vim.fn.setqflist({}, " ", { title = title, items = items })
                    vim.cmd("cfirst")
                end)

                vim.o.undofile = orig_undo
            end
        end
    end

    -- 2. Define Servers
    local servers = {
        stylua = {},
        clangd = {
            cmd = {
                "clangd",
                "--background-index",
                "--clang-tidy",
                "--header-insertion=iwyu",
                "--completion-style=detailed",
                "--function-arg-placeholders",
                "--fallback-style=llvm",
            },
            init_options = {
                usePlaceholders = true,
                completeUnimported = true,
                clangdFileStatus = true,
            },
        },
        pyright = {},
        rust_analyzer = {},
        jsonls = {},
        marksman = {},
        lua_ls = {
            on_init = function(client)
                if client.workspace_folders then
                    local path = client.workspace_folders[1].name
                    if
                        path ~= vim.fn.stdpath("config")
                        and (
                            vim.uv.fs_stat(path .. "/.luarc.json")
                            or vim.uv.fs_stat(path .. "/.luarc.jsonc")
                        )
                    then
                        return
                    end
                end
                client.config.settings.Lua =
                    vim.tbl_deep_extend("force", client.config.settings.Lua, {
                        runtime = {
                            version = "LuaJIT",
                            path = { "lua/?.lua", "lua/?/init.lua" },
                        },
                        workspace = {
                            checkThirdParty = false,
                            library = vim.tbl_extend(
                                "force",
                                vim.api.nvim_get_runtime_file("", true),
                                { "${3rd}/luv/library", "${3rd}/busted/library" }
                            ),
                        },
                    })
            end,
            settings = {
                Lua = {},
            },
        },
    }

    -- 3. Mason Setup
    local has_mason, mason = pcall(require, "mason")
    if has_mason then
        mason.setup(opts.mason or {})
    end

    local has_mason_tool, mason_tool = pcall(require, "mason-tool-installer")
    if has_mason_tool then
        local ensure_installed = vim.tbl_keys(servers or {})
        mason_tool.setup({
            ensure_installed = ensure_installed,
        })
    end

    -- 4. Diagnostic Config
    vim.diagnostic.config({
        update_in_insert = false,
        severity_sort = true,
        float = { border = "rounded", source = "if_many" },
        underline = { severity = { min = vim.diagnostic.severity.WARN } },
        virtual_text = true,
        virtual_lines = false,
        jump = {
            on_jump = function(_, bufnr)
                vim.diagnostic.open_float({
                    bufnr = bufnr,
                    scope = "cursor",
                    focus = false,
                })
            end,
        },
    })

    -- 5. LspAttach Autocmd
    vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("RookieLspConfig", { clear = true }),
        callback = function(ev)
            local client = vim.lsp.get_client_by_id(ev.data.client_id)
            local bufnr = ev.buf

            -- Disable diagnostics by default for this buffer (from lspcfg2.lua)
            vim.diagnostic.enable(false, { bufnr = bufnr })

            -- Disable semantic tokens by default for this buffer (from lspcfg2.lua)
            vim.schedule(function()
                if not vim.api.nvim_buf_is_valid(bufnr) then
                    return
                end
                if vim.lsp.semantic_tokens and vim.lsp.semantic_tokens.enable then
                    vim.lsp.semantic_tokens.enable(false, { bufnr = bufnr })
                else
                    if client and client.server_capabilities.semanticTokensProvider then
                        vim.lsp.semantic_tokens.stop(bufnr, client.id)
                    end
                end
                vim.b[bufnr].semantic_tokens_enabled = false
            end)

            -- Keymaps
            require("rookie_lsp.keymaps").on_attach(client, bufnr)

            -- Highlighting
            if client and client:supports_method("textDocument/documentHighlight", bufnr) then
                local highlight_augroup =
                    vim.api.nvim_create_augroup("rookie-lsp-highlight", { clear = false })
                vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
                    buffer = bufnr,
                    group = highlight_augroup,
                    callback = vim.lsp.buf.document_highlight,
                })

                vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
                    buffer = bufnr,
                    group = highlight_augroup,
                    callback = vim.lsp.buf.clear_references,
                })

                vim.api.nvim_create_autocmd("LspDetach", {
                    group = vim.api.nvim_create_augroup("rookie-lsp-detach", { clear = true }),
                    callback = function(ev2)
                        vim.lsp.buf.clear_references()
                        vim.api.nvim_clear_autocmds({
                            group = "rookie-lsp-highlight",
                            buffer = ev2.buf,
                        })
                    end,
                })
            end
        end,
    })

    -- 6. Enable Servers
    if vim.lsp.config then
        -- Neovim 0.11+ style
        for name, config in pairs(servers) do
            vim.lsp.config(name, config)
            vim.lsp.enable(name)
        end
    else
        -- Fallback for older Neovim versions using nvim-lspconfig
        local has_lspconfig, lspconfig = pcall(require, "lspconfig")
        if has_lspconfig then
            for name, config in pairs(servers) do
                lspconfig[name].setup(config)
            end
        end
    end
end

return M
