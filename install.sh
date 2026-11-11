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
# Mode (default: toggle — every press toggles Flow on/off):
#   MODE=cycle ./install.sh   # press 1 = start, press 2 = stop, press 3 = Enter
#   MODE=cycle CYCLE_TIMEOUT_MS=30000 ./install.sh   # Enter step expires sooner
#
# Merges into ~/.config/karabiner/karabiner.json non-destructively:
# existing rules and devices are kept; re-running updates the rule in place.
set -euo pipefail

HOTKEY_KEY="${HOTKEY_KEY:-spacebar}"
HOTKEY_MODS="${HOTKEY_MODS:-fn}"
MODE="${MODE:-toggle}"
CYCLE_TIMEOUT_MS="${CYCLE_TIMEOUT_MS:-60000}"
case "$MODE" in
    toggle|cycle) ;;
    *) echo "MODE must be 'toggle' or 'cycle' (got '$MODE')" >&2; exit 1 ;;
esac

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

HOTKEY_KEY="$HOTKEY_KEY" HOTKEY_MODS="$HOTKEY_MODS" MODE="$MODE" \
CYCLE_TIMEOUT_MS="$CYCLE_TIMEOUT_MS" CONFIG="$CONFIG" python3 <<'PYEOF'
import json, os

config_path = os.environ["CONFIG"]
key = os.environ["HOTKEY_KEY"]
mods = [m for m in os.environ["HOTKEY_MODS"].split("+") if m]
mode = os.environ["MODE"]
cycle_timeout_ms = int(os.environ["CYCLE_TIMEOUT_MS"])

VENDOR, PRODUCT = 11427, 16401
RULE_DESC = "DJI Mic button -> Wispr Flow"
to_event = {"key_code": key, **({"modifiers": mods} if mods else {})}
device_cond = {
    "type": "device_if",
    "identifiers": [{"vendor_id": VENDOR, "product_id": PRODUCT}],
}
CODES = ("volume_increment", "volume_decrement")


def from_event(code):
    return {"consumer_key_code": code, "modifiers": {"optional": ["any"]}}


if mode == "toggle":
    manipulators = [
        {
            "type": "basic",
            "conditions": [device_cond],
            "from": from_event(c),
            "to": [to_event],
        }
        for c in CODES
    ]
else:
    # cycle: press 1 = start, press 2 = stop, press 3 = Enter.
    # State lives in a Karabiner variable: 0 idle, 1 dictating, 2 stopped.
    # Every DJI button arrives as the same volume key, so a second button
    # can't be told apart; the press count does the work instead.
    VAR = "dji_wispr_state"

    def state(n):
        return {"set_variable": {"name": VAR, "value": n}}

    def state_is(n):
        return {"type": "variable_if", "name": VAR, "value": n}

    manipulators = []
    for c in CODES:
        manipulators += [
            {   # press 3: Enter, back to idle
                "type": "basic",
                "conditions": [device_cond, state_is(2)],
                "from": from_event(c),
                "to": [state(0), {"key_code": "return_or_enter", "repeat": False}],
            },
            {   # press 2: stop; the Enter step expires if nothing is touched
                "type": "basic",
                "conditions": [device_cond, state_is(1)],
                "from": from_event(c),
                "to": [to_event, state(2)],
                "parameters": {"basic.to_delayed_action_delay_milliseconds": cycle_timeout_ms},
                "to_delayed_action": {"to_if_invoked": [state(0)], "to_if_canceled": []},
            },
            {   # press 1: start
                "type": "basic",
                "conditions": [device_cond],
                "from": from_event(c),
                "to": [to_event, state(1)],
            },
        ]

    # Resync. The rule only counts presses, it can't see Flow, so the count
    # drifts when Flow stops on its own (e.g. it cancels a recording after a
    # mic switch) or when you send with the keyboard instead of press 3.
    # Keyboard keys that end a dictation reset the count; they still pass
    # through unchanged.
    not_dji = {"type": "device_unless", "identifiers": device_cond["identifiers"]}
    manipulators += [
        {   # Esc (Flow's dismiss key) mid-cycle -> idle
            "type": "basic",
            "conditions": [not_dji, {"type": "variable_unless", "name": VAR, "value": 0}],
            "from": {"key_code": "escape", "modifiers": {"optional": ["any"]}},
            "to": [state(0), {"key_code": "escape"}],
        },
        {   # plain Return after a stop (sent by hand) -> idle; Shift+Return doesn't count
            "type": "basic",
            "conditions": [not_dji, state_is(2)],
            "from": {"key_code": "return_or_enter"},
            "to": [state(0), {"key_code": "return_or_enter"}],
        },
    ]

rule = {"description": f"{RULE_DESC} ({mode})", "manipulators": manipulators}
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
if mode == "cycle":
    print(f"Rule installed (cycle): press 1 -> {hotkey} (start), "
          f"press 2 -> {hotkey} (stop), press 3 -> Enter")
else:
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
