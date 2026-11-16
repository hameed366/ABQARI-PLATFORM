import 'dart:convert';

/// A signed-in session as issued by the auth server.
class CloudSession {
  const CloudSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.userId,
    this.email = '',
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String userId;
  final String email;

  /// Refresh a little early so a request never leaves with a dying token.
  bool isExpiredAt(DateTime now) =>
      !now.isBefore(expiresAt.subtract(const Duration(seconds: 60)));

  /// From an auth server token reply. Returns null when it is not a session
  /// (e.g. sign-up waiting for email confirmation).
  static CloudSession? fromAuthReply(Object? json, DateTime now) {
    if (json is! Map) return null;
    final access = json['access_token'];
    final refresh = json['refresh_token'];
    final user = json['user'];
    if (access is! String || refresh is! String || user is! Map) return null;
    final id = user['id'];
    if (id is! String || access.isEmpty || refresh.isEmpty) return null;
    final expiresIn = json['expires_in'];
    final expiresAtSeconds = json['expires_at'];
    final DateTime expiry;
    if (expiresAtSeconds is int) {
      expiry = DateTime.fromMillisecondsSinceEpoch(expiresAtSeconds * 1000,
          isUtc: true);
    } else {
      expiry = now.add(Duration(seconds: expiresIn is int ? expiresIn : 3600));
    }
    final email = user['email'];
    return CloudSession(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: expiry,
      userId: id,
      email: email is String ? email : '',
    );
  }

  String encode() => jsonEncode({
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_at': expiresAt.toUtc().millisecondsSinceEpoch ~/ 1000,
        'user': {'id': userId, 'email': email},
      });

  /// Tolerant: anything unreadable means "not signed in", never a crash.
  static CloudSession? decode(String? text) {
    if (text == null || text.isEmpty) return null;
    try {
      return fromAuthReply(jsonDecode(text), DateTime.now());
    } on FormatException {
      return null;
    }
  }
}

/// Where the session is kept between launches.
abstract interface class SessionStore {
  Future<String?> read();

  Future<void> write(String data);

  Future<void> clear();
}

class InMemorySessionStore implements SessionStore {
  InMemorySessionStore([this.data]);

  String? data;

  @override
  Future<String?> read() async => data;

  @override
  Future<void> write(String data) async => this.data = data;

  @override
  Future<void> clear() async => data = null;
}
