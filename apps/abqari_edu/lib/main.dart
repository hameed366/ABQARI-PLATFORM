import 'package:abqari_localization/abqari_localization.dart';
import 'package:material_ui/material_ui.dart';

import 'l10n/edu_strings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localeController = LocaleController(
    store: const SharedPreferencesLocaleStore(),
  );
  await localeController.load();
  runApp(AbqariEduApp(localeController: localeController));
}

class AbqariEduApp extends StatelessWidget {
  const AbqariEduApp({super.key, required this.localeController});

  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: localeController,
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
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2457A6)),
          useMaterial3: true,
        ),
        home: EduHomePage(localeController: localeController),
      ),
    );
  }
}

class EduHomePage extends StatelessWidget {
  const EduHomePage({super.key, required this.localeController});

  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    final strings = EduStrings.of(context);
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
          leading: const Icon(Icons.auto_stories_outlined),
          title: Text(title),
          subtitle: Text(subtitle),
        ),
      );
}
