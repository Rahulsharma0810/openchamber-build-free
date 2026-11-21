#!/usr/bin/env python3
"""Point the Electron app's updater at this repo's GitHub releases.

Usage: patch-updater-feed.py <path/to/updater-feed.mjs> <owner> <repo>

Upstream's updater-feed.mjs has a GitHub feed (owner/repo) and, since 2.7.x,
generic "mirror" feeds on downloads.openchamber.dev that are tried first.
Left unpatched, the app downloads upstream's OpenChamber build, which
Squirrel.Mac then rejects ("Could not locate update bundle for <our appId>").

This script:
  * rewrites the GitHub feed's owner/repo to ours,
  * makes pickUpdaterSource() always choose 'github' (no mirror),
  * rewrites every remaining feed URL to this repo's latest release,
  * fails if anything still points at upstream.
"""
import re
import sys

path, owner, repo = sys.argv[1:4]
src = open(path, encoding="utf-8").read()
orig = src
ours_url = f"https://github.com/{owner}/{repo}/releases/latest/download/"

# GitHub provider feed.
src, n = re.subn(r"owner:\s*'openchamber',", f"owner: '{owner}',", src)
if n != 1:
    sys.exit(f"expected 1 owner: 'openchamber', found {n}")
src, n = re.subn(r"repo:\s*'openchamber',", f"repo: '{repo}',", src)
if n != 1:
    sys.exit(f"expected 1 repo: 'openchamber', found {n}")

# Mirror selection (2.7.x+). Older versions have no pickUpdaterSource.
if "pickUpdaterSource" in src:
    src, n = re.subn(
        r"export const pickUpdaterSource = [\s\S]*?\n\);",
        "export const pickUpdaterSource = () => 'github';",
        src,
        count=1,
    )
    if n != 1:
        sys.exit("could not patch pickUpdaterSource")

# Any generic feed URL (canary, mirrors) -> our latest release.
src = re.sub(
    r"url:\s*'https://(?:downloads\.openchamber\.dev|github\.com/openchamber/openchamber)/[^']*'",
    f"url: '{ours_url}'",
    src,
)

leftover = [
    m for m in ("openchamber.dev", "openchamber/openchamber", "owner: 'openchamber'")
    if m in src
]
if leftover:
    sys.exit(f"upstream updater references remain: {leftover}")
if src == orig:
    sys.exit("nothing patched")

open(path, "w", encoding="utf-8").write(src)
print(src)
