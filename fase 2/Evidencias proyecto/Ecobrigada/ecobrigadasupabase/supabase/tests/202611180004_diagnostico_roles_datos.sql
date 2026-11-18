-- Consultas SOLO LECTURA. Ejecutar desde SQL Editor después de migrar y cargar.
-- Las cifras mostradas no son evidencia de contaminación real.
select
 to_regclass('public.perfiles') as perfiles,
 to_regclass('public.incidencias') as incidencias,
 to_regclass('public.informes_finales_brigada') as informes_finales,
 to_regclass('public.actividades') as jornadas,
 to_regclass('public.solicitudes') as solicitudes;

select u.email,p.role from auth.users u join public.perfiles p on p.id=u.id
where lower(u.email)='seba@gmail.com';

select b.nombre,b.comuna,u.email as correo_jefe,b.lider_uid,
 (select count(*) from public.solicitudes s where s.brigada_id=b.id
   and s.estado='pendiente' and s.actividad_id is null) as solicitudes_pendientes
from public.brigadas b left join auth.users u on u.id=b.lider_uid
where lower(b.nombre) like '%fictici%'
order by b.nombre;

select count(*) as incidencias_sinteticas,
 count(*) filter(where i.estado='cerrado') as cerradas,
 count(*) filter(where i.estado='pendiente') as pendientes,
 count(*) filter(where i.estado='asignado') as asignadas,
 count(*) filter(where i.estado='en_proceso') as en_proceso,
 count(*) filter(where i.estado='en_revision') as en_revision,
 count(*) filter(where i.estado='descartado') as descartadas,
 count(*) filter(where i.estado not in ('cerrado','descartado') and
   (case when i.prioridad>=75 then 2
         when i.prioridad>=45 then 5 else 10 end)*interval '1 day'
     < now()-i.creado_en) as vencidas_estimadas
from public.incidencias i where i.titulo like '[FICTICIO%';

select estado,count(*) from public.actividades
where titulo like '[FICTICIO]%' group by estado order by estado;

select count(*) as nuevas_solicitudes_de_prueba from public.solicitudes
where mensaje like '[FICTICIO]%';

select count(*) as mensajes_de_prueba from public.mensajes
where texto like '[FICTICIO]%';

select count(*) as informes_reales_enviados from public.informes_finales_brigada;

-- Auditoría de duplicación de líderes entre brigadas FICTICIAS únicamente:
select lider_uid,count(*) as brigadas_asignadas
from public.brigadas where lower(nombre) like '%fictici%'
group by lider_uid having count(*)>1;
