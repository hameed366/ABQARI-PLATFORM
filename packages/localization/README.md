# abqari_localization

البنية المشتركة للغتين في تطبيقَي ABQARI. لا تحتوي نصوص أي تطبيق؛ كل تطبيق يحتفظ بنصوصه في `lib/l10n/`.

- `AbqariLocales` — اللغتان المدعومتان (ar، en) واللغة الافتراضية.
- `LocaleController` — اللغة الحالية، التبديل الفوري، والحفظ.
- `LocaleStore` — واجهة الحفظ؛ `SharedPreferencesLocaleStore` للتطبيق و`InMemoryLocaleStore` للاختبارات.
- `TypedLocalizationsDelegate<T>` — يربط صنف نصوص مكتوبًا بالأنواع بنظام الترجمة في Flutter.
- `CommonStrings` و`LanguageSwitchButton` — زر تبديل اللغة ونصوصه.

اتجاه الواجهة لا يُكتب يدويًا في أي مكان: يستنتجه Flutter من اللغة.
