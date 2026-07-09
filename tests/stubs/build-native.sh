#!/bin/bash
# Test stub for scripts/build-native.sh. Behavior is driven by $STUB_BUILD:
#   ok   (default) — "build" succeeds: prints the path of a fake dylib
#   fail           — CLT missing: message on stderr, exit 2 (degraded mode)
#
# The --spectrum path is driven by $STUB_SPECTRUM:
#   signal (default) — builds a fake spectrum tool that prints bars
#   silence          — fake tool captures only silence (exit 3)
#   unavailable      — helper cannot be built (exit 2, e.g. macOS < 14.4)
set -euo pipefail

DATA_DIR="${CLAUDE_PLUGIN_DATA:?stub requires CLAUDE_PLUGIN_DATA}"
FAKE_DYLIB="$DATA_DIR/stub/libadapter.dylib"
FAKE_SPECTRUM="$DATA_DIR/stub/spectrum"

mode="${STUB_BUILD:-ok}"

# ---- spectrum helper stub -------------------------------------------------
if [ "${1:-}" = "--spectrum" ]; then
  smode="${STUB_SPECTRUM:-signal}"
  if [ "$smode" = "unavailable" ]; then
    echo "media: the audio spectrum needs macOS 14.4+ (stub)." >&2
    exit 2
  fi
  if [ "${2:-}" = "--check-only" ]; then
    [ -f "$FAKE_SPECTRUM" ] && { echo "$FAKE_SPECTRUM"; exit 0; }
    exit 1
  fi
  mkdir -p "$(dirname "$FAKE_SPECTRUM")"
  # A tiny executable that honors STUB_SPECTRUM at run time: silence -> exit 3.
  cat > "$FAKE_SPECTRUM" <<'STUBEOF'
#!/bin/bash
[ "${STUB_SPECTRUM:-signal}" = "silence" ] && exit 3
case "${1:-snapshot}" in
  snapshot|live) echo "63Hz ▂▄▆█▇▅▃▂ ▃▂▁▁ ▁ 16kHz   (peak: 1.2kHz)" ;;
  bars)          echo "▂▄▆█▇▅▃▂▃▂" ;;
  preflight)     exit 0 ;;
  *)             exit 64 ;;
esac
exit 0
STUBEOF
  chmod +x "$FAKE_SPECTRUM"
  echo "$FAKE_SPECTRUM"
  exit 0
fi

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
