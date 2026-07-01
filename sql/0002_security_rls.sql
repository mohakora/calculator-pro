-- =========================================================
-- نظام الإيجارات الزراعية - Migration 0002: الأمان (RLS)
-- =========================================================
-- المبدأ: أي مستخدم مسجّل دخول وله دور في user_roles يقدر يشتغل.
-- admin/manager: قراءة + كتابة. viewer: قراءة فقط.
-- الحذف الفعلي مسموح فقط لـ admin (الباقي يستخدمون deleted_at).

alter table tenants enable row level security;
alter table parcels enable row level security;
alter table infringements enable row level security;
alter table documents enable row level security;
alter table backups enable row level security;
alter table system_logs enable row level security;
alter table app_settings enable row level security;
alter table user_roles enable row level security;

-- ---------------------------------------------------------
-- user_roles: كل مستخدم يشوف دوره فقط، admin يشوف ويعدل الكل
-- ---------------------------------------------------------
create policy "user can view own role" on user_roles
    for select using (auth.uid() = user_id or current_user_role() = 'admin');

create policy "admin manages roles" on user_roles
    for all using (current_user_role() = 'admin')
    with check (current_user_role() = 'admin');

-- ---------------------------------------------------------
-- tenants
-- ---------------------------------------------------------
create policy "authenticated can read tenants" on tenants
    for select using (auth.role() = 'authenticated' and current_user_role() is not null);

create policy "admin/manager can insert tenants" on tenants
    for insert with check (current_user_role() in ('admin','manager'));

create policy "admin/manager can update tenants" on tenants
    for update using (current_user_role() in ('admin','manager'))
    with check (current_user_role() in ('admin','manager'));

create policy "admin can delete tenants" on tenants
    for delete using (current_user_role() = 'admin');

-- ---------------------------------------------------------
-- parcels
-- ---------------------------------------------------------
create policy "authenticated can read parcels" on parcels
    for select using (current_user_role() is not null);

create policy "admin/manager can insert parcels" on parcels
    for insert with check (current_user_role() in ('admin','manager'));

create policy "admin/manager can update parcels" on parcels
    for update using (current_user_role() in ('admin','manager'))
    with check (current_user_role() in ('admin','manager'));

create policy "admin can delete parcels" on parcels
    for delete using (current_user_role() = 'admin');

-- ---------------------------------------------------------
-- infringements
-- ---------------------------------------------------------
create policy "authenticated can read infringements" on infringements
    for select using (current_user_role() is not null);

create policy "admin/manager can insert infringements" on infringements
    for insert with check (current_user_role() in ('admin','manager'));

create policy "admin/manager can update infringements" on infringements
    for update using (current_user_role() in ('admin','manager'))
    with check (current_user_role() in ('admin','manager'));

create policy "admin can delete infringements" on infringements
    for delete using (current_user_role() = 'admin');

-- ---------------------------------------------------------
-- documents
-- ---------------------------------------------------------
create policy "authenticated can read documents" on documents
    for select using (current_user_role() is not null);

create policy "admin/manager can insert documents" on documents
    for insert with check (current_user_role() in ('admin','manager'));

create policy "admin/manager can update documents" on documents
    for update using (current_user_role() in ('admin','manager'))
    with check (current_user_role() in ('admin','manager'));

create policy "admin can delete documents" on documents
    for delete using (current_user_role() = 'admin');

-- ---------------------------------------------------------
-- backups / system_logs / app_settings: admin فقط
-- ---------------------------------------------------------
create policy "admin manages backups" on backups
    for all using (current_user_role() = 'admin')
    with check (current_user_role() = 'admin');

create policy "admin reads logs" on system_logs
    for select using (current_user_role() = 'admin');

create policy "system inserts logs" on system_logs
    for insert with check (current_user_role() is not null);

create policy "admin manages settings" on app_settings
    for all using (current_user_role() = 'admin')
    with check (current_user_role() = 'admin');

-- ---------------------------------------------------------
-- أول مستخدم يسجّل دخول يبقى admin تلقائياً (تسهيل أول إعداد فقط)
-- بعد إنشاء أول حساب، عدّل/احذف هذا المشغل لتفادي منح admin للجميع
-- ---------------------------------------------------------
create or replace function handle_new_user()
returns trigger as $$
begin
    insert into user_roles (user_id, role, full_name)
    values (
        new.id,
        case when (select count(*) from user_roles) = 0 then 'admin' else 'viewer' end,
        new.raw_user_meta_data->>'full_name'
    );
    return new;
end;
$$ language plpgsql security definer set search_path = public;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function handle_new_user();
