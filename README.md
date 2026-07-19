# dji-mic-wispr-flow

Use the DJI Mic Mini 2 transmitter's linking button as a wireless remote for
[Wispr Flow](https://wisprflow.ai) dictation on macOS. Press the button on the
mic clipped to your collar → Flow starts hands-free dictation; press again →
Flow stops and inserts the text at the cursor. Works from across the room —
the press travels over DJI's own wireless link, not Bluetooth.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/caezium/dji-mic-wispr-flow/main/install.sh | bash
```

The script installs Karabiner-Elements if needed and **merges** the rule into
your existing Karabiner config (existing rules and devices are kept; a
timestamped backup is written next to it; re-running updates the rule in
place). Then two one-time permission grants:

1. Approve the Karabiner driver extension when prompted.
2. System Settings → Privacy & Security → Input Monitoring → enable
   `karabiner_grabber`.

Plug in the DJI receiver (USB-C), set Wispr Flow's mic to "Wireless Mic Rx",
make sure Flow's hands-free shortcut is **Fn+Space** (the default target), and
press the transmitter's linking button.

Different Flow shortcut? Pass it in:

```bash
HOTKEY_KEY=left_option HOTKEY_MODS=left_control ./install.sh   # Ctrl+Opt
HOTKEY_KEY=f13 HOTKEY_MODS= ./install.sh                       # bare F13
```

`HOTKEY_MODS` takes `+`-separated [Karabiner modifier names](https://karabiner-elements.pqrs.org/docs/json/complex-modifications-manipulator-definition/from/modifiers/).

## How it works

The Mic Mini 2 has a camera-shutter remote feature: when the receiver (RX) is
mounted on a host, pressing the transmitter's linking button makes the RX emit
a **volume keypress** over its USB HID interface (DJI's manual, §2.5: works
"for apps that use volume buttons as shutter controls"). Plugged into a Mac via
USB-C, that keypress is visible to Karabiner-Elements, which remaps it —
filtered to the DJI device only — to Wispr Flow's hands-free shortcut.

```
TX button ─(DJI wireless link)→ RX ─(USB HID volume key)→ Karabiner ─(Fn+Space)→ Wispr Flow
```

- Works only with the RX plugged in (USB-C). Bluetooth-only mode exposes a bare
  audio device (HFP), no button events.
- The rule matches `volume_increment` and `volume_decrement` from the DJI
  device only, so keyboard volume keys are unaffected. While the RX is plugged
  in, its button no longer changes system volume.
- The original Mic Mini should work identically — its receiver reports the
  same USB IDs (untested here; the Mini 2 is what I own).

## Device identifiers

| Field | Value |
|---|---|
| USB product | `Wireless Mic Rx` |
| vendor_id | `11427` (0x2CA3, DJI Technology Co., Ltd.) |
| product_id | `16401` (0x4011 — same as the original Mic Mini RX) |
| Karabiner flag | `is_consumer: true` |

The `is_consumer` flag matters: Karabiner ignores non-keyboard consumer-control
devices unless the profile's `devices` list has an entry with `ignore: false`
for these identifiers. The installer adds it.

## Repo contents

- `install.sh` — self-contained installer/merger (the one-liner above).
- `karabiner/karabiner.json` — reference snapshot of a full working config.

## Credits

Mechanism confirmed by [Johnixr/dji-mic-dictation](https://github.com/Johnixr/dji-mic-dictation),
which does the same capture for the original Mic Mini (targeting macOS
dictation + Typeless instead of Wispr Flow).
