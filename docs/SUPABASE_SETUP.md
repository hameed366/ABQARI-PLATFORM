# تشغيل الخادم على Supabase

هذه الخطوات تجعل الحسابات تعمل فعلًا. بدونها يبقى التطبيقان يعملان كاملين، لكن بلا زر حساب.

## ١. إنشاء المشروع (صاحب المشروع)
1. أنشئ حسابًا على supabase.com، ثم مشروعًا جديدًا. اختر أقرب منطقة (مثل Frankfurt أو Mumbai).
2. احفظ كلمة مرور قاعدة البيانات في مكان آمن.
3. من **Project Settings → API** انسخ:
   - **Project URL** (مثل `https://abcd.supabase.co`)
   - **anon / publishable key** — المفتاح العام، آمن داخل التطبيق.
4. **لا ترسل** مفتاح `service_role` / `secret` لأحد، ولا تضعه في التطبيق أو المستودع.

## ٢. تطبيق الهجرات
في **SQL Editor** الصق الملف المجمّع `abqari_supabase_setup.sql` (الهجرات كلها ثم الهيكل، في معاملة واحدة)، أو شغّل الملفات بالترتيب:
`backend/database/001_initial_schema.sql` ← `002` ← `003` ← `004` ← ثم `backend/database/seed/catalog.sql`.

## ٣. إعدادات المصادقة
**Authentication → Providers → Email**: مفعّل. يُنصح بإبقاء «Confirm email» مفعّلًا؛ التطبيق يخبر المستخدم بأن رسالة تأكيد أُرسلت.
**Authentication → Policies (Password)**: حد أدنى ٨ أحرف (التطبيق يطلب ٨).

## ٤. أول مدير
بعد أن تسجّل حسابك من التطبيق، شغّل في SQL Editor (مرة واحدة):
```sql
update public.user_roles set role = 'admin'
where user_id = (select id from auth.users where email = 'بريدك@example.com');
```
بعدها تستطيع ترقية المعلمين من حسابك:
```sql
select public.set_user_role('<user id>', 'teacher');
```
(واجهة إدارة الأدوار داخل التطبيق مخطط لها لاحقًا.)

## ٥. بناء التطبيق مع الخادم
العنوان والمفتاح العام محفوظان في `config/cloud.public.json`:
```
flutter build apk --release --dart-define-from-file=../../config/cloud.public.json
```
فحص حي للخادم (لا ينشئ شيئًا ولا يغيّر شيئًا): `python3 tools/cloud_smoke.py`، ويعمل تلقائيًا في GitHub (`cloud-smoke`).

## ملاحظات أمان
- كل الصلاحيات تُفرض في قاعدة البيانات (RLS والدوال)، لا في التطبيق. اختبارات `tests/db/test_access.py` تثبت ذلك على PostgreSQL.
- الجلسة تُحفظ على الجهاز في التخزين المحلي للتطبيق؛ نقلها إلى خزنة النظام (Keychain/Keystore) مخطط له قبل النشر.
