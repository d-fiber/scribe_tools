class Conventions {
  const Conventions._();

  static const String sourceExtension = '.ts';
  static const String indexName = 'index';
  static const String middlewareName = '_middleware';
  static const String nodeName = '_node';
  static const String privatePrefix = '_';

  static bool isSource(String basename) => basename.endsWith(sourceExtension);

  static bool isMiddleware(String basename) =>
      basename == '$middlewareName$sourceExtension';

  static bool isObsoleteNode(String basename) =>
      basename == '$nodeName$sourceExtension';

  static bool isPrivate(String basename) => basename.startsWith(privatePrefix);

  static bool isRoutable(String basename) => isSource(basename) && !isPrivate(basename);

  static String withoutExtension(String basename) =>
      basename.substring(0, basename.length - sourceExtension.length);

  static String segment(String name) {
    if (name.startsWith('[') && name.endsWith(']')) {
      return ':${name.substring(1, name.length - 1)}';
    }
    return name;
  }

  static String join(String prefix, String name) {
    final String encoded = segment(name);
    return prefix == '/' ? '/$encoded' : '$prefix/$encoded';
  }
}
