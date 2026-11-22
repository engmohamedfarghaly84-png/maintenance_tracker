-- ============================================================================
-- مخطط جداول Supabase لتطبيق متابعة الصيانة (Maintenance Tracker)
-- انسخ هذا الكود وشغّله في Supabase Dashboard > SQL Editor
-- ============================================================================

create table if not exists public.customers (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  client_number integer not null default 1,
  name text not null,
  area text not null default '',
  amount double precision not null default 0,
  payment_method text not null default 'cash',
  start_month text not null,
  is_deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.customers add column if not exists client_number integer not null default 1;

create table if not exists public.maintenance_entries (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  customer_id text not null references public.customers(id) on delete cascade,
  account_month text not null,
  is_advance boolean not null default false,
  amount double precision not null default 0,
  status text not null default 'unpaid',
  payment_method text not null default 'cash',
  is_deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.engineer_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  engineer_name text not null default '',
  base_salary double precision not null default 0,
  commission_rate double precision not null default 0,
  commission_basis text not null default 'total',
  dues_association double precision not null default 0,
  dues_telecom double precision not null default 0,
  dues_insurance double precision not null default 0,
  carried_balance double precision not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists public.settlements (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  month text not null,
  total_maintenance double precision not null default 0,
  commission double precision not null default 0,
  wallet_transfers double precision not null default 0,
  salary_and_dues double precision not null default 0,
  carried_in double precision not null default 0,
  payment double precision not null default 0,
  net_remaining double precision not null default 0,
  approved boolean not null default false,
  approved_at timestamptz,
  updated_at timestamptz not null default now()
);

-- فهارس لتسريع المزامنة
create index if not exists idx_customers_user_updated on public.customers(user_id, updated_at);
create index if not exists idx_entries_user_updated on public.maintenance_entries(user_id, updated_at);
create index if not exists idx_settlements_user_updated on public.settlements(user_id, updated_at);

-- تفعيل عزل بيانات كل مهندس تلقائياً (Row Level Security)
alter table public.customers enable row level security;
alter table public.maintenance_entries enable row level security;
alter table public.engineer_settings enable row level security;
alter table public.settlements enable row level security;

drop policy if exists "engineer_customers_policy" on public.customers;
create policy "engineer_customers_policy" on public.customers
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "engineer_entries_policy" on public.maintenance_entries;
create policy "engineer_entries_policy" on public.maintenance_entries
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "engineer_settings_policy" on public.engineer_settings;
create policy "engineer_settings_policy" on public.engineer_settings
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "engineer_settlements_policy" on public.settlements;
create policy "engineer_settlements_policy" on public.settlements
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
