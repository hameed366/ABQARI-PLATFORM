import 'package:abqari_engine/abqari_engine.dart';
import 'package:abqari_formula/abqari_formula.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/math_strings.dart';

/// Notes already said by the answer itself, so they are not repeated below it.
const Set<String> _answerNotes = {
  'true_statement',
  'false_statement',
  'no_real_solutions',
  'all_real_numbers',
};

/// Shows one engine result: what was understood, then the answer, its
/// verification, the steps, and notes — or the reason there is no answer.
class ResultView extends StatelessWidget {
  const ResultView({
    super.key,
    required this.result,
    required this.notation,
    required this.languageCode,
  });

  final SolveResult result;
  final Notation notation;
  final String languageCode;

  String _say(String code) => engineMessage(code, languageCode);

  Widget _math(Widget view) =>
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: view);

  @override
  Widget build(BuildContext context) {
    final strings = MathStrings.of(context);
    final understood = result.understood;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (understood != null)
          _Section(
            title: strings.understoodTitle,
            child: _math(MathView.statement(understood, notation: notation)),
          ),
        if (result.status == SolveStatus.solved)
          ..._solved(context, strings)
        else
          _Problem(
            message: _say(result.errorCode ?? 'internal_error'),
            detail: result.errorPosition == null
                ? null
                : strings.errorAt(result.errorPosition! + 1),
          ),
      ],
    );
  }

  List<Widget> _solved(BuildContext context, MathStrings strings) {
    final answer = result.answer!;
    final verification = result.verification!;
    final notes =
        result.notes.where((code) => !_answerNotes.contains(code)).toList();
    return [
      _Section(title: strings.answerTitle, child: _answer(context, answer)),
      _VerificationBanner(
        status: verification.status,
        summary: _say('verification_${verification.status.name}'),
        detail: strings.checksPassed(
            verification.passedCount, verification.checks.length),
      ),
      if (result.steps.isNotEmpty)
        _Section(
          title: strings.stepsTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < result.steps.length; i++)
                _StepTile(
                  number: notation.number('${i + 1}'),
                  text: _say(result.steps[i].messageCode),
                  operand: result.steps[i].operand == null
                      ? null
                      : _math(MathView.expression(
                          result.steps[i].operand!,
                          notation: notation,
                          fontSize: 18,
                        )),
                  lines: [
                    for (final line in result.steps[i].lines)
                      _math(MathView.chain(line, notation: notation)),
                  ],
                ),
            ],
          ),
        ),
      if (notes.isNotEmpty)
        _Section(
          title: strings.notesTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final code in notes) Text('• ${_say(code)}')],
          ),
        ),
    ];
  }

  Widget _answer(BuildContext context, Answer answer) {
    final emphasis = Theme.of(context).textTheme.titleMedium;
    switch (answer.kind) {
      case AnswerKind.value:
        final approx =
            answer.exact!.isRational && answer.exact!.rationalValue.isInteger
                ? null
                : approximateText(answer.exact!.toDouble(), notation);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _math(MathView.expression(answer.expression!,
                notation: notation, fontSize: 26)),
            if (approx != null) Text('≈ $approx'),
          ],
        );
      case AnswerKind.truth:
        return Text(_say(answer.truth! ? 'true_statement' : 'false_statement'),
            style: emphasis);
      case AnswerKind.solutions:
        switch (answer.solutionSet!) {
          case SolutionSet.allReals:
            return Text(_say('all_real_numbers'), style: emphasis);
          case SolutionSet.none:
            return Text(_say('no_real_solutions'), style: emphasis);
          case SolutionSet.finite:
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < answer.roots.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Flexible(
                          child: _math(MathView.chain(
                            EquationChain(
                                [Var(result.variable!), answer.rootNodes[i]]),
                            notation: notation,
                            fontSize: 26,
                          )),
                        ),
                        if (!answer.roots[i].isRational) ...[
                          const SizedBox(width: 12),
                          Text(
                              '≈ ${approximateText(answer.roots[i].toDouble(), notation) ?? ''}'),
                        ],
                      ],
                    ),
                  ),
              ],
            );
        }
      case AnswerKind.expression:
        final expression = answer.constantOfIntegration
            ? Add(answer.expression!, const Sym('C'))
            : answer.expression!;
        return _math(
            MathView.expression(expression, notation: notation, fontSize: 26));
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

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

class _Problem extends StatelessWidget {
  const _Problem({required this.message, this.detail});

  final String message;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.errorContainer,
      child: ListTile(
        leading: Icon(Icons.error_outline, color: scheme.onErrorContainer),
        title: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
        subtitle: detail == null
            ? null
            : Text(detail!, style: TextStyle(color: scheme.onErrorContainer)),
      ),
    );
  }
}

class _VerificationBanner extends StatelessWidget {
  const _VerificationBanner({
    required this.status,
    required this.summary,
    required this.detail,
  });

  final VerificationStatus status;
  final String summary;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, background, foreground) = switch (status) {
      VerificationStatus.verified => (
          Icons.verified_outlined,
          scheme.primaryContainer,
          scheme.onPrimaryContainer
        ),
      VerificationStatus.partial => (
          Icons.info_outline,
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer
        ),
      VerificationStatus.failed => (
          Icons.gpp_bad_outlined,
          scheme.errorContainer,
          scheme.onErrorContainer
        ),
    };
    return Card(
      elevation: 0,
      color: background,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: foreground),
        title: Text(summary, style: TextStyle(color: foreground)),
        subtitle: Text(detail, style: TextStyle(color: foreground)),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.number,
    required this.text,
    required this.lines,
    this.operand,
  });

  final String number;
  final String text;
  final List<Widget> lines;
  final Widget? operand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            child: Text(number, style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (operand == null)
                  Text(text)
                else
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [Text(text), operand!],
                  ),
                const SizedBox(height: 6),
                ...lines,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
