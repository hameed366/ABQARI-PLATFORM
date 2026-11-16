import 'dart:ui';

import 'package:abqari_localization/abqari_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingStore implements LocaleStore {
  @override
  Future<String?> readLanguageCode() async => throw StateError('read failed');

  @override
  Future<void> writeLanguageCode(String languageCode) async =>
      throw StateError('write failed');
}

/// Runs [body] and returns the errors it reported via FlutterError.
Future<List<FlutterErrorDetails>> _capturingErrors(
  Future<void> Function() body,
) async {
  final reported = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = reported.add;
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return reported;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AbqariLocales', () {
    test('ships exactly Arabic and English, Arabic first', () {
      expect(AbqariLocales.supported, const [Locale('ar'), Locale('en')]);
      expect(AbqariLocales.fallback, const Locale('ar'));
    });

    test('resolves supported codes and rejects others', () {
      expect(AbqariLocales.fromLanguageCode('en'), const Locale('en'));
      expect(AbqariLocales.fromLanguageCode('ar'), const Locale('ar'));
      expect(AbqariLocales.fromLanguageCode('fr'), isNull);
      expect(AbqariLocales.fromLanguageCode(null), isNull);
    });

    test('other() flips between the two languages', () {
      expect(AbqariLocales.other(const Locale('ar')), const Locale('en'));
      expect(AbqariLocales.other(const Locale('en')), const Locale('ar'));
    });
  });

  group('LocaleController', () {
    test('starts in Arabic when nothing is saved', () async {
      final controller = LocaleController(store: InMemoryLocaleStore());
      await controller.load();
      expect(controller.locale, const Locale('ar'));
    });

    test('restores a saved language and notifies', () async {
      final controller = LocaleController(store: InMemoryLocaleStore('en'));
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.load();

      expect(controller.locale, const Locale('en'));
      expect(notifications, 1);
    });

    test('ignores an unsupported saved language', () async {
      final controller = LocaleController(store: InMemoryLocaleStore('fr'));
      await controller.load();
      expect(controller.locale, const Locale('ar'));
    });

    test('setLocale switches at once, notifies once, and saves', () async {
      final store = InMemoryLocaleStore();
      final controller = LocaleController(store: store);
      final seen = <Locale>[];
      controller.addListener(() => seen.add(controller.locale));

      final pending = controller.setLocale(const Locale('en'));
      expect(controller.locale, const Locale('en'), reason: 'before the save completes');
      await pending;

      expect(seen, const [Locale('en')]);
      expect(store.languageCode, 'en');
    });

    test('setLocale to the current language does nothing', () async {
      final store = InMemoryLocaleStore();
      final controller = LocaleController(store: store);
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.setLocale(const Locale('ar'));

      expect(notifications, 0);
      expect(store.languageCode, isNull);
    });

    test('setLocale rejects an unsupported language', () async {
      final controller = LocaleController(store: InMemoryLocaleStore());
      await expectLater(
        controller.setLocale(const Locale('fr')),
        throwsArgumentError,
      );
      expect(controller.locale, const Locale('ar'));
    });

    test('toggle goes ar → en → ar and saves each time', () async {
      final store = InMemoryLocaleStore();
      final controller = LocaleController(store: store);

      await controller.toggle();
      expect(controller.locale, const Locale('en'));
      expect(store.languageCode, 'en');

      await controller.toggle();
      expect(controller.locale, const Locale('ar'));
      expect(store.languageCode, 'ar');
    });

    test('a failing read is reported and the app still starts in Arabic', () async {
      final controller = LocaleController(store: _FailingStore());
      final reported = await _capturingErrors(controller.load);

      expect(controller.locale, const Locale('ar'));
      expect(reported, hasLength(1));
      expect(reported.single.exception, isStateError);
    });

    test('a failing save is reported and the switch still holds', () async {
      final controller = LocaleController(store: _FailingStore());
      final reported = await _capturingErrors(
        () => controller.setLocale(const Locale('en')),
      );

      expect(controller.locale, const Locale('en'));
      expect(reported, hasLength(1));
    });
  });

  group('SharedPreferencesLocaleStore', () {
    test('reads nothing on a fresh install', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await const SharedPreferencesLocaleStore().readLanguageCode(), isNull);
    });

    test('a written language survives into a new controller', () async {
      SharedPreferences.setMockInitialValues({});
      const store = SharedPreferencesLocaleStore();

      await LocaleController(store: store).setLocale(const Locale('en'));

      final relaunched = LocaleController(store: store);
      await relaunched.load();
      expect(relaunched.locale, const Locale('en'));
    });
  });
}
