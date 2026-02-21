#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
NVIM_CONFIG="$HOME/.config/nvim"

echo "==> Backing up Neovim config to $REPO_DIR"

# ── Config files ──
mkdir -p "$REPO_DIR/config/nvim"
rsync -av --delete \
  --exclude '.git' \
  "$NVIM_CONFIG/" "$REPO_DIR/config/nvim/"

# ── Mason package list (so restore can reinstall them) ──
MASON_PKG_DIR="$HOME/.local/share/nvim/mason/packages"
if [ -d "$MASON_PKG_DIR" ]; then
  ls -1 "$MASON_PKG_DIR" > "$REPO_DIR/mason-packages.txt"
  echo "==> Saved Mason package list ($(wc -l < "$REPO_DIR/mason-packages.txt") packages)"
else
  echo "==> No Mason packages directory found, skipping"
fi

# ── Treesitter installed parsers list ──
# New nvim-treesitter installs parsers to site/parser/, old versions used plugin dir
TS_PARSER_DIR="$HOME/.local/share/nvim/site/parser"
if [ ! -d "$TS_PARSER_DIR" ]; then
  TS_PARSER_DIR="$HOME/.local/share/nvim/site/pack/packer/start/nvim-treesitter/parser"
fi
if [ -d "$TS_PARSER_DIR" ] && [ "$(ls -1 "$TS_PARSER_DIR" 2>/dev/null | wc -l)" -gt 0 ]; then
  ls -1 "$TS_PARSER_DIR" | sed 's/\.so$//' > "$REPO_DIR/treesitter-parsers.txt"
  echo "==> Saved Treesitter parser list ($(wc -l < "$REPO_DIR/treesitter-parsers.txt") parsers)"
else
  echo "==> No Treesitter parsers found, skipping"
fi

echo "==> Backup complete. Review changes with: git -C '$REPO_DIR' diff"
