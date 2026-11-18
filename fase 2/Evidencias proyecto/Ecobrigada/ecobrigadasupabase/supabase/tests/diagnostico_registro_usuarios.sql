-- EcoBrigada: consultas SOLO DE LECTURA para HTTP 500 al crear usuarios.
-- NO borra ni modifica tablas, triggers o permisos.

-- 1. Estado de las cuentas ficticias esperadas
select
  count(*) filter(where email like 'lider%.ecobrigada@example.com') as jefes,
  count(*) filter(where email like 'ciudadano%.ecobrigada@example.com') as ciudadanos
from auth.users;

-- 2. Triggers de altas de usuarios y sus funciones
select t.tgname as trigger,
       p.proname as funcion,
       pg_get_functiondef(p.oid) as codigo_funcion
from pg_trigger t
join pg_proc p on p.oid=t.tgfoid
where t.tgrelid = 'auth.users'::regclass
  and not t.tgisinternal
order by t.tgname;

-- 3. Restricciones del perfil y datos privados
select conrelid::regclass as tabla, conname as restriccion,
       pg_get_constraintdef(oid) as definicion
from pg_constraint
where conrelid in ('public.perfiles'::regclass,
                   'public.perfil_datos_privados'::regclass)
order by tabla, restriccion;

-- 4. La funcion publica debe aceptar el RUT sintetico, si esta instalada
-- select public.eco_rut_valido('99000001-...'); -- remplazar DV

-- Si HTTP 500 continua, revisa en Supabase > Logs & Analytics > Postgres Logs.
-- Busca 'Database error creating new user' y errores con referencia a los triggers.
