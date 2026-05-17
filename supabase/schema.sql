create extension if not exists pgcrypto;

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null,
  confidence double precision not null check (confidence >= 0 and confidence <= 1),
  latitude double precision not null,
  longitude double precision not null,
  image_url text not null,
  created_at timestamptz not null default now(),
  status text not null default 'pending',
  classification jsonb not null default '{}'::jsonb,
  embedding double precision[] not null default '{}',
  description text,
  device_timestamp timestamptz,
  severity_percentage integer,
  severity_label text,
  priority_level text
);

create index if not exists reports_user_created_at_idx
  on public.reports (user_id, created_at desc);

create index if not exists reports_created_at_idx
  on public.reports (created_at desc);

alter table public.reports enable row level security;

drop policy if exists "Authenticated users can read reports" on public.reports;
create policy "Authenticated users can read reports"
  on public.reports
  for select
  to authenticated
  using (true);

drop policy if exists "Users can insert own reports" on public.reports;
create policy "Users can insert own reports"
  on public.reports
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own reports" on public.reports;
create policy "Users can update own reports"
  on public.reports
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ===================================================================================
-- KEBIJAKAN KHUSUS ADMIN DASHBOARD (ANON)
-- Karena Admin menggunakan akses anonim (berbasis Javascript key), 
-- kita berikan akses penuh (CRUD) ke tabel reports dan hak hapus gambar di storage.
-- ===================================================================================

-- 1. Admin bisa membaca semua laporan
drop policy if exists "Admin can read all reports" on public.reports;
create policy "Admin can read all reports"
  on public.reports for select to anon using (true);

-- 2. Admin bisa mengubah (update) status laporan
drop policy if exists "Admin can update reports" on public.reports;
create policy "Admin can update reports"
  on public.reports for update to anon using (true);

-- 3. Admin bisa menghapus laporan dari database
drop policy if exists "Admin can delete reports" on public.reports;
create policy "Admin can delete reports"
  on public.reports for delete to anon using (true);

-- 4. Admin bisa menghapus gambar bukti dari Storage
drop policy if exists "Admin can delete images" on storage.objects;
create policy "Admin can delete images"
  on storage.objects for delete to anon 
  using (bucket_id = 'report-images');
insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'report-images',
  'report-images',
  true,
  8388608,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Authenticated users can read report images"
  on storage.objects;
create policy "Authenticated users can read report images"
  on storage.objects
  for select
  to authenticated
  using (bucket_id = 'report-images');

drop policy if exists "Users can upload own report images"
  on storage.objects;
create policy "Users can upload own report images"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'report-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Users can update own report images"
  on storage.objects;
create policy "Users can update own report images"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'report-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'report-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'reports'
  ) then
    alter publication supabase_realtime add table public.reports;
  end if;
end $$;
