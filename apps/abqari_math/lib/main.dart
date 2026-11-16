import 'package:abqari_localization/abqari_localization.dart';
import 'package:material_ui/material_ui.dart';

import 'l10n/math_strings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localeController = LocaleController(
    store: const SharedPreferencesLocaleStore(),
  );
  await localeController.load();
  runApp(AbqariMathApp(localeController: localeController));
}

class AbqariMathApp extends StatelessWidget {
  const AbqariMathApp({super.key, required this.localeController});

  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: localeController,
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
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6741A5)),
          useMaterial3: true,
        ),
        home: MathHomePage(localeController: localeController),
      ),
    );
  }
}

class MathHomePage extends StatelessWidget {
  const MathHomePage({super.key, required this.localeController});

  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    final strings = MathStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.appTitle),
        actions: [LanguageSwitchButton(controller: localeController)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            strings.headline,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(strings.tagline),
          const SizedBox(height: 24),
          _FeatureCard(
            title: strings.firstFeatureTitle,
            subtitle: strings.firstFeatureSubtitle,
          ),
          _FeatureCard(
            title: strings.secondFeatureTitle,
            subtitle: strings.secondFeatureSubtitle,
          ),
          _FeatureCard(
            title: strings.thirdFeatureTitle,
            subtitle: strings.thirdFeatureSubtitle,
          ),
        ],
      ),
    );
  }
}

/// Describes a planned capability. Deliberately not tappable and without a
/// navigation arrow: it must not look like a control until the feature exists.
class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const Icon(Icons.functions),
          title: Text(title),
          subtitle: Text(subtitle),
        ),
      );
}
