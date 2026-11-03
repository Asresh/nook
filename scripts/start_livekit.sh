#!/usr/bin/env bash
set -euo pipefail

BIN="${LIVEKIT_SERVER_BIN:-$HOME/.local/bin/livekit-server}"

if [[ ! -x "$BIN" ]]; then
  echo "livekit-server not found at $BIN"
  echo "Build it with: go install github.com/livekit/livekit/cmd/server@latest"
  echo "Or set LIVEKIT_SERVER_BIN to an existing binary."
  exit 1
fi

exec "$BIN" --dev --bind 127.0.0.1 "$@"
