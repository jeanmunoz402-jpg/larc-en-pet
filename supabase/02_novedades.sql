-- =====================================================================
-- Larc en Pet · actualización 2: fechas especiales, recuerdos y servicios
-- Pégalo completo en Supabase → SQL Editor → New query → Run.
-- Se puede ejecutar más de una vez sin problema.
-- =====================================================================

-- ---------- Fechas exactas en cada mascota ----------
alter table public.pets add column if not exists birth_date text check (birth_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$');
alter table public.pets add column if not exists death_date text check (death_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$');

-- ---------- Recuerdos (fotos e historias de cada mascota) ----------
create table if not exists public.memories (
  id         bigint generated always as identity primary key,
  pet_id     text not null check (pet_id ~ '^p[0-9]{1,6}$'),
  text       text check (char_length(text) <= 600),
  photo_url  text check (char_length(photo_url) <= 500),
  author     text check (char_length(author) <= 40),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  check (text is not null or photo_url is not null)
);
create index if not exists memories_pet_idx on public.memories (pet_id, created_at desc);
alter table public.memories enable row level security;

-- ¿Es la persona dueña de esta mascota?
create or replace function public.owns_pet(p text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.pets where 'p' || idx = p and owner = auth.uid());
$$;
grant execute on function public.owns_pet(text) to anon, authenticated;

drop policy if exists "recuerdos: todos leen" on public.memories;
create policy "recuerdos: todos leen" on public.memories for select using (true);
drop policy if exists "recuerdos: dueño o admin agregan" on public.memories;
create policy "recuerdos: dueño o admin agregan" on public.memories for insert to authenticated
  with check (user_id = auth.uid() and (public.owns_pet(pet_id) or public.is_admin()));
drop policy if exists "recuerdos: dueño o admin borran" on public.memories;
create policy "recuerdos: dueño o admin borran" on public.memories for delete to authenticated
  using (user_id = auth.uid() or public.owns_pet(pet_id) or public.is_admin());

-- ---------- Directorio de servicios (lo administra el admin) ----------
create table if not exists public.services (
  id          bigint generated always as identity primary key,
  category    text not null check (category in ('cremacion','veterinaria','recuerdos','retratos','duelo','otros')),
  name        text not null check (char_length(name) between 1 and 80),
  description text check (char_length(description) <= 400),
  city        text check (char_length(city) <= 60),
  url         text check (url ~ '^https?://' and char_length(url) <= 300),
  phone       text check (char_length(phone) <= 40),
  featured    boolean not null default false,
  created_at  timestamptz not null default now()
);
alter table public.services enable row level security;
drop policy if exists "servicios: todos leen" on public.services;
create policy "servicios: todos leen" on public.services for select using (true);
drop policy if exists "servicios: admin escribe" on public.services;
create policy "servicios: admin escribe" on public.services for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------- Postulaciones de servicios ----------
create table if not exists public.service_requests (
  id          bigint generated always as identity primary key,
  name        text not null check (char_length(name) between 1 and 80),
  category    text not null default 'otros' check (category in ('cremacion','veterinaria','recuerdos','retratos','duelo','otros')),
  city        text check (char_length(city) <= 60),
  contact     text not null check (char_length(contact) between 3 and 120),
  description text check (char_length(description) <= 600),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at  timestamptz not null default now()
);
alter table public.service_requests enable row level security;
drop policy if exists "postulaciones: con cuenta envían" on public.service_requests;
create policy "postulaciones: con cuenta envían" on public.service_requests for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "postulaciones: admin lee" on public.service_requests;
create policy "postulaciones: admin lee" on public.service_requests for select to authenticated using (public.is_admin());
drop policy if exists "postulaciones: admin borra" on public.service_requests;
create policy "postulaciones: admin borra" on public.service_requests for delete to authenticated using (public.is_admin());

-- ---------- Tiempo real ----------
do $$ begin
  begin alter publication supabase_realtime add table public.memories; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.services; exception when duplicate_object then null; end;
end $$;
