#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
NVIM_CONFIG="$HOME/.config/nvim"

echo "==> Restoring Neovim config from $REPO_DIR"

# ── Restore config files ──
if [ ! -d "$REPO_DIR/config/nvim" ]; then
  echo "ERROR: No backup found at $REPO_DIR/config/nvim"
  echo "Run backup.sh on your source machine first."
  exit 1
fi

mkdir -p "$NVIM_CONFIG"
rsync -av --delete \
  "$REPO_DIR/config/nvim/" "$NVIM_CONFIG/"
echo "==> Config restored to $NVIM_CONFIG"

# ── Install Packer if missing ──
PACKER_DIR="$HOME/.local/share/nvim/site/pack/packer/start/packer.nvim"
if [ ! -d "$PACKER_DIR" ]; then
  echo "==> Installing Packer..."
  git clone --depth 1 https://github.com/wbthomason/packer.nvim "$PACKER_DIR"
else
  echo "==> Packer already installed"
fi

# ── Sync plugins via Packer (headless) ──
echo "==> Installing plugins via PackerSync..."
nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync' 2>&1 || true
echo "==> Plugins installed"

# ── Install Mason packages ──
if [ -f "$REPO_DIR/mason-packages.txt" ]; then
  echo "==> Installing Mason packages..."
  while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    echo "    Installing: $pkg"
    nvim --headless -c "MasonInstall $pkg" -c 'sleep 30' -c 'quitall' 2>&1 || true
  done < "$REPO_DIR/mason-packages.txt"
  echo "==> Mason packages installed"
else
  echo "==> No mason-packages.txt found, skipping Mason install"
fi

# ── Install Treesitter parsers ──
if [ -f "$REPO_DIR/treesitter-parsers.txt" ]; then
  PARSERS=$(paste -sd',' "$REPO_DIR/treesitter-parsers.txt" | sed "s/,/','/g" | sed "s/^/'/;s/$/'/")
  echo "==> Installing Treesitter parsers..."
  nvim --headless -c "TSInstallSync $PARSERS" -c 'quitall' 2>&1 || true
  echo "==> Treesitter parsers installed"
else
  echo "==> No treesitter-parsers.txt found, skipping"
fi

echo ""
echo "==> Restore complete!"
echo "    Start nvim and verify everything works."
echo "    If any Mason package failed, run :Mason inside nvim to install manually."
