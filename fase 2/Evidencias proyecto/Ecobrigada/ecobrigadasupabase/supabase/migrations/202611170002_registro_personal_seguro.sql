-- ECOBRIGADA 3.0 / EXTENSION DE REGISTRO, SOBRE EL SUPABASE ORIGINAL.
-- Ejecutar DESPUÉS de 202611170001_integracion_sin_perder_datos.sql.
-- No modifica ni elimina las cuentas ya creadas.
-- El RUT y la dirección NO van a public.perfiles: esa tabla es visible.

create or replace function public.eco_rut_valido(p_rut text)
returns boolean language plpgsql immutable set search_path = '' as $$
declare
  v text := pg_catalog.upper(pg_catalog.regexp_replace(pg_catalog.btrim(coalesce(p_rut, '')), '[. ]', '', 'g'));
  base text;
  valor integer;
  suma integer := 0;
  factor integer := 2;
  digito text;
  i integer;
begin
  if v !~ '^[0-9]{7,8}-[0-9K]$' then return false; end if;
  base := pg_catalog.split_part(v, '-', 1);
  i := pg_catalog.length(base);
  while i > 0 loop
    valor := pg_catalog.substr(base, i, 1)::integer;
    suma := suma + valor * factor;
    factor := case when factor = 7 then 2 else factor + 1 end;
    i := i - 1;
  end loop;
  valor := 11 - (suma % 11);
  digito := case when valor = 11 then '0'
                 when valor = 10 then 'K'
                 else valor::text end;
  return digito = pg_catalog.split_part(v, '-', 2);
end; $$;

create table if not exists public.perfil_datos_privados (
 usuario_id uuid primary key references auth.users(id) on delete cascade,
 apellido text not null check (char_length(btrim(apellido)) between 2 and 100),
 rut text not null unique check (public.eco_rut_valido(rut)),
 comuna text not null check (char_length(btrim(comuna)) between 2 and 100),
 direccion text check (direccion is null or char_length(direccion) <= 200),
 registrado_en timestamptz not null default now()
);

alter table public.perfil_datos_privados enable row level security;
revoke all on public.perfil_datos_privados from anon, authenticated;
grant select on public.perfil_datos_privados to authenticated;
drop policy if exists eco_solo_yo_veo_datos_privados on public.perfil_datos_privados;
create policy eco_solo_yo_veo_datos_privados on public.perfil_datos_privados
for select to authenticated using (usuario_id = (select auth.uid()));

-- Función activada por Auth al crear cuentas; los usuarios no insertan directamente.
create or replace function public.eco_crear_datos_privados()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_nombre text := pg_catalog.btrim(coalesce(new.raw_user_meta_data->>'nombre', ''));
  v_apellido text := pg_catalog.btrim(coalesce(new.raw_user_meta_data->>'apellido', ''));
  v_rut text := pg_catalog.upper(pg_catalog.regexp_replace(
     pg_catalog.btrim(coalesce(new.raw_user_meta_data->>'rut','')), '[. ]', '', 'g'));
  v_comuna text := pg_catalog.btrim(coalesce(new.raw_user_meta_data->>'comuna', ''));
  v_direccion text := pg_catalog.nullif(pg_catalog.btrim(coalesce(new.raw_user_meta_data->>'direccion', '')), '');
begin
  -- Mantiene compatibilidad con cuentas anteriores e invitaciones que no tengan RUT.
  -- El formulario nuevo sí exige todos los campos obligatorios.
  if v_rut = '' then return new; end if;
  if not public.eco_rut_valido(v_rut) then raise exception 'RUT inválido'; end if;
  if pg_catalog.length(v_nombre)<2 or pg_catalog.length(v_apellido)<2
    or pg_catalog.length(v_comuna)<2 then
    raise exception 'Nombre, apellido y comuna son obligatorios';
  end if;
  insert into public.perfil_datos_privados(usuario_id, apellido, rut, comuna, direccion)
  values(new.id, v_apellido, v_rut, v_comuna, v_direccion);
  -- Conserva el modelo original: perfiles.nombre es el nombre para mostrar.
  update public.perfiles
  set nombre = pg_catalog.left(v_nombre || ' ' || v_apellido, 100)
  where id = new.id;
  return new;
end; $$;

drop trigger if exists eco_auth_datos_privados on auth.users;
create trigger eco_auth_datos_privados after insert on auth.users
for each row execute function public.eco_crear_datos_privados();

-- Prueba de validación (consultar resultado, no cambia datos):
-- select public.eco_rut_valido('12.345.678-5');
-- IMPORTANTE: no usar el editor de perfiles públicos para almacenar RUT/dirección.
