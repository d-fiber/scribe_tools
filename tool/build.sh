#!/usr/bin/env bash
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

set -euo pipefail

package=$(cd "$(dirname "$0")/.." && pwd)
destination=${1:-$package/out}

extension=""
case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*) extension=".exe" ;;
esac

binary="$destination/scribe$extension"

if ! command -v dart >/dev/null 2>&1; then
  echo "dart is not on your PATH. Install the Dart SDK, then run this again." >&2
  echo "  https://dart.dev/get-dart" >&2
  exit 1
fi

cd "$package"

dart pub get

mkdir -p "$destination"

version=$(awk '/^version:/ { print $2; exit }' pubspec.yaml)

dart compile exe bin/scribe.dart -o "$binary" --define=SCRIBE_VERSION="$version"

echo ""
echo "Built $binary $version ($(du -h "$binary" | cut -f1))"
echo ""
echo "out/ is ignored by git, so this binary never reaches a commit."

shortcut=$(command -v scribe 2>/dev/null || true)

if [ -n "$shortcut" ] && [ "$shortcut" -ef "$binary" ]; then
  echo "Typing scribe runs this build: $shortcut points here."
  exit 0
fi

if [ -n "$shortcut" ]; then
  echo "Careful: typing scribe runs $shortcut, which is not this build."
  exit 0
fi

echo "To type scribe instead of the full path, link it into a directory"
echo "already on your PATH, once:"
echo "  ln -sfn $binary ~/.local/bin/scribe"
