import 'package:abqari_math/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('home screen renders its title and three tiles', (tester) async {
    await tester.pumpWidget(const AbqariMathApp());
    await tester.pumpAndSettle();

    expect(find.text('عبقري رياضيات'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(3));
  });

  testWidgets('home screen is laid out right-to-left', (tester) async {
    await tester.pumpWidget(const AbqariMathApp());
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ListView));
    expect(Directionality.of(context), TextDirection.rtl);
  });

  testWidgets('app declares Arabic and English as supported locales', (tester) async {
    await tester.pumpWidget(const AbqariMathApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.supportedLocales, containsAll(const [Locale('ar'), Locale('en')]));
  });
}
