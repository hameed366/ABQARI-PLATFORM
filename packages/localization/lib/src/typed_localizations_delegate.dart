import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Serves one ready-made strings object per language code.
///
/// Strings are plain Dart classes, so a missing translation is a compile
/// error rather than a runtime surprise.
class TypedLocalizationsDelegate<T extends Object>
    extends LocalizationsDelegate<T> {
  const TypedLocalizationsDelegate(this.byLanguageCode);

  final Map<String, T> byLanguageCode;

  @override
  bool isSupported(Locale locale) =>
      byLanguageCode.containsKey(locale.languageCode);

  @override
  Future<T> load(Locale locale) =>
      SynchronousFuture<T>(byLanguageCode[locale.languageCode]!);

  @override
  bool shouldReload(TypedLocalizationsDelegate<T> old) => false;
}
