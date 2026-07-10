#!/bin/bash
# media.sh — single dispatcher for the "media" Claude Code plugin.
#
# Subcommands:
#   now                          now-playing state, one JSON line (or "null")
#   play|pause|toggle|next|prev  send a playback command, then re-read state
#   seek <seconds>               jump to an absolute position, then re-read
#   artwork [path-prefix]        save current artwork to a file, print JSON
#   volume [0-100]               system output volume get/set, one JSON line
#   output [device]              audio output device list / switch, JSON
#   history [n|clear|--json]     recently played tracks (passive local log)
#   statusline                   one-line segment for a statusline (TTL cache)
#   statusline install           wire the segment into ~/.claude/settings.json
#   statusline uninstall         unwire it and restore the previous statusLine
#   statusline status            report how the segment is wired
#   test                         primary-path self-check (exit code only)
#   config [key] [value]         display toggles + per-item statusline styles
#   doctor [--rebuild]           full diagnosis (+ optional cache rebuild)
#   detect                       SessionStart hook probe: silent when healthy
#   warmup                       SessionStart async hook: pre-build the dylib
#   open-url <url>               claude-media:// click-action dispatch (used
#                                by the statusline's cmd+click handler app)
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
  artwork [path-prefix] | volume [0-100] | output [device]
  statusline [install | uninstall | status]
  history [count | clear | --json [count]]
  test | config [key] [on|off|value] | doctor [--rebuild] | detect | warmup
  open-url <claude-media://toggle|activate|seek/<pct>>   (statusline clicks)
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
primary_output_list() { /usr/bin/perl "$LOADER" "$LIB" adapter_output_list 2>/dev/null; }
# stderr passes through: the helper's messages name the candidate devices.
primary_output_set() { MEDIA_OUTPUT_DEVICE="$1" /usr/bin/perl "$LOADER" "$LIB" adapter_output_set; }

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

# ---- history (passive playback log) ------------------------------------------

HISTORY_FILE_NAME="history.jsonl"
HISTORY_MAX_ENTRIES=500
# A track change flows through MediaRemote in stages — the title switches
# first, the artist follows a beat later — so a read landing mid-transition
# sees the new title with the STALE artist. The corrected snapshot (same
# title, same app, real artist) arrives on the next read, normally 1-2
# seconds later; within this window it replaces the transitional entry
# instead of appending a phantom track.
HISTORY_AMEND_SECONDS=10

# Log a now-playing JSON snapshot into history.jsonl. Piggybacks on reads
# that happen anyway (now / control re-reads / statusline ticks) — history
# never polls on its own, so its cost is one short perl per read, and a
# write only when the track actually changed. One perl handles everything:
# the history.record gate, dedup against the last entry, the artist-lag
# amend (see HISTORY_AMEND_SECONDS), append, and the size cap (oldest
# entries dropped past HISTORY_MAX_ENTRIES). Snapshots without a title are
# transitional noise (browsers publish them mid-navigation) and never land.
history_record() {
  mkdir -p "$DATA_DIR" 2>/dev/null || true
  printf '%s' "$1" | /usr/bin/perl -MJSON::PP -e '
    my ($config, $file, $max, $amendwin) = @ARGV;
    if (-f $config) {
      local $/;
      if (open my $cf, "<", $config) {
        my $c = eval { decode_json(<$cf>) };
        close $cf;
        exit 0 if ref $c eq "HASH" && exists $c->{"history.record"}
               && !$c->{"history.record"};
      }
    }
    # Slurp STDIN inside a block: $/ must stay line-based for the
    # history-file reads below.
    my $d;
    { local $/; $d = eval { decode_json(<STDIN>) }; }
    exit 0 unless ref $d eq "HASH" && defined $d->{title} && length $d->{title};
    my $key = join "\x1f", map { $d->{$_} // "" }
      qw(title artist bundleIdentifier);
    my @lines;
    if (open my $fh, "<", $file) { chomp(@lines = <$fh>); close $fh; }
    my $amend = 0;
    if (@lines) {
      my $last = eval { decode_json($lines[-1]) };
      if (ref $last eq "HASH") {
        my $lk = join "\x1f", map { $last->{$_} // "" }
          qw(title artist bundleIdentifier);
        exit 0 if $lk eq $key;
        # Same title + same app but a different artist (the keys differ, so
        # with title and app equal the artist must differ), seconds after
        # the last append -> the last entry was a transitional mixed
        # snapshot; the corrected read supersedes it in place.
        $amend = 1 if defined $last->{ts}
          && time() - $last->{ts} <= $amendwin
          && ($last->{title} // "") eq $d->{title}
          && ($last->{bundleIdentifier} // "") eq ($d->{bundleIdentifier} // "");
      }
    }
    my %e = (ts => time());
    for (qw(title artist album appName bundleIdentifier)) {
      $e{$_} = $d->{$_} if defined $d->{$_};
    }
    if ($amend) { $lines[-1] = JSON::PP->new->canonical->encode(\%e) }
    else        { push @lines, JSON::PP->new->canonical->encode(\%e) }
    if ($amend || @lines > $max) {
      splice @lines, 0, @lines - $max if @lines > $max;
      open my $fh, ">", "$file.tmp" or exit 0;
      print $fh "$_\n" for @lines;
      close $fh;
      rename "$file.tmp", $file;
    } else {
      open my $fh, ">>", $file or exit 0;
      print $fh "$lines[-1]\n";
      close $fh;
    }
  ' "$CONFIG_FILE" "$DATA_DIR/$HISTORY_FILE_NAME" "$HISTORY_MAX_ENTRIES" \
    "$HISTORY_AMEND_SECONDS" 2>/dev/null || true
}

# Print one now-playing JSON line, logging it into the history on the way out.
emit_now() {
  if [ -n "$1" ] && [ "$1" != "null" ]; then
    history_record "$1"
  fi
  printf '%s\n' "$1"
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
        emit_now "$out"
        return 0
      fi
      # Primary sees nothing. Cross-check with the independent JXA path to
      # distinguish "nothing playing" from "primary read blocked".
      local jxa
      jxa="$(jxa_read)"
      if [ "$jxa" != "null" ] && [ -n "$jxa" ]; then
        echo "media: native read returned nothing but the fallback sees media — the primary path may be broken. Run /media:doctor." >&2
        emit_now "$jxa"
        return 0
      fi
      echo "null"
      return 0
    fi
    echo "media: native read failed — using fallback. Run /media:doctor if this persists." >&2
  fi
  emit_now "$(jxa_read)"
}

# Playback history viewer: newest first, default 20 entries.
#   history [count]          human-readable lines (MM-DD HH:MM  title — artist  (app))
#   history --json [count]   raw JSONL, newest first
#   history clear            delete the log
do_history() {
  local a1="${1:-}" a2="${2:-}" n=20 as_json=""
  local file="$DATA_DIR/$HISTORY_FILE_NAME"
  if [ "$a1" = "clear" ]; then
    rm -f "$file"
    echo "playback history cleared."
    return 0
  fi
  if [ "$a1" = "--json" ]; then
    as_json=1
    a1="$a2"
  fi
  if [ -n "$a1" ]; then
    case "$a1" in
      *[!0-9]*)
        echo "media: usage: media.sh history [count | clear | --json [count]]" >&2
        exit 2
        ;;
    esac
    n="$a1"
    [ "$n" -ge 1 ] || n=1
  fi
  if [ ! -s "$file" ]; then
    echo "media: no playback history yet — tracks are logged while media reads run (history.record=$(config_get history.record))."
    return 0
  fi
  if [ -n "$as_json" ]; then
    /usr/bin/tail -n "$n" "$file" | /usr/bin/perl -e 'print reverse <STDIN>'
    return 0
  fi
  /usr/bin/tail -n "$n" "$file" | /usr/bin/perl -MJSON::PP -MPOSIX=strftime -e '
    binmode STDOUT, ":utf8";
    my @rows;
    while (my $l = <STDIN>) {
      my $d = eval { decode_json($l) };
      next unless ref $d eq "HASH" && defined $d->{title};
      my $when = defined $d->{ts}
        ? strftime("%m-%d %H:%M", localtime($d->{ts})) : "unknown time";
      my $t = $d->{title};
      $t .= " \x{2014} $d->{artist}" if defined $d->{artist};
      my $app = $d->{appName} // $d->{bundleIdentifier};
      $t .= "  ($app)" if defined $app;
      push @rows, "$when  $t";
    }
    print "$_\n" for reverse @rows;
  '
  return 0
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
  # The cached statusline segment predates the state change — drop it so the
  # next tick re-renders (same rule as volume/output set).
  rm -f "$DATA_DIR/statusline.cache"
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
  rm -f "$DATA_DIR/statusline.cache"
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

# ---- open-url (statusline cmd+click actions) ----------------------------------

# Bring the now-playing app to the front. The now-playing process may be a
# helper (e.g. a browser's web-content process, whose bundle id is a suffixed
# variant of the browser's — com.openai.atlas.web vs com.openai.atlas), so:
# 1. the process itself when it is a regular app, else 2. a running regular
# app whose bundle id is a dotted prefix of the reported one (or vice versa),
# else 3. `open -b` as a last resort. NSRunningApplication activation is
# public AppKit — no Automation (AppleEvents) permission involved.
# On success the OWNING app's bundle id is printed (the resolved regular app,
# which may differ from the reported helper id) — focus_media keys off it.
activate_app() {
  local pid="${1:-}" bundle="${2:-}" got=""
  got="$(/usr/bin/osascript -l JavaScript -e '
    ObjC.import("AppKit");
    function run(argv) {
      var pid = parseInt(argv[0] || "0", 10);
      var want = (argv[1] || "").toLowerCase();
      var apps = $.NSWorkspace.sharedWorkspace.runningApplications;
      var byPid = null, exact = null, prefix = null;
      for (var i = 0; i < apps.count; i++) {
        var a = apps.objectAtIndex(i);
        if (a.activationPolicy != $.NSApplicationActivationPolicyRegular) continue;
        var bid = a.bundleIdentifier.js ? ObjC.unwrap(a.bundleIdentifier).toLowerCase() : "";
        if (pid && a.processIdentifier == pid) byPid = a;
        if (want && bid && bid == want) exact = a;
        if (want && bid && !prefix &&
            (want.indexOf(bid + ".") == 0 || bid.indexOf(want + ".") == 0)) prefix = a;
      }
      var target = byPid || exact || prefix;
      if (!target) return "";
      target.activateWithOptions($.NSApplicationActivateAllWindows);
      return ObjC.unwrap(target.bundleIdentifier) || "activated";
    }
  ' "$pid" "$bundle" 2>/dev/null || true)"
  if [ -n "$got" ]; then
    echo "$got"
    return 0
  fi
  if [ -n "$bundle" ] && /usr/bin/open -b "$bundle" 2>/dev/null; then
    echo "$bundle"
    return 0
  fi
  echo "media: could not bring the now-playing app to the front (${bundle:-unknown app})." >&2
  return 1
}

# Move the app's UI to the playing media itself, best effort — called with
# the OWNING app id activate_app resolved: browsers with AppleScript tab
# control select the window+tab whose name contains the track title (the
# Safari dialect / the Chromium suite — only known-scriptable bundles, so no
# consent prompt is ever triggered for an app that could not honor it
# anyway), and Music reveals the current track. Everything else (e.g.
# ChatGPT Atlas — no scripting interface) keeps plain activation. The first
# use shows a one-time Automation consent attributed to the click-handler
# app; a denial or any script error just leaves activation-only behavior.
# The title travels via the environment (system attribute), so no user data
# is ever spliced into the script source.
focus_media() {
  local bundle="$1" title="$2"
  [ -n "$title" ] || return 0
  case "$bundle" in
    com.apple.Safari)
      MEDIA_FOCUS_TITLE="$title" /usr/bin/osascript -e '
        set t to system attribute "MEDIA_FOCUS_TITLE"
        with timeout of 3 seconds
          tell application "Safari"
            repeat with w in windows
              set i to 0
              repeat with tb in tabs of w
                set i to i + 1
                if name of tb contains t then
                  set current tab of w to tab i of w
                  set index of w to 1
                  return
                end if
              end repeat
            end repeat
          end tell
        end timeout' >/dev/null 2>&1 || true
      ;;
    com.google.Chrome | com.google.Chrome.canary | com.google.Chrome.beta | \
    com.microsoft.edgemac | com.brave.Browser | com.vivaldi.Vivaldi | \
    com.operasoftware.Opera)
      MEDIA_FOCUS_TITLE="$title" MEDIA_FOCUS_BUNDLE="$bundle" /usr/bin/osascript -e '
        set t to system attribute "MEDIA_FOCUS_TITLE"
        set b to system attribute "MEDIA_FOCUS_BUNDLE"
        with timeout of 3 seconds
          tell application id b
            repeat with w in windows
              set i to 0
              repeat with tb in tabs of w
                set i to i + 1
                if title of tb contains t then
                  set active tab index of w to i
                  set index of w to 1
                  return
                end if
              end repeat
            end repeat
          end tell
        end timeout' >/dev/null 2>&1 || true
      ;;
    com.apple.Music)
      /usr/bin/osascript -e '
        with timeout of 3 seconds
          tell application "Music" to reveal current track
        end timeout' >/dev/null 2>&1 || true
      ;;
  esac
  return 0
}

# Dispatch one clicked claude-media:// URL from the statusline. The applet
# accepts URLs from anywhere (any app can open a URL scheme), so the surface
# stays deliberately tiny and benign: toggle, activate, and seek by percent —
# nothing else, no free-form parameters.
do_open_url() {
  local url="${1:-}" pct=""
  case "$url" in
    claude-media://toggle | claude-media://toggle/)
      do_control toggle 2
      ;;
    claude-media://activate | claude-media://activate/)
      local json bundle pid
      json="$(do_now 2>/dev/null || echo null)"
      if [ -z "$json" ] || [ "$json" = "null" ]; then
        echo "media: nothing is playing — no app to activate." >&2
        exit 1
      fi
      bundle="$(printf '%s' "$json" | json_field bundleIdentifier)"
      pid="$(printf '%s' "$json" | json_field processIdentifier)"
      if [ -z "$bundle" ] && [ -z "$pid" ]; then
        echo "media: the current read does not name the playing app — cannot activate it." >&2
        exit 1
      fi
      # Land on the media, not just the app: bring the owning app forward,
      # then select the playing tab / reveal the track (best effort).
      local owner
      owner="$(activate_app "$pid" "$bundle")" || exit 1
      focus_media "$owner" "$(printf '%s' "$json" | json_field title)"
      ;;
    claude-media://seek/*)
      pct="${url#claude-media://seek/}"
      pct="${pct%/}"
      case "$pct" in
        '' | *[!0-9]*)
          echo "media: open-url: seek wants an integer percent 0-100 (got: $url)." >&2
          exit 2
          ;;
      esac
      if [ "$pct" -gt 100 ]; then
        echo "media: open-url: seek wants an integer percent 0-100 (got: $url)." >&2
        exit 2
      fi
      local json dur secs
      json="$(do_now 2>/dev/null || echo null)"
      dur="$(printf '%s' "$json" | json_field duration)"
      if [ -z "$dur" ]; then
        echo "media: no track with a known duration is playing — cannot seek by percent." >&2
        exit 1
      fi
      secs="$(/usr/bin/perl -e 'printf "%.1f", $ARGV[0] * $ARGV[1] / 100' "$dur" "$pct")"
      do_seek "$secs"
      ;;
    *)
      echo "media: open-url: unsupported URL: ${url:-<empty>} (expected claude-media://toggle | activate | seek/<0-100>)." >&2
      exit 2
      ;;
  esac
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
    # The statusline `volume` field must show the change on the next tick.
    rm -f "$DATA_DIR/statusline.cache"
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

# ---- output device ----------------------------------------------------------

# List (no argument) or switch (name / unique substring / 1-based index) the
# system default audio output device via CoreAudio (public API). There is no
# osascript equivalent, so this needs the native helper; degraded mode gets a
# clear refusal instead of a broken half-feature.
do_output() {
  local target="${1:-}"
  ensure_native
  if [ -z "$LIB" ]; then
    echo "media: the output-device feature needs the native helper (Xcode Command Line Tools). Run /media:doctor." >&2
    exit 1
  fi
  if [ -n "$target" ]; then
    local rc=0
    primary_output_set "$target" >/dev/null || rc=$?
    if [ "$rc" -eq 4 ]; then
      # The helper's stderr already named the candidates / the ambiguity.
      exit 4
    fi
    if [ "$rc" -ne 0 ]; then
      echo "media: switching the output device failed. Run /media:doctor." >&2
      exit 1
    fi
    # The statusline `output` field must show the switch on the next tick.
    rm -f "$DATA_DIR/statusline.cache"
  fi
  local out=""
  if ! out="$(primary_output_list)" || [ -z "$out" ]; then
    echo "media: reading the output devices failed. Run /media:doctor." >&2
    exit 1
  fi
  echo "$out"
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
  local fields json line="" multiline color marquee styles links
  fields="$(config_get_statusline_fields)"
  multiline="$(config_get statusline.multiline)"
  marquee="$(config_get statusline.marquee)"
  styles="$(style_resolve)"
  # NO_COLOR (https://no-color.org) beats the config key. The cache may serve
  # a line rendered under the other setting for at most one TTL second.
  color="$(config_get statusline.color)"
  [ -n "${NO_COLOR:-}" ] && color=off
  # cmd+click links render only while the claude-media:// handler app exists
  # — a link nothing answers is worse than no link. Independent of colors.
  links="$(config_get statusline.links)"
  [ -d "$DATA_DIR/ClaudeMediaClick.app" ] || links=off
  json="$(do_now 2>/dev/null || echo null)"
  if [ -n "$json" ] && [ "$json" != "null" ]; then
    # Render the chosen fields as groups in their stored order (arrange with
    # /media:statusline), joined by two spaces inline or a newline in multiline
    # layout. `app` folds into the track group when both are chosen; adjacent
    # progressbar+time share one group, `output` merges into an adjacent
    # track group (so `track,app,output,progressbar,time` stacks as two lines:
    # track+app+output / bar+time), and `volume` merges into an adjacent
    # track or output group. Adjacency is judged over the fields that
    # actually rendered a token, so a folded `app` between track and output is
    # transparent. A "/" in the stored fields switches to the explicit layout:
    # each "/" starts a new line, items render in the given order joined by
    # two spaces, and the grouping rules plus statusline.multiline no longer
    # apply — the user's lines ARE the layout. In a line, `app` right after
    # `track` still folds into it as "(App)"; anywhere else it renders as the
    # plain app name. A line whose items all rendered nothing (e.g. `output`
    # without the native helper) disappears entirely — no blank lines.
    # Fields the user didn't pick are omitted; Claude Code renders
    # multi-line statuslines as-is. Styling (statusline.color on) follows the
    # per-part style.* keys (see style_resolve for the set and defaults):
    # state-colored icon + filled bar (style.progressbar.playing/.paused,
    # green/yellow by default; the icon keeps its bold), bold title and
    # elapsed time (the moving part must stay readable, so only the
    # "/duration" tail is dim), italic artist, dim chrome. The bar characters
    # come from style.progressbar.style (a named charset or two glyphs) and
    # apply even with colors off. A text part whose style is "off" is not
    # rendered at all: a hidden title drops the "—" separator with it, a
    # hidden elapsed time drops the total's leading "/", and a token whose
    # parts all vanished is never created — its field (and an explicit line
    # left empty) disappears. The `volume` field renders icon + level bar
    # + percent (`🔉 ▄ 45%`): a speaker glyph tiered by level (🔈/🔉/🔊, 🔇 at
    # 0; overridable via style.volume.icon), a bar shaped by
    # style.volume.style (block = one eighth-block whose height tracks the
    # level, 50% = half block; progress = a five-cell mini bar drawn with the
    # progress-bar charset; stairs = ▂▄▆█ steps), and the percent. The bar
    # draws in the playing/paused accent — style.volume.bar only toggles it
    # on/off. Muted
    # shows 🔇 alone — the underlying level is not what plays. The `output`
    # icon follows style.output.icon (auto = by device kind, none = hidden,
    # any glyph verbatim); the device name takes style.output. Claude Code
    # statuslines render ANSI SGR
    # codes; every token resets with \e[0m so surrounding statusline content is
    # never restyled. statusline.marquee scrolls titles wider than 30 display
    # cells through a fixed window, one character per second (offset derives
    # from the epoch, so each 1s cache refresh advances it — no state file
    # needed). With statusline.links on and the claude-media:// handler app
    # present, the segment is cmd+clickable via OSC 8 hyperlinks: the ▶︎/⏸
    # icon toggles playback, title/artist/app activate the playing app, and
    # each progress-bar cell seeks to its position (see do_open_url).
    line="$(printf '%s' "$json" | /usr/bin/perl -CA -MJSON::PP -e '
      binmode STDOUT, ":utf8";
      my (@order, %seen);
      for (split /\s+/, ($ARGV[0] // "")) {
        if ($_ eq "/") { push @order, $_; next; }   # keep every line break
        push @order, $_ unless $seen{$_}++;
      }
      my $explicit = grep { $_ eq "/" } @order;
      my %w = map { $_ => 1 } grep { $_ ne "/" } @order;
      my $ml = ($ARGV[1] // "") eq "on";
      my $c  = ($ARGV[2] // "") eq "on";
      my $mq = ($ARGV[3] // "") eq "on";
      my $lk = ($ARGV[5] // "") eq "on";
      # Per-part styles from style_resolve ("key<TAB>value<TAB>default" lines).
      my %sty;
      for my $sl (split /\n/, ($ARGV[4] // "")) {
        my ($k, $v) = (split /\t/, $sl)[0, 1];
        next unless defined $v;
        $k =~ s/^style\.//;
        $sty{$k} = $v;
      }
      # Style spec -> SGR codes ("bold cyan" -> "1;36"). The setter validates;
      # this stays lenient for hand-edited configs (unknown tokens drop out,
      # "none" means no styling at all).
      my %ATTR = (bold => 1, dim => 2, italic => 3, underline => 4);
      my %COL  = (black => 30, red => 31, green => 32, yellow => 33,
                  blue => 34, magenta => 35, cyan => 36, white => 37);
      sub sgr {
        my (@a, $col);
        for my $t (split /[\s,]+/, lc($_[0] // "")) {
          next unless length $t;
          return "" if $t eq "none" || $t eq "plain";
          if (exists $ATTR{$t}) { push @a, $ATTR{$t}; next; }
          my $b = ($t =~ s/^bright-//) ? 60 : 0;
          $col = $COL{$t} + $b if exists $COL{$t};
        }
        my %u;
        @a = sort { $a <=> $b } grep { !$u{$_}++ } @a;
        return join ";", @a, (defined $col ? ($col) : ());
      }
      local $/; my $d = eval { decode_json(<STDIN>) };
      exit 0 unless ref $d eq "HASH" && defined $d->{title};
      sub mss { my $s = int($_[0]); sprintf "%d:%02d", $s / 60, $s % 60 }
      # Approximate terminal cell width: East Asian wide/fullwidth blocks and
      # emoji count 2 cells, everything else 1 (enough to keep the marquee
      # window steady for CJK titles).
      sub cw {
        return ($_[0] =~ /[\x{1100}-\x{115F}\x{2E80}-\x{303E}\x{3041}-\x{33FF}\x{3400}-\x{4DBF}\x{4E00}-\x{9FFF}\x{A000}-\x{A4CF}\x{AC00}-\x{D7A3}\x{F900}-\x{FAFF}\x{FE30}-\x{FE4F}\x{FF00}-\x{FF60}\x{FFE0}-\x{FFE6}\x{1F300}-\x{1FAFF}\x{20000}-\x{2FFFD}]/) ? 2 : 1;
      }
      sub dwidth { my $t = 0; $t += cw($_) for split //, $_[0]; $t }
      my $MQW = 30;
      sub marquee {
        my ($s) = @_;
        return $s if dwidth($s) <= $MQW;
        my @ch = split //, $s . "   ";
        my $off = time() % scalar(@ch);
        my ($out, $wd) = ("", 0);
        for (my $i = 0; $wd < $MQW; $i++) {
          my $g = $ch[($off + $i) % @ch];
          my $gw = cw($g);
          last if $wd + $gw > $MQW;
          $out .= $g;
          $wd += $gw;
        }
        return $out . (" " x ($MQW - $wd));
      }
      my $st = sub {
        my ($codes, $t) = @_;
        ($c && length($codes // "") && length $t) ? "\e[${codes}m$t\e[0m" : $t;
      };
      # OSC 8 hyperlink wrapper (BEL-terminated — the form Claude Code
      # itself emits). The statusline renderer passes these through to the
      # terminal: capable ones (iTerm2, Ghostty, WezTerm, Kitty, VS Code)
      # make the text cmd+clickable, others ignore the sequence. Clicked
      # URLs land in ClaudeMediaClick.app -> click-handler.sh -> open-url.
      my $href = sub {
        my ($u, $t) = @_;
        ($lk && length $t) ? "\e]8;;$u\a$t\e]8;;\a" : $t;
      };
      # A text part whose style spec is "off" is hidden entirely (the setter
      # only allows it on text parts; lc keeps hand-edited configs lenient).
      my $hid = sub { lc($sty{$_[0]} // "") eq "off" };
      # The playing/paused accent (track icon + bar fill) comes from
      # style.progressbar.playing / .paused; the icon keeps its bold on top.
      my $acc = $d->{playing} ? ($sty{"progressbar.playing"} // "green")
                              : ($sty{"progressbar.paused"}  // "yellow");
      my $accsgr  = sgr($acc);
      my $iconsgr = sgr("bold $acc");
      my $appsgr  = sgr($sty{"app"});
      my $app = $d->{appName} // $d->{bundleIdentifier};
      # One token per renderable field; the order pass below assembles them.
      my %tok;
      if ($w{track}) {
        my $icon = $d->{playing} ? "\x{25B6}\x{FE0E}" : "\x{23F8}";
        # cmd+click targets: the icon toggles play/pause; the title/artist
        # (and the app name below) bring the playing app to the front.
        my $t = $href->("claude-media://toggle", $st->($iconsgr, $icon));
        my $body = "";
        unless ($hid->("track.title")) {
          my $title = $mq ? marquee($d->{title}) : $d->{title};
          $body .= $st->(sgr($sty{"track.title"}), $title);
        }
        # The "—" separator belongs to the title/artist pair: a hidden title
        # leaves just "icon artist".
        $body .= ($hid->("track.title") ? "" : " " . $st->(2, "\x{2014}") . " ")
            . $st->(sgr($sty{"track.artist"}), $d->{artist})
          if defined $d->{artist} && !$hid->("track.artist");
        $t .= " " . $href->("claude-media://activate", $body) if length $body;
        $t .= " " . $href->("claude-media://activate", $st->($appsgr, "($app)"))
          if !$explicit && $w{app} && defined $app && !$hid->("app");
        $tok{track} = $t;
      }
      # Standalone app token: always in the explicit layout (folding happens
      # per line during assembly), only without a track in the grouped one.
      if ($w{app} && defined $app && !$hid->("app") && ($explicit || !$w{track})) {
        $tok{app} = $href->("claude-media://activate", $st->($appsgr, $app));
      }
      my $pos = $d->{elapsedTimeNow} // $d->{elapsedTime};
      my $dur = $d->{duration};
      # Bar characters by style.progressbar.style: a named charset or any
      # two glyphs "filled+empty" — character choices show even with colors
      # off. Resolved up front: the volume "progress" shape draws with the
      # same charset through the same $bar builder. A multi-glyph fill
      # (wave, pulse, eq, notes) repeats cell by cell; its phase follows
      # the playback position, so the trace rolls toward the empty end each
      # second while playing and freezes on pause. A third charset glyph
      # (knob) caps the last filled cell. smooth is special-cased in $bar:
      # its boundary cell is an eighth-block sized by the remainder.
      my %cs = (blocks => ["\x{2588}", "\x{2591}"],
                wave => ["\x{2582}\x{2584}\x{2586}\x{2584}", "\x{2581}"],
                pulse => ["\x{2582}\x{2582}\x{2588}\x{2581}\x{2584}", "\x{2581}"],
                eq => ["\x{2582}\x{2587}\x{2583}\x{2588}\x{2585}\x{2586}", "\x{2581}"],
                notes => ["\x{266A}\x{266B}", "\x{B7}"],
                braille => ["\x{28FF}", "\x{28C0}"],
                chevron => ["\x{25B8}", "\x{25B9}"],
                tape => ["\x{25B0}", "\x{25B1}"],
                cassette => ["\x{25AE}", "\x{25AF}"],
                retro => ["=", "-"],
                knob => ["\x{2501}", "\x{2500}", "\x{25CF}"],
                smooth => ["\x{2588}", "\x{2591}"],
                line => ["\x{2501}", "\x{2500}"], dots => ["\x{25CF}", "\x{25CB}"]);
      my $csv = $sty{"progressbar.style"} // "line";
      my ($fc, $ec, $hc) = $cs{$csv}      ? @{$cs{$csv}}
                    : length($csv) == 2   ? (substr($csv, 0, 1), substr($csv, 1, 1))
                    :                       @{$cs{line}};
      my @fp = split //, $fc;
      my $ph = (defined $pos ? int($pos) : 0) % @fp;
      my $fill = sub {
        my ($n) = @_;
        return "" if $n <= 0;
        my $b = defined $hc ? $n - 1 : $n;
        join("", map { $fp[($_ - $ph) % @fp] } 0 .. $b - 1)
          . (defined $hc ? $hc : "");
      };
      my $bar = sub {
        my ($cells, $r, $seek) = @_;
        $r = 0 if $r < 0; $r = 1 if $r > 1;
        # A seekable bar (the progressbar token only — never the volume
        # mini bar) wraps every cell in its own cmd+click link: cell i
        # jumps to its center percent, (i+0.5)/cells. Without links the
        # fill stays one SGR run — byte-identical to the unlinked render.
        my $link = $seek && $lk;
        my $cell = sub {
          my ($i, $t) = @_;
          $href->("claude-media://seek/" . int((($i + 0.5) * 100) / $cells), $t);
        };
        if ($csv eq "smooth") {
          # Fill measured in eighths of a cell; the remainder becomes one
          # partial block on the boundary cell (chr: 0x2590 - e = ▏..▉).
          my $te = int($r * $cells * 8 + 0.5);
          my ($nf, $e) = (int($te / 8), $te % 8);
          unless ($link) {
            return $st->($accsgr, ($fc x $nf) . ($e ? chr(0x2590 - $e) : ""))
                 . $st->(2, $ec x ($cells - $nf - ($e ? 1 : 0)));
          }
          my $out = "";
          for my $i (0 .. $cells - 1) {
            $out .= $i < $nf          ? $cell->($i, $st->($accsgr, $fc))
                  : ($i == $nf && $e) ? $cell->($i, $st->($accsgr, chr(0x2590 - $e)))
                  :                     $cell->($i, $st->(2, $ec));
          }
          return $out;
        }
        my $filled = int($r * $cells + 0.5);
        unless ($link) {
          return $st->($accsgr, $fill->($filled))
               . $st->(2, $ec x ($cells - $filled));
        }
        my $out = "";
        for my $i (0 .. $cells - 1) {
          if ($i < $filled) {
            # Same glyph the one-run $fill would pick: phase-mapped charset
            # cells, the knob head capping the last filled cell.
            my $g = (defined $hc && $i == $filled - 1)
                  ? $hc : $fp[($i - $ph) % @fp];
            $out .= $cell->($i, $st->($accsgr, $g));
          } else {
            $out .= $cell->($i, $st->(2, $ec));
          }
        }
        return $out;
      };
      if ($w{progressbar} && defined $pos && defined $dur && $dur > 0) {
        $tok{progressbar} = $bar->(10, $pos / $dur, 1);
      }
      if ($w{time} && defined $pos) {
        my $t = "";
        $t .= $st->(sgr($sty{"time.elapsed"}), mss($pos))
          unless $hid->("time.elapsed");
        unless ($hid->("time.total")) {
          my $tail = defined $dur ? mss($dur) : "LIVE";
          # The "/" belongs to the pair: with the elapsed part hidden the
          # total stands alone.
          $tail = "/$tail" unless $hid->("time.elapsed");
          $t .= $st->(sgr($sty{"time.total"}), $tail);
        }
        $tok{time} = $t if length $t;
      }
      if ($w{output} && defined $d->{outputDevice}) {
        # Icon by device kind (adapter outputKind): headphones for Bluetooth
        # devices and the built-in jack, a TV for HDMI/DisplayPort audio,
        # signal bars for AirPlay, a speaker for everything else.
        # style.output.icon overrides: none hides it, a glyph replaces it.
        # The icon stays unstyled; the name takes style.output ("off" hides
        # it). Nothing left -> no token.
        my %oicon = ("headphones" => "\x{1F3A7}", "display" => "\x{1F4FA}",
                     "airplay" => "\x{1F4F6}");
        my $oic = lc($sty{"output.icon"} // "auto");
        $oic = "none" if $oic eq "off";
        my @op;
        push @op, ($oic eq "auto" ? ($oicon{$d->{outputKind} // ""} // "\x{1F50A}")
                                  : $sty{"output.icon"})
          unless $oic eq "none";
        push @op, $st->(sgr($sty{"output"}), $d->{outputDevice})
          unless $hid->("output");
        $tok{output} = join(" ", @op) if @op;
      }
      if ($w{volume} && defined $d->{volume}) {
        my $v = int($d->{volume});
        $v = 0 if $v < 0; $v = 100 if $v > 100;
        if ($d->{muted}) {
          $tok{volume} = "\x{1F507}";
        } else {
          # Icon by style.volume.icon: auto = tiered by level, none = hidden,
          # anything else renders verbatim. Muted always shows the mute glyph.
          my $vic = $sty{"volume.icon"} // "auto";
          $vic = "none" if lc($vic) eq "off";
          my @vp;
          push @vp, ($vic eq "auto"
                   ? ($v == 0 ? "\x{1F507}"
                    : $v < 34 ? "\x{1F508}"
                    : $v < 67 ? "\x{1F509}"
                    :           "\x{1F50A}")
                   : $vic)
            unless $vic eq "none";
          # The bar draws in the playing/paused accent — one accent across
          # the segment (icon, bar fill, volume bar). style.volume.bar is
          # just its on/off switch; any other stored value (a pre-0.14 SGR
          # spec) counts as on.
          unless ($hid->("volume.bar")) {
            my $shape = lc($sty{"volume.style"} // "block");
            if ($shape eq "progress") {
              # Five-cell mini bar via the shared builder, so the two bars
              # always match (charset, phase, knob head, smooth edge).
              push @vp, $bar->(5, $v / 100);
            } elsif ($shape eq "stairs") {
              # Staircase: ceil(v*4/100) of ▂▄▆█ (45% -> ▂▄), min one step.
              my @steps = ("\x{2582}", "\x{2584}", "\x{2586}", "\x{2588}");
              my $n = int(($v * 4 + 99) / 100);
              $n = 1 if $n < 1;
              push @vp, $st->($accsgr, join("", @steps[0 .. $n - 1]));
            } else {
              # block (default): eighth-block whose height tracks the level —
              # ceil(v*8/100) maps 1-100 onto ▁..█ (50% = ▄); 0 keeps the
              # lowest sliver and the mute glyph.
              my $i = int(($v * 8 + 99) / 100);
              $i = 1 if $i < 1;
              push @vp, $st->($accsgr, chr(0x2580 + $i));
            }
          }
          push @vp, $st->(sgr($sty{"volume.percent"}), "$v%")
            unless $hid->("volume.percent");
          $tok{volume} = join(" ", @vp) if @vp;
        }
      }
      if ($explicit) {
        my (@lines, @cur);
        for my $f (@order) {
          if ($f eq "/") { push @lines, [@cur] if @cur; @cur = (); next; }
          push @cur, $f;
        }
        push @lines, [@cur] if @cur;
        my @out;
        for my $ln (@lines) {
          my @fs = grep { exists $tok{$_} } @$ln;
          my @parts;
          for my $k (0 .. $#fs) {
            if ($fs[$k] eq "app" && $k > 0 && $fs[$k - 1] eq "track") {
              $parts[-1] .= " " . $href->("claude-media://activate",
                                          $st->($appsgr, "($app)"));
              next;
            }
            push @parts, $tok{$fs[$k]};
          }
          push @out, join("  ", @parts) if @parts;
        }
        print join("\n", @out);
        exit 0;
      }
      my @ro = grep { exists $tok{$_} } @order;
      my %pair = map { $_ => 1 } ("progressbar time", "time progressbar",
                                  "track output", "output track",
                                  "track volume", "volume track",
                                  "output volume", "volume output");
      my @groups;
      my $i = 0;
      while ($i < @ro) {
        my $n = ($i + 1 < @ro) ? $ro[$i + 1] : "";
        if ($n ne "" && $pair{"$ro[$i] $n"}) {
          push @groups, $tok{$ro[$i]} . "  " . $tok{$n};
          $i += 2;
          next;
        }
        push @groups, $tok{$ro[$i]};
        $i++;
      }
      print join($ml ? "\n" : "  ", @groups);
    ' "$fields" "$multiline" "$color" "$marquee" "$styles" "$links" 2>/dev/null || true)"
  fi
  mkdir -p "$DATA_DIR" 2>/dev/null || true
  printf '%s' "$line" > "$cache" 2>/dev/null || true
  printf '%s' "$line"
  return 0
}

# ---- statusline wiring (settings.json install / uninstall) --------------------

# Enabling display.statusline wires the segment into Claude Code by itself:
# the previous "statusLine" value from ~/.claude/settings.json is snapshotted
# into a sidecar backup, a wrapper script runs that previous command first
# (byte-for-byte) and appends the segment, and settings.json is pointed at the
# wrapper. Claude Code has no plugin-uninstall hook, so the wrapper is
# self-healing: on every tick it checks the installed-plugins registry, and
# when the plugin is gone it restores the backed-up "statusLine" and deletes
# itself and the backup — uninstalling the plugin reverts settings.json
# without any manual step. A statusline the user wired by hand (the
# docs/statusline.md recipe, or any command that already runs the segment) is
# detected and never touched.
CLAUDE_SETTINGS_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_SETTINGS_DIR/settings.json"
WRAPPER_FILE="$CLAUDE_SETTINGS_DIR/statusline-media.sh"
WRAPPER_BACKUP_FILE="$CLAUDE_SETTINGS_DIR/statusline-media.backup.json"
WRAPPER_MARKER="managed-by: claude-media-control"

# Print the current settings.json statusLine command (empty when absent or
# not a command-type statusline). Read-only probe; parse errors read as "".
settings_statusline_cmd() {
  [ -f "$SETTINGS_FILE" ] || return 0
  /usr/bin/perl -MJSON::PP -e '
    local $/; my $d = eval { decode_json(<STDIN>) };
    exit 0 unless ref $d eq "HASH" && ref $d->{statusLine} eq "HASH";
    my $c = $d->{statusLine}{command};
    print $c if defined $c && !ref $c;
  ' < "$SETTINGS_FILE" 2>/dev/null
}

# How the segment reaches Claude Code right now: "managed" (our generated
# wrapper), "manual" (the user wired it by hand — never touch it), or "none".
statusline_wiring_state() {
  local cmd
  cmd="$(settings_statusline_cmd)"
  case "$cmd" in
    *statusline-media.sh*)
      if [ -f "$WRAPPER_FILE" ] && /usr/bin/grep -q "$WRAPPER_MARKER" "$WRAPPER_FILE" 2>/dev/null; then
        echo managed
      else
        echo manual
      fi
      ;;
    *media.sh*statusline*)
      echo manual
      ;;
    *)
      echo none
      ;;
  esac
}

# Snapshot the current statusLine into the sidecar backup (null when there is
# none — restore then removes the key) and print its command string for the
# wrapper. Refuses (die -> non-zero) when settings.json cannot be parsed:
# never rewrite a file we cannot read back.
statusline_backup_write() {
  mkdir -p "$CLAUDE_SETTINGS_DIR"
  /usr/bin/perl -MJSON::PP -e '
    my ($settings, $backup) = @ARGV;
    my $s = {};
    if (-f $settings) {
      local $/;
      open my $sf, "<", $settings or die "cannot read $settings: $!\n";
      $s = eval { decode_json(<$sf>) };
      die "cannot parse $settings — fix it first, or wire manually (docs/statusline.md)\n"
        unless ref $s eq "HASH";
      close $sf;
    }
    my $orig = $s->{statusLine};
    my $tmp = "$backup.tmp$$";
    open my $bf, ">", $tmp or die "cannot write $backup: $!\n";
    print $bf JSON::PP->new->utf8->canonical->pretty->space_before(0)
      ->indent_length(2)->encode({ statusLine => $orig });
    close $bf;
    rename $tmp, $backup or die "cannot save $backup: $!\n";
    if (ref $orig eq "HASH" && defined $orig->{command} && !ref $orig->{command}
        && ($orig->{type} // "command") eq "command") {
      print $orig->{command};
    }
  ' "$SETTINGS_FILE" "$WRAPPER_BACKUP_FILE"
}

# The previous statusline command as recorded in the sidecar backup (empty
# when there was none) — the single source of truth for wrapper regeneration.
statusline_backup_cmd() {
  [ -f "$WRAPPER_BACKUP_FILE" ] || return 0
  /usr/bin/perl -MJSON::PP -e '
    local $/; my $d = eval { decode_json(<STDIN>) };
    exit 0 unless ref $d eq "HASH" && ref $d->{statusLine} eq "HASH";
    my $c = $d->{statusLine}{command};
    print $c if defined $c && !ref $c
      && ($d->{statusLine}{type} // "command") eq "command";
  ' < "$WRAPPER_BACKUP_FILE" 2>/dev/null
}

# Generate the wrapper script. $1 = the previous statusline command (may be
# empty or multi-line; embedded through a quoted heredoc so any content is
# safe). The plugin root is recorded for dev checkouts (claude --plugin-dir)
# only — marketplace installs are recognized via the registry, because their
# cache directory is swept lazily and would mask an uninstall.
statusline_wrapper_write() {
  local dev_root=""
  case "$PLUGIN_ROOT" in
    */plugins/cache/*) ;;
    *) dev_root="$PLUGIN_ROOT" ;;
  esac
  mkdir -p "$CLAUDE_SETTINGS_DIR"
  MEDIA_WRAPPER_ORIG="$1" MEDIA_WRAPPER_DEV="$dev_root" /usr/bin/perl -e '
    my $t = do { local $/; <STDIN> };
    my $orig = $ENV{MEDIA_WRAPPER_ORIG} // "";
    my $dev  = $ENV{MEDIA_WRAPPER_DEV} // "";
    $t =~ s/\@ORIG\@/$orig/;
    $t =~ s/\@DEV\@/$dev/;
    print $t;
  ' <<'WRAPPER_EOF' > "$WRAPPER_FILE.tmp"
#!/bin/bash
# statusline-media.sh — your previous statusline (verbatim) + a now-playing
# line from the claude-media-control plugin.
# managed-by: claude-media-control (generated by media.sh statusline install)
#
# Generated file — edits are lost on regeneration. The statusLine value this
# replaced is kept in statusline-media.backup.json; when the media plugin is
# uninstalled, this wrapper restores it into settings.json and deletes itself
# and the backup on the next statusline tick. Unwire manually with:
#   media.sh statusline uninstall
input=$(cat)

# ── 1. The statusline command this install wrapped, byte-for-byte.
EXISTING=$(/bin/cat <<'MEDIA_WRAP_EOF'
@ORIG@
MEDIA_WRAP_EOF
)
[ -n "$EXISTING" ] && printf '%s' "$input" | /bin/bash -c "$EXISTING"

# ── 2. Is the media plugin still installed? Marketplace installs are listed
#       in the registry (their cache dir is swept lazily, so it proves
#       nothing); a dev checkout is the recorded path below.
MEDIA_DEV_ROOT='@DEV@'
installed=""
/usr/bin/grep -q '"media@' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null && installed=1
[ -n "$MEDIA_DEV_ROOT" ] && [ -x "$MEDIA_DEV_ROOT/scripts/media.sh" ] && installed=1
if [ -z "$installed" ]; then
  # Uninstalled -> put the previous statusLine back and retire this wrapper.
  /usr/bin/perl -MJSON::PP -MCwd=abs_path -e '
    my ($settings, $backup) = @ARGV;
    my $real = abs_path($settings) or exit 0;
    local $/;
    open my $sf, "<", $real or exit 0;
    my $s = eval { decode_json(<$sf>) }; close $sf;
    exit 0 unless ref $s eq "HASH";
    my $cur = $s->{statusLine};
    exit 0 unless ref $cur eq "HASH"
      && defined $cur->{command} && !ref $cur->{command}
      && $cur->{command} =~ /statusline-media\.sh/;
    my $orig;
    if (open my $bf, "<", $backup) {
      my $b = eval { decode_json(<$bf>) }; close $bf;
      $orig = $b->{statusLine} if ref $b eq "HASH";
    }
    if (defined $orig) { $s->{statusLine} = $orig } else { delete $s->{statusLine} }
    my $tmp = "$real.tmp$$";
    open my $out, ">", $tmp or exit 0;
    print $out JSON::PP->new->utf8->canonical->pretty->space_before(0)
      ->indent_length(2)->encode($s);
    close $out;
    my @st = stat($real); chmod $st[2] & 07777, $tmp if @st;
    rename $tmp, $real;
  ' "$HOME/.claude/settings.json" "$HOME/.claude/statusline-media.backup.json" 2>/dev/null
  rm -f "$HOME/.claude/statusline-media.sh" "$HOME/.claude/statusline-media.backup.json"
  # The cmd+click handler dies with the plugin too (Claude Code usually
  # sweeps the data dir on uninstall; this covers dev checkouts, where it
  # stays). A stale LaunchServices entry for a deleted bundle is inert.
  LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
  for d in "$HOME"/.claude/plugins/data/media-* "$HOME/.cache/claude-media-control"; do
    [ -d "$d/ClaudeMediaClick.app" ] || { rm -f "$d/click-handler.sh"; continue; }
    [ -x "$LSREG" ] && "$LSREG" -u "$d/ClaudeMediaClick.app" >/dev/null 2>&1
    rm -rf "$d/ClaudeMediaClick.app"
    rm -f "$d/click-handler.sh"
  done
  exit 0
fi

# ── 3. Plugin disabled -> keep the wiring, render nothing extra.
/usr/bin/grep -Eq '"media@[^"]*"[[:space:]]*:[[:space:]]*false' \
  "$HOME/.claude/settings.json" 2>/dev/null && exit 0

# ── 4. Now-playing (empty when off / nothing playing). The newest installed
#       version wins, so the wrapper survives plugin updates.
MEDIA_DIR="$(ls -d "$HOME"/.claude/plugins/cache/*/media/*/ 2>/dev/null \
  | /usr/bin/awk -F/ '{ print $(NF-1) "\t" $0 }' \
  | /usr/bin/sort -t. -k1,1n -k2,2n -k3,3n \
  | /usr/bin/tail -1 | /usr/bin/cut -f2-)"
# Absolute candidates only — an empty MEDIA_DIR or dev root must never turn
# this into a relative path that resolves inside the caller's cwd.
MEDIA_SH=""
[ -n "$MEDIA_DIR" ] && MEDIA_SH="${MEDIA_DIR}scripts/media.sh"
if [ ! -x "$MEDIA_SH" ] && [ -n "$MEDIA_DEV_ROOT" ]; then
  MEDIA_SH="$MEDIA_DEV_ROOT/scripts/media.sh"
fi
if [ -n "$MEDIA_SH" ] && [ -x "$MEDIA_SH" ]; then
  np="$("$MEDIA_SH" statusline 2>/dev/null)"
  [ -n "$np" ] && printf '%s\n' "$np"
fi
exit 0
WRAPPER_EOF
  chmod +x "$WRAPPER_FILE.tmp"
  mv "$WRAPPER_FILE.tmp" "$WRAPPER_FILE"
}

# Point settings.json statusLine at the wrapper, preserving every other key
# of the original statusLine object (padding etc.) and an explicit
# refreshInterval; without one, refreshInterval 1 makes the elapsed time and
# progress bar tick once a second (see docs/statusline.md). Writes through a
# symlink to its target, atomically, keeping the file mode.
statusline_settings_wire() {
  /usr/bin/perl -MJSON::PP -MCwd=abs_path -e '
    my ($settings, $backup) = @ARGV;
    my $s = {};
    my $real = $settings;
    if (-e $settings) {
      $real = abs_path($settings) // $settings;
      local $/;
      open my $sf, "<", $real or die "cannot read $settings: $!\n";
      $s = eval { decode_json(<$sf>) };
      die "cannot parse $settings\n" unless ref $s eq "HASH";
      close $sf;
    }
    my $orig;
    if (open my $bf, "<", $backup) {
      local $/; my $b = eval { decode_json(<$bf>) }; close $bf;
      $orig = $b->{statusLine} if ref $b eq "HASH";
    }
    my %sl = ref $orig eq "HASH" ? %$orig : ();
    $sl{type} = "command";
    $sl{command} = "\"\$HOME/.claude/statusline-media.sh\"";
    $sl{refreshInterval} = 1 unless defined $sl{refreshInterval};
    $s->{statusLine} = \%sl;
    my $tmp = "$real.tmp$$";
    open my $out, ">", $tmp or die "cannot write $settings: $!\n";
    print $out JSON::PP->new->utf8->canonical->pretty->space_before(0)
      ->indent_length(2)->encode($s);
    close $out;
    my @st = stat($real); chmod $st[2] & 07777, $tmp if @st;
    rename $tmp, $real or die "cannot save $settings: $!\n";
  ' "$SETTINGS_FILE" "$WRAPPER_BACKUP_FILE"
}

# Restore the backed-up statusLine into settings.json — but only while
# statusLine still points at our wrapper; a value the user changed since is
# not ours to overwrite. (The wrapper embeds this same logic for the
# self-heal after an uninstall, where this script is gone.)
statusline_settings_restore() {
  /usr/bin/perl -MJSON::PP -MCwd=abs_path -e '
    my ($settings, $backup) = @ARGV;
    exit 0 unless -f $settings;
    my $real = abs_path($settings) // $settings;
    local $/;
    open my $sf, "<", $real or die "cannot read $settings: $!\n";
    my $s = eval { decode_json(<$sf>) }; close $sf;
    die "cannot parse $settings\n" unless ref $s eq "HASH";
    my $cur = $s->{statusLine};
    exit 0 unless ref $cur eq "HASH"
      && defined $cur->{command} && !ref $cur->{command}
      && $cur->{command} =~ /statusline-media\.sh/;
    my $orig;
    if (open my $bf, "<", $backup) {
      my $b = eval { decode_json(<$bf>) }; close $bf;
      $orig = $b->{statusLine} if ref $b eq "HASH";
    }
    if (defined $orig) { $s->{statusLine} = $orig } else { delete $s->{statusLine} }
    my $tmp = "$real.tmp$$";
    open my $out, ">", $tmp or die "cannot write $settings: $!\n";
    print $out JSON::PP->new->utf8->canonical->pretty->space_before(0)
      ->indent_length(2)->encode($s);
    close $out;
    my @st = stat($real); chmod $st[2] & 07777, $tmp if @st;
    rename $tmp, $real or die "cannot save $settings: $!\n";
  ' "$SETTINGS_FILE" "$WRAPPER_BACKUP_FILE"
}

# Wire the segment into settings.json (idempotent). Called by
# `config display.statusline on` so enabling applies immediately, and
# available directly as `media.sh statusline install`.
statusline_install() {
  local state orig_cmd
  state="$(statusline_wiring_state)"
  case "$state" in
    managed)
      # Re-wired on a newer plugin version: refresh the wrapper from the
      # existing backup — never re-backup (settings point at the wrapper now).
      statusline_wrapper_write "$(statusline_backup_cmd)" || return 1
      if [ "$(config_get statusline.links)" = "on" ]; then
        "$SCRIPT_DIR/build-click-handler.sh" >/dev/null 2>&1 || true
      fi
      echo "statusline: already wired into settings.json (wrapper refreshed)."
      return 0
      ;;
    manual)
      echo "statusline: settings.json already runs the media segment through your own setup — leaving it untouched (see docs/statusline.md)."
      return 0
      ;;
  esac
  if ! orig_cmd="$(statusline_backup_write)"; then
    echo "media: statusline wiring refused — could not snapshot $SETTINGS_FILE." >&2
    return 1
  fi
  statusline_wrapper_write "$orig_cmd" || return 1
  if ! statusline_settings_wire; then
    rm -f "$WRAPPER_FILE" "$WRAPPER_BACKUP_FILE"
    echo "media: statusline wiring failed — $SETTINGS_FILE was left unchanged." >&2
    return 1
  fi
  rm -f "$DATA_DIR/statusline.cache"
  if [ -n "$orig_cmd" ]; then
    echo "statusline: wired into settings.json — your previous statusline still runs first (backup: $WRAPPER_BACKUP_FILE; auto-restored if the plugin is uninstalled)."
  else
    echo "statusline: wired into settings.json (no previous statusline; the key is removed again if the plugin is uninstalled)."
  fi
  statusline_click_handler_setup
}

# Best-effort cmd+click support next to the wiring: build + register the
# claude-media:// handler app while statusline.links is on. A failed build
# never blocks the statusline itself — the segment just renders without
# links (the renderer gates on the app's presence).
statusline_click_handler_setup() {
  [ "$(config_get statusline.links)" = "on" ] || return 0
  if "$SCRIPT_DIR/build-click-handler.sh" >/dev/null; then
    echo "statusline: cmd+click enabled — the claude-media:// handler app is registered (disable with /media:config statusline.links off)."
  else
    echo "statusline: click-handler build failed — the segment stays plain (no cmd+click). Retry with /media:config statusline.links on." >&2
  fi
}

# Unwire without uninstalling the plugin: restore the previous statusLine,
# remove the wrapper + backup, and turn the visibility toggle off so state
# stays consistent (re-enabling re-wires).
statusline_uninstall() {
  local state
  state="$(statusline_wiring_state)"
  case "$state" in
    manual)
      echo "media: this statusline was wired by hand — restore your own \"statusLine\" in $SETTINGS_FILE and remove your wrapper yourself (docs/statusline.md)." >&2
      return 1
      ;;
    none)
      if [ -f "$WRAPPER_FILE" ] && /usr/bin/grep -q "$WRAPPER_MARKER" "$WRAPPER_FILE" 2>/dev/null; then
        rm -f "$WRAPPER_FILE" "$WRAPPER_BACKUP_FILE"
        "$SCRIPT_DIR/build-click-handler.sh" --remove >/dev/null 2>&1 || true
        echo "statusline: not wired in settings.json — removed the leftover managed wrapper."
      else
        echo "statusline: not wired — nothing to undo."
      fi
      return 0
      ;;
    managed)
      if ! statusline_settings_restore; then
        echo "media: restoring the previous statusLine in $SETTINGS_FILE failed — nothing was removed." >&2
        return 1
      fi
      rm -f "$WRAPPER_FILE" "$WRAPPER_BACKUP_FILE"
      "$SCRIPT_DIR/build-click-handler.sh" --remove >/dev/null 2>&1 || true
      config_write display.statusline off
      rm -f "$DATA_DIR/statusline.cache"
      echo "statusline: unwired — the previous \"statusLine\" is back in settings.json (display.statusline = off)."
      ;;
  esac
}

do_statusline_status() {
  case "$(statusline_wiring_state)" in
    managed)
      echo "managed — settings.json statusLine runs $WRAPPER_FILE; the previous value is backed up and auto-restored when the plugin is uninstalled." ;;
    manual)
      echo "manual — settings.json statusLine runs the media segment through your own setup; the plugin never touches it (docs/statusline.md)." ;;
    none)
      echo "none — the segment is not wired into settings.json; /media:config display.statusline on wires it automatically." ;;
  esac
}

# ---- config (§4.9: fail-closed enable) ---------------------------------------

CONFIG_KEYS="display.progressbar display.statusline statusline.multiline statusline.color statusline.marquee statusline.links history.record"

# Which segments the statusline renders, in the order they were stored
# (arranged with /media:statusline or /media:config). "output" and "volume"
# need the native helper (the JXA fallback carries no outputDevice /
# volume / muted fields). Besides these fields the stored list may hold "/"
# markers — each one starts a new line and switches the segment to the
# explicit per-line layout (see do_statusline).
VALID_STATUSLINE_FIELDS="track app progressbar time output volume"
DEFAULT_STATUSLINE_FIELDS="track app progressbar time"

config_default() {
  case "$1" in
    display.progressbar) echo on ;;
    display.statusline)  echo off ;;
    statusline.multiline) echo off ;;
    statusline.color)    echo on ;;
    statusline.marquee)  echo on ;;
    statusline.links)    echo on ;;
    history.record)      echo on ;;
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
    print $fh JSON::PP->new->canonical->ascii->encode($d), "\n";
    close $fh;
    rename "$file.tmp", $file or die "cannot save config: $!\n";
  ' "$CONFIG_FILE" "$1" "$2"
}

# Read statusline.fields (JSON array) as a space-separated list in stored
# order, falling back to the default set when the key is absent, empty, or
# malformed. Names that are no longer valid fields (e.g. "spectrum" from a
# pre-0.6.0 config) are filtered out here so stale configs stay harmless.
# "/" line-break markers pass through, normalized: never leading or trailing,
# never doubled (also after invalid neighbors were dropped).
config_get_statusline_fields() {
  local v=""
  if [ -f "$CONFIG_FILE" ]; then
    v="$(/usr/bin/perl -MJSON::PP -e '
      my %valid = map { $_ => 1 } split /\s+/, $ARGV[0];
      local $/; my $d = eval { decode_json(<STDIN>) };
      exit 0 unless ref $d eq "HASH";
      my $a = $d->{"statusline.fields"};
      exit 0 unless ref $a eq "ARRAY";
      my (@out, %seen);
      for my $f (grep { defined && !ref } @$a) {
        if ($f eq "/") { push @out, "/" if @out && $out[-1] ne "/"; next; }
        push @out, $f if $valid{$f} && !$seen{$f}++;
      }
      pop @out while @out && $out[-1] eq "/";
      print join(" ", @out);
    ' "$VALID_STATUSLINE_FIELDS" < "$CONFIG_FILE" 2>/dev/null)"
  fi
  if [ -n "$v" ]; then echo "$v"; else echo "$DEFAULT_STATUSLINE_FIELDS"; fi
}

# Store statusline.fields from a comma/space-separated list, keeping only known
# fields in the order they were given — the segment renders in that order.
# A "/" between items starts a new line (explicit per-line layout; also
# accepted glued to a name, so "track,app/time" splits into `track app / time`).
# Duplicates collapse onto their first occurrence, invalid names are dropped
# silently, breaks are kept only between items (never leading, trailing, or
# doubled), and an empty result is stored as [] — which reads back as the
# default set, like a missing key.
config_set_statusline_fields() {
  local input="$1" ordered="" f g
  input="$(printf '%s' "$input" | tr ',' ' ' | sed 's;/; / ;g')"
  for g in $input; do
    if [ "$g" = "/" ]; then
      case "$ordered" in
        '' | *' /') ;;
        *) ordered="$ordered /" ;;
      esac
      continue
    fi
    for f in $VALID_STATUSLINE_FIELDS; do
      if [ "$f" = "$g" ]; then
        case " $ordered " in
          *" $g "*) ;;
          *) ordered="$ordered $g" ;;
        esac
        break
      fi
    done
  done
  ordered="${ordered% /}"
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
    print $fh JSON::PP->new->canonical->ascii->encode($d), "\n";
    close $fh;
    rename "$file.tmp", $file or die "cannot save config: $!\n";
  ' "$CONFIG_FILE" $ordered
  rm -f "$DATA_DIR/statusline.cache"
  echo "statusline.fields =${ordered:- (none)}"
}

# ---- per-item statusline styles (string-valued style.* keys) -------------------

# Every visible part of the statusline segment has a style.* key. Text parts
# take a style spec — any of "bold dim italic underline" plus at most one
# color (black red green yellow blue magenta cyan white, or bright-<color>),
# "none" for no styling, or "off" to hide that part entirely (off is a text-
# part value only); specs render only while statusline.color is on, but
# "off" hides regardless — it changes content, not styling.
# style.progressbar.style, style.volume.icon, style.volume.style, and
# style.output.icon change the characters instead, so they apply even with
# colors off. style.volume.bar is an on/off toggle: the bar draws in the
# progress-bar playing/paused accent, so it has no spec of its own (a
# pre-0.14 stored spec counts as on). Per key, the value "reset" deletes it
# (back to the default);
# "config style" lists everything, "config style reset" clears all style
# customizations, and "config statusline reset" additionally restores the
# statusline layout/line/color/marquee keys. The defaults reproduce the
# classic rendering, except the bar charset default moved from blocks to
# line in 0.12.0 (set "blocks" to restore the pre-0.12 bar).
STYLE_KEYS="style.track.title style.track.artist style.app style.volume.icon style.volume.style style.volume.bar style.volume.percent style.progressbar.playing style.progressbar.paused style.progressbar.style style.time.elapsed style.time.total style.output.icon style.output"

# Text parts that accept the "off" (hide) value; the icon keys spell hiding
# as none, style.volume.bar is a dedicated on/off toggle, and the bar
# colors/charsets cannot hide (drop the field instead).
STYLE_OFF_KEYS="style.track.title style.track.artist style.app style.volume.percent style.time.elapsed style.time.total style.output"

# Print "key<TAB>value<TAB>default" for every style key, resolved against the
# config file (stored strings win; absent keys fall back to the default).
# This is the single source of the defaults table — the listing, single-key
# get, doctor, and the renderer all consume it.
style_resolve() {
  /usr/bin/perl -MJSON::PP -e '
    binmode STDOUT, ":utf8";
    my @def = (
      ["style.track.title",         "bold"],
      ["style.track.artist",        "italic"],
      ["style.app",                 "dim"],
      ["style.volume.icon",         "auto"],
      ["style.volume.style",        "block"],
      ["style.volume.bar",          "on"],
      ["style.volume.percent",      "dim"],
      ["style.progressbar.playing", "green"],
      ["style.progressbar.paused",  "yellow"],
      ["style.progressbar.style",   "line"],
      ["style.time.elapsed",        "bold"],
      ["style.time.total",          "dim"],
      ["style.output.icon",         "auto"],
      ["style.output",              "dim"],
    );
    my $d = {};
    if (-f $ARGV[0]) {
      local $/;
      if (open my $fh, "<", $ARGV[0]) { $d = eval { decode_json(<$fh>) } || {}; close $fh; }
      $d = {} unless ref $d eq "HASH";
    }
    for my $e (@def) {
      my ($k, $def) = @$e;
      my $v = $d->{$k};
      $v = $def unless defined $v && !ref $v && length $v;
      print "$k\t$v\t$def\n";
    }
  ' "$CONFIG_FILE" 2>/dev/null
}

style_get() {
  style_resolve | /usr/bin/awk -F'\t' -v k="$1" '$1 == k { print $2 }'
}

style_known() {
  local k
  for k in $STYLE_KEYS; do
    [ "$k" = "$1" ] && return 0
  done
  echo "media: unknown style key: $1 (valid: $STYLE_KEYS)" >&2
  return 2
}

# Validate + canonicalize a style value for a key: prints the canonical form,
# exit 2 with a reason on stderr when invalid. -CAS because values may carry
# non-ASCII glyphs (custom volume icons, custom bar characters).
style_validate() {
  /usr/bin/perl -CAS -e '
    my ($key, $val, $offkeys) = @ARGV;
    my %offok = map { $_ => 1 } split /\s+/, ($offkeys // "");
    sub fail { print STDERR "media: $_[0]\n"; exit 2 }
    if ($key eq "style.progressbar.style") {
      # Keep exactly-two-character values raw so a space can be a bar glyph
      # ("x " = filled x, empty space); only longer input is trimmed.
      $val =~ s/^\s+|\s+$//g if length($val) != 2;
      my %preset = map { $_ => 1 }
        qw(blocks wave pulse eq notes braille chevron tape cassette retro
           knob smooth line dots);
      if ($preset{lc $val}) { print lc $val; exit 0 }
      fail("progressbar style must be blocks|wave|pulse|eq|notes|braille|chevron|tape|cassette|retro|knob|smooth|line|dots or exactly two characters (filled+empty, e.g. \"~-\"); got: $val")
        unless length($val) == 2 && $val !~ /[\t\n]/ && $val ne "  ";
      print $val; exit 0;
    }
    $val =~ s/^\s+|\s+$//g;
    if ($key eq "style.volume.style") {
      # Volume bar shape; "default" is accepted as an alias for block.
      my %shape = (block => "block", default => "block",
                   progress => "progress", stairs => "stairs");
      my $s = $shape{lc $val}
        or fail("volume bar style must be block|progress|stairs; got: $val");
      print $s; exit 0;
    }
    if ($key eq "style.volume.bar") {
      # A visibility toggle since 0.14.0 — the bar itself draws in the
      # progress-bar playing/paused accent, so there is no spec to take.
      my %tog = (on => "on", show => "on",
                 off => "off", hide => "off", hidden => "off", none => "off");
      my $t = $tog{lc $val}
        or fail("volume bar is an on/off toggle (its color follows the progress-bar playing/paused colors); got: $val");
      print $t; exit 0;
    }
    if ($key eq "style.volume.icon" || $key eq "style.output.icon") {
      my $what = $key eq "style.volume.icon" ? "volume icon" : "output icon";
      # "off" reads naturally for an icon toggle — canonicalize it to none.
      if (lc($val) eq "auto" || lc($val) eq "none" || lc($val) eq "off") {
        print lc($val) eq "off" ? "none" : lc($val); exit 0;
      }
      fail("$what must be auto, none, or a short glyph (1-8 characters, no whitespace); got: $val")
        unless length($val) >= 1 && length($val) <= 8 && $val !~ /\s/;
      print $val; exit 0;
    }
    my %attr = map { $_ => 1 } qw(bold dim italic underline);
    my %col  = map { $_ => 1 } qw(black red green yellow blue magenta cyan white);
    my (%have, $color, $none, $off);
    my @tok = grep { length } split /[\s,]+/, lc $val;
    fail("empty style — use e.g. \"bold cyan\", or the value reset to restore the default") unless @tok;
    for my $t (@tok) {
      if ($t eq "none" || $t eq "plain") { $none = 1; next }
      if ($t eq "off" || $t eq "hidden") {
        fail("off (hide this part) is not valid for $key - remove the whole item via /media:statusline instead") unless $offok{$key};
        $off = 1; next;
      }
      if ($attr{$t}) { $have{$t} = 1; next }
      (my $c = $t) =~ s/^bright-//;
      if ($col{$c}) {
        fail("only one color per style (got: $color and $t)") if defined $color;
        $color = $t; next;
      }
      fail("invalid style token: $t (valid: bold dim italic underline none, off to hide the part, colors black red green yellow blue magenta cyan white or bright-<color>)");
    }
    fail("none cannot be combined with other style tokens") if $none && (%have || defined $color || $off);
    fail("off cannot be combined with other style tokens") if $off && (%have || defined $color);
    if ($off)  { print "off";  exit 0 }
    if ($none) { print "none"; exit 0 }
    print join(" ", (grep { $have{$_} } qw(bold dim italic underline)),
                    (defined $color ? ($color) : ()));
  ' "$1" "$2" "$STYLE_OFF_KEYS"
}

# Write (or with an empty value delete) one style key. ->ascii keeps the
# config file pure ASCII even for glyph values (\uXXXX escapes), so every
# other reader/writer of config.json stays byte-safe.
style_write() {
  mkdir -p "$DATA_DIR"
  /usr/bin/perl -CA -MJSON::PP -e '
    my ($file, $key, $val) = @ARGV;
    my $d = {};
    if (-f $file) {
      local $/;
      if (open my $fh, "<", $file) { $d = eval { decode_json(<$fh>) } || {}; close $fh; }
      $d = {} unless ref $d eq "HASH";
    }
    if (length $val) { $d->{$key} = $val } else { delete $d->{$key} }
    open my $fh, ">", "$file.tmp" or die "cannot write config: $!\n";
    print $fh JSON::PP->new->canonical->ascii->encode($d), "\n";
    close $fh;
    rename "$file.tmp", $file or die "cannot save config: $!\n";
  ' "$CONFIG_FILE" "$1" "${2:-}"
}

# Delete every style.* key (config style reset).
style_wipe() {
  [ -f "$CONFIG_FILE" ] || return 0
  /usr/bin/perl -MJSON::PP -e '
    local $/;
    open my $fh, "<", $ARGV[0] or exit 0;
    my $d = eval { decode_json(<$fh>) } || {};
    close $fh;
    exit 0 unless ref $d eq "HASH";
    delete $d->{$_} for grep { /^style\./ } keys %$d;
    open my $out, ">", "$ARGV[0].tmp" or exit 0;
    print $out JSON::PP->new->canonical->ascii->encode($d), "\n";
    close $out;
    rename "$ARGV[0].tmp", $ARGV[0];
  ' "$CONFIG_FILE"
}

style_list() {
  echo "style key                     value         default"
  style_resolve | while IFS=$'\t' read -r k v def; do
    if [ "$v" = "$def" ]; then
      printf '%-29s %-13s %s\n' "$k" "$v" "$def"
    else
      printf '%-29s %-13s %s  *custom\n' "$k" "$v" "$def"
    fi
  done
  echo "(spec: bold dim italic underline + one color — black red green yellow blue"
  echo " magenta cyan white or bright-<color> — or none; text parts also take off"
  echo " = hide that part; style.progressbar.style: blocks|wave|pulse|eq|notes|"
  echo " braille|chevron|tape|cassette|retro|knob|smooth|line|dots or two glyphs"
  echo " like \"~-\"; style.volume.style: block|progress|stairs;"
  echo " style.volume.bar: on|off — the bar draws in the progress-bar accent;"
  echo " style.volume.icon / style.output.icon: auto|none|<glyph>."
  echo " Set: media.sh config <style key> \"<spec>\" — the value reset restores a"
  echo " default, media.sh config style reset clears them all, and media.sh config"
  echo " statusline reset also restores the layout/lines/colors/marquee.)"
}

# Delete every statusline appearance key: the arrangement (statusline.fields),
# the line/color/marquee toggles, and all style.* customizations — back to
# the stock look. The display.statusline visibility toggle (and the non-
# statusline features) survive on purpose: this resets how the segment looks,
# not whether it shows.
statusline_wipe() {
  [ -f "$CONFIG_FILE" ] || return 0
  /usr/bin/perl -MJSON::PP -e '
    local $/;
    open my $fh, "<", $ARGV[0] or exit 0;
    my $d = eval { decode_json(<$fh>) } || {};
    close $fh;
    exit 0 unless ref $d eq "HASH";
    delete $d->{$_} for grep { /^style\./ } keys %$d;
    delete $d->{$_} for qw(statusline.fields statusline.multiline
                           statusline.color statusline.marquee);
    open my $out, ">", "$ARGV[0].tmp" or exit 0;
    print $out JSON::PP->new->canonical->ascii->encode($d), "\n";
    close $out;
    rename "$ARGV[0].tmp", $ARGV[0];
  ' "$CONFIG_FILE"
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
    statusline.links)
      # Links are useless without the claude-media:// handler app — build
      # (or refresh) it now and refuse the enable when that fails.
      if "$SCRIPT_DIR/build-click-handler.sh" >/dev/null; then
        return 0
      fi
      echo "media: cannot enable statusline.links — building the claude-media:// click-handler app failed. Run /media:doctor." >&2
      return 3
      ;;
  esac
}

config_known() {
  local k
  for k in $CONFIG_KEYS; do
    [ "$k" = "$1" ] && return 0
  done
  echo "media: unknown config key: $1 (valid keys: $CONFIG_KEYS; per-item styles: media.sh config style)" >&2
  return 2
}

do_config() {
  # Everything after the key joins into one value, so multi-word style specs
  # and field lists work unquoted: config style.track.title bold cyan
  local key="${1:-}" value=""
  if [ $# -gt 1 ]; then
    shift
    value="$*"
  fi

  # statusline.fields is array-valued (arranged with /media:statusline or
  # /media:config); handle it before the boolean keys.
  if [ "$key" = "statusline.fields" ]; then
    if [ -z "$value" ]; then
      config_get_statusline_fields
    else
      config_set_statusline_fields "$value"
    fi
    return 0
  fi

  # Per-item statusline styles (string-valued). "config style" lists them,
  # "config style reset" clears every customization; per key, an empty value
  # prints the resolved value and "reset" restores the default. Any style
  # change drops the segment cache so it redraws on the next tick.
  if [ "$key" = "style" ]; then
    if [ -z "$value" ]; then
      style_list
      return 0
    fi
    if [ "$value" = "reset" ]; then
      style_wipe
      rm -f "$DATA_DIR/statusline.cache"
      echo "style.* = defaults (all statusline styles cleared)"
      return 0
    fi
    echo "media: usage: media.sh config style [reset]   (single key: media.sh config <style key> [\"<spec>\"|reset])" >&2
    exit 2
  fi

  # "config statusline reset" restores the whole statusline appearance —
  # arrangement, explicit lines, color/marquee toggles, and every style.*
  # key — without touching the display.statusline visibility toggle.
  if [ "$key" = "statusline" ]; then
    if [ "$value" = "reset" ]; then
      statusline_wipe
      rm -f "$DATA_DIR/statusline.cache"
      echo "statusline = defaults (arrangement, lines, colors, marquee, and styles restored)"
      return 0
    fi
    echo "media: usage: media.sh config statusline reset   (restore the statusline appearance defaults)" >&2
    exit 2
  fi
  case "$key" in
    style.*)
      style_known "$key" || exit 2
      if [ -z "$value" ]; then
        style_get "$key"
        return 0
      fi
      if [ "$value" = "reset" ]; then
        style_write "$key" ""
        rm -f "$DATA_DIR/statusline.cache"
        echo "$key = $(style_get "$key") (default)"
        return 0
      fi
      local canon
      canon="$(style_validate "$key" "$value")" || exit 2
      style_write "$key" "$canon"
      rm -f "$DATA_DIR/statusline.cache"
      echo "$key = $canon"
      return 0
      ;;
  esac

  if [ -z "$key" ]; then
    local k
    echo "key                   value  notes"
    for k in $CONFIG_KEYS; do
      local note=""
      case "$k" in
        display.progressbar) note="progress bar in /media:now and statusline output" ;;
        display.statusline)  note="statusline now-playing segment (recipe: docs/statusline.md)" ;;
        statusline.multiline) note="statusline layout: on = each group on its own line, off = one line (unused when statusline.fields has / breaks)" ;;
        statusline.color)    note="ANSI colors/bold/italic in the statusline segment (honors NO_COLOR)" ;;
        statusline.marquee)  note="scroll statusline titles wider than 30 cells (1 char/second)" ;;
        statusline.links)    note="cmd+click actions in the statusline: icon toggles, track jumps to the playing media (tab/track), bar seeks (OSC 8 + claude-media:// handler)" ;;
        history.record)      note="log played tracks to history.jsonl (view with /media:history)" ;;
      esac
      printf '%-21s %-6s %s\n' "$k" "$(config_get "$k")" "$note"
    done
    printf '%-21s %-6s %s\n' "statusline.fields" "-" \
      "[$(config_get_statusline_fields)] — items in render order, / starts a new line; arrange with /media:statusline"
    echo ""
    style_list
    echo ""
    echo "usage: media.sh config <key> [on|off|value] | config statusline reset   (config file: $CONFIG_FILE)"
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
      # Enabling the statusline wires the segment into ~/.claude/settings.json
      # by itself (§4.9 fail-closed: refuse the enable when wiring fails, so
      # "on" never silently shows nothing). A manual setup is left untouched.
      if [ "$key" = "display.statusline" ]; then
        statusline_install || exit 3
      fi
      config_write "$key" on
      # Any key that changes what the segment renders drops the stale cache so
      # the change shows up on the next tick instead of after the TTL.
      case "$key" in
        display.statusline | display.progressbar | statusline.multiline | statusline.color | statusline.marquee | statusline.links)
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
        display.statusline | display.progressbar | statusline.multiline | statusline.color | statusline.marquee | statusline.links)
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

  # Output device (CoreAudio via the adapter; needs the native helper).
  local outdev="unavailable (needs the native helper — see [2]/[3])"
  if [ -n "$LIB" ]; then
    local ojson
    if ojson="$(primary_output_list)" && [ -n "$ojson" ]; then
      local ocur ocount
      ocur="$(printf '%s' "$ojson" | json_field current)"
      ocount="$(printf '%s' "$ojson" | /usr/bin/perl -MJSON::PP -e '
        local $/; my $d = eval { decode_json(<STDIN>) };
        print((ref $d eq "HASH" && ref $d->{devices} eq "ARRAY")
          ? scalar @{$d->{devices}} : 0);
      ' 2>/dev/null)"
      outdev="${ocur:-unknown} (${ocount:-0} output devices; switch with /media:output)"
    else
      outdev="FAILED — CoreAudio device read error"
    fi
  fi
  echo "[7] Output dev  : $outdev"
  echo "[8] Statusline  : $(do_statusline_status)"

  # cmd+click actions: the claude-media:// handler app must exist for the
  # segment to render OSC 8 links at all.
  local clicks clickapp
  if [ "$(config_get statusline.links)" != "on" ]; then
    clicks="off (statusline.links) — the segment renders without cmd+click links"
  elif clickapp="$("$SCRIPT_DIR/build-click-handler.sh" --check-only 2>/dev/null)"; then
    clicks="on — handler app registered ($clickapp)"
  else
    clicks="on but the handler app is MISSING — links render plain; rebuild with /media:config statusline.links on"
  fi
  echo "[9] Click links : $clicks"
  echo "[10] Config     : progressbar=$(config_get display.progressbar) statusline=$(config_get display.statusline) color=$(config_get statusline.color) marquee=$(config_get statusline.marquee)"
  echo "                  statusline.fields=[$(config_get_statusline_fields)] history.record=$(config_get history.record) styles=$(style_resolve | /usr/bin/awk -F'\t' '$2 != $3 { n++ } END { print n + 0 }') customized"
  echo "                  ($CONFIG_FILE)"
  echo "[11] Build log  : $DATA_DIR/build.log"
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
  # Keep a managed statusline wrapper current with this plugin version (a
  # plugin update leaves the old generated wrapper behind otherwise). Only
  # ever refreshes existing managed wiring — never creates it.
  if [ "$(statusline_wiring_state)" = "managed" ]; then
    statusline_wrapper_write "$(statusline_backup_cmd)" >/dev/null 2>&1
    # Managed wiring + links on -> the handler pair must exist; this is what
    # brings cmd+click to installs wired before 0.17.0 on their next session.
    if [ "$(config_get statusline.links)" = "on" ]; then
      "$SCRIPT_DIR/build-click-handler.sh" >/dev/null 2>&1
    fi
  elif [ -d "$DATA_DIR/ClaudeMediaClick.app" ]; then
    # Manual setups: never create, only refresh what already exists (the
    # generated click-handler.sh may have changed with this version).
    "$SCRIPT_DIR/build-click-handler.sh" >/dev/null 2>&1
  fi
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
  output)     do_output "${2:-}" ;;
  history)    do_history "${2:-}" "${3:-}" ;;
  statusline)
    case "${2:-}" in
      "")        do_statusline ;;
      install)   statusline_install ;;
      uninstall) statusline_uninstall ;;
      status)    do_statusline_status ;;
      *)         usage ;;
    esac
    ;;
  test)
    ensure_native
    if [ -z "$LIB" ]; then
      echo "media: native helper unavailable — degraded mode. Run /media:doctor." >&2
      exit 1
    fi
    primary_test
    ;;
  config) shift; do_config "$@" ;;
  doctor) do_doctor "${2:-}" ;;
  detect) do_detect ;;
  warmup) do_warmup ;;
  open-url) do_open_url "${2:-}" ;;
  *) usage ;;
esac
