import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() => runApp(const AbqariEduApp());

class AbqariEduApp extends StatelessWidget {
  const AbqariEduApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ABQARI EDU',
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      locale: const Locale('ar'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2457A6)),
        useMaterial3: true,
      ),
      home: const EduHomePage(),
    );
  }
}

class EduHomePage extends StatelessWidget {
  const EduHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('عبقري التعليمي')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            Text('تعلّم الرياضيات بطريقتك',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('مسارات عامة مبنية على الموضوع والمهارة ومستوى الإتقان.'),
            SizedBox(height: 24),
            _FeatureTile(title: 'ابدأ مسار تعلّم', subtitle: 'اختر مجالاً وموضوعاً يناسب مستواك'),
            _FeatureTile(title: 'تدرّب واختبر نفسك', subtitle: 'أسئلة متدرجة مع تغذية راجعة'),
            _FeatureTile(title: 'تابع تقدّمك', subtitle: 'اعرف المهارات التي أتقنتها وما يحتاج إلى مراجعة'),
          ],
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const Icon(Icons.auto_stories_outlined),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_left),
        ),
      );
}
