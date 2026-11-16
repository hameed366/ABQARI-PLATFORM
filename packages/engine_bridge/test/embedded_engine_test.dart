import 'dart:convert';
import 'dart:io';

import 'package:abqari_bridge/abqari_bridge.dart';
import 'package:abqari_engine/abqari_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the Python service: same routes, same token rule.
class FakeService {
  HttpServer? server;
  String? token;
  int launches = 0;
  int solveStatus = 200;
  String solveBody = '';
  Duration solveDelay = Duration.zero;

  Future<void> launch(Map<String, String> environment) async {
    launches++;
    token = environment['ABQARI_TOKEN'];
    final port = int.parse(environment['ABQARI_PORT']!);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    server!.listen((request) async {
      final response = request.response;
      if (request.headers.value(tokenHeader) != token) {
        response.statusCode = 403;
        response.write('{"error":"forbidden"}');
      } else if (request.method == 'GET' && request.uri.path == '/health') {
        response.write('{"ready":true}');
      } else if (request.method == 'POST' && request.uri.path == '/solve') {
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        await Future<void>.delayed(solveDelay);
        response.statusCode = solveStatus;
        response.write(solveBody.isNotEmpty
            ? solveBody
            : _answerFor(body['text'] as String));
      } else {
        response.statusCode = 404;
      }
      await response.close();
    });
  }

  String _answerFor(String text) => jsonEncode({
        'input': {'raw': text, 'normalized': 'sin(pi/6)'},
        'status': 'solved',
        'task': 'evaluate',
        'answer': {
          'plain': '1/2',
          'approx': '0.5',
          'tree': [
            'div',
            ['num', '1'],
            ['num', '2']
          ],
        },
        'notes': [],
        'verification': {
          'status': 'verified',
          'checks': [
            {'name': 'high_precision_numeric', 'passed': true, 'detail': ''},
          ],
        },
      });

  Future<void> close() async => server?.close(force: true);
}

void main() {
  late FakeService service;
  setUp(() => service = FakeService());
  tearDown(() => service.close());

  test('starts once, sends the secret, and decodes the answer', () async {
    final engine = EmbeddedPythonEngine(launcher: service.launch);
    final first = await engine.solve('جا(π/٦)');
    final second = await engine.solve('جا(π/٦)');
    expect(first.status, SolveStatus.solved);
    expect(sexpr(first.answer!.expression!), '(div 1 2)');
    expect(second.status, SolveStatus.solved);
    expect(service.launches, 1);
    expect(service.token, hasLength(64));
  });

  test('every launch gets a fresh secret and port', () async {
    final a = FakeService();
    final b = FakeService();
    await EmbeddedPythonEngine(launcher: a.launch).solve('1');
    await EmbeddedPythonEngine(launcher: b.launch).solve('1');
    expect(a.token, isNot(b.token));
    expect(a.server!.port, isNot(b.server!.port));
    await a.close();
    await b.close();
  });

  test('a launch that never answers becomes unavailable, then can retry',
      () async {
    var attempts = 0;
    final engine = EmbeddedPythonEngine(
      launcher: (_) async => attempts++,
      startTimeout: const Duration(milliseconds: 800),
    );
    await expectLater(
      engine.solve('1'),
      throwsA(isA<FullEngineUnavailable>()
          .having((e) => e.reason, 'reason', 'start_timeout')),
    );
    await expectLater(engine.solve('1'), throwsA(isA<FullEngineUnavailable>()));
    expect(attempts, 2);
  });

  test('a launcher that throws is reported as launch_failed', () async {
    final engine = EmbeddedPythonEngine(
        launcher: (_) async => throw StateError('no python'));
    await expectLater(
      engine.solve('1'),
      throwsA(isA<FullEngineUnavailable>()
          .having((e) => e.reason, 'reason', 'launch_failed')),
    );
  });

  test('server errors, slow answers and malformed answers are not shown',
      () async {
    final engine = EmbeddedPythonEngine(
      launcher: service.launch,
      solveTimeout: const Duration(milliseconds: 500),
    );
    service.solveStatus = 500;
    service.solveBody = '{"error":"internal_error"}';
    await expectLater(
        engine.solve('1'),
        throwsA(isA<FullEngineUnavailable>()
            .having((e) => e.reason, 'reason', 'http_500')));

    service.solveStatus = 200;
    service.solveBody =
        '{"status":"solved","task":"evaluate","answer":{"tree":["num","oops"]}}';
    await expectLater(
        engine.solve('1'),
        throwsA(isA<FullEngineUnavailable>()
            .having((e) => e.reason, 'reason', 'malformed_answer')));

    service.solveBody = '[1, 2, 3]';
    await expectLater(
        engine.solve('1'),
        throwsA(isA<FullEngineUnavailable>()
            .having((e) => e.reason, 'reason', 'malformed_answer')));

    service.solveBody = '';
    service.solveDelay = const Duration(seconds: 2);
    await expectLater(
        engine.solve('1'),
        throwsA(isA<FullEngineUnavailable>()
            .having((e) => e.reason, 'reason', 'timeout')));
  });
}
