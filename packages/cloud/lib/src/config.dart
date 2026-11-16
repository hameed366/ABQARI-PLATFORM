/// Where the backend is. Only the project URL and its public ("anon") key —
/// both are safe to ship inside an app, because every table is protected by
/// row level security on the server. The secret service key never belongs in
/// an app and this package has no way to accept one.
class CloudConfig {
  CloudConfig({required this.url, required this.anonKey}) {
    if (url.scheme != 'https' && !_isLoopback(url)) {
      throw ArgumentError.value(url, 'url', 'must be https');
    }
    if (anonKey.trim().isEmpty) {
      throw ArgumentError.value(anonKey, 'anonKey', 'must not be empty');
    }
  }

  final Uri url;
  final String anonKey;

  /// Read from build flags:
  ///   --dart-define=ABQARI_CLOUD_URL=https://xyz.supabase.co
  ///   --dart-define=ABQARI_CLOUD_ANON_KEY=...
  /// Returns null when either is missing or invalid; the apps then hide every
  /// account feature instead of showing buttons that cannot work.
  static CloudConfig? fromEnvironment() => tryParse(
        const String.fromEnvironment('ABQARI_CLOUD_URL'),
        const String.fromEnvironment('ABQARI_CLOUD_ANON_KEY'),
      );

  static CloudConfig? tryParse(String url, String anonKey) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasAuthority || anonKey.trim().isEmpty) return null;
    try {
      return CloudConfig(url: uri, anonKey: anonKey.trim());
    } on ArgumentError {
      return null;
    }
  }

  /// Plain http only for a server on this machine (tests, local development).
  static bool _isLoopback(Uri uri) =>
      uri.scheme == 'http' &&
      (uri.host == '127.0.0.1' || uri.host == 'localhost' || uri.host == '::1');

  Uri endpoint(String path, [Map<String, String>? query]) {
    final base = url.path.endsWith('/')
        ? url.path.substring(0, url.path.length - 1)
        : url.path;
    return url.replace(path: '$base$path', queryParameters: query);
  }
}
