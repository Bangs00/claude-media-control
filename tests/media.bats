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
  cp "$PROJECT_ROOT/tests/stubs/read-jxa.js" "$PLUGIN/scripts/read-jxa.js"
  cp "$PROJECT_ROOT/tests/stubs/loader.pl" "$PLUGIN/native/loader.pl"
  chmod +x "$PLUGIN/scripts/media.sh" "$PLUGIN/scripts/build-native.sh"
  export CLAUDE_PLUGIN_DATA="$BATS_TEST_TMPDIR/data"
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
  run "$MEDIA" config style.progressbar.style "#."
  [ "$status" -eq 0 ]
  run "$MEDIA" config style.progressbar.style "~~~"
  [ "$status" -eq 2 ]
  [[ "$output" == *"blocks|wave|line|dots"* ]]
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
  [[ "$output" == *$'\e[32m━━━━\e[0m\e[2m──────\e[0m'* ]] # green fill + dim rest
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
  [[ "$output" == *$'\e[31m━━━━\e[0m'* ]]   # red fill
  [[ "$output" == *$'\e[1;31m'* ]]          # icon: bold + the same accent
}

@test "statusline: progressbar charsets — wave preset and a custom pair" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["progressbar"],"style.progressbar.style":"wave"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "~~~~------" ]              # charset applies even with color off
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  echo '{"display.statusline":true,"statusline.color":false,"statusline.fields":["progressbar"],"style.progressbar.style":"#."}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = "####......" ]
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

@test "statusline: volume bar and percent are styled separately (color on)" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"statusline.fields":["volume"]}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = $'🔉 \e[2m▄\e[0m \e[2m45%\e[0m' ]   # plain icon, dim bar + percent
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  echo '{"display.statusline":true,"statusline.fields":["volume"],"style.volume.percent":"bold red"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = $'🔉 \e[2m▄\e[0m \e[1;31m45%\e[0m' ]
}

@test "statusline: time and output styles apply" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"style.time.total":"italic"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [[ "$output" == *$'\e[1m1:15\e[0m\e[3m/3:20\e[0m'* ]]
  rm -f "$CLAUDE_PLUGIN_DATA/statusline.cache"
  echo '{"display.statusline":true,"statusline.fields":["output"],"style.output":"bold cyan"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  run "$MEDIA" statusline
  [ "$output" = $'\e[1;36m🔊 Stub Speakers\e[0m' ]
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
