import 'package:abqari_engine/abqari_engine.dart';
import 'package:abqari_formula/abqari_formula.dart';
import 'package:abqari_localization/abqari_localization.dart';
import 'package:abqari_ui/abqari_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/math_strings.dart';
import 'result_view.dart';

abstract final class SolverKeys {
  static const Key input = ValueKey('solver-input');
  static const Key solve = ValueKey('solver-solve');
  static const Key result = ValueKey('solver-result');
}

/// Type a problem, see what was understood, the answer, its steps, and how
/// far it was verified. Everything runs on the device.
class SolverPage extends StatefulWidget {
  const SolverPage({
    super.key,
    required this.localeController,
    required this.themeModeController,
  });

  final LocaleController localeController;
  final ThemeModeController themeModeController;

  @override
  State<SolverPage> createState() => _SolverPageState();
}

class _SolverPageState extends State<SolverPage> {
  final TextEditingController _input = TextEditingController();
  SolveResult? _result;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _solve() {
    final text = _input.text;
    SolveResult result;
    try {
      result = solve(text);
    } catch (error, stack) {
      // A bug in the engine must never take the app down or show a guess.
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'abqari_math solver',
      ));
      result = SolveResult(
        status: SolveStatus.unsupported,
        input: text,
        errorCode: 'internal_error',
      );
    }
    setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    final strings = MathStrings.of(context);
    final common = CommonStrings.of(context);
    final locale = Localizations.localeOf(context);
    final result = _result;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.solverTitle),
        actions: [
          ThemeModeButton(
            controller: widget.themeModeController,
            tooltip: common.switchAppearanceTooltip,
          ),
          LanguageSwitchButton(controller: widget.localeController),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: SolverKeys.input,
              controller: _input,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _solve(),
              decoration: InputDecoration(
                labelText: strings.inputLabel,
                hintText: strings.inputHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: SolverKeys.solve,
              onPressed: _solve,
              icon: const Icon(Icons.calculate_outlined),
              label: Text(strings.solveButton),
            ),
            const SizedBox(height: 16),
            Text(strings.examplesTitle,
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final example in strings.examples)
                  ActionChip(
                    label: Text(example),
                    onPressed: () {
                      _input.text = example;
                      _solve();
                    },
                  ),
              ],
            ),
            if (result != null) ...[
              const SizedBox(height: 20),
              ResultView(
                key: SolverKeys.result,
                result: result,
                notation: Notation.forLocale(locale),
                languageCode: locale.languageCode,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
