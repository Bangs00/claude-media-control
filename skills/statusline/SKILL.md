---
name: statusline
description: Choose which items appear in the now-playing statusline (track, progress bar, time, spectrum) and whether they stack on separate lines. Use when the user wants to customize, configure, pick, or lay out what shows in their media statusline.
allowed-tools: Bash, AskUserQuestion
---

Customize the now-playing statusline segment interactively.

Current selection and layout:

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config statusline.fields && "${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config statusline.multiline`

Now do the following:

1. Ask the user with **AskUserQuestion** (send both questions together). Pre-select
   the options that match the current selection shown above.

   - **Question 1** — header "Items", `multiSelect: true`,
     "Which items should the statusline show?"
     - `Track` — ▶︎ title — artist
     - `Progress bar` — ██████░░░░
     - `Time` — elapsed / total
     - `Spectrum` — live frequency bars (opt-in; needs audio-recording permission)

     Selecting all four = show everything.

   - **Question 2** — header "Layout", single select,
     "How should the items be arranged?"
     - `One line` — all items on a single line
     - `Separate lines` — each group (track / progress+time / spectrum) on its own line

2. Map the chosen items to field names (Track→`track`, Progress bar→`progressbar`,
   Time→`time`, Spectrum→`spectrum`) and save them (comma-separated; order does not
   matter, the script canonicalizes):

   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config statusline.fields "track,progressbar,time"
   ```

3. Save the layout (`on` for separate lines, `off` for one line):

   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config statusline.multiline off
   ```

4. If the user picked **Spectrum**, enable it (it is off by default):

   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config display.spectrum on
   ```

   If this is **refused (exit 3)**, the system-audio-recording permission is missing.
   Tell the user to grant it to their terminal app (System Settings > Privacy &
   Security, with audio playing), then re-save the fields **without** `spectrum` so the
   rest works. Do not force it.

   Then ask one more **AskUserQuestion** (header "Spectrum") — "How should the
   spectrum bars be colored?":
   - `Solid cyan (default)` — one color, the default
   - `Solid — another color` — then take the color (red/green/yellow/blue/magenta/white) via the Other field or a follow-up
   - `Rainbow` — front-to-back color cycle (ignores the solid color)

   Save with `config spectrum.style solid|rainbow` and, for a custom solid,
   `config spectrum.color <color>`.

5. Show the result and remind the user the segment only appears when
   `display.statusline` is on and the wrapper from `docs/statusline.md` is installed:

   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config display.statusline on
   "${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" statusline
   ```

   (If `statusline` prints nothing, the statusline is off or nothing is playing.)

Colors: the segment is styled with ANSI colors by default (green/yellow state
accent, bold title, italic artist; spectrum bars tinted per `spectrum.style` —
solid `spectrum.color`, default cyan, or a positional rainbow cycle). If the
user asks to turn styling off or on, use `/media:config statusline.color
off|on` — the `NO_COLOR` env var is also honored.
