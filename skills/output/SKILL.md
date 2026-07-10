---
name: output
description: Show or switch the Mac's audio output device (built-in speakers, AirPods, external displays, DACs). Use when the user asks where sound is playing, which output device is active, or wants audio routed to a different device.
argument-hint: [device name or number]
allowed-tools: Bash
---

Requested device: $ARGUMENTS

Current output device and everything available (JSON):

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" output`

Now do the following:

1. **No argument** → present the devices as a short markdown list, marking the
   current one, e.g. `🔊 **MacBook Pro Speakers** (current)`, then offer to
   switch.

2. **With a device request** → map what the user said to one entry in the
   `devices` list above (they may use loose words: "에어팟"/"earbuds" → the
   AirPods entry, "speakers" → the built-in speakers, "monitor"/"TV" → the
   display device). Then run:

   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" output "<device name>"
   ```

   The script itself accepts an exact name, a unique case-insensitive
   substring, or the 1-based list position, and prints the updated list.

3. Confirm in one styled line: `🔊 Output → **AirPods Pro**`.

Error handling:

- **Exit 4** — no match or ambiguous; stderr names the candidates. Show them
  and ask which one (AskUserQuestion is not available here — just ask in
  text).
- **Exit 1 with "native helper"** — the feature needs the compiled helper;
  point to `/media:doctor`.
- A device that is not connected (e.g. AirPods in the case) does not appear
  in the list — switching cannot connect it; the user must connect it first.

Tip: the statusline can show the current output device (icon by device kind —
🎧 Bluetooth/headphones, 📺 HDMI/DisplayPort, 📶 AirPlay, 🔊 speakers) —
check "Output device" in `/media:config`, or place it anywhere with
`/media:statusline` (digit 6).
