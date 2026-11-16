import 'package:shared_preferences/shared_preferences.dart';

/// Where the chosen language is remembered between launches.
abstract interface class LocaleStore {
  Future<String?> readLanguageCode();

  Future<void> writeLanguageCode(String languageCode);
}

/// Keeps the choice only for the lifetime of the object. For tests.
class InMemoryLocaleStore implements LocaleStore {
  InMemoryLocaleStore([this.languageCode]);

  String? languageCode;

  @override
  Future<String?> readLanguageCode() async => languageCode;

  @override
  Future<void> writeLanguageCode(String languageCode) async {
    this.languageCode = languageCode;
  }
}

/// Persists the choice on the device.
class SharedPreferencesLocaleStore implements LocaleStore {
  const SharedPreferencesLocaleStore({this.key = defaultKey});

  static const String defaultKey = 'abqari.language_code';

  final String key;

  @override
  Future<String?> readLanguageCode() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(key);
  }

  @override
  Future<void> writeLanguageCode(String languageCode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, languageCode);
  }
}
