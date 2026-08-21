-- ============================================================
-- SUPABASE SCHEMA for ISI CMI Prep
-- ============================================================
-- Run this in Supabase SQL Editor
-- ============================================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ============================================================
-- 1. USER PROFILES (extends auth.users)
-- ============================================================
create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    email text not null,
    display_name text,
    is_admin boolean default false,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

-- RLS: users can read own profile, admins can read all
alter table public.profiles enable row level security;

create policy "Users can view own profile"
    on public.profiles for select
    using (auth.uid() = id);

create policy "Admins can view all profiles"
    on public.profiles for select
    using (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true));

create policy "Users can update own profile"
    on public.profiles for update
    using (auth.uid() = id);

create policy "Admins can update any profile"
    on public.profiles for update
    using (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true));

-- Trigger to auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
    insert into public.profiles (id, email, display_name)
    values (new.id, new.email, new.raw_user_meta_data->>'display_name');
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute procedure public.handle_new_user();

-- ============================================================
-- 2. TASKS (Planner)
-- ============================================================
create table if not exists public.tasks (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid not null references auth.users(id) on delete cascade,
    title text not null,
    date date not null,
    done boolean default false,
    alarm_at timestamptz,
    sound text default 'none',
    ring_seconds int default 30,
    notify_only boolean default false,
    backlog boolean default false,
    "order" int default 0,
    repeat_daily boolean default false,
    locked boolean default false,
    locked_by uuid references auth.users(id),
    locked_at timestamptz,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

create index if not exists idx_tasks_user_date on public.tasks(user_id, date);
create index if not exists idx_tasks_user_alarm on public.tasks(user_id, alarm_at) where alarm_at is not null;

alter table public.tasks enable row level security;

-- User can CRUD own tasks
create policy "User CRUD own tasks"
    on public.tasks for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

-- Admin can CRUD any user's tasks
create policy "Admin CRUD any tasks"
    on public.tasks for all
    using (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true))
    with check (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true));

-- ============================================================
-- 3. SCHEDULE SLOTS (Weekly recurring)
-- ============================================================
create table if not exists public.schedule_slots (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid not null references auth.users(id) on delete cascade,
    weekday int not null check (weekday between 1 and 7), -- 1=Mon ... 7=Sun
    title text not null,
    start_min int not null,  -- minutes from midnight
    end_min int not null,
    locked boolean default false,
    locked_by uuid references auth.users(id),
    locked_at timestamptz,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

create index if not exists idx_schedule_user_weekday on public.schedule_slots(user_id, weekday);

alter table public.schedule_slots enable row level security;

create policy "User CRUD own schedule"
    on public.schedule_slots for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

create policy "Admin CRUD any schedule"
    on public.schedule_slots for all
    using (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true))
    with check (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true));

-- ============================================================
-- 4. SYLLABUS (Exam tree)
-- ============================================================
create table if not exists public.syllabus_nodes (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid not null references auth.users(id) on delete cascade,
    parent_id uuid references public.syllabus_nodes(id) on delete cascade,
    name text not null,
    status int default 0, -- 0=notDone, 1=doing, 2=partial, 3=done
    revisions int default 0,
    attempts int default 0,
    next_revision timestamptz,
    "order" int default 0,
    locked boolean default false,
    locked_by uuid references auth.users(id),
    locked_at timestamptz,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

create index if not exists idx_syllabus_user_parent on public.syllabus_nodes(user_id, parent_id);

alter table public.syllabus_nodes enable row level security;

create policy "User CRUD own syllabus"
    on public.syllabus_nodes for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

create policy "Admin CRUD any syllabus"
    on public.syllabus_nodes for all
    using (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true))
    with check (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true));

-- ============================================================
-- 5. REMINDERS (One-time notifications)
-- ============================================================
create table if not exists public.reminders (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid not null references auth.users(id) on delete cascade,
    title text not null,
    at timestamptz not null,
    silent boolean default false,
    locked boolean default false,
    locked_by uuid references auth.users(id),
    locked_at timestamptz,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

create index if not exists idx_reminders_user_at on public.reminders(user_id, at);

alter table public.reminders enable row level security;

create policy "User CRUD own reminders"
    on public.reminders for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

create policy "Admin CRUD any reminders"
    on public.reminders for all
    using (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true))
    with check (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true));

-- ============================================================
-- 6. STUDY LOG
-- ============================================================
create table if not exists public.study_logs (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid not null references auth.users(id) on delete cascade,
    date date not null,
    minutes int not null,
    created_at timestamptz default now()
);

create unique index if not exists idx_study_log_user_date on public.study_logs(user_id, date);

alter table public.study_logs enable row level security;

create policy "User CRUD own study logs"
    on public.study_logs for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

create policy "Admin CRUD any study logs"
    on public.study_logs for all
    using (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true))
    with check (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true));

-- ============================================================
-- 7. MOCK TEST RESULTS
-- ============================================================
create table if not exists public.mock_results (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid not null references auth.users(id) on delete cascade,
    day date not null,
    score int not null,
    total int not null,
    created_at timestamptz default now()
);

create index if not exists idx_mock_results_user_day on public.mock_results(user_id, day);

alter table public.mock_results enable row level security;

create policy "User CRUD own mock results"
    on public.mock_results for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

create policy "Admin CRUD any mock results"
    on public.mock_results for all
    using (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true))
    with check (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true));

-- ============================================================
-- 8. DAILY PLAN
-- ============================================================
create table if not exists public.daily_plans (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid not null references auth.users(id) on delete cascade,
    day date not null,
    plan_json jsonb not null,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

create unique index if not exists idx_daily_plan_user_day on public.daily_plans(user_id, day);

alter table public.daily_plans enable row level security;

drop policy if exists "User CRUD own daily plans" on public.daily_plans;
create policy "User CRUD own daily plans"
    on public.daily_plans for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

drop policy if exists "Admin CRUD any daily plans" on public.daily_plans;
create policy "Admin CRUD any daily plans"
    on public.daily_plans for all
    using (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true))
    with check (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true));

-- ============================================================
-- 9. SETTINGS / META
-- ============================================================
create table if not exists public.user_settings (
    user_id uuid primary key references auth.users(id) on delete cascade,
    theme_id text default 'midnight',
    time_format_24 boolean default true,
    custom_sound text,
    updated_at timestamptz default now()
);

alter table public.user_settings enable row level security;

create policy "User CRUD own settings"
    on public.user_settings for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

create policy "Admin CRUD any settings"
    on public.user_settings for all
    using (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true))
    with check (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true));

-- ============================================================
-- 10. ADMIN IMPERSONATION LOG (audit)
-- ============================================================
create table if not exists public.impersonation_logs (
    id uuid primary key default uuid_generate_v4(),
    admin_id uuid not null references auth.users(id) on delete cascade,
    target_user_id uuid not null references auth.users(id) on delete cascade,
    started_at timestamptz default now(),
    ended_at timestamptz
);

create index if not exists idx_impersonation_admin on public.impersonation_logs(admin_id);
create index if not exists idx_impersonation_target on public.impersonation_logs(target_user_id);

alter table public.impersonation_logs enable row level security;

create policy "Admin can view own impersonation logs"
    on public.impersonation_logs for select
    using (auth.uid() = admin_id);

create policy "Admins can insert impersonation logs"
    on public.impersonation_logs for insert
    with check (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true));

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================

-- Auto-update updated_at timestamp
create or replace function public.handle_updated_at()
returns trigger language plpgsql as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create trigger tasks_updated_at
    before update on public.tasks
    for each row execute procedure public.handle_updated_at();

create trigger schedule_slots_updated_at
    before update on public.schedule_slots
    for each row execute procedure public.handle_updated_at();

create trigger syllabus_nodes_updated_at
    before update on public.syllabus_nodes
    for each row execute procedure public.handle_updated_at();

create trigger reminders_updated_at
    before update on public.reminders
    for each row execute procedure public.handle_updated_at();

create trigger daily_plans_updated_at
    before update on public.daily_plans
    for each row execute procedure public.handle_updated_at();

create trigger user_settings_updated_at
    before update on public.user_settings
    for each row execute procedure public.handle_updated_at();

-- ============================================================
-- REALTIME PUBLICATION (for cross-device sync)
-- ============================================================
alter publication supabase_realtime add table
    public.tasks,
    public.schedule_slots,
    public.syllabus_nodes,
    public.reminders,
    public.study_logs,
    public.mock_results,
    public.daily_plans,
    public.user_settings,
    public.profiles;