import 'package:abqari_cloud/abqari_cloud.dart';
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

  // ── account (optional; shown only when the build has a backend) ──
  String get accountTooltip;
  String get accountTitle;
  String get accountIntro;
  String get signInTab;
  String get signUpTab;
  String get emailLabel;
  String get passwordLabel;
  String get displayNameLabel;
  String get fieldRequired;
  String get passwordTooShort;
  String get signInButton;
  String get signUpButton;
  String get signOutButton;
  String get retryButton;
  String get roleStudent;
  String get roleTeacher;
  String get roleAdmin;
  String get syncButton;
  String get joinClassTitle;
  String get joinCodeLabel;
  String get joinButton;
  String get myClassesTitle;
  String get noClasses;
  String get classNameLabel;
  String get createClassButton;
  String get newCodeButton;
  String get archiveClassButton;
  String get leaveClassButton;
  String get noStudents;
  String get noProgressYet;
  String get errorOffline;
  String get errorInvalidCredentials;
  String get errorEmailNotConfirmed;
  String get errorEmailTaken;
  String get errorWeakPassword;
  String get errorSignedOut;
  String get errorUnknownClassCode;
  String get errorNotAllowed;
  String get errorUnexpected;
  String confirmationSent(String email);
  String synced(DateTime at);
  String joined(String className);
  String joinCodeIs(String code);
  String studentsCount(int count);
  String masteredCount(int mastered, int total);

  String cloudError(CloudErrorKind kind) => switch (kind) {
        CloudErrorKind.offline => errorOffline,
        CloudErrorKind.invalidCredentials => errorInvalidCredentials,
        CloudErrorKind.emailNotConfirmed => errorEmailNotConfirmed,
        CloudErrorKind.emailTaken => errorEmailTaken,
        CloudErrorKind.weakPassword => errorWeakPassword,
        CloudErrorKind.signedOut => errorSignedOut,
        CloudErrorKind.unknownClassCode => errorUnknownClassCode,
        CloudErrorKind.notAllowed => errorNotAllowed,
        CloudErrorKind.unexpected => errorUnexpected,
      };

  String roleName(AccountRole role) => switch (role) {
        AccountRole.student => roleStudent,
        AccountRole.teacher => roleTeacher,
        AccountRole.admin => roleAdmin,
      };

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
        accountTooltip,
        accountTitle,
        accountIntro,
        signInTab,
        signUpTab,
        emailLabel,
        passwordLabel,
        displayNameLabel,
        fieldRequired,
        passwordTooShort,
        signInButton,
        signUpButton,
        signOutButton,
        retryButton,
        syncButton,
        joinClassTitle,
        joinCodeLabel,
        joinButton,
        myClassesTitle,
        noClasses,
        classNameLabel,
        createClassButton,
        newCodeButton,
        archiveClassButton,
        leaveClassButton,
        noStudents,
        noProgressYet,
        for (final kind in CloudErrorKind.values) cloudError(kind),
        for (final role in AccountRole.values) roleName(role),
        confirmationSent('a@example.com'),
        synced(DateTime(2026, 1, 1, 9, 5)),
        joined('7A'),
        joinCodeIs('ABCD2345'),
        studentsCount(12),
        masteredCount(3, 11),
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
  String mastery(int percent) =>
      AbqariDigits.toArabicIndic('الإتقان: ٪$percent');

  @override
  String get accountTooltip => 'الحساب';
  @override
  String get accountTitle => 'الحساب';
  @override
  String get accountIntro =>
      'الحساب اختياري، والتطبيق يعمل كاملًا بدونه. مع الحساب يُحفظ تقدمك على الخادم ويستطيع معلمك متابعته إذا انضممت إلى صفه.';
  @override
  String get signInTab => 'تسجيل الدخول';
  @override
  String get signUpTab => 'حساب جديد';
  @override
  String get emailLabel => 'البريد الإلكتروني';
  @override
  String get passwordLabel => 'كلمة المرور';
  @override
  String get displayNameLabel => 'الاسم';
  @override
  String get fieldRequired => 'هذا الحقل مطلوب';
  @override
  String get passwordTooShort =>
      AbqariDigits.toArabicIndic('كلمة المرور ٨ أحرف على الأقل');
  @override
  String get signInButton => 'دخول';
  @override
  String get signUpButton => 'إنشاء الحساب';
  @override
  String get signOutButton => 'تسجيل الخروج';
  @override
  String get retryButton => 'إعادة المحاولة';
  @override
  String get roleStudent => 'طالب';
  @override
  String get roleTeacher => 'معلم';
  @override
  String get roleAdmin => 'مدير';
  @override
  String get syncButton => 'رفع تقدمي الآن';
  @override
  String get joinClassTitle => 'الانضمام إلى صف';
  @override
  String get joinCodeLabel => 'رمز الصف من معلمك';
  @override
  String get joinButton => 'انضمام';
  @override
  String get myClassesTitle => 'صفوفي';
  @override
  String get noClasses => 'لا توجد صفوف بعد.';
  @override
  String get classNameLabel => 'اسم الصف الجديد';
  @override
  String get createClassButton => 'إنشاء صف';
  @override
  String get newCodeButton => 'رمز جديد';
  @override
  String get archiveClassButton => 'أرشفة الصف';
  @override
  String get leaveClassButton => 'مغادرة الصف';
  @override
  String get noStudents => 'لم ينضم أي طالب بعد. أعطِ طلابك رمز الصف.';
  @override
  String get noProgressYet => 'لم يُرفع تقدم بعد';
  @override
  String get errorOffline =>
      'تعذّر الاتصال بالخادم. تحقّق من الإنترنت ثم أعد المحاولة.';
  @override
  String get errorInvalidCredentials =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
  @override
  String get errorEmailNotConfirmed =>
      'لم يُؤكَّد البريد الإلكتروني بعد. افتح رسالة التأكيد ثم سجّل الدخول.';
  @override
  String get errorEmailTaken =>
      'هذا البريد مسجّل من قبل. سجّل الدخول بدلًا من إنشاء حساب.';
  @override
  String get errorWeakPassword =>
      'كلمة المرور ضعيفة. استخدم كلمة أطول فيها أحرف وأرقام.';
  @override
  String get errorSignedOut => 'انتهت الجلسة. سجّل الدخول مرة أخرى.';
  @override
  String get errorUnknownClassCode =>
      'لا يوجد صف مفتوح بهذا الرمز. تأكّد منه مع معلمك.';
  @override
  String get errorNotAllowed => 'هذا الإجراء غير متاح لحسابك.';
  @override
  String get errorUnexpected => 'حدث خطأ غير متوقع. أعد المحاولة.';
  @override
  String confirmationSent(String email) =>
      'أرسلنا رسالة تأكيد إلى $email. أكّد بريدك ثم سجّل الدخول.';
  @override
  String synced(DateTime at) => AbqariDigits.toArabicIndic(
      'آخر رفع للتقدم: ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}');
  @override
  String joined(String className) => 'انضممت إلى صف «$className».';
  @override
  String joinCodeIs(String code) => 'رمز الانضمام: $code';
  @override
  String studentsCount(int count) =>
      AbqariDigits.toArabicIndic('عدد الطلاب: $count');
  @override
  String masteredCount(int mastered, int total) =>
      AbqariDigits.toArabicIndic('أتقن $mastered من $total مهارة');
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
  String get questionUnavailable =>
      'A question for this skill could not be prepared right now.';
  @override
  String pathProgress(int percent) => 'Path mastery: $percent%';
  @override
  String mastery(int percent) => 'Mastery: $percent%';

  @override
  String get accountTooltip => 'Account';
  @override
  String get accountTitle => 'Account';
  @override
  String get accountIntro =>
      'An account is optional; the app works fully without one. With an account your progress is saved on the server, and your teacher can follow it if you join their class.';
  @override
  String get signInTab => 'Sign in';
  @override
  String get signUpTab => 'New account';
  @override
  String get emailLabel => 'Email';
  @override
  String get passwordLabel => 'Password';
  @override
  String get displayNameLabel => 'Name';
  @override
  String get fieldRequired => 'This field is required';
  @override
  String get passwordTooShort => 'At least 8 characters';
  @override
  String get signInButton => 'Sign in';
  @override
  String get signUpButton => 'Create account';
  @override
  String get signOutButton => 'Sign out';
  @override
  String get retryButton => 'Try again';
  @override
  String get roleStudent => 'Student';
  @override
  String get roleTeacher => 'Teacher';
  @override
  String get roleAdmin => 'Admin';
  @override
  String get syncButton => 'Upload my progress now';
  @override
  String get joinClassTitle => 'Join a class';
  @override
  String get joinCodeLabel => 'Class code from your teacher';
  @override
  String get joinButton => 'Join';
  @override
  String get myClassesTitle => 'My classes';
  @override
  String get noClasses => 'No classes yet.';
  @override
  String get classNameLabel => 'New class name';
  @override
  String get createClassButton => 'Create class';
  @override
  String get newCodeButton => 'New code';
  @override
  String get archiveClassButton => 'Archive class';
  @override
  String get leaveClassButton => 'Leave class';
  @override
  String get noStudents => 'No students yet. Give your students the class code.';
  @override
  String get noProgressYet => 'No progress uploaded yet';
  @override
  String get errorOffline =>
      'Could not reach the server. Check your connection and try again.';
  @override
  String get errorInvalidCredentials => 'Wrong email or password.';
  @override
  String get errorEmailNotConfirmed =>
      'Your email is not confirmed yet. Open the confirmation email, then sign in.';
  @override
  String get errorEmailTaken =>
      'This email is already registered. Sign in instead.';
  @override
  String get errorWeakPassword =>
      'That password is too weak. Use a longer one with letters and numbers.';
  @override
  String get errorSignedOut => 'Your session ended. Please sign in again.';
  @override
  String get errorUnknownClassCode =>
      'No open class has that code. Check it with your teacher.';
  @override
  String get errorNotAllowed => 'Your account cannot do this.';
  @override
  String get errorUnexpected => 'Something went wrong. Please try again.';
  @override
  String confirmationSent(String email) =>
      'We sent a confirmation email to $email. Confirm it, then sign in.';
  @override
  String synced(DateTime at) =>
      'Progress last uploaded: ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
  @override
  String joined(String className) => 'You joined "$className".';
  @override
  String joinCodeIs(String code) => 'Join code: $code';
  @override
  String studentsCount(int count) => 'Students: $count';
  @override
  String masteredCount(int mastered, int total) =>
      'Mastered $mastered of $total skills';
}
