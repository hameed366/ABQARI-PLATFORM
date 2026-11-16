import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:abqari_engine/abqari_engine.dart';
import 'package:serious_python/serious_python.dart';

import 'result_codec.dart';

/// Solves what the device engine cannot.
abstract interface class FullEngine {
  Future<SolveResult> solve(String text);
}

/// The full engine could not answer: it failed to start, timed out, or sent
/// something unreadable. The caller keeps the device engine's result.
class FullEngineUnavailable implements Exception {
  const FullEngineUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'FullEngineUnavailable($reason)';
}

/// Starts the embedded Python program with the given environment.
typedef PythonLauncher = Future<void> Function(Map<String, String> environment);

/// Runs `main.py` from the Python app packaged into this build.
Future<void> launchEmbeddedPython(Map<String, String> environment) async {
  await SeriousPython.run(
      appFileName: 'main.py', environmentVariables: environment);
}

const String tokenHeader = 'X-Abqari-Token';

/// The full engine running as a loopback-only service inside the app.
///
/// It is started on the first problem that needs it. Each launch gets a new
/// random port and a 256-bit secret, so no other app on the device can use it.
class EmbeddedPythonEngine implements FullEngine {
  EmbeddedPythonEngine({
    PythonLauncher launcher = launchEmbeddedPython,
    this.startTimeout = const Duration(seconds: 90),
    this.solveTimeout = const Duration(seconds: 30),
  }) : _launcher = launcher;

  final PythonLauncher _launcher;
  final Duration startTimeout;
  final Duration solveTimeout;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5);

  Future<_Endpoint>? _starting;

  /// One start at a time; a failed start is forgotten so the next call retries.
  Future<_Endpoint> _endpoint() {
    final existing = _starting;
    if (existing != null) return existing;
    final started = _start();
    _starting = started;
    started.then<void>((_) {}, onError: (Object _) {
      if (identical(_starting, started)) _starting = null;
    });
    return started;
  }

  Future<_Endpoint> _start() async {
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();
    final random = Random.secure();
    final token = [
      for (var i = 0; i < 32; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    final endpoint =
        _Endpoint(Uri(scheme: 'http', host: '127.0.0.1', port: port), token);

    try {
      await _launcher({'ABQARI_PORT': '$port', 'ABQARI_TOKEN': token});
    } catch (_) {
      throw const FullEngineUnavailable('launch_failed');
    }
    final deadline = DateTime.now().add(startTimeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final (status, body) = await _request(endpoint, 'GET', '/health')
            .timeout(const Duration(seconds: 3));
        if (status == 200 && body['ready'] == true) return endpoint;
      } on Object {
        // not listening yet
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    throw const FullEngineUnavailable('start_timeout');
  }

  Future<(int, Map<String, dynamic>)> _request(
    _Endpoint endpoint,
    String method,
    String path, [
    Map<String, Object?>? body,
  ]) async {
    final request =
        await _client.openUrl(method, endpoint.base.replace(path: path));
    request.headers.set(tokenHeader, endpoint.token);
    if (body != null) {
      // A fixed length, not chunked: the Python service reads Content-Length.
      final bytes = utf8.encode(jsonEncode(body));
      request.headers.contentType = ContentType.json;
      request.contentLength = bytes.length;
      request.add(bytes);
    }
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    final decoded = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
    return (response.statusCode, (decoded as Map).cast<String, dynamic>());
  }

  @override
  Future<SolveResult> solve(String text) async {
    final endpoint = await _endpoint();
    try {
      final (status, body) =
          await _request(endpoint, 'POST', '/solve', {'text': text})
              .timeout(solveTimeout);
      if (status != 200) throw FullEngineUnavailable('http_$status');
      return solveResultFromJson(body);
    } on FullEngineUnavailable {
      rethrow;
    } on TimeoutException {
      throw const FullEngineUnavailable('timeout');
    } on IOException {
      _starting = null; // the service died; start it again next time
      throw const FullEngineUnavailable('connection_failed');
    } on Object {
      // FormatException, a JSON value of the wrong shape, …
      throw const FullEngineUnavailable('malformed_answer');
    }
  }
}

class _Endpoint {
  const _Endpoint(this.base, this.token);

  final Uri base;
  final String token;
}
