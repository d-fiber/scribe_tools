// Copyright (C) 2026 Fiber
//
// All rights reserved. This script, including its code and logic, is the
// exclusive property of Fiber. Redistribution, reproduction,
// or modification of any part of this script is strictly prohibited
// without prior written permission from Fiber.
//
// Conditions of use:
// - The code may not be copied, duplicated, or used, in whole or in part,
//   for any purpose without explicit authorization.
// - Redistribution of this code, with or without modification, is not
//   permitted unless expressly agreed upon by Fiber.
// - The name "Fiber" and any associated branding, logos, or
//   trademarks may not be used to endorse or promote derived products
//   or services without prior written approval.
//
// Disclaimer:
// THIS SCRIPT AND ITS CODE ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT. IN NO EVENT SHALL
// FIBER BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT LIMITED TO LOSS OF USE,
// DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT OF OR RELATED TO THE USE
// OR INABILITY TO USE THIS SCRIPT, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Unauthorized copying or reproduction of this script, in whole or in part,
// is a violation of applicable intellectual property laws and will result
// in legal action.

const ALL_QUALIFIER = "All";

function splitPascalCase(word: string): string[] {
  return word.match(/[A-Z][a-z0-9]*|[A-Z]+(?=[A-Z]|$)/g) ?? [word];
}

export function humanizeEndpointClassName(
  className: string,
  statusQualifiers: Set<string>,
): string {
  const base = className.endsWith("Endpoint")
    ? className.slice(0, -"Endpoint".length)
    : className;
  const words = splitPascalCase(base);

  if (words[0] === "Pagination" && words.length >= 2) {
    const rest = words.slice(1);
    const isKnownQualifier =
      rest[0] === ALL_QUALIFIER || statusQualifiers.has(rest[0]);
    const qualifier = isKnownQualifier ? rest[0] : null;
    const entityWords = qualifier ? rest.slice(1) : rest;
    const parts = ["Paginate"];
    if (qualifier && qualifier !== ALL_QUALIFIER) {
      parts.push(qualifier.toLowerCase());
    }
    parts.push(...entityWords.map((w) => w.toLowerCase()));
    return parts.join(" ");
  }

  const [verb, ...remainder] = words;
  return [verb, ...remainder.map((w) => w.toLowerCase())].join(" ");
}
