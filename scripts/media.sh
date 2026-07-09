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
  spectrum [snapshot | --live <seconds>]
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

# Resolve (building if necessary) the spectrum helper. Sets SPECTRUM_BIN;
# empty means unavailable (macOS < 14.4, no CLT, or build failure). Opt-in and
# independent of the adapter — never built by the SessionStart warmup.
SPECTRUM_BIN=""
ensure_spectrum() {
  SPECTRUM_BIN="$("$SCRIPT_DIR/build-native.sh" --spectrum 2>/dev/null || true)"
}

primary_get() { /usr/bin/perl "$LOADER" "$LIB" adapter_get 2>/dev/null; }
primary_test() { /usr/bin/perl "$LOADER" "$LIB" adapter_test; }
primary_send() { MEDIA_SEND_COMMAND="$1" /usr/bin/perl "$LOADER" "$LIB" adapter_send >/dev/null 2>&1; }
primary_seek() { MEDIA_SEEK_SECONDS="$1" /usr/bin/perl "$LOADER" "$LIB" adapter_seek >/dev/null 2>&1; }
primary_artwork() { MEDIA_ARTWORK_PATH="$1" /usr/bin/perl "$LOADER" "$LIB" adapter_artwork 2>/dev/null; }

jxa_read() { /usr/bin/osascript -l JavaScript "$SCRIPT_DIR/read-jxa.js" 2>/dev/null || echo "null"; }

# Extract a scalar field from a JSON object on stdin (empty when absent).
# JSON booleans decode to blessed refs, so map those to "true"/"false" rather
# than dropping them — callers test fields like `playing` this way.
json_field() {
  /usr/bin/perl -MJSON::PP -e '
    local $/; my $d = eval { decode_json(<STDIN>) };
    exit 0 unless ref $d eq "HASH";
    my $v = $d->{$ARGV[0]};
    exit 0 unless defined $v;
    if (ref $v) { print $v ? "true" : "false"; }
    else        { print $v; }
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

# ---- spectrum coloring ------------------------------------------------------

# Tint spectrum block glyphs (stdin line stream) per the spectrum.style /
# spectrum.color config. solid wraps each glyph run in the one configured
# color; rainbow assigns a fixed front-to-back color cycle by bar position —
# never amplitude — whose phase advances each second so it marches across
# refreshes. Non-glyph text (Hz labels, peak note) is left untouched.
spectrum_colorize() {
  /usr/bin/perl -CS -e '
    $| = 1;
    my ($style, $name) = @ARGV;
    my %sgr = (red=>31, green=>32, yellow=>33, blue=>34,
               magenta=>35, cyan=>36, white=>37);
    my @cycle = (31, 33, 32, 36, 34, 35);
    my $c = $sgr{$name} // 36;
    while (my $line = <STDIN>) {
      if ($style eq "rainbow") {
        my $phase = time() % @cycle;
        my $i = 0;
        $line =~ s/([\x{2581}-\x{2588}])/"\e[" . $cycle[($phase + $i++) % @cycle] . "m$1\e[0m"/ge;
      } else {
        $line =~ s/([\x{2581}-\x{2588}]+)/\e[${c}m$1\e[0m/g;
      }
      print $line;
    }
  ' "$(config_get_str spectrum.style solid)" "$(config_get_str spectrum.color cyan)"
}

# ---- statusline -----------------------------------------------------------------

# Short cache window: a now-read costs ~60ms, so a 1s TTL keeps high-frequency
# statusline re-runs cheap while letting the elapsed time and progress bar
# advance every second (paired with a small `refreshInterval` — see
# docs/statusline.md; idle statuslines otherwise refresh only on events).
STATUSLINE_TTL_SECONDS=1

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
  local fields json line="" multiline sep color
  fields="$(config_get_statusline_fields)"
  multiline="$(config_get statusline.multiline)"
  # NO_COLOR (https://no-color.org) beats the config key. The cache may serve
  # a line rendered under the other setting for at most one TTL second.
  color="$(config_get statusline.color)"
  [ -n "${NO_COLOR:-}" ] && color=off
  if [ "$multiline" = "on" ]; then sep=$'\n'; else sep="  "; fi
  json="$(do_now 2>/dev/null || echo null)"
  if [ -n "$json" ] && [ "$json" != "null" ]; then
    # Render the chosen fields as groups (track / progress+time), joined by two
    # spaces inline or a newline in multiline layout. Fields the user didn't
    # pick are omitted; Claude Code renders multi-line statuslines as-is.
    # Styling (statusline.color on): state-colored icon + filled bar (green
    # playing / yellow paused), bold title, italic artist, dim chrome. Claude
    # Code statuslines render ANSI SGR codes; every token resets with \e[0m so
    # surrounding statusline content is never restyled.
    line="$(printf '%s' "$json" | /usr/bin/perl -MJSON::PP -e '
      binmode STDOUT, ":utf8";
      my %w = map { $_ => 1 } split /\s+/, ($ARGV[0] // "");
      my $ml = ($ARGV[1] // "") eq "on";
      my $c  = ($ARGV[2] // "") eq "on";
      local $/; my $d = eval { decode_json(<STDIN>) };
      exit 0 unless ref $d eq "HASH" && defined $d->{title};
      sub mss { my $s = int($_[0]); sprintf "%d:%02d", $s / 60, $s % 60 }
      my $st = sub {
        my ($codes, $t) = @_;
        ($c && length $t) ? "\e[${codes}m$t\e[0m" : $t;
      };
      my $accent = $d->{playing} ? 32 : 33;
      my @groups;
      if ($w{track}) {
        my $icon = $d->{playing} ? "\x{25B6}\x{FE0E}" : "\x{23F8}";
        my $t = $st->("1;$accent", $icon) . " " . $st->(1, $d->{title});
        $t .= " " . $st->(2, "\x{2014}") . " " . $st->(3, $d->{artist})
          if defined $d->{artist};
        push @groups, $t;
      }
      my $pos = $d->{elapsedTimeNow} // $d->{elapsedTime};
      my $dur = $d->{duration};
      my @prog;
      if ($w{progressbar} && defined $pos && defined $dur && $dur > 0) {
        my $cells = 10;
        my $r = $pos / $dur; $r = 0 if $r < 0; $r = 1 if $r > 1;
        my $filled = int($r * $cells + 0.5);
        push @prog, $st->($accent, "\x{2588}" x $filled)
                  . $st->(2, "\x{2591}" x ($cells - $filled));
      }
      if ($w{time} && defined $pos) {
        push @prog, $st->(2, mss($pos) . "/" . (defined $dur ? mss($dur) : "LIVE"));
      }
      push @groups, join("  ", @prog) if @prog;
      print join($ml ? "\n" : "  ", @groups);
    ' "$fields" "$multiline" "$color" 2>/dev/null || true)"

    # spectrum field: a real capture (~0.5s), so it is gated on the field being
    # chosen AND display.spectrum on AND the helper being available. It rides
    # the same statusline cache, so the capture runs at most once per TTL.
    case " $fields " in
      *" spectrum "*)
        if [ "$(config_get display.spectrum)" = "on" ]; then
          ensure_spectrum
          if [ -n "$SPECTRUM_BIN" ]; then
            local bars
            bars="$("$SPECTRUM_BIN" bars 10 2>/dev/null || true)"
            if [ -n "$bars" ] && [ "$color" = "on" ]; then
              bars="$(printf '%s' "$bars" | spectrum_colorize 2>/dev/null || printf '%s' "$bars")"
            fi
            if [ -n "$bars" ]; then
              if [ -n "$line" ]; then line="$line$sep$bars"; else line="$bars"; fi
            fi
          fi
        fi
        ;;
    esac
  fi
  mkdir -p "$DATA_DIR" 2>/dev/null || true
  printf '%s' "$line" > "$cache" 2>/dev/null || true
  printf '%s' "$line"
  return 0
}

# ---- spectrum (Phase 4, opt-in) ----------------------------------------------

# Render the system output spectrum. Gated on display.spectrum, which required
# the audio-recording permission at enable time. If a capture is silent while
# audio is playing the grant was revoked at runtime, so we downgrade the
# feature to off (§4.9 fail-closed) instead of printing an empty spectrum.
do_spectrum() {
  local a1="${1:-}" a2="${2:-}"
  if [ "$(config_get display.spectrum)" != "on" ]; then
    echo "media: the audio spectrum is off. Enable it with /media:config display.spectrum on (it needs the system-audio-recording permission)." >&2
    exit 3
  fi
  ensure_spectrum
  if [ -z "$SPECTRUM_BIN" ]; then
    echo "media: the spectrum helper is unavailable (needs macOS 14.4+ and Xcode Command Line Tools). Run /media:doctor." >&2
    exit 1
  fi
  # `|| rc=$?` keeps a non-zero exit (e.g. 3 = silence) from tripping set -e
  # before the downgrade logic below can run. With pipefail, the helper's
  # exit code survives the tint pipe (the perl filter itself exits 0).
  #
  # Direct terminal runs get the spectrum.style/spectrum.color tint; captured
  # output (the skill's inline command, tests, scripts) stays plain so the
  # conversation never sees raw escape codes.
  local rc=0 tint="cat"
  if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then tint="spectrum_colorize"; fi
  case "$a1" in
    '' | snapshot)
      "$SPECTRUM_BIN" snapshot | $tint || rc=$?
      ;;
    --live | live)
      local secs="${a2:-5}"
      case "$secs" in '' | *[!0-9]*) secs=5 ;; esac
      "$SPECTRUM_BIN" live "$secs" | $tint || rc=$?
      ;;
    *[!0-9]*)
      echo "media: usage: media.sh spectrum [snapshot | --live <seconds>]" >&2
      exit 2
      ;;
    *)
      # bare number == live duration shorthand
      "$SPECTRUM_BIN" live "$a1" | $tint || rc=$?
      ;;
  esac
  if [ "$rc" = "3" ]; then
    local playing
    playing="$(do_now 2>/dev/null | json_field playing)"
    if [ "$playing" = "true" ]; then
      config_write display.spectrum off 2>/dev/null || true
      rm -f "$DATA_DIR/statusline.cache"
      echo "media: the spectrum captured only silence while audio is playing — the system-audio-recording permission was revoked. Turned display.spectrum off; re-grant it in System Settings > Privacy & Security, then run /media:config display.spectrum on." >&2
    else
      echo "media: nothing is playing to visualize." >&2
    fi
    exit 3
  fi
  return "$rc"
}

# ---- config (§4.9: fail-closed enable) ---------------------------------------

CONFIG_KEYS="display.progressbar display.statusline display.spectrum statusline.multiline statusline.color"

# Which segments the statusline renders, in fixed display order. Chosen with
# /media:statusline (AskUserQuestion). "spectrum" additionally requires
# display.spectrum on + the audio-recording grant.
VALID_STATUSLINE_FIELDS="track progressbar time spectrum"
DEFAULT_STATUSLINE_FIELDS="track progressbar time"

config_default() {
  case "$1" in
    display.progressbar) echo on ;;
    display.statusline)  echo off ;;
    display.spectrum)    echo off ;;
    statusline.multiline) echo off ;;
    statusline.color)    echo on ;;
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

# String-valued keys (spectrum.style, spectrum.color) live beside the boolean
# ones but never go through config_get, whose truthiness test would mangle
# them. Values are validated in do_config before config_write_str runs.
config_get_str() {
  local key="$1" default="$2" v=""
  if [ -f "$CONFIG_FILE" ]; then
    v="$(/usr/bin/perl -MJSON::PP -e '
      local $/; my $d = eval { decode_json(<STDIN>) };
      exit 0 unless ref $d eq "HASH";
      my $v = $d->{$ARGV[0]};
      print $v if defined $v && !ref $v;
    ' "$key" < "$CONFIG_FILE" 2>/dev/null)"
  fi
  if [ -n "$v" ]; then echo "$v"; else echo "$default"; fi
}

config_write_str() {
  mkdir -p "$DATA_DIR"
  /usr/bin/perl -MJSON::PP -e '
    my ($file, $key, $val) = @ARGV;
    my $d = {};
    if (-f $file) {
      local $/;
      if (open my $fh, "<", $file) { $d = eval { decode_json(<$fh>) } || {}; close $fh; }
      $d = {} unless ref $d eq "HASH";
    }
    $d->{$key} = $val;
    open my $fh, ">", "$file.tmp" or die "cannot write config: $!\n";
    print $fh JSON::PP->new->canonical->encode($d), "\n";
    close $fh;
    rename "$file.tmp", $file or die "cannot save config: $!\n";
  ' "$CONFIG_FILE" "$1" "$2"
}

# Read statusline.fields (JSON array) as a space-separated list, falling back
# to the default set when the key is absent, empty, or malformed.
config_get_statusline_fields() {
  local v=""
  if [ -f "$CONFIG_FILE" ]; then
    v="$(/usr/bin/perl -MJSON::PP -e '
      local $/; my $d = eval { decode_json(<STDIN>) };
      exit 0 unless ref $d eq "HASH";
      my $a = $d->{"statusline.fields"};
      exit 0 unless ref $a eq "ARRAY";
      print join(" ", grep { defined && /^[a-z]+$/ } @$a);
    ' < "$CONFIG_FILE" 2>/dev/null)"
  fi
  if [ -n "$v" ]; then echo "$v"; else echo "$DEFAULT_STATUSLINE_FIELDS"; fi
}

# Store statusline.fields from a comma/space-separated list, keeping only known
# fields in canonical display order (invalid names are dropped silently; an
# empty result is stored as [] so the segment renders nothing).
config_set_statusline_fields() {
  local input="$1" ordered="" f g
  input="$(printf '%s' "$input" | tr ',' ' ')"
  for f in $VALID_STATUSLINE_FIELDS; do
    for g in $input; do
      if [ "$f" = "$g" ]; then
        ordered="$ordered $f"
        break
      fi
    done
  done
  mkdir -p "$DATA_DIR"
  # shellcheck disable=SC2086
  /usr/bin/perl -MJSON::PP -e '
    my ($file, @fields) = @ARGV;
    my $d = {};
    if (-f $file) {
      local $/;
      if (open my $fh, "<", $file) { $d = eval { decode_json(<$fh>) } || {}; close $fh; }
      $d = {} unless ref $d eq "HASH";
    }
    $d->{"statusline.fields"} = [@fields];
    open my $fh, ">", "$file.tmp" or die "cannot write config: $!\n";
    print $fh JSON::PP->new->canonical->encode($d), "\n";
    close $fh;
    rename "$file.tmp", $file or die "cannot save config: $!\n";
  ' "$CONFIG_FILE" $ordered
  rm -f "$DATA_DIR/statusline.cache"
  echo "statusline.fields =${ordered:- (none)}"
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
    display.spectrum)
      ensure_spectrum
      if [ -z "$SPECTRUM_BIN" ]; then
        echo "media: cannot enable display.spectrum — the spectrum helper is unavailable (needs macOS 14.4+ and Xcode Command Line Tools). Run /media:doctor." >&2
        return 3
      fi
      if "$SPECTRUM_BIN" preflight >/dev/null 2>&1; then
        return 0
      fi
      # Only silence was captured. There is no API to read the grant, so
      # disambiguate via playback: audio playing + silence == permission
      # missing; nothing playing == cannot verify (still fail-closed).
      local playing
      playing="$(do_now 2>/dev/null | json_field playing)"
      if [ "$playing" = "true" ]; then
        echo "media: cannot enable display.spectrum — audio is playing but the tap captured only silence, so the system-audio-recording permission is missing. Grant it to your terminal app in System Settings > Privacy & Security, then retry." >&2
      else
        echo "media: cannot enable display.spectrum yet — start playback so the capture can be verified (the permission cannot be queried directly), then retry. See /media:doctor." >&2
      fi
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

SPECTRUM_COLORS="red green yellow blue magenta cyan white"

do_config() {
  local key="${1:-}" value="${2:-}"

  # statusline.fields is array-valued (chosen with /media:statusline); handle
  # it before the boolean keys.
  if [ "$key" = "statusline.fields" ]; then
    if [ -z "$value" ]; then
      config_get_statusline_fields
    else
      config_set_statusline_fields "$value"
    fi
    return 0
  fi

  # String-valued spectrum appearance keys — no preflight (display-only), but
  # values are validated and a change drops the statusline cache.
  if [ "$key" = "spectrum.style" ]; then
    if [ -z "$value" ]; then
      config_get_str spectrum.style solid
      return 0
    fi
    case "$value" in
      solid | rainbow) ;;
      *)
        echo "media: spectrum.style must be 'solid' or 'rainbow' (got: $value)" >&2
        exit 2
        ;;
    esac
    config_write_str spectrum.style "$value"
    rm -f "$DATA_DIR/statusline.cache"
    echo "spectrum.style = $value"
    return 0
  fi
  if [ "$key" = "spectrum.color" ]; then
    if [ -z "$value" ]; then
      config_get_str spectrum.color cyan
      return 0
    fi
    local c ok=""
    for c in $SPECTRUM_COLORS; do
      [ "$c" = "$value" ] && ok=1
    done
    if [ -z "$ok" ]; then
      echo "media: spectrum.color must be one of: $SPECTRUM_COLORS (got: $value)" >&2
      exit 2
    fi
    config_write_str spectrum.color "$value"
    rm -f "$DATA_DIR/statusline.cache"
    echo "spectrum.color = $value"
    return 0
  fi

  if [ -z "$key" ]; then
    local k
    echo "key                   value  notes"
    for k in $CONFIG_KEYS; do
      local note=""
      case "$k" in
        display.progressbar) note="progress bar in /media:now and statusline output" ;;
        display.statusline)  note="statusline now-playing segment (recipe: docs/statusline.md)" ;;
        display.spectrum)    note="audio spectrum (/media:spectrum + statusline field); needs audio-recording permission" ;;
        statusline.multiline) note="statusline layout: on = each item on its own line, off = one line" ;;
        statusline.color)    note="ANSI colors/bold/italic in the statusline segment (honors NO_COLOR)" ;;
      esac
      printf '%-21s %-6s %s\n' "$k" "$(config_get "$k")" "$note"
    done
    printf '%-21s %-6s %s\n' "statusline.fields" "-" \
      "[$(config_get_statusline_fields)] — choose with /media:statusline"
    printf '%-21s %-6s %s\n' "spectrum.style" "$(config_get_str spectrum.style solid)" \
      "statusline spectrum coloring: solid (one color) or rainbow (front-to-back cycle)"
    printf '%-21s %-6s %s\n' "spectrum.color" "$(config_get_str spectrum.color cyan)" \
      "solid spectrum color: $SPECTRUM_COLORS (ignored when style is rainbow)"
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
      # Any key that changes what the segment renders drops the stale cache so
      # the change shows up on the next tick instead of after the TTL.
      case "$key" in
        display.statusline | display.progressbar | display.spectrum | statusline.multiline | statusline.color)
          rm -f "$DATA_DIR/statusline.cache" ;;
      esac
      echo "$key = on"
      ;;
    off)
      # Disabling is always allowed, no preconditions.
      config_write "$key" off
      # A stale segment cache must not outlive the toggle (§4.8.1: off leaves
      # no trace, not even a cached line; layout/field changes must re-render).
      case "$key" in
        display.statusline | display.progressbar | display.spectrum | statusline.multiline | statusline.color)
          rm -f "$DATA_DIR/statusline.cache" ;;
      esac
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

  # Audio spectrum (opt-in Phase 4): report availability + the capture grant.
  local spec
  ensure_spectrum
  if [ -z "$SPECTRUM_BIN" ]; then
    spec="unavailable (needs macOS 14.4+ and Xcode CLT; opt-in feature)"
  else
    set +e
    "$SPECTRUM_BIN" preflight >/dev/null 2>&1
    local prc=$?
    set -e
    case "$prc" in
      0) spec="ok — audio capture working (display.spectrum=$(config_get display.spectrum))" ;;
      3)
        local pl
        pl="$(do_now 2>/dev/null | json_field playing)"
        if [ "$pl" = "true" ]; then
          spec="PERMISSION MISSING — audio is playing but the tap is silent. Grant \"system audio recording\" to your terminal app in System Settings > Privacy & Security."
        else
          spec="cannot verify now (nothing playing) — start playback and re-check"
        fi
        ;;
      2) spec="capture API unavailable (macOS < 14.4?)" ;;
      *) spec="capture error (exit $prc)" ;;
    esac
  fi
  echo "[7] Spectrum    : $spec"
  echo "[8] Config      : progressbar=$(config_get display.progressbar) statusline=$(config_get display.statusline) spectrum=$(config_get display.spectrum) color=$(config_get statusline.color)"
  echo "                  statusline.fields=[$(config_get_statusline_fields)] spectrum.style=$(config_get_str spectrum.style solid) spectrum.color=$(config_get_str spectrum.color cyan)"
  echo "                  ($CONFIG_FILE)"
  echo "[9] Build log   : $DATA_DIR/build.log"
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
  spectrum)   do_spectrum "${2:-}" "${3:-}" ;;
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
