import 'package:abqari_localization/abqari_localization.dart';
import 'package:flutter/widgets.dart';

/// Every user-visible string of ABQARI MATH, in both languages.
///
/// Adding a getter here forces both languages to provide it at compile time.
abstract class MathStrings {
  const MathStrings();

  String get appTitle;
  String get headline;
  String get tagline;
  String get firstFeatureTitle;
  String get firstFeatureSubtitle;
  String get secondFeatureTitle;
  String get secondFeatureSubtitle;
  String get thirdFeatureTitle;
  String get thirdFeatureSubtitle;

  /// All strings, for completeness checks in tests.
  List<String> get all => [
        appTitle,
        headline,
        tagline,
        firstFeatureTitle,
        firstFeatureSubtitle,
        secondFeatureTitle,
        secondFeatureSubtitle,
        thirdFeatureTitle,
        thirdFeatureSubtitle,
      ];

  static const LocalizationsDelegate<MathStrings> delegate =
      TypedLocalizationsDelegate<MathStrings>({
    'ar': MathStringsAr(),
    'en': MathStringsEn(),
  });

  static MathStrings of(BuildContext context) =>
      Localizations.of<MathStrings>(context, MathStrings)!;
}

class MathStringsAr extends MathStrings {
  const MathStringsAr();

  @override
  String get appTitle => 'عبقري رياضيات';
  @override
  String get headline => 'مساحتك الرياضية الشاملة';
  @override
  String get tagline => 'أدخل مسألة، افهم خطواتها، وتحقق من الحل.';
  @override
  String get firstFeatureTitle => 'حل المسائل';
  @override
  String get firstFeatureSubtitle => 'حساب، جبر، معادلات ومتباينات';
  @override
  String get secondFeatureTitle => 'الهندسة والرسوم';
  @override
  String get secondFeatureSubtitle => 'أشكال، قياسات وتمثيل بياني';
  @override
  String get thirdFeatureTitle => 'الرياضيات المتقدمة';
  @override
  String get thirdFeatureSubtitle => 'تفاضل وتكامل، إحصاء وجبر خطي';
}

class MathStringsEn extends MathStrings {
  const MathStringsEn();

  @override
  String get appTitle => 'ABQARI MATH';
  @override
  String get headline => 'Your complete mathematics workspace';
  @override
  String get tagline =>
      'Enter a problem, understand its steps, and verify the solution.';
  @override
  String get firstFeatureTitle => 'Problem solving';
  @override
  String get firstFeatureSubtitle =>
      'Arithmetic, algebra, equations, and inequalities';
  @override
  String get secondFeatureTitle => 'Geometry and graphs';
  @override
  String get secondFeatureSubtitle => 'Shapes, measurements, and graphing';
  @override
  String get thirdFeatureTitle => 'Advanced mathematics';
  @override
  String get thirdFeatureSubtitle => 'Calculus, statistics, and linear algebra';
}
