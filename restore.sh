#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
NVIM_CONFIG="$HOME/.config/nvim"
TMPINIT="$(mktemp /tmp/packer-bootstrap-XXXXXX.lua)"

echo "==> Restoring Neovim config from $REPO_DIR"

# ── 1. Restore config files ──
if [ ! -d "$REPO_DIR/config/nvim" ]; then
  echo "ERROR: No backup found at $REPO_DIR/config/nvim"
  echo "Run backup.sh on your source machine first."
  exit 1
fi

mkdir -p "$NVIM_CONFIG"
rsync -av --delete "$REPO_DIR/config/nvim/" "$NVIM_CONFIG/"
echo "==> Config restored to $NVIM_CONFIG"

# ── 2. Install Packer if missing ──
PACKER_DIR="$HOME/.local/share/nvim/site/pack/packer/start/packer.nvim"
if [ ! -d "$PACKER_DIR" ]; then
  echo "==> Installing Packer..."
  git clone --depth 1 https://github.com/wbthomason/packer.nvim "$PACKER_DIR"
else
  echo "==> Packer already installed"
fi

# ── 3. PackerSync with a minimal init (skips real init.lua) ──
# The real init.lua requires plugins that don't exist yet, so we
# write a temp init that ONLY runs the packer block.
cat > "$TMPINIT" <<'LUAEOF'
vim.cmd [[packadd packer.nvim]]
require('packer').startup(function(use)
  use 'wbthomason/packer.nvim'
  use 'marko-cerovac/material.nvim'
  use 'nvim-lualine/lualine.nvim'
  use 'nvim-lua/plenary.nvim'
  use 'nvim-telescope/telescope.nvim'
  use { 'nvim-treesitter/nvim-treesitter', run = ':TSUpdate' }
  use 'neovim/nvim-lspconfig'
  use 'williamboman/mason.nvim'
  use 'williamboman/mason-lspconfig.nvim'
  use 'hrsh7th/nvim-cmp'
  use 'hrsh7th/cmp-nvim-lsp'
  use 'L3MON4D3/LuaSnip'
  use 'saadparwaiz1/cmp_luasnip'
  use 'github/copilot.vim'
end)
vim.api.nvim_create_autocmd('User', {
  pattern = 'PackerComplete',
  callback = function() vim.cmd('quitall') end,
})
vim.cmd('PackerSync')
LUAEOF

echo "==> Installing plugins via PackerSync (this may take a minute)..."
nvim -u "$TMPINIT" --headless 2>&1 || true
rm -f "$TMPINIT"
echo "==> Plugins installed"

# ── 4. Install Treesitter parsers ──
# Now all plugins exist, so init.lua loads without errors.
if [ -f "$REPO_DIR/treesitter-parsers.txt" ]; then
  PARSERS=$(paste -sd' ' "$REPO_DIR/treesitter-parsers.txt")
  echo "==> Installing Treesitter parsers: $PARSERS"
  nvim --headless -c "TSInstallSync $PARSERS" -c 'quitall' 2>&1 || true
  echo "==> Treesitter parsers installed"
fi

# ── 5. Install Mason packages ──
if [ -f "$REPO_DIR/mason-packages.txt" ]; then
  PKGS=$(paste -sd' ' "$REPO_DIR/mason-packages.txt")
  echo "==> Installing Mason packages: $PKGS"
  nvim --headless -c "MasonInstall $PKGS" -c 'sleep 60' -c 'quitall' 2>&1 || true
  echo "==> Mason packages installed"
fi

echo ""
echo "==> Restore complete!"
echo "    Start nvim and verify everything works."
echo "    If any Mason package failed, run :Mason inside nvim to install manually."
