local M = {}

---@class InternalRoslynNvimConfig
---@field filewatching "auto" | "off" | "roslyn"
---@field exe string[]
---@field args string[]
---@field config vim.lsp.ClientConfig
---@field choose_sln? fun(solutions: string[]): string?
---@field ignore_sln? fun(solution: string): boolean
---@field choose_target? fun(targets: string[]): string?
---@field ignore_target? fun(target: string): boolean
---@field broad_search boolean
---@field lock_target boolean

---@class RoslynNvimConfig
---@field filewatching? boolean | "auto" | "off" | "roslyn"
---@field exe? string|string[]
---@field args? string[]
---@field config? vim.lsp.ClientConfig
---@field choose_sln? fun(solutions: string[]): string?
---@field ignore_sln? fun(solution: string): boolean
---@field choose_target? fun(targets: string[]): string?
---@field ignore_target? fun(target: string): boolean
---@field broad_search? boolean
---@field lock_target? boolean

local sysname = vim.uv.os_uname().sysname:lower()
local iswin = not not (sysname:find("windows") or sysname:find("mingw"))

---@return lsp.ClientCapabilities
local function default_capabilities()
    local cmp_ok, cmp = pcall(require, "cmp_nvim_lsp")
    local blink_ok, blink = pcall(require, "blink.cmp")
    local default = vim.lsp.protocol.make_client_capabilities()
    return cmp_ok and vim.tbl_deep_extend("force", default, cmp.default_capabilities())
        or blink_ok and vim.tbl_deep_extend("force", default, blink.get_lsp_capabilities())
        or default
end

---@return string[]
local function default_exe()
    local data = vim.fn.stdpath("data") --[[@as string]]

    local mason_path = vim.fs.joinpath(data, "mason", "bin", "roslyn")
    local mason_installation = iswin and string.format("%s.cmd", mason_path) or mason_path

    if vim.uv.fs_stat(mason_installation) ~= nil then
        return { mason_installation }
    else
        return { "dotnet", vim.fs.joinpath(data, "roslyn", "Microsoft.CodeAnalysis.LanguageServer.dll") }
    end
end

---@type InternalRoslynNvimConfig
local roslyn_config = {
    filewatching = "auto",
    exe = default_exe(),
    args = {
        "--logLevel=Information",
        "--extensionLogDirectory=" .. vim.fs.dirname(vim.lsp.get_log_path()),
        "--stdio",
    },
    ---@diagnostic disable-next-line: missing-fields
    config = {
        capabilities = default_capabilities(),
    },
    choose_sln = nil,
    ignore_sln = nil,
    choose_target = nil,
    ignore_target = nil,
    broad_search = false,
    lock_target = false,
}

function M.get()
    return roslyn_config
end

---@param user_config? RoslynNvimConfig
---@return InternalRoslynNvimConfig
function M.setup(user_config)
    roslyn_config = vim.tbl_deep_extend("force", roslyn_config, user_config or {})
    roslyn_config.exe = type(roslyn_config.exe) == "string" and { roslyn_config.exe } or roslyn_config.exe

    -- HACK: Enable filewatching to later just not watch any files
    -- This is to not make the server watch files and make everything super slow in certain situations
    if roslyn_config.filewatching == "off" or roslyn_config.filewatching == "roslyn" then
        roslyn_config.config.capabilities = vim.tbl_deep_extend("force", roslyn_config.config.capabilities, {
            workspace = {
                didChangeWatchedFiles = {
                    dynamicRegistration = roslyn_config.filewatching == "off",
                },
            },
        })
    end

    -- HACK: Doesn't show any diagnostics if we do not set this to true
    roslyn_config.config.capabilities = vim.tbl_deep_extend("force", roslyn_config.config.capabilities, {
        textDocument = {
            diagnostic = {
                dynamicRegistration = true,
            },
        },
    })

    return roslyn_config
end

return M
