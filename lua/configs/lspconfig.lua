-- load defaults i.e lua_lsp
require("nvchad.configs.lspconfig").defaults()

local lspconfig = require "lspconfig"

-- EXAMPLE
local servers = {
  "html",
  "cssls",
  "ts_ls",
  "astro",
  "gopls",
  "tailwindcss",
  "eslint",
  "clangd",
  "prismals",
  "arduino-language-server",
}
local nvlsp = require "nvchad.configs.lspconfig"

-- lsps with default config
for _, lsp in ipairs(servers) do
  lspconfig[lsp].setup {
    on_attach = nvlsp.on_attach,
    on_init = nvlsp.on_init,
    capabilities = nvlsp.capabilities,
  }
end

-- configuring single server, example: typescript
lspconfig.ts_ls.setup {
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = nvlsp.capabilities,

  lspconfig.arduino_language_server.setup {
    cmd = {
      "arduino-language-server",
      "-cli-config",
      "~/.arduino15/arduino-cli.yaml",
      "-fqbn",
      "arduino:avr:uno", -- ganti sesuai board yang kamu pakai
      "-cli",
      "arduino-cli",
      "-clangd",
      "clangd",
    },
    on_attach = nvlsp.on_attach,
    on_init = nvlsp.on_init,
    capabilities = nvlsp.capabilities,
  },
}
