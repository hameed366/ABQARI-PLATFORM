import 'dart:math' as math;

import 'package:abqari_ui/abqari_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// WCAG 2 contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final product in AbqariProduct.values) {
    for (final brightness in Brightness.values) {
      final theme = brightness == Brightness.light
          ? AbqariTheme.light(product)
          : AbqariTheme.dark(product);
      final scheme = theme.colorScheme;
      final name = '${product.name} ${brightness.name}';

      test('$name: theme reports the requested brightness', () {
        expect(theme.brightness, brightness);
        expect(scheme.brightness, brightness);
        expect(theme.scaffoldBackgroundColor, scheme.surface);
      });

      test('$name: text and icon pairs meet WCAG AA contrast (4.5:1)', () {
        final pairs = <String, (Color, Color)>{
          'onPrimary/primary': (scheme.onPrimary, scheme.primary),
          'onSecondary/secondary': (scheme.onSecondary, scheme.secondary),
          'onSurface/surface': (scheme.onSurface, scheme.surface),
          'onSurface/card': (scheme.onSurface, scheme.surfaceContainerLow),
          'primary/surface': (scheme.primary, scheme.surface),
          'primary/card': (scheme.primary, scheme.surfaceContainerLow),
        };
        for (final entry in pairs.entries) {
          final ratio = _contrast(entry.value.$1, entry.value.$2);
          expect(ratio, greaterThanOrEqualTo(4.5), reason: '${entry.key} = $ratio');
        }
      });
    }
  }

  test('the two apps share surfaces but lead with different colours', () {
    for (final build in [AbqariTheme.light, AbqariTheme.dark]) {
      final edu = build(AbqariProduct.edu).colorScheme;
      final mathApp = build(AbqariProduct.math).colorScheme;
      expect(edu.surface, mathApp.surface);
      expect(edu.onSurface, mathApp.onSurface);
      expect(edu.primary, isNot(mathApp.primary));
      expect(edu.primary, mathApp.secondary);
    }
  });

  test('light themes lead with the brand blue and violet', () {
    expect(AbqariTheme.light(AbqariProduct.edu).colorScheme.primary, AbqariColors.blue);
    expect(AbqariTheme.light(AbqariProduct.math).colorScheme.primary, AbqariColors.violet);
    expect(AbqariTheme.light(AbqariProduct.edu).colorScheme.onSurface, AbqariColors.navy);
  });
}
