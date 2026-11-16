import 'package:abqari_learning/abqari_learning.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where a learner's progress is kept between launches.
abstract interface class ProgressStore {
  Future<String?> read();

  Future<void> write(String data);
}

/// For tests.
class InMemoryProgressStore implements ProgressStore {
  InMemoryProgressStore([this.data]);

  String? data;

  @override
  Future<String?> read() async => data;

  @override
  Future<void> write(String data) async => this.data = data;
}

/// On the device. (With an account, AccountController also uploads it.)
class SharedPreferencesProgressStore implements ProgressStore {
  const SharedPreferencesProgressStore({this.key = 'abqari.edu.progress'});

  final String key;

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String data) async =>
      (await SharedPreferences.getInstance()).setString(key, data);
}

/// The learner's progress, saved after every counted answer.
class ProgressController extends ChangeNotifier {
  ProgressController({required ProgressStore store}) : _store = store;

  final ProgressStore _store;
  LearnerProgress _progress = const LearnerProgress();

  LearnerProgress get progress => _progress;

  Future<void> load() async {
    try {
      _progress = LearnerProgress.decode(await _store.read());
      notifyListeners();
    } catch (error, stack) {
      _report(error, stack, 'while loading progress');
    }
  }

  Future<void> record(String skillId, bool isCorrect) async {
    _progress = _progress.record(skillId, isCorrect);
    notifyListeners();
    try {
      await _store.write(_progress.encode());
    } catch (error, stack) {
      _report(error, stack, 'while saving progress');
    }
  }

  void _report(Object error, StackTrace stack, String context) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'abqari_edu progress',
      context: ErrorDescription(context),
    ));
  }
}
