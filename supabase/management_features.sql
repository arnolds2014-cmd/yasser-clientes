alter table public.yasser_barber_settings
  add column if not exists opening_time time not null default time '08:00',
  add column if not exists closing_time time not null default time '20:00';

drop policy if exists "YASSER barber can update barber settings"
  on public.yasser_barber_settings;
create policy "YASSER barber can update barber settings"
  on public.yasser_barber_settings for update to authenticated
  using (
    singleton is true
    and barber_id = (select auth.uid())
  )
  with check (
    singleton is true
    and barber_id = (select auth.uid())
  );

grant update on public.yasser_barber_settings to authenticated;

drop policy if exists "YASSER users can update their own profile"
  on public.yasser_profiles;
create policy "YASSER users can update their own profile"
  on public.yasser_profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

grant update on public.yasser_profiles to authenticated;

create table if not exists public.yasser_gallery_items (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  storage_path text not null unique,
  created_at timestamptz not null default now()
);

alter table public.yasser_gallery_items enable row level security;

drop policy if exists "YASSER authenticated users can view gallery"
  on public.yasser_gallery_items;
create policy "YASSER authenticated users can view gallery"
  on public.yasser_gallery_items for select to authenticated
  using (true);

drop policy if exists "YASSER barber can manage gallery"
  on public.yasser_gallery_items;
create policy "YASSER barber can manage gallery"
  on public.yasser_gallery_items for all to authenticated
  using (
    exists (
      select 1
      from public.yasser_barber_settings settings
      where settings.singleton is true
        and settings.barber_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1
      from public.yasser_barber_settings settings
      where settings.singleton is true
        and settings.barber_id = (select auth.uid())
    )
  );

grant select, insert, update, delete on public.yasser_gallery_items to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'yasser-gallery',
  'yasser-gallery',
  true,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "YASSER barber uploads gallery images"
  on storage.objects;
create policy "YASSER barber uploads gallery images"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'yasser-gallery'
    and exists (
      select 1
      from public.yasser_barber_settings settings
      where settings.singleton is true
        and settings.barber_id = (select auth.uid())
    )
  );

drop policy if exists "YASSER barber deletes gallery images"
  on storage.objects;
create policy "YASSER barber deletes gallery images"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'yasser-gallery'
    and exists (
      select 1
      from public.yasser_barber_settings settings
      where settings.singleton is true
        and settings.barber_id = (select auth.uid())
    )
  );

grant select on public.yasser_gallery_items to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'yasser_barber_settings'
  ) then
    alter publication supabase_realtime add table public.yasser_barber_settings;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'yasser_gallery_items'
  ) then
    alter publication supabase_realtime add table public.yasser_gallery_items;
  end if;
end;
$$;
