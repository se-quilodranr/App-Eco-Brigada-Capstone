-- Consultas NO destructivas para verificar la instalación.
select to_regclass('public.perfiles') is not null as perfiles_originales,
       to_regclass('public.brigadas') is not null as brigadas_originales,
       to_regclass('public.mensajes') is not null as mensajes_originales,
       to_regclass('public.publicaciones') is not null as publicaciones_originales,
       to_regclass('public.incidencias') is not null as incidencias_nuevas,
       to_regclass('public.fotos_incidencia') is not null as fotos_nuevas,
       to_regclass('public.lugar_historial') is not null as historial_original;
select tablename, rowsecurity from pg_tables
where schemaname='public' and tablename in ('perfiles','brigadas','mensajes','incidencias','fotos_incidencia','notificaciones');
select name, public from storage.buckets where id in ('publicaciones','eco-evidencias');
-- ¡No ejecutar cambios de rol desde una sesión de usuario no autorizada!
