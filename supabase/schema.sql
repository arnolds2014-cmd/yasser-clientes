create extension if not exists pgcrypto;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique,
  role text not null default 'client' check (role in ('client', 'barber')),
  created_at timestamptz not null default now()
);

create function public.create_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, username)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'username'), ''),
      'cliente-' || left(new.id::text, 8)
    )
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.create_profile_for_new_user();

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (length(trim(body)) > 0),
  kind text not null default 'text' check (kind in ('text', 'cut_reference')),
  created_at timestamptz not null default now()
);

create index messages_participants_created_at
  on public.messages (sender_id, recipient_id, created_at);

create table public.haircut_history (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.profiles(id) on delete cascade,
  specifications text not null,
  created_at timestamptz not null default now()
);

create table public.barber_settings (
  singleton boolean primary key default true check (singleton),
  barber_id uuid not null references public.profiles(id)
);

alter table public.profiles enable row level security;
alter table public.messages enable row level security;
alter table public.haircut_history enable row level security;
alter table public.barber_settings enable row level security;

create policy "Authenticated users can read barber settings"
  on public.barber_settings for select to authenticated
  using (true);

create policy "Clients and barber can read profiles"
  on public.profiles for select to authenticated
  using (
    id = (select auth.uid())
    or id = (
      select barber_id from public.barber_settings where singleton = true
    )
    or exists (
      select 1 from public.barber_settings
      where barber_id = (select auth.uid())
    )
    or exists (
      select 1 from public.messages m
      where (m.sender_id = (select auth.uid()) and m.recipient_id = profiles.id)
         or (m.recipient_id = (select auth.uid()) and m.sender_id = profiles.id)
    )
  );

create policy "Users can update own username"
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()) and role = 'client');

create policy "Participants can read messages"
  on public.messages for select to authenticated
  using (
    sender_id = (select auth.uid())
    or recipient_id = (select auth.uid())
  );

create policy "Clients can send messages to barber"
  on public.messages for insert to authenticated
  with check (
    sender_id = (select auth.uid())
    and exists (
      select 1
      from public.profiles sender
      join public.profiles recipient on recipient.id = messages.recipient_id
      where sender.id = (select auth.uid())
        and sender.role = 'client'
        and recipient.role = 'barber'
        and recipient.id = (
          select barber_id from public.barber_settings where singleton = true
        )
    )
  );

create policy "Barber can reply to clients"
  on public.messages for insert to authenticated
  with check (
    sender_id = (select auth.uid())
    and exists (
      select 1
      from public.profiles sender
      join public.profiles recipient on recipient.id = messages.recipient_id
      where sender.id = (select auth.uid())
        and sender.role = 'barber'
        and sender.id = (
          select barber_id from public.barber_settings where singleton = true
        )
        and recipient.role = 'client'
    )
  );

create policy "Barber can read client haircut history"
  on public.haircut_history for select to authenticated
  using (
    exists (
      select 1 from public.barber_settings
      where barber_id = (select auth.uid())
    )
  );

create policy "Clients read their own haircut history"
  on public.haircut_history for select to authenticated
  using (client_id = (select auth.uid()));

create policy "Barber can add haircut history"
  on public.haircut_history for insert to authenticated
  with check (
    exists (
      select 1 from public.profiles
      where id = (select auth.uid()) and role = 'barber'
    )
  );

grant select, update on public.profiles to authenticated;
grant select, insert on public.messages to authenticated;
grant select, insert on public.haircut_history to authenticated;
grant select on public.barber_settings to authenticated;

alter publication supabase_realtime add table public.messages;
