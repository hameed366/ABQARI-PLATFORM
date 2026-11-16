import 'dart:math';

import 'package:abqari_formula/abqari_formula.dart';
import 'package:abqari_learning/abqari_learning.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/edu_strings.dart';
import 'progress_controller.dart';
import 'widgets.dart';

abstract final class PracticeKeys {
  static const Key answer = ValueKey('practice-answer');
  static const Key check = ValueKey('practice-check');
  static const Key next = ValueKey('practice-next');
  static const Key solution = ValueKey('practice-solution');
  static const Key feedback = ValueKey('practice-feedback');
}

/// Endless practice: each question is new, verified by the engine, and
/// marked exactly. Correct and incorrect answers update mastery; unreadable
/// ones do not.
class PracticePage extends StatefulWidget {
  const PracticePage(
      {super.key, required this.skill, required this.progress, this.firstSeed});

  final Skill skill;
  final ProgressController progress;
  final int? firstSeed;

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  final TextEditingController _answer = TextEditingController();
  late int _seed;
  Question? _question;
  Marking? _marking;
  bool _showSolution = false;

  @override
  void initState() {
    super.initState();
    _seed = widget.firstSeed ?? Random().nextInt(1 << 30);
    _prepare();
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  void _prepare() {
    try {
      _question = makeQuestion(widget.skill, _seed);
    } on QuestionUnavailable {
      _question = null;
    }
  }

  bool get _answered => _marking?.counts ?? false;

  Future<void> _check() async {
    final question = _question;
    if (question == null || _answered) return;
    final marking = mark(question, _answer.text);
    setState(() => _marking = marking);
    if (marking.counts) {
      await widget.progress.record(widget.skill.id, marking.isCorrect);
    }
  }

  void _next() {
    setState(() {
      _seed++;
      _prepare();
      _marking = null;
      _showSolution = false;
      _answer.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = EduStrings.of(context);
    final locale = Localizations.localeOf(context);
    final language = locale.languageCode;
    final notation = Notation.forLocale(locale);
    final question = _question;
    return Scaffold(
      appBar: AppBar(title: Text(widget.skill.title.of(language))),
      body: question == null
          ? Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(strings.questionUnavailable)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListenableBuilder(
                  listenable: widget.progress,
                  builder: (context, _) {
                    final record = widget.progress.progress.of(widget.skill.id);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                            '${strings.mastery(record.masteryPercent)} · ${levelName(strings, record.level)}'),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                            value: record.masteryPercent / 100),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Section(
                  title: widget.skill.instruction.of(language),
                  child: scrollingMath(
                    MathView.statement(question.result.understood!,
                        notation: notation, fontSize: 28),
                  ),
                ),
                TextField(
                  key: PracticeKeys.answer,
                  controller: _answer,
                  enabled: !_answered,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _check(),
                  decoration: InputDecoration(
                    labelText: strings.answerLabel,
                    hintText: widget.skill.answerHint?.of(language) ??
                        strings.answerHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (!_answered) {
                  FilledButton(
                      key: PracticeKeys.check,
                      onPressed: _check,
                      child: Text(strings.checkButton))
                else
                  FilledButton.icon(
                    key: PracticeKeys.next,
                    onPressed: _next,
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(strings.nextButton),
                  ),
                if (_marking != null) ...[
                  const SizedBox(height: 16),
                  _Feedback(
                    key: PracticeKeys.feedback,
                    marking: _marking!,
                    question: question,
                    notation: notation,
                    language: language,
                    showSolution: _showSolution,
                    onShowSolution: () => setState(() => _showSolution = true),
                  ),
                ],
              ],
            ),
    );
                }
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({
    super.key,
    required this.marking,
    required this.question,
    required this.notation,
    required this.language,
    required this.showSolution,
    required this.onShowSolution,
  });

  final Marking marking;
  final Question question;
  final Notation notation;
  final String language;
  final bool showSolution;
  final VoidCallback onShowSolution;

  @override
  Widget build(BuildContext context) {
    final strings = EduStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final code = marking.messageCode;
    if (!marking.counts && marking.verdict != Verdict.wrongForm) {
      return Text(markingMessages[code]?.of(language) ?? strings.incorrect);
    }
    final ok = marking.isCorrect;
    final background = ok ? scheme.primaryContainer : scheme.errorContainer;
    final foreground = ok ? scheme.onPrimaryContainer : scheme.onErrorContainer;
    return Card(
      elevation: 0,
      color: background,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(ok ? Icons.check_circle_outline : Icons.highlight_off,
                    color: foreground),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ok
                        ? strings.correct
                        : (markingMessages[code]?.of(language) ??
                            strings.incorrect),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: foreground),
                  ),
                ),
              ],
            ),
            if (!ok) ...[
              const SizedBox(height: 10),
              Text(strings.correctAnswerIs,
                  style: TextStyle(color: foreground)),
              DefaultTextStyle.merge(
                style: TextStyle(color: foreground),
                child: AnswerView(result: question.result, notation: notation),
              ),
            ],
            if (question.result.steps.isNotEmpty) ...[
              const SizedBox(height: 8),
              if (!showSolution) {
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    key: PracticeKeys.solution,
                    onPressed: onShowSolution,
                    child: Text(strings.showSolution),
                  ),
                )
              else
                StepList(
                    steps: question.result.steps,
                    notation: notation,
                    languageCode: language),
            ],
          ],
        ),
      ),
    );
              }
  }
}
