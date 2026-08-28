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

BINARIES="scribe_linux scribe_macos scribe_windows.exe"
LAUNCHERS="scribe scribe.cmd"
TEMPLATES_ASSET="scribe-templates.tar.gz"

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

download() {
  asset=$1
  target=$2

  rm -f "$target"

  if have curl; then
    curl -fsSL -o "$target" "https://github.com/$TOOLS_REPOSITORY/releases/latest/download/$asset" \
      || fail "Could not download $asset from the latest release of $TOOLS_REPOSITORY"
  elif have gh; then
    gh release download --repo "$TOOLS_REPOSITORY" --pattern "$asset" --output "$target"
  else
    fail "Needs curl. Install it, or the GitHub CLI: https://cli.github.com"
  fi
}

fetch() {
  destination="$ROOT/tools"
  mkdir -p "$destination"

  for asset in $BINARIES $LAUNCHERS; do
    say "  $asset"
    download "$asset" "$destination/$asset"
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

  rm -rf "$destination/templates"
  tar -xzf "$archive" -C "$destination"
  rm -f "$archive"

  [ -d "$destination/templates/project" ] || fail "$TEMPLATES_ASSET carried no templates/project/"
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
  fetch
  fetch_templates

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
  say "rebuilt the tools."
}

main "$@"
