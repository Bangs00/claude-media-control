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

@test "volume: set drops the cached read (no-op set to the current level)" {
  run "$MEDIA" volume
  if [ "$status" -ne 0 ]; then
    skip "no standard audio output device on this machine"
  fi
  [[ "$output" =~ \"volume\":([0-9]+) ]]
  cur="${BASH_REMATCH[1]}"
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  printf 'stale' > "$CLAUDE_PLUGIN_DATA/now.cache"
  run "$MEDIA" volume "$cur"               # same level: no audible change
  [ "$status" -eq 0 ]
  # The snapshot carries the old level, and the statusline would extrapolate
  # it rather than re-read — so the set has to forget it.
  [ ! -f "$CLAUDE_PLUGIN_DATA/now.cache" ]
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

@test "output: switch drops the cached read" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  printf 'stale' > "$CLAUDE_PLUGIN_DATA/now.cache"
  run "$MEDIA" output "airpods"
  [ "$status" -eq 0 ]
  # The snapshot still names the old device (same rule as volume).
  [ ! -f "$CLAUDE_PLUGIN_DATA/now.cache" ]
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

@test "statusline: on -> one segment line + the read is cached" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stub Song"* ]]
  [[ "$output" == *"Stub Artist"* ]]
  [[ "$output" == *"1:15"* ]]      # elapsed and total are styled separately,
  [[ "$output" == *"/3:20"* ]]     # so SGR codes may sit between them
  # What is cached is the READ, not the rendered line — the line is the
  # animation frame, and caching a frame would freeze the waveform presets.
  [ -f "$CLAUDE_PLUGIN_DATA/now.cache" ]
  run cat "$CLAUDE_PLUGIN_DATA/now.cache"
  [[ "$output" == *'"title":"Stub Song"'* ]]
}

@test "statusline: a fresh cached read is reused instead of re-reading" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  # A snapshot no stub could ever produce: if it renders, the tick did not
  # re-read. Written fresh, so it is inside the serve window.
  printf '%s\n' '{"title":"Cached Only","artist":"From The Cache","playing":true,"elapsedTime":10,"elapsedTimeNow":10,"duration":200,"playbackRate":1,"appName":"CacheApp","bundleIdentifier":"com.example.cache"}' \
    > "$CLAUDE_PLUGIN_DATA/now.cache"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" == *"Cached Only"* ]]
  [[ "$output" != *"Stub Song"* ]]
}

@test "statusline: an expired cached read is re-read, not extrapolated" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  printf '%s\n' '{"title":"Cached Only","artist":"From The Cache","playing":true,"elapsedTime":10,"elapsedTimeNow":10,"duration":200,"playbackRate":1}' \
    > "$CLAUDE_PLUGIN_DATA/now.cache"
  # Older than NOW_CACHE_MAX_SECONDS: too stale to extrapolate honestly (the
  # track may have ended), so the tick pays for a real read instead.
  touch -t 200001010000 "$CLAUDE_PLUGIN_DATA/now.cache"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stub Song"* ]]
  [[ "$output" != *"Cached Only"* ]]
}

@test "statusline: the cached position advances with the clock, not the read" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["time"]}' \
    > "$CLAUDE_PLUGIN_DATA/config.json"
  # Captured at 1:00 of a 3:20 track, two seconds ago: the segment must show
  # 1:02 without re-reading. This is what lets the waveform presets animate
  # at the tick rate while the ~290ms MediaRemote read runs far less often.
  printf '%s\n' '{"title":"Cached Only","playing":true,"elapsedTime":60,"elapsedTimeNow":60,"duration":200,"playbackRate":1}' \
    > "$CLAUDE_PLUGIN_DATA/now.cache"
  /usr/bin/perl -e 'my $t = time - 2; utime $t, $t, $ARGV[0]' "$CLAUDE_PLUGIN_DATA/now.cache"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [ "$output" = "1:02/3:20" ]
}

@test "statusline: a paused cached read does not advance" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["time"]}' \
    > "$CLAUDE_PLUGIN_DATA/config.json"
  # playbackRate 0: the position is where it was left, however long ago that
  # was — so a paused track's animation holds still, as it should.
  printf '%s\n' '{"title":"Cached Only","playing":false,"elapsedTime":60,"elapsedTimeNow":60,"duration":200,"playbackRate":0}' \
    > "$CLAUDE_PLUGIN_DATA/now.cache"
  /usr/bin/perl -e 'my $t = time - 2; utime $t, $t, $ARGV[0]' "$CLAUDE_PLUGIN_DATA/now.cache"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [ "$output" = "1:00/3:20" ]
}

@test "statusline: nothing playing -> empty output" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  STUB_PRIMARY=null run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [ -z "$output" ]
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

@test "config: off always succeeds and the segment goes quiet" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" config display.statusline off
  [ "$status" -eq 0 ]
  # §4.8.1 (off leaves no trace) needs nothing invalidated: the segment is
  # built from scratch each tick, and gated on the toggle before it is built.
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [ -z "$output" ]
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
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  STUB_OUTPUT_KIND=headphones run "$MEDIA" statusline
  [ "$output" = "🎧 Stub Speakers" ]             # bluetooth / headphone jack
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
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
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"   # re-read: the stub changed
  STUB_VOLUME=50 run "$MEDIA" statusline
  [ "$output" = "🔉 ▄ 50%" ]                     # 50% = half-height bar
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  STUB_VOLUME=10 run "$MEDIA" statusline
  [ "$output" = "🔈 ▁ 10%" ]                     # low tier, sliver bar
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
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

@test "config style.*: hex colors accepted and canonicalized, one color max" {
  run "$MEDIA" config style.track.title "bold #FF8800"
  [ "$status" -eq 0 ]
  [ "$output" = "style.track.title = bold #ff8800" ]   # lowercased, color last
  run "$MEDIA" config style.progressbar.playing "#0aF"
  [ "$status" -eq 0 ]
  [ "$output" = "style.progressbar.playing = #00aaff" ]   # short #rgb doubles up
  run "$MEDIA" config style.track.title "#ff88"
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid style token"* ]]
  run "$MEDIA" config style.track.title "#ff8800 red"
  [ "$status" -eq 2 ]
  [[ "$output" == *"one color"* ]]
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
  for p in eq notes braille chevron tape cassette retro knob playhead \
           smooth rise fade corner glide stipple tiles dash \
           spectrum mirror cava ripple swell bars ekg heartbeat monitor; do
    run "$MEDIA" config style.progressbar.style "$p"
    [ "$status" -eq 0 ]
  done
  run "$MEDIA" config style.progressbar.style HEARTBEAT
  [ "$status" -eq 0 ]
  [[ "$output" == *"= heartbeat"* ]]
  run "$MEDIA" config style.progressbar.style "#."
  [ "$status" -eq 0 ]
  run "$MEDIA" config style.progressbar.style "~~~"
  [ "$status" -eq 2 ]
  [[ "$output" == *"blocks|wave|pulse|eq|notes|braille|chevron|tape|cassette|retro|knob|playhead|smooth|rise|fade|corner|glide|stipple|tiles|dash|line|dots"* ]]
}

@test "config style.progressbar.style: validator, error text and help list the same presets" {
  # The roster is spelled out three times in media.sh — the qw() list that
  # validates, the fail() message, and the `config style` help — and nothing in
  # the code keeps them in step. Adding a preset to one and not the others makes
  # a preset that works but is never mentioned, or vice versa.
  local validator errtext helptext
  validator="$(/usr/bin/perl -0777 -ne 'print $1 if /qw\((blocks.*?)\)/s' \
    "$PLUGIN/scripts/media.sh" | tr -s " \n" "\n" | grep . | sort | tr "\n" " ")"
  [ -n "$validator" ]
  run "$MEDIA" config style.progressbar.style "~~~"
  errtext="$(printf '%s' "$output" | /usr/bin/perl -ne \
    'print $1 if /style must be (\S+) or exactly/' | tr "|" "\n" | sort | tr "\n" " ")"
  run "$MEDIA" config style
  helptext="$(printf '%s' "$output" | tr -d " \n" | /usr/bin/perl -ne \
    'print $1 if /style\.progressbar\.style:(.*?)ortwoglyphs/' | tr "|" "\n" | sort | tr "\n" " ")"
  echo "validator: $validator"
  echo "errtext  : $errtext"
  echo "helptext : $helptext"
  [ "$validator" = "$errtext" ]
  [ "$validator" = "$helptext" ]
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
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["progressbar"],"style.progressbar.length":"5"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "━━───" ]                    # 75.4/200 -> 2 of 5 cells
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  # Junk in a hand-edited config falls back to the default width.
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["progressbar"],"style.progressbar.length":"huge"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "━━━━━━━━────────────" ]
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  # The volume progress mini bar keeps its fixed 8 cells (45% -> 4 filled).
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["volume"],"style.volume.style":"progress","style.progressbar.length":"40"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [[ "$output" == *"━━━━────"* ]]
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

@test "config style.*: a set shows on the very next render" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.fields":["app"]}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" config style.app "off"
  [ "$status" -eq 0 ]
  # Only the read is cached, so a style change needs no invalidation at all:
  # the next tick re-renders, and the hidden app takes its whole line with it.
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [ -z "$output" ]
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

@test "statusline: hex colors render as 24-bit truecolor SGR" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  # The stored 3-digit form exercises the renderer's lenient path (the
  # setter would have canonicalized #0af to #00aaff).
  echo '{"display.statusline":true,"style.track.title":"bold #ff8800","style.progressbar.playing":"#0af"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\e[1;38;2;255;136;0mStub Song\e[0m'* ]]   # bold + truecolor title
  [[ "$output" == *$'\e[38;2;0;170;255m━━━━━━━━\e[0m'* ]]      # accent fill: #0af -> 0;170;255
  [[ "$output" == *$'\e[1;38;2;0;170;255m'* ]]                 # icon: bold + the same accent
}

@test "statusline: progressbar charsets — wave preset and a custom pair" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  # Length pinned to 10 so the charset expectations stay compact — the
  # default width has its own test.
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["progressbar"],"style.progressbar.style":"wave","style.progressbar.length":"10"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  # wave is a length-adaptive sine sampled to 8 block levels (▁..█) spanning
  # the whole bar (a field preset); with colors off the unplayed tail
  # (past 75.4/200 = 4/10) is attenuated so progress still reads by height.
  # The phase drifts with the position. Charset applies even with color off.
  [ "$output" = "▅▂▂▆▃▂▁▁▂▃" ]
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  STUB_ELAPSED=76 run "$MEDIA" statusline
  [ "$output" = "▇▃▁▄▃▃▂▁▂▃" ]              # one second on — the wave drifts
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["progressbar"],"style.progressbar.style":"pulse","style.progressbar.length":"10"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "▃▁▆█▁▂▂▁▃▃" ]              # ECG trace: a QRS spike over a flat baseline
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["progressbar"],"style.progressbar.style":"#.","style.progressbar.length":"10"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "####......" ]
}

@test "statusline: progressbar charsets — every 0.16.0 preset renders" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  # Length pinned to 10 (compact expectations): stub position 75.4/200 →
  # 4 of 10 cells. eq/notes are Phase 19 length-adaptive waveforms — field
  # presets spanning the bar with an attenuated tail (eq = multi-frequency
  # heights; notes = ♪♫ density, whose colors-off tail thins to rest
  # dots); knob spends one filled cell on its
  # ● head; smooth measures 30 eighths → 3 full blocks + ▊ (6/8).
  local cases=(
    "eq|▄▃▁▅▂▂▂▂▃▃"
    "notes|♪··♫······"
    "braille|⣿⣿⣿⣿⣀⣀⣀⣀⣀⣀"
    "chevron|▸▸▸▸▹▹▹▹▹▹"
    "tape|▰▰▰▰▱▱▱▱▱▱"
    "cassette|▮▮▮▮▯▯▯▯▯▯"
    "retro|====------"
    "knob|━━━●──────"
    "smooth|███▊░░░░░░"
  )
  for c in "${cases[@]}"; do
    rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
    echo "{\"display.statusline\":true,\"statusline.color\":false,\"statusline.fields\":[\"progressbar\"],\"style.progressbar.style\":\"${c%%|*}\",\"style.progressbar.length\":\"10\"}" > "$CLAUDE_PLUGIN_DATA/config.json"
    run "$MEDIA" statusline
    echo "preset ${c%%|*}: got '$output', want '${c#*|}'"
    [ "$output" = "${c#*|}" ]
  done
}

@test "statusline: progressbar visualizers — spectrum/mirror/cava/ripple span the bar" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  # Field presets (Phase 19) fill the whole bar; with colors off the unplayed
  # tail (past 75.4/200 = 4/10) is attenuated so progress still reads by height.
  local cases=(
    "spectrum|▄▅▇▅▁▂▂▂▂▂"
    "mirror|▃▂▇▆▁▁▂▃▁▂"
    "cava|⣤⣦⢀⣦⣀⡀⢀⣀⣀⠀"
    "ripple|⣄⢀⣾⣦⠀⠀⣀⣀⠀⢀"
  )
  for c in "${cases[@]}"; do
    rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
    echo "{\"display.statusline\":true,\"statusline.color\":false,\"statusline.fields\":[\"progressbar\"],\"style.progressbar.style\":\"${c%%|*}\",\"style.progressbar.length\":\"10\"}" > "$CLAUDE_PLUGIN_DATA/config.json"
    run "$MEDIA" statusline
    echo "preset ${c%%|*}: got '$output', want '${c#*|}'"
    [ "$output" = "${c#*|}" ]
  done
}

@test "statusline: progressbar braille field presets — swell/bars/ekg span the bar" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  # swell/bars mirror wave/eq in braille; ekg is a braille-tuned ECG. Two
  # sub-columns per cell; field presets, so the tail past 4/10 renders
  # attenuated instead of blank.
  local cases=(
    "swell|⣷⡄⢀⣼⣀⠀⠀⣀⣀⠀"
    "bars|⣦⢀⣠⣦⣀⢀⣀⡀⠀⣀"
    "ekg|⣀⣶⣀⣤⠀⠀⠀⣀⠀⢀"
  )
  for c in "${cases[@]}"; do
    rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
    echo "{\"display.statusline\":true,\"statusline.color\":false,\"statusline.fields\":[\"progressbar\"],\"style.progressbar.style\":\"${c%%|*}\",\"style.progressbar.length\":\"10\"}" > "$CLAUDE_PLUGIN_DATA/config.json"
    run "$MEDIA" statusline
    echo "preset ${c%%|*}: got '$output', want '${c#*|}'"
    [ "$output" = "${c#*|}" ]
  done
}

@test "statusline: progressbar ECG twins — the beat spacing does not follow the bar length" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  # heartbeat/monitor are the only waveforms whose shape does NOT scale with the
  # bar: the beat stays 10 cells apart, so a longer bar shows MORE beats rather
  # than a wider one (a stretched beat leaves ~20 dead cells at length 60).
  # Colors on, so the whole bar renders at full amplitude and every beat shows.
  echo '{"display.statusline":true,"statusline.fields":["progressbar"],"style.progressbar.style":"heartbeat","style.progressbar.length":"20"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = $'\e[32m━━┻╋┳━━━\e[0m\e[2m━━━━┻╋┳━━━━━\e[0m' ]
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  echo '{"display.statusline":true,"statusline.fields":["progressbar"],"style.progressbar.style":"heartbeat","style.progressbar.length":"40"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  # Twice the bar, twice the beats, same spacing.
  [ "$output" = $'\e[32m━━┻╋┳━━━━━━━┻╋┳\e[0m\e[2m━━━━━━━┻╋┳━━━━━━━┻╋┳━━━━━\e[0m' ]
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  echo '{"display.statusline":true,"statusline.fields":["progressbar"],"style.progressbar.style":"monitor","style.progressbar.length":"20"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = $'\e[32m⠤⠶⢾⡤⠴⠲⠤⠤\e[0m\e[2m⠤⠤⠤⠶⢾⡤⠴⠲⠤⠤⠤⠤\e[0m' ]
}

@test "statusline: progressbar ECG twins — colors off flatline the unplayed tail" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  # Unlike pulse/ekg, which draw their ECG up from a floor baseline, these two
  # ride a centre line — so the field attenuation has to scale the excursion
  # AROUND that line. Scaling the raw height, as every other preset here does,
  # would drag the baseline itself down. Past 75.4/200 = 4/10 the trace settles
  # flat instead of sagging: an unplayed tail reads as a flatline, which is both
  # the right metaphor and still legible as progress.
  local cases=(
    "heartbeat|━━┻╋━━━━━━"
    "monitor|⠤⠶⢾⡤⠤⠤⠤⠤⠤⠤"
  )
  for c in "${cases[@]}"; do
    rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
    echo "{\"display.statusline\":true,\"statusline.color\":false,\"statusline.fields\":[\"progressbar\"],\"style.progressbar.style\":\"${c%%|*}\",\"style.progressbar.length\":\"10\"}" > "$CLAUDE_PLUGIN_DATA/config.json"
    run "$MEDIA" statusline
    echo "preset ${c%%|*}: got '$output', want '${c#*|}'"
    [ "$output" = "${c#*|}" ]
  done
}

@test "statusline: progressbar field preset — colors split accent/dim without attenuation" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  # With colors ON a field preset spans the whole bar at full amplitude; the
  # accent/dim split (not attenuation) marks progress at 4 of 10 cells.
  echo '{"display.statusline":true,"statusline.fields":["progressbar"],"style.progressbar.style":"spectrum","style.progressbar.length":"10"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [[ "$output" == *$'\e[32m▄▅▇▅\e[0m\e[2m▂▃▆▅▄▅\e[0m'* ]]
  # wave is a field preset too — same split, full-height tail.
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  echo '{"display.statusline":true,"statusline.fields":["progressbar"],"style.progressbar.style":"wave","style.progressbar.length":"10"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [[ "$output" == *$'\e[32m▅▂▂▆\e[0m\e[2m█▅▂▂▆█\e[0m'* ]]
  # notes as well: the dim tail keeps the full ♪♫ density, so only the
  # accent/dim split marks progress (colors off thins it to rest dots).
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  echo '{"display.statusline":true,"statusline.fields":["progressbar"],"style.progressbar.style":"notes","style.progressbar.length":"10"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [[ "$output" == *$'\e[32m♪··♫\e[0m\e[2m♪♫··♪♫\e[0m'* ]]
}

@test "statusline: progressbar spectrum — per-cell seek links, plain glyphs match" {
  mkdir -p "$CLAUDE_PLUGIN_DATA/ClaudeMediaClick.app"
  # A field preset stays fully seekable: 10 cells, each its own link; strip
  # the OSC 8 wrappers and the plain glyphs match the unlinked render.
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["progressbar"],"style.progressbar.style":"spectrum","style.progressbar.length":"10"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$(printf '%s' "$output" | /usr/bin/grep -o ']8;;' | wc -l | tr -d ' ')" -eq 20 ]
  plain="$(printf '%s' "$output" | /usr/bin/perl -pe 's/\e\]8;;[^\a]*\a//g')"
  [ "$plain" = "▄▅▇▅▁▂▂▂▂▂" ]
}

@test "statusline: progressbar rise preset — boundary cell climbs bottom-up" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  # Stub position 75.4/200 at length 10 measures 30 eighths: 3 full
  # blocks + ▆ (6/8) over ░ water. Earlier positions walk the boundary
  # down the ▁..▇ ramp; a nearly-done track still spans exactly 10 cells.
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["progressbar"],"style.progressbar.style":"rise","style.progressbar.length":"10"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "███▆░░░░░░" ]
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  STUB_ELAPSED=65 run "$MEDIA" statusline
  [ "$output" = "███▂░░░░░░" ]              # 26 eighths → ▂
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  STUB_ELAPSED=70 run "$MEDIA" statusline
  [ "$output" = "███▄░░░░░░" ]              # 28 eighths → ▄
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  STUB_ELAPSED=77 run "$MEDIA" statusline
  [ "$output" = "███▇░░░░░░" ]              # 31 eighths → ▇
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  STUB_ELAPSED=80 run "$MEDIA" statusline
  [ "$output" = "████░░░░░░" ]              # 32 eighths — the cell completes
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  STUB_ELAPSED=199 run "$MEDIA" statusline
  [ "$output" = "██████████" ]              # 199.4/200 rounds to full
}

@test "statusline: progressbar rise preset — accent run and per-cell links" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  # Colors on: fill + boundary share one accent run, the rest one dim run.
  echo '{"display.statusline":true,"statusline.fields":["progressbar"],"style.progressbar.style":"rise","style.progressbar.length":"10"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [[ "$output" == *$'\e[32m███▆\e[0m\e[2m░░░░░░\e[0m'* ]]
  # With the handler app present every cell (boundary included) is its own
  # seek link, and stripping the links leaves the plain glyphs.
  mkdir -p "$CLAUDE_PLUGIN_DATA/ClaudeMediaClick.app"
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["progressbar"],"style.progressbar.style":"rise","style.progressbar.length":"10"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$(printf '%s' "$output" | /usr/bin/grep -o ']8;;' | wc -l | tr -d ' ')" -eq 20 ]
  plain="$(printf '%s' "$output" | /usr/bin/perl -pe 's/\e\]8;;[^\a]*\a//g')"
  [ "$plain" = "███▆░░░░░░" ]
}

@test "statusline: progressbar playhead — thick head glides a thin track" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  # Stub position 75.4/200 at length 10: the head's left edge sits at
  # round(0.377 * 18) = 7 half-steps — odd, so it straddles cells 3+4
  # as ╼╾. Aligned positions park it as ━ on one cell, and the ends pin
  # it to the first and last cell (a playhead exists even at 0:00).
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["progressbar"],"style.progressbar.style":"playhead","style.progressbar.length":"10"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "───╼╾─────" ]
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  STUB_ELAPSED=70 run "$MEDIA" statusline
  [ "$output" = "───━──────" ]              # 6.336 → 6 half-steps, aligned
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  STUB_ELAPSED=1 run "$MEDIA" statusline
  [ "$output" = "━─────────" ]              # parked at the start
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  STUB_ELAPSED=199 run "$MEDIA" statusline
  [ "$output" = "─────────━" ]              # pinned to the last cell
}

@test "statusline: progressbar playhead — accent stops at ╼, links per cell" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  # Colors on: elapsed track + ╼ are one accent run; the ╾ half sits in
  # the next (remaining) cell, so it dims with the rest of the track.
  echo '{"display.statusline":true,"statusline.fields":["progressbar"],"style.progressbar.style":"playhead","style.progressbar.length":"10"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [[ "$output" == *$'\e[32m───╼\e[0m\e[2m╾─────\e[0m'* ]]
  # With the handler app present every cell is its own seek link, and
  # stripping the links leaves the plain glyphs.
  mkdir -p "$CLAUDE_PLUGIN_DATA/ClaudeMediaClick.app"
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["progressbar"],"style.progressbar.style":"playhead","style.progressbar.length":"10"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$(printf '%s' "$output" | /usr/bin/grep -o ']8;;' | wc -l | tr -d ' ')" -eq 20 ]
  plain="$(printf '%s' "$output" | /usr/bin/perl -pe 's/\e\]8;;[^\a]*\a//g')"
  [ "$plain" = "───╼╾─────" ]
}

@test "statusline: progressbar sub-cell presets — ramp arity drives the step math" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  # Stub position 75.4/200 at length 10, measured in steps-per-cell
  # (partials + 1): fade thirds → 11 → 3 cells + ▓ (2/3); corner
  # quarters → 15 → 3 cells + ▙ (3/4); stipple sixths → 23 → 3 cells
  # + ⣷ (5/6); dash quarters → 15 → 3 cells + ┉ (3/4); glide and
  # tiles halves → 8 → 4 cells, no partial.
  local cases=(
    "fade|███▓░░░░░░"
    "corner|███▙░░░░░░"
    "stipple|⣿⣿⣿⣷⣀⣀⣀⣀⣀⣀"
    "glide|━━━━──────"
    "tiles|■■■■□□□□□□"
    "dash|━━━┉╌╌╌╌╌╌"
  )
  for c in "${cases[@]}"; do
    rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
    echo "{\"display.statusline\":true,\"statusline.color\":false,\"statusline.fields\":[\"progressbar\"],\"style.progressbar.style\":\"${c%%|*}\",\"style.progressbar.length\":\"10\"}" > "$CLAUDE_PLUGIN_DATA/config.json"
    run "$MEDIA" statusline
    echo "preset ${c%%|*}: got '$output', want '${c#*|}'"
    [ "$output" = "${c#*|}" ]
  done
}

@test "statusline: progressbar stipple preset — braille boundary walks every sixth" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  # Sixths at length 10 (te = int((elapsed+0.4)/200*60 + 0.5)): elapsed
  # 62..77 walks the whole ⣄⣤⣦⣶⣷ ramp, 79 completes the cell.
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["progressbar"],"style.progressbar.style":"stipple","style.progressbar.length":"10"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  STUB_ELAPSED=62 run "$MEDIA" statusline
  [ "$output" = "⣿⣿⣿⣄⣀⣀⣀⣀⣀⣀" ]              # 19 sixths → ⣄
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  STUB_ELAPSED=65 run "$MEDIA" statusline
  [ "$output" = "⣿⣿⣿⣤⣀⣀⣀⣀⣀⣀" ]              # 20 sixths → ⣤
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  STUB_ELAPSED=70 run "$MEDIA" statusline
  [ "$output" = "⣿⣿⣿⣦⣀⣀⣀⣀⣀⣀" ]              # 21 sixths → ⣦
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  STUB_ELAPSED=73 run "$MEDIA" statusline
  [ "$output" = "⣿⣿⣿⣶⣀⣀⣀⣀⣀⣀" ]              # 22 sixths → ⣶
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  STUB_ELAPSED=77 run "$MEDIA" statusline
  [ "$output" = "⣿⣿⣿⣷⣀⣀⣀⣀⣀⣀" ]              # 23 sixths → ⣷
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  STUB_ELAPSED=79 run "$MEDIA" statusline
  [ "$output" = "⣿⣿⣿⣿⣀⣀⣀⣀⣀⣀" ]              # 24 sixths — the cell completes
}

@test "statusline: progressbar glide and tiles — half-cell boundary" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  # Halves at length 10 (S=2): elapsed 65 lands mid-cell (7 halves →
  # 3 cells + ╾/◧), 85 pushes the boundary one cell right, 199 rounds
  # to a full bar.
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["progressbar"],"style.progressbar.style":"glide","style.progressbar.length":"10"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  STUB_ELAPSED=65 run "$MEDIA" statusline
  [ "$output" = "━━━╾──────" ]
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  STUB_ELAPSED=85 run "$MEDIA" statusline
  [ "$output" = "━━━━╾─────" ]
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  STUB_ELAPSED=199 run "$MEDIA" statusline
  [ "$output" = "━━━━━━━━━━" ]
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["progressbar"],"style.progressbar.style":"tiles","style.progressbar.length":"10"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  STUB_ELAPSED=65 run "$MEDIA" statusline
  [ "$output" = "■■■◧□□□□□□" ]
}

@test "statusline: progressbar dash preset — the boundary thickens, then fuses" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  # Quarters at length 10 (S=4): the boundary cell thickens the dashed
  # track (╌ → ╍), then multiplies the dashes until they fuse into the
  # heavy line (┅ ┉ → ━) — ink only ever grows. Elapsed 65 → 13
  # quarters → 3 cells + ╍; 70 → 14 → ┅; 73 → 15 → ┉; 79 → 16 — the
  # cell completes.
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["progressbar"],"style.progressbar.style":"dash","style.progressbar.length":"10"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  STUB_ELAPSED=65 run "$MEDIA" statusline
  [ "$output" = "━━━╍╌╌╌╌╌╌" ]              # 13 quarters → ╍ (1/4)
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  STUB_ELAPSED=70 run "$MEDIA" statusline
  [ "$output" = "━━━┅╌╌╌╌╌╌" ]              # 14 quarters → ┅ (2/4)
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  STUB_ELAPSED=73 run "$MEDIA" statusline
  [ "$output" = "━━━┉╌╌╌╌╌╌" ]              # 15 quarters → ┉ (3/4)
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  STUB_ELAPSED=79 run "$MEDIA" statusline
  [ "$output" = "━━━━╌╌╌╌╌╌" ]              # 16 quarters — the cell fuses
}

@test "statusline: progressbar fade preset — accent run and per-cell links" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  # Colors on: fill + ▓ boundary share one accent run, the rest one dim run.
  echo '{"display.statusline":true,"statusline.fields":["progressbar"],"style.progressbar.style":"fade","style.progressbar.length":"10"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [[ "$output" == *$'\e[32m███▓\e[0m\e[2m░░░░░░\e[0m'* ]]
  # With the handler app present every cell (boundary included) is its own
  # seek link, and stripping the links leaves the plain glyphs.
  mkdir -p "$CLAUDE_PLUGIN_DATA/ClaudeMediaClick.app"
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["progressbar"],"style.progressbar.style":"fade","style.progressbar.length":"10"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$(printf '%s' "$output" | /usr/bin/grep -o ']8;;' | wc -l | tr -d ' ')" -eq 20 ]
  plain="$(printf '%s' "$output" | /usr/bin/perl -pe 's/\e\]8;;[^\a]*\a//g')"
  [ "$plain" = "███▓░░░░░░" ]
}

@test "statusline: volume icon override, none, and muted" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["volume"],"style.volume.icon":"♪"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "♪ ▄ 45%" ]
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["volume"],"style.volume.icon":"none"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "▄ 45%" ]
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
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
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  echo '{"display.statusline":true,"statusline.fields":["volume"],"style.volume.percent":"bold red"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = $'🔉 \e[32m▄\e[0m \e[1;31m45%\e[0m' ]
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
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
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
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
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["track","app"],"style.track.title":"off"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "▶︎ Stub Artist (StubPlayer)" ]
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["track","app"],"style.app":"off"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "▶︎ Stub Song — Stub Artist" ]
}

@test "statusline: time parts hide individually" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["time"],"style.time.total":"off"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "1:15" ]
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["time"],"style.time.elapsed":"off"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "3:20" ]                           # no leading slash alone
}

@test "statusline: volume parts hide individually; a fully hidden token drops its line" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["volume"],"style.volume.percent":"off"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "🔉 ▄" ]
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["volume"],"style.volume.bar":"off"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "🔉 45%" ]
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["track","/","volume"],"style.volume.icon":"none","style.volume.bar":"off","style.volume.percent":"off"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "${#lines[@]}" -eq 1 ]                         # the volume line vanishes
  [[ "${lines[0]}" == *"Stub Song"* ]]
}

@test "statusline: volume bar shapes — progress shares the bar charset, stairs steps" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["volume"],"style.volume.style":"progress"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "🔉 ━━━━──── 45%" ]                # 45% of 8 cells, line charset
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["volume"],"style.volume.style":"progress","style.progressbar.style":"#."}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "🔉 ####.... 45%" ]                # follows the custom pair
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["volume"],"style.volume.style":"progress","style.progressbar.style":"knob"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "🔉 ━━━●──── 45%" ]                # knob head caps the fill
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["volume"],"style.volume.style":"progress","style.progressbar.style":"smooth"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "🔉 ███▋░░░░ 45%" ]                # 45% of 8 cells = 29/8 → ▋
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["volume"],"style.volume.style":"progress","style.progressbar.style":"rise"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "🔉 ███▅░░░░ 45%" ]                # same 29/8, rising ramp → ▅
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["volume"],"style.volume.style":"progress","style.progressbar.style":"stipple"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "🔉 ⣿⣿⣿⣶⣀⣀⣀⣀ 45%" ]              # 45% in sixths = 22/6 → ⣶
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["volume"],"style.volume.style":"stairs"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "🔉 ▁▂▃▄ 45%" ]                    # ceil(45*8/100) = 4 steps
}

@test "statusline: output icon hides, swaps, and the name hides" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["output"],"style.output.icon":"none"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "Stub Speakers" ]
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["output"],"style.output.icon":"→"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "→ Stub Speakers" ]
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["output"],"style.output":"off"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "🔊" ]                             # icon-only output item
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
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
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
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

# ---- statusline cmd+click links (OSC 8 + claude-media-control:// handler) ------

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
  [[ "$output" == *$'\e]8;;claude-media-control://toggle\a'* ]]   # ▶︎/⏸ icon
  [[ "$output" == *$'\e]8;;claude-media-control://activate\a'* ]] # title — artist (+ app)
  [[ "$output" == *"claude-media-control://seek/2"* ]]            # first of 20 bar cells
  [[ "$output" == *"claude-media-control://seek/97"* ]]           # last bar cell
  [[ "$output" != *']8;;claude-media://'* ]]                      # legacy scheme retired
  [[ "$output" == *"Stub Song"* ]]
}

@test "statusline: every bar cell is its own seek link, glyphs unchanged" {
  mkdir -p "$CLAUDE_PLUGIN_DATA/ClaudeMediaClick.app"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["progressbar"]}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  # Cell i of the default 20 jumps to int((i+0.5)*100/20) percent.
  for pct in 2 7 12 17 22 27 32 37 42 47 52 57 62 67 72 77 82 87 92 97; do
    [[ "$output" == *"claude-media-control://seek/$pct"* ]]
  done
  # 20 cells x (open + close) = 40 OSC 8 sequences, nothing more.
  [ "$(printf '%s' "$output" | /usr/bin/grep -o ']8;;' | wc -l | tr -d ' ')" -eq 40 ]
  # Stripping the links leaves exactly the unlinked bar (75.4/200 -> 8 cells).
  plain="$(printf '%s' "$output" | /usr/bin/perl -pe 's/\e\]8;;[^\a]*\a//g')"
  [ "$plain" = "━━━━━━━━────────────" ]
  # A custom length re-divides the click map: 4 cells seek to their centers.
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["progressbar"],"style.progressbar.length":"4"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  for pct in 12 37 62 87; do
    [[ "$output" == *"claude-media-control://seek/$pct"* ]]
  done
  [ "$(printf '%s' "$output" | /usr/bin/grep -o ']8;;' | wc -l | tr -d ' ')" -eq 8 ]
}

@test "statusline: no links without the handler app, with links off, and in the volume bar" {
  # Handler missing: statusline.links defaults on but nothing would answer
  # (and nothing may be built from the render path — never-created stays so).
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" != *']8;;'* ]]
  [ ! -d "$CLAUDE_PLUGIN_DATA/ClaudeMediaClick.app" ]
  # Handler present but the key off.
  mkdir -p "$CLAUDE_PLUGIN_DATA/ClaudeMediaClick.app"
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  echo '{"display.statusline":true,"statusline.links":false}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" != *']8;;'* ]]
  # The volume mini bar (progress shape) never seeks.
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["volume"],"style.volume.style":"progress"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" != *"seek/"* ]]
}

# ---- per-part links (statusline.links as a list) ------------------------------

@test "statusline.links: a list round-trips; on/off stay the all/none shorthands" {
  run "$MEDIA" config statusline.links "toggle,seek"
  [ "$status" -eq 0 ]
  run "$MEDIA" config statusline.links
  [ "$output" = "toggle seek" ]
  # Normalized to VALID_STATUSLINE_LINKS order — links are a set, not a layout.
  run "$MEDIA" config statusline.links "seek app toggle"
  [ "$status" -eq 0 ]
  run "$MEDIA" config statusline.links
  [ "$output" = "toggle app seek" ]
  # Every part reads back as the "on" it is.
  run "$MEDIA" config statusline.links "toggle,track,app,seek"
  run "$MEDIA" config statusline.links
  [ "$output" = "on" ]
  run "$MEDIA" config statusline.links off
  run "$MEDIA" config statusline.links
  [ "$output" = "off" ]
}

@test "statusline.links: unknown names drop; a list naming nothing valid is an error" {
  run "$MEDIA" config statusline.links "toggle,bogus,seek"
  [ "$status" -eq 0 ]
  run "$MEDIA" config statusline.links
  [ "$output" = "toggle seek" ]
  # All-bogus is a typo, not an intent to switch links off.
  run "$MEDIA" config statusline.links "bogus,nonsense"
  [ "$status" -eq 2 ]
  [[ "$output" == *"statusline.links"* ]]
}

@test "statusline.links: a stored boolean still means all/none" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  # What every config written before per-part links holds.
  echo '{"statusline.links":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" config statusline.links
  [ "$output" = "on" ]
  echo '{"statusline.links":false}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" config statusline.links
  [ "$output" = "off" ]
  # An empty list is "none" — not "unset", which would read as the default.
  echo '{"statusline.links":[]}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" config statusline.links
  [ "$output" = "off" ]
}

@test "statusline.links: each part links independently of the others" {
  mkdir -p "$CLAUDE_PLUGIN_DATA/ClaudeMediaClick.app"
  local p
  # One part on at a time: only that part's action may appear.
  for p in toggle track app seek; do
    rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
    echo "{\"display.statusline\":true,\"statusline.color\":false,\"statusline.fields\":[\"track\",\"app\",\"progressbar\"],\"statusline.links\":[\"$p\"]}" \
      > "$CLAUDE_PLUGIN_DATA/config.json"
    run "$MEDIA" statusline
    [ "$status" -eq 0 ]
    case "$p" in
      toggle)
        [[ "$output" == *"://toggle"* ]]
        [[ "$output" != *"://activate"* ]]
        [[ "$output" != *"://seek/"* ]]
        ;;
      track | app)
        # track and app share the activate action, so what distinguishes them
        # is which text carries it: the title, or the "(StubPlayer)" tail.
        [[ "$output" == *"://activate"* ]]
        [[ "$output" != *"://toggle"* ]]
        [[ "$output" != *"://seek/"* ]]
        if [ "$p" = "track" ]; then
          [[ "$output" == *"activate"*"Stub Song"* ]]
          [[ "$output" != *"activate"*"(StubPlayer)"* ]]
        else
          [[ "$output" == *"activate"*"(StubPlayer)"* ]]
          [[ "$output" != *"activate"*"Stub Song"* ]]
        fi
        ;;
      seek)
        [[ "$output" == *"://seek/"* ]]
        [[ "$output" != *"://toggle"* ]]
        [[ "$output" != *"://activate"* ]]
        ;;
    esac
  done
}

@test "statusline.links: a part switched off renders byte-identically to links off" {
  mkdir -p "$CLAUDE_PLUGIN_DATA/ClaudeMediaClick.app"
  local with without
  # The bar is the one that matters: with seek off its fill must collapse back
  # to a single SGR run, exactly as it does with links off entirely.
  echo '{"display.statusline":true,"statusline.fields":["progressbar"],"statusline.links":["toggle","track","app"]}' \
    > "$CLAUDE_PLUGIN_DATA/config.json"
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  with="$("$MEDIA" statusline)"
  echo '{"display.statusline":true,"statusline.fields":["progressbar"],"statusline.links":false}' \
    > "$CLAUDE_PLUGIN_DATA/config.json"
  rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
  without="$("$MEDIA" statusline)"
  [ -n "$without" ]
  [ "$with" = "$without" ]
}

@test "statusline.links: a non-empty list still builds the handler; off never does" {
  run "$MEDIA" config statusline.links "toggle"
  [ "$status" -eq 0 ]
  [ -d "$CLAUDE_PLUGIN_DATA/ClaudeMediaClick.app" ]     # preflight built it
  rm -rf "$CLAUDE_PLUGIN_DATA/ClaudeMediaClick.app"
  run "$MEDIA" config statusline.links off
  [ "$status" -eq 0 ]
  [ ! -d "$CLAUDE_PLUGIN_DATA/ClaudeMediaClick.app" ]
  # A list is refused (exit 3) when the build fails, exactly as "on" is: a
  # link nothing answers is worse than no link.
  STUB_CLICK=fail run "$MEDIA" config statusline.links "seek"
  [ "$status" -eq 3 ]
  [[ "$output" == *"click-handler"* ]]
}

# ---- bar (the /media:now progress bar) --------------------------------------

@test "bar: the progress bar alone — no colors, no links, honors the charset" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"style.progressbar.style":"line","style.progressbar.length":"10"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" bar
  [ "$status" -eq 0 ]
  [ "$output" = "━━━━──────" ]
}

@test "bar: byte-identical to the statusline progressbar token, for every preset" {
  # The whole point of the subcommand: /media:now and the statusline draw the
  # bar with one builder, so they cannot disagree about what a preset looks
  # like. Presets that are computed waveforms could never be kept in step by a
  # prose table in the skill — which is exactly how they drifted before.
  #
  # Both calls read fresh (the cache is dropped before each), so both render
  # the stub's position with nothing extrapolated on top: same builder, same
  # instant. Left to extrapolate, the two would legitimately differ by the
  # milliseconds between them — a live bar is supposed to move.
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  local seg bar p
  for p in line blocks heartbeat monitor wave pulse eq notes spectrum mirror \
           cava ripple swell bars ekg playhead smooth rise fade corner glide \
           stipple tiles dash knob braille chevron tape cassette retro dots "#-"; do
    echo "{\"display.statusline\":true,\"statusline.color\":false,\"statusline.links\":false,\"statusline.fields\":[\"progressbar\"],\"style.progressbar.style\":\"$p\",\"style.progressbar.length\":\"20\"}" > "$CLAUDE_PLUGIN_DATA/config.json"
    rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
    seg="$("$MEDIA" statusline)"
    rm -f "$CLAUDE_PLUGIN_DATA/now.cache"
    bar="$("$MEDIA" bar)"
    echo "preset $p: statusline='$seg' bar='$bar'"
    [ -n "$bar" ]
    [ "$seg" = "$bar" ]
  done
}

@test "bar: display.progressbar off prints nothing" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.progressbar":false}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" bar
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "bar: nothing playing prints nothing" {
  STUB_PRIMARY=null run "$MEDIA" bar
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "bar: a track with no duration prints nothing" {
  # A live stream has no duration to measure against, so /media:now drops the
  # bar line and shows "m:ss / LIVE" instead.
  STUB_PRIMARY=fail \
    STUB_JXA_JSON='{"degraded":true,"title":"Live Set","artist":"Radio","playing":true,"elapsedTimeNow":42.0}' \
    run "$MEDIA" bar
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "statusline: NO_COLOR strips styling but keeps the links" {
  mkdir -p "$CLAUDE_PLUGIN_DATA/ClaudeMediaClick.app"
  echo '{"display.statusline":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  NO_COLOR=1 run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" != *$'\e['* ]]                                        # no SGR
  [[ "$output" == *$'\e]8;;claude-media-control://toggle\a'* ]]      # links intact
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
  run "$MEDIA" open-url claude-media-control://toggle
  [ "$status" -eq 0 ]
  [[ "$output" == *'"title":"Stub Song"'* ]]
}

@test "open-url: seek/<pct> converts the percent to seconds via the duration" {
  run "$MEDIA" open-url claude-media-control://seek/50
  [ "$status" -eq 0 ]
  [[ "$output" == *'"title":"Stub Song"'* ]]
  [ "$(/bin/cat "$CLAUDE_PLUGIN_DATA/stub-last-seek")" = "100.0" ]   # 50% of 200s
}

@test "open-url: the legacy claude-media:// scheme still dispatches" {
  # Links rendered by still-open pre-0.29 sessions keep working: the applet
  # claims both schemes and open-url accepts both.
  run "$MEDIA" open-url claude-media://toggle
  [ "$status" -eq 0 ]
  [[ "$output" == *'"title":"Stub Song"'* ]]
  run "$MEDIA" open-url claude-media://seek/50
  [ "$status" -eq 0 ]
  [ "$(/bin/cat "$CLAUDE_PLUGIN_DATA/stub-last-seek")" = "100.0" ]
}

@test "open-url: seek without a known duration fails cleanly" {
  STUB_PRIMARY=null STUB_JXA_JSON='{"degraded":true,"title":"X","playing":true}' \
    run "$MEDIA" open-url claude-media-control://seek/50
  [ "$status" -eq 1 ]
  [[ "$output" == *"duration"* ]]
}

@test "open-url: activate without an identified app fails cleanly" {
  STUB_PRIMARY=null STUB_JXA_JSON='{"degraded":true,"title":"X"}' \
    run "$MEDIA" open-url claude-media-control://activate
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot activate"* ]]
}

@test "open-url: activate reports when no matching app can be brought forward" {
  # The stub app (com.stub.player, pid 1) is neither a running regular app
  # nor an installed bundle — the chain must fail with a clear message, not
  # hang or launch anything.
  run "$MEDIA" open-url claude-media-control://activate
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not bring"* ]]
}

@test "open-url: anything but the three actions is rejected, exit 2" {
  for bad in "claude-media-control://volume/50" "claude-media-control://seek/" \
             "claude-media-control://seek/101" "claude-media-control://seek/1x" \
             "claude-media-control://seek/5%20" "http://example.com" "" \
             "claude-media-control://toggle/../seek/5" \
             "claude-media://volume/50" "claude-media://seek/" \
             "claude-media://toggle/../seek/5"; do
    run "$MEDIA" open-url "$bad"
    [ "$status" -eq 2 ]
    [[ "$output" == *"open-url"* ]]
  done
}

@test "open-url: control clicks refresh the cached read" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  printf '%s\n' '{"title":"Stale Click","playing":false,"elapsedTime":1,"elapsedTimeNow":1,"duration":200,"playbackRate":0}' \
    > "$CLAUDE_PLUGIN_DATA/now.cache"
  run "$MEDIA" open-url claude-media-control://toggle
  [ "$status" -eq 0 ]
  # The click changed the state, so the snapshot behind it is void — and the
  # re-read that follows the command replaces it. This is what flips the icon
  # on the next tick instead of a serve-window later.
  run cat "$CLAUDE_PLUGIN_DATA/now.cache"
  [[ "$output" != *"Stale Click"* ]]
  [[ "$output" == *"Stub Song"* ]]
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
