-- ═══════════════════════════════════════════════════════
-- AKU ROWING CLUB — Supabase Schema
-- Paste this entire file into Supabase SQL Editor and run
-- ═══════════════════════════════════════════════════════

-- ─── PROFILES ────────────────────────────────────────────
-- Extends Supabase auth.users with club-specific fields
create table public.profiles (
  id          uuid references auth.users on delete cascade primary key,
  full_name   text not null,
  initials    text,
  programme   text check (programme in ('MBBS','Nursing','BSc')),
  grad_year   int,
  role        text default 'Member',
  discipline  text default 'Both' check (discipline in ('Indoor','Outdoor','Both')),
  color       text default '#1FB8C9',
  kbc_active  boolean default false,
  kbc_renewal date,
  avatar_url  text,
  portal_role text default 'member' check (portal_role in ('member','coach','admin')),
  joined_at   date default now(),
  created_at  timestamptz default now()
);

-- ─── WORKOUTS (coach library) ─────────────────────────────
create table public.workouts (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  type        text,
  description text,
  target_split text,
  target_rate  text,
  hr_zone      text,
  duration_min int,
  created_by  uuid references public.profiles(id),
  created_at  timestamptz default now()
);

-- ─── ASSIGNED WORKOUTS ────────────────────────────────────
create table public.assigned_workouts (
  id          uuid primary key default gen_random_uuid(),
  workout_id  uuid references public.workouts(id),
  assigned_to uuid references public.profiles(id),
  assigned_by uuid references public.profiles(id),
  scheduled_date date,
  notes       text,
  status      text default 'pending' check (status in ('pending','completed','skipped')),
  created_at  timestamptz default now()
);

-- ─── WORKOUT LOGS (member session records) ────────────────
create table public.workout_logs (
  id              uuid primary key default gen_random_uuid(),
  member_id       uuid references public.profiles(id),
  assigned_id     uuid references public.assigned_workouts(id),
  logged_date     date default now(),
  total_meters    int,
  avg_split       text,
  mood            text,
  difficulty      text,
  notes           text,
  receipt_url     text,
  created_at      timestamptz default now()
);

-- ─── AVAILABILITY ─────────────────────────────────────────
create table public.availability (
  id          uuid primary key default gen_random_uuid(),
  member_id   uuid references public.profiles(id),
  week_start  date not null,
  mon         text default 'unavailable',
  tue         text default 'unavailable',
  wed         text default 'unavailable',
  thu         text default 'unavailable',
  fri         text default 'unavailable',
  sat         text default 'unavailable',
  sun         text default 'unavailable',
  notes       text,
  submitted_at timestamptz default now(),
  unique(member_id, week_start)
);

-- ─── PAYMENTS ─────────────────────────────────────────────
create table public.payments (
  id            uuid primary key default gen_random_uuid(),
  member_id     uuid references public.profiles(id),
  description   text,
  amount        int,
  paid_to       text,
  status        text default 'pending' check (status in ('pending','submitted','confirmed','overdue')),
  due_date      date,
  receipt_url   text,
  confirmed_by  uuid references public.profiles(id),
  confirmed_at  timestamptz,
  created_at    timestamptz default now()
);

-- ─── REGATTAS ─────────────────────────────────────────────
create table public.regattas (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  date        date,
  venue       text,
  type        text default 'Indoor',
  is_flagship boolean default false,
  status      text default 'upcoming',
  created_at  timestamptz default now()
);

-- ─── REGATTA SELECTIONS ───────────────────────────────────
create table public.regatta_selections (
  id          uuid primary key default gen_random_uuid(),
  regatta_id  uuid references public.regattas(id),
  member_id   uuid references public.profiles(id),
  event       text,
  result      text,
  medal       text,
  created_at  timestamptz default now()
);

-- ─── NEWS ─────────────────────────────────────────────────
create table public.news (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  category    text,
  body        text,
  author_id   uuid references public.profiles(id),
  published   boolean default false,
  published_at timestamptz,
  created_at  timestamptz default now()
);

-- ═══════════════════════════════════════════════════════
-- ROW LEVEL SECURITY
-- ═══════════════════════════════════════════════════════

alter table public.profiles             enable row level security;
alter table public.workouts             enable row level security;
alter table public.assigned_workouts    enable row level security;
alter table public.workout_logs         enable row level security;
alter table public.availability         enable row level security;
alter table public.payments             enable row level security;
alter table public.regattas             enable row level security;
alter table public.regatta_selections   enable row level security;
alter table public.news                 enable row level security;

-- PROFILES: members see everyone (for leaderboards), edit only own
create policy "Profiles visible to all members"
  on public.profiles for select
  using (auth.role() = 'authenticated');

create policy "Members update own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- WORKOUTS: all authenticated can read
create policy "Workouts readable by all"
  on public.workouts for select
  using (auth.role() = 'authenticated');

create policy "Coach/admin can manage workouts"
  on public.workouts for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid()
      and portal_role in ('coach','admin')
    )
  );

-- ASSIGNED WORKOUTS: members see own, coach/admin see all
create policy "Members see own assigned workouts"
  on public.assigned_workouts for select
  using (
    assigned_to = auth.uid() or
    exists (select 1 from public.profiles where id = auth.uid() and portal_role in ('coach','admin'))
  );

create policy "Coach/admin manage assigned workouts"
  on public.assigned_workouts for all
  using (
    exists (select 1 from public.profiles where id = auth.uid() and portal_role in ('coach','admin'))
  );

-- WORKOUT LOGS: members manage own, coach/admin see all
create policy "Members manage own logs"
  on public.workout_logs for all
  using (
    member_id = auth.uid() or
    exists (select 1 from public.profiles where id = auth.uid() and portal_role in ('coach','admin'))
  );

-- AVAILABILITY: members manage own, coach/admin see all
create policy "Members manage own availability"
  on public.availability for all
  using (
    member_id = auth.uid() or
    exists (select 1 from public.profiles where id = auth.uid() and portal_role in ('coach','admin'))
  );

-- PAYMENTS: members see own, admin sees all
create policy "Members see own payments"
  on public.payments for select
  using (
    member_id = auth.uid() or
    exists (select 1 from public.profiles where id = auth.uid() and portal_role = 'admin')
  );

create policy "Members submit receipts"
  on public.payments for update
  using (member_id = auth.uid());

create policy "Admin manage payments"
  on public.payments for all
  using (
    exists (select 1 from public.profiles where id = auth.uid() and portal_role = 'admin')
  );

-- REGATTAS: all can read, admin manages
create policy "Regattas readable by all"
  on public.regattas for select
  using (auth.role() = 'authenticated');

create policy "Admin manages regattas"
  on public.regattas for all
  using (
    exists (select 1 from public.profiles where id = auth.uid() and portal_role = 'admin')
  );

-- REGATTA SELECTIONS: all can read, coach/admin manage
create policy "Selections readable by all"
  on public.regatta_selections for select
  using (auth.role() = 'authenticated');

create policy "Coach/admin manage selections"
  on public.regatta_selections for all
  using (
    exists (select 1 from public.profiles where id = auth.uid() and portal_role in ('coach','admin'))
  );

-- NEWS: published readable by all, admin manages
create policy "Published news readable by all"
  on public.news for select
  using (published = true or exists (select 1 from public.profiles where id = auth.uid() and portal_role = 'admin'));

create policy "Admin manages news"
  on public.news for all
  using (
    exists (select 1 from public.profiles where id = auth.uid() and portal_role = 'admin')
  );

-- ═══════════════════════════════════════════════════════
-- AUTO-CREATE PROFILE ON SIGNUP
-- ═══════════════════════════════════════════════════════
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, initials)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.email),
    upper(left(coalesce(new.raw_user_meta_data->>'full_name', new.email), 1))
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ═══════════════════════════════════════════════════════
-- SEED DATA — AKU RC Regatta
-- ═══════════════════════════════════════════════════════
insert into public.regattas (name, date, venue, type, is_flagship, status)
values
  ('AKU RC Regatta 2025', '2025-05-29', 'AKU Sports & Rehabilitation Center', 'Indoor', true, 'upcoming'),
  ('NUST Inter-University 2024', '2024-11-15', 'NUST, Islamabad', 'Indoor', false, 'complete'),
  ('LUMS Indoor Challenge 2024', '2024-06-20', 'LUMS, Lahore', 'Indoor', false, 'complete');

-- ═══════════════════════════════════════════════════════
-- DONE. Schema created successfully.
-- ═══════════════════════════════════════════════════════
