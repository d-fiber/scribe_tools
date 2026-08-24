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

PACKAGE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCOPE="test"

say() {
  echo "[$SCOPE] $1"
}

if ! command -v dart >/dev/null 2>&1; then
  echo "[$SCOPE] dart is not on your PATH. Install the Dart SDK, then run this again." >&2
  echo "[$SCOPE]   https://dart.dev/get-dart" >&2
  exit 1
fi

cd "$PACKAGE"

if [ ! -d ../scribe/engine ]; then
  echo "[$SCOPE] the framework is not checked out next to this package, and the ops tests read it." >&2
  echo "[$SCOPE] clone d-fiber/scribe as a sibling directory named scribe, then run this again." >&2
  exit 1
fi

say "resolving dependencies"
dart pub get

say "analysing"
dart analyze

say "checking the formatting"
dart format --line-length 120 --output none --set-exit-if-changed lib bin test

say "running the suite"
dart test "$@"

echo ""
say "everything a pull request has to pass is green."
say "run the commands themselves through out/scribe too, see CONTRIBUTING.md."
