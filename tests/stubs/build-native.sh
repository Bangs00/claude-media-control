#!/bin/bash
# Test stub for scripts/build-native.sh. Behavior is driven by $STUB_BUILD:
#   ok   (default) — "build" succeeds: prints the path of a fake dylib
#   fail           — CLT missing: message on stderr, exit 2 (degraded mode)
set -euo pipefail

DATA_DIR="${CLAUDE_PLUGIN_DATA:?stub requires CLAUDE_PLUGIN_DATA}"
FAKE_DYLIB="$DATA_DIR/stub/libadapter.dylib"

mode="${STUB_BUILD:-ok}"

if [ "${1:-}" = "--check-only" ]; then
  if [ "$mode" = "ok" ] && [ -f "$FAKE_DYLIB" ]; then
    echo "$FAKE_DYLIB"
    exit 0
  fi
  exit 1
fi

if [ "$mode" = "fail" ]; then
  echo "media: Xcode Command Line Tools not found (xcode-select -p failed)." >&2
  exit 2
fi

mkdir -p "$(dirname "$FAKE_DYLIB")"
: > "$FAKE_DYLIB"
echo "$FAKE_DYLIB"
