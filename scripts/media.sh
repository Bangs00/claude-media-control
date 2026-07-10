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
  artwork [path-prefix] | volume [0-100] | output [device] | statusline
  history [count | clear | --json [count]]
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

# Log a now-playing JSON snapshot into history.jsonl. Piggybacks on reads
# that happen anyway (now / control re-reads / statusline ticks) — history
# never polls on its own, so its cost is one short perl per read, and a
# write only when the track actually changed. One perl handles everything:
# the history.record gate, dedup against the last entry, append, and the
# size cap (oldest entries dropped past HISTORY_MAX_ENTRIES).
history_record() {
  mkdir -p "$DATA_DIR" 2>/dev/null || true
  printf '%s' "$1" | /usr/bin/perl -MJSON::PP -e '
    my ($config, $file, $max) = @ARGV;
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
    exit 0 unless ref $d eq "HASH" && defined $d->{title};
    my $key = join "\x1f", map { $d->{$_} // "" }
      qw(title artist bundleIdentifier);
    my @lines;
    if (open my $fh, "<", $file) { chomp(@lines = <$fh>); close $fh; }
    if (@lines) {
      my $last = eval { decode_json($lines[-1]) };
      if (ref $last eq "HASH") {
        my $lk = join "\x1f", map { $last->{$_} // "" }
          qw(title artist bundleIdentifier);
        exit 0 if $lk eq $key;
      }
    }
    my %e = (ts => time());
    for (qw(title artist album appName bundleIdentifier)) {
      $e{$_} = $d->{$_} if defined $d->{$_};
    }
    push @lines, JSON::PP->new->canonical->encode(\%e);
    if (@lines > $max) {
      splice @lines, 0, @lines - $max;
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
    2>/dev/null || true
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
  local fields json line="" multiline color marquee
  fields="$(config_get_statusline_fields)"
  multiline="$(config_get statusline.multiline)"
  marquee="$(config_get statusline.marquee)"
  # NO_COLOR (https://no-color.org) beats the config key. The cache may serve
  # a line rendered under the other setting for at most one TTL second.
  color="$(config_get statusline.color)"
  [ -n "${NO_COLOR:-}" ] && color=off
  json="$(do_now 2>/dev/null || echo null)"
  if [ -n "$json" ] && [ "$json" != "null" ]; then
    # Render the chosen fields as groups in their stored order (arrange with
    # /media:statusline), joined by two spaces inline or a newline in multiline
    # layout. `app` folds into the track group when both are chosen; adjacent
    # progressbar+time share one group, and `output` merges into an adjacent
    # track group (so `track,app,output,progressbar,time` stacks as two lines:
    # track+app+output / bar+time). Adjacency is judged over the fields that
    # actually rendered a token, so a folded `app` between track and output is
    # transparent. A "/" in the stored fields switches to the explicit layout:
    # each "/" starts a new line, items render in the given order joined by
    # two spaces, and the grouping rules plus statusline.multiline no longer
    # apply — the user's lines ARE the layout. In a line, `app` right after
    # `track` still folds into it as "(App)"; anywhere else it renders as the
    # plain app name. A line whose items all rendered nothing (e.g. `output`
    # without the native helper) disappears entirely — no blank lines.
    # Fields the user didn't pick are omitted; Claude Code renders
    # multi-line statuslines as-is. Styling (statusline.color on):
    # state-colored icon + filled bar (green playing / yellow paused), bold
    # title and elapsed time (the moving part must stay readable, so only
    # the "/duration" tail is dim), italic artist, dim chrome. Claude Code
    # statuslines render ANSI SGR
    # codes; every token resets with \e[0m so surrounding statusline content is
    # never restyled. statusline.marquee scrolls titles wider than 30 display
    # cells through a fixed window, one character per second (offset derives
    # from the epoch, so each 1s cache refresh advances it — no state file
    # needed).
    line="$(printf '%s' "$json" | /usr/bin/perl -MJSON::PP -e '
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
        ($c && length $t) ? "\e[${codes}m$t\e[0m" : $t;
      };
      my $accent = $d->{playing} ? 32 : 33;
      my $app = $d->{appName} // $d->{bundleIdentifier};
      # One token per renderable field; the order pass below assembles them.
      my %tok;
      if ($w{track}) {
        my $icon = $d->{playing} ? "\x{25B6}\x{FE0E}" : "\x{23F8}";
        my $title = $mq ? marquee($d->{title}) : $d->{title};
        my $t = $st->("1;$accent", $icon) . " " . $st->(1, $title);
        $t .= " " . $st->(2, "\x{2014}") . " " . $st->(3, $d->{artist})
          if defined $d->{artist};
        $t .= " " . $st->(2, "($app)")
          if !$explicit && $w{app} && defined $app;
        $tok{track} = $t;
      }
      # Standalone app token: always in the explicit layout (folding happens
      # per line during assembly), only without a track in the grouped one.
      if ($w{app} && defined $app && ($explicit || !$w{track})) {
        $tok{app} = $st->(2, $app);
      }
      my $pos = $d->{elapsedTimeNow} // $d->{elapsedTime};
      my $dur = $d->{duration};
      if ($w{progressbar} && defined $pos && defined $dur && $dur > 0) {
        my $cells = 10;
        my $r = $pos / $dur; $r = 0 if $r < 0; $r = 1 if $r > 1;
        my $filled = int($r * $cells + 0.5);
        $tok{progressbar} = $st->($accent, "\x{2588}" x $filled)
                          . $st->(2, "\x{2591}" x ($cells - $filled));
      }
      if ($w{time} && defined $pos) {
        $tok{time} = $st->(1, mss($pos))
                   . $st->(2, "/" . (defined $dur ? mss($dur) : "LIVE"));
      }
      if ($w{output} && defined $d->{outputDevice}) {
        $tok{output} = $st->(2, "\x{1F50A} " . $d->{outputDevice});
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
              $parts[-1] .= " " . $st->(2, "($app)");
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
                                  "track output", "output track");
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
    ' "$fields" "$multiline" "$color" "$marquee" 2>/dev/null || true)"
  fi
  mkdir -p "$DATA_DIR" 2>/dev/null || true
  printf '%s' "$line" > "$cache" 2>/dev/null || true
  printf '%s' "$line"
  return 0
}

# ---- config (§4.9: fail-closed enable) ---------------------------------------

CONFIG_KEYS="display.progressbar display.statusline statusline.multiline statusline.color statusline.marquee history.record"

# Which segments the statusline renders, in the order they were stored
# (arranged with /media:statusline or /media:config). "output" needs the
# native helper (the JXA fallback carries no outputDevice field). Besides
# these fields the stored list may hold "/" markers — each one starts a new
# line and switches the segment to the explicit per-line layout (see
# do_statusline).
VALID_STATUSLINE_FIELDS="track app progressbar time output"
DEFAULT_STATUSLINE_FIELDS="track app progressbar time"

config_default() {
  case "$1" in
    display.progressbar) echo on ;;
    display.statusline)  echo off ;;
    statusline.multiline) echo off ;;
    statusline.color)    echo on ;;
    statusline.marquee)  echo on ;;
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
    print $fh JSON::PP->new->canonical->encode($d), "\n";
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
        history.record)      note="log played tracks to history.jsonl (view with /media:history)" ;;
      esac
      printf '%-21s %-6s %s\n' "$k" "$(config_get "$k")" "$note"
    done
    printf '%-21s %-6s %s\n' "statusline.fields" "-" \
      "[$(config_get_statusline_fields)] — items in render order, / starts a new line; arrange with /media:statusline"
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
        display.statusline | display.progressbar | statusline.multiline | statusline.color | statusline.marquee)
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
        display.statusline | display.progressbar | statusline.multiline | statusline.color | statusline.marquee)
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
  echo "[8] Config      : progressbar=$(config_get display.progressbar) statusline=$(config_get display.statusline) color=$(config_get statusline.color) marquee=$(config_get statusline.marquee)"
  echo "                  statusline.fields=[$(config_get_statusline_fields)] history.record=$(config_get history.record)"
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
  output)     do_output "${2:-}" ;;
  history)    do_history "${2:-}" "${3:-}" ;;
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
