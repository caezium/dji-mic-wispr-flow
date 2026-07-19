#!/bin/bash
# Restore the DJI Mic Mini 2 -> Wispr Flow button setup on a fresh Mac.
set -euo pipefail

cd "$(dirname "$0")"

if [ ! -d "/Applications/Karabiner-Elements.app" ]; then
    echo "Installing Karabiner-Elements..."
    brew install --cask karabiner-elements
fi

mkdir -p ~/.config/karabiner
if [ -f ~/.config/karabiner/karabiner.json ]; then
    backup=~/.config/karabiner/karabiner.json.bak.$(date +%Y%m%d%H%M%S)
    cp ~/.config/karabiner/karabiner.json "$backup"
    echo "Existing config backed up to $backup"
    echo "NOTE: this overwrites it. Merge the rule manually if you had other rules."
fi
cp karabiner/karabiner.json ~/.config/karabiner/karabiner.json
echo "Config installed."

open -a "Karabiner-Elements"
cat <<'EOF'

Manual steps (first install only):
  1. Approve the Karabiner driver extension when prompted.
  2. System Settings -> Privacy & Security -> Input Monitoring:
     enable karabiner_grabber.
  3. Plug in the DJI receiver (USB-C), set Wispr Flow's mic to
     "Wireless Mic Rx", and confirm Flow's hands-free shortcut is Fn+Space.
  4. Press the transmitter's linking button to toggle dictation.
EOF
