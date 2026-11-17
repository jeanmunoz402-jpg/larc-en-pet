-- Larc en Pet · actualización 4: redes sociales de cada mascota
-- Guarda el @usuario de Instagram y TikTok, y la página de Facebook, para mostrarlos en su memorial.
-- Pégalo completo en Supabase → SQL Editor → New query → Run.

alter table public.pets add column if not exists instagram text check (instagram ~ '^[A-Za-z0-9._]{1,30}$');
alter table public.pets add column if not exists tiktok    text check (tiktok ~ '^[A-Za-z0-9._]{2,24}$');
alter table public.pets add column if not exists facebook  text check (facebook ~ '^[A-Za-z0-9.\-]{3,60}$');
