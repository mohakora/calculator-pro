-- ============================================================
-- مخطط قاعدة بيانات Supabase لتطبيق "حاسبة مساحات الأراضي الزراعية"
-- نفّذ هذا الملف كاملاً مرة واحدة من Supabase Studio -> SQL Editor -> New query
-- ============================================================

-- 1) جدول الملف الشخصي للمستخدم (الاسم الكامل، الجوال/واتساب، البريد)
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  phone text,
  email text,
  created_at timestamptz default now()
);

alter table public.profiles enable row level security;

-- كل مستخدم يرى ويعدّل بياناته فقط
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);

create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);

create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = id);

-- ------------------------------------------------------------
-- دالة + Trigger: عند إنشاء مستخدم جديد في auth.users تلقائياً
-- يتم إنشاء صف مطابق في profiles مع الاسم والجوال اللذين تم
-- إرسالهما من نموذج التسجيل (raw_user_meta_data)
-- ------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, phone, email)
  values (
    new.id,
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'phone',
    new.email
  )
  on conflict (id) do update
    set full_name = excluded.full_name,
        phone = excluded.phone,
        email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ============================================================
-- 2) جدول الأراضي/الأحواض (بيانات Zira.csv بعد ترحيلها)
-- ============================================================
create table if not exists public.land_plots (
  id bigint generated always as identity primary key,
  nahia text,        -- الناحية
  plot_type text,     -- النوع
  waqf text,           -- الوقف
  gazette text,        -- الجريدة
  basin text,          -- الحوض
  tenant text,         -- المستأجر
  sahm int default 0,    -- السهم
  qirat int default 0,   -- القيراط
  feddan int default 0   -- الفدان
);

create index if not exists idx_land_plots_tenant on public.land_plots (tenant);
create index if not exists idx_land_plots_nahia on public.land_plots (nahia);
create index if not exists idx_land_plots_basin on public.land_plots (basin);

alter table public.land_plots enable row level security;

-- أي مستخدم مسجّل دخول يمكنه القراءة فقط (لا تعديل من الواجهة)
create policy "land_plots_read_authenticated" on public.land_plots
  for select using (auth.role() = 'authenticated');

-- ============================================================
-- 3) جدول الحسابات المحفوظة لكل مستخدم (اختياري - ميزة إضافية)
-- ============================================================
create table if not exists public.saved_calculations (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users (id) on delete cascade,
  title text,
  feddan_price numeric,
  main_rows jsonb,
  deduct_rows jsonb,
  totals jsonb,
  created_at timestamptz default now()
);

alter table public.saved_calculations enable row level security;

create policy "saved_calc_select_own" on public.saved_calculations
  for select using (auth.uid() = user_id);

create policy "saved_calc_insert_own" on public.saved_calculations
  for insert with check (auth.uid() = user_id);

create policy "saved_calc_delete_own" on public.saved_calculations
  for delete using (auth.uid() = user_id);

-- ============================================================
-- بعد تنفيذ هذا الملف:
-- 1. اذهب إلى Table Editor -> land_plots -> Insert -> Import data from CSV
-- 2. ارفع ملف land_plots.csv المرفق (الأعمدة متطابقة تماماً مع الجدول)
-- ============================================================
