import 'package:material_ui/material_ui.dart';

import 'theme_mode_store.dart';

/// Holds the appearance choice, applies it immediately, and remembers it.
class ThemeModeController extends ChangeNotifier {
  ThemeModeController({
    required ThemeModeStore store,
    ThemeMode initial = ThemeMode.system,
  })  : _store = store,
        _mode = initial;

  final ThemeModeStore _store;
  ThemeMode _mode;

  ThemeMode get mode => _mode;

  /// Restores the saved choice. Call once before the first frame.
  ///
  /// An unknown saved value keeps the current mode. A storage failure is
  /// reported through [FlutterError.reportError] and the app still starts.
  Future<void> load() async {
    String? saved;
    try {
      saved = await _store.readThemeModeName();
    } catch (error, stack) {
      _report(error, stack, 'while restoring the saved appearance');
      return;
    }
    final mode = _fromName(saved);
    if (mode != null && mode != _mode) {
      _mode = mode;
      notifyListeners();
    }
  }

  /// Applies [mode] now and saves it. If saving fails the change still holds
  /// for this session and the failure is reported.
  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    try {
      await _store.writeThemeModeName(mode.name);
    } catch (error, stack) {
      _report(error, stack, 'while saving the chosen appearance');
    }
  }

  /// system → light → dark → system.
  Future<void> cycle() => setMode(switch (_mode) {
        ThemeMode.system => ThemeMode.light,
        ThemeMode.light => ThemeMode.dark,
        ThemeMode.dark => ThemeMode.system,
      });

  static ThemeMode? _fromName(String? name) {
    for (final mode in ThemeMode.values) {
      if (mode.name == name) return mode;
    }
    return null;
  }

  void _report(Object error, StackTrace stack, String context) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'abqari_ui',
        context: ErrorDescription(context),
      ),
    );
  }
}
