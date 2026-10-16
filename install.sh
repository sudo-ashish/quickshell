#!/usr/bin/env bash
# QuickShell — Self-contained installer for Arch-based systems
# Run once on a fresh Arch install; all dependencies are handled automatically.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ──────────────────────────────────────────────────────────────────────────────
# 1. System package dependencies
# ──────────────────────────────────────────────────────────────────────────────
echo "==> Checking system packages..."

PACMAN_PKGS=(
  # Core compositor
  hyprland

  # QuickShell runtime
  quickshell

  # PipeWire audio stack (PulseAudio-compatible layer required for pactl)
  pipewire
  pipewire-pulse
  wireplumber

  # Bluetooth control
  bluez
  bluez-utils

  # Brightness control (backlight)
  brightnessctl

  # Networking (NetworkManager standalone — wpa_supplicant is pulled automatically)
  networkmanager

  # Power & Battery
  upower
  power-profiles-daemon

  # Desktop Integration
  xdg-utils      # xdg-open in launcher
  libnotify      # notify-send in qs-notifications

  # Utilities used by helper scripts
  jq             # JSON parsing in shell scripts
  qrencode       # qs-network-qr (Wi-Fi sharing)

  # Fonts
  ttf-jetbrains-mono-nerd  # default shell font & icons
)

# AUR packages (installed with yay/paru if available)
AUR_PKGS=(
  # none required — all above are in official repos
)

MISSING_PACMAN=()
for pkg in "${PACMAN_PKGS[@]}"; do
  if ! pacman -Qi "$pkg" &>/dev/null; then
    MISSING_PACMAN+=("$pkg")
  fi
done

if [[ ${#MISSING_PACMAN[@]} -gt 0 ]]; then
  echo "==> Installing missing packages: ${MISSING_PACMAN[*]}"
  if [[ "$EUID" -eq 0 ]]; then
    pacman -S --needed --noconfirm "${MISSING_PACMAN[@]}"
  else
    sudo pacman -S --needed --noconfirm "${MISSING_PACMAN[@]}"
  fi
else
  echo "==> All system packages already installed."
fi

# ──────────────────────────────────────────────────────────────────────────────
# 2. Enable system services
# ──────────────────────────────────────────────────────────────────────────────
echo "==> Enabling user services..."
systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || true
systemctl --user mask hyprpolkitagent.service 2>/dev/null || true

echo "==> Enabling system services..."
systemctl enable --now bluetooth NetworkManager power-profiles-daemon 2>/dev/null || \
  sudo systemctl enable --now bluetooth NetworkManager power-profiles-daemon 2>/dev/null || true

# ──────────────────────────────────────────────────────────────────────────────
# 3. Install helper scripts to ~/.local/bin
# ──────────────────────────────────────────────────────────────────────────────
TARGET_BIN_DIR="$HOME/.local/bin"
mkdir -p "$TARGET_BIN_DIR"

if [[ -f "$SCRIPT_DIR/src/qs-lockstate-monitor.c" ]]; then
  gcc -O2 "$SCRIPT_DIR/src/qs-lockstate-monitor.c" -o "$SCRIPT_DIR/scripts/qs-lockstate-monitor" 2>/dev/null || true
fi

echo "==> Installing QuickShell helper scripts to $TARGET_BIN_DIR..."
for script in "$SCRIPT_DIR/scripts"/*; do
  if [[ -f "$script" ]]; then
    base=$(basename "$script")
    chmod +x "$script"
    cp -f "$script" "$TARGET_BIN_DIR/$base"
    chmod +x "$TARGET_BIN_DIR/$base"
    echo "   -> $base"
  fi
done

# ──────────────────────────────────────────────────────────────────────────────
# 4. Ensure ~/.local/bin is in PATH
# ──────────────────────────────────────────────────────────────────────────────
BASHRC="$HOME/.bashrc"
ZSHRC="$HOME/.zshrc"
PATH_SNIPPET='
# QuickShell: ensure ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi'

for RC in "$BASHRC" "$ZSHRC"; do
  if [[ -f "$RC" ]] && ! grep -q 'HOME/.local/bin' "$RC"; then
    echo "$PATH_SNIPPET" >> "$RC"
    echo "==> Added ~/.local/bin to $RC"
  fi
done

# Also update current session
export PATH="$HOME/.local/bin:$PATH"

# ──────────────────────────────────────────────────────────────────────────────
# 5. Create state directories
# ──────────────────────────────────────────────────────────────────────────────
mkdir -p "$HOME/.local/state/quickshell"

# ──────────────────────────────────────────────────────────────────────────────
# 6. Done
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "✓ QuickShell setup complete!"
echo ""
echo "  Start the shell with:  quickshell -p ~/.config/quickshell"
echo "  Or add it to your Hyprland config:"
echo "    exec-once = quickshell -p ~/.config/quickshell"
echo ""
