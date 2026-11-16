import 'dart:ui';

/// The ABQARI palette: deep navy, blue, violet, and one luminous accent.
abstract final class AbqariColors {
  static const Color navy = Color(0xFF0B1F4B);
  static const Color blue = Color(0xFF2457A6);
  static const Color violet = Color(0xFF6741A5);

  /// The single "glow" accent. Use sparingly: highlights, the logo spark.
  static const Color glow = Color(0xFF7FE3FF);

  /// Lighter tints of blue and violet, readable on dark surfaces.
  static const Color blueOnDark = Color(0xFFA9C7FF);
  static const Color violetOnDark = Color(0xFFD3BBFF);

  static const Color lightSurface = Color(0xFFF6F8FD);
  static const Color darkSurface = Color(0xFF0A1330);
  static const Color darkSurfaceRaised = Color(0xFF14204A);
}
