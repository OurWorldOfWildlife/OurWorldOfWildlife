-- Our World of Wildlife: database setup
-- Run this whole file once in the Supabase SQL Editor.

-- 1. Who is allowed to sign in and manage the site
create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'editor'))
);
alter table public.admins enable row level security;

-- 2. All site content lives in one table
create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('blog', 'sanctuary', 'magazine', 'gallery')),
  title text not null check (char_length(title) between 1 and 140),
  category text check (char_length(category) <= 60),
  author text check (char_length(author) <= 60),
  body text check (char_length(body) <= 20000),
  image_path text,
  image_alt text check (char_length(image_alt) <= 300),
  published boolean not null default false,
  author_id uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists posts_type_created_idx on public.posts (type, created_at desc);
alter table public.posts enable row level security;

-- 3. Helper checks
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;
create or replace function public.is_owner() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid() and role = 'owner');
$$;

create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$ begin new.updated_at = now(); return new; end $$;
drop trigger if exists posts_touch on public.posts;
create trigger posts_touch before update on public.posts
  for each row execute function public.touch_updated_at();

-- 4. Access rules
grant usage on schema public to anon, authenticated;
grant select on public.posts to anon, authenticated;
grant insert, update, delete on public.posts to authenticated;
grant select on public.admins to authenticated;

drop policy if exists "admins read own row" on public.admins;
create policy "admins read own row" on public.admins
  for select to authenticated using (user_id = auth.uid());

-- Everyone can read published posts
drop policy if exists "public reads published" on public.posts;
create policy "public reads published" on public.posts
  for select to anon, authenticated using (published = true);

-- Signed-in team members can read everything, including drafts
drop policy if exists "admins read all" on public.posts;
create policy "admins read all" on public.posts
  for select to authenticated using (public.is_admin());

-- Owners (parents) can do anything
drop policy if exists "owners insert" on public.posts;
create policy "owners insert" on public.posts
  for insert to authenticated with check (public.is_owner());
drop policy if exists "owners update" on public.posts;
create policy "owners update" on public.posts
  for update to authenticated using (public.is_owner()) with check (public.is_owner());
drop policy if exists "owners delete" on public.posts;
create policy "owners delete" on public.posts
  for delete to authenticated using (public.is_owner());

-- Editors (River) can only create and change their own drafts. They cannot publish.
drop policy if exists "editors insert drafts" on public.posts;
create policy "editors insert drafts" on public.posts
  for insert to authenticated
  with check (public.is_admin() and published = false and author_id = auth.uid());
drop policy if exists "editors update own drafts" on public.posts;
create policy "editors update own drafts" on public.posts
  for update to authenticated
  using (public.is_admin() and author_id = auth.uid() and published = false)
  with check (public.is_admin() and author_id = auth.uid() and published = false);
drop policy if exists "editors delete own drafts" on public.posts;
create policy "editors delete own drafts" on public.posts
  for delete to authenticated
  using (public.is_admin() and author_id = auth.uid() and published = false);

-- 5. Photo storage (public to view, team-only to upload)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('site-images', 'site-images', true, 5242880, array['image/jpeg', 'image/png', 'image/webp', 'image/gif'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "admins read site images" on storage.objects;
create policy "admins read site images" on storage.objects
  for select to authenticated using (bucket_id = 'site-images' and public.is_admin());
drop policy if exists "admins upload site images" on storage.objects;
create policy "admins upload site images" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'site-images' and public.is_admin() and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "admins delete own site images" on storage.objects;
create policy "admins delete own site images" on storage.objects
  for delete to authenticated
  using (bucket_id = 'site-images' and public.is_admin() and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "owners delete any site image" on storage.objects;
create policy "owners delete any site image" on storage.objects
  for delete to authenticated using (bucket_id = 'site-images' and public.is_owner());
