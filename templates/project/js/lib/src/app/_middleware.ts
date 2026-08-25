import { Middleware, type RateLimiter, Time } from "@scribe/sdk";

export class AppBrowsing extends Middleware {
  protected override rateLimit(): RateLimiter {
    return {
      limit: 60,
      window: Time.minutes(1),
      penalty: Time.minutes(1),
      maxPenalty: Time.minutes(15),
    };
  }
}
