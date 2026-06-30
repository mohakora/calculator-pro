-- ============================================================
-- إنشاء / تحديث بيانات حساب الأدمن
-- نفّذ هذا الملف من Supabase Studio -> SQL Editor -> New query
-- آمن لإعادة التشغيل أكثر من مرة (Idempotent)
-- يتطلب تنفيذ supabase_schema.sql أولاً (لإنشاء جدول profiles وعمود is_admin)
-- ============================================================


-- ============================================================
-- الطريقة 1 (المُوصى بها): ترقية حساب موجود بالفعل إلى أدمن
-- ------------------------------------------------------------
-- سجّل أولاً حسابًا عاديًا من صفحة الموقع (index.html -> تبويب "حساب جديد")
-- بنفس البريد اللي هتحطه تحت، ثم شغّل السطر ده فقط لتحويله لأدمن:
-- ============================================================

update public.profiles
set is_admin = true
where email = 'admin@example.com';   -- غيّر البريد هنا لبريد الحساب اللي سجّلته فعلاً


-- ============================================================
-- الطريقة 2: إنشاء حساب الأدمن بالكامل من SQL مباشرة (بدون المرور
-- بنموذج التسجيل في الموقع إطلاقًا). يكتب المستخدم مباشرة في
-- auth.users + auth.identities ثم ينشئ صف الـ profile المرتبط به.
-- ⚠️ هذه طريقة غير رسمية لكنها شائعة الاستخدام؛ إن واجهت أي خطأ
-- معها استخدم الطريقة 1 فهي أبسط وأضمن.
-- ============================================================

create extension if not exists pgcrypto;

do $$
declare
  admin_email    text := 'admin@example.com';     -- عدّل البريد
  admin_password text := 'ChangeThisPassword123';  -- عدّل كلمة المرور (6 أحرف فأكثر)
  admin_name     text := 'مدير النظام';            -- عدّل الاسم
  admin_phone    text := '0100000000';             -- عدّل رقم الجوال
  admin_id       uuid;
begin
  -- هل المستخدم موجود مسبقاً في auth.users بنفس البريد؟
  select id into admin_id from auth.users where email = admin_email;

  if admin_id is null then
    admin_id := gen_random_uuid();

    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at, confirmation_token, recovery_token,
      email_change_token_new, email_change
    ) values (
      '00000000-0000-0000-0000-000000000000',
      admin_id, 'authenticated', 'authenticated', admin_email,
      crypt(admin_password, gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}',
      jsonb_build_object('full_name', admin_name, 'phone', admin_phone),
      now(), now(), '', '', '', ''
    );

    insert into auth.identities (
      id, user_id, provider_id, identity_data, provider,
      last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), admin_id, admin_id::text,
      jsonb_build_object('sub', admin_id::text, 'email', admin_email),
      'email', now(), now(), now()
    );
  else
    -- المستخدم موجود بالفعل: حدّث كلمة المرور لنفس القيمة المحددة أعلاه
    update auth.users
    set encrypted_password = crypt(admin_password, gen_salt('bf'))
    where id = admin_id;
  end if;

  -- إنشاء/تحديث صف الـ profile وتفعيل صلاحية الأدمن
  insert into public.profiles (id, full_name, phone, email, is_admin)
  values (admin_id, admin_name, admin_phone, admin_email, true)
  on conflict (id) do update
    set full_name = excluded.full_name,
        phone     = excluded.phone,
        email     = excluded.email,
        is_admin  = true;
end $$;

-- ============================================================
-- بعد التنفيذ: سجّل دخول من index.html بنفس البريد وكلمة المرور
-- اللي حددتهم فوق. تقدر تتأكد إن الحساب أدمن بتشغيل:
--   select email, is_admin from public.profiles where is_admin = true;
-- ============================================================
