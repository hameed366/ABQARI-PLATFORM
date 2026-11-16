import 'package:abqari_localization/abqari_localization.dart';
import 'package:flutter/widgets.dart';

/// Every user-visible interface string of ABQARI EDU, in both languages.
/// (Lesson content lives in the abqari_learning catalog.)
///
/// Adding a getter here forces both languages to provide it at compile time.
abstract class EduStrings {
  const EduStrings();

  String get appTitle;
  String get headline;
  String get tagline;
  String get pathsTitle;
  String get lessonTitle;
  String get workedExampleTitle;
  String get practiceButton;
  String get lockedHint;
  String get recommended;
  String get levelNotStarted;
  String get levelLearning;
  String get levelPractising;
  String get levelMastered;
  String get answerLabel;
  String get answerHint;
  String get checkButton;
  String get nextButton;
  String get correct;
  String get incorrect;
  String get correctAnswerIs;
  String get showSolution;
  String get questionUnavailable;
  String pathProgress(int percent);
  String mastery(int percent);

  /// The home-screen strings, for completeness checks in tests.
  List<String> get all => [appTitle, headline, tagline, pathsTitle];

  /// Every string, for completeness checks in tests.
  List<String> get everything => [
        ...all,
        lessonTitle,
        workedExampleTitle,
        practiceButton,
        lockedHint,
        recommended,
        levelNotStarted,
        levelLearning,
        levelPractising,
        levelMastered,
        answerLabel,
        answerHint,
        checkButton,
        nextButton,
        correct,
        incorrect,
        correctAnswerIs,
        showSolution,
        questionUnavailable,
        pathProgress(40),
        mastery(80),
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
  String get tagline => 'مسارات عامة مبنية على الموضوع والمهارة ومستوى الإتقان.';
  @override
  String get pathsTitle => 'مسارات التعلّم';
  @override
  String get lessonTitle => 'الدرس';
  @override
  String get workedExampleTitle => 'مثال محلول';
  @override
  String get practiceButton => 'تدرّب';
  @override
  String get lockedHint => 'أتقن المهارة السابقة أولًا';
  @override
  String get recommended => 'المهارة التالية المقترحة';
  @override
  String get levelNotStarted => 'لم تبدأ';
  @override
  String get levelLearning => 'تتعلّم';
  @override
  String get levelPractising => 'تتدرّب';
  @override
  String get levelMastered => 'أتقنتها';
  @override
  String get answerLabel => 'إجابتك';
  @override
  String get answerHint => 'اكتب الإجابة هنا';
  @override
  String get checkButton => 'تحقّق';
  @override
  String get nextButton => 'سؤال آخر';
  @override
  String get correct => 'إجابة صحيحة';
  @override
  String get incorrect => 'إجابة غير صحيحة';
  @override
  String get correctAnswerIs => 'الإجابة الصحيحة';
  @override
  String get showSolution => 'طريقة الحل';
  @override
  String get questionUnavailable => 'تعذّر إعداد سؤال لهذه المهارة الآن.';
  @override
  String pathProgress(int percent) =>
      AbqariDigits.toArabicIndic('الإتقان في المسار: ٪$percent');
  @override
  String mastery(int percent) => AbqariDigits.toArabicIndic('الإتقان: ٪$percent');
}

class EduStringsEn extends EduStrings {
  const EduStringsEn();

  @override
  String get appTitle => 'ABQARI EDU';
  @override
  String get headline => 'Learn mathematics your way';
  @override
  String get tagline => 'General learning paths built on topic, skill, and mastery level.';
  @override
  String get pathsTitle => 'Learning paths';
  @override
  String get lessonTitle => 'Lesson';
  @override
  String get workedExampleTitle => 'Worked example';
  @override
  String get practiceButton => 'Practise';
  @override
  String get lockedHint => 'Master the previous skill first';
  @override
  String get recommended => 'Suggested next skill';
  @override
  String get levelNotStarted => 'Not started';
  @override
  String get levelLearning => 'Learning';
  @override
  String get levelPractising => 'Practising';
  @override
  String get levelMastered => 'Mastered';
  @override
  String get answerLabel => 'Your answer';
  @override
  String get answerHint => 'Type the answer here';
  @override
  String get checkButton => 'Check';
  @override
  String get nextButton => 'Another question';
  @override
  String get correct => 'Correct';
  @override
  String get incorrect => 'Not correct';
  @override
  String get correctAnswerIs => 'The correct answer';
  @override
  String get showSolution => 'How to solve it';
  @override
  String get questionUnavailable => 'A question for this skill could not be prepared right now.';
  @override
  String pathProgress(int percent) => 'Path mastery: $percent%';
  @override
  String mastery(int percent) => 'Mastery: $percent%';
}
