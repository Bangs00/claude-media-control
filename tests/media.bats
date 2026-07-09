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
  [[ "$output" == *"1:15/3:20"* ]]
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

@test "statusline.fields: set, canonicalize order, drop unknown names" {
  run "$MEDIA" config statusline.fields "time,bogus,track"
  [ "$status" -eq 0 ]
  run "$MEDIA" config statusline.fields
  [ "$output" = "track time" ]   # canonical order, bogus dropped
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

@test "statusline: spectrum bars default to a solid cyan tint" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"display.spectrum":true,"statusline.fields":["spectrum"]}' > "$CLAUDE_PLUGIN_DATA/config.json"
  STUB_SPECTRUM=signal run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\e[36m'* ]]      # solid cyan (the default spectrum.color)
  [[ "$output" != *$'\e[31m'* ]]      # not amplitude/rainbow tinted
}

@test "statusline: spectrum.color picks the solid tint" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"display.spectrum":true,"statusline.fields":["spectrum"],"spectrum.color":"magenta"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  STUB_SPECTRUM=signal run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\e[35m'* ]]
  [[ "$output" != *$'\e[36m'* ]]
}

@test "statusline: rainbow spectrum cycles colors by band position" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"display.spectrum":true,"statusline.fields":["spectrum"],"spectrum.style":"rainbow","spectrum.color":"magenta"}' > "$CLAUDE_PLUGIN_DATA/config.json"
  STUB_SPECTRUM=signal run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  # 10 bands cover the whole 6-color cycle whatever the phase; the configured
  # solid color is ignored (it appears only as one cycle member among six).
  [[ "$output" == *$'\e[31m'* ]]
  [[ "$output" == *$'\e[34m'* ]]
  [[ "$output" == *$'\e[36m'* ]]
}

@test "config: spectrum.style/color defaults, persistence, validation" {
  run "$MEDIA" config spectrum.style
  [ "$output" = "solid" ]
  run "$MEDIA" config spectrum.color
  [ "$output" = "cyan" ]
  run "$MEDIA" config spectrum.style rainbow
  [ "$status" -eq 0 ]
  run "$MEDIA" config spectrum.style
  [ "$output" = "rainbow" ]
  run "$MEDIA" config spectrum.color blue
  [ "$status" -eq 0 ]
  run "$MEDIA" config spectrum.color
  [ "$output" = "blue" ]
  run "$MEDIA" config spectrum.style diagonal
  [ "$status" -eq 2 ]
  run "$MEDIA" config spectrum.color chartreuse
  [ "$status" -eq 2 ]
}

@test "config: statusline.color defaults to on and toggles off" {
  run "$MEDIA" config statusline.color
  [ "$output" = "on" ]
  run "$MEDIA" config statusline.color off
  [ "$status" -eq 0 ]
  run "$MEDIA" config statusline.color
  [ "$output" = "off" ]
}

# ---- spectrum -----------------------------------------------------------------------

@test "spectrum: refused when display.spectrum is off (opt-in)" {
  run "$MEDIA" spectrum
  [ "$status" -eq 3 ]
  [[ "$output" == *"spectrum is off"* ]]
}

@test "spectrum: snapshot prints a spectrum line when enabled + signal" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.spectrum":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  STUB_SPECTRUM=signal run "$MEDIA" spectrum
  [ "$status" -eq 0 ]
  [[ "$output" == *"16kHz"* ]]
}

@test "spectrum: enable preflight passes when capture has signal" {
  STUB_SPECTRUM=signal run "$MEDIA" config display.spectrum on
  [ "$status" -eq 0 ]
  run "$MEDIA" config display.spectrum
  [ "$output" = "on" ]
}

@test "spectrum: enable refused (fail-closed) when capture is silent but audio plays" {
  # STUB_PRIMARY defaults to a playing track; a silent capture => missing grant.
  STUB_SPECTRUM=silence run "$MEDIA" config display.spectrum on
  [ "$status" -eq 3 ]
  [[ "$output" == *"permission"* ]]
}

@test "spectrum: enable refused when the helper is unavailable" {
  STUB_SPECTRUM=unavailable run "$MEDIA" config display.spectrum on
  [ "$status" -eq 3 ]
  [[ "$output" == *"unavailable"* ]]
}

@test "spectrum: runtime silence while playing auto-disables the feature" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.spectrum":true}' > "$CLAUDE_PLUGIN_DATA/config.json"
  STUB_SPECTRUM=silence run "$MEDIA" spectrum
  [ "$status" -eq 3 ]
  [[ "$output" == *"revoked"* ]]
  run "$MEDIA" config display.spectrum
  [ "$output" = "off" ]              # downgraded to off
}

@test "statusline: spectrum field appends bars when enabled" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"display.spectrum":true,"statusline.fields":["track","spectrum"]}' > "$CLAUDE_PLUGIN_DATA/config.json"
  STUB_SPECTRUM=signal run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stub Song"* ]]
  [[ "$output" == *"▄"* ]]           # spectrum bars present
}

@test "statusline: spectrum field silently omitted when display.spectrum off" {
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo '{"display.statusline":true,"display.spectrum":false,"statusline.fields":["track","spectrum"]}' > "$CLAUDE_PLUGIN_DATA/config.json"
  STUB_SPECTRUM=signal run "$MEDIA" statusline
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stub Song"* ]]
  [[ "$output" != *"▄"* ]]           # no bars: feature is off
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
