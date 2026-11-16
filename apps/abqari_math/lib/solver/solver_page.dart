import 'package:abqari_bridge/abqari_bridge.dart';
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
  static const Key working = ValueKey('solver-working');
}

/// Type a problem, see what was understood, the answer, its steps, and how
/// far it was verified.
///
/// The fast on-device core answers first. Only what it declines with
/// [needsFullEngine] goes to the full engine, which also runs on the device.
class SolverPage extends StatefulWidget {
  const SolverPage({
    super.key,
    required this.localeController,
    required this.themeModeController,
    this.fullEngine,
  });

  final LocaleController localeController;
  final ThemeModeController themeModeController;
  final FullEngine? fullEngine;

  @override
  State<SolverPage> createState() => _SolverPageState();
}

class _SolverPageState extends State<SolverPage> {
  final TextEditingController _input = TextEditingController();
  SolveResult? _result;
  bool _fromFullEngine = false;
  bool _fullEngineFailed = false;
  bool _working = false;
  int _request = 0;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  SolveResult _solveOnDevice(String text) {
    try {
      return solve(text);
    } catch (error, stack) {
      // A bug in the engine must never take the app down or show a guess.
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'abqari_math solver',
      ));
      return SolveResult(
        status: SolveStatus.unsupported,
        input: text,
        errorCode: 'internal_error',
      );
    }
  }

  Future<void> _solve() async {
    final text = _input.text;
    final request = ++_request;
    final local = _solveOnDevice(text);
    final engine = widget.fullEngine;
    final needsFull = local.status == SolveStatus.unsupported &&
        local.errorCode == needsFullEngine &&
        engine != null;
    setState(() {
      _result = local;
      _fromFullEngine = false;
      _fullEngineFailed = false;
      _working = needsFull;
    });
    if (!needsFull) return;

    SolveResult? full;
    try {
      full = await engine.solve(text);
    } on FullEngineUnavailable {
      full = null;
    }
    if (!mounted || request != _request) return; // a newer problem was asked
    setState(() {
      _working = false;
      if (full != null) {
        _result = full;
        _fromFullEngine = true;
      } else {
        _fullEngineFailed = true;
      }
    });
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
            if (_working) ...[
              const SizedBox(height: 20),
              Row(
                key: SolverKeys.working,
                children: [
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(strings.fullEngineWorking)),
                ],
              ),
            ] else if (result != null) ...[
              const SizedBox(height: 20),
              if (_fullEngineFailed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(strings.fullEngineUnavailable),
                ),
              ResultView(
                key: SolverKeys.result,
                result: result,
                notation: Notation.forLocale(locale),
                languageCode: locale.languageCode,
                fromFullEngine: _fromFullEngine,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
