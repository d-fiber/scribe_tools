import 'package:sdk/commands/gen/code/generators/config/kong.dart';
import 'package:test/test.dart';

void main() {
  group('consumerBlock', () {
    test('emits one consumer per username, with its credentials', () {
      expect(
        consumerBlock(<String, List<String>>{
          'app': <String>['a1', 'a2'],
          'admin': <String>['b1'],
        }),
        '- username: app\n'
        '  keyauth_credentials:\n'
        '    - key: a1\n'
        '    - key: a2\n'
        '- username: admin\n'
        '  keyauth_credentials:\n'
        '    - key: b1',
      );
    });

    test('a consumer without key keeps its declaration but no credentials', () {
      expect(
        consumerBlock(<String, List<String>>{'app': const <String>[]}),
        '- username: app',
      );
    });
  });

  group('originsBlock', () {
    test('emits the configured origins under an origins key', () {
      expect(
        originsBlock(<String>['https://a.test', 'https://b.test']),
        'origins:\n  - "https://a.test"\n  - "https://b.test"',
      );
    });

    test('no configured origin denies all rather than allowing all', () {
      expect(originsBlock(const <String>[]), 'origins:\n  - "https://cors.disabled.invalid"');
    });
  });
}
