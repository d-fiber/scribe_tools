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

REPOSITORY="${1:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"

if [ -z "$REPOSITORY" ]; then
  echo "usage: $0 <owner>/<repo>" >&2
  exit 64
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "This needs the GitHub CLI. See https://cli.github.com" >&2
  exit 1
fi

apply_one() {
  ruleset="$1"
  name=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['name'])" "$ruleset")
  existing=$(gh api "repos/$REPOSITORY/rulesets" --jq ".[] | select(.name == \"$name\") | .id" 2>/dev/null || true)

  if [ -n "$existing" ]; then
    echo "Updating \"$name\" (id $existing) on $REPOSITORY"
    gh api --method PUT "repos/$REPOSITORY/rulesets/$existing" --input "$ruleset" --jq '"  " + .name + " is now " + .enforcement'
  else
    echo "Creating \"$name\" on $REPOSITORY"
    gh api --method POST "repos/$REPOSITORY/rulesets" --input "$ruleset" --jq '"  " + .name + " is now " + .enforcement'
  fi
}

for ruleset in "$HERE"/*.json; do
  apply_one "$ruleset"
done

cat <<EOF

Done. $REPOSITORY now rejects a direct push to main and an untagged commit
message. That applies to you too, so an urgent fix still goes through a pull
request.

To check what is in place:
  gh api repos/$REPOSITORY/rulesets --jq '.[] | .name + " (" + .enforcement + ")"'
EOF
