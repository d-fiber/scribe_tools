import 'package:scribe_sdk_dart/scribe.dart';

class AppBrowsing extends Middleware {
  const AppBrowsing();

  @override
  RateLimiter rateLimit() => RateLimiter(
    limit: 60,
    window: Time.minutes(1),
    penalty: Time.minutes(1),
    maxPenalty: Time.minutes(15),
  );
}
