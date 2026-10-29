#!/usr/bin/env bash
# One-time setup for CachyOS (Hyprland + Noctalia).
set -euo pipefail
cd "$(dirname "$0")"

missing=()
for c in wl-paste wl-copy notify-send ssh ssh-keygen; do
  command -v "$c" >/dev/null || missing+=("$c")
done
if [ ${#missing[@]} -gt 0 ]; then
  echo "Missing: ${missing[*]}"
  echo "Install:  sudo pacman -S --needed wl-clipboard libnotify openssh"
  exit 1
fi

mkdir -p "$HOME/.local/bin"
install -m 755 shot "$HOME/.local/bin/shot"
echo "Installed ~/.local/bin/shot"

KEY="$HOME/.ssh/screenshot_drop_ed25519"
if [ ! -f "$KEY" ]; then
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  ssh-keygen -q -t ed25519 -N '' -C "screenshot-drop-cachy" -f "$KEY"
  echo "Created upload key $KEY"
fi

# Upload host: kept in an untracked config file, because this repo is public.
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/screenshot-drop/host"
if [ ! -f "$CONFIG" ] && [ -n "${SHOT_HOST:-}" ]; then
  mkdir -p "$(dirname "$CONFIG")"
  printf '%s\n' "$SHOT_HOST" > "$CONFIG"
  echo "Wrote upload host to $CONFIG"
fi
if [ -f "$CONFIG" ]; then
  HOST_STEP="Upload host is set in $CONFIG."
else
  HOST_STEP="Write the Mac mini's user@host (ask Hermes) to $CONFIG, one line,
   or re-run with SHOT_HOST=user@host $0"
fi

# fish: make sure ~/.local/bin is on PATH
if command -v fish >/dev/null; then
  fish -c 'contains $HOME/.local/bin $fish_user_paths; or fish_add_path -U $HOME/.local/bin' || true
fi

cat <<EOF

1) Send this public key to Hermes (one line):

$(cat "$KEY.pub")

2) Add this line to ~/.config/hypr/config/binds.lua (near the Print binds):

hl.bind(mainMod .. " + SHIFT + U", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/shot"))

3) $HOST_STEP

4) Reload Hyprland (or log out/in). Test: Print, annotate, Ctrl+C, Super+Shift+U.
EOF
