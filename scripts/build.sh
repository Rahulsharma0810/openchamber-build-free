#!/usr/bin/env bash
# Build opencode-gui (upstream openchamber/openchamber, renamed) for macOS Apple Silicon.
#
# Usage:
#   ./scripts/build.sh           # builds the latest upstream release tag
#   ./scripts/build.sh v2.6.0    # builds a specific upstream tag/ref
#
# Requires: macOS on Apple Silicon (arm64), Xcode command line tools,
# Bun >= 1.4, Node.js >= 24.

set -euo pipefail

if [ "$(uname -m)" != "arm64" ]; then
  echo "error: this script must run on Apple Silicon (arm64), detected $(uname -m)" >&2
  exit 1
fi

UPSTREAM_REPO="openchamber/openchamber"
PRODUCT_NAME="opencode-gui"
APP_ID="dev.opencode-gui.desktop"
RELEASE_OWNER="Rahulsharma0810"
RELEASE_REPO="openchamber-build-free"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$ROOT_DIR/work/openchamber"

REF="${1:-}"
if [ -z "$REF" ]; then
  echo "No ref given, resolving latest upstream release tag..."
  REF=$(gh api "repos/${UPSTREAM_REPO}/releases/latest" --jq '.tag_name' 2>/dev/null || true)
  if [ -z "$REF" ]; then
    echo "error: could not resolve latest release tag (and no ref was given)" >&2
    exit 1
  fi
fi
echo "Building ${UPSTREAM_REPO}@${REF} as ${PRODUCT_NAME}"

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
git clone --depth 1 --branch "$REF" "https://github.com/${UPSTREAM_REPO}.git" "$WORK_DIR"

cd "$WORK_DIR"

echo "Installing dependencies (bun install)..."
bun install --frozen-lockfile

PKG_JSON="packages/electron/package.json"

echo "Patching product name/appId/update feed: ${PRODUCT_NAME} / ${APP_ID} / ${RELEASE_OWNER}/${RELEASE_REPO}"
tmp=$(mktemp)
jq --arg name "$PRODUCT_NAME" --arg appId "$APP_ID" \
   --arg owner "$RELEASE_OWNER" --arg repo "$RELEASE_REPO" '
  .build.productName = $name
  | .build.appId = $appId
  | .build.publish.owner = $owner
  | .build.publish.repo = $repo
' "$PKG_JSON" > "$tmp"
mv "$tmp" "$PKG_JSON"

cd packages/electron

echo "Building web assets..."
bun run build:web-assets

echo "Preparing opencode CLI..."
bun run prepare:opencode-cli
bun run verify:opencode-cli || true

echo "Preparing ripgrep..."
bun run prepare:ripgrep

echo "Bundling main process..."
bun run bundle:main

echo "Rebuilding native modules for arm64..."
bun run rebuild:native

echo "Packaging with electron-builder (mac arm64)..."
ELECTRON_BUILDER_ARCH=arm64 ./node_modules/.bin/electron-builder --mac --arm64 --publish=never

bun run verify:opencode-cli:packaged || true

echo
echo "Build complete. Artifacts:"
find dist -maxdepth 1 \( -name "*.dmg" -o -name "*.zip" -o -name "latest-mac.yml" \) -print
