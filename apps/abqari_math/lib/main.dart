import 'package:material_ui/material_ui.dart';

void main() => runApp(const AbqariMathApp());

class AbqariMathApp extends StatelessWidget {
  const AbqariMathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ABQARI MATH',
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      locale: const Locale('ar'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6741A5)),
        useMaterial3: true,
      ),
      home: const MathHomePage(),
    );
  }
}

class MathHomePage extends StatelessWidget {
  const MathHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('عبقري رياضيات')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            Text('مساحتك الرياضية الشاملة',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('أدخل مسألة، افهم خطواتها، وتحقق من الحل.'),
            SizedBox(height: 24),
            _MathToolTile(title: 'حل المسائل', subtitle: 'حساب، جبر، معادلات ومتباينات'),
            _MathToolTile(title: 'الهندسة والرسوم', subtitle: 'أشكال، قياسات وتمثيل بياني'),
            _MathToolTile(title: 'الرياضيات المتقدمة', subtitle: 'تفاضل وتكامل، إحصاء وجبر خطي'),
          ],
        ),
      ),
    );
  }
}

class _MathToolTile extends StatelessWidget {
  const _MathToolTile({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const Icon(Icons.functions),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_left),
        ),
      );
}
