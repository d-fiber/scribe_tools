import 'discovered_route.dart';

class DiscoveredSource {
  const DiscoveredSource({
    required this.nodes,
    required this.routes,
  });

  final List<String> nodes;
  final List<DiscoveredRoute> routes;
}
