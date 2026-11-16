import 'package:shared_preferences/shared_preferences.dart';

/// Where the chosen appearance (system / light / dark) is remembered.
abstract interface class ThemeModeStore {
  Future<String?> readThemeModeName();

  Future<void> writeThemeModeName(String name);
}

/// Keeps the choice only for the lifetime of the object. For tests.
class InMemoryThemeModeStore implements ThemeModeStore {
  InMemoryThemeModeStore([this.name]);

  String? name;

  @override
  Future<String?> readThemeModeName() async => name;

  @override
  Future<void> writeThemeModeName(String name) async {
    this.name = name;
  }
}

/// Persists the choice on the device.
class SharedPreferencesThemeModeStore implements ThemeModeStore {
  const SharedPreferencesThemeModeStore({this.key = defaultKey});

  static const String defaultKey = 'abqari.theme_mode';

  final String key;

  @override
  Future<String?> readThemeModeName() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(key);
  }

  @override
  Future<void> writeThemeModeName(String name) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, name);
  }
}
