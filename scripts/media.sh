#!/bin/bash
# media.sh — single dispatcher for the "media" Claude Code plugin.
#
# Subcommands:
#   now                          now-playing state, one JSON line (or "null")
#   play|pause|toggle|next|prev  send a playback command, then re-read state
#   seek <seconds>               jump to an absolute position, then re-read
#   artwork [path-prefix]        save current artwork to a file, print JSON
#   volume [0-100]               system output volume get/set, one JSON line
#   statusline                   one-line segment for a statusline (TTL cache)
#   test                         primary-path self-check (exit code only)
#   config [key] [on|off]        display-feature toggles (fail-closed enable)
#   doctor [--rebuild]           full diagnosis (+ optional cache rebuild)
#   detect                       SessionStart hook probe: silent when healthy
#   warmup                       SessionStart async hook: pre-build the dylib
#
# Backend order: perl+dylib primary -> JXA read fallback -> per-app
# AppleScript control fallback (Spotify / Apple Music only). All errors point
# at the next action (usually /media:doctor). No third-party tools are used;
# JSON handling relies on the JSON::PP module bundled with macOS perl.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# CLAUDE_PLUGIN_DATA is injected inside Claude Code sessions. Statusline
# commands (and direct shell use) run outside a session without it, so fall
# back to the known plugin data locations — both worlds must share one
# config + build cache. Last resort: ~/.cache (older Claude Code versions).
resolve_data_dir() {
  if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
    echo "$CLAUDE_PLUGIN_DATA"
    return
  fi
  local d
  for d in "$HOME/.claude/plugins/data/media-claude-media-control" \
           "$HOME/.claude/plugins/data/media-inline"; do
    if [ -d "$d" ]; then
      echo "$d"
      return
    fi
  done
  echo "$HOME/.cache/claude-media-control"
}
DATA_DIR="$(resolve_data_dir)"
CONFIG_FILE="$DATA_DIR/config.json"
LOADER="$PLUGIN_ROOT/native/loader.pl"

usage() {
  cat >&2 <<'EOF'
usage: media.sh <subcommand>
  now | play | pause | toggle | next | prev | seek <seconds>
  artwork [path-prefix] | volume [0-100] | statusline
  test | config [key] [on|off] | doctor [--rebuild] | detect | warmup
EOF
  exit 2
}

cmd="${1:-}"
[ -n "$cmd" ] || usage

# ---- OS guard -------------------------------------------------------------
if [ "$(uname -s)" != "Darwin" ]; then
  if [ "$cmd" = "detect" ]; then
    echo "media plugin: macOS only — /media: commands are unavailable on this OS."
    exit 0
  fi
  echo "media: this plugin controls the macOS system now-playing service and only works on macOS." >&2
  exit 1
fi

# ---- backend helpers --------------------------------------------------------

LIB=""

# Resolve (building if necessary) the native dylib. Sets LIB; empty means
# degraded mode. Build progress/errors go to stderr from build-native.sh.
ensure_native() {
  LIB="$("$SCRIPT_DIR/build-native.sh" || true)"
}

primary_get() { /usr/bin/perl "$LOADER" "$LIB" adapter_get 2>/dev/null; }
primary_test() { /usr/bin/perl "$LOADER" "$LIB" adapter_test; }
primary_send() { MEDIA_SEND_COMMAND="$1" /usr/bin/perl "$LOADER" "$LIB" adapter_send >/dev/null 2>&1; }
primary_seek() { MEDIA_SEEK_SECONDS="$1" /usr/bin/perl "$LOADER" "$LIB" adapter_seek >/dev/null 2>&1; }
primary_artwork() { MEDIA_ARTWORK_PATH="$1" /usr/bin/perl "$LOADER" "$LIB" adapter_artwork 2>/dev/null; }

jxa_read() { /usr/bin/osascript -l JavaScript "$SCRIPT_DIR/read-jxa.js" 2>/dev/null || echo "null"; }

# Extract a scalar field from a JSON object on stdin (empty when absent).
json_field() {
  /usr/bin/perl -MJSON::PP -e '
    local $/; my $d = eval { decode_json(<STDIN>) };
    exit 0 unless ref $d eq "HASH";
    my $v = $d->{$ARGV[0]};
    print $v if defined $v && !ref $v;
  ' "$1" 2>/dev/null
}

# ---- now --------------------------------------------------------------------

# Prints one JSON line ("null" when nothing plays). Exit 0 unless every
# backend failed to run.
do_now() {
  ensure_native
  if [ -n "$LIB" ]; then
    local out=""
    if out="$(primary_get)" && [ -n "$out" ]; then
      if [ "$out" != "null" ]; then
        echo "$out"
        return 0
      fi
      # Primary sees nothing. Cross-check with the independent JXA path to
      # distinguish "nothing playing" from "primary read blocked".
      local jxa
      jxa="$(jxa_read)"
      if [ "$jxa" != "null" ] && [ -n "$jxa" ]; then
        echo "media: native read returned nothing but the fallback sees media — the primary path may be broken. Run /media:doctor." >&2
        echo "$jxa"
        return 0
      fi
      echo "null"
      return 0
    fi
    echo "media: native read failed — using fallback. Run /media:doctor if this persists." >&2
  fi
  jxa_read
}

# ---- control ----------------------------------------------------------------

# AppleScript per-app control (fallback). Args: bundleId action [seconds].
# Never launches an app that is not already running.
control_applescript() {
  local bundle="$1" action="$2" arg="${3:-}" app=""
  case "$bundle" in
    com.spotify.client) app="Spotify" ;;
    com.apple.Music)    app="Music" ;;
    *)
      echo "media: degraded control supports only Spotify and Apple Music (current app: ${bundle:-unknown}). Run /media:doctor." >&2
      return 3
      ;;
  esac
  local running
  running="$(/usr/bin/osascript -e "application \"$app\" is running" 2>/dev/null || echo false)"
  if [ "$running" != "true" ]; then
    echo "media: $app is not running — fallback control skipped (apps are never auto-launched)." >&2
    return 4
  fi
  local script=""
  case "$action" in
    play)   script="play" ;;
    pause)  script="pause" ;;
    toggle) script="playpause" ;;
    next)   script="next track" ;;
    prev)   script="previous track" ;;
    seek)   script="set player position to $arg" ;;
    *) return 2 ;;
  esac
  if ! /usr/bin/osascript -e "tell application \"$app\" to $script" >/dev/null 2>&1; then
    echo "media: AppleScript control of $app failed — likely an Automation permission issue (error -1743). Approve your terminal app under System Settings > Privacy & Security > Automation, or run /media:doctor." >&2
    return 1
  fi
  return 0
}

# Send a playback command through the best available backend, then print the
# resulting now-playing state.
do_control() {
  local action="$1" id="$2"
  ensure_native
  if [ -n "$LIB" ] && primary_send "$id"; then
    sleep 0.5
    do_now
    return 0
  fi
  if [ -n "$LIB" ]; then
    echo "media: native command failed — trying AppleScript fallback. Run /media:doctor if this persists." >&2
  fi
  local bundle
  bundle="$(jxa_read | json_field bundleIdentifier)"
  control_applescript "$bundle" "$action"
  sleep 0.5
  do_now
}

do_seek() {
  local seconds="${1:-}"
  case "$seconds" in
    ''|*[!0-9.]*|.|*.*.*)
      echo "media: seek requires an absolute position in seconds (e.g. media.sh seek 90)." >&2
      exit 2
      ;;
  esac
  ensure_native
  if [ -n "$LIB" ] && primary_seek "$seconds"; then
    sleep 0.5
    do_now
    return 0
  fi
  if [ -n "$LIB" ]; then
    echo "media: native seek failed — trying AppleScript fallback. Run /media:doctor if this persists." >&2
  fi
  local bundle
  bundle="$(jxa_read | json_field bundleIdentifier)"
  control_applescript "$bundle" seek "$seconds"
  sleep 0.5
  do_now
}

# ---- artwork ------------------------------------------------------------------

# Save the current track's artwork to <prefix>.<jpg|png|bin> and print
# {"path":…,"bytes":…} JSON ("null" when the track has no artwork). The image
# never enters the conversation as base64 — only its path does. Default prefix
# lives in $TMPDIR so the OS cleans it up (§4.7: no stray files).
do_artwork() {
  local prefix="${1:-}"
  if [ -z "$prefix" ]; then
    local tmp="${TMPDIR:-/tmp}"
    prefix="${tmp%/}/claude-media-artwork"
  fi
  ensure_native
  if [ -z "$LIB" ]; then
    echo "media: artwork needs the native helper — the JXA fallback cannot read artwork. Run /media:doctor." >&2
    exit 1
  fi
  local out=""
  if ! out="$(primary_artwork "$prefix")" || [ -z "$out" ]; then
    echo "media: artwork read failed. Run /media:doctor." >&2
    exit 1
  fi
  echo "$out"
}

# ---- volume ---------------------------------------------------------------------

# System output volume via AppleScript's `volume settings` (public API — no
# MediaRemote involved). With an argument, sets 0-100 first; always prints the
# resulting {"volume":N,"muted":bool} JSON.
do_volume() {
  local target="${1:-}"
  if [ -n "$target" ]; then
    case "$target" in
      *[!0-9]*)
        echo "media: volume must be an integer between 0 and 100 (got: $target)." >&2
        exit 2
        ;;
    esac
    if [ "$target" -gt 100 ]; then
      echo "media: volume must be an integer between 0 and 100 (got: $target)." >&2
      exit 2
    fi
    if ! /usr/bin/osascript -e "set volume output volume $target" >/dev/null 2>&1; then
      echo "media: setting the system volume failed. Run /media:doctor." >&2
      exit 1
    fi
  fi
  local vol muted
  vol="$(/usr/bin/osascript -e 'output volume of (get volume settings)' 2>/dev/null || true)"
  muted="$(/usr/bin/osascript -e 'output muted of (get volume settings)' 2>/dev/null || true)"
  case "$vol" in
    ''|*[!0-9]*)
      echo "media: could not read the system output volume (no standard output device?)." >&2
      exit 1
      ;;
  esac
  [ "$muted" = "true" ] || muted="false"
  printf '{"volume":%s,"muted":%s}\n' "$vol" "$muted"
}

# ---- statusline -----------------------------------------------------------------

STATUSLINE_TTL_SECONDS=5

# One-line now-playing segment for a statusline command. Statuslines fire on
# every conversation event (plus optional refreshInterval polling), so this
# must answer instantly: a TTL file cache absorbs the perl+dylib startup cost
# and the real read runs at most once per TTL window. Empty output (and no
# trailing newline) when the feature is off or nothing is playing — the
# wrapper recipe in docs/statusline.md relies on that to add no extra line.
do_statusline() {
  [ "$(config_get display.statusline)" = "on" ] || return 0
  local cache="$DATA_DIR/statusline.cache"
  local now_epoch mtime age
  now_epoch="$(/bin/date +%s)"
  if [ -f "$cache" ]; then
    mtime="$(/usr/bin/stat -f %m "$cache" 2>/dev/null || echo 0)"
    age=$((now_epoch - mtime))
    if [ "$age" -ge 0 ] && [ "$age" -lt "$STATUSLINE_TTL_SECONDS" ]; then
      cat "$cache"
      return 0
    fi
  fi
  local json line=""
  json="$(do_now 2>/dev/null || echo null)"
  if [ -n "$json" ] && [ "$json" != "null" ]; then
    line="$(printf '%s' "$json" | /usr/bin/perl -MJSON::PP -e '
      binmode STDOUT, ":utf8";
      local $/; my $d = eval { decode_json(<STDIN>) };
      exit 0 unless ref $d eq "HASH" && defined $d->{title};
      sub mss { my $s = int($_[0]); sprintf "%d:%02d", $s / 60, $s % 60 }
      my $line = ($d->{playing} ? "\x{25B6}\x{FE0E}" : "\x{23F8}") . " $d->{title}";
      $line .= " \x{2014} $d->{artist}" if defined $d->{artist};
      my $pos = $d->{elapsedTimeNow} // $d->{elapsedTime};
      if (defined $pos) {
        $line .= "  " . mss($pos);
        $line .= "/" . mss($d->{duration}) if defined $d->{duration};
      }
      print $line;
    ' 2>/dev/null || true)"
  fi
  mkdir -p "$DATA_DIR" 2>/dev/null || true
  printf '%s' "$line" > "$cache" 2>/dev/null || true
  printf '%s' "$line"
  return 0
}

# ---- config (§4.9: fail-closed enable) ---------------------------------------

CONFIG_KEYS="display.progressbar display.statusline"

config_default() {
  case "$1" in
    display.progressbar) echo on ;;
    display.statusline)  echo off ;;
    *) return 1 ;;
  esac
}

config_get() {
  local key="$1" v=""
  if [ -f "$CONFIG_FILE" ]; then
    v="$(/usr/bin/perl -MJSON::PP -e '
      local $/; my $d = eval { decode_json(<STDIN>) };
      exit 0 unless ref $d eq "HASH";
      my $v = $d->{$ARGV[0]};
      print($v ? "on" : "off") if defined $v;
    ' "$key" < "$CONFIG_FILE" 2>/dev/null)"
  fi
  if [ -n "$v" ]; then echo "$v"; else config_default "$key"; fi
}

config_write() {
  mkdir -p "$DATA_DIR"
  /usr/bin/perl -MJSON::PP -e '
    my ($file, $key, $val) = @ARGV;
    my $d = {};
    if (-f $file) {
      local $/;
      if (open my $fh, "<", $file) { $d = eval { decode_json(<$fh>) } || {}; close $fh; }
      $d = {} unless ref $d eq "HASH";
    }
    $d->{$key} = ($val eq "on") ? JSON::PP::true : JSON::PP::false;
    open my $fh, ">", "$file.tmp" or die "cannot write config: $!\n";
    print $fh JSON::PP->new->canonical->encode($d), "\n";
    close $fh;
    rename "$file.tmp", $file or die "cannot save config: $!\n";
  ' "$CONFIG_FILE" "$1" "$2"
}

# Preflight gate for enabling a display feature. Enabling is refused (exit 3)
# when the feature cannot actually work right now — fail-closed by design.
config_preflight() {
  case "$1" in
    display.progressbar)
      return 0
      ;;
    display.statusline)
      if do_now >/dev/null 2>&1; then
        return 0
      fi
      echo "media: cannot enable display.statusline — no working now-playing read path (native and fallback both failed). Run /media:doctor first." >&2
      return 3
      ;;
  esac
}

config_known() {
  local k
  for k in $CONFIG_KEYS; do
    [ "$k" = "$1" ] && return 0
  done
  echo "media: unknown config key: $1 (valid keys: $CONFIG_KEYS)" >&2
  return 2
}

do_config() {
  local key="${1:-}" value="${2:-}"
  if [ -z "$key" ]; then
    local k
    echo "key                   value  notes"
    for k in $CONFIG_KEYS; do
      local note=""
      case "$k" in
        display.progressbar) note="progress bar in /media:now output" ;;
        display.statusline)  note="statusline segment (recipe: docs/statusline.md); enable checks a read path" ;;
      esac
      printf '%-21s %-6s %s\n' "$k" "$(config_get "$k")" "$note"
    done
    echo ""
    echo "usage: media.sh config <key> [on|off]   (config file: $CONFIG_FILE)"
    return 0
  fi
  config_known "$key" || exit 2
  if [ -z "$value" ]; then
    config_get "$key"
    return 0
  fi
  case "$value" in
    on)
      config_preflight "$key" || exit 3
      config_write "$key" on
      echo "$key = on"
      ;;
    off)
      # Disabling is always allowed, no preconditions.
      config_write "$key" off
      # A stale segment cache must not outlive the toggle (§4.8.1: off leaves
      # no trace, not even a cached line).
      [ "$key" = "display.statusline" ] && rm -f "$DATA_DIR/statusline.cache"
      echo "$key = off"
      ;;
    *)
      echo "media: config value must be 'on' or 'off' (got: $value)" >&2
      exit 2
      ;;
  esac
}

# ---- doctor -------------------------------------------------------------------

do_doctor() {
  if [ "${1:-}" = "--rebuild" ]; then
    echo "[rebuild] clearing native build cache..."
    "$SCRIPT_DIR/build-native.sh" --rebuild >/dev/null || true
  fi

  echo "media doctor — $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""
  echo "[1] OS          : macOS $(/usr/bin/sw_vers -productVersion) (build $(/usr/bin/sw_vers -buildVersion)), $(/usr/bin/uname -m)"

  local clt="missing"
  if clt_path="$(/usr/bin/xcode-select -p 2>/dev/null)"; then
    clt="$clt_path"
  fi
  echo "[2] Xcode CLT   : $clt"

  local cache
  if cache="$("$SCRIPT_DIR/build-native.sh" --check-only 2>/dev/null)"; then
    echo "[3] Build cache : ok — $cache"
  else
    echo "[3] Build cache : missing (will build on first use; data dir: $DATA_DIR)"
  fi

  local primary_state="unavailable" primary_rc=0
  ensure_native
  if [ -n "$LIB" ]; then
    set +e
    primary_test >/dev/null 2>&1
    primary_rc=$?
    set -e
    case "$primary_rc" in
      0) primary_state="ok (now-playing metadata readable)" ;;
      5) primary_state="reachable, no now-playing info (nothing playing, or read blocked)" ;;
      2) primary_state="FAILED — MediaRemote symbols not resolved (macOS changed the framework?)" ;;
      3) primary_state="FAILED — mediaremoted did not respond" ;;
      *) primary_state="FAILED (exit $primary_rc)" ;;
    esac
  fi
  echo "[4] Primary path: $primary_state"

  local jxa
  jxa="$(jxa_read)"
  if [ "$jxa" != "null" ] && [ -n "$jxa" ]; then
    echo "[5] JXA fallback: ok — sees now-playing data"
  else
    echo "[5] JXA fallback: reachable, no now-playing data"
  fi

  # Cross-check disambiguates "nothing playing" from "primary blocked".
  local verdict=""
  if [ -n "$LIB" ] && [ "$primary_rc" = "0" ]; then
    verdict="PRIMARY OK — full functionality."
  elif [ "$primary_rc" = "5" ] && [ "$jxa" != "null" ] && [ -n "$jxa" ]; then
    verdict="PRIMARY READ LIKELY BLOCKED — fallback sees media but the native path does not. Try: media.sh doctor --rebuild (a macOS update may have broken the technique — please report it)."
  elif [ "$primary_rc" = "5" ]; then
    verdict="PRIMARY OK — nothing is playing right now (both paths agree)."
  elif [ -z "$LIB" ]; then
    verdict="DEGRADED — native helper unavailable (see [2]/[3]); reads use JXA, control is limited to Spotify/Apple Music. Install Xcode CLT with: xcode-select --install"
  else
    verdict="PRIMARY FAILED — reads/control fall back to AppleScript. Try: media.sh doctor --rebuild"
  fi

  echo "[6] Automation  : AppleScript fallback asks for permission on first use (System Settings > Privacy & Security > Automation)"
  echo "[7] Config      : progressbar=$(config_get display.progressbar) statusline=$(config_get display.statusline) ($CONFIG_FILE)"
  echo "[8] Build log   : $DATA_DIR/build.log"
  echo ""
  echo "verdict: $verdict"
}

# ---- detect (SessionStart hook: silent unless something needs attention) -----

do_detect() {
  trap 'exit 0' ERR
  set +e
  # Healthy or self-healing situations stay silent: cache present, or cache
  # absent but CLT available (first use builds automatically).
  if "$SCRIPT_DIR/build-native.sh" --check-only >/dev/null 2>&1; then
    exit 0
  fi
  if ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
    echo "media plugin: Xcode Command Line Tools not found — running in degraded mode (fallback only). Run /media:doctor for details."
  fi
  exit 0
}

# ---- warmup (SessionStart async hook: pre-build so first use has no delay) ----

# Runs in the background (hooks.json `async: true`), so it never blocks the
# session. Strictly best-effort and always silent: build failures are left for
# the first real command / doctor to surface.
do_warmup() {
  trap 'exit 0' ERR
  set +e
  "$SCRIPT_DIR/build-native.sh" >/dev/null 2>&1
  exit 0
}

# ---- dispatch -----------------------------------------------------------------

case "$cmd" in
  now)        do_now ;;
  play)       do_control play 0 ;;
  pause)      do_control pause 1 ;;
  toggle)     do_control toggle 2 ;;
  next)       do_control next 4 ;;
  prev)       do_control prev 5 ;;
  seek)       do_seek "${2:-}" ;;
  artwork)    do_artwork "${2:-}" ;;
  volume)     do_volume "${2:-}" ;;
  statusline) do_statusline ;;
  test)
    ensure_native
    if [ -z "$LIB" ]; then
      echo "media: native helper unavailable — degraded mode. Run /media:doctor." >&2
      exit 1
    fi
    primary_test
    ;;
  config) do_config "${2:-}" "${3:-}" ;;
  doctor) do_doctor "${2:-}" ;;
  detect) do_detect ;;
  warmup) do_warmup ;;
  *) usage ;;
esac
