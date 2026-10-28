-- Altar de Muertos Virtual: tabla, fotos y reglas.
-- Pégalo completo en Supabase → SQL Editor → New query → Run. Se corre una sola vez.

-- 1. Ofrendas
create table if not exists public.ofrendas (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  nombre      text not null check (char_length(nombre) between 1 and 60),
  anios       text check (char_length(anios) <= 30),
  quien_fue   text check (char_length(quien_fue) <= 80),
  origen      text check (char_length(origen) <= 60),
  autor       text not null check (char_length(autor) between 1 and 60),
  relacion    text check (char_length(relacion) <= 40),
  comidas     jsonb not null default '[]'::jsonb
              check (jsonb_typeof(comidas) = 'array' and jsonb_array_length(comidas) <= 14),
  mensaje     text check (char_length(mensaje) <= 220),
  foto        text not null check (foto like 'https://%'),
  platillos   jsonb not null default '[]'::jsonb
              check (jsonb_typeof(platillos) = 'array' and jsonb_array_length(platillos) <= 3)
);

-- La hora la pone el servidor (así nadie se adelanta en la fila de turnos).
create or replace function public.fijar_hora() returns trigger
language plpgsql as $$
begin
  new.created_at := now();
  return new;
end $$;
drop trigger if exists fijar_hora on public.ofrendas;
create trigger fijar_hora before insert on public.ofrendas
  for each row execute function public.fijar_hora();

-- 2. Reglas: todos pueden ver y poner ofrendas; nadie puede cambiarlas ni borrarlas desde la página.
--    Para quitar una ofrenda: Table Editor → ofrendas → seleccionar fila → Delete.
alter table public.ofrendas enable row level security;
drop policy if exists "todos ven el altar" on public.ofrendas;
create policy "todos ven el altar" on public.ofrendas
  for select to anon, authenticated using (true);
drop policy if exists "todos ponen ofrenda" on public.ofrendas;
create policy "todos ponen ofrenda" on public.ofrendas
  for insert to anon, authenticated with check (true);

-- 3. Avisos en vivo al proyector cuando llega una ofrenda
do $$ begin
  alter publication supabase_realtime add table public.ofrendas;
exception when duplicate_object then null; end $$;

-- 4. Fotos: carpeta pública de solo JPEG, máximo 1 MB por foto
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fotos', 'fotos', true, 1048576, array['image/jpeg'])
on conflict (id) do nothing;
drop policy if exists "todos suben fotos" on storage.objects;
create policy "todos suben fotos" on storage.objects
  for insert to anon, authenticated with check (bucket_id = 'fotos');
