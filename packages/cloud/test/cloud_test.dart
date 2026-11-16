import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:abqari_cloud/abqari_cloud.dart';
import 'package:test/test.dart';

/// A loopback stand-in for the backend's auth and REST APIs. It records every
/// request and answers from small scripted rules, so the client's HTTP
/// behaviour (headers, bodies, retries, error mapping) is tested for real.
class FakeBackend {
  late HttpServer _server;
  final List<Recorded> requests = [];
  final Map<String, FutureOr<(int, Object?)> Function(Recorded)> routes = {};

  int tokenCounter = 0;
  String validAccess = '';

  Uri get url => Uri.parse('http://127.0.0.1:${_server.port}');

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      final recorded = Recorded(
        request.method,
        request.uri,
        {
          for (final name in ['apikey', 'authorization', 'prefer'])
            if (request.headers.value(name) != null)
              name: request.headers.value(name)!,
        },
        body.isEmpty ? null : jsonDecode(body),
      );
      requests.add(recorded);
      final key = '${request.method} ${request.uri.path}';
      final route = routes[key];
      final (status, reply) = route == null
          ? (404, {'message': 'no route $key'})
          : await route(recorded);
      request.response.statusCode = status;
      request.response.headers.contentType = ContentType.json;
      if (reply != null) request.response.write(jsonEncode(reply));
      await request.response.close();
    });
  }

  Future<void> stop() => _server.close(force: true);

  Map<String, Object> session({String user = 'u1', int expiresIn = 3600}) {
    tokenCounter++;
    validAccess = 'access-$tokenCounter';
    return {
      'access_token': validAccess,
      'refresh_token': 'refresh-$tokenCounter',
      'expires_in': expiresIn,
      'token_type': 'bearer',
      'user': {'id': user, 'email': 'a@example.test'},
    };
  }

  /// Account rows for user u1 with the given role, guarded by the token.
  void serveAccount({String role = 'student', String name = 'Alice'}) {
    routes['GET /rest/v1/profiles'] = (r) => authorized(r)
        ? (
            200,
            [
              {'display_name': name, 'preferred_locale': 'ar'}
            ]
          )
        : (401, {'message': 'JWT expired'});
    routes['GET /rest/v1/user_roles'] = (r) => authorized(r)
        ? (
            200,
            [
              {'role': role}
            ]
          )
        : (401, {'message': 'JWT expired'});
  }

  bool authorized(Recorded r) =>
      r.headers['authorization'] == 'Bearer $validAccess';

  List<Recorded> named(String method, String path) => [
        for (final r in requests)
          if (r.method == method && r.uri.path == path) r
      ];
}

class Recorded {
  Recorded(this.method, this.uri, this.headers, this.body);

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final Object? body;
}

void main() {
  late FakeBackend backend;
  late InMemorySessionStore store;
  late CloudClient client;
  var now = DateTime.utc(2026, 11, 16, 12);

  CloudClient makeClient() => CloudClient(
        CloudConfig(url: backend.url, anonKey: 'public-anon-key'),
        store: store,
        clock: () => now,
        timeout: const Duration(seconds: 5),
      );

  setUp(() async {
    now = DateTime.utc(2026, 11, 16, 12);
    backend = FakeBackend();
    await backend.start();
    store = InMemorySessionStore();
    client = makeClient();
  });

  tearDown(() async {
    client.close();
    await backend.stop();
  });

  void serveSignIn({String role = 'student'}) {
    backend.routes['POST /auth/v1/token'] = (r) {
      final grant = r.uri.queryParameters['grant_type'];
      final body = r.body as Map;
      if (grant == 'password' && body['password'] == 'right-password') {
        return (200, backend.session());
      }
      if (grant == 'refresh_token' &&
          body['refresh_token'] == 'refresh-${backend.tokenCounter}') {
        return (200, backend.session());
      }
      return (
        400,
        {
          'error_code': 'invalid_credentials',
          'msg': 'Invalid login credentials'
        }
      );
    };
    backend.serveAccount(role: role);
  }

  test('join codes typed with Arabic-Indic digits are understood', () {
    expect(normalizeJoinCode(' abcd٢٣٤٥ '), 'ABCD2345');
    expect(normalizeJoinCode('abcd۲۳۴۵'), 'ABCD2345');
    expect(normalizeJoinCode('AB CD 2345'), 'ABCD2345');
  });

  group('config', () {
    test('only https, except for a server on this machine', () {
      expect(
          () => CloudConfig(url: Uri.parse('http://example.com'), anonKey: 'k'),
          throwsArgumentError);
      expect(
          CloudConfig(url: Uri.parse('https://x.supabase.co'), anonKey: 'k')
              .url
              .host,
          'x.supabase.co');
      expect(
          CloudConfig(url: Uri.parse('http://127.0.0.1:9'), anonKey: 'k')
              .url
              .port,
          9);
    });

    test('missing or bad build flags mean no account features', () {
      expect(CloudConfig.fromEnvironment(), isNull);
      expect(CloudConfig.tryParse('', 'k'), isNull);
      expect(CloudConfig.tryParse('https://x.supabase.co', ' '), isNull);
      expect(CloudConfig.tryParse('not a url', 'k'), isNull);
      expect(CloudConfig.tryParse('http://example.com', 'k'), isNull);
      expect(CloudConfig.tryParse(' https://x.supabase.co ', ' k '), isNotNull);
    });

    test('endpoints keep a base path', () {
      final c =
          CloudConfig(url: Uri.parse('https://h.example/base/'), anonKey: 'k');
      expect(
          c.endpoint('/auth/v1/token', {'grant_type': 'password'}).toString(),
          'https://h.example/base/auth/v1/token?grant_type=password');
    });
  });

  group('sign-in', () {
    test('signs in, loads the account and keeps the session', () async {
      serveSignIn(role: 'teacher');
      final account = await client.signIn(' a@example.test ', 'right-password');
      expect(account.displayName, 'Alice');
      expect(account.role, AccountRole.teacher);
      expect(account.locale, 'ar');
      expect(client.isSignedIn, isTrue);
      expect(CloudSession.decode(store.data)?.accessToken, backend.validAccess);
      final token = backend.named('POST', '/auth/v1/token').single;
      expect(token.headers['apikey'], 'public-anon-key');
      expect(token.headers.containsKey('authorization'), isFalse);
      expect((token.body as Map)['email'], 'a@example.test');
      final profile = backend.named('GET', '/rest/v1/profiles').single;
      expect(profile.headers['authorization'], 'Bearer ${backend.validAccess}');
      expect(profile.uri.queryParameters['id'], 'eq.u1');
    });

    test('wrong password, in old and new server wording', () async {
      serveSignIn();
      await expectLater(
          client.signIn('a@example.test', 'nope'),
          throwsA(isA<CloudException>().having(
              (e) => e.kind, 'kind', CloudErrorKind.invalidCredentials)));
      backend.routes['POST /auth/v1/token'] = (_) => (
            400,
            {
              'error': 'invalid_grant',
              'error_description': 'Invalid login credentials'
            }
          );
      await expectLater(
          client.signIn('a@example.test', 'nope'),
          throwsA(isA<CloudException>().having(
              (e) => e.kind, 'kind', CloudErrorKind.invalidCredentials)));
      expect(client.isSignedIn, isFalse);
      expect(store.data, isNull);
    });

    test('unconfirmed email', () async {
      backend.routes['POST /auth/v1/token'] = (_) => (
            400,
            {'error_code': 'email_not_confirmed', 'msg': 'Email not confirmed'}
          );
      await expectLater(
          client.signIn('a@example.test', 'x'),
          throwsA(isA<CloudException>().having(
              (e) => e.kind, 'kind', CloudErrorKind.emailNotConfirmed)));
    });

    test('offline when nothing listens', () async {
      final dead = CloudClient(
        CloudConfig(url: Uri.parse('http://127.0.0.1:1'), anonKey: 'k'),
        store: store,
        timeout: const Duration(seconds: 5),
      );
      await expectLater(
          dead.signIn('a@example.test', 'x'),
          throwsA(isA<CloudException>()
              .having((e) => e.kind, 'kind', CloudErrorKind.offline)));
      dead.close();
    });
  });

  group('sign-up', () {
    test('sends only name and language as user data', () async {
      backend.routes['POST /auth/v1/signup'] = (_) => (200, backend.session());
      backend.serveAccount();
      final result = await client.signUp(
          email: 'a@example.test',
          password: 'pw-123456',
          displayName: ' حميد ',
          locale: 'ar');
      expect(result, isA<SignedUp>());
      final body = backend.named('POST', '/auth/v1/signup').single.body as Map;
      expect(body['data'], {'display_name': 'حميد', 'preferred_locale': 'ar'});
      expect(jsonEncode(body).contains('role'), isFalse);
    });

    test('email confirmation required', () async {
      backend.routes['POST /auth/v1/signup'] = (_) => (
            200,
            {
              'id': 'u1',
              'email': 'a@example.test',
              'confirmation_sent_at': 'now'
            }
          );
      final result = await client.signUp(
          email: 'a@example.test',
          password: 'pw-123456',
          displayName: 'A',
          locale: 'en');
      expect(result, isA<ConfirmationSent>());
      expect(client.isSignedIn, isFalse);
    });

    test('taken email and weak password', () async {
      backend.routes['POST /auth/v1/signup'] = (_) => (
            422,
            {
              'error_code': 'user_already_exists',
              'msg': 'User already registered'
            }
          );
      await expectLater(
          client.signUp(
              email: 'a@example.test',
              password: 'pw-123456',
              displayName: 'A',
              locale: 'ar'),
          throwsA(isA<CloudException>()
              .having((e) => e.kind, 'kind', CloudErrorKind.emailTaken)));
      backend.routes['POST /auth/v1/signup'] = (_) => (
            422,
            {
              'error_code': 'weak_password',
              'msg': 'Password should be at least 6 characters'
            }
          );
      await expectLater(
          client.signUp(
              email: 'a@example.test',
              password: '1',
              displayName: 'A',
              locale: 'ar'),
          throwsA(isA<CloudException>()
              .having((e) => e.kind, 'kind', CloudErrorKind.weakPassword)));
    });
  });

  group('sessions', () {
    test('restore with nothing saved is signed out, without any request',
        () async {
      expect(await client.restore(), isNull);
      expect(backend.requests, isEmpty);
    });

    test('restore refreshes an expired session first', () async {
      serveSignIn();
      await client.signIn('a@example.test', 'right-password');
      final saved = store.data;
      now = now.add(const Duration(hours: 2));
      final again = makeClient();
      store.data = saved;
      final account = await again.restore();
      expect(account?.displayName, 'Alice');
      expect(
          backend
              .named('POST', '/auth/v1/token')
              .map((r) => r.uri.queryParameters['grant_type']),
          ['password', 'refresh_token']);
      again.close();
    });

    test('a refused refresh signs out and clears the saved session', () async {
      serveSignIn();
      await client.signIn('a@example.test', 'right-password');
      now = now.add(const Duration(hours: 2));
      backend.routes['POST /auth/v1/token'] =
          (_) => (400, {'error_code': 'refresh_token_not_found'});
      final again = makeClient();
      expect(await again.restore(), isNull);
      expect(store.data, isNull);
      again.close();
    });

    test('a 401 mid-session refreshes once and retries', () async {
      serveSignIn();
      await client.signIn('a@example.test', 'right-password');
      backend.validAccess = 'revoked-on-server';
      final account = await client.account();
      expect(account.displayName, 'Alice');
      expect(backend.named('POST', '/auth/v1/token').length, 2);
    });

    test('damaged saved data means signed out', () {
      expect(CloudSession.decode('{oops'), isNull);
      expect(CloudSession.decode('{"access_token": 3}'), isNull);
      expect(CloudSession.decode(null), isNull);
    });

    test('sign-out clears locally even when the server is unreachable',
        () async {
      serveSignIn();
      await client.signIn('a@example.test', 'right-password');
      await backend.stop();
      await client.signOut();
      expect(client.isSignedIn, isFalse);
      expect(store.data, isNull);
      await backend.start();
    });
  });

  group('progress and classes', () {
    setUp(() async {
      serveSignIn();
      await client.signIn('a@example.test', 'right-password');
    });

    test('progress upload is chunked to the server limit', () async {
      backend.routes['POST /rest/v1/rpc/sync_progress'] =
          (r) => (200, ((r.body as Map)['items'] as List).length);
      final items = [
        for (var i = 0; i < 1200; i++)
          ProgressItem(
              path: 'p',
              skill: 's$i',
              mastery: 80,
              attempts: 5,
              mastered: true),
      ];
      expect(await client.syncProgress(items), 1200);
      final calls = backend.named('POST', '/rest/v1/rpc/sync_progress');
      expect(calls.length, 3);
      final first = ((calls.first.body as Map)['items'] as List).first;
      expect(first, {
        'path': 'p',
        'skill': 's0',
        'mastery': 80,
        'attempts': 5,
        'mastered': true
      });
    });

    test('joining normalizes the code; an unknown code is reported', () async {
      backend.routes['POST /rest/v1/rpc/join_class'] =
          (r) => (r.body as Map)['code'] == 'ABCD2345'
              ? (
                  200,
                  [
                    {'class_id': 'c1', 'class_name': 'Class A'}
                  ]
                )
              : (400, {'code': 'P0002', 'message': 'unknown class code'});
      final joined = await client.joinClass(' abcd2345 ');
      expect(joined.name, 'Class A');
      expect(joined.joinCode, 'ABCD2345');
      await expectLater(
          client.joinClass('ZZZZZZZZ'),
          throwsA(isA<CloudException>()
              .having((e) => e.kind, 'kind', CloudErrorKind.unknownClassCode)));
    });

    test('class list marks the classes I teach', () async {
      backend.routes['GET /rest/v1/classes'] = (_) => (
            200,
            [
              {
                'id': 'c1',
                'name': 'Mine',
                'join_code': 'ABCD2345',
                'teacher_id': 'u1'
              },
              {
                'id': 'c2',
                'name': 'Joined',
                'join_code': 'EFGH6789',
                'teacher_id': 'u9'
              },
            ]
          );
      final list = await client.classes();
      expect([for (final c in list) c.isMine], [true, false]);
      expect(
          backend
              .named('GET', '/rest/v1/classes')
              .single
              .uri
              .queryParameters['archived_at'],
          'is.null');
    });

    test('creating a class asks for the new row; a refusal is "not allowed"',
        () async {
      backend.routes['POST /rest/v1/classes'] = (_) => (
            201,
            [
              {
                'id': 'c1',
                'name': 'Class A',
                'join_code': 'ABCD2345',
                'teacher_id': 'u1'
              }
            ]
          );
      final created = await client.createClass('  Class A ');
      expect(created.isMine, isTrue);
      final call = backend.named('POST', '/rest/v1/classes').single;
      expect(call.headers['prefer'], 'return=representation');
      expect(call.body, {'name': 'Class A'});
      backend.routes['POST /rest/v1/classes'] = (_) => (
            403,
            {
              'code': '42501',
              'message': 'new row violates row-level security policy'
            }
          );
      await expectLater(
          client.createClass('x'),
          throwsA(isA<CloudException>()
              .having((e) => e.kind, 'kind', CloudErrorKind.notAllowed)));
    });

    test('class progress rows, including students with nothing yet', () async {
      backend.routes['POST /rest/v1/rpc/class_progress'] = (_) => (
            200,
            [
              {
                'student_id': 's1',
                'display_name': 'Alice',
                'path': 'fractions',
                'skill': 'add-fractions',
                'mastery': 40.0,
                'attempts': 3,
                'mastered': false,
              },
              {
                'student_id': 's2',
                'display_name': 'Bob',
                'path': null,
                'skill': null,
                'mastery': null,
                'attempts': null,
                'mastered': null,
              },
            ]
          );
      final rows = await client.classProgress('c1');
      expect(rows.first.mastery, 40);
      expect(rows.last.skill, isNull);
      expect(backend.named('POST', '/rest/v1/rpc/class_progress').single.body,
          {'class': 'c1'});
    });

    test('leaving a class deletes only my membership row', () async {
      backend.routes['DELETE /rest/v1/class_members'] = (_) => (204, null);
      await client.leaveClass('c1');
      final q = backend
          .named('DELETE', '/rest/v1/class_members')
          .single
          .uri
          .queryParameters;
      expect(q, {'class_id': 'eq.c1', 'student_id': 'eq.u1'});
    });
  });
}
