# Backend

الخادم المختار: **Supabase** (قرار صاحب المشروع، المرحلة 8). الهجرات جاهزة ومختبرة، لكنها **لم تُطبَّق على أي مشروع حي بعد**. خطوات التشغيل في `docs/SUPABASE_SETUP.md`.

## متطلبات التنفيذ
- API موثق ومتحقق من المدخلات.
- مصادقة وأدوار: student / teacher / admin.
- سياسات وصول واختبارات عزل بيانات.
- حفظ مفاتيح مزود الذكاء الاصطناعي على الخادم فقط.
- سجل تدقيق لا يحتوي على أسرار أو بيانات حساسة غير لازمة.

لا تضف مفاتيح حقيقية إلى المستودع. أضف `.env.example` بقيم وهمية فقط عند الحاجة.

## الهجرات
- `database/001_initial_schema.sql` — الجداول الأولية؛ RLS مفعّل دون سياسات (المنع هو الأصل).
- `database/002_integrity_hardening.sql` — قيود إضافية، فهرس، وتحديث تلقائي لـ`updated_at`.
- `database/003_roles_and_archiving.sql` — الأدوار في جدول `user_roles` المستقل؛ أرشفة المحتوى بدل حذفه. تغيّر كائنات من 001.

- `database/004_accounts_classes_policies.sql` — الحسابات (ملف شخصي ودور «طالب» تلقائيًا عند التسجيل)، والصفوف ورموز الانضمام، وأول سياسات الوصول، ودوال: `join_class`، `sync_progress`، `class_progress`، `set_user_role`، `regenerate_join_code`.
- `database/seed/catalog.sql` — هيكل المحتوى (مجال ← مسار ← مهارة)، يُولَّد من `packages/learning_core` بالأداة `tools/generate_catalog_seed.py`. اختبار يفشل إن اختلفا.

تُختبر الهجرات في `tests/db/` على PostgreSQL عادي مع بديل محلي لأدوار الواجهة. لم تُطبَّق على أي قاعدة حية.

## محرك الرياضيات
`math_solver/` — مكتبة Python (`abqari_solver`) للحل والتحقق. راجع `math_solver/README.md`. غير موصولة بأي خادم بعد.
