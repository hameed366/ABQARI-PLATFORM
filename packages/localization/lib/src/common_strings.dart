import 'package:flutter/widgets.dart';

import 'typed_localizations_delegate.dart';

/// Strings shared by both apps. App-specific strings live in each app.
abstract class CommonStrings {
  const CommonStrings();

  /// Name of the language the user can switch to, written in that language.
  String get otherLanguageName;

  String get switchLanguageTooltip;

  String get switchAppearanceTooltip;

  static const LocalizationsDelegate<CommonStrings> delegate =
      TypedLocalizationsDelegate<CommonStrings>({
    'ar': CommonStringsAr(),
    'en': CommonStringsEn(),
  });

  static CommonStrings of(BuildContext context) =>
      Localizations.of<CommonStrings>(context, CommonStrings)!;
}

class CommonStringsAr extends CommonStrings {
  const CommonStringsAr();

  @override
  String get otherLanguageName => 'English';

  @override
  String get switchLanguageTooltip => 'تغيير اللغة إلى الإنجليزية';

  @override
  String get switchAppearanceTooltip => 'تغيير المظهر: تلقائي، فاتح، داكن';
}

class CommonStringsEn extends CommonStrings {
  const CommonStringsEn();

  @override
  String get otherLanguageName => 'العربية';

  @override
  String get switchLanguageTooltip => 'Switch language to Arabic';

  @override
  String get switchAppearanceTooltip =>
      'Change appearance: automatic, light, dark';
}
