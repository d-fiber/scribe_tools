import 'package:change_case/change_case.dart';

import '../../../core/console/console.dart';
import '../../../core/file_system_entity/paths.dart';
import '../../../ops/config.dart';
import 'discovered_source.dart';
import 'emitter.dart';
import 'scanner.dart';

const Log _log = Log('gen:routes');

class GenRoutesCommand extends Command {
  const GenRoutesCommand();

  @override
  String get name => 'routes';

  @override
  String get description =>
      'Walk lib/src/<node>/ and write the generated routes.ts, the route table '
      'the worker reads at boot. One file is one path, one class is one method.';

  @override
  Future<void> run(Context cli) async {
    await generateRoutes();
  }
}

Future<void> generateRoutes() async {
  final DiscoveredSource source = await RouteScanner.discover();
  final String bin = (await Config.read()).get('NAME').toSnakeCase();

  final String header = '// This file is auto-generated do not edit manually.\n'
      '// Run: $bin gen routes\n';

  await Paths.alchemy.sdk.js.create();
  await Paths.alchemy.sdk.js.routesTs.writeAsString(RoutesEmitter(source).render(header));

  _log.info(
    '${source.routes.length} paths on ${source.nodes.length} nodes → ${Paths.generatedDirectory}/sdk/js/routes.ts',
  );
}
