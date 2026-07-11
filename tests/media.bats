#!/usr/bin/env bats
# Unit tests for scripts/media.sh (bats-core).
#
# media.sh is copied unmodified into a scratch plugin tree whose
# build-native.sh / loader.pl / read-jxa.js are replaced by tests/stubs/*, so
# every branch is exercised without MediaRemote, a real build, or playing
# media. Knobs: STUB_BUILD (ok|fail), STUB_PRIMARY (ok|null|fail),
# STUB_JXA_JSON (JSON the JXA fallback "sees").
#
# Real system commands still run: osascript for `volume` and for the
# AppleScript fallback's "is app running" probe (safe: reads state, never
# launches apps). Run: npx bats tests/media.bats  (CI: brew install bats-core)

setup() {
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  PLUGIN="$BATS_TEST_TMPDIR/plugin"
  mkdir -p "$PLUGIN/scripts" "$PLUGIN/native"
  cp "$PROJECT_ROOT/scripts/media.sh" "$PLUGIN/scripts/media.sh"
  cp "$PROJECT_ROOT/tests/stubs/build-native.sh" "$PLUGIN/scripts/build-native.sh"
  cp "$PROJECT_ROOT/tests/stubs/build-click-handler.sh" "$PLUGIN/scripts/build-click-handler.sh"
  cp "$PROJECT_ROOT/tests/stubs/read-jxa.js" "$PLUGIN/scripts/read-jxa.js"
  cp "$PROJECT_ROOT/tests/stubs/loader.pl" "$PLUGIN/native/loader.pl"
  chmod +x "$PLUGIN/scripts/media.sh" "$PLUGIN/scripts/build-native.sh" \
           "$PLUGIN/scripts/build-click-handler.sh"
  export CLAUDE_PLUGIN_DATA="$BATS_TEST_TMPDIR/data"
  # Statusline wiring writes to $HOME/.claude (settings.json + wrapper), and
  # enabling display.statusline wires automatically — isolate every test from
  # the developer's real home directory.
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  MEDIA="$PLUGIN/scripts/media.sh"
}

# ---- dispatch / usage -------------------------------------------------------

@test "no subcommand: usage on stderr, exit 2" {
  run "$MEDIA"
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage: media.sh"* ]]
}

@test "unknown subcommand: usage, exit 2" {
  run "$MEDIA" frobnicate
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage: media.sh"* ]]
}

@test "non-macOS guard: clear error, exit 1" {
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/bash\necho Linux\n' > "$BATS_TEST_TMPDIR/bin/uname"
  chmod +x "$BATS_TEST_TMPDIR/bin/uname"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" run "$MEDIA" now
  [ "$status" -eq 1 ]
  [[ "$output" == *"only works on macOS"* ]]
}

@test "non-macOS guard: detect stays exit 0 for the hook" {
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/bash\necho Linux\n' > "$BATS_TEST_TMPDIR/bin/uname"
  chmod +x "$BATS_TEST_TMPDIR/bin/uname"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" run "$MEDIA" detect
  [ "$status" -eq 0 ]
  [[ "$output" == *"macOS only"* ]]
}

# ---- now ---------------------------------------------------------------------

@test "now: primary path returns track JSON untouched" {
  run "$MEDIA" now
  [ "$status" -eq 0 ]
  [[ "$output" == *'"title":"Stub Song"'* ]]
  [[ "$output" != *degraded* ]]
}

@test "now: primary and fallback both empty -> null" {
  STUB_PRIMARY=null run "$MEDIA" now
  [ "$status" -eq 0 ]
  [ "$output" = "null" ]
}

@test "now: primary empty but fallback sees media -> fallback JSON + doctor hint" {
  STUB_PRIMARY=null STUB_JXA_JSON='{"degraded":true,"title":"Jxa Song","bundleIdentifier":"com.stub.player"}' \
    run "$MEDIA" now
  [ "$status" -eq 0 ]
  [[ "$output" == *'"title":"Jxa Song"'* ]]
  [[ "$output" == *"/media:doctor"* ]]
}

@test "now: native build unavailable -> degraded JXA read" {
  STUB_BUILD=fail STUB_JXA_JSON='{"degraded":true,"title":"Jxa Song"}' run "$MEDIA" now
  [ "$status" -eq 0 ]
  [[ "$output" == *'"degraded":true'* ]]
  [[ "$output" == *'"title":"Jxa Song"'* ]]
}

@test "now: native read error -> fallback with warning" {
  STUB_PRIMARY=fail STUB_JXA_JSON='{"degraded":true,"title":"Jxa Song"}' run "$MEDIA" now
  [ "$status" -eq 0 ]
  [[ "$output" == *"native read failed"* ]]
  [[ "$output" == *'"title":"Jxa Song"'* ]]
}

# ---- history -----------------------------------------------------------------

@test "history: empty log -> friendly note" {
  run "$MEDIA" history
  [ "$status" -eq 0 ]
  [[ "$output" == *"no playback history yet"* ]]
}

@test "now: logs one history entry per track (dedup on repeat reads)" {
  run "$MEDIA" now
  run "$MEDIA" now
  [ -f "$CLAUDE_PLUGIN_DATA/history.jsonl" ]
  [ "$(wc -l < "$CLAUDE_PLUGIN_DATA/history.jsonl")" -eq 1 ]
  STUB_TRACK_TITLE="Second Song" run "$MEDIA" now
  [ "$(wc -l < "$CLAUDE_PLUGIN_DATA/history.jsonl")" -eq 2 ]
  # Dedup must keep working once the log holds multiple lines.
  STUB_TRACK_TITLE="Second Song" run "$MEDIA" now
  [ "$(wc -l < "$CLAUDE_PLUGIN_DATA/history.jsonl")" -eq 2 ]
}

@test "history: prints newest first with app name" {
  run "$MEDIA" now
  STUB_TRACK_TITLE="Second Song" run "$MEDIA" now
  run "$MEDIA" history
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == *"Second Song"* ]]
  [[ "${lines[1]}" == *"Stub Song"* ]]
  [[ "$output" == *"(StubPlayer)"* ]]
}

@test "history: count limits entries; --json prints raw JSONL" {
  run "$MEDIA" now
  STUB_TRACK_TITLE="Second Song" run "$MEDIA" now
  run "$MEDIA" history 1
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [[ "$output" == *"Second Song"* ]]
  run "$MEDIA" history --json 1
  [ "$status" -eq 0 ]
  [[ "$output" == *'"title":"Second Song"'* ]]
}

@test "history: invalid count rejected, exit 2" {
  run "$MEDIA" history abc
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage"* ]]
}

@test "history clear: removes the log" {
  run "$MEDIA" now
  run "$MEDIA" history clear
  [ "$status" -eq 0 ]
  [ ! -f "$CLAUDE_PLUGIN_DATA/history.jsonl" ]
}

@test "history.record off: reads leave no log" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"history.record":false}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" now
  [ "$status" -eq 0 ]
  [ ! -f "$CLAUDE_PLUGIN_DATA/history.jsonl" ]
}

@test "history: log capped at 500 entries (oldest dropped)" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  for i in $(seq 1 505); do
    printf '{"ts":%s,"title":"Old %s"}\n' "$i" "$i"
  done > "$CLAUDE_PLUGIN_DATA/history.jsonl"
  run "$MEDIA" now
  [ "$(wc -l < "$CLAUDE_PLUGIN_DATA/history.jsonl")" -eq 500 ]
  tail -1 "$CLAUDE_PLUGIN_DATA/history.jsonl" | grep -q '"title":"Stub Song"'
  head -1 "$CLAUDE_PLUGIN_DATA/history.jsonl" | grep -q '"title":"Old 7"'
}

@test "history: artist correction seconds later amends the entry (no phantom track)" {
  run "$MEDIA" now                                     # Stub Song — Stub Artist
  # Track change: MediaRemote switches the title first, the artist lags one
  # read behind — the transitional snapshot pairs the NEW title with the
  # STALE artist.
  STUB_TRACK_TITLE="Next Song" run "$MEDIA" now
  [ "$(wc -l < "$CLAUDE_PLUGIN_DATA/history.jsonl")" -eq 2 ]
  # The corrected read (same title/app, real artist) replaces it in place.
  STUB_TRACK_TITLE="Next Song" STUB_TRACK_ARTIST="Real Artist" run "$MEDIA" now
  [ "$(wc -l < "$CLAUDE_PLUGIN_DATA/history.jsonl")" -eq 2 ]
  tail -1 "$CLAUDE_PLUGIN_DATA/history.jsonl" | grep -q '"artist":"Real Artist"'
  [ "$(grep -c '"artist":"Stub Artist"' "$CLAUDE_PLUGIN_DATA/history.jsonl")" -eq 1 ]
  # The amended entry deduplicates like any other.
  STUB_TRACK_TITLE="Next Song" STUB_TRACK_ARTIST="Real Artist" run "$MEDIA" now
  [ "$(wc -l < "$CLAUDE_PLUGIN_DATA/history.jsonl")" -eq 2 ]
}

@test "history: title correction seconds later amends the entry (artist switched first)" {
  run "$MEDIA" now                                     # Stub Song — Stub Artist
  # The reverse lag: the ARTIST switches first, the title follows one read
  # behind — the transitional snapshot pairs the OLD title with the NEW
  # artist.
  STUB_TRACK_ARTIST="Next Artist" run "$MEDIA" now
  [ "$(wc -l < "$CLAUDE_PLUGIN_DATA/history.jsonl")" -eq 2 ]
  # The corrected read (new title, same artist/app) replaces it in place.
  STUB_TRACK_TITLE="Next Song" STUB_TRACK_ARTIST="Next Artist" run "$MEDIA" now
  [ "$(wc -l < "$CLAUDE_PLUGIN_DATA/history.jsonl")" -eq 2 ]
  head -1 "$CLAUDE_PLUGIN_DATA/history.jsonl" | grep -q '"title":"Stub Song"'
  tail -1 "$CLAUDE_PLUGIN_DATA/history.jsonl" | grep -q '"title":"Next Song"'
  # The old-title/new-artist mix is gone.
  ! grep -E '"artist":"Next Artist".*"title":"Stub Song"' "$CLAUDE_PLUGIN_DATA/history.jsonl"
}

@test "history: artist-less transitional snapshot is amended by the full read" {
  run "$MEDIA" now                                     # Stub Song — Stub Artist
  # Some sources publish the new title with NO artist for a beat.
  STUB_TRACK_TITLE="Next Song" STUB_TRACK_ARTIST="" run "$MEDIA" now
  [ "$(wc -l < "$CLAUDE_PLUGIN_DATA/history.jsonl")" -eq 2 ]
  STUB_TRACK_TITLE="Next Song" run "$MEDIA" now        # full snapshot
  [ "$(wc -l < "$CLAUDE_PLUGIN_DATA/history.jsonl")" -eq 2 ]
  tail -1 "$CLAUDE_PLUGIN_DATA/history.jsonl" | grep -q '"artist":"Stub Artist"'
  ! grep -E '"artist":"".*"title":"Next Song"' "$CLAUDE_PLUGIN_DATA/history.jsonl"
}

@test "history: same-artist album playthrough appends (no false amend)" {
  STUB_TRACK_TITLE="First Song" run "$MEDIA" now
  STUB_TRACK_TITLE="Second Song" run "$MEDIA" now
  STUB_TRACK_TITLE="Third Song" run "$MEDIA" now       # all Stub Artist
  [ "$(wc -l < "$CLAUDE_PLUGIN_DATA/history.jsonl")" -eq 3 ]
}

@test "history: an aged same-title entry appends instead of amending" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  printf '{"artist":"Old Artist","bundleIdentifier":"com.stub.player","title":"Stub Song","ts":%s}\n' \
    "$(( $(date +%s) - 60 ))" > "$CLAUDE_PLUGIN_DATA/history.jsonl"
  run "$MEDIA" now                                     # same title, 60s later
  [ "$(wc -l < "$CLAUDE_PLUGIN_DATA/history.jsonl")" -eq 2 ]
  grep -q '"artist":"Old Artist"' "$CLAUDE_PLUGIN_DATA/history.jsonl"
}

@test "history: a same-title entry from another app appends (no cross-app amend)" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  printf '{"artist":"Other Artist","bundleIdentifier":"com.other.app","title":"Stub Song","ts":%s}\n' \
    "$(date +%s)" > "$CLAUDE_PLUGIN_DATA/history.jsonl"
  run "$MEDIA" now
  [ "$(wc -l < "$CLAUDE_PLUGIN_DATA/history.jsonl")" -eq 2 ]
  grep -q '"artist":"Other Artist"' "$CLAUDE_PLUGIN_DATA/history.jsonl"
}

@test "history: transitional empty-title snapshots are never logged" {
  STUB_TRACK_TITLE="" run "$MEDIA" now
  [ "$status" -eq 0 ]
  [ ! -f "$CLAUDE_PLUGIN_DATA/history.jsonl" ]
}

# ---- control -------------------------------------------------------------------

@test "toggle: primary send then state re-read" {
  run "$MEDIA" toggle
  [ "$status" -eq 0 ]
  [[ "$output" == *'"title":"Stub Song"'* ]]
}

@test "control fallback: unsupported app is refused with exit 3" {
  STUB_BUILD=fail STUB_JXA_JSON='{"degraded":true,"title":"X","bundleIdentifier":"com.google.Chrome"}' \
    run "$MEDIA" pause
  [ "$status" -eq 3 ]
  [[ "$output" == *"only Spotify and Apple Music"* ]]
}

@test "control fallback: app not running is a no-op with exit 4" {
  # Spotify/Music are never running inside the test env; the guard must
  # refuse instead of launching them.
  STUB_BUILD=fail STUB_JXA_JSON='{"degraded":true,"title":"X","bundleIdentifier":"com.apple.Music"}' \
    run "$MEDIA" pause
  [ "$status" -eq 4 ]
  [[ "$output" == *"not running"* ]]
}

# ---- seek ----------------------------------------------------------------------

@test "seek: missing argument rejected, exit 2" {
  run "$MEDIA" seek
  [ "$status" -eq 2 ]
  [[ "$output" == *"seconds"* ]]
}

@test "seek: non-numeric argument rejected, exit 2" {
  run "$MEDIA" seek 1:30
  [ "$status" -eq 2 ]
}

@test "seek: malformed number rejected, exit 2" {
  run "$MEDIA" seek 1.2.3
  [ "$status" -eq 2 ]
}

@test "seek: valid seconds go through primary and re-read state" {
  run "$MEDIA" seek 42.5
  [ "$status" -eq 0 ]
  [[ "$output" == *'"title":"Stub Song"'* ]]
}

# ---- artwork --------------------------------------------------------------------

@test "artwork: saves a file and prints its path as JSON" {
  run "$MEDIA" artwork "$BATS_TEST_TMPDIR/cover"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"path\":\"$BATS_TEST_TMPDIR/cover.jpg\""* ]]
  [ -f "$BATS_TEST_TMPDIR/cover.jpg" ]
}

@test "artwork: track without artwork -> null" {
  STUB_PRIMARY=null run "$MEDIA" artwork "$BATS_TEST_TMPDIR/cover"
  [ "$status" -eq 0 ]
  [ "$output" = "null" ]
}

@test "artwork: refused in degraded mode (JXA cannot read artwork)" {
  STUB_BUILD=fail run "$MEDIA" artwork "$BATS_TEST_TMPDIR/cover"
  [ "$status" -eq 1 ]
  [[ "$output" == *"native helper"* ]]
}

# ---- volume ---------------------------------------------------------------------

@test "volume: out-of-range rejected, exit 2" {
  run "$MEDIA" volume 101
  [ "$status" -eq 2 ]
  [[ "$output" == *"between 0 and 100"* ]]
}

@test "volume: non-integer rejected, exit 2" {
  run "$MEDIA" volume abc
  [ "$status" -eq 2 ]
}

@test "volume: read prints {volume,muted} JSON (or a clear error headless)" {
  run "$MEDIA" volume
  if [ "$status" -eq 0 ]; then
    [[ "$output" =~ \{\"volume\":[0-9]+,\"muted\":(true|false)\} ]]
  else
    # CI runners may expose no standard audio output device.
    [ "$status" -eq 1 ]
    [[ "$output" == *"could not read"* ]]
  fi
}

@test "volume: set drops the statusline cache (no-op set to the current level)" {
  run "$MEDIA" volume
  if [ "$status" -ne 0 ]; then
    skip "no standard audio output device on this machine"
  fi
  [[ "$output" =~ \"volume\":([0-9]+) ]]
  cur="${BASH_REMATCH[1]}"
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  printf 'stale' > "$CLAUDE_PLUGIN_DATA/statusline.cache"
  run "$MEDIA" volume "$cur"               # same level: no audible change
  [ "$status" -eq 0 ]
  [ ! -f "$CLAUDE_PLUGIN_DATA/statusline.cache" ]
}

# ---- output device ----------------------------------------------------------

@test "output: lists current + devices as JSON" {
  run "$MEDIA" output
  [ "$status" -eq 0 ]
  [[ "$output" == *'"current":"Stub Speakers"'* ]]
  [[ "$output" == *'"devices":["Stub Speakers","Stub AirPods"]'* ]]
}

@test "output: switch by name, list reflects the new device" {
  run "$MEDIA" output "airpods"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"current":"Stub AirPods"'* ]]
}

@test "output: switch by 1-based index" {
  run "$MEDIA" output 2
  [ "$status" -eq 0 ]
  [[ "$output" == *'"current":"Stub AirPods"'* ]]
}

@test "output: unknown device refused with candidates, exit 4" {
  run "$MEDIA" output "sonos"
  [ "$status" -eq 4 ]
  [[ "$output" == *"no output device matches"* ]]
}

@test "output: switch drops the statusline cache" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  printf 'stale' > "$CLAUDE_PLUGIN_DATA/statusline.cache"
  run "$MEDIA" output "airpods"
  [ "$status" -eq 0 ]
  [ ! -f "$CLAUDE_PLUGIN_DATA/statusline.cache" ]
}

@test "output: refused in degraded mode (needs the native helper)" {
  STUB_BUILD=fail run "$MEDIA" output
  [ "$status" -eq 1 ]
  [[ "$output" == *"native helper"* ]]
}

# ---- statusline ------------------------------------------------------------------

@test "statusline: off by default -> empty output, exit 0" {
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "statusline: on -> one segment line + cache file written" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stub Song"* ]]
  [[ "$output" == *"Stub Artist"* ]]
  [[ "$output" == *"1:15"* ]]      # elapsed and total are styled separately,
  [[ "$output" == *"/3:20"* ]]     # so SGR codes may sit between them
  [ -f "$CLAUDE_PLUGIN_DATA/statusline.cache" ]
}

@test "statusline: fresh cache is served without a new read" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  # The TTL compares whole seconds, so a write landing right at a second
  # boundary can age out instantly — retry across a few boundaries.
  for _ in 1 2 3; do
    printf 'CACHED_SENTINEL' > "$CLAUDE_PLUGIN_DATA/statusline.cache"
    run "$MEDIA" statusline
    [ "$status" -eq 0 ]
    [ "$output" = "CACHED_SENTINEL" ] && break
  done
  [ "$output" = "CACHED_SENTINEL" ]
}

@test "statusline: nothing playing -> empty output" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  STUB_PRIMARY=null run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ---- statusline active-tab gate ---------------------------------------------------
# The gate ranks sessions by their tty's atime (last consumed input) through
# MEDIA_STATUSLINE_TTY, which points it at plain files whose atime/mtime the
# tests control with touch. The state file statusline.tty names the holder;
# its mtime is the holder's heartbeat. An inactive session reprints its
# statusline.frozen.<tty> snapshot instead of rendering.

@test "statusline: activetab — first session claims the segment and renders live" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  touch "$BATS_TEST_TMPDIR/tty-a"
  MEDIA_STATUSLINE_TTY="$BATS_TEST_TMPDIR/tty-a" run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stub Song"* ]]
  [ "$(cat "$CLAUDE_PLUGIN_DATA/statusline.tty")" = "$BATS_TEST_TMPDIR/tty-a" ]
  # The live render also lays down this terminal's freeze snapshot.
  [ -f "$CLAUDE_PLUGIN_DATA/statusline.frozen.tty-a" ]
  grep -q "Stub Song" "$CLAUDE_PLUGIN_DATA/statusline.frozen.tty-a"
}

@test "statusline: activetab — another session in use -> frozen line, no update" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  touch -a -t 202601010000 "$BATS_TEST_TMPDIR/tty-a"          # mine: idle
  touch "$BATS_TEST_TMPDIR/tty-b"                             # theirs: in use
  printf '%s' "$BATS_TEST_TMPDIR/tty-b" > "$CLAUDE_PLUGIN_DATA/statusline.tty"
  printf 'FROZEN_LINE' > "$CLAUDE_PLUGIN_DATA/statusline.frozen.tty-a"
  printf 'LIVE_CACHE' > "$CLAUDE_PLUGIN_DATA/statusline.cache"
  MEDIA_STATUSLINE_TTY="$BATS_TEST_TMPDIR/tty-a" run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  # The frozen snapshot is reprinted — not the (newer) shared cache, and
  # no re-render happens.
  [ "$output" = "FROZEN_LINE" ]
  # The holder is untouched by a losing challenger.
  [ "$(cat "$CLAUDE_PLUGIN_DATA/statusline.tty")" = "$BATS_TEST_TMPDIR/tty-b" ]
}

@test "statusline: activetab — first inactive tick bootstraps its freeze from the cache" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  touch -a -t 202601010000 "$BATS_TEST_TMPDIR/tty-a"
  touch "$BATS_TEST_TMPDIR/tty-b"
  printf '%s' "$BATS_TEST_TMPDIR/tty-b" > "$CLAUDE_PLUGIN_DATA/statusline.tty"
  printf 'CACHE_AT_FREEZE' > "$CLAUDE_PLUGIN_DATA/statusline.cache"
  MEDIA_STATUSLINE_TTY="$BATS_TEST_TMPDIR/tty-a" run "$MEDIA" statusline
  [ "$output" = "CACHE_AT_FREEZE" ]
  # ...and stays frozen there even when the active tab moves the cache on.
  printf 'NEWER_CACHE' > "$CLAUDE_PLUGIN_DATA/statusline.cache"
  MEDIA_STATUSLINE_TTY="$BATS_TEST_TMPDIR/tty-a" run "$MEDIA" statusline
  [ "$output" = "CACHE_AT_FREEZE" ]
}

@test "statusline: activetab — fresher input takes the segment over" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  touch "$BATS_TEST_TMPDIR/tty-a"                             # mine: in use
  touch -a -t 202601010000 "$BATS_TEST_TMPDIR/tty-b"          # theirs: idle
  printf '%s' "$BATS_TEST_TMPDIR/tty-b" > "$CLAUDE_PLUGIN_DATA/statusline.tty"
  MEDIA_STATUSLINE_TTY="$BATS_TEST_TMPDIR/tty-a" run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stub Song"* ]]
  [ "$(cat "$CLAUDE_PLUGIN_DATA/statusline.tty")" = "$BATS_TEST_TMPDIR/tty-a" ]
}

@test "statusline: activetab — stopped heartbeat forfeits the segment" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  touch -a -t 202601010000 "$BATS_TEST_TMPDIR/tty-a"          # mine: idle
  touch "$BATS_TEST_TMPDIR/tty-b"                             # theirs: fresher, but
  printf '%s' "$BATS_TEST_TMPDIR/tty-b" > "$CLAUDE_PLUGIN_DATA/statusline.tty"
  touch -t 202601010000 "$CLAUDE_PLUGIN_DATA/statusline.tty"  # ...its session died
  MEDIA_STATUSLINE_TTY="$BATS_TEST_TMPDIR/tty-a" run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stub Song"* ]]
  [ "$(cat "$CLAUDE_PLUGIN_DATA/statusline.tty")" = "$BATS_TEST_TMPDIR/tty-a" ]
}

@test "statusline: activetab — holder tty gone -> takeover" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  touch -a -t 202601010000 "$BATS_TEST_TMPDIR/tty-a"
  printf '%s' "$BATS_TEST_TMPDIR/tty-gone" > "$CLAUDE_PLUGIN_DATA/statusline.tty"
  MEDIA_STATUSLINE_TTY="$BATS_TEST_TMPDIR/tty-a" run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stub Song"* ]]
  [ "$(cat "$CLAUDE_PLUGIN_DATA/statusline.tty")" = "$BATS_TEST_TMPDIR/tty-a" ]
}

@test "statusline: activetab — back in use -> live updates resume" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  touch "$BATS_TEST_TMPDIR/tty-a"                             # mine: in use again
  touch -a -t 202601010000 "$BATS_TEST_TMPDIR/tty-b"
  printf '%s' "$BATS_TEST_TMPDIR/tty-b" > "$CLAUDE_PLUGIN_DATA/statusline.tty"
  printf 'FROZEN_LINE' > "$CLAUDE_PLUGIN_DATA/statusline.frozen.tty-a"
  MEDIA_STATUSLINE_TTY="$BATS_TEST_TMPDIR/tty-a" run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stub Song"* ]]                            # live, not frozen
  grep -q "Stub Song" "$CLAUDE_PLUGIN_DATA/statusline.frozen.tty-a"  # snapshot refreshed
}

@test "statusline: activetab — session without a tty renders live and never competes" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  MEDIA_STATUSLINE_TTY= run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stub Song"* ]]
  [ ! -f "$CLAUDE_PLUGIN_DATA/statusline.tty" ]
  [ -z "$(ls "$CLAUDE_PLUGIN_DATA"/statusline.frozen.* 2>/dev/null)" ]
}

@test "statusline: activetab off -> every session renders" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.activetab":false}' > "$CLAUDE_PLUGIN_DATA/config.json"
  touch -a -t 202601010000 "$BATS_TEST_TMPDIR/tty-a"          # mine: idle
  touch "$BATS_TEST_TMPDIR/tty-b"                             # theirs: in use
  printf '%s' "$BATS_TEST_TMPDIR/tty-b" > "$CLAUDE_PLUGIN_DATA/statusline.tty"
  MEDIA_STATUSLINE_TTY="$BATS_TEST_TMPDIR/tty-a" run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stub Song"* ]]
}

@test "config: statusline.activetab defaults to on and toggles" {
  run "$MEDIA" config statusline.activetab
  [ "$output" = "on" ]
  run "$MEDIA" config statusline.activetab off
  [ "$status" -eq 0 ]
  run "$MEDIA" config statusline.activetab
  [ "$output" = "off" ]
}

# ---- config -----------------------------------------------------------------------

@test "config: no args prints the full key table" {
  run "$MEDIA" config
  [ "$status" -eq 0 ]
  [[ "$output" == *"display.progressbar"* ]]
  [[ "$output" == *"display.statusline"* ]]
}

@test "config: defaults are progressbar=on, statusline=off" {
  run "$MEDIA" config display.progressbar
  [ "$output" = "on" ]
  run "$MEDIA" config display.statusline
  [ "$output" = "off" ]
}

@test "config: unknown key rejected, exit 2" {
  run "$MEDIA" config display.bogus on
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown config key"* ]]
}

@test "config: invalid value rejected, exit 2" {
  run "$MEDIA" config display.progressbar maybe
  [ "$status" -eq 2 ]
}

@test "config: enable statusline passes preflight when a read path works" {
  run "$MEDIA" config display.statusline on
  [ "$status" -eq 0 ]
  run "$MEDIA" config display.statusline
  [ "$output" = "on" ]
}

@test "config: off always succeeds and clears the statusline cache" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  printf 'stale' > "$CLAUDE_PLUGIN_DATA/statusline.cache"
  run "$MEDIA" config display.statusline off
  [ "$status" -eq 0 ]
  [ ! -f "$CLAUDE_PLUGIN_DATA/statusline.cache" ]
}

@test "config: settings persist in config.json" {
  run "$MEDIA" config display.progressbar off
  [ "$status" -eq 0 ]
  run "$MEDIA" config display.progressbar
  [ "$output" = "off" ]
  grep -q '"display.progressbar"' "$CLAUDE_PLUGIN_DATA/config.json"
}

# ---- statusline fields + layout -----------------------------------------------------

@test "statusline.fields: keeps the given order, drops unknown names and dupes" {
  run "$MEDIA" config statusline.fields "time,bogus,track,time"
  [ "$status" -eq 0 ]
  run "$MEDIA" config statusline.fields
  [ "$output" = "time track" ]   # given order kept, bogus + duplicate dropped
}

@test "statusline: fields render in their stored order (time first)" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.fields":["time","progressbar","track"],"statusline.color":false}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" == "1:15/3:20  "* ]]        # time leads...
  [[ "$output" == *"Stub Song"* ]]         # ...track follows
}

@test "statusline: legacy spectrum field in a stored config is ignored" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.fields":["track","spectrum","time"]}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" config statusline.fields
  [ "$output" = "track time" ]             # filtered on read
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stub Song"* ]]
  [[ "$output" == *"1:15"* ]]
  [[ "$output" == *"/3:20"* ]]
}

@test "statusline: multiline keeps adjacent progressbar+time on one line" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.multiline":true,"statusline.color":false,"statusline.fields":["track","progressbar","time"]}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]                 # track / bar+time
  [[ "${lines[1]}" == *"1:15/3:20"* ]]
}

@test "statusline: multiline splits progressbar and time when not adjacent" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.multiline":true,"statusline.color":false,"statusline.fields":["progressbar","track","time"]}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 3 ]                 # bar / track / time
  [[ "${lines[2]}" == "1:15/3:20" ]]
}

@test "statusline: multiline merges output into an adjacent track group" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.multiline":true,"statusline.color":false,"statusline.fields":["track","app","output","progressbar","time"]}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]                 # track+app+output / bar+time
  [[ "${lines[0]}" == *"Stub Song"* ]]
  [[ "${lines[0]}" == *"(StubPlayer)"* ]]  # folded app stays transparent for adjacency
  [[ "${lines[0]}" == *"Stub Speakers"* ]]
  [[ "${lines[1]}" == *"1:15/3:20"* ]]
}

@test "statusline: multiline merges a leading output into the track group" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.multiline":true,"statusline.color":false,"statusline.fields":["output","track","progressbar","time"]}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]                 # output+track / bar+time
  [[ "${lines[0]}" == *"Stub Speakers"* ]]
  [[ "${lines[0]}" == *"Stub Song"* ]]
  [[ "${lines[1]}" == *"1:15/3:20"* ]]
}

@test "statusline: multiline keeps a non-adjacent output on its own line" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.multiline":true,"statusline.color":false,"statusline.fields":["track","app","progressbar","time","output"]}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 3 ]                 # track / bar+time / output — Everything order unchanged
  [[ "${lines[2]}" == *"Stub Speakers"* ]]
}

# ---- statusline explicit per-line layout ("/" breaks) ------------------------------

@test "statusline.fields: / line breaks are stored and normalized" {
  # Glued slashes split like separators; doubled and trailing breaks collapse.
  run "$MEDIA" config statusline.fields "track,app//progressbar,time,/"
  [ "$status" -eq 0 ]
  run "$MEDIA" config statusline.fields
  [ "$output" = "track app / progressbar time" ]
  # A leading break is dropped too.
  run "$MEDIA" config statusline.fields "/,time,track"
  [ "$status" -eq 0 ]
  run "$MEDIA" config statusline.fields
  [ "$output" = "time track" ]
}

@test "statusline: explicit / layout renders the given lines (multiline off)" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["track","app","/","progressbar","time","output"]}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]                 # track+app / bar+time+output
  [[ "${lines[0]}" == *"Stub Song"* ]]
  [[ "${lines[0]}" == *"(StubPlayer)"* ]]  # app right after track still folds
  [[ "${lines[1]}" == *"1:15/3:20"* ]]
  [[ "${lines[1]}" == *"Stub Speakers"* ]]
}

@test "statusline: explicit / layout overrides grouping rules and multiline" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  # progressbar and time end up on separate lines even though the legacy
  # grouping would merge the adjacent pair — the user's breaks win.
  echo '{"display.statusline":true,"statusline.multiline":true,"statusline.color":false,"statusline.fields":["progressbar","/","time","/","track"]}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 3 ]                 # bar / time / track
  [[ "${lines[0]}" != *"1:15"* ]]
  [[ "${lines[1]}" == "1:15/3:20" ]]
  [[ "${lines[2]}" == *"Stub Song"* ]]
}

@test "statusline: explicit layout keeps app standalone unless it follows the track" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["app","track","/","time"]}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [[ "${lines[0]}" == "StubPlayer  "* ]]   # app leads, plain (no parens)
  [[ "${lines[0]}" != *"(StubPlayer)"* ]]
  [[ "${lines[1]}" == "1:15/3:20" ]]
}

@test "statusline: explicit layout drops a line whose items render nothing" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["track","/","output"]}' > "$CLAUDE_PLUGIN_DATA/config.json"
  # The JXA fallback carries no outputDevice, so the output line vanishes.
  STUB_PRIMARY=null STUB_JXA_JSON='{"degraded":true,"title":"Jxa Song","artist":"Jxa Artist","playing":true,"elapsedTime":30,"duration":100}' \
    run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]                 # no blank second line
  [[ "${lines[0]}" == *"Jxa Song"* ]]
}

@test "statusline: only chosen fields render (track only)" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.fields":["track"]}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stub Song"* ]]
  [[ "$output" != *"1:15/3:20"* ]]   # time omitted
}

@test "statusline: multiline layout breaks groups onto separate lines" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.multiline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\n'* ]]          # a line break is present
  [[ "$output" == *"Stub Song"* ]]
}

@test "statusline: inline layout stays on one line" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.multiline":false}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" != *$'\n'* ]]          # single line
}

# ---- statusline colors ---------------------------------------------------------

@test "statusline: ANSI styling present by default" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\e['* ]]         # SGR codes present
  [[ "$output" == *"Stub Song"* ]]    # content intact inside the styling
}

@test "statusline: statusline.color off renders plain text" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.color":false}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" != *$'\e['* ]]
  [[ "$output" == *"Stub Song"* ]]
}

@test "statusline: NO_COLOR env beats the color config" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.color":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  NO_COLOR=1 run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" != *$'\e['* ]]
  [[ "$output" == *"Stub Song"* ]]
}

@test "statusline: time token bolds the elapsed part, dims the total" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  # elapsed (the moving part) is bold, only the "/duration" tail is dim
  [[ "$output" == *$'\e[1m1:15\e[0m\e[2m/3:20\e[0m'* ]]
}

@test "statusline: playing app shows by default" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" == *"(StubPlayer)"* ]]
}

@test "statusline: output field renders the device when selected" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.fields":["track","output"]}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stub Speakers"* ]]
}

@test "statusline: output field omitted by default" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" != *"Stub Speakers"* ]]
}

@test "statusline: output icon follows the device kind" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["output"]}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "🔊 Stub Speakers" ]             # speaker kind (stub default)
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  STUB_OUTPUT_KIND=headphones run "$MEDIA" statusline
  [ "$output" = "🎧 Stub Speakers" ]             # bluetooth / headphone jack
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  STUB_OUTPUT_KIND=display run "$MEDIA" statusline
  [ "$output" = "📺 Stub Speakers" ]             # HDMI / DisplayPort audio
}

# ---- statusline volume field --------------------------------------------------

@test "statusline.fields: volume is a valid field" {
  run "$MEDIA" config statusline.fields "track,volume"
  [ "$status" -eq 0 ]
  run "$MEDIA" config statusline.fields
  [ "$output" = "track volume" ]
}

@test "statusline: volume field renders the system level when selected" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["track","volume"]}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" == *"🔉 ▄ 45%"* ]]          # icon tier + level-height bar + %
}

@test "statusline: volume field omitted by default" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" != *"45%"* ]]
}

@test "statusline: volume icon and bar height follow the level; muted collapses to 🔇" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["volume"]}' > "$CLAUDE_PLUGIN_DATA/config.json"
  STUB_VOLUME=90 run "$MEDIA" statusline
  [ "$output" = "🔊 █ 90%" ]                     # high tier, full-height bar
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"   # beat the 1s TTL between runs
  STUB_VOLUME=50 run "$MEDIA" statusline
  [ "$output" = "🔉 ▄ 50%" ]                     # 50% = half-height bar
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  STUB_VOLUME=10 run "$MEDIA" statusline
  [ "$output" = "🔈 ▁ 10%" ]                     # low tier, sliver bar
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  STUB_MUTED=true run "$MEDIA" statusline
  [ "$output" = "🔇" ]
}

@test "statusline: multiline merges volume into an adjacent track group" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  # The Standard order: a folded app stays transparent, so track and volume
  # count as adjacent and share the first line.
  echo '{"display.statusline":true,"statusline.multiline":true,"statusline.color":false,"statusline.fields":["track","app","volume","progressbar","time"]}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]                 # track+app+volume / bar+time
  [[ "${lines[0]}" == *"(StubPlayer)"* ]]
  [[ "${lines[0]}" == *"🔉 ▄ 45%"* ]]
  [[ "${lines[1]}" == *"1:15/3:20"* ]]
}

@test "statusline: multiline merges volume into an adjacent output group" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.multiline":true,"statusline.color":false,"statusline.fields":["track","progressbar","output","volume"]}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 3 ]                 # track / bar / output+volume
  [[ "${lines[2]}" == *"Stub Speakers"* ]]
  [[ "${lines[2]}" == *"🔉 ▄ 45%"* ]]
}

@test "statusline: explicit layout puts volume on the chosen line" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["track","app","volume","/","progressbar","time","output"]}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]                 # the Stacked preset, two lines
  [[ "${lines[0]}" == *"(StubPlayer)"* ]]
  [[ "${lines[0]}" == *"🔉 ▄ 45%"* ]]
  [[ "${lines[1]}" == *"1:15/3:20"* ]]
  [[ "${lines[1]}" == *"Stub Speakers"* ]]
}

@test "statusline: degraded read drops the volume item (JXA carries no volume)" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["track","/","volume"]}' > "$CLAUDE_PLUGIN_DATA/config.json"
  STUB_PRIMARY=null STUB_JXA_JSON='{"degraded":true,"title":"Jxa Song","artist":"Jxa Artist","playing":true,"elapsedTime":30,"duration":100}' \
    run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]                 # the volume line vanishes, no blank
  [[ "${lines[0]}" == *"Jxa Song"* ]]
}

# ---- per-item statusline styles (style.* keys) ----------------------------------

@test "config style.*: defaults resolve without a config file" {
  run "$MEDIA" config style.track.title
  [ "$output" = "bold" ]
  run "$MEDIA" config style.progressbar.playing
  [ "$output" = "green" ]
  run "$MEDIA" config style.volume.icon
  [ "$output" = "auto" ]
}

@test "config style.*: set persists and canonicalizes token order" {
  run "$MEDIA" config style.track.title "cyan bold"
  [ "$status" -eq 0 ]
  [ "$output" = "style.track.title = bold cyan" ]   # attrs first, color last
  run "$MEDIA" config style.track.title
  [ "$output" = "bold cyan" ]
  grep -q '"style.track.title"' "$CLAUDE_PLUGIN_DATA/config.json"
}

@test "config style.*: multi-word values work unquoted" {
  run "$MEDIA" config style.track.artist bold bright-magenta
  [ "$status" -eq 0 ]
  run "$MEDIA" config style.track.artist
  [ "$output" = "bold bright-magenta" ]
}

@test "config style.*: invalid specs rejected, exit 2" {
  run "$MEDIA" config style.track.title sparkly
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid style token"* ]]
  run "$MEDIA" config style.track.title "red blue"
  [ "$status" -eq 2 ]
  [[ "$output" == *"one color"* ]]
  run "$MEDIA" config style.track.title "none bold"
  [ "$status" -eq 2 ]
  [[ "$output" == *"none cannot be combined"* ]]
}

@test "config style.*: unknown style key rejected, exit 2" {
  run "$MEDIA" config style.bogus.part red
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown style key"* ]]
}

@test "config style.progressbar.style: presets or exactly two glyphs" {
  run "$MEDIA" config style.progressbar.style wave
  [ "$status" -eq 0 ]
  run "$MEDIA" config style.progressbar.style pulse
  [ "$status" -eq 0 ]
  for p in eq notes braille chevron tape cassette retro knob smooth; do
    run "$MEDIA" config style.progressbar.style "$p"
    [ "$status" -eq 0 ]
  done
  run "$MEDIA" config style.progressbar.style "#."
  [ "$status" -eq 0 ]
  run "$MEDIA" config style.progressbar.style "~~~"
  [ "$status" -eq 2 ]
  [[ "$output" == *"blocks|wave|pulse|eq|notes|braille|chevron|tape|cassette|retro|knob|smooth|line|dots"* ]]
}

@test "config style.progressbar.length: whole number of cells 1-60, default 20" {
  run "$MEDIA" config style.progressbar.length
  [ "$output" = "20" ]
  run "$MEDIA" config style.progressbar.length 10
  [ "$status" -eq 0 ]
  [ "$output" = "style.progressbar.length = 10" ]
  run "$MEDIA" config style.progressbar.length "040"   # canonicalized
  [ "$output" = "style.progressbar.length = 40" ]
  for bad in 0 61 -5 1.5 abc "1 0"; do
    run "$MEDIA" config style.progressbar.length "$bad"
    [ "$status" -eq 2 ]
    [[ "$output" == *"1 to 60"* ]]
  done
  run "$MEDIA" config style.progressbar.length reset
  [ "$status" -eq 0 ]
  [ "$output" = "style.progressbar.length = 20 (default)" ]
  run "$MEDIA" config style.progressbar.length
  [ "$output" = "20" ]
}

@test "statusline: bar width follows style.progressbar.length" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  # Default width: 75.4/200 fills 8 of 20 cells.
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["progressbar"]}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "━━━━━━━━────────────" ]
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["progressbar"],"style.progressbar.length":"5"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "━━───" ]                    # 75.4/200 -> 2 of 5 cells
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  # Junk in a hand-edited config falls back to the default width.
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["progressbar"],"style.progressbar.length":"huge"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "━━━━━━━━────────────" ]
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  # The volume progress mini bar keeps its fixed 5 cells (45% -> 2 filled).
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["volume"],"style.volume.style":"progress","style.progressbar.length":"40"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [[ "$output" == *"━━───"* ]]
}

@test "config style.volume.icon: auto, none, or a whitespace-free glyph" {
  run "$MEDIA" config style.volume.icon "♪"
  [ "$status" -eq 0 ]
  run "$MEDIA" config style.volume.icon none
  [ "$status" -eq 0 ]
  run "$MEDIA" config style.volume.icon "a b"
  [ "$status" -eq 2 ]
  [[ "$output" == *"volume icon"* ]]
}

@test "config style.*: reset restores the default and removes the key" {
  run "$MEDIA" config style.time.total "bold red"
  run "$MEDIA" config style.time.total reset
  [ "$status" -eq 0 ]
  [[ "$output" == *"style.time.total = dim (default)"* ]]
  run "$MEDIA" config style.time.total
  [ "$output" = "dim" ]
  ! grep -q '"style.time.total"' "$CLAUDE_PLUGIN_DATA/config.json"
}

@test "config style: lists every key; config style reset clears them all" {
  run "$MEDIA" config style
  [ "$status" -eq 0 ]
  [[ "$output" == *"style.track.title"* ]]
  [[ "$output" == *"style.output"* ]]
  run "$MEDIA" config style.app "bold"
  run "$MEDIA" config style.output "cyan"
  run "$MEDIA" config style reset
  [ "$status" -eq 0 ]
  ! grep -q '"style\.' "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" config style.app
  [ "$output" = "dim" ]
}

@test "config style.*: set drops the statusline cache" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  printf 'stale' > "$CLAUDE_PLUGIN_DATA/statusline.cache"
  run "$MEDIA" config style.app "bold"
  [ "$status" -eq 0 ]
  [ ! -f "$CLAUDE_PLUGIN_DATA/statusline.cache" ]
}

@test "statusline: default styling is unchanged with no style keys set" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\e[1;32m'* ]]                       # bold green icon
  [[ "$output" == *$'\e[1mStub Song\e[0m'* ]]            # bold title
  [[ "$output" == *$'\e[3mStub Artist\e[0m'* ]]          # italic artist
  [[ "$output" == *$'\e[2m(StubPlayer)\e[0m'* ]]         # dim app
  # green fill + dim rest (75.4/200 -> 8 of the default 20 cells)
  [[ "$output" == *$'\e[32m━━━━━━━━\e[0m\e[2m────────────\e[0m'* ]]
}

@test "statusline: style.track.title and style.track.artist restyle their parts" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"style.track.title":"bold cyan","style.track.artist":"none"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\e[1;36mStub Song\e[0m'* ]]   # bold cyan title
  [[ "$output" == *"Stub Artist"* ]]
  [[ "$output" != *$'\e[3m'* ]]                    # none: no italic wrap left
}

@test "statusline: progressbar playing color drives the bar fill and the icon accent" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"style.progressbar.playing":"red"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\e[31m━━━━━━━━\e[0m'* ]]   # red fill (8 of 20 cells)
  [[ "$output" == *$'\e[1;31m'* ]]              # icon: bold + the same accent
}

@test "statusline: progressbar charsets — wave preset and a custom pair" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  # Length pinned to 10 so the charset expectations stay compact — the
  # default width has its own test.
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["progressbar"],"style.progressbar.style":"wave","style.progressbar.length":"10"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  # Fill cycles ▂▄▆▄ over ▁ water, phased by the position (75 % 4 = 3);
  # charset applies even with color off.
  [ "$output" = "▄▆▄▂▁▁▁▁▁▁" ]
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  STUB_ELAPSED=76 run "$MEDIA" statusline
  [ "$output" = "▂▄▆▄▁▁▁▁▁▁" ]              # one second on — the swell rolls right
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["progressbar"],"style.progressbar.style":"pulse","style.progressbar.length":"10"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "▂▂█▁▁▁▁▁▁▁" ]              # ECG beat ▂▂█▁▄, phase 75 % 5 = 0
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["progressbar"],"style.progressbar.style":"#.","style.progressbar.length":"10"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "####......" ]
}

@test "statusline: progressbar charsets — every 0.16.0 preset renders" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  # Length pinned to 10 (compact expectations): stub position 75.4/200 →
  # 4 of 10 cells; rolling fills phase by int(75). knob spends one filled
  # cell on its ● head; smooth measures 30 eighths → 3 full blocks + ▊ (6/8).
  local cases=(
    "eq|█▅▆▂▁▁▁▁▁▁"
    "notes|♫♪♫♪······"
    "braille|⣿⣿⣿⣿⣀⣀⣀⣀⣀⣀"
    "chevron|▸▸▸▸▹▹▹▹▹▹"
    "tape|▰▰▰▰▱▱▱▱▱▱"
    "cassette|▮▮▮▮▯▯▯▯▯▯"
    "retro|====------"
    "knob|━━━●──────"
    "smooth|███▊░░░░░░"
  )
  for c in "${cases[@]}"; do
    rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
    echo "{\"display.statusline\":true,\"statusline.color\":false,\"statusline.fields\":[\"progressbar\"],\"style.progressbar.style\":\"${c%%|*}\",\"style.progressbar.length\":\"10\"}" > "$CLAUDE_PLUGIN_DATA/config.json"
    run "$MEDIA" statusline
    echo "preset ${c%%|*}: got '$output', want '${c#*|}'"
    [ "$output" = "${c#*|}" ]
  done
}

@test "statusline: volume icon override, none, and muted" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["volume"],"style.volume.icon":"♪"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "♪ ▄ 45%" ]
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["volume"],"style.volume.icon":"none"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "▄ 45%" ]
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["volume"],"style.volume.icon":"♪"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  STUB_MUTED=true run "$MEDIA" statusline
  [ "$output" = "🔇" ]                      # muted always shows the mute glyph
}

@test "statusline: volume bar draws in the accent; percent styled separately" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.fields":["volume"]}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  # Since 0.14.0 the bar follows the playing/paused accent (green while
  # playing) — one accent across the segment; the percent keeps its own spec.
  [ "$output" = $'🔉 \e[32m▄\e[0m \e[2m45%\e[0m' ]
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  echo '{"display.statusline":true,"statusline.fields":["volume"],"style.volume.percent":"bold red"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = $'🔉 \e[32m▄\e[0m \e[1;31m45%\e[0m' ]
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  echo '{"display.statusline":true,"statusline.fields":["volume"],"style.progressbar.playing":"red"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = $'🔉 \e[31m▄\e[0m \e[2m45%\e[0m' ]  # accent change recolors the bar
}

@test "config style.volume.bar: an on/off toggle since 0.14.0" {
  run "$MEDIA" config style.volume.bar
  [ "$output" = "on" ]
  run "$MEDIA" config style.volume.bar off
  [ "$status" -eq 0 ]
  [ "$output" = "style.volume.bar = off" ]
  run "$MEDIA" config style.volume.bar show          # alias
  [ "$output" = "style.volume.bar = on" ]
  run "$MEDIA" config style.volume.bar cyan          # specs no longer apply
  [ "$status" -eq 2 ]
  [[ "$output" == *"on/off toggle"* ]]
}

@test "statusline: a legacy volume.bar spec still shows the bar (acts as on)" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.fields":["volume"],"style.volume.bar":"dim"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [ "$output" = $'🔉 \e[32m▄\e[0m \e[2m45%\e[0m' ]   # pre-0.14 config: bar kept
}

@test "statusline: time and output styles apply" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"style.time.total":"italic"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [[ "$output" == *$'\e[1m1:15\e[0m\e[3m/3:20\e[0m'* ]]
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  echo '{"display.statusline":true,"statusline.fields":["output"],"style.output":"bold cyan"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  # Since 0.13.0 the icon stays outside the SGR wrap (so style.output.icon
  # can hide or swap it independently) — visually identical to the old
  # whole-token wrap.
  [ "$output" = $'🔊 \e[1;36mStub Speakers\e[0m' ]
}

@test "config style.volume.style: block, progress, stairs — default is an alias" {
  run "$MEDIA" config style.volume.style
  [ "$output" = "block" ]
  run "$MEDIA" config style.volume.style progress
  [ "$status" -eq 0 ]
  [ "$output" = "style.volume.style = progress" ]
  run "$MEDIA" config style.volume.style default   # alias for the stock shape
  [ "$status" -eq 0 ]
  [ "$output" = "style.volume.style = block" ]
  run "$MEDIA" config style.volume.style zigzag
  [ "$status" -eq 2 ]
  [[ "$output" == *"block|progress|stairs"* ]]
}

@test "config style.output.icon: auto, none (off alias), or a glyph" {
  run "$MEDIA" config style.output.icon
  [ "$output" = "auto" ]
  run "$MEDIA" config style.output.icon "♪"
  [ "$status" -eq 0 ]
  run "$MEDIA" config style.output.icon off        # icons spell hiding as none
  [ "$status" -eq 0 ]
  [ "$output" = "style.output.icon = none" ]
  run "$MEDIA" config style.output.icon "a b"
  [ "$status" -eq 2 ]
  [[ "$output" == *"output icon"* ]]
}

@test "config style.*: off (hide) is a text-part value, alone only" {
  run "$MEDIA" config style.track.artist off
  [ "$status" -eq 0 ]
  [ "$output" = "style.track.artist = off" ]
  run "$MEDIA" config style.track.title "off bold"
  [ "$status" -eq 2 ]
  [[ "$output" == *"off cannot be combined"* ]]
  run "$MEDIA" config style.progressbar.playing off   # bar colors cannot hide
  [ "$status" -eq 2 ]
  [[ "$output" == *"not valid for style.progressbar.playing"* ]]
}

@test "statusline: off hides the title, artist, or app part" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["track","app"],"style.track.artist":"off"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "▶︎ Stub Song (StubPlayer)" ]      # the — separator goes too
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["track","app"],"style.track.title":"off"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "▶︎ Stub Artist (StubPlayer)" ]
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["track","app"],"style.app":"off"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "▶︎ Stub Song — Stub Artist" ]
}

@test "statusline: time parts hide individually" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["time"],"style.time.total":"off"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "1:15" ]
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["time"],"style.time.elapsed":"off"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "3:20" ]                           # no leading slash alone
}

@test "statusline: volume parts hide individually; a fully hidden token drops its line" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["volume"],"style.volume.percent":"off"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "🔉 ▄" ]
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["volume"],"style.volume.bar":"off"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "🔉 45%" ]
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["track","/","volume"],"style.volume.icon":"none","style.volume.bar":"off","style.volume.percent":"off"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "${#lines[@]}" -eq 1 ]                         # the volume line vanishes
  [[ "${lines[0]}" == *"Stub Song"* ]]
}

@test "statusline: volume bar shapes — progress shares the bar charset, stairs steps" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["volume"],"style.volume.style":"progress"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "🔉 ━━─── 45%" ]                   # 45% of 5 cells, line charset
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["volume"],"style.volume.style":"progress","style.progressbar.style":"#."}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "🔉 ##... 45%" ]                   # follows the custom pair
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["volume"],"style.volume.style":"progress","style.progressbar.style":"knob"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "🔉 ━●─── 45%" ]                   # knob head caps the fill
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["volume"],"style.volume.style":"progress","style.progressbar.style":"smooth"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "🔉 ██▎░░ 45%" ]                   # 45% of 5 cells = 18/8 → ▎
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["volume"],"style.volume.style":"stairs"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "🔉 ▂▄ 45%" ]                      # ceil(45*4/100) = 2 steps
}

@test "statusline: output icon hides, swaps, and the name hides" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["output"],"style.output.icon":"none"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "Stub Speakers" ]
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["output"],"style.output.icon":"→"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "→ Stub Speakers" ]
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["output"],"style.output":"off"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "🔊" ]                             # icon-only output item
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["track","/","output"],"style.output.icon":"none","style.output":"off"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "${#lines[@]}" -eq 1 ]                         # nothing left -> line drops
}

@test "config statusline reset: restores arrangement, toggles, and styles" {
  run "$MEDIA" config statusline.fields "time,track"
  run "$MEDIA" config statusline.multiline on
  run "$MEDIA" config statusline.color off
  run "$MEDIA" config statusline.marquee off
  run "$MEDIA" config style.track.title "cyan"
  run "$MEDIA" config display.statusline off
  run "$MEDIA" config history.record off
  printf 'stale' > "$CLAUDE_PLUGIN_DATA/statusline.cache"
  run "$MEDIA" config statusline reset
  [ "$status" -eq 0 ]
  [[ "$output" == *"defaults"* ]]
  [ ! -f "$CLAUDE_PLUGIN_DATA/statusline.cache" ]
  ! grep -q '"statusline\.' "$CLAUDE_PLUGIN_DATA/config.json"
  ! grep -q '"style\.' "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" config statusline.fields
  [ "$output" = "track app progressbar time" ]
  run "$MEDIA" config statusline.color
  [ "$output" = "on" ]
  # The visibility toggle and non-statusline features are NOT appearance:
  run "$MEDIA" config display.statusline
  [ "$output" = "off" ]
  run "$MEDIA" config history.record
  [ "$output" = "off" ]
}

@test "config statusline: only reset is valid" {
  run "$MEDIA" config statusline
  [ "$status" -eq 2 ]
  [[ "$output" == *"config statusline reset"* ]]
  run "$MEDIA" config statusline on
  [ "$status" -eq 2 ]
}

@test "statusline: custom styles are inert with color off and under NO_COLOR" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.color":false,"style.track.title":"bold cyan"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [[ "$output" != *$'\e['* ]]
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  echo '{"display.statusline":true,"style.track.title":"bold cyan"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  NO_COLOR=1 run "$MEDIA" statusline
  [[ "$output" != *$'\e['* ]]
  [[ "$output" == *"Stub Song"* ]]
}

@test "statusline: marquee windows titles wider than 30 cells (default on)" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  STUB_TRACK_TITLE="XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" \
    run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  # 60-cell title: the full string never fits the 30-cell window...
  [[ "$output" != *"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"* ]]
  # ...but a contiguous fragment of it is always visible.
  [[ "$output" == *"XXXXXXXXXX"* ]]
}

@test "statusline: marquee off keeps the full title" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.marquee":false}' > "$CLAUDE_PLUGIN_DATA/config.json"
  STUB_TRACK_TITLE="XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" \
    run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" == *"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"* ]]
}

@test "config: statusline.marquee and history.record default on" {
  run "$MEDIA" config statusline.marquee
  [ "$output" = "on" ]
  run "$MEDIA" config history.record
  [ "$output" = "on" ]
}

@test "config: statusline.color defaults to on and toggles off" {
  run "$MEDIA" config statusline.color
  [ "$output" = "on" ]
  run "$MEDIA" config statusline.color off
  [ "$status" -eq 0 ]
  run "$MEDIA" config statusline.color
  [ "$output" = "off" ]
}

# ---- statusline wiring (settings.json install / uninstall / self-heal) --------

@test "statusline install: fresh settings -> wrapper, statusLine entry, null backup" {
  run "$MEDIA" statusline install
  [ "$status" -eq 0 ]
  [[ "$output" == *"wired into settings.json"* ]]
  [ -x "$HOME/.claude/statusline-media.sh" ]
  grep -q "managed-by: claude-media-control" "$HOME/.claude/statusline-media.sh"
  grep -q 'statusline-media.sh' "$HOME/.claude/settings.json"
  grep -q '"refreshInterval": 1' "$HOME/.claude/settings.json"
  grep -q '"statusLine": null' "$HOME/.claude/statusline-media.backup.json"
}

@test "statusline install: existing statusLine is wrapped, backed up, keys preserved" {
  mkdir -p "$HOME/.claude"
  printf '%s\n' '{"model":"opus","statusLine":{"type":"command","command":"echo OLD-LINE","padding":3,"refreshInterval":5}}' \
    > "$HOME/.claude/settings.json"
  run "$MEDIA" statusline install
  [ "$status" -eq 0 ]
  [[ "$output" == *"previous statusline still runs first"* ]]
  grep -q '"command": "echo OLD-LINE"' "$HOME/.claude/statusline-media.backup.json"
  grep -q 'statusline-media.sh' "$HOME/.claude/settings.json"
  grep -q '"padding": 3' "$HOME/.claude/settings.json"           # merged into the new entry
  grep -q '"refreshInterval": 5' "$HOME/.claude/settings.json"   # explicit interval kept
  grep -q '"model": "opus"' "$HOME/.claude/settings.json"        # unrelated keys intact
  grep -q 'echo OLD-LINE' "$HOME/.claude/statusline-media.sh"    # embedded for pass-through
}

@test "statusline install: idempotent — second run refreshes, backup not clobbered" {
  mkdir -p "$HOME/.claude"
  echo '{"statusLine":{"type":"command","command":"echo OLD-LINE"}}' > "$HOME/.claude/settings.json"
  run "$MEDIA" statusline install
  run "$MEDIA" statusline install
  [ "$status" -eq 0 ]
  [[ "$output" == *"already wired"* ]]
  # The backup still holds the pre-plugin value, not the wrapper pointer.
  grep -q '"command": "echo OLD-LINE"' "$HOME/.claude/statusline-media.backup.json"
  ! grep -q 'statusline-media' "$HOME/.claude/statusline-media.backup.json"
}

@test "statusline install: a manual setup is detected and left untouched" {
  mkdir -p "$HOME/.claude"
  printf '#!/bin/bash\necho MY-CUSTOM\n' > "$HOME/.claude/statusline-media.sh"
  chmod +x "$HOME/.claude/statusline-media.sh"
  echo '{"statusLine":{"type":"command","command":"\"$HOME/.claude/statusline-media.sh\""}}' > "$HOME/.claude/settings.json"
  run "$MEDIA" statusline install
  [ "$status" -eq 0 ]
  [[ "$output" == *"your own setup"* ]]
  grep -q 'MY-CUSTOM' "$HOME/.claude/statusline-media.sh"        # not regenerated
  [ ! -f "$HOME/.claude/statusline-media.backup.json" ]          # nothing backed up
  run "$MEDIA" statusline uninstall
  [ "$status" -eq 1 ]                                            # manual: refuse to touch
  [ -f "$HOME/.claude/statusline-media.sh" ]
}

@test "statusline install: unparseable settings.json refuses to wire" {
  mkdir -p "$HOME/.claude"
  echo '{ not json' > "$HOME/.claude/settings.json"
  run "$MEDIA" statusline install
  [ "$status" -ne 0 ]
  [[ "$output" == *"cannot parse"* ]]
  grep -q 'not json' "$HOME/.claude/settings.json"               # left exactly as it was
  [ ! -f "$HOME/.claude/statusline-media.sh" ]
}

@test "config display.statusline on: wires settings.json automatically" {
  run "$MEDIA" config display.statusline on
  [ "$status" -eq 0 ]
  [[ "$output" == *"wired into settings.json"* ]]
  [[ "$output" == *"display.statusline = on"* ]]
  [ -x "$HOME/.claude/statusline-media.sh" ]
  grep -q 'statusline-media.sh' "$HOME/.claude/settings.json"
}

@test "config display.statusline off: hides the segment but keeps the wiring" {
  run "$MEDIA" config display.statusline on
  run "$MEDIA" config display.statusline off
  [ "$status" -eq 0 ]
  [ -x "$HOME/.claude/statusline-media.sh" ]                     # cheap re-enable later
  grep -q 'statusline-media.sh' "$HOME/.claude/settings.json"
  run bash -c 'printf "{}" | "$HOME/.claude/statusline-media.sh"'
  [ "$status" -eq 0 ]
  [ -z "$output" ]                                               # wired but silent
}

@test "wrapper: previous statusline passes through first, segment appended" {
  mkdir -p "$HOME/.claude"
  echo '{"statusLine":{"type":"command","command":"echo OLD-LINE"}}' > "$HOME/.claude/settings.json"
  run "$MEDIA" config display.statusline on
  [ "$status" -eq 0 ]
  run bash -c 'printf "{}" | "$HOME/.claude/statusline-media.sh"'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "OLD-LINE" ]                                 # byte-for-byte, first
  [[ "${lines[1]}" == *"Stub Song"* ]]                           # segment as its own line
}

@test "wrapper: disabled plugin renders the previous statusline only" {
  mkdir -p "$HOME/.claude/plugins"
  echo '{"statusLine":{"type":"command","command":"echo OLD-LINE"}}' > "$HOME/.claude/settings.json"
  run "$MEDIA" config display.statusline on
  echo '{"version":2,"plugins":{"media@claude-media-control":[{"scope":"user"}]}}' \
    > "$HOME/.claude/plugins/installed_plugins.json"
  # Claude Code records a disable as enabledPlugins: false.
  /usr/bin/perl -MJSON::PP -e '
    local $/; open my $f, "<", $ARGV[0]; my $d = decode_json(<$f>); close $f;
    $d->{enabledPlugins}{"media\@claude-media-control"} = JSON::PP::false;
    open my $o, ">", $ARGV[0]; print $o encode_json($d); close $o;
  ' "$HOME/.claude/settings.json"
  run bash -c 'printf "{}" | "$HOME/.claude/statusline-media.sh"'
  [ "$status" -eq 0 ]
  [ "$output" = "OLD-LINE" ]                                     # no segment, wiring kept
  [ -f "$HOME/.claude/statusline-media.sh" ]
}

@test "wrapper self-heal: uninstalled plugin restores settings and removes itself" {
  mkdir -p "$HOME/.claude"
  echo '{"model":"opus","statusLine":{"type":"command","command":"echo OLD-LINE","padding":3}}' > "$HOME/.claude/settings.json"
  run "$MEDIA" config display.statusline on
  [ "$status" -eq 0 ]
  # Uninstall: no registry entry, and the recorded dev checkout is gone.
  mkdir -p "$HOME/.claude/plugins"
  echo '{"version":2,"plugins":{}}' > "$HOME/.claude/plugins/installed_plugins.json"
  mv "$PLUGIN" "$PLUGIN-gone"
  run bash -c 'printf "{}" | "$HOME/.claude/statusline-media.sh"'
  [ "$status" -eq 0 ]
  [ "$output" = "OLD-LINE" ]                                     # last tick still renders
  grep -q '"command": "echo OLD-LINE"' "$HOME/.claude/settings.json"
  grep -q '"padding": 3' "$HOME/.claude/settings.json"           # object restored verbatim
  ! grep -q 'statusline-media' "$HOME/.claude/settings.json"
  grep -q '"model": "opus"' "$HOME/.claude/settings.json"        # other keys survive
  [ ! -f "$HOME/.claude/statusline-media.sh" ]                   # retired itself
  [ ! -f "$HOME/.claude/statusline-media.backup.json" ]
}

@test "wrapper self-heal: no previous statusline -> statusLine key removed" {
  run "$MEDIA" config display.statusline on
  [ "$status" -eq 0 ]
  mkdir -p "$HOME/.claude/plugins"
  echo '{"version":2,"plugins":{}}' > "$HOME/.claude/plugins/installed_plugins.json"
  mv "$PLUGIN" "$PLUGIN-gone"
  run bash -c 'printf "{}" | "$HOME/.claude/statusline-media.sh"'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  ! grep -q 'statusLine' "$HOME/.claude/settings.json"
  [ ! -f "$HOME/.claude/statusline-media.sh" ]
}

@test "statusline uninstall: restores settings, removes files, toggles off" {
  mkdir -p "$HOME/.claude"
  echo '{"statusLine":{"type":"command","command":"echo OLD-LINE"}}' > "$HOME/.claude/settings.json"
  run "$MEDIA" config display.statusline on
  run "$MEDIA" statusline uninstall
  [ "$status" -eq 0 ]
  [[ "$output" == *"unwired"* ]]
  grep -q '"command": "echo OLD-LINE"' "$HOME/.claude/settings.json"
  ! grep -q 'statusline-media' "$HOME/.claude/settings.json"
  [ ! -f "$HOME/.claude/statusline-media.sh" ]
  [ ! -f "$HOME/.claude/statusline-media.backup.json" ]
  run "$MEDIA" config display.statusline
  [ "$output" = "off" ]
}

@test "statusline status: reflects none -> managed" {
  run "$MEDIA" statusline status
  [ "$status" -eq 0 ]
  [[ "$output" == none* ]]
  run "$MEDIA" statusline install
  run "$MEDIA" statusline status
  [[ "$output" == managed* ]]
}

@test "statusline: unknown subcommand-argument -> usage, exit 2" {
  run "$MEDIA" statusline frobnicate
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage: media.sh"* ]]
}

# ---- statusline cmd+click links (OSC 8 + claude-media:// handler) --------------

@test "config: statusline.links defaults on and round-trips; enable builds the handler" {
  run "$MEDIA" config statusline.links
  [ "$output" = "on" ]
  run "$MEDIA" config statusline.links off
  [ "$status" -eq 0 ]
  run "$MEDIA" config statusline.links
  [ "$output" = "off" ]
  run "$MEDIA" config statusline.links on
  [ "$status" -eq 0 ]
  [ -d "$CLAUDE_PLUGIN_DATA/ClaudeMediaClick.app" ]    # preflight built + registered
}

@test "config statusline.links on: refused (exit 3) when the handler build fails" {
  STUB_CLICK=fail run "$MEDIA" config statusline.links on
  [ "$status" -eq 3 ]
  [[ "$output" == *"click-handler"* ]]
}

@test "statusline: cmd+click links render when the handler app is present" {
  mkdir -p "$CLAUDE_PLUGIN_DATA/ClaudeMediaClick.app"
  echo '{"display.statusline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\e]8;;claude-media://toggle\a'* ]]      # ▶︎/⏸ icon
  [[ "$output" == *$'\e]8;;claude-media://activate\a'* ]]    # title — artist (+ app)
  [[ "$output" == *"claude-media://seek/2"* ]]               # first of 20 bar cells
  [[ "$output" == *"claude-media://seek/97"* ]]              # last bar cell
  [[ "$output" == *"Stub Song"* ]]
}

@test "statusline: every bar cell is its own seek link, glyphs unchanged" {
  mkdir -p "$CLAUDE_PLUGIN_DATA/ClaudeMediaClick.app"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["progressbar"]}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  # Cell i of the default 20 jumps to int((i+0.5)*100/20) percent.
  for pct in 2 7 12 17 22 27 32 37 42 47 52 57 62 67 72 77 82 87 92 97; do
    [[ "$output" == *"claude-media://seek/$pct"* ]]
  done
  # 20 cells x (open + close) = 40 OSC 8 sequences, nothing more.
  [ "$(printf '%s' "$output" | /usr/bin/grep -o ']8;;' | wc -l | tr -d ' ')" -eq 40 ]
  # Stripping the links leaves exactly the unlinked bar (75.4/200 -> 8 cells).
  plain="$(printf '%s' "$output" | /usr/bin/perl -pe 's/\e\]8;;[^\a]*\a//g')"
  [ "$plain" = "━━━━━━━━────────────" ]
  # A custom length re-divides the click map: 4 cells seek to their centers.
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["progressbar"],"style.progressbar.length":"4"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  for pct in 12 37 62 87; do
    [[ "$output" == *"claude-media://seek/$pct"* ]]
  done
  [ "$(printf '%s' "$output" | /usr/bin/grep -o ']8;;' | wc -l | tr -d ' ')" -eq 8 ]
}

@test "statusline: no links without the handler app, with links off, and in the volume bar" {
  # Handler missing: statusline.links defaults on but nothing would answer.
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" != *']8;;'* ]]
  # Handler present but the key off.
  mkdir -p "$CLAUDE_PLUGIN_DATA/ClaudeMediaClick.app"
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  echo '{"display.statusline":true,"statusline.links":false}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" != *']8;;'* ]]
  # The volume mini bar (progress shape) never seeks.
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["volume"],"style.volume.style":"progress"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" != *"seek/"* ]]
}

@test "statusline: NO_COLOR strips styling but keeps the links" {
  mkdir -p "$CLAUDE_PLUGIN_DATA/ClaudeMediaClick.app"
  echo '{"display.statusline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  NO_COLOR=1 run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" != *$'\e['* ]]                                # no SGR
  [[ "$output" == *$'\e]8;;claude-media://toggle\a'* ]]      # links intact
}

@test "statusline install: builds the click handler; uninstall removes it" {
  run "$MEDIA" statusline install
  [ "$status" -eq 0 ]
  [[ "$output" == *"cmd+click enabled"* ]]
  [ -d "$CLAUDE_PLUGIN_DATA/ClaudeMediaClick.app" ]
  [ -x "$CLAUDE_PLUGIN_DATA/click-handler.sh" ]
  run "$MEDIA" statusline uninstall
  [ "$status" -eq 0 ]
  [ ! -d "$CLAUDE_PLUGIN_DATA/ClaudeMediaClick.app" ]
  [ ! -f "$CLAUDE_PLUGIN_DATA/click-handler.sh" ]
}

@test "statusline install: a failed click-handler build never blocks the wiring" {
  STUB_CLICK=fail run "$MEDIA" statusline install
  [ "$status" -eq 0 ]
  [[ "$output" == *"wired into settings.json"* ]]
  [[ "$output" == *"click-handler build failed"* ]]
  [ ! -d "$CLAUDE_PLUGIN_DATA/ClaudeMediaClick.app" ]
}

# ---- open-url (click-action dispatch) -------------------------------------------

@test "open-url: toggle sends the command and prints the re-read state" {
  run "$MEDIA" open-url claude-media://toggle
  [ "$status" -eq 0 ]
  [[ "$output" == *'"title":"Stub Song"'* ]]
}

@test "open-url: seek/<pct> converts the percent to seconds via the duration" {
  run "$MEDIA" open-url claude-media://seek/50
  [ "$status" -eq 0 ]
  [[ "$output" == *'"title":"Stub Song"'* ]]
  [ "$(/bin/cat "$CLAUDE_PLUGIN_DATA/stub-last-seek")" = "100.0" ]   # 50% of 200s
}

@test "open-url: seek without a known duration fails cleanly" {
  STUB_PRIMARY=null STUB_JXA_JSON='{"degraded":true,"title":"X","playing":true}' \
    run "$MEDIA" open-url claude-media://seek/50
  [ "$status" -eq 1 ]
  [[ "$output" == *"duration"* ]]
}

@test "open-url: activate without an identified app fails cleanly" {
  STUB_PRIMARY=null STUB_JXA_JSON='{"degraded":true,"title":"X"}' \
    run "$MEDIA" open-url claude-media://activate
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot activate"* ]]
}

@test "open-url: activate reports when no matching app can be brought forward" {
  # The stub app (com.stub.player, pid 1) is neither a running regular app
  # nor an installed bundle — the chain must fail with a clear message, not
  # hang or launch anything.
  run "$MEDIA" open-url claude-media://activate
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not bring"* ]]
}

@test "open-url: anything but the three actions is rejected, exit 2" {
  for bad in "claude-media://volume/50" "claude-media://seek/" \
             "claude-media://seek/101" "claude-media://seek/1x" \
             "claude-media://seek/5%20" "http://example.com" "" \
             "claude-media://toggle/../seek/5"; do
    run "$MEDIA" open-url "$bad"
    [ "$status" -eq 2 ]
    [[ "$output" == *"open-url"* ]]
  done
}

@test "open-url: control clicks drop the statusline cache" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  printf 'stale' > "$CLAUDE_PLUGIN_DATA/statusline.cache"
  run "$MEDIA" open-url claude-media://toggle
  [ "$status" -eq 0 ]
  [ ! -f "$CLAUDE_PLUGIN_DATA/statusline.cache" ]
}

# ---- removed features ------------------------------------------------------------

@test "spectrum: subcommand no longer exists (removed in 0.6.0)" {
  run "$MEDIA" spectrum
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage: media.sh"* ]]
}

@test "config: display.spectrum is no longer a key" {
  run "$MEDIA" config display.spectrum on
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown config key"* ]]
}

# ---- detect / warmup ----------------------------------------------------------------

@test "detect: healthy (cache present) -> silent, exit 0" {
  "$PLUGIN/scripts/build-native.sh" >/dev/null   # prime the fake cache
  run "$MEDIA" detect
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "detect: no cache but CLT present -> silent (first use will build)" {
  run "$MEDIA" detect
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "warmup: builds the cache and stays silent" {
  run "$MEDIA" warmup
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -f "$CLAUDE_PLUGIN_DATA/stub/libadapter.dylib" ]
}

@test "warmup: never fails even when the build fails" {
  STUB_BUILD=fail run "$MEDIA" warmup
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "warmup: managed wiring with links on (re)creates the click handler" {
  run "$MEDIA" statusline install
  rm -rf "$CLAUDE_PLUGIN_DATA/ClaudeMediaClick.app"    # e.g. wired before 0.17.0
  run "$MEDIA" warmup
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -d "$CLAUDE_PLUGIN_DATA/ClaudeMediaClick.app" ]
}

@test "warmup: no wiring -> never creates the click handler" {
  run "$MEDIA" warmup
  [ "$status" -eq 0 ]
  [ ! -d "$CLAUDE_PLUGIN_DATA/ClaudeMediaClick.app" ]
}
