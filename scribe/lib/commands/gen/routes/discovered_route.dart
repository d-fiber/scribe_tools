class DiscoveredRoute {
  const DiscoveredRoute({
    required this.node,
    required this.path,
    required this.file,
    required this.branches,
  });

  final String node;
  final String path;
  final String file;
  final List<String> branches;
}
