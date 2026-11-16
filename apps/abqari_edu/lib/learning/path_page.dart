import 'package:abqari_learning/abqari_learning.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/edu_strings.dart';
import 'progress_controller.dart';
import 'skill_page.dart';
import 'widgets.dart';

/// The skills of one path, in order, with each one's mastery. A skill opens
/// once its prerequisites are mastered.
class PathPage extends StatelessWidget {
  const PathPage({super.key, required this.path, required this.progress});

  final LearningPath path;
  final ProgressController progress;

  @override
  Widget build(BuildContext context) {
    final strings = EduStrings.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(path.title.of(language))),
      body: ListenableBuilder(
        listenable: progress,
        builder: (context, _) {
          final learner = progress.progress;
          final next = learner.recommendedNext(path);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(path.description.of(language)),
              const SizedBox(height: 12),
              Text(strings.pathProgress(learner.pathPercent(path))),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: learner.pathPercent(path) / 100),
              const SizedBox(height: 16),
              for (final skill in path.skills)
                Builder(builder: (context) {
                  final record = learner.of(skill.id);
                  final open = learner.isUnlocked(skill);
                  return Card(
                    elevation: 0,
                    color: scheme.surfaceContainerLow,
                    child: ListTile(
                      key: ValueKey('skill-${skill.id}'),
                      enabled: open,
                      leading: Icon(
                          open ? levelIcon(record.level) : Icons.lock_outline,
                          color: open ? scheme.primary : null),
                      title: Text(skill.title.of(language)),
                      subtitle: Text(open
                          ? (identical(skill, next)
                              ? '${strings.recommended} · ${levelName(strings, record.level)}'
                              : levelName(strings, record.level))
                          : strings.lockedHint),
                      trailing: open
                          ? Icon(Icons.arrow_forward, color: scheme.primary)
                          : null,
                      onTap: open
                          ? () => Navigator.of(context)
                                  .push(MaterialPageRoute<void>(
                                builder: (_) =>
                                    SkillPage(skill: skill, progress: progress),
                              ))
                          : null,
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
