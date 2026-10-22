select
  (select count(*) from public.profiles where role = 'barber')
    as barber_profiles,
  (select count(*) from public.profiles where role = 'client')
    as client_profiles,
  (select count(*) from public.barber_settings where singleton = true)
    as barber_setting_rows,
  (
    select count(*)
    from public.barber_settings settings
    join public.profiles barber on barber.id = settings.barber_id
    where settings.singleton = true and barber.role = 'barber'
  ) as valid_barber_settings,
  exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'messages'
  ) as messages_realtime_enabled,
  exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'profiles'
  ) as profiles_realtime_enabled,
  (select count(*) from public.messages) as saved_messages;
