-- ─────────────────────────────────────────────
-- PLUGINS
-- ─────────────────────────────────────────────
require('packer').startup(function(use)
  use 'wbthomason/packer.nvim'

  -- UI/Theme
  use 'marko-cerovac/material.nvim'
  use 'nvim-lualine/lualine.nvim'

  -- Telescope + deps
  use 'nvim-lua/plenary.nvim'
  use 'nvim-telescope/telescope.nvim'

  -- Treesitter
  use { 'nvim-treesitter/nvim-treesitter', run = ':TSUpdate' }

  -- LSP plumbing
  use 'neovim/nvim-lspconfig'

  -- Mason (binaries)
  use 'williamboman/mason.nvim'
  use 'williamboman/mason-lspconfig.nvim'

  -- Completion
  use 'hrsh7th/nvim-cmp'
  use 'hrsh7th/cmp-nvim-lsp'
  use 'L3MON4D3/LuaSnip'
  use 'saadparwaiz1/cmp_luasnip'

  -- Extras
  use 'github/copilot.vim'
end)

-- ─────────────────────────────────────────────
-- BASIC UX
-- ─────────────────────────────────────────────
vim.o.completeopt = 'menuone,noselect'
require('lualine').setup { options = { theme = 'material' } }
vim.cmd('colorscheme material-palenight')

-- Treesitter: enable highlighting for all buffers
vim.api.nvim_create_autocmd('FileType', {
  callback = function()
    pcall(vim.treesitter.start)
  end,
})

-- Completion
local cmp = require('cmp')
cmp.setup({
  snippet = { expand = function(args) require('luasnip').lsp_expand(args.body) end },
  mapping = {
    ['<C-n>']     = cmp.mapping.select_next_item(),
    ['<C-p>']     = cmp.mapping.select_prev_item(),
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<CR>']      = cmp.mapping.confirm({ select = true }),
  },
  sources = { { name = 'nvim_lsp' }, { name = 'luasnip' } },
})

-- ─────────────────────────────────────────────
-- MASON (no jdtls here)
-- ─────────────────────────────────────────────
require('mason').setup()
require('mason-lspconfig').setup({
  ensure_installed = { 'pyright','ts_ls','rust_analyzer','gopls' }, -- clangd uses system package (Mason unsupported on aarch64)
  automatic_installation = false,
  automatic_enable = false,
})

-- ─────────────────────────────────────────────
-- LSP (Neovim 0.11 style: vim.lsp.config + vim.lsp.start)
-- ─────────────────────────────────────────────
local C = vim.lsp.config
local capabilities = require('cmp_nvim_lsp').default_capabilities()

local function with(overrides, base)
  return vim.tbl_deep_extend('force', {}, base or {}, overrides or {})
end

local function root_pattern(...)
  local pats = { ... }
  return function(startpath)
    local f = vim.fs.find(pats, { path = startpath or vim.api.nvim_buf_get_name(0), upward = true })[1]
    return f and vim.fs.dirname(f) or vim.fn.getcwd()
  end
end

local function start(cfg)
  vim.lsp.start(cfg)
end

-- Python
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'python',
  callback = function()
    start(with({ capabilities = capabilities }, C.pyright))
  end,
})

-- C/C++
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'c','cpp','objc','objcpp' },
  callback = function()
    start(with({ capabilities = capabilities }, C.clangd))
  end,
})

-- TypeScript / JavaScript (tsserver is ts_ls)
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'typescript','typescriptreact','typescript.tsx','javascript','javascriptreact','javascript.jsx' },
  callback = function()
    start(with({ capabilities = capabilities }, C.ts_ls))
  end,
})

-- Rust
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'rust',
  callback = function(args)
    start(with({
      capabilities = capabilities,
      root_dir = root_pattern('Cargo.toml', '.git')(vim.api.nvim_buf_get_name(args.buf)),
      settings = { ['rust-analyzer'] = { cargo = { allFeatures = true }, check = { command = 'clippy' } } },
    }, C.rust_analyzer))
  end,
})

-- Go
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'go','gomod','gowork','gotmpl' },
  callback = function(args)
    start(with({
      capabilities = capabilities,
      root_dir = root_pattern('go.work', 'go.mod', '.git')(vim.api.nvim_buf_get_name(args.buf)),
      settings = { gopls = { analyses = { unusedparams = true }, staticcheck = true } },
    }, C.gopls))
  end,
})

-- Java
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'java',
  callback = function(args)
    start({
      name = 'jdtls',
      cmd = {
        '/home/ubuntu/.local/share/nvim/mason/bin/jdtls',
        '--java-executable', '/usr/lib/jvm/java-21-openjdk-arm64/bin/java',
      },
      root_dir = root_pattern('pom.xml', 'gradlew', 'mvnw', '.git')(vim.api.nvim_buf_get_name(args.buf)),
      capabilities = capabilities,
    })
  end,
})

