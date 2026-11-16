import 'package:abqari_learning/abqari_learning.dart';
import 'package:abqari_localization/abqari_localization.dart';
import 'package:abqari_ui/abqari_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'l10n/edu_strings.dart';
import 'learning/path_page.dart';
import 'learning/progress_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localeController = LocaleController(
    store: const SharedPreferencesLocaleStore(),
  );
  final themeModeController = ThemeModeController(
    store: const SharedPreferencesThemeModeStore(),
  );
  final progressController = ProgressController(
    store: const SharedPreferencesProgressStore(),
  );
  await Future.wait([
    localeController.load(),
    themeModeController.load(),
    progressController.load(),
  ]);
  runApp(
    AbqariEduApp(
      localeController: localeController,
      themeModeController: themeModeController,
      progressController: progressController,
    ),
  );
}

class AbqariEduApp extends StatelessWidget {
  const AbqariEduApp({
    super.key,
    required this.localeController,
    required this.themeModeController,
    required this.progressController,
  });

  final LocaleController localeController;
  final ThemeModeController themeModeController;
  final ProgressController progressController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([localeController, themeModeController]),
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        onGenerateTitle: (context) => EduStrings.of(context).appTitle,
        locale: localeController.locale,
        supportedLocales: AbqariLocales.supported,
        localizationsDelegates: [
          EduStrings.delegate,
          CommonStrings.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: AbqariTheme.light(AbqariProduct.edu),
        darkTheme: AbqariTheme.dark(AbqariProduct.edu),
        themeMode: themeModeController.mode,
        home: EduHomePage(
          localeController: localeController,
          themeModeController: themeModeController,
          progressController: progressController,
        ),
      ),
    );
  }
}

class EduHomePage extends StatelessWidget {
  const EduHomePage({
    super.key,
    required this.localeController,
    required this.themeModeController,
    required this.progressController,
  });

  final LocaleController localeController;
  final ThemeModeController themeModeController;
  final ProgressController progressController;

  static const Map<String, IconData> _icons = {
    'linear-equations': Icons.balance,
    'fractions': Icons.pie_chart_outline,
    'quadratics': Icons.functions,
  };

  @override
  Widget build(BuildContext context) {
    final strings = EduStrings.of(context);
    final common = CommonStrings.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.appTitle),
        actions: [
          ThemeModeButton(
            controller: themeModeController,
            tooltip: common.switchAppearanceTooltip,
          ),
          LanguageSwitchButton(controller: localeController),
        ],
      ),
      body: ListenableBuilder(
        listenable: progressController,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                const AbqariLogo(size: 64),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.headline,
                        style: textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(strings.tagline, style: textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(strings.pathsTitle, style: textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final path in catalog)
              FeatureCard(
                key: ValueKey('path-${path.id}'),
                icon: _icons[path.id] ?? Icons.route_outlined,
                title: path.title.of(language),
                subtitle: '${path.description.of(language)}\n'
                    '${strings.pathProgress(progressController.progress.pathPercent(path))}',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        PathPage(path: path, progress: progressController),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
