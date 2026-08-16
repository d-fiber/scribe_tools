#!/usr/bin/env bash
# Copyright (C) 2026 Fiber
#
# All rights reserved. This script, including its code and logic, is the
# exclusive property of Fiber. Redistribution, reproduction,
# or modification of any part of this script is strictly prohibited
# without prior written permission from Fiber.
#
# Conditions of use:
# - The code may not be copied, duplicated, or used, in whole or in part,
#   for any purpose without explicit authorization.
# - Redistribution of this code, with or without modification, is not
#   permitted unless expressly agreed upon by Fiber.
# - The name "Fiber" and any associated branding, logos, or
#   trademarks may not be used to endorse or promote derived products
#   or services without prior written approval.
#
# Disclaimer:
# THIS SCRIPT AND ITS CODE ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT. IN NO EVENT SHALL
# FIBER BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT LIMITED TO LOSS OF USE,
# DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT OF OR RELATED TO THE USE
# OR INABILITY TO USE THIS SCRIPT, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# Unauthorized copying or reproduction of this script, in whole or in part,
# is a violation of applicable intellectual property laws and will result
# in legal action.

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

dart compile exe bin/scribe.dart -o "$binary"

echo ""
echo "Built $binary ($(du -h "$binary" | cut -f1))"
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
