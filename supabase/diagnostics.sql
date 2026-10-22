select
  (select count(*) from public.yasser_profiles) as app_profiles,
  (select count(*) from public.yasser_messages) as app_messages,
  (select count(*) from public.yasser_barber_settings) as barber_setting_rows,
  (
    select count(*)
    from public.yasser_barber_settings settings
    join public.yasser_profiles barber on barber.id = settings.barber_id
    where settings.singleton is true
      and settings.barber_id = 'UUID_DEL_BARBERO'::uuid
  ) as matching_barber_setting,
  exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'yasser_messages'
  ) as messages_realtime_enabled,
  exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'yasser_profiles'
  ) as profiles_realtime_enabled;
