import 'package:abqari_cloud/abqari_cloud.dart';
import 'package:abqari_edu/account/account_controller.dart';
import 'package:abqari_edu/account/account_page.dart';
import 'package:abqari_edu/account/class_page.dart';
import 'package:abqari_edu/l10n/edu_strings.dart';
import 'package:abqari_edu/learning/progress_controller.dart';
import 'package:abqari_edu/main.dart';
import 'package:abqari_learning/abqari_learning.dart';
import 'package:abqari_localization/abqari_localization.dart';
import 'package:abqari_ui/abqari_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _ar = EduStringsAr();

/// An in-memory backend with the same rules the server enforces that matter
/// to the UI: password check, roles, join codes, ownership.
class FakeCloud implements CloudService {
  FakeCloud({this.role = AccountRole.student, this.confirmEmail = false});

  AccountRole role;
  bool confirmEmail;
  CloudErrorKind? failNext;
  bool _signedIn = false;
  final List<List<ProgressItem>> uploads = [];
  final List<SchoolClass> _classes = [];
  final Map<String, String> openCodes = {'ABCD2345': 'Class 7A'};
  List<ClassProgressRow> progressRows = const [];

  void _maybeFail() {
    final kind = failNext;
    if (kind != null) {
      failNext = null;
      throw CloudException(kind);
    }
  }

  Account get _account => Account(
      userId: 'u1',
      displayName: 'Alice',
      role: role,
      locale: 'ar',
      email: 'a@example.test');

  @override
  bool get isSignedIn => _signedIn;

  @override
  String? get userId => _signedIn ? 'u1' : null;

  @override
  Future<Account?> restore() async => _signedIn ? _account : null;

  @override
  Future<Account> signIn(String email, String password) async {
    _maybeFail();
    if (password != 'right-password') {
      throw const CloudException(CloudErrorKind.invalidCredentials);
    }
    _signedIn = true;
    return _account;
  }

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String displayName,
    required String locale,
  }) async {
    _maybeFail();
    if (confirmEmail) return ConfirmationSent(email.trim());
    _signedIn = true;
    return SignedUp(_account);
  }

  @override
  Future<void> signOut() async => _signedIn = false;

  @override
  Future<Account> account() async {
    _maybeFail();
    return _account;
  }

  @override
  Future<void> updateProfile({String? displayName, String? locale}) async {}

  @override
  Future<int> syncProgress(List<ProgressItem> items) async {
    _maybeFail();
    uploads.add(items);
    return items.length;
  }

  @override
  Future<SchoolClass> joinClass(String code) async {
    _maybeFail();
    final name = openCodes[code.trim().toUpperCase()];
    if (name == null) {
      throw const CloudException(CloudErrorKind.unknownClassCode);
    }
    final joined =
        SchoolClass(id: 'c-$name', name: name, joinCode: code, isMine: false);
    _classes.add(joined);
    return joined;
  }

  @override
  Future<List<SchoolClass>> classes() async {
    _maybeFail();
    return List.of(_classes);
  }

  @override
  Future<SchoolClass> createClass(String name) async {
    _maybeFail();
    if (role != AccountRole.teacher) {
      throw const CloudException(CloudErrorKind.notAllowed);
    }
    final created = SchoolClass(
        id: 'c${_classes.length}',
        name: name,
        joinCode: 'WXYZ6789',
        isMine: true);
    _classes.add(created);
    return created;
  }

  @override
  Future<void> archiveClass(String classId) async =>
      _classes.removeWhere((c) => c.id == classId);

  @override
  Future<String> regenerateJoinCode(String classId) async {
    final i = _classes.indexWhere((c) => c.id == classId);
    final old = _classes[i];
    _classes[i] = SchoolClass(
        id: old.id, name: old.name, joinCode: 'NEWC0DE2', isMine: true);
    return 'NEWC0DE2';
  }

  @override
  Future<void> leaveClass(String classId) async =>
      _classes.removeWhere((c) => c.id == classId);

  @override
  Future<List<ClassProgressRow>> classProgress(String classId) async {
    _maybeFail();
    return progressRows;
  }
}

Future<(AccountController, ProgressController)> openAccount(
  WidgetTester tester,
  FakeCloud cloud, {
  LearnerProgress? progress,
}) async {
  final store = InMemoryProgressStore(progress?.encode());
  final progressController = ProgressController(store: store);
  await progressController.load();
  final account = AccountController(
    cloud: cloud,
    progress: progressController,
    syncDelay: const Duration(milliseconds: 50),
  );
  await account.start();
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: AbqariLocales.supported,
    localizationsDelegates: [
      EduStrings.delegate,
      CommonStrings.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    home: AccountPage(controller: account),
  ));
  await tester.pumpAndSettle();
  return (account, progressController);
}

Future<void> signIn(WidgetTester tester, String password) async {
  await tester.enterText(find.byKey(AccountKeys.email), 'a@example.test');
  await tester.enterText(find.byKey(AccountKeys.password), password);
  await tester.tap(find.byKey(AccountKeys.submit));
  await tester.pumpAndSettle();
}

LearnerProgress practised() => const LearnerProgress()
    .record('one-step-add', true)
    .record('one-step-add', true)
    .record('add-fractions', false);

void main() {
  test('only skills that were tried are uploaded, with their path', () {
    final items = progressItems(practised());
    expect([for (final i in items) '${i.path}/${i.skill}'],
        ['linear-equations/one-step-add', 'fractions/add-fractions']);
    expect(items.first.mastery, 100);
    expect(items.first.attempts, 2);
    expect(items.first.mastered, isFalse); // fewer than 5 answers
    expect(progressItems(const LearnerProgress()), isEmpty);
  });

  testWidgets('a build without a backend has no account button',
      (tester) async {
    final progress = ProgressController(store: InMemoryProgressStore());
    await tester.pumpWidget(AbqariEduApp(
      localeController: LocaleController(store: InMemoryLocaleStore()),
      themeModeController: ThemeModeController(store: InMemoryThemeModeStore()),
      progressController: progress,
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(EduHomePage.accountButtonKey), findsNothing);
  });

  testWidgets('home shows the account button when a backend exists',
      (tester) async {
    final progress = ProgressController(store: InMemoryProgressStore());
    final account = AccountController(cloud: FakeCloud(), progress: progress);
    await account.start();
    await tester.pumpWidget(AbqariEduApp(
      localeController: LocaleController(store: InMemoryLocaleStore()),
      themeModeController: ThemeModeController(store: InMemoryThemeModeStore()),
      progressController: progress,
      accountController: account,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(EduHomePage.accountButtonKey));
    await tester.pumpAndSettle();
    expect(find.text(_ar.accountIntro), findsOneWidget);
  });

  testWidgets('wrong password, then sign-in uploads local progress',
      (tester) async {
    final cloud = FakeCloud();
    await openAccount(tester, cloud, progress: practised());
    await signIn(tester, 'nope');
    expect(find.text(_ar.errorInvalidCredentials), findsOneWidget);
    expect(cloud.isSignedIn, isFalse);

    await signIn(tester, 'right-password');
    expect(find.text('Alice'), findsOneWidget);
    expect(find.textContaining(_ar.roleStudent), findsOneWidget);
    expect(find.text(_ar.errorInvalidCredentials), findsNothing);
    expect(cloud.uploads.single.length, 2);
    expect(find.byKey(AccountKeys.joinCode), findsOneWidget);
    expect(find.byKey(AccountKeys.createClass), findsNothing);
  });

  testWidgets('empty fields are caught before any request', (tester) async {
    final cloud = FakeCloud();
    await openAccount(tester, cloud);
    await tester.tap(find.byKey(AccountKeys.submit));
    await tester.pumpAndSettle();
    expect(find.text(_ar.fieldRequired), findsNWidgets(2));
    expect(cloud.isSignedIn, isFalse);
  });

  testWidgets('sign-up waiting for email confirmation says so', (tester) async {
    final cloud = FakeCloud(confirmEmail: true);
    await openAccount(tester, cloud);
    await tester.tap(find.byKey(AccountKeys.signUpTab));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AccountKeys.displayName), 'حميد');
    await tester.enterText(find.byKey(AccountKeys.email), 'h@example.test');
    await tester.enterText(find.byKey(AccountKeys.password), 'short');
    await tester.tap(find.byKey(AccountKeys.submit));
    await tester.pumpAndSettle();
    expect(find.text(_ar.passwordTooShort), findsOneWidget);
    await tester.enterText(find.byKey(AccountKeys.password), 'long-enough-1');
    await tester.tap(find.byKey(AccountKeys.submit));
    await tester.pumpAndSettle();
    expect(find.text(_ar.confirmationSent('h@example.test')), findsOneWidget);
    expect(cloud.isSignedIn, isFalse);
  });

  testWidgets('student joins a class; a wrong code is explained',
      (tester) async {
    final cloud = FakeCloud();
    await openAccount(tester, cloud);
    await signIn(tester, 'right-password');
    await tester.enterText(find.byKey(AccountKeys.joinCode), 'zzzz9999');
    await tester.tap(find.byKey(AccountKeys.join));
    await tester.pumpAndSettle();
    expect(find.text(_ar.errorUnknownClassCode), findsOneWidget);

    await tester.enterText(find.byKey(AccountKeys.joinCode), 'abcd2345');
    await tester.tap(find.byKey(AccountKeys.join));
    await tester.pumpAndSettle();
    expect(find.text(_ar.joined('Class 7A')), findsOneWidget);
    expect(find.byKey(AccountKeys.classTile('c-Class 7A')), findsOneWidget);

    await tester.tap(find.byKey(AccountKeys.leave('c-Class 7A')));
    await tester.pumpAndSettle();
    expect(find.byKey(AccountKeys.classTile('c-Class 7A')), findsNothing);
  });

  testWidgets('teacher creates a class and sees each student\'s mastery',
      (tester) async {
    final cloud = FakeCloud(role: AccountRole.teacher)
      ..progressRows = const [
        ClassProgressRow(
            studentId: 's1',
            displayName: 'Sara',
            path: 'linear-equations',
            skill: 'one-step-add',
            mastery: 100,
            attempts: 6,
            mastered: true),
        ClassProgressRow(
            studentId: 's1',
            displayName: 'Sara',
            path: 'fractions',
            skill: 'add-fractions',
            mastery: 40,
            attempts: 3,
            mastered: false),
        ClassProgressRow(studentId: 's2', displayName: 'Omar'),
      ];
    await openAccount(tester, cloud);
    await signIn(tester, 'right-password');
    expect(find.byKey(AccountKeys.joinCode), findsNothing);
    await tester.enterText(find.byKey(AccountKeys.className), '7A');
    await tester.tap(find.byKey(AccountKeys.createClass));
    await tester.pumpAndSettle();
    expect(find.text(_ar.joinCodeIs('WXYZ6789')), findsOneWidget);

    await tester.tap(find.byKey(AccountKeys.classTile('c0')));
    await tester.pumpAndSettle();
    final total = catalog.fold<int>(0, (n, p) => n + p.skills.length);
    expect(find.text(_ar.studentsCount(2)), findsOneWidget);
    expect(find.text(_ar.masteredCount(1, total)), findsOneWidget);
    expect(find.text(_ar.noProgressYet), findsOneWidget);
    await tester.tap(find.byKey(ClassKeys.student('s1')));
    await tester.pumpAndSettle();
    expect(
        find.text(linearEquations.skills.first.title.of('ar')), findsOneWidget);
    expect(find.text(_ar.mastery(40)), findsOneWidget);

    await tester.tap(find.byKey(ClassKeys.newCode));
    await tester.pumpAndSettle();
    expect(find.text(_ar.joinCodeIs('NEWC0DE2')), findsOneWidget);
  });

  testWidgets('practice after signing in is uploaded in the background',
      (tester) async {
    final cloud = FakeCloud();
    final (_, progress) = await openAccount(tester, cloud);
    await signIn(tester, 'right-password');
    expect(cloud.uploads, isEmpty); // nothing practised yet
    await progress.record('one-step-add', true);
    await progress.record('one-step-add', true);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(cloud.uploads.length, 1);
    expect(cloud.uploads.single.single.attempts, 2);
  });

  testWidgets('an ended session returns to the sign-in form', (tester) async {
    final cloud = FakeCloud();
    await openAccount(tester, cloud);
    await signIn(tester, 'right-password');
    cloud.failNext = CloudErrorKind.signedOut;
    await tester.tap(find.byKey(AccountKeys.sync));
    await tester.pumpAndSettle();
    expect(find.text(_ar.errorSignedOut), findsOneWidget);
    expect(find.byKey(AccountKeys.submit), findsOneWidget);
  });

  testWidgets('offline sync keeps the user signed in and explains',
      (tester) async {
    final cloud = FakeCloud();
    await openAccount(tester, cloud);
    await signIn(tester, 'right-password');
    cloud.failNext = CloudErrorKind.offline;
    await tester.tap(find.byKey(AccountKeys.sync));
    await tester.pumpAndSettle();
    expect(find.text(_ar.errorOffline), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('sign out', (tester) async {
    final cloud = FakeCloud();
    await openAccount(tester, cloud);
    await signIn(tester, 'right-password');
    await tester.ensureVisible(find.byKey(AccountKeys.signOut));
    await tester.tap(find.byKey(AccountKeys.signOut));
    await tester.pumpAndSettle();
    expect(cloud.isSignedIn, isFalse);
    expect(find.byKey(AccountKeys.submit), findsOneWidget);
  });
}
