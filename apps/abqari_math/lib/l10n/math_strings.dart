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

  // solver screen
  String get solverTitle;
  String get inputLabel;
  String get inputHint;
  String get solveButton;
  String get examplesTitle;
  List<String> get examples;
  String get understoodTitle;
  String get answerTitle;
  String get stepsTitle;
  String get notesTitle;
  String get verificationTitle;
  String get fullEngineWorking;
  String get fullEngineUnavailable;
  String get solvedByFullEngine;
  String checksPassed(int passed, int total);
  String errorAt(int position);

  /// The solver strings, for completeness checks in tests.
  List<String> get solverStrings => [
        solverTitle,
        inputLabel,
        inputHint,
        solveButton,
        examplesTitle,
        ...examples,
        understoodTitle,
        answerTitle,
        stepsTitle,
        notesTitle,
        verificationTitle,
        fullEngineWorking,
        fullEngineUnavailable,
        solvedByFullEngine,
        checksPassed(3, 4),
        errorAt(5),
      ];

  /// The home-screen strings, for completeness checks in tests.
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

  @override
  String get solverTitle => 'حل المسائل';
  @override
  String get inputLabel => 'اكتب المسألة';
  @override
  String get inputHint => 'مثال: ٢س + ٣ = ٧';
  @override
  String get solveButton => 'حل';
  @override
  String get examplesTitle => 'أمثلة';
  @override
  List<String> get examples => const [
        '٢س + ٣ = ٧',
        'س² − ٥س + ٦ = ٠',
        'حلل س² − ٩',
        'احسب ١/٢ + ١/٣',
      ];
  @override
  String get understoodTitle => 'فهمتُ المسألة هكذا';
  @override
  String get answerTitle => 'الناتج';
  @override
  String get stepsTitle => 'خطوات الحل';
  @override
  String get notesTitle => 'ملاحظات';
  @override
  String get verificationTitle => 'التحقق';
  @override
  String get fullEngineWorking => 'يعمل المحرك الكامل على المسألة…';
  @override
  String get fullEngineUnavailable =>
      'تعذّر تشغيل المحرك الكامل الآن. حاول مرة أخرى.';
  @override
  String get solvedByFullEngine => 'حُلّت بالمحرك الكامل';
  @override
  String checksPassed(int passed, int total) => AbqariDigits.toArabicIndic(
        'اجتاز $passed من $total فحوص مستقلة',
      );
  @override
  String errorAt(int position) =>
      AbqariDigits.toArabicIndic('عند الحرف رقم $position');
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

  @override
  String get solverTitle => 'Problem solving';
  @override
  String get inputLabel => 'Type the problem';
  @override
  String get inputHint => 'Example: 2x + 3 = 7';
  @override
  String get solveButton => 'Solve';
  @override
  String get examplesTitle => 'Examples';
  @override
  List<String> get examples => const [
        '2x + 3 = 7',
        'x^2 - 5x + 6 = 0',
        'factor x^2 - 9',
        'calculate 1/2 + 1/3',
      ];
  @override
  String get understoodTitle => 'I read the problem as';
  @override
  String get answerTitle => 'Result';
  @override
  String get stepsTitle => 'Steps';
  @override
  String get notesTitle => 'Notes';
  @override
  String get verificationTitle => 'Verification';
  @override
  String get fullEngineWorking => 'The full engine is working on it…';
  @override
  String get fullEngineUnavailable =>
      'The full engine could not run right now. Please try again.';
  @override
  String get solvedByFullEngine => 'Solved by the full engine';
  @override
  String checksPassed(int passed, int total) =>
      'Passed $passed of $total independent checks';
  @override
  String errorAt(int position) => 'At character $position';
}
