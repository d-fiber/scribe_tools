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

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCOPE="version"

say() {
  echo "[$SCOPE] $1"
}

fail() {
  echo "[$SCOPE] $1" >&2
  exit 1
}

cd "$ROOT"

declared=$(awk '/^version:/ { print $2; exit }' pubspec.yaml)

[ -n "$declared" ] || fail "pubspec.yaml has no version."

case "$declared" in
  *.*.*) ;;
  *) fail "pubspec.yaml says \"$declared\", which is not a version. Write three numbers, as in \"1.0.2\"." ;;
esac

say "the version is $declared, and pubspec.yaml is the only place that says so"

previous=$(git tag --list 'v*' --sort=-v:refname | head -1)

if [ -z "$previous" ]; then
  say "nothing has ever been tagged, so this will be the first"
  exit 0
fi

if [ "${previous#v}" = "$declared" ]; then
  say "it has not moved since $previous, so nothing will be tagged or written"
  exit 0
fi

say "it has moved from ${previous#v}, so the push will tag it and write its changelog section"
