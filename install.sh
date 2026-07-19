#!/bin/bash
# DJI Mic Mini / Mini 2 button -> Wispr Flow, via Karabiner-Elements.
#
# One-liner:
#   curl -fsSL https://raw.githubusercontent.com/caezium/dji-mic-wispr-flow/main/install.sh | bash
#
# Custom hotkey (default: Fn+Space, Wispr Flow's hands-free shortcut):
#   HOTKEY_KEY=spacebar HOTKEY_MODS=fn ./install.sh
#   HOTKEY_KEY=left_option HOTKEY_MODS=left_control ./install.sh   # Ctrl+Opt
#
# Merges into ~/.config/karabiner/karabiner.json non-destructively:
# existing rules and devices are kept; re-running updates the rule in place.
set -euo pipefail

HOTKEY_KEY="${HOTKEY_KEY:-spacebar}"
HOTKEY_MODS="${HOTKEY_MODS:-fn}"

if [ ! -d "/Applications/Karabiner-Elements.app" ]; then
    if ! command -v brew >/dev/null; then
        echo "Homebrew not found. Install Karabiner-Elements manually from" >&2
        echo "https://karabiner-elements.pqrs.org/ then re-run this script." >&2
        exit 1
    fi
    echo "Installing Karabiner-Elements..."
    brew install --cask karabiner-elements
fi

CONFIG=~/.config/karabiner/karabiner.json
mkdir -p ~/.config/karabiner
if [ -f "$CONFIG" ]; then
    cp "$CONFIG" "$CONFIG.bak.$(date +%Y%m%d%H%M%S)"
fi

HOTKEY_KEY="$HOTKEY_KEY" HOTKEY_MODS="$HOTKEY_MODS" CONFIG="$CONFIG" python3 <<'PYEOF'
import json, os

config_path = os.environ["CONFIG"]
key = os.environ["HOTKEY_KEY"]
mods = [m for m in os.environ["HOTKEY_MODS"].split("+") if m]

VENDOR, PRODUCT = 11427, 16401
RULE_DESC = "DJI Mic button -> Wispr Flow"
to_event = {"key_code": key, **({"modifiers": mods} if mods else {})}
device_cond = {
    "type": "device_if",
    "identifiers": [{"vendor_id": VENDOR, "product_id": PRODUCT}],
}
rule = {
    "description": RULE_DESC,
    "manipulators": [
        {
            "type": "basic",
            "conditions": [device_cond],
            "from": {"consumer_key_code": c, "modifiers": {"optional": ["any"]}},
            "to": [to_event],
        }
        for c in ("volume_increment", "volume_decrement")
    ],
}
device_entry = {
    "identifiers": {"is_consumer": True, "vendor_id": VENDOR, "product_id": PRODUCT},
    "ignore": False,
    "manipulate_caps_lock_led": False,
}

try:
    with open(config_path) as f:
        config = json.load(f)
except FileNotFoundError:
    config = {"profiles": [{"name": "Default profile", "selected": True,
                            "virtual_hid_keyboard": {"keyboard_type_v2": "ansi"}}]}

profiles = config.setdefault("profiles", [])
profile = next((p for p in profiles if p.get("selected")), None)
if profile is None:
    profile = profiles[0] if profiles else {}
    if not profiles:
        profiles.append(profile)

devices = profile.setdefault("devices", [])
for d in devices:
    ident = d.get("identifiers", {})
    if ident.get("vendor_id") == VENDOR and ident.get("product_id") == PRODUCT:
        d.update(device_entry)
        break
else:
    devices.append(device_entry)

rules = profile.setdefault("complex_modifications", {}).setdefault("rules", [])
rules[:] = [r for r in rules
            if not r.get("description", "").startswith(("DJI Mic button", "DJI Mic Mini 2 button"))]
rules.append(rule)

with open(config_path, "w") as f:
    json.dump(config, f, indent=4)
    f.write("\n")

hotkey = "+".join(mods + [key]) if mods else key
print(f"Rule installed: DJI button -> {hotkey}")
PYEOF

open -a "Karabiner-Elements"
cat <<'EOF'

Done. First install only — two permission grants:
  1. Approve the Karabiner driver extension when prompted.
  2. System Settings -> Privacy & Security -> Input Monitoring:
     enable karabiner_grabber.

Then: plug in the DJI receiver (USB-C), set Wispr Flow's mic to
"Wireless Mic Rx", make sure Flow's hands-free shortcut matches the
hotkey above, and press the transmitter's linking button to toggle
dictation.
EOF
