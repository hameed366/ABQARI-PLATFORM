import 'package:abqari_engine/abqari_engine.dart';
import 'package:abqari_formula/abqari_formula.dart';
import 'package:abqari_learning/abqari_learning.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/edu_strings.dart';
import 'practice_page.dart';
import 'progress_controller.dart';
import 'widgets.dart';

abstract final class SkillKeys {
  static const Key practice = ValueKey('skill-practice');
}

/// A short lesson: explanations, then examples solved live by the engine.
class SkillPage extends StatelessWidget {
  const SkillPage(
      {super.key, required this.skill, required this.progress, this.firstSeed});

  final Skill skill;
  final ProgressController progress;

  /// Fixes the first practice question (tests).
  final int? firstSeed;

  @override
  Widget build(BuildContext context) {
    final strings = EduStrings.of(context);
    final locale = Localizations.localeOf(context);
    final language = locale.languageCode;
    final notation = Notation.forLocale(locale);
    return Scaffold(
      appBar: AppBar(title: Text(skill.title.of(language))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Section(
            title: strings.lessonTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final block in skill.lesson.whereType<Explanation>())
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(block.text.of(language)),
                  ),
              ],
            ),
          ),
          for (final example in skill.lesson.whereType<WorkedExample>())
            Builder(builder: (context) {
              final result = solve(example.problem);
              if (result.status != SolveStatus.solved) {
                return const SizedBox.shrink();
              }
              return Section(
                title: strings.workedExampleTitle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ProblemView(
                        result: result,
                        instruction: skill.instruction.of(language),
                        notation: notation),
                    if (result.steps.isNotEmpty) {
                      StepList(
                          steps: result.steps,
                          notation: notation,
                          languageCode: language),
                    const SizedBox(height: 8),
                    Text(strings.correctAnswerIs,
                        style: Theme.of(context).textTheme.labelLarge),
                    AnswerView(result: result, notation: notation),
                  ],
                ),
              );
                    }
            }),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: SkillKeys.practice,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => PracticePage(
                  skill: skill, progress: progress, firstSeed: firstSeed),
            )),
            icon: const Icon(Icons.edit_note),
            label: Text(strings.practiceButton),
          ),
        ],
      ),
    );
  }
}
