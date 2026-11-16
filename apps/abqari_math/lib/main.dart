import 'package:abqari_localization/abqari_localization.dart';
import 'package:abqari_ui/abqari_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'l10n/math_strings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localeController = LocaleController(
    store: const SharedPreferencesLocaleStore(),
  );
  final themeModeController = ThemeModeController(
    store: const SharedPreferencesThemeModeStore(),
  );
  await Future.wait([localeController.load(), themeModeController.load()]);
  runApp(
    AbqariMathApp(
      localeController: localeController,
      themeModeController: themeModeController,
    ),
  );
}

class AbqariMathApp extends StatelessWidget {
  const AbqariMathApp({
    super.key,
    required this.localeController,
    required this.themeModeController,
  });

  final LocaleController localeController;
  final ThemeModeController themeModeController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([localeController, themeModeController]),
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        onGenerateTitle: (context) => MathStrings.of(context).appTitle,
        locale: localeController.locale,
        supportedLocales: AbqariLocales.supported,
        localizationsDelegates: [
          MathStrings.delegate,
          CommonStrings.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: AbqariTheme.light(AbqariProduct.math),
        darkTheme: AbqariTheme.dark(AbqariProduct.math),
        themeMode: themeModeController.mode,
        home: MathHomePage(
          localeController: localeController,
          themeModeController: themeModeController,
        ),
      ),
    );
  }
}

class MathHomePage extends StatelessWidget {
  const MathHomePage({
    super.key,
    required this.localeController,
    required this.themeModeController,
  });

  final LocaleController localeController;
  final ThemeModeController themeModeController;

  @override
  Widget build(BuildContext context) {
    final strings = MathStrings.of(context);
    final common = CommonStrings.of(context);
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
      body: ListView(
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
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(strings.tagline, style: textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FeatureCard(
            icon: Icons.calculate_outlined,
            title: strings.firstFeatureTitle,
            subtitle: strings.firstFeatureSubtitle,
          ),
          FeatureCard(
            icon: Icons.category_outlined,
            title: strings.secondFeatureTitle,
            subtitle: strings.secondFeatureSubtitle,
          ),
          FeatureCard(
            icon: Icons.functions,
            title: strings.thirdFeatureTitle,
            subtitle: strings.thirdFeatureSubtitle,
          ),
        ],
      ),
    );
  }
}
