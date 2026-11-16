import 'package:abqari_engine/abqari_engine.dart';
import 'package:abqari_formula/abqari_formula.dart';
import 'package:abqari_learning/abqari_learning.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/edu_strings.dart';

Widget scrollingMath(Widget view) =>
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: view);

String levelName(EduStrings strings, MasteryLevel level) => switch (level) {
      MasteryLevel.notStarted => strings.levelNotStarted,
      MasteryLevel.learning => strings.levelLearning,
      MasteryLevel.practising => strings.levelPractising,
      MasteryLevel.mastered => strings.levelMastered,
    };

IconData levelIcon(MasteryLevel level) => switch (level) {
      MasteryLevel.notStarted => Icons.radio_button_unchecked,
      MasteryLevel.learning => Icons.timelapse,
      MasteryLevel.practising => Icons.trending_up,
      MasteryLevel.mastered => Icons.verified,
    };

/// The engine's solution steps, numbered in the interface digits.
class StepList extends StatelessWidget {
  const StepList(
      {super.key,
      required this.steps,
      required this.notation,
      required this.languageCode});

  final List<SolutionStep> steps;
  final Notation notation;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  child: Text(notation.number('${i + 1}'),
                      style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(engineMessage(
                              steps[i].messageCode, languageCode)),
                          if (steps[i].operand != null)
                            MathView.expression(steps[i].operand!,
                                notation: notation, fontSize: 18),
                        ],
                      ),
                      for (final line in steps[i].lines)
                        scrollingMath(MathView.chain(line, notation: notation)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The answer the engine found, in the form the skill asks for.
class AnswerView extends StatelessWidget {
  const AnswerView({super.key, required this.result, required this.notation});

  final SolveResult result;
  final Notation notation;

  @override
  Widget build(BuildContext context) {
    final answer = result.answer!;
    if (answer.kind == AnswerKind.solutions) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final node in answer.rootNodes)
            scrollingMath(MathView.chain(
              EquationChain([Var(result.variable ?? 'x'), node]),
              notation: notation,
              fontSize: 24,
            )),
        ],
      );
    }
    return scrollingMath(MathView.expression(answer.expression!,
        notation: notation, fontSize: 24));
  }
}

class Section extends StatelessWidget {
  const Section({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: scheme.primary)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

/// The problem with its instruction above it.
class ProblemView extends StatelessWidget {
  const ProblemView(
      {super.key,
      required this.result,
      required this.instruction,
      required this.notation});

  final SolveResult result;
  final String instruction;
  final Notation notation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(instruction, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        scrollingMath(MathView.statement(result.understood!,
            notation: notation, fontSize: 26)),
      ],
    );
  }
}
