import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'config.dart';
import 'errors.dart';
import 'models.dart';
import 'session.dart';

class _Reply {
  const _Reply(this.status, this.body);

  final int status;
  final Object? body;

  bool get ok => status >= 200 && status < 300;

  /// The auth server and the REST layer name errors in a few different
  /// fields depending on version; gather them into one lower-case string.
  String get errorText {
    final b = body;
    if (b is! Map) return '';
    return [
      b['error_code'],
      b['code'],
      b['error'],
      b['error_description'],
      b['msg'],
      b['message'],
    ].whereType<Object>().map((e) => e.toString().toLowerCase()).join(' | ');
  }
}

/// Join codes are shown with Arabic-Indic digits in Arabic, so a student may
/// type them either way: spaces go, letters become capitals, and ٠–٩ / ۰–۹
/// become 0–9.
String normalizeJoinCode(String code) {
  final out = StringBuffer();
  for (final rune in code.trim().toUpperCase().runes) {
    if (rune >= 0x0660 && rune <= 0x0669) {
      out.writeCharCode(0x30 + rune - 0x0660);
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      out.writeCharCode(0x30 + rune - 0x06F0);
    } else if (rune != 0x20) {
      out.writeCharCode(rune);
    }
  }
  return out.toString();
}

/// Everything the apps use from the backend. [CloudClient] is the real one;
/// app tests use fakes.
abstract interface class CloudService {
  bool get isSignedIn;
  String? get userId;
  Future<Account?> restore();
  Future<Account> signIn(String email, String password);
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String displayName,
    required String locale,
  });
  Future<void> signOut();
  Future<Account> account();
  Future<void> updateProfile({String? displayName, String? locale});
  Future<int> syncProgress(List<ProgressItem> items);
  Future<SchoolClass> joinClass(String code);
  Future<List<SchoolClass>> classes();
  Future<SchoolClass> createClass(String name);
  Future<void> archiveClass(String classId);
  Future<String> regenerateJoinCode(String classId);
  Future<void> leaveClass(String classId);
  Future<List<ClassProgressRow>> classProgress(String classId);
}

/// Talks to the project's Supabase backend over HTTPS: the auth API for
/// accounts and the REST API (with the user's token) for everything else.
/// What a user may read or change is decided by the server's row level
/// security, not by this client.
class CloudClient implements CloudService {
  CloudClient(
    this.config, {
    required SessionStore store,
    HttpClient? httpClient,
    DateTime Function()? clock,
    this.timeout = const Duration(seconds: 20),
  })  : _store = store,
        _http = httpClient ??
            (HttpClient()..connectionTimeout = const Duration(seconds: 10)),
        _now = clock ?? DateTime.now;

  final CloudConfig config;
  final Duration timeout;
  final SessionStore _store;
  final HttpClient _http;
  final DateTime Function() _now;

  CloudSession? _session;
  Future<CloudSession>? _refreshing;

  @override
  bool get isSignedIn => _session != null;

  @override
  String? get userId => _session?.userId;

  // ── accounts ─────────────────────────────────────────────────────────────

  /// Picks up a saved session, if any. Returns null when signed out. When the
  /// network is down the saved session is kept and [CloudException] (offline)
  /// is thrown, so the caller can try again later.
  @override
  Future<Account?> restore() async {
    final saved = CloudSession.decode(await _store.read());
    if (saved == null) return null;
    _session = saved;
    try {
      return await account();
    } on CloudException catch (e) {
      if (e.kind == CloudErrorKind.signedOut) return null;
      rethrow;
    }
  }

  @override
  Future<Account> signIn(String email, String password) async {
    final reply = await _auth('/auth/v1/token', {'grant_type': 'password'},
        {'email': email.trim(), 'password': password});
    if (!reply.ok) throw _authError(reply);
    await _adopt(reply);
    return account();
  }

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String displayName,
    required String locale,
  }) async {
    final reply = await _auth('/auth/v1/signup', null, {
      'email': email.trim(),
      'password': password,
      // Only these two are read by the server; a role here would be ignored.
      'data': {'display_name': displayName.trim(), 'preferred_locale': locale},
    });
    if (!reply.ok) throw _authError(reply);
    final session = CloudSession.fromAuthReply(reply.body, _now());
    if (session == null) return ConfirmationSent(email.trim());
    await _adopt(reply);
    return SignedUp(await account());
  }

  /// Ends the session here and, when reachable, on the server too.
  @override
  Future<void> signOut() async {
    final session = _session;
    _session = null;
    await _store.clear();
    if (session == null) return;
    try {
      await _send('POST', config.endpoint('/auth/v1/logout'),
          token: session.accessToken);
    } on CloudException {
      // Already signed out locally; the token expires on its own.
    }
  }

  @override
  Future<Account> account() async {
    final id = _requireSession().userId;
    final profile = await _rest('GET', '/rest/v1/profiles', query: {
      'select': 'display_name,preferred_locale',
      'id': 'eq.$id',
    });
    final role = await _rest('GET', '/rest/v1/user_roles', query: {
      'select': 'role',
      'user_id': 'eq.$id',
    });
    final p = _single(profile);
    final r = _single(role);
    final parsedRole = accountRoleFromName(r['role']);
    final name = p['display_name'];
    final locale = p['preferred_locale'];
    if (parsedRole == null || name is! String || locale is! String) {
      throw const CloudException(CloudErrorKind.unexpected, 'account shape');
    }
    return Account(
      userId: id,
      displayName: name,
      role: parsedRole,
      locale: locale,
      email: _session?.email ?? '',
    );
  }

  @override
  Future<void> updateProfile({String? displayName, String? locale}) async {
    final id = _requireSession().userId;
    final changes = <String, Object>{
      if (displayName != null) 'display_name': displayName.trim(),
      if (locale != null) 'preferred_locale': locale,
    };
    if (changes.isEmpty) return;
    await _rest('PATCH', '/rest/v1/profiles',
        query: {'id': 'eq.$id'}, body: changes);
  }

  // ── progress ─────────────────────────────────────────────────────────────

  /// Uploads progress; returns how many skills the server recorded.
  @override
  Future<int> syncProgress(List<ProgressItem> items) async {
    var written = 0;
    for (var start = 0; start < items.length; start += 500) {
      final chunk = items.skip(start).take(500).toList();
      final reply = await _rest('POST', '/rest/v1/rpc/sync_progress', body: {
        'items': [for (final item in chunk) item.toJson()],
      });
      if (reply is! int) {
        throw const CloudException(CloudErrorKind.unexpected, 'sync reply');
      }
      written += reply;
    }
    return written;
  }

  // ── classes ──────────────────────────────────────────────────────────────

  @override
  Future<SchoolClass> joinClass(String code) async {
    final normalized = normalizeJoinCode(code);
    final reply = await _rest('POST', '/rest/v1/rpc/join_class',
        body: {'code': normalized});
    final row = _single(reply);
    final id = row['class_id'];
    final name = row['class_name'];
    if (id is! String || name is! String) {
      throw const CloudException(CloudErrorKind.unexpected, 'join reply');
    }
    return SchoolClass(id: id, name: name, joinCode: normalized, isMine: false);
  }

  /// Classes the user teaches or belongs to (open ones only).
  @override
  Future<List<SchoolClass>> classes() async {
    final me = _requireSession().userId;
    final reply = await _rest('GET', '/rest/v1/classes', query: {
      'select': 'id,name,join_code,teacher_id',
      'archived_at': 'is.null',
      'order': 'created_at.asc',
    });
    return [for (final row in _rows(reply)) _schoolClass(row, me)];
  }

  /// Teachers only (the server refuses everyone else).
  @override
  Future<SchoolClass> createClass(String name) async {
    final me = _requireSession().userId;
    final reply = await _rest('POST', '/rest/v1/classes',
        body: {'name': name.trim()},
        query: {'select': 'id,name,join_code,teacher_id'},
        headers: {'Prefer': 'return=representation'});
    return _schoolClass(_single(reply), me);
  }

  @override
  Future<void> archiveClass(String classId) async {
    await _rest('PATCH', '/rest/v1/classes',
        query: {'id': 'eq.$classId'},
        body: {'archived_at': _now().toUtc().toIso8601String()});
  }

  @override
  Future<String> regenerateJoinCode(String classId) async {
    final reply = await _rest('POST', '/rest/v1/rpc/regenerate_join_code',
        body: {'class': classId});
    if (reply is! String) {
      throw const CloudException(CloudErrorKind.unexpected, 'code reply');
    }
    return reply;
  }

  @override
  Future<void> leaveClass(String classId) async {
    final me = _requireSession().userId;
    await _rest('DELETE', '/rest/v1/class_members',
        query: {'class_id': 'eq.$classId', 'student_id': 'eq.$me'});
  }

  @override
  Future<List<ClassProgressRow>> classProgress(String classId) async {
    final reply = await _rest('POST', '/rest/v1/rpc/class_progress',
        body: {'class': classId});
    return [
      for (final row in _rows(reply))
        ClassProgressRow(
          studentId: row['student_id'] as String? ?? '',
          displayName: row['display_name'] as String? ?? '',
          path: row['path'] as String?,
          skill: row['skill'] as String?,
          mastery: (row['mastery'] as num?)?.round(),
          attempts: (row['attempts'] as num?)?.toInt(),
          mastered: row['mastered'] as bool?,
        ),
    ];
  }

  void close() => _http.close(force: true);

  // ── plumbing ─────────────────────────────────────────────────────────────

  CloudSession _requireSession() {
    final session = _session;
    if (session == null) {
      throw const CloudException(CloudErrorKind.signedOut, 'no session');
    }
    return session;
  }

  Future<void> _adopt(_Reply reply) async {
    final session = CloudSession.fromAuthReply(reply.body, _now());
    if (session == null) {
      throw const CloudException(CloudErrorKind.unexpected, 'session shape');
    }
    _session = session;
    await _store.write(session.encode());
  }

  Future<_Reply> _auth(
          String path, Map<String, String>? query, Map<String, Object> body) =>
      _send('POST', config.endpoint(path, query), body: body);

  CloudException _authError(_Reply reply) {
    final text = reply.errorText;
    if (text.contains('email_not_confirmed') ||
        text.contains('email not confirmed')) {
      return CloudException(CloudErrorKind.emailNotConfirmed, text);
    }
    if (text.contains('invalid_credentials') ||
        text.contains('invalid login credentials') ||
        text.contains('invalid_grant')) {
      return CloudException(CloudErrorKind.invalidCredentials, text);
    }
    if (text.contains('user_already_exists') ||
        text.contains('email_exists') ||
        text.contains('already registered')) {
      return CloudException(CloudErrorKind.emailTaken, text);
    }
    if (text.contains('weak_password') || text.contains('password should')) {
      return CloudException(CloudErrorKind.weakPassword, text);
    }
    return CloudException(
        CloudErrorKind.unexpected, 'auth ${reply.status}: $text');
  }

  Future<CloudSession> _validSession() async {
    final session = _requireSession();
    if (!session.isExpiredAt(_now())) return session;
    return _refresh();
  }

  /// One refresh at a time, shared by every request that needs it.
  Future<CloudSession> _refresh() {
    final running = _refreshing;
    if (running != null) return running;
    final started = _doRefresh();
    _refreshing = started;
    return started.whenComplete(() => _refreshing = null);
  }

  Future<CloudSession> _doRefresh() async {
    final session = _requireSession();
    final reply = await _auth('/auth/v1/token', {'grant_type': 'refresh_token'},
        {'refresh_token': session.refreshToken});
    if (!reply.ok) {
      if (reply.status == 400 || reply.status == 401 || reply.status == 403) {
        _session = null;
        await _store.clear();
        throw CloudException(CloudErrorKind.signedOut, reply.errorText);
      }
      throw CloudException(
          CloudErrorKind.unexpected, 'refresh ${reply.status}');
    }
    await _adopt(reply);
    return _session!;
  }

  /// A REST call as the signed-in user; refreshes and retries once on 401.
  Future<Object?> _rest(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    Map<String, String> headers = const {},
  }) async {
    final uri = config.endpoint(path, query);
    var session = await _validSession();
    var reply = await _send(method, uri,
        body: body, token: session.accessToken, headers: headers);
    if (reply.status == 401) {
      session = await _refresh();
      reply = await _send(method, uri,
          body: body, token: session.accessToken, headers: headers);
    }
    if (reply.ok) return reply.body;
    final text = reply.errorText;
    if (reply.status == 401) {
      _session = null;
      await _store.clear();
      throw CloudException(CloudErrorKind.signedOut, text);
    }
    if (text.contains('unknown class code') || text.contains('p0002')) {
      throw CloudException(CloudErrorKind.unknownClassCode, text);
    }
    if (reply.status == 403 ||
        text.contains('42501') ||
        text.contains('row-level security') ||
        text.contains('permission denied')) {
      throw CloudException(CloudErrorKind.notAllowed, text);
    }
    throw CloudException(
        CloudErrorKind.unexpected, '$method $path ${reply.status}: $text');
  }

  Future<_Reply> _send(
    String method,
    Uri uri, {
    Object? body,
    String? token,
    Map<String, String> headers = const {},
  }) async {
    try {
      final request = await _http.openUrl(method, uri).timeout(timeout);
      request.headers.set('apikey', config.anonKey);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      headers.forEach(request.headers.set);
      if (body != null) {
        final bytes = utf8.encode(jsonEncode(body));
        request.headers.contentType = ContentType.json;
        request.contentLength = bytes.length;
        request.add(bytes);
      } else {
        request.contentLength = 0;
      }
      final response = await request.close().timeout(timeout);
      final text =
          await response.transform(utf8.decoder).join().timeout(timeout);
      Object? decoded;
      if (text.isNotEmpty) {
        try {
          decoded = jsonDecode(text);
        } on FormatException {
          decoded = null;
        }
      }
      return _Reply(response.statusCode, decoded);
    } on SocketException catch (e) {
      throw CloudException(CloudErrorKind.offline, e.message);
    } on TimeoutException {
      throw const CloudException(CloudErrorKind.offline, 'timeout');
    } on HandshakeException catch (e) {
      throw CloudException(CloudErrorKind.offline, e.message);
    } on HttpException catch (e) {
      throw CloudException(CloudErrorKind.offline, e.message);
    }
  }

  static List<Map<String, Object?>> _rows(Object? reply) {
    if (reply is! List) {
      throw const CloudException(CloudErrorKind.unexpected, 'expected rows');
    }
    return [
      for (final row in reply)
        if (row is Map) row.cast<String, Object?>(),
    ];
  }

  static Map<String, Object?> _single(Object? reply) {
    final rows = _rows(reply);
    if (rows.length != 1) {
      throw CloudException(
          CloudErrorKind.unexpected, 'expected one row, got ${rows.length}');
    }
    return rows.single;
  }

  static SchoolClass _schoolClass(Map<String, Object?> row, String me) {
    final id = row['id'];
    final name = row['name'];
    final code = row['join_code'];
    if (id is! String || name is! String || code is! String) {
      throw const CloudException(CloudErrorKind.unexpected, 'class shape');
    }
    return SchoolClass(
        id: id, name: name, joinCode: code, isMine: row['teacher_id'] == me);
  }
}
