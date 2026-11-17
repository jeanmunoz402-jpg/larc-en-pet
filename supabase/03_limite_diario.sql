-- Larc en Pet · actualización 3: una ofrenda de cada tipo por día
-- Cada persona puede dejar, por memorial y por día (hora de Chile):
-- 1 velita, 1 flor, 1 regalo y 1 mensaje. Para dejar algo hay que tener cuenta.
-- Pégalo completo en Supabase → SQL Editor → New query → Run.

drop policy if exists "ofrendas: crear" on public.offerings;
create policy "ofrendas: crear" on public.offerings for insert to authenticated
  with check (auth.uid() is not null and user_id = auth.uid());

create index if not exists offerings_user_pet_idx on public.offerings (user_id, pet_id, kind, created_at desc);

create or replace function public.offerings_daily_limit() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if exists (
    select 1 from public.offerings
    where user_id = new.user_id and pet_id = new.pet_id and kind = new.kind
      and (created_at at time zone 'America/Santiago')::date = (now() at time zone 'America/Santiago')::date
  ) then
    raise exception 'daily_limit';
  end if;
  return new;
end $$;

drop trigger if exists offerings_daily_limit on public.offerings;
create trigger offerings_daily_limit before insert on public.offerings
  for each row execute function public.offerings_daily_limit();
