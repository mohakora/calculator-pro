-- =========================================================
-- نظام الإيجارات الزراعية - Migration 0001: الهيكل الأساسي
-- =========================================================

create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ---------------------------------------------------------
-- جدول الأدوار: يربط كل مستخدم بدور (admin / manager / viewer)
-- ---------------------------------------------------------
create table if not exists user_roles (
    user_id uuid primary key references auth.users(id) on delete cascade,
    role text not null check (role in ('admin', 'manager', 'viewer')),
    full_name text,
    created_at timestamptz not null default now()
);

-- دالة مساعدة لمعرفة دور المستخدم الحالي (تُستخدم داخل سياسات RLS)
create or replace function current_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from user_roles where user_id = auth.uid();
$$;

-- ---------------------------------------------------------
-- جدول المستأجرين (tenants) - الكيان المركزي
-- ---------------------------------------------------------
create table if not exists tenants (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid references auth.users(id),
    journal text,
    name text not null,
    district text,
    sahm numeric(10,2) default 0 check (sahm >= 0),
    qirat numeric(10,2) default 0 check (qirat >= 0),
    feddan numeric(10,2) default 0 check (feddan >= 0),
    infringements_count integer not null default 0,
    hand_holder text,
    location_url text,
    phone text,
    notes text,
    contract_start_date date,
    contract_end_date date,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz
);

create index if not exists idx_tenants_name on tenants (name);
create index if not exists idx_tenants_district on tenants (district);
create index if not exists idx_tenants_journal on tenants (journal);
create index if not exists idx_tenants_user_id on tenants (user_id);
create index if not exists idx_tenants_deleted_at on tenants (deleted_at);
create index if not exists idx_tenants_search on tenants using gin (
    to_tsvector('simple', coalesce(name,'') || ' ' || coalesce(district,'') || ' ' || coalesce(journal,''))
);

-- ---------------------------------------------------------
-- جدول القطع الزراعية (parcels)
-- ---------------------------------------------------------
create table if not exists parcels (
    id uuid primary key default uuid_generate_v4(),
    tenant_id uuid not null references tenants(id) on delete cascade,
    basin text,            -- الحوض
    parcel_number text,    -- رقم القطعة
    location text,
    area numeric(10,2) default 0 check (area >= 0),
    notes text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz
);

create index if not exists idx_parcels_tenant_id on parcels (tenant_id);
create index if not exists idx_parcels_tenant_created on parcels (tenant_id, created_at);

-- ---------------------------------------------------------
-- جدول التعديات (infringements)
-- ---------------------------------------------------------
create table if not exists infringements (
    id uuid primary key default uuid_generate_v4(),
    tenant_id uuid not null references tenants(id) on delete cascade,
    infringement_type text,
    infringer_name text,
    area numeric(10,2) default 0 check (area >= 0),
    action_taken text,
    notes text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz
);

create index if not exists idx_infringements_tenant_id on infringements (tenant_id);
create index if not exists idx_infringements_tenant_created on infringements (tenant_id, created_at);

-- ---------------------------------------------------------
-- جدول الوثائق (documents)
-- ---------------------------------------------------------
create table if not exists documents (
    id uuid primary key default uuid_generate_v4(),
    tenant_id uuid not null references tenants(id) on delete cascade,
    document_number text,
    document_type text,
    document_date date,
    file_url text,
    notes text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz
);

create index if not exists idx_documents_tenant_id on documents (tenant_id);
create index if not exists idx_documents_tenant_created on documents (tenant_id, created_at);

-- ---------------------------------------------------------
-- جداول مستقلة: النسخ الاحتياطية، السجلات، الإعدادات
-- ---------------------------------------------------------
create table if not exists backups (
    id uuid primary key default uuid_generate_v4(),
    backup_number text,
    backup_date date not null default current_date,
    backup_time time not null default current_time,
    created_by uuid references auth.users(id),
    backup_type text,
    size_bytes bigint,
    download_link text,
    created_at timestamptz not null default now()
);

create table if not exists system_logs (
    id uuid primary key default uuid_generate_v4(),
    action_type text not null,
    user_id uuid references auth.users(id),
    details text,
    context jsonb,
    created_at timestamptz not null default now()
);

create table if not exists app_settings (
    key text primary key,
    value jsonb,
    updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------
-- مشغّل: تحديث updated_at تلقائياً
-- ---------------------------------------------------------
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create trigger trg_tenants_updated before update on tenants
    for each row execute function set_updated_at();
create trigger trg_parcels_updated before update on parcels
    for each row execute function set_updated_at();
create trigger trg_infringements_updated before update on infringements
    for each row execute function set_updated_at();
create trigger trg_documents_updated before update on documents
    for each row execute function set_updated_at();

-- ---------------------------------------------------------
-- مشغّل: تحديث infringements_count تلقائياً (يعالج INSERT/UPDATE/DELETE)
-- ---------------------------------------------------------
create or replace function update_infringements_count()
returns trigger as $$
begin
    if TG_OP = 'INSERT' then
        update tenants set infringements_count = infringements_count + 1 where id = new.tenant_id;
    elsif TG_OP = 'DELETE' then
        update tenants set infringements_count = greatest(infringements_count - 1, 0) where id = old.tenant_id;
    elsif TG_OP = 'UPDATE' then
        if old.tenant_id is distinct from new.tenant_id then
            update tenants set infringements_count = greatest(infringements_count - 1, 0) where id = old.tenant_id;
            update tenants set infringements_count = infringements_count + 1 where id = new.tenant_id;
        end if;
    end if;
    return null;
end;
$$ language plpgsql;

create trigger trg_infringements_count
    after insert or update or delete on infringements
    for each row execute function update_infringements_count();
