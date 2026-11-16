import 'package:abqari_ui/abqari_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingStore implements ThemeModeStore {
  @override
  Future<String?> readThemeModeName() async => throw StateError('read failed');

  @override
  Future<void> writeThemeModeName(String name) async =>
      throw StateError('write failed');
}

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

  test('follows the system when nothing is saved', () async {
    final controller = ThemeModeController(store: InMemoryThemeModeStore());
    await controller.load();
    expect(controller.mode, ThemeMode.system);
  });

  test('restores a saved choice and notifies', () async {
    final controller =
        ThemeModeController(store: InMemoryThemeModeStore('dark'));
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.load();

    expect(controller.mode, ThemeMode.dark);
    expect(notifications, 1);
  });

  test('ignores an unknown saved value', () async {
    final controller =
        ThemeModeController(store: InMemoryThemeModeStore('sepia'));
    await controller.load();
    expect(controller.mode, ThemeMode.system);
  });

  test('cycle goes system → light → dark → system and saves each step',
      () async {
    final store = InMemoryThemeModeStore();
    final controller = ThemeModeController(store: store);

    await controller.cycle();
    expect(controller.mode, ThemeMode.light);
    expect(store.name, 'light');

    await controller.cycle();
    expect(controller.mode, ThemeMode.dark);
    expect(store.name, 'dark');

    await controller.cycle();
    expect(controller.mode, ThemeMode.system);
    expect(store.name, 'system');
  });

  test('setMode to the current mode does nothing', () async {
    final store = InMemoryThemeModeStore();
    final controller = ThemeModeController(store: store);
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.setMode(ThemeMode.system);

    expect(notifications, 0);
    expect(store.name, isNull);
  });

  test('a failing read is reported and the app still starts', () async {
    final controller = ThemeModeController(store: _FailingStore());
    final reported = await _capturingErrors(controller.load);

    expect(controller.mode, ThemeMode.system);
    expect(reported, hasLength(1));
  });

  test('a failing save is reported and the change still holds', () async {
    final controller = ThemeModeController(store: _FailingStore());
    final reported =
        await _capturingErrors(() => controller.setMode(ThemeMode.dark));

    expect(controller.mode, ThemeMode.dark);
    expect(reported, hasLength(1));
  });

  test('a saved choice survives into a new controller', () async {
    SharedPreferences.setMockInitialValues({});
    const store = SharedPreferencesThemeModeStore();

    await ThemeModeController(store: store).setMode(ThemeMode.dark);

    final relaunched = ThemeModeController(store: store);
    await relaunched.load();
    expect(relaunched.mode, ThemeMode.dark);
  });
}
