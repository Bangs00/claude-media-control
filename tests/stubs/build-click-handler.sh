#!/bin/bash
# Test stub for scripts/build-click-handler.sh — no osacompile, no plutil,
# no LaunchServices. $STUB_CLICK (ok|fail) drives the default build mode;
# ok materializes a fake app bundle dir + handler script under
# $CLAUDE_PLUGIN_DATA so media.sh's presence gates (renderer, doctor) see
# them, fail exits 1 like a real build failure.
set -euo pipefail

DATA_DIR="${CLAUDE_PLUGIN_DATA:?tests always set CLAUDE_PLUGIN_DATA}"
APP="$DATA_DIR/ClaudeMediaClick.app"
HANDLER_SH="$DATA_DIR/click-handler.sh"

mode="${1:-}"

if [ "$mode" = "--check-only" ]; then
  if [ -d "$APP" ] && [ -x "$HANDLER_SH" ]; then
    echo "$APP"
    exit 0
  fi
  exit 1
fi

if [ "$mode" = "--remove" ]; then
  rm -rf "$APP"
  rm -f "$HANDLER_SH"
  exit 0
fi

if [ "${STUB_CLICK:-ok}" = "fail" ]; then
  echo "stub: click-handler build failed" >&2
  exit 1
fi

mkdir -p "$APP"
printf '#!/bin/bash\n# stub click-handler\n' > "$HANDLER_SH"
chmod +x "$HANDLER_SH"
echo "$APP"
