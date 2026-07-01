# السجل الزراعي — دليل التشغيل

## المشروع يعمل بـ ملف HTML واحد فقط — لا يحتاج npm أو تثبيت

---

## الخطوة 1: إعداد Supabase (مرة واحدة فقط)

1. افتح https://supabase.com وأنشئ حساباً ومشروعاً جديداً
2. من القائمة: **SQL Editor** → أنشئ استعلاماً جديداً
3. الصق محتوى `sql/0001_init_schema.sql` ← اضغط **Run**
4. الصق محتوى `sql/0002_security_rls.sql` ← اضغط **Run**
5. من **Authentication → Users** ← أضف أول مستخدم (Add User)
   - هذا المستخدم سيكون **admin** تلقائياً
6. من **Project Settings → API** انسخ:
   - **Project URL**
   - **anon / public key**

---

## الخطوة 2: فتح التطبيق

- افتح ملف `index.html` مباشرة في المتصفح
- في أول مرة ستظهر شاشة إعداد — الصق URL و Key اللي نسختهم
- البيانات تُحفظ في المتصفح تلقائياً (لن تُطلب مرة ثانية)
- سجّل الدخول بالبريد وكلمة المرور اللي أنشأتهم في Supabase

---

## الخطوة 3: رفع على GitHub + Netlify (اختياري)

### GitHub
```bash
git init
git add .
git commit -m "السجل الزراعي v1"
git branch -M main
git remote add origin https://github.com/USERNAME/REPO.git
git push -u origin main
```

### Netlify
1. Add new site → Import from GitHub
2. Build command: ← اتركه **فارغاً**
3. Publish directory: اكتب `.` (نقطة واحدة)
4. Deploy — لا توجد متغيرات بيئة مطلوبة

---

## الأدوار

| الدور   | الصلاحية                              |
|---------|---------------------------------------|
| admin   | قراءة + كتابة + حذف + إدارة المستخدمين |
| manager | قراءة + كتابة (بدون حذف)             |
| viewer  | قراءة فقط                            |

لتغيير دور مستخدم:
```sql
UPDATE user_roles SET role = 'manager' WHERE user_id = 'UUID_هنا';
```

---

## ملاحظة أمان

- بيانات Supabase (URL و Key) تُخزَّن في `localStorage` في المتصفح
- مناسب للبيئات الداخلية والشبكات الخاصة
- للنشر العام: استخدم متغيرات البيئة (نسخة React+Vite)
