import 'dart:io';

import 'package:sdk/ops/dependencies.dart';
import 'package:test/test.dart';

const String _root = '../..';

List<Directory> get _roots => <Directory>[
  Directory('$_root/scribe/host/dependencies'),
  Directory('$_root/scribe/host/packages'),
];

/// The modules the framework ships, written by hand.
///
/// The walk finds a module by the artefacts its directory carries, so nothing
/// in the repository states which directories are modules. This list is that
/// statement, and it fails in both directions: a module that stops being seen,
/// and a directory that starts being seen as one.
const List<String> _shipped = <String>[
  'features/devops',
  'features/messagings',
  'features/recommendation',
  'features/searcher',
  'foundation',
  'geospatial',
  'realtime',
  'security/auth',
  'security/rbac',
  'security/vpn',
  'storage',
];

void main() {
  group('the modules the walk finds', () {
    test('are the ones the framework ships, and only those', () {
      final List<String> found = Dependencies.load(
        roots: _roots,
      ).all.map((Dependency dependency) => dependency.path).toList();

      expect(found, _shipped);
    });

    test('none of them sits inside another', () {
      final List<String> nested = <String>[
        for (final String module in _shipped)
          for (final String other in _shipped)
            if (module != other && module.startsWith('$other/')) '$module is inside $other',
      ];

      expect(nested, isEmpty, reason: 'a module inside a module would have its fragments read twice');
    });
  });
}
