# opencode-gui

GitHub Actions builds of upstream [OpenChamber](https://github.com/openchamber/openchamber) for macOS (Apple Silicon / arm64), rebranded as **opencode-gui**.

OpenChamber is MIT-licensed; this repo only automates building it from source and renaming the resulting app. No functional patches are applied — it is a straight build of whatever upstream tag/ref is selected.

## Overview

`.github/workflows/build-release.yml` checks out upstream `openchamber/openchamber` at a tag (latest `v*` by default, or any ref you choose via manual dispatch), builds the Electron desktop app for macOS arm64 with Bun + electron-builder, renames the product to `opencode-gui`, and publishes a GitHub release with the `.dmg` and `.zip` artifacts.

`scripts/build.sh` does the same build locally on an Apple Silicon Mac, for testing before (or instead of) running CI.

## Install

1. Download the DMG from the [latest release](https://github.com/Rahulsharma0810/openchamber-build-free/releases/latest) and drag `OpenCode GUI.app` to `/Applications`.
2. The build is signed with a self-signed certificate (`signing/opencode-gui-codesign.cer`, SHA-1 `E2:94:B1:6A:CB:5C:68:56:34:24:94:97:FB:83:42:F6:FC:1B:85:2E`), not an Apple Developer ID, and is not notarized. Gatekeeper will block it on first launch:
   ```bash
   xattr -dr com.apple.quarantine "/Applications/OpenCode GUI.app"
   ```
   or right-click the app → **Open**.

## Auto-update

OpenChamber already ships with `electron-updater` (GitHub provider) built in — upstream just points it at `openchamber/openchamber`. The build/release workflow repoints `build.publish.owner`/`repo` at **this** repo before packaging, so every installed `OpenCode GUI.app` checks *this* repo's releases for updates, not upstream's. Each release includes `latest-mac.yml` (the update manifest electron-updater reads) alongside the `.dmg`/`.zip`, so once you've installed one release, later releases install themselves automatically — no manual re-download needed.

## Manual builds

```bash
gh workflow run build-release.yml -R Rahulsharma0810/openchamber-build-free \
  -f ref=v2.6.0
```

Leave `ref` empty to build the latest upstream release tag. The workflow also runs on a schedule (every 6h) and skips automatically if a release for that upstream tag already exists in this repo.

## Local build (Apple Silicon only)

```bash
./scripts/build.sh            # builds latest upstream tag
./scripts/build.sh v2.6.0      # builds a specific tag/ref
```

Requires: macOS on Apple Silicon (arm64), Xcode command line tools, [Bun](https://bun.sh) >= 1.4, Node.js >= 24.

Output lands in `work/openchamber/packages/electron/dist/`.

## How the rename works

Upstream's Electron package (`packages/electron/package.json`) defines `productName: "OpenChamber"` and `appId: "dev.openchamber.desktop"`. Before packaging, both the build script and the CI workflow patch those fields (via `jq`) to:

- `productName`: `OpenCode GUI`
- `appId`: `dev.opencode-gui.desktop`

so the resulting `.app`, `.dmg`, and release asset names all read `opencode-gui-*` instead of `OpenChamber-*`. No other source files are modified — this is a rename/repackage only, not a fork with behavior changes.

## Attribution & license

OpenChamber is Copyright (c) 2025 Bohdan Triapitsyn, licensed under the [MIT License](LICENSE) (copied unmodified from upstream). All credit for the application itself belongs to the upstream [openchamber/openchamber](https://github.com/openchamber/openchamber) project and its contributors. This repository exists only to provide ready-to-run macOS Apple Silicon builds under a different display name; it claims no authorship over OpenChamber's code.

## Build notes

- Runner: `macos-15` (Apple Silicon / arm64).
- Build tool: Bun workspaces + `electron-builder` (OpenChamber is an Electron app, not Tauri).
- Targets: `dmg` and `zip` (`.app` bundle), arm64 only.
- Signing: every build is signed with the same self-signed certificate (secrets `MAC_CSC_LINK` / `MAC_CSC_KEY_PASSWORD`). That keeps the app's designated requirement stable, so in-app updates (Squirrel.Mac) install. Ad-hoc builds (2.7.1 and earlier) can't auto-update to a signed build: install the first signed build by hand. Rotating the certificate needs one more manual install. Users must clear quarantine on first run (see Install above).
- The workflow derives the release tag from the upstream tag/ref that was built (e.g. upstream `v2.6.0` → this repo's release `v2.6.0`), so it's easy to tell which upstream version a given release corresponds to.
