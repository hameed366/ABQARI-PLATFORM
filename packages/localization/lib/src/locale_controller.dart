import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'abqari_locales.dart';
import 'locale_store.dart';

/// Holds the app language, switches it immediately, and remembers the choice.
///
/// Listeners are notified synchronously on change, so the UI rebuilds in the
/// new language and direction without a restart and without losing state.
class LocaleController extends ChangeNotifier {
  LocaleController({required LocaleStore store, Locale? initial})
      : _store = store,
        _locale = initial ?? AbqariLocales.fallback;

  final LocaleStore _store;
  Locale _locale;

  Locale get locale => _locale;

  /// Restores the saved language. Call once before the first frame.
  ///
  /// A missing or unsupported saved value keeps the current locale. A storage
  /// failure is reported through [FlutterError.reportError] and the app starts
  /// in the current locale rather than not starting at all.
  Future<void> load() async {
    String? saved;
    try {
      saved = await _store.readLanguageCode();
    } catch (error, stack) {
      _report(error, stack, 'while restoring the saved language');
      return;
    }
    final locale = AbqariLocales.fromLanguageCode(saved);
    if (locale != null && locale != _locale) {
      _locale = locale;
      notifyListeners();
    }
  }

  /// Switches to [locale] now and saves the choice.
  ///
  /// Throws [ArgumentError] for a language the apps do not ship. If saving
  /// fails the switch still holds for this session and the failure is reported.
  Future<void> setLocale(Locale locale) async {
    final next = AbqariLocales.fromLanguageCode(locale.languageCode);
    if (next == null) {
      throw ArgumentError.value(locale, 'locale', 'Unsupported language');
    }
    if (next == _locale) return;
    _locale = next;
    notifyListeners();
    try {
      await _store.writeLanguageCode(next.languageCode);
    } catch (error, stack) {
      _report(error, stack, 'while saving the chosen language');
    }
  }

  Future<void> toggle() => setLocale(AbqariLocales.other(_locale));

  void _report(Object error, StackTrace stack, String context) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'abqari_localization',
        context: ErrorDescription(context),
      ),
    );
  }
}
