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

### Cycle mode: start / stop / Enter

Handy for dictating prompts into a terminal or chat box without touching the
keyboard:

```bash
MODE=cycle ./install.sh
# or: curl -fsSL https://raw.githubusercontent.com/caezium/dji-mic-wispr-flow/main/install.sh | MODE=cycle bash
```

| Press | Action |
|---|---|
| 1 | start Flow (hands-free shortcut) |
| 2 | stop Flow — text is inserted |
| 3 | Enter |

You can edit the text with the keyboard between press 2 and press 3. If
nothing is touched for 60 s after press 2, the Enter step expires and the next
press starts a new dictation (`CYCLE_TIMEOUT_MS` changes this). Re-run without
`MODE` to go back to plain toggling.

**Keeping the count in sync.** The rule counts presses; it can't see Flow. So
the count drifts when Flow stops on its own (it cancels a recording when the
mic switches, for example) or when you send with the keyboard instead of
press 3. Two keyboard keys reset it:

- **Esc** (Flow's dismiss key) at any point mid-cycle → the next press starts.
- **Return** (without modifiers) after press 2 → the next press starts.
  Shift+Return still just adds a new line.

If it ever feels one step off, press Esc once. Setting Flow's microphone to
"Wireless Mic Rx" rather than letting it switch mics avoids most of the
cancelled recordings.

Why a press count and not a second button or a double-press? See the notes
under *How it works*.

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
- Only one key code ever arrives. In testing, the other button that produced
  an event at all sent the very same `volume_increment` as the linking button,
  so a second button can't be given its own action.
- Avoid fast double-presses: they never reached the Mac in testing, and
  double-pressing the receiver's button (then holding) puts the system into
  DJI's blue-mode pairing — flickering blue LED, no button events until it is
  re-paired (charging case, or hold the RX linking button until it blinks
  green, then hold the TX linking button → solid green).
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
