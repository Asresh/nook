#!/usr/bin/env bash
set -euo pipefail

ASSUME_YES=0
CHECK_ONLY=0
BUILD=0
QUIET=0

usage() {
  cat <<'EOF'
Nook setup: check required tools and offer to install whatever is missing.

Usage: ./scripts/setup.sh [options]

Options:
  -y, --yes     Accept every install prompt (CI / automation)
      --check   Report missing tools and exit; install nothing
      --build   Run `flutter build web` after the checks pass
  -q, --quiet   Suppress non-essential output
  -h, --help    Show this help

Nothing is installed without your confirmation unless --yes is passed.
If you decline an install, the script exits non-zero and the build stops.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes) ASSUME_YES=1 ;;
    --check) CHECK_ONLY=1 ;;
    --build) BUILD=1 ;;
    -q|--quiet) QUIET=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

say() { [[ $QUIET -eq 1 ]] || printf '%s\n' "$*"; }
note() { printf '%s\n' "$*" >&2; }

ask() {
  local prompt="$1"
  if [[ $ASSUME_YES -eq 1 ]]; then
    say "Auto-confirmed: $prompt"
    return 0
  fi
  if [[ ! -t 0 ]]; then
    note "No TTY available to answer: $prompt"
    note "Re-run with --yes or install it manually, then try again."
    return 1
  fi
  local reply
  read -r -p "$prompt [y/N] " reply
  [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}

require_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    note "Homebrew is required to install missing tools."
    note "Install it from https://brew.sh, then re-run this script."
    exit 1
  fi
}

stop_missing() {
  note "Build stopped: $1 is required but was not installed."
  exit 1
}

install_cask() {
  local cask="$1" label="$2"
  if [[ $CHECK_ONLY -eq 1 ]]; then
    note "Missing: $label"
    exit 1
  fi
  require_brew
  if ! ask "Install $label with Homebrew?"; then
    stop_missing "$label"
  fi
  say "Installing $label..."
  brew install --cask "$cask"
}

install_formula() {
  local formula="$1" label="$2"
  if [[ $CHECK_ONLY -eq 1 ]]; then
    note "Missing: $label"
    exit 1
  fi
  require_brew
  if ! ask "Install $label with Homebrew?"; then
    stop_missing "$label"
  fi
  say "Installing $label..."
  brew install "$formula"
}

has_chrome() {
  [[ -d "/Applications/Google Chrome.app" ]] ||
    command -v google-chrome >/dev/null 2>&1 ||
    command -v chromium >/dev/null 2>&1
}

say "Checking Nook's local toolchain..."

# Homebrew is only needed when something must be installed.
if ! command -v brew >/dev/null 2>&1; then
  if ! command -v flutter >/dev/null 2>&1 ||
    ! has_chrome ||
    ! command -v go >/dev/null 2>&1 ||
    [[ ! -x "${LIVEKIT_SERVER_BIN:-$HOME/.local/bin/livekit-server}" ]]; then
    note "Homebrew is not installed and tools are missing."
    note "Install Homebrew from https://brew.sh, then re-run this script."
    exit 1
  fi
fi

# 1. Flutter + Dart
if ! command -v flutter >/dev/null 2>&1; then
  install_cask flutter "Flutter"
fi

hash -r 2>/dev/null || true

if ! command -v dart >/dev/null 2>&1; then
  FLUTTER_BIN="$(command -v flutter || true)"
  if [[ -n "$FLUTTER_BIN" && -x "$(dirname "$FLUTTER_BIN")/dart" ]]; then
    export PATH="$(dirname "$FLUTTER_BIN"):$PATH"
    hash -r 2>/dev/null || true
  fi
fi

if ! command -v dart >/dev/null 2>&1; then
  note "Dart was not found even though Flutter is installed."
  note "Open a new terminal (or add Flutter's bin directory to PATH), then re-run."
  exit 1
fi

# 2. Required shell utilities
for cmd in git curl lsof; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    note "Required command '$cmd' is missing. Install it, then re-run."
    exit 1
  fi
done

# 3. Chrome (default Flutter web target)
if ! has_chrome; then
  install_cask google-chrome "Google Chrome"
fi

# 4. LiveKit server
LIVEKIT_BIN="${LIVEKIT_SERVER_BIN:-$HOME/.local/bin/livekit-server}"
if [[ ! -x "$LIVEKIT_BIN" ]]; then
  note "livekit-server is missing at $LIVEKIT_BIN"

  if ! command -v go >/dev/null 2>&1; then
    install_formula go "Go (needed to compile livekit-server)"
  fi

  if [[ $CHECK_ONLY -eq 1 ]]; then
    note "Missing: livekit-server (build it with Go)"
    exit 1
  fi

  if ! ask "Download and compile livekit-server v1.13.11 into ~/.local/bin?"; then
    stop_missing "livekit-server"
  fi

  BUILD_DIR="${TMPDIR:-/tmp}/nook-livekit-build"
  say "Compiling livekit-server (this can take a few minutes)..."
  rm -rf "$BUILD_DIR"
  git clone --depth 1 --branch v1.13.11 \
    https://github.com/livekit/livekit.git "$BUILD_DIR"
  mkdir -p "$(dirname "$LIVEKIT_BIN")"
  (
    cd "$BUILD_DIR"
    go build -o "$LIVEKIT_BIN" ./cmd/server
  )
  say "Built $LIVEKIT_BIN"
fi

# 5. Optional native toolchains
if [[ ! -d "/Applications/Xcode.app" ]]; then
  say "Note: full Xcode not found. Web works now; iOS builds need Xcode."
fi
if ! command -v pod >/dev/null 2>&1; then
  say "Note: CocoaPods not found. Only needed for iOS/macOS builds."
fi

if [[ $CHECK_ONLY -eq 1 ]]; then
  say "All required tools are available."
  exit 0
fi

say "Fetching Dart packages..."
flutter pub get

if [[ $BUILD -eq 1 ]]; then
  say "Building the web app..."
  flutter build web
  say "Build complete: build/web"
else
  say "Tools ready."
fi

say "Next: ./scripts/dev.sh"
