#!/bin/sh
# Copyright (C) 2026 Fiber
#
# This Source Code Form is subject to the terms of the Mozilla Public License,
# v. 2.0. If a copy of the MPL was not distributed with this file, You can
# obtain one at https://mozilla.org/MPL/2.0/.
#
# What you may do:
# - Use this software for any purpose, including commercially, and build and
#   sell your own products on top of it.
# - Change it, and create new works based on it.
# - Distribute copies of it, with or without your changes.
# - Combine it with files under any other licence, proprietary ones included,
#   and licence that larger work on your own terms.
#
# What you must do in return:
# - Keep this notice on every file you received it on.
# - Publish, under these same terms, the source of every file covered by them
#   that you distribute, including the ones you changed, so that whoever
#   receives your version can obtain that source.
# - Leave Fiber out of it: the name "Fiber", its branding, its logos and its
#   trademarks may not be used to endorse or promote what you build, and this
#   licence grants no right to them.
#
# Disclaimer:
# AS FAR AS THE LAW ALLOWS, THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY
# OR CONDITION OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
# WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR
# NON-INFRINGEMENT. IN NO EVENT SHALL FIBER BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT
# LIMITED TO LOSS OF USE, DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT
# OF OR RELATED TO THESE TERMS OR THE USE OR NATURE OF THE SOFTWARE, UNDER ANY
# KIND OF LEGAL CLAIM.
#
# This header is a summary written for convenience. Where it differs from the
# LICENSE file, the LICENSE file governs.

set -eu

REPOSITORY="${SCRIBE_REPOSITORY:-d-fiber/scribe}"
BRANCH="${SCRIBE_BRANCH:-main}"
TOOLS_REPOSITORY="${SCRIBE_TOOLS_REPOSITORY:-d-fiber/scribe_tools}"
CODEX_REPOSITORY="${SCRIBE_CODEX_REPOSITORY:-d-fiber/scribe_codex}"

BINARIES="scribe_linux scribe_macos scribe_windows.exe"
LAUNCHERS="scribe scribe.cmd"
TEMPLATES_ASSET="scribe-templates.tar.gz"
SCRIPTS_ASSET="scribe-scripts.tar.gz"
CHECKSUMS_ASSET="scribe-checksums.txt"
CODEX_ASSET="scribe-codex.tar.gz"

say() { printf '%s\n' "$*"; }
fail() { printf '%s\n' "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

is_scribe_checkout() {
  [ -d "$1/.git" ] && [ -d "$1/tools" ] && [ -f "$1/deno.json" ] && [ -d "$1/engine" ]
}

locate_or_clone() {
  candidate=""

  if [ -n "${SCRIBE_DIRECTORY:-}" ]; then
    candidate="$SCRIBE_DIRECTORY"
  elif is_scribe_checkout "$(pwd)"; then
    candidate="$(pwd)"
  fi

  if [ -n "$candidate" ] && is_scribe_checkout "$candidate"; then
    ROOT="$(cd "$candidate" && pwd)"
    say "Installing into the checkout at $ROOT"
    return
  fi

  ROOT="${SCRIBE_DIRECTORY:-$(pwd)/scribe}"

  if [ -d "$ROOT/.git" ]; then
    say "Reusing the clone at $ROOT"
    return
  fi

  [ -e "$ROOT" ] && fail "$ROOT already exists and is not a scribe clone"

  say "Cloning $REPOSITORY into $ROOT"
  if have git; then
    git clone --branch "$BRANCH" --depth 1 "https://github.com/$REPOSITORY.git" "$ROOT"
  elif have gh; then
    gh repo clone "$REPOSITORY" "$ROOT" -- --branch "$BRANCH" --depth 1
  else
    fail "Needs git. Install it from https://git-scm.com/downloads"
  fi
}

download_from() {
  repository=$1
  asset=$2
  target=$3

  rm -f "$target"

  if have curl; then
    curl -fsSL -o "$target" "https://github.com/$repository/releases/latest/download/$asset" \
      || fail "Could not download $asset from the latest release of $repository"
  elif have gh; then
    gh release download --repo "$repository" --pattern "$asset" --output "$target"
  else
    fail "Needs curl. Install it, or the GitHub CLI: https://cli.github.com"
  fi
}

download() {
  download_from "$TOOLS_REPOSITORY" "$1" "$2"
}

sha256_of() {
  if have sha256sum; then
    sha256sum "$1" | awk '{print $1}'
  elif have shasum; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif have openssl; then
    openssl dgst -sha256 "$1" | awk '{print $NF}'
  else
    fail "Needs sha256sum, shasum or openssl to verify what was downloaded"
  fi
}

verify() {
  target=$1
  name=$2

  want=$(awk -v name="$name" '$2 == name { print $1 }' "$CHECKSUMS_FILE")
  [ -n "$want" ] || fail "$name has no checksum in $CHECKSUMS_ASSET"

  got=$(sha256_of "$target")
  [ "$want" = "$got" ] || fail "$name failed its checksum: expected $want, got $got"
}

fetch_checksums() {
  destination="$ROOT/tools"
  mkdir -p "$destination"
  CHECKSUMS_FILE="$destination/$CHECKSUMS_ASSET"

  say "  $CHECKSUMS_ASSET"
  download "$CHECKSUMS_ASSET" "$CHECKSUMS_FILE"
}

fetch() {
  destination="$ROOT/tools"

  for asset in $BINARIES $LAUNCHERS; do
    say "  $asset"
    download "$asset" "$destination/$asset"
    verify "$destination/$asset" "$asset"
  done

  chmod +x "$destination/scribe_linux" "$destination/scribe_macos" "$destination/scribe" 2>/dev/null || true

  for binary in $BINARIES; do
    [ -s "$destination/$binary" ] || fail "$binary came down empty"
  done
}

fetch_templates() {
  destination="$ROOT/tools"
  archive="$destination/$TEMPLATES_ASSET"

  say "  $TEMPLATES_ASSET"
  download "$TEMPLATES_ASSET" "$archive"
  verify "$archive" "$TEMPLATES_ASSET"

  rm -rf "$destination/templates"
  tar -xzf "$archive" -C "$destination"
  rm -f "$archive"

  [ -d "$destination/templates/project" ] || fail "$TEMPLATES_ASSET carried no templates/project/"
}

fetch_scripts() {
  destination="$ROOT/tools"
  archive="$destination/$SCRIPTS_ASSET"

  say "  $SCRIPTS_ASSET"
  download "$SCRIPTS_ASSET" "$archive"
  verify "$archive" "$SCRIPTS_ASSET"

  rm -rf "$destination/scripts"
  tar -xzf "$archive" -C "$destination"
  rm -f "$archive"

  [ -f "$destination/scripts/sql/schema_bridge.ts" ] || fail "$SCRIPTS_ASSET carried no scripts/sql/schema_bridge.ts"
}

fetch_dashboard() {
  destination="$ROOT/web"
  archive="$destination/$CODEX_ASSET"
  url="https://github.com/$CODEX_REPOSITORY/releases/latest/download/$CODEX_ASSET"
  mkdir -p "$destination"
  rm -f "$archive"

  say "  $CODEX_ASSET"

  # Unlike the CLI's own assets, this one is optional: no release of
  # scribe_codex may carry it yet, and that is not this installer's problem
  # to fail on. A missing dashboard leaves the proxy answering "not
  # installed in this checkout" instead of taking a project down.
  if have curl; then
    curl -fsSL -o "$archive" "$url" || {
      say "  no release of $CODEX_REPOSITORY carries $CODEX_ASSET yet, skipping the dashboard"
      return 0
    }
  elif have gh; then
    gh release download --repo "$CODEX_REPOSITORY" --pattern "$CODEX_ASSET" --output "$archive" || {
      say "  no release of $CODEX_REPOSITORY carries $CODEX_ASSET yet, skipping the dashboard"
      return 0
    }
  else
    say "  needs curl or the GitHub CLI to fetch it, skipping the dashboard"
    return 0
  fi

  rm -rf "$destination/codex"
  tar -xzf "$archive" -C "$destination"
  rm -f "$archive"

  [ -f "$destination/codex/index.html" ] || fail "$CODEX_ASSET carried no codex/index.html"
}

provision() {
  [ -x "$ROOT/tools/scribe" ] || return 0

  say ""
  say "Looking for the programs a project needs, and installing what is missing"
  "$ROOT/tools/scribe" doctor --rescue || say "Some of them are still missing: run scribe doctor to see which."
}

main() {
  locate_or_clone

  say ""
  say "Fetching the tools from the latest release of $TOOLS_REPOSITORY"
  fetch_checksums
  fetch
  fetch_templates
  fetch_scripts
  rm -f "$CHECKSUMS_FILE"

  say ""
  say "Fetching the dashboard from the latest release of $CODEX_REPOSITORY"
  fetch_dashboard

  provision

  say ""
  say "Ready. Everything is in $ROOT/tools"
  say ""
  say "The three builds sit side by side and scribe picks the one this machine runs."
  say "That is what goes on your PATH, and the line is the same on every machine:"
  say "  ln -sfn $ROOT/tools/scribe ~/.local/bin/scribe"
  say ""
  say "On Windows, put $ROOT/tools on your PATH instead: typing scribe finds"
  say "scribe.cmd there, which starts the same build."
  say ""
  say "None of this is committed, so run it again after pulling a release that"
  say "rebuilt the tools or the dashboard."
}

main "$@"
