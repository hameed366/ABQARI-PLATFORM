import 'package:abqari_cloud/abqari_cloud.dart';
import 'package:abqari_learning/abqari_learning.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/edu_strings.dart';
import 'account_controller.dart';

class ClassKeys {
  static const code = ValueKey('class-code');
  static const newCode = ValueKey('class-new-code');
  static const archive = ValueKey('class-archive');
  static const error = ValueKey('class-error');

  static ValueKey<String> student(String id) => ValueKey('class-student-$id');
}

/// One student's rows from the class view, with skill titles from the catalog.
class StudentSummary {
  StudentSummary(this.id, this.name, this.skills);

  final String id;
  final String name;

  /// (skill, row) for every skill the student has uploaded progress on.
  final List<(Skill, ClassProgressRow)> skills;

  int get mastered => skills.where((s) => s.$2.mastered ?? false).length;
}

List<StudentSummary> summarize(List<ClassProgressRow> rows) {
  final skillsById = {
    for (final path in catalog)
      for (final skill in path.skills) '${path.id}/${skill.id}': skill,
  };
  final byStudent = <String, StudentSummary>{};
  for (final row in rows) {
    final summary = byStudent.putIfAbsent(row.studentId,
        () => StudentSummary(row.studentId, row.displayName, []));
    final skill = skillsById['${row.path}/${row.skill}'];
    if (skill != null) summary.skills.add((skill, row));
  }
  return byStudent.values.toList();
}

/// A teacher's view of one class: the join code and each student's mastery.
class ClassPage extends StatefulWidget {
  const ClassPage(
      {super.key, required this.controller, required this.schoolClass});

  final AccountController controller;
  final SchoolClass schoolClass;

  @override
  State<ClassPage> createState() => _ClassPageState();
}

class _ClassPageState extends State<ClassPage> {
  List<StudentSummary>? _students;
  late SchoolClass _class = widget.schoolClass;

  AccountController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await _c.classProgress(_class.id);
    if (!mounted) return;
    setState(() => _students = rows == null ? null : summarize(rows));
  }

  Future<void> _newCode() async {
    if (!await _c.regenerateJoinCode(_class.id) || !mounted) return;
    final updated = _c.classes.where((c) => c.id == _class.id);
    if (updated.isNotEmpty) setState(() => _class = updated.first);
  }

  Future<void> _archive() async {
    if (await _c.archiveClass(_class.id) && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = EduStrings.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final textTheme = Theme.of(context).textTheme;
    final total = catalog.fold<int>(0, (n, p) => n + p.skills.length);
    final students = _students;
    return Scaffold(
      appBar: AppBar(title: Text(_class.name)),
      body: ListenableBuilder(
        listenable: _c,
        builder: (context, _) => RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_c.busy) const LinearProgressIndicator(),
              if (_c.error case final kind?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    strings.cloudError(kind),
                    key: ClassKeys.error,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              Text(strings.joinCodeIs(_class.joinCode),
                  key: ClassKeys.code, style: textTheme.titleLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    key: ClassKeys.newCode,
                    onPressed: _c.busy ? null : _newCode,
                    child: Text(strings.newCodeButton),
                  ),
                  OutlinedButton(
                    key: ClassKeys.archive,
                    onPressed: _c.busy ? null : _archive,
                    child: Text(strings.archiveClassButton),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (students == null && !_c.busy && _c.error != null)
                const SizedBox.shrink()
              else if (students == null)
                const Center(child: CircularProgressIndicator())
              else if (students.isEmpty)
                Text(strings.noStudents)
              else ...[
                Text(strings.studentsCount(students.length),
                    style: textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final s in students)
                  Card(
                    child: ExpansionTile(
                      key: ClassKeys.student(s.id),
                      title: Text(s.name),
                      subtitle: Text(s.skills.isEmpty
                          ? strings.noProgressYet
                          : strings.masteredCount(s.mastered, total)),
                      children: [
                        for (final (skill, row) in s.skills)
                          ListTile(
                            dense: true,
                            leading: Icon((row.mastered ?? false)
                                ? Icons.verified_outlined
                                : Icons.trending_up),
                            title: Text(skill.title.of(language)),
                            trailing: Text(strings.mastery(row.mastery ?? 0)),
                          ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
