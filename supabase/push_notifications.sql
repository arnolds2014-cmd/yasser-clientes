create table if not exists public.yasser_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.yasser_profiles(id) on delete cascade,
  token text not null unique,
  platform text not null default 'android' check (platform = 'android'),
  updated_at timestamptz not null default now()
);

alter table public.yasser_push_tokens enable row level security;

drop policy if exists "YASSER users manage their own push tokens"
  on public.yasser_push_tokens;
create policy "YASSER users manage their own push tokens"
  on public.yasser_push_tokens for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

grant select, insert, update, delete on public.yasser_push_tokens to authenticated;
