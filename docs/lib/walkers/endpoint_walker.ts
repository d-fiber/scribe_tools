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

import { ClassDeclaration } from "ts-morph";
import { findBodyOrFormSchema } from "../extractors/body_schema.ts";
import { resolveBareLiteral } from "../extractors/literal_resolve.ts";
import {
  findResponseCalls,
  ThisResponseMatcher,
} from "../extractors/response_call_finder.ts";
import type { ResponseMethodInfo } from "../extractors/response_defaults.ts";
import type { LiteralResponse, RequestBodyField } from "../core/types.ts";

const THIS_RESPONSE = new ThisResponseMatcher();

export interface EndpointExtraction {
  responses: LiteralResponse[];
  requestBody: RequestBodyField[] | null;
}

export function extractEndpoint(
  endpointClass: ClassDeclaration,
  defaults: Map<string, ResponseMethodInfo>,
): EndpointExtraction {
  const responses: LiteralResponse[] = [];

  const rateLimit = defaults.get("tooManyRequests");
  if (rateLimit) {
    responses.push({
      status: rateLimit.status,
      code: rateLimit.defaultCode,
      message: rateLimit.defaultMessage,
    });
  }

  const runMethod = endpointClass.getMethod("run");
  let requestBody: RequestBodyField[] | null = null;

  if (runMethod) {
    for (const call of findResponseCalls(runMethod, THIS_RESPONSE)) {
      const literal = resolveBareLiteral(
        call.method,
        call.code,
        call.message,
        defaults,
      );
      if (literal) responses.push(literal);
    }
    requestBody = findBodyOrFormSchema(runMethod);
  }

  return { responses, requestBody };
}
