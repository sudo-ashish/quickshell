#!/usr/bin/env bash
# qyra-shell.sh: Comprehensive startup script for Quickshell desktop environment
set -euo pipefail

QS_DIR="${QUICKSHELL_DIR:-$HOME/quickshell}"
export PATH="$HOME/.local/bin:$QS_DIR/scripts:$PATH"
export QS_CONFIG_PATH="$QS_DIR"

# 1. Terminate conflicting legacy bars, notification daemons, OSD servers, or polkit agents
killall -q waybar swaync swayosd-server hyprpolkitagent polkit-kde-authentication-agent-1 polkit-gnome-authentication-agent-1 2>/dev/null || true
systemctl --user stop hyprpolkitagent.service 2>/dev/null || true

# 2. Terminate any previous or stale QuickShell instances cleanly
killall -q qs quickshell 2>/dev/null || true
sleep 0.3

# 3. Ensure PipeWire audio server is running
systemctl --user start pipewire pipewire-pulse wireplumber 2>/dev/null || true

# 4. Sync helper scripts into ~/.local/bin
mkdir -p "$HOME/.local/bin"
if [[ -d "$QS_DIR/scripts" ]]; then
  for s in "$QS_DIR/scripts"/*; do
    [[ -f "$s" ]] || continue
    base=$(basename "$s")
    chmod +x "$s"
    if [[ ! -f "$HOME/.local/bin/$base" || "$s" -nt "$HOME/.local/bin/$base" ]]; then
      cp -f "$s" "$HOME/.local/bin/$base"
      chmod +x "$HOME/.local/bin/$base"
    fi
  done
fi

# 5. Start Quickshell daemon attached to the workspace config
/usr/bin/qs -d -p "$QS_DIR"

# 6. Bridge IPC sockets so all commands (with or without -p) seamlessly reach the instance
sleep 0.4
uid=$(id -u)
mkdir -p "/run/user/$uid/quickshell/by-shell/3bb4e7c6d4dad9dfd3f25bf68311dcd8" \
         "/run/user/$uid/quickshell/by-shell/297537087f24e658cd0a0b2380d3bfef" \
         "/run/user/$uid/quickshell/by-path"

for id_dir in "/run/user/$uid/quickshell/by-id"/*; do
  [[ -e "$id_dir" ]] || continue
  b=$(basename "$id_dir")
  ln -sf "$id_dir" "/run/user/$uid/quickshell/by-shell/3bb4e7c6d4dad9dfd3f25bf68311dcd8/$b"
  ln -sf "$id_dir" "/run/user/$uid/quickshell/by-shell/297537087f24e658cd0a0b2380d3bfef/$b"
done

# Bridge by-path so standard config path searches find the running instance
ln -sf "/run/user/$uid/quickshell/by-shell/297537087f24e658cd0a0b2380d3bfef" "/run/user/$uid/quickshell/by-path/3bb4e7c6d4dad9dfd3f25bf68311dcd8" 2>/dev/null || true

# 7. Quick verification
qs ipc call osd ping >/dev/null 2>&1 || true
