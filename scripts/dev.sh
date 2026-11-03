#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

LIVEKIT_BIN="${LIVEKIT_SERVER_BIN:-$HOME/.local/bin/livekit-server}"

if ! lsof -iTCP:7880 -sTCP:LISTEN >/dev/null 2>&1; then
  if [[ ! -x "$LIVEKIT_BIN" ]]; then
    echo "livekit-server is missing. Build it first (see README.md)." >&2
    exit 1
  fi
  "$LIVEKIT_BIN" --dev --bind 127.0.0.1 >/tmp/nook-livekit.log 2>&1 &
  echo "LiveKit dev server started (log: /tmp/nook-livekit.log)"
else
  echo "LiveKit already listening on :7880"
fi

if ! lsof -iTCP:8787 -sTCP:LISTEN >/dev/null 2>&1; then
  dart run tool/dev_token_server.dart >/tmp/nook-token.log 2>&1 &
  echo "Token server started (log: /tmp/nook-token.log)"
else
  echo "Token server already listening on :8787"
fi

sleep 1
exec flutter run -d chrome --web-port=5173 "$@"
