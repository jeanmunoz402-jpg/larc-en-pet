-- =====================================================================
-- Larc en Pet · esquema de Supabase
-- Pégalo completo en Supabase → SQL Editor → New query → Run.
-- Se puede volver a ejecutar sin romper nada.
-- =====================================================================

-- ---------- Administradores (moderación) ----------
create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);
alter table public.admins enable row level security;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;
grant execute on function public.is_admin() to anon, authenticated;

-- ---------- Mascotas ----------
create table if not exists public.pets (
  idx        integer primary key check (idx >= 0 and idx < 1000000),
  name       text not null check (char_length(name) between 1 and 40),
  species    text not null default 'otro' check (species in ('perro','gato','conejo','ave','hamster','pez','tortuga','caballo','otro')),
  born       text check (char_length(born) <= 20),
  died       text check (char_length(died) <= 20),
  epitaph    text check (char_length(epitaph) <= 160),
  photo_url  text check (char_length(photo_url) <= 500),
  by_name    text check (char_length(by_name) <= 40),
  owner      uuid not null default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
alter table public.pets enable row level security;
drop policy if exists "pets: todos leen" on public.pets;
create policy "pets: todos leen" on public.pets for select using (true);
drop policy if exists "pets: con cuenta crean" on public.pets;
create policy "pets: con cuenta crean" on public.pets for insert to authenticated with check (owner = auth.uid());
drop policy if exists "pets: dueño o admin editan" on public.pets;
create policy "pets: dueño o admin editan" on public.pets for update to authenticated using (owner = auth.uid() or public.is_admin());
drop policy if exists "pets: dueño o admin borran" on public.pets;
create policy "pets: dueño o admin borran" on public.pets for delete to authenticated using (owner = auth.uid() or public.is_admin());

-- ---------- Ofrendas: velitas, flores, regalos y libro de visitas ----------
create table if not exists public.offerings (
  id         bigint generated always as identity primary key,
  pet_id     text not null check (pet_id ~ '^p[0-9]{1,6}$'),
  kind       text not null check (kind in ('candle','flower','gift','message')),
  text       text check (char_length(text) <= 400),
  color      text check (color ~ '^#[0-9a-fA-F]{6}$'),
  author     text check (char_length(author) <= 40),
  user_id    uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists offerings_created_idx on public.offerings (created_at desc);
create index if not exists offerings_pet_idx on public.offerings (pet_id);
alter table public.offerings enable row level security;
drop policy if exists "ofrendas: todos leen" on public.offerings;
create policy "ofrendas: todos leen" on public.offerings for select using (true);
-- Velitas, flores y regalos son libres; los mensajes del libro de visitas requieren cuenta.
drop policy if exists "ofrendas: crear" on public.offerings;
create policy "ofrendas: crear" on public.offerings for insert to anon, authenticated
  with check (kind in ('candle','flower','gift') or (kind = 'message' and auth.uid() is not null and user_id = auth.uid()));
drop policy if exists "ofrendas: autor o admin borran" on public.offerings;
create policy "ofrendas: autor o admin borran" on public.offerings for delete to authenticated using (user_id = auth.uid() or public.is_admin());

-- ---------- Chat (hall y cada memorial) ----------
create table if not exists public.chat_messages (
  id         bigint generated always as identity primary key,
  room       text not null check (room = 'hall' or room ~ '^p[0-9]{1,6}$'),
  text       text not null check (char_length(text) between 1 and 280),
  author     text check (char_length(author) <= 40),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  hidden     boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists chat_room_created_idx on public.chat_messages (room, created_at desc);
alter table public.chat_messages enable row level security;
drop policy if exists "chat: todos leen lo visible" on public.chat_messages;
create policy "chat: todos leen lo visible" on public.chat_messages for select using (hidden = false or public.is_admin());
drop policy if exists "chat: con cuenta escriben" on public.chat_messages;
create policy "chat: con cuenta escriben" on public.chat_messages for insert to authenticated with check (user_id = auth.uid() and hidden = false);
drop policy if exists "chat: autor o admin borran" on public.chat_messages;
create policy "chat: autor o admin borran" on public.chat_messages for delete to authenticated using (user_id = auth.uid() or public.is_admin());
drop policy if exists "chat: admin oculta" on public.chat_messages;
create policy "chat: admin oculta" on public.chat_messages for update to authenticated using (public.is_admin());

-- Límite anti-spam: máximo 5 mensajes cada 30 segundos por persona.
create or replace function public.chat_rate_limit() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.chat_messages
      where user_id = new.user_id and created_at > now() - interval '30 seconds') >= 5 then
    raise exception 'Vas muy rápido. Espera un momento.';
  end if;
  return new;
end $$;
drop trigger if exists chat_rate_limit on public.chat_messages;
create trigger chat_rate_limit before insert on public.chat_messages for each row execute function public.chat_rate_limit();

-- Ocultar automáticamente un mensaje con 3 reportes o más.
create table if not exists public.reports (
  id         bigint generated always as identity primary key,
  message_id bigint not null references public.chat_messages(id) on delete cascade,
  reason     text check (char_length(reason) <= 200),
  reporter   uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (message_id, reporter)
);
alter table public.reports enable row level security;
drop policy if exists "reportes: con cuenta reportan" on public.reports;
create policy "reportes: con cuenta reportan" on public.reports for insert to authenticated with check (reporter = auth.uid());
drop policy if exists "reportes: admin lee" on public.reports;
create policy "reportes: admin lee" on public.reports for select to authenticated using (public.is_admin());

create or replace function public.auto_hide_reported() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.reports where message_id = new.message_id) >= 3 then
    update public.chat_messages set hidden = true where id = new.message_id;
  end if;
  return new;
end $$;
drop trigger if exists auto_hide_reported on public.reports;
create trigger auto_hide_reported after insert on public.reports for each row execute function public.auto_hide_reported();

-- ---------- Tiempo real ----------
do $$ begin
  begin alter publication supabase_realtime add table public.pets; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.offerings; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.chat_messages; exception when duplicate_object then null; end;
end $$;

-- ---------- Fotos (Storage) ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photos', 'photos', true, 2097152, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = true, file_size_limit = 2097152, allowed_mime_types = array['image/jpeg','image/png','image/webp'];

drop policy if exists "fotos: todos ven" on storage.objects;
create policy "fotos: todos ven" on storage.objects for select using (bucket_id = 'photos');
drop policy if exists "fotos: con cuenta suben a su carpeta" on storage.objects;
create policy "fotos: con cuenta suben a su carpeta" on storage.objects for insert to authenticated
  with check (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "fotos: dueño borra" on storage.objects;
create policy "fotos: dueño borra" on storage.objects for delete to authenticated
  using (bucket_id = 'photos' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));

-- ---------- Para hacerte administrador ----------
-- 1) Inicia sesión una vez en la app.
-- 2) Busca tu id en Authentication → Users y ejecuta:
--    insert into public.admins (user_id) values ('TU-ID-AQUI');
