#!/bin/bash
# build-native.sh — compile native/adapter.m into a cached libadapter.dylib.
#
# Cache layout:  <data-dir>/build/<plugin-version>-<os-build>-<arch>/libadapter.dylib
# The cache key includes the macOS build version so a macOS update triggers an
# automatic rebuild (and re-validation of the private-API technique).
#
# Usage:
#   build-native.sh              ensure the dylib exists (build if needed);
#                                prints its absolute path on stdout
#   build-native.sh --check-only exit 0 + path if the cache is current,
#                                exit 1 without building otherwise
#   build-native.sh --rebuild    discard the cache and build from scratch
#
# Exit codes: 0 ok, 1 build failed / cache missing, 2 Xcode CLT not installed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# CLAUDE_PLUGIN_DATA is provided by Claude Code and survives plugin updates;
# it is removed automatically on uninstall. Outside a session (statusline
# commands, direct shell use) it is absent — fall back to the known plugin
# data locations so there is exactly one build cache, then to ~/.cache
# (older Claude Code versions). Keep in sync with media.sh.
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
BUILD_ROOT="$DATA_DIR/build"
LOG_FILE="$DATA_DIR/build.log"

plugin_version() {
  /usr/bin/perl -MJSON::PP -e '
    local $/;
    my $j = eval { decode_json(<STDIN>) };
    print(($j && $j->{version}) ? $j->{version} : "0.0.0");
  ' < "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null || echo "0.0.0"
}

CACHE_KEY="$(plugin_version)-$(/usr/bin/sw_vers -buildVersion)-$(/usr/bin/uname -m)"
CACHE_DIR="$BUILD_ROOT/$CACHE_KEY"
DYLIB="$CACHE_DIR/libadapter.dylib"

mode="${1:-}"

if [ "$mode" = "--check-only" ]; then
  if [ -f "$DYLIB" ]; then
    echo "$DYLIB"
    exit 0
  fi
  exit 1
fi

if [ "$mode" = "--rebuild" ]; then
  rm -rf "$BUILD_ROOT"
fi

if [ -f "$DYLIB" ]; then
  echo "$DYLIB"
  exit 0
fi

# Detect the Xcode Command Line Tools via xcode-select. Never invoke clang
# blindly: on a machine without CLT that pops up a GUI install dialog.
if ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
  echo "media: Xcode Command Line Tools not found (xcode-select -p failed)." >&2
  echo "media: install with: xcode-select --install — falling back to degraded mode." >&2
  exit 2
fi

if ! mkdir -p "$CACHE_DIR" 2>/dev/null; then
  echo "media: cannot create build cache at $CACHE_DIR — falling back to degraded mode. Run /media:doctor." >&2
  exit 1
fi

echo "First run: building native helper (~2s)..." >&2

tmp_dylib="$CACHE_DIR/.libadapter.$$.tmp"
trap 'rm -f "$tmp_dylib"' EXIT

{
  echo "== $(date '+%Y-%m-%dT%H:%M:%S%z') build $CACHE_KEY =="
  echo "clang: $(/usr/bin/xcrun --find clang 2>/dev/null || echo 'xcrun lookup failed')"
} >> "$LOG_FILE" 2>&1 || true

if ! /usr/bin/clang -fobjc-arc -dynamiclib -fvisibility=default -Wall \
    -framework Foundation -framework AppKit \
    "$PLUGIN_ROOT/native/adapter.m" -o "$tmp_dylib" >> "$LOG_FILE" 2>&1; then
  echo "media: native build failed — see $LOG_FILE. Falling back to degraded mode. Run /media:doctor for help." >&2
  exit 1
fi

# Atomic placement: concurrent first runs both end up with an identical file.
mv -f "$tmp_dylib" "$DYLIB"
trap - EXIT
echo "== build ok: $DYLIB ==" >> "$LOG_FILE" 2>&1 || true

# Drop caches for other keys (old plugin versions / old macOS builds).
for d in "$BUILD_ROOT"/*/; do
  [ -d "$d" ] || continue
  case "$d" in
    "$CACHE_DIR"/) ;;
    *) rm -rf "$d" ;;
  esac
done

echo "$DYLIB"
