create extension if not exists pgcrypto;

-- The yasser_* tables isolate the new chat from any existing public tables.
create table if not exists public.yasser_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.yasser_messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.yasser_profiles(id) on delete cascade,
  recipient_id uuid not null references public.yasser_profiles(id) on delete cascade,
  body text not null check (length(trim(body)) > 0),
  kind text not null default 'text'
    check (kind in ('text', 'cut_reference')),
  created_at timestamptz not null default now()
);

create index if not exists yasser_messages_participants_created_at
  on public.yasser_messages (sender_id, recipient_id, created_at);

create table if not exists public.yasser_haircut_history (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.yasser_profiles(id) on delete cascade,
  specifications text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.yasser_barber_settings (
  singleton boolean primary key default true check (singleton),
  barber_id uuid not null references public.yasser_profiles(id),
  opening_time time not null default time '08:00',
  closing_time time not null default time '20:00'
);

create or replace function public.create_yasser_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.yasser_profiles (id, username)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
      'Cliente'
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists yasser_on_auth_user_created on auth.users;
create trigger yasser_on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.create_yasser_profile_for_new_user();

-- Backfill accounts created before this schema was installed.
insert into public.yasser_profiles (id, username)
select
  users.id,
  coalesce(
    nullif(trim(users.raw_user_meta_data ->> 'display_name'), ''),
    nullif(trim(users.raw_user_meta_data ->> 'username'), ''),
    'Cliente'
  )
from auth.users users
on conflict (id) do nothing;

alter table public.yasser_profiles enable row level security;
alter table public.yasser_messages enable row level security;
alter table public.yasser_haircut_history enable row level security;
alter table public.yasser_barber_settings enable row level security;

drop policy if exists "YASSER users can read allowed profiles"
  on public.yasser_profiles;
create policy "YASSER users can read allowed profiles"
  on public.yasser_profiles for select to authenticated
  using (
    id = (select auth.uid())
    or id = (
      select settings.barber_id
      from public.yasser_barber_settings settings
      where settings.singleton is true
    )
    or exists (
      select 1
      from public.yasser_barber_settings settings
      where settings.singleton is true
        and settings.barber_id = (select auth.uid())
    )
  );

drop policy if exists "YASSER participants can read messages"
  on public.yasser_messages;
create policy "YASSER participants can read messages"
  on public.yasser_messages for select to authenticated
  using (
    sender_id = (select auth.uid())
    or recipient_id = (select auth.uid())
  );

drop policy if exists "YASSER users can message the barber or reply"
  on public.yasser_messages;
create policy "YASSER users can message the barber or reply"
  on public.yasser_messages for insert to authenticated
  with check (
    sender_id = (select auth.uid())
    and (
      recipient_id = (
        select settings.barber_id
        from public.yasser_barber_settings settings
        where settings.singleton is true
      )
      or sender_id = (
        select settings.barber_id
        from public.yasser_barber_settings settings
        where settings.singleton is true
      )
    )
  );

drop policy if exists "YASSER users can read their haircut history"
  on public.yasser_haircut_history;
create policy "YASSER users can read their haircut history"
  on public.yasser_haircut_history for select to authenticated
  using (
    client_id = (select auth.uid())
    or exists (
      select 1 from public.yasser_barber_settings settings
      where settings.singleton is true
        and settings.barber_id = (select auth.uid())
    )
  );

drop policy if exists "YASSER barber can record client haircut history"
  on public.yasser_haircut_history;
create policy "YASSER barber can record client haircut history"
  on public.yasser_haircut_history for insert to authenticated
  with check (
    exists (
      select 1 from public.yasser_barber_settings settings
      where settings.singleton is true
        and settings.barber_id = (select auth.uid())
    )
    and exists (
      select 1 from public.yasser_profiles client
      where client.id = client_id
        and client.id <> (select auth.uid())
    )
  );

drop policy if exists "YASSER authenticated users can read barber settings"
  on public.yasser_barber_settings;
create policy "YASSER authenticated users can read barber settings"
  on public.yasser_barber_settings for select to authenticated
  using (true);

grant select on public.yasser_profiles to authenticated;
grant select, insert on public.yasser_messages to authenticated;
grant select, insert on public.yasser_haircut_history to authenticated;
grant select on public.yasser_barber_settings to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'yasser_messages'
  ) then
    alter publication supabase_realtime add table public.yasser_messages;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'yasser_profiles'
  ) then
    alter publication supabase_realtime add table public.yasser_profiles;
  end if;
end;
$$;
