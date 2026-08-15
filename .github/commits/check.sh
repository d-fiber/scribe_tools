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

BASE="${1:-}"
HEAD="${2:-HEAD}"

TAGS="DEV|BUGFIX|REFACTO|DOC|TEST|CI|PERF|SECURITY|BREAKING|RELEASE|REVERT|CHORE"
PATTERN="^\[(${TAGS})\]: .+$"
SUBJECT_LIMIT=72

if [ -z "$BASE" ] || [ "$BASE" = "0000000000000000000000000000000000000000" ] || ! git cat-file -e "$BASE^{commit}" 2>/dev/null; then
  echo "No base revision to compare against, checking $HEAD on its own"
  COMMITS=$(git rev-list -1 "$HEAD")
else
  COMMITS=$(git rev-list "$BASE..$HEAD")
fi

failed=0
checked=0

for commit in $COMMITS; do
  parents=$(git rev-list --parents -n 1 "$commit" | wc -w)
  if [ "$parents" -gt 2 ]; then
    continue
  fi

  subject=$(git log -1 --format=%s "$commit")
  checked=$((checked + 1))

  if [ ${#subject} -gt $SUBJECT_LIMIT ]; then
    echo "BAD  ${commit:0:8}  subject is ${#subject} characters, limit is $SUBJECT_LIMIT"
    echo "                   $subject"
    failed=$((failed + 1))
    continue
  fi

  if ! printf '%s' "$subject" | grep -Eq "$PATTERN"; then
    echo "BAD  ${commit:0:8}  $subject"
    failed=$((failed + 1))
    continue
  fi

  if printf '%s' "$subject" | grep -Eq '\.$'; then
    echo "BAD  ${commit:0:8}  subject ends with a period"
    echo "                   $subject"
    failed=$((failed + 1))
    continue
  fi

  echo "ok   ${commit:0:8}  $subject"
done

if [ "$failed" -gt 0 ]; then
  cat >&2 <<EOF

$failed of $checked commit messages have the wrong format.

Use [TAG]: message

  DEV        new feature, new endpoint, new code
  BUGFIX     a fix for something that was broken
  REFACTO    moving or rewriting code without changing behaviour
  DOC        documentation only
  TEST       tests only
  CI         workflows and build tooling
  PERF       speed or footprint
  SECURITY   hardening, closing a leak
  BREAKING   breaks the contract or a published API
  RELEASE    publishing, generated files, versions that moved
  REVERT     undoing an earlier commit
  CHORE      dependencies and other housekeeping

Tags are uppercase and in brackets. Keep the message in the imperative, drop
the trailing period, and stay under $SUBJECT_LIMIT characters.

For example:

  [DEV]: add the capability token to every invocation
  [BUGFIX]: keep the rate limit a node passes down
  [REFACTO]: move the rest engine out of dependencies
  [BREAKING]: replace the Mount enum with declared nodes
EOF
  exit 1
fi

echo ""
echo "Checked $checked commit messages, all good"
