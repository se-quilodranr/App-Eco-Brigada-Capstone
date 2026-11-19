-- Supabase SQL Editor. Solo lectura.
-- 1. Confirma que todos los RPC administrativos fueron instalados.
SELECT p.proname AS funcion, pg_get_function_identity_arguments(p.oid) AS argumentos
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname LIKE 'eco_admin_%'
ORDER BY p.proname;

-- 2. Confirma tu(s) administrador(es) existentes. No cambia ningún permiso.
SELECT u.email,p.nombre,p.role,p.creado_en
FROM auth.users u JOIN public.perfiles p ON p.id=u.id
WHERE p.role='admin'
ORDER BY p.creado_en;

-- 3. Contadores generales para contrastar con la web.
SELECT
 (SELECT count(*) FROM public.perfiles) AS usuarios,
 (SELECT count(*) FROM public.brigadas) AS brigadas,
 (SELECT count(*) FROM public.incidencias) AS incidencias,
 (SELECT count(*) FROM public.incidencias WHERE estado='cerrado') AS cerradas,
 (SELECT count(*) FROM public.actividades) AS jornadas;

-- Importante: los RPC administrativos fallarán si se llaman directamente
-- en SQL Editor sin un token de sesión de Auth. Es deliberado.
