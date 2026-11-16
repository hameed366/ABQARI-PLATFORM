import 'dart:async';

import 'package:abqari_cloud/abqari_cloud.dart';
import 'package:abqari_learning/abqari_learning.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../learning/progress_controller.dart';

/// Keeps the session on the device between launches.
class SharedPreferencesSessionStore implements SessionStore {
  const SharedPreferencesSessionStore({this.key = 'abqari.edu.session'});

  final String key;

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String data) async =>
      (await SharedPreferences.getInstance()).setString(key, data);

  @override
  Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(key);
}

/// The learner's local progress as upload items: every skill tried at least once.
List<ProgressItem> progressItems(LearnerProgress progress) => [
      for (final path in catalog)
        for (final skill in path.skills)
          if (progress.of(skill.id).attempts > 0)
            ProgressItem(
              path: path.id,
              skill: skill.id,
              mastery: progress.of(skill.id).masteryPercent,
              attempts: progress.of(skill.id).attempts,
              mastered: progress.of(skill.id).level == MasteryLevel.mastered,
            ),
    ];

enum AccountStatus { starting, signedOut, signedIn }

/// The optional account: sign-in state, the user's classes, and keeping the
/// server's copy of progress up to date. Every call reports failure through
/// [error] (a kind the UI turns into a message) instead of throwing.
class AccountController extends ChangeNotifier {
  AccountController({
    required CloudService cloud,
    required ProgressController progress,
    this.syncDelay = const Duration(seconds: 4),
  })  : _cloud = cloud,
        _progress = progress {
    _progress.addListener(_progressChanged);
  }

  final CloudService _cloud;
  final ProgressController _progress;

  /// After practice, wait this long for more answers before uploading.
  final Duration syncDelay;

  AccountStatus _status = AccountStatus.starting;
  Account? _account;
  List<SchoolClass> _classes = const [];
  bool _busy = false;
  CloudErrorKind? _error;
  DateTime? _lastSync;
  Timer? _syncTimer;

  AccountStatus get status => _status;
  Account? get account => _account;
  List<SchoolClass> get classes => _classes;
  bool get busy => _busy;
  CloudErrorKind? get error => _error;
  DateTime? get lastSync => _lastSync;

  CloudService get cloud => _cloud;

  Future<void> start() async {
    try {
      final account = await _cloud.restore();
      if (account == null) {
        _status = AccountStatus.signedOut;
      } else {
        _account = account;
        _status = AccountStatus.signedIn;
        unawaited(_afterSignIn());
      }
    } on CloudException catch (e) {
      // Offline at launch: stay signed out in the UI for now; the saved
      // session is kept and used next time.
      _status = _cloud.isSignedIn ? AccountStatus.signedIn : AccountStatus.signedOut;
      _error = e.kind;
    }
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) => _run(() async {
        _account = await _cloud.signIn(email, password);
        _status = AccountStatus.signedIn;
        await _afterSignIn();
      });

  /// Returns the result, or null when sign-up failed (see [error]).
  Future<SignUpResult?> signUp({
    required String email,
    required String password,
    required String displayName,
    required String locale,
  }) async {
    SignUpResult? result;
    await _run(() async {
      result = await _cloud.signUp(
          email: email, password: password, displayName: displayName, locale: locale);
      if (result case SignedUp(:final account)) {
        _account = account;
        _status = AccountStatus.signedIn;
        await _afterSignIn();
      }
    });
    return result;
  }

  Future<void> signOut() async {
    _syncTimer?.cancel();
    await _run(() async {
      await _cloud.signOut();
    });
    _account = null;
    _classes = const [];
    _lastSync = null;
    _status = AccountStatus.signedOut;
    notifyListeners();
  }

  /// Uploads local progress now. Returns false on failure.
  Future<bool> syncNow() => _run(_sync);

  Future<bool> refreshClasses() => _run(() async {
        _classes = await _cloud.classes();
      });

  Future<SchoolClass?> joinClass(String code) async {
    SchoolClass? joined;
    await _run(() async {
      joined = await _cloud.joinClass(code);
      await _sync();
      _classes = await _cloud.classes();
    });
    return joined;
  }

  Future<SchoolClass?> createClass(String name) async {
    SchoolClass? created;
    await _run(() async {
      created = await _cloud.createClass(name);
      _classes = await _cloud.classes();
    });
    return created;
  }

  Future<bool> leaveClass(String classId) => _run(() async {
        await _cloud.leaveClass(classId);
        _classes = await _cloud.classes();
      });

  Future<bool> archiveClass(String classId) => _run(() async {
        await _cloud.archiveClass(classId);
        _classes = await _cloud.classes();
      });

  Future<bool> regenerateJoinCode(String classId) => _run(() async {
        await _cloud.regenerateJoinCode(classId);
        _classes = await _cloud.classes();
      });

  /// For the teacher's class page. Null on failure (see [error]).
  Future<List<ClassProgressRow>?> classProgress(String classId) async {
    List<ClassProgressRow>? rows;
    await _run(() async {
      rows = await _cloud.classProgress(classId);
    });
    return rows;
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<void> _afterSignIn() async {
    await _sync();
    _classes = await _cloud.classes();
  }

  Future<void> _sync() async {
    final items = progressItems(_progress.progress);
    if (items.isNotEmpty) await _cloud.syncProgress(items);
    _lastSync = DateTime.now();
  }

  void _progressChanged() {
    if (_status != AccountStatus.signedIn) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(syncDelay, () async {
      try {
        await _sync();
        notifyListeners();
      } on CloudException {
        // Background upload: the next answer or a manual sync tries again.
      }
    });
  }

  Future<bool> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on CloudException catch (e) {
      _error = e.kind;
      if (e.kind == CloudErrorKind.signedOut) {
        _account = null;
        _classes = const [];
        _status = AccountStatus.signedOut;
      }
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _progress.removeListener(_progressChanged);
    super.dispose();
  }
}
