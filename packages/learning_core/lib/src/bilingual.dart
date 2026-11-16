/// A text in both interface languages.
class Bilingual {
  const Bilingual(this.ar, this.en);

  final String ar;
  final String en;

  String of(String languageCode) => languageCode == 'ar' ? ar : en;
}
