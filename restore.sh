#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
NVIM_CONFIG="$HOME/.config/nvim"
PLUGIN_DIR="$HOME/.local/share/nvim/site/pack/packer/start"
TMPINIT="$(mktemp /tmp/nvim-restore-XXXXXX.lua)"
trap 'rm -f "$TMPINIT"' EXIT

echo "==> Restoring Neovim config from $REPO_DIR"

# ── 0. Check / install prerequisites ──
missing=()
command -v nvim  >/dev/null 2>&1 || missing+=("neovim")
command -v git   >/dev/null 2>&1 || missing+=("git")
command -v rsync >/dev/null 2>&1 || missing+=("rsync")
command -v cc    >/dev/null 2>&1 || missing+=("build-essential")
command -v node  >/dev/null 2>&1 || missing+=("nodejs npm")
command -v cmake >/dev/null 2>&1 || missing+=("cmake")
command -v pip3  >/dev/null 2>&1 || missing+=("python3-pip")
command -v python3 >/dev/null 2>&1 || missing+=("python3-dev python3-venv")
command -v java  >/dev/null 2>&1 || missing+=("openjdk-21-jdk")
command -v go    >/dev/null 2>&1 || missing+=("golang-go")
command -v lua   >/dev/null 2>&1 || missing+=("lua5.4 liblua5.4-dev luarocks")
command -v clangd >/dev/null 2>&1 || missing+=("clangd")
command -v unzip >/dev/null 2>&1 || missing+=("unzip")
command -v rg    >/dev/null 2>&1 || missing+=("ripgrep")

if [ ${#missing[@]} -gt 0 ]; then
  echo "==> Missing packages: ${missing[*]}"
  echo "    Installing via apt..."
  sudo apt-get update -qq && sudo apt-get install -y -qq ${missing[*]}
fi

# Rust (needed for rust-analyzer LSP)
if ! command -v rustc >/dev/null 2>&1; then
  echo "==> Installing Rust via rustup..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y 2>&1
  # shellcheck disable=SC1091
  . "$HOME/.cargo/env"
fi

# tree-sitter CLI is needed by nvim-treesitter to compile parsers
if ! command -v tree-sitter >/dev/null 2>&1; then
  echo "==> Installing tree-sitter CLI..."
  npm install -g tree-sitter-cli 2>&1
fi

# ── 1. Restore config files ──
if [ ! -d "$REPO_DIR/config/nvim" ]; then
  echo "ERROR: No backup found at $REPO_DIR/config/nvim"
  echo "Run backup.sh on your source machine first."
  exit 1
fi

mkdir -p "$NVIM_CONFIG"
rsync -av --delete "$REPO_DIR/config/nvim/" "$NVIM_CONFIG/"
echo "==> Config restored to $NVIM_CONFIG"

# ── 2. Clone all plugins directly ──
declare -A PLUGINS=(
  [packer.nvim]="wbthomason/packer.nvim"
  [material.nvim]="marko-cerovac/material.nvim"
  [lualine.nvim]="nvim-lualine/lualine.nvim"
  [plenary.nvim]="nvim-lua/plenary.nvim"
  [telescope.nvim]="nvim-telescope/telescope.nvim"
  [nvim-treesitter]="nvim-treesitter/nvim-treesitter"
  [nvim-lspconfig]="neovim/nvim-lspconfig"
  [mason.nvim]="williamboman/mason.nvim"
  [mason-lspconfig.nvim]="williamboman/mason-lspconfig.nvim"
  [nvim-cmp]="hrsh7th/nvim-cmp"
  [cmp-nvim-lsp]="hrsh7th/cmp-nvim-lsp"
  [LuaSnip]="L3MON4D3/LuaSnip"
  [cmp_luasnip]="saadparwaiz1/cmp_luasnip"
  [copilot.vim]="github/copilot.vim"
)

mkdir -p "$PLUGIN_DIR"
echo "==> Installing plugins..."
for name in "${!PLUGINS[@]}"; do
  repo="${PLUGINS[$name]}"
  target="$PLUGIN_DIR/$name"
  if [ -d "$target" ]; then
    echo "    $name — already installed"
  else
    echo "    $name — cloning..."
    git clone --depth 1 "https://github.com/$repo.git" "$target" 2>&1
  fi
done
echo "==> All plugins installed"

# ── 3. Generate packer_compiled.lua ──
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
LUAEOF
echo "==> Compiling packer..."
nvim -u "$TMPINIT" --headless -c 'PackerCompile' -c 'quitall' 2>&1 || true

# ── 4. Install Treesitter parsers ──
if [ -f "$REPO_DIR/treesitter-parsers.txt" ]; then
  PARSERS=$(paste -sd' ' "$REPO_DIR/treesitter-parsers.txt")
  echo "==> Installing Treesitter parsers: $PARSERS"
  echo "" > "$TMPINIT"
  nvim -u "$TMPINIT" --headless -c "TSInstall $PARSERS" -c 'sleep 60' -c 'quitall' 2>&1 || true
  echo "==> Treesitter parsers installed"
fi

# ── 5. Install Mason packages ──
if [ -f "$REPO_DIR/mason-packages.txt" ]; then
  PKGS=$(paste -sd' ' "$REPO_DIR/mason-packages.txt")
  cat > "$TMPINIT" <<'LUAEOF'
require('mason').setup()
LUAEOF
  echo "==> Installing Mason packages: $PKGS"
  nvim -u "$TMPINIT" --headless -c "MasonInstall $PKGS" -c 'sleep 120' -c 'quitall' 2>&1 || true
  echo "==> Mason packages installed"
fi

echo ""
echo "==> Restore complete!"
echo "    Start nvim and verify everything works."
echo "    If any Mason package failed, run :Mason inside nvim to install manually."
