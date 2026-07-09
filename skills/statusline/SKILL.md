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

5. Show the result and remind the user the segment only appears when
   `display.statusline` is on and the wrapper from `docs/statusline.md` is installed:

   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config display.statusline on
   "${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" statusline
   ```

   (If `statusline` prints nothing, the statusline is off or nothing is playing.)
