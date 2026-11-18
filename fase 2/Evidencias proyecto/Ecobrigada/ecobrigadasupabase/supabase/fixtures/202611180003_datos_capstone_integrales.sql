-- ECOBRIGADA 3.1: DATASET SINTÉTICO DE PRUEBAS - GRAN CONCEPCIÓN
-- EJECUTAR MANUALMENTE SOLO EN UN PROYECTO DE PRUEBAS O TRAS RESPALDO.
-- REQUIERE migraciones 202611170001, 202611170002 y 202611180001.
-- REQUIERE también el SQL de administrador y las 26 cuentas @example.com
-- creadas por scripts/provisionar_usuarios_prueba.py.
-- Identificadores deterministas: repetir este archivo NO duplica estas filas.
-- NINGUNA de estas incidencias, ubicaciones, jornadas o mensajes es real.
-- No crea fotografías; las evidencias reales deben cargarse desde la app.
begin;

do $$
begin
 if not exists(select 1 from auth.users where lower(email)='seba@gmail.com') or
    not exists(select 1 from public.perfiles p join auth.users u on p.id=u.id
      where lower(u.email)='seba@gmail.com' and p.role='admin') then
   raise exception 'Primero ejecuta admin/202611180002_promover_seba_admin.sql';
 end if;
 if (select count(*) from generate_series(1,20) n
      join auth.users u on lower(u.email)=
        ('lider'||lpad(n::text,2,'0')||'.ecobrigada@example.com')) < 20
    or (select count(*) from generate_series(1,6) n
      join auth.users u on lower(u.email)=
        ('ciudadano'||lpad(n::text,2,'0')||'.ecobrigada@example.com')) < 6 then
   raise exception 'Faltan cuentas de prueba. Ejecuta scripts/provisionar_usuarios_prueba.py';
 end if;
end $$;

-- A. NUEVE BRIGADAS NUEVAS. El jefe es una cuenta Auth ficticia distinta.
with equipos(numero,nombre,comuna,lat,lng) as (values
 (1,'EcoBarrio Collao (ficticia)','Concepción',-36.84210,-73.02520),
 (2,'Guardianes Barrio Norte (ficticia)','Concepción',-36.81130,-73.05420),
 (3,'EcoRibera Boca Sur (ficticia)','San Pedro de la Paz',-36.85980,-73.11950),
 (4,'Humedales Candelaria (ficticia)','San Pedro de la Paz',-36.84830,-73.10410),
 (5,'Costa Higueras (ficticia)','Talcahuano',-36.71920,-73.09100),
 (6,'EcoLaguna Lo Méndez (ficticia)','Concepción',-36.80570,-73.03510),
 (7,'Red Ambiental Lota (ficticia)','Lota',-37.09150,-73.15800),
 (8,'EcoVecinos Tomé (ficticia)','Tomé',-36.61700,-72.95810),
 (9,'Verde Hualqui (ficticia)','Hualqui',-36.97520,-72.93230)
)
insert into public.brigadas(id,nombre,comuna,descripcion,creador_id,lider_uid,
 lat,lng,estado,disponible)
select md5('eco31-brigada-'||e.numero)::uuid,e.nombre,e.comuna,
 '[FICTICIO QA-31] Equipo de ensayo de EcoBrigada. Los datos son inventados; no representa un colectivo real.',
 u.id,u.id,e.lat,e.lng,'abierta',true
from equipos e join auth.users u
  on lower(u.email)=('lider'||lpad(e.numero::text,2,'0')||'.ecobrigada@example.com')
on conflict(id) do nothing;

-- B. LOS SIETE EQUIPOS FICTICIOS PREVIOS TAMBIÉN RECIBEN JEFES DISTINTOS.
-- NO alteramos el liderazgo de brigadas auténticas de la organización.
with anteriores(id,numero) as (values
 ('fec126f8-a523-53be-9b08-837242363e01'::uuid,10),
 ('fa31e029-5581-51c5-8eb8-6b24fbd1e8ec'::uuid,11),
 ('9d85ecbc-4267-5613-b87c-e48712f134cd'::uuid,12),
 ('aec9c825-20cc-58ca-9135-c14ae8a954ca'::uuid,13),
 ('bcfe60e9-999c-52fa-ac6a-e7e63aa0a5a6'::uuid,14),
 ('f9f195b4-86ff-5bad-97aa-100272cc6a59'::uuid,15),
 ('d0135d64-5405-560e-a00e-5a8ed9547cbf'::uuid,16)
)
update public.brigadas b set lider_uid=u.id
from anteriores a join auth.users u
 on lower(u.email)=('lider'||lpad(a.numero::text,2,'0')||'.ecobrigada@example.com')
where b.id=a.id and lower(b.nombre) like '%fictici%';

-- C. SINCRONIZA EL ROL DENTRO DE CADA BRIGADA FICTICIA.
-- Los antiguos creadores quedan como integrantes, pero no reciben permisos de jefe.
with ids as (
 select id from public.brigadas where
  id in (select md5('eco31-brigada-'||n)::uuid from generate_series(1,9) n)
  or id in (
   'fec126f8-a523-53be-9b08-837242363e01'::uuid,
   'fa31e029-5581-51c5-8eb8-6b24fbd1e8ec'::uuid,
   '9d85ecbc-4267-5613-b87c-e48712f134cd'::uuid,
   'aec9c825-20cc-58ca-9135-c14ae8a954ca'::uuid,
   'bcfe60e9-999c-52fa-ac6a-e7e63aa0a5a6'::uuid,
   'f9f195b4-86ff-5bad-97aa-100272cc6a59'::uuid,
   'd0135d64-5405-560e-a00e-5a8ed9547cbf'::uuid)
)
update public.brigada_miembros m set rol='miembro'
from public.brigadas b join ids on ids.id=b.id
where m.brigada_id=b.id and m.usuario_id<>b.lider_uid
  and m.rol='administrador';

insert into public.brigada_miembros(brigada_id,usuario_id,rol)
select b.id,b.lider_uid,'administrador' from public.brigadas b
where b.lider_uid is not null and (
 b.id in (select md5('eco31-brigada-'||n)::uuid from generate_series(1,9) n)
 or b.id in (
   'fec126f8-a523-53be-9b08-837242363e01'::uuid,
   'fa31e029-5581-51c5-8eb8-6b24fbd1e8ec'::uuid,
   '9d85ecbc-4267-5613-b87c-e48712f134cd'::uuid,
   'aec9c825-20cc-58ca-9135-c14ae8a954ca'::uuid,
   'bcfe60e9-999c-52fa-ac6a-e7e63aa0a5a6'::uuid,
   'd0135d64-5405-560e-a00e-5a8ed9547cbf'::uuid,
   'f9f195b4-86ff-5bad-97aa-100272cc6a59'::uuid))
on conflict (brigada_id,usuario_id) do update set rol='administrador';

-- D. JORNADAS CON ESTADOS PASADOS, EN CURSO Y FUTUROS (36 NUEVAS).
with equipos as (
 select n,b.id,b.lat,b.lng from generate_series(1,9) n
 join public.brigadas b on b.id=md5('eco31-brigada-'||n)::uuid
), jornadas as (
 select e.*,j,
 case when j=1 then 'finalizada'
      when j=2 then 'en_curso' else 'programada' end as estado,
 case when j=1 then now()-interval '21 days'
      when j=2 then now()-interval '1 days'
      when j=3 then now()+interval '7 days'
      else now()+interval '18 days' end as fecha
 from equipos e cross join generate_series(1,4) j
)
insert into public.actividades(id,brigada_id,titulo,descripcion,latitud,
 longitud,fecha_inicio,estado)
select md5('eco31-jornada-'||n||'-'||j)::uuid,id,
 '[FICTICIO] Jornada ambiental '||n||'.'||j,
 '[FICTICIO QA-31] Actividad ambiental de prueba: retiro de basura y educación comunitaria.',
 lat,lng,fecha,estado
from jornadas on conflict(id) do nothing;

-- E. CHATS CON MENSAJES DE BIENVENIDA POR EL JEFE (18 MENSAJES).
insert into public.mensajes(id,brigada_id,autor_id,texto,enviado_en)
select md5('eco31-chat-'||n||'-'||j)::uuid,b.id,b.lider_uid,
 case when j=1 then '[FICTICIO] Bienvenidos al equipo. Este chat se usa para coordinar las jornadas.'
 else '[FICTICIO] Recuerden registrar fotos de antes/después y el informe final.' end,
 now()-(10-j)*interval '1 days'
from generate_series(1,9) n
join public.brigadas b on b.id=md5('eco31-brigada-'||n)::uuid
cross join generate_series(1,2) j
on conflict(id) do nothing;

-- F. CIUDADANOS DE PRUEBA: seis miembros aprobados y seis solicitudes pendientes.
insert into public.brigada_miembros(brigada_id,usuario_id,rol)
select b.id,u.id,'miembro'
from generate_series(1,6) n
join public.brigadas b on b.id=md5('eco31-brigada-'||n)::uuid
join auth.users u on lower(u.email)=('ciudadano'||lpad(n::text,2,'0')||'.ecobrigada@example.com')
on conflict(brigada_id,usuario_id) do nothing;
insert into public.solicitudes(id,brigada_id,usuario_id,mensaje,estado,enviada_en)
select md5('eco31-solicitud-'||n)::uuid,b.id,u.id,
 '[FICTICIO] Solicito participar de las actividades de la brigada.','pendiente',
 now()-(n%3)*interval '1 days'
from generate_series(1,6) n
join public.brigadas b on b.id=md5('eco31-brigada-'||(n+3))::uuid
join auth.users u on lower(u.email)=('ciudadano'||lpad(n::text,2,'0')||'.ecobrigada@example.com')
on conflict(id) do nothing;

-- G. 240 INCIDENCIAS NUEVAS: 12 ZONAS x 20 CASOS.
-- Los reportes abiertos se agrupan a menos de 250m para EcoZonas.
-- Los casos cerrados 1-4 y los recientes 5-7 son del mismo tipo y
-- están próximos, para demostrar posibles reincidencias.
-- Se evitan notificaciones artificiales a cuentas reales.
alter table public.incidencias disable trigger tr_nueva_incidencia_aviso;
alter table public.incidencias disable trigger tr_preparar_incidencia;
with sectores(n,comuna,sector,lat,lng) as (values
 (1,'Concepción','Nonguén',-36.8587,-73.0271),
 (2,'Concepción','Collao',-36.8421,-73.0252),
 (3,'Concepción','Barrio Norte',-36.8113,-73.0542),
 (4,'San Pedro de la Paz','Candelaria',-36.8483,-73.1041),
 (5,'San Pedro de la Paz','Boca Sur',-36.8598,-73.1195),
 (6,'Talcahuano','Las Higueras',-36.7192,-73.0910),
 (7,'Talcahuano','Centro',-36.7251,-73.1135),
 (8,'Hualpén','Sector Ribera',-36.7784,-73.1078),
 (9,'Chiguayante','Zona Central',-36.9270,-73.0355),
 (10,'Penco','Sector Playa',-36.7372,-72.9948),
 (11,'Coronel','Zona Urbana',-37.0155,-73.1489),
 (12,'Tomé','Sector Costero',-36.6170,-72.9581)
), reportes as (
 select s.*,g.caso as caso,
 case when g.caso between 1 and 4 then 'cerrado'
      when g.caso between 5 and 7 then 'pendiente'
      when g.caso between 8 and 9 then 'validado'
      when g.caso between 10 and 12 then 'asignado'
      when g.caso between 13 and 15 then 'en_proceso'
      when g.caso between 16 and 17 then 'en_revision'
      when g.caso=18 then 'descartado'
      else 'pendiente' end as estado,
 case when g.caso between 1 and 7 then 'Basura'
      when g.caso%3=0 then 'Escombros'
      when g.caso%3=1 then 'Microbasural' else 'Otro' end as tipo,
 case when g.caso in (5,6,19,20) then 88
      when g.caso between 13 and 17 then 78
      else least(99,24+(g.caso%5)*13) end as prioridad,
 case when g.caso between 1 and 4 then now()-((70-g.caso*3)::text||' days')::interval
      when g.caso between 5 and 7 then now()-((6+g.caso%3)::text||' days')::interval
      else now()-((5+g.caso*2+s.n%6)::text||' days')::interval end as fecha_creacion,
 case when g.caso between 1 and 4 then now()-((32-g.caso*3)::text||' days')::interval
      else null::timestamptz end as cierre
 from sectores s cross join generate_series(1,20) as g(caso)
), admin as (
 select u.id from auth.users u join public.perfiles p on p.id=u.id
 where lower(u.email)='seba@gmail.com' and p.role='admin'
)
insert into public.incidencias(id,titulo,descripcion,tipo,direccion,comuna,
 lat,lng,gravedad,prioridad,estado,creador_uid,brigada_id,creado_en,actualizado_en,cerrado_en)
select md5('eco31-incidencia-'||r.n||'-'||r.caso)::uuid,
 '[FICTICIO QA-31] '||r.tipo||' - '||r.sector||' #'||r.caso,
 '[FICTICIO QA-31] Registro sintético para pruebas de agrupación, vencimientos, tendencias, asignaciones y reincidencia. NO representa una denuncia ni una limpieza comprobada.',
 r.tipo,'Sector referencial '||r.sector||' (ubicación inventada)',r.comuna,
 r.lat+((r.caso%5)-2)*0.00022, r.lng+((r.caso%4)-1.5)*0.00026,
 1+(r.caso%5),r.prioridad,r.estado,a.id,
 case when r.estado in ('asignado','en_proceso','en_revision','cerrado')
      then md5('eco31-brigada-'||(1+(r.n-1)%9))::uuid
      else null end,
 r.fecha_creacion,case when r.cierre is not null then r.cierre
      else r.fecha_creacion+interval '1 day' end,r.cierre
from reportes r cross join admin a
on conflict(id) do nothing;
alter table public.incidencias enable trigger tr_preparar_incidencia;
alter table public.incidencias enable trigger tr_nueva_incidencia_aviso;

-- H. HISTORIAL INDICA EXPRESAMENTE QUE NO SON OPERACIONES VERIFICADAS.
insert into public.historial_incidencias(id,reporte_id,anterior,nuevo,autor_uid,comentario,fecha)
select md5('eco31-historial-'||i.id)::uuid,i.id,'carga_sintetica',i.estado,i.creador_uid,
 '[FICTICIO QA-31] Estado preparado para probar EcoImpacto. No hubo trabajo real.',
 i.actualizado_en
from public.incidencias i where i.titulo like '[FICTICIO QA-31] %'
on conflict(id) do nothing;

-- I. PUNTOS DEL MAPA, NO VERIFICADOS Y ETIQUETADOS COMO SIMULADOS.
insert into public.puntos_reciclaje(id,nombre,descripcion,comuna,lat,lng,verificado)
select md5('eco31-reciclaje-'||s.n)::uuid,
 '[FICTICIO] Reciclaje '||s.sector,
 'Marcador solamente de prueba: NO corresponde a un punto limpio verificado.',
 s.comuna,s.lat+0.0009,s.lng-0.0007,false
from (values
 (1,'Concepción','Nonguén',-36.8587,-73.0271),
 (2,'Concepción','Collao',-36.8421,-73.0252),
 (3,'Concepción','Barrio Norte',-36.8113,-73.0542),
 (4,'San Pedro de la Paz','Candelaria',-36.8483,-73.1041),
 (5,'San Pedro de la Paz','Boca Sur',-36.8598,-73.1195),
 (6,'Talcahuano','Las Higueras',-36.7192,-73.0910),
 (7,'Talcahuano','Centro',-36.7251,-73.1135),
 (8,'Hualpén','Ribera',-36.7784,-73.1078),
 (9,'Chiguayante','Centro',-36.9270,-73.0355),
 (10,'Penco','Playa',-36.7372,-72.9948),
 (11,'Coronel','Urbano',-37.0155,-73.1489),
 (12,'Tomé','Costero',-36.6170,-72.9581)
) as s(n,comuna,sector,lat,lng)
on conflict(id) do nothing;

-- J. LUGARES COMUNITARIOS LIMPIOS/SUCIOS DEL SISTEMA ORIGINAL.
with administrador as (
 select u.id from auth.users u join public.perfiles p on p.id=u.id
 where lower(u.email)='seba@gmail.com' and p.role='admin'
)
insert into public.lugares(id,nombre,descripcion,latitud,longitud,estado,creado_por)
select md5('eco31-lugar-'||n)::uuid,
 '[FICTICIO] Punto comunitario '||n,
 '[FICTICIO QA-31] Ubicación inventada para probar el mapa original. No es una constatación ambiental.',
 -36.82+(n-6)*0.012,-73.06+(n%5)*0.011,
 case when n%2=0 then 'limpio' else 'sucio' end,admin.id
from generate_series(1,12) n cross join administrador admin
on conflict(id) do nothing;

commit;
-- FIN: todo sintético, reproducible e idempotente por identificadores fijos.
