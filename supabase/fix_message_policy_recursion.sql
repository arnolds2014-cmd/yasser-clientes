create or replace function public.yasser_barber_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select settings.barber_id
  from public.barber_settings settings
  join public.profiles barber on barber.id = settings.barber_id
  where settings.singleton is true
    and barber.role = 'barber'
  limit 1;
$$;

create or replace function public.current_user_is_yasser_barber()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select public.yasser_barber_id()) = (select auth.uid()),
    false
  );
$$;

create or replace function public.can_send_yasser_message(
  p_sender_id uuid,
  p_recipient_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles sender
    join public.profiles recipient on recipient.id = p_recipient_id
    join public.barber_settings settings on settings.singleton is true
    where sender.id = p_sender_id
      and sender.id = (select auth.uid())
      and (
        (
          sender.role = 'client'
          and recipient.role = 'barber'
          and recipient.id = settings.barber_id
        )
        or (
          sender.role = 'barber'
          and sender.id = settings.barber_id
          and recipient.role = 'client'
        )
      )
  );
$$;

revoke execute on function public.yasser_barber_id() from public, anon;
revoke execute on function public.current_user_is_yasser_barber() from public, anon;
revoke execute on function public.can_send_yasser_message(uuid, uuid) from public, anon;
grant execute on function public.yasser_barber_id() to authenticated;
grant execute on function public.current_user_is_yasser_barber() to authenticated;
grant execute on function public.can_send_yasser_message(uuid, uuid) to authenticated;

drop policy if exists "Clients and barber can read profiles" on public.profiles;
create policy "Clients and barber can read profiles"
  on public.profiles for select to authenticated
  using (
    id = (select auth.uid())
    or id = (select public.yasser_barber_id())
    or (select public.current_user_is_yasser_barber())
  );

drop policy if exists "Clients can send messages to barber" on public.messages;
drop policy if exists "Barber can reply to clients" on public.messages;
create policy "Conversation participants can send messages"
  on public.messages for insert to authenticated
  with check ((select public.can_send_yasser_message(sender_id, recipient_id)));
