import 'package:abqari_localization/abqari_localization.dart';
import 'package:flutter/widgets.dart';

/// Every user-visible string of ABQARI EDU, in both languages.
///
/// Adding a getter here forces both languages to provide it at compile time.
abstract class EduStrings {
  const EduStrings();

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

  static const LocalizationsDelegate<EduStrings> delegate =
      TypedLocalizationsDelegate<EduStrings>({
    'ar': EduStringsAr(),
    'en': EduStringsEn(),
  });

  static EduStrings of(BuildContext context) =>
      Localizations.of<EduStrings>(context, EduStrings)!;
}

class EduStringsAr extends EduStrings {
  const EduStringsAr();

  @override
  String get appTitle => 'عبقري التعليمي';
  @override
  String get headline => 'تعلّم الرياضيات بطريقتك';
  @override
  String get tagline =>
      'مسارات عامة مبنية على الموضوع والمهارة ومستوى الإتقان.';
  @override
  String get firstFeatureTitle => 'مسارات التعلّم';
  @override
  String get firstFeatureSubtitle => 'اختر مجالاً وموضوعاً يناسب مستواك';
  @override
  String get secondFeatureTitle => 'التدريب والاختبار';
  @override
  String get secondFeatureSubtitle => 'أسئلة متدرجة مع تغذية راجعة';
  @override
  String get thirdFeatureTitle => 'متابعة التقدّم';
  @override
  String get thirdFeatureSubtitle =>
      'اعرف المهارات التي أتقنتها وما يحتاج إلى مراجعة';
}

class EduStringsEn extends EduStrings {
  const EduStringsEn();

  @override
  String get appTitle => 'ABQARI EDU';
  @override
  String get headline => 'Learn mathematics your way';
  @override
  String get tagline =>
      'General learning paths built on topic, skill, and mastery level.';
  @override
  String get firstFeatureTitle => 'Learning paths';
  @override
  String get firstFeatureSubtitle =>
      'Pick a domain and a topic that match your level';
  @override
  String get secondFeatureTitle => 'Practice and quizzes';
  @override
  String get secondFeatureSubtitle => 'Graded questions with feedback';
  @override
  String get thirdFeatureTitle => 'Progress tracking';
  @override
  String get thirdFeatureSubtitle =>
      'See which skills you have mastered and which need review';
}
