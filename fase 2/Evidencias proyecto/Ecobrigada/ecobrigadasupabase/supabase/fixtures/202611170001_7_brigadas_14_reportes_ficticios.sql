-- ECOBRIGADA 3.0: DATOS FICTICIOS OPTATIVOS SOBRE LA BASE REAL.
-- EJECUTA: base_original (si procede) → migración 001 → migración 002 → ESTE SEED.
-- Ejecutar manualmente DESDE SUPABASE SQL EDITOR (rol postgres).
-- CREA EXACTAMENTE SIETE BRIGADAS Y CATORCE REPORTES CON UUID FIJOS.
-- Todos los nombres incluyen FICTICIO; ubicaciones, resultados y fechas NO SON REALES.
-- El script es idempotente: volver a ejecutarlo NO duplica los registros.
-- No crea cuentas inventadas. Utiliza la primera cuenta existente con role='admin'.
-- No borra registros previos. Haz respaldo antes de ejecutar cualquier SQL.

begin;
do $$ begin
 if not exists(select 1 from public.perfiles where role='admin') then
   raise exception 'Primero registra una cuenta real y asígnale role=admin en public.perfiles.';
 end if;
end $$;

-- 1) Brigadas ficticias. El trigger original agrega al creador como miembro.
insert into public.brigadas(id,nombre,comuna,descripcion,creador_id,lider_uid,lat,lng,estado,disponible)
 select 'fec126f8-a523-53be-9b08-837242363e01'::uuid,'Brigada Bosque Nonguén (ficticia)','Concepción','Equipo de prueba orientado al cuidado de áreas verdes y retiro de residuos en senderos.', p.id,p.id,-36.8587,-73.0271,'abierta',true
 from public.perfiles p where p.role='admin' order by p.creado_en limit 1
 on conflict(id) do nothing;
insert into public.brigadas(id,nombre,comuna,descripcion,creador_id,lider_uid,lat,lng,estado,disponible)
 select 'fa31e029-5581-51c5-8eb8-6b24fbd1e8ec'::uuid,'Brigada Costa Talcahuano (ficticia)','Talcahuano','Grupo ficticio de limpieza costera y seguimiento de microbasurales urbanos.', p.id,p.id,-36.7251,-73.1135,'abierta',true
 from public.perfiles p where p.role='admin' order by p.creado_en limit 1
 on conflict(id) do nothing;
insert into public.brigadas(id,nombre,comuna,descripcion,creador_id,lider_uid,lat,lng,estado,disponible)
 select '9d85ecbc-4267-5613-b87c-e48712f134cd'::uuid,'Brigada Humedales San Pedro (ficticia)','San Pedro de la Paz','Comunidad de prueba enfocada en humedales y prevención de puntos críticos.', p.id,p.id,-36.8463,-73.1072,'abierta',true
 from public.perfiles p where p.role='admin' order by p.creado_en limit 1
 on conflict(id) do nothing;
insert into public.brigadas(id,nombre,comuna,descripcion,creador_id,lider_uid,lat,lng,estado,disponible)
 select 'aec9c825-20cc-58ca-9135-c14ae8a954ca'::uuid,'Brigada Río Hualpén (ficticia)','Hualpén','Brigada ficticia de recuperación de espacios públicos cercanos al río.', p.id,p.id,-36.7784,-73.1078,'abierta',true
 from public.perfiles p where p.role='admin' order by p.creado_en limit 1
 on conflict(id) do nothing;
insert into public.brigadas(id,nombre,comuna,descripcion,creador_id,lider_uid,lat,lng,estado,disponible)
 select 'bcfe60e9-999c-52fa-ac6a-e7e63aa0a5a6'::uuid,'Brigada Verde Chiguayante (ficticia)','Chiguayante','Equipo de prueba para jornadas de retiro de residuos y educación ambiental.', p.id,p.id,-36.927,-73.0355,'abierta',true
 from public.perfiles p where p.role='admin' order by p.creado_en limit 1
 on conflict(id) do nothing;
insert into public.brigadas(id,nombre,comuna,descripcion,creador_id,lider_uid,lat,lng,estado,disponible)
 select 'f9f195b4-86ff-5bad-97aa-100272cc6a59'::uuid,'Brigada Playa Penco (ficticia)','Penco','Brigada ficticia dedicada a limpieza de espacios costeros y plazas.', p.id,p.id,-36.7372,-72.9948,'abierta',true
 from public.perfiles p where p.role='admin' order by p.creado_en limit 1
 on conflict(id) do nothing;
insert into public.brigadas(id,nombre,comuna,descripcion,creador_id,lider_uid,lat,lng,estado,disponible)
 select 'd0135d64-5405-560e-a00e-5a8ed9547cbf'::uuid,'Brigada Sur Coronel (ficticia)','Coronel','Equipo de prueba de respuesta comunitaria a denuncias de residuos.', p.id,p.id,-37.0155,-73.1489,'abierta',true
 from public.perfiles p where p.role='admin' order by p.creado_en limit 1
 on conflict(id) do nothing;

-- 2) Reportes de prueba con estados y fechas de prueba.
-- Se desactivan solo durante el INSERT los triggers que fuerzan estado=pendiente
-- y fecha actual; esto es válido SOLO para fixtures ejecutados desde SQL Editor.
-- La transacción garantiza que se restauran si algo falla.
alter table public.incidencias disable trigger tr_preparar_incidencia;
alter table public.incidencias disable trigger tr_nueva_incidencia_aviso;

insert into public.incidencias(id,titulo,descripcion,tipo,direccion,comuna,lat,lng,gravedad,prioridad,estado,creador_uid,brigada_id,creado_en,actualizado_en,cerrado_en)
 select '91a6ef3e-9a4d-5d94-a534-bf29e94380a9'::uuid,'[FICTICIO] Limpieza histórica de residuos en plaza','Escenario de prueba para EcoBrigada: Limpieza histórica de residuos en plaza. Datos y coordenadas ilustrativos; no corresponde a una denuncia real.','Basura','Sector referencial de Concepción (punto ficticio)','Concepción',-36.8279,-73.0499,3,39,'cerrado',p.id,'fec126f8-a523-53be-9b08-837242363e01'::uuid,now()-interval '48 days',now()-interval '24 days',now()-interval '24 days'
 from public.perfiles p where p.role='admin' order by p.creado_en limit 1
 on conflict(id) do nothing;
insert into public.incidencias(id,titulo,descripcion,tipo,direccion,comuna,lat,lng,gravedad,prioridad,estado,creador_uid,brigada_id,creado_en,actualizado_en,cerrado_en)
 select 'fda58348-bdcd-55bd-9d6b-e9db6a06fc4c'::uuid,'[FICTICIO] Residuos reaparecidos cerca de plaza','Escenario de prueba para EcoBrigada: Residuos reaparecidos cerca de plaza. Datos y coordenadas ilustrativos; no corresponde a una denuncia real.','Basura','Sector referencial de Concepción (punto ficticio)','Concepción',-36.8282,-73.0501,4,57,'pendiente',p.id,null,now()-interval '8 days',now()-interval '8 days',null
 from public.perfiles p where p.role='admin' order by p.creado_en limit 1
 on conflict(id) do nothing;
insert into public.incidencias(id,titulo,descripcion,tipo,direccion,comuna,lat,lng,gravedad,prioridad,estado,creador_uid,brigada_id,creado_en,actualizado_en,cerrado_en)
 select '5429af25-0392-5d4c-9289-039b35663bc3'::uuid,'[FICTICIO] Microbasural retirado en sector costero','Escenario de prueba para EcoBrigada: Microbasural retirado en sector costero. Datos y coordenadas ilustrativos; no corresponde a una denuncia real.','Microbasural','Sector referencial de Talcahuano (punto ficticio)','Talcahuano',-36.7251,-73.114,5,65,'cerrado',p.id,'fa31e029-5581-51c5-8eb8-6b24fbd1e8ec'::uuid,now()-interval '55 days',now()-interval '20 days',now()-interval '20 days'
 from public.perfiles p where p.role='admin' order by p.creado_en limit 1
 on conflict(id) do nothing;
insert into public.incidencias(id,titulo,descripcion,tipo,direccion,comuna,lat,lng,gravedad,prioridad,estado,creador_uid,brigada_id,creado_en,actualizado_en,cerrado_en)
 select '72ca7530-befe-50de-a64e-0499223d7c80'::uuid,'[FICTICIO] Nueva acumulación en sector costero','Escenario de prueba para EcoBrigada: Nueva acumulación en sector costero. Datos y coordenadas ilustrativos; no corresponde a una denuncia real.','Microbasural','Sector referencial de Talcahuano (punto ficticio)','Talcahuano',-36.7253,-73.1143,4,57,'validado',p.id,null,now()-interval '5 days',now()-interval '4 days',null
 from public.perfiles p where p.role='admin' order by p.creado_en limit 1
 on conflict(id) do nothing;
insert into public.incidencias(id,titulo,descripcion,tipo,direccion,comuna,lat,lng,gravedad,prioridad,estado,creador_uid,brigada_id,creado_en,actualizado_en,cerrado_en)
 select '9e6bf6b5-26d5-5207-b147-c3b9a781caee'::uuid,'[FICTICIO] Escombros en acceso a plaza','Escenario de prueba para EcoBrigada: Escombros en acceso a plaza. Datos y coordenadas ilustrativos; no corresponde a una denuncia real.','Escombros','Sector referencial de San Pedro de la Paz (punto ficticio)','San Pedro de la Paz',-36.8462,-73.108,3,39,'asignado',p.id,'9d85ecbc-4267-5613-b87c-e48712f134cd'::uuid,now()-interval '10 days',now()-interval '4 days',null
 from public.perfiles p where p.role='admin' order by p.creado_en limit 1
 on conflict(id) do nothing;
insert into public.incidencias(id,titulo,descripcion,tipo,direccion,comuna,lat,lng,gravedad,prioridad,estado,creador_uid,brigada_id,creado_en,actualizado_en,cerrado_en)
 select '881dd628-a35c-5891-a5aa-4d8ddda99651'::uuid,'[FICTICIO] Bolsas de basura junto a paradero','Escenario de prueba para EcoBrigada: Bolsas de basura junto a paradero. Datos y coordenadas ilustrativos; no corresponde a una denuncia real.','Basura','Sector referencial de Hualpén (punto ficticio)','Hualpén',-36.779,-73.1081,2,26,'en_proceso',p.id,'aec9c825-20cc-58ca-9135-c14ae8a954ca'::uuid,now()-interval '9 days',now()-interval '2 days',null
 from public.perfiles p where p.role='admin' order by p.creado_en limit 1
 on conflict(id) do nothing;
insert into public.incidencias(id,titulo,descripcion,tipo,direccion,comuna,lat,lng,gravedad,prioridad,estado,creador_uid,brigada_id,creado_en,actualizado_en,cerrado_en)
 select 'ea62c147-0bef-5e32-a596-ecef495b2545'::uuid,'[FICTICIO] Microbasural junto a camino','Escenario de prueba para EcoBrigada: Microbasural junto a camino. Datos y coordenadas ilustrativos; no corresponde a una denuncia real.','Microbasural','Sector referencial de Chiguayante (punto ficticio)','Chiguayante',-36.9282,-73.0348,5,65,'en_revision',p.id,'bcfe60e9-999c-52fa-ac6a-e7e63aa0a5a6'::uuid,now()-interval '15 days',now()-interval '2 days',null
 from public.perfiles p where p.role='admin' order by p.creado_en limit 1
 on conflict(id) do nothing;
insert into public.incidencias(id,titulo,descripcion,tipo,direccion,comuna,lat,lng,gravedad,prioridad,estado,creador_uid,brigada_id,creado_en,actualizado_en,cerrado_en)
 select '46ee24df-52de-5939-9675-87f7f60f1971'::uuid,'[FICTICIO] Denuncia duplicada o errónea','Escenario de prueba para EcoBrigada: Denuncia duplicada o errónea. Datos y coordenadas ilustrativos; no corresponde a una denuncia real.','Otro','Sector referencial de Penco (punto ficticio)','Penco',-36.7378,-72.994,1,13,'descartado',p.id,null,now()-interval '12 days',now()-interval '10 days',null
 from public.perfiles p where p.role='admin' order by p.creado_en limit 1
 on conflict(id) do nothing;
insert into public.incidencias(id,titulo,descripcion,tipo,direccion,comuna,lat,lng,gravedad,prioridad,estado,creador_uid,brigada_id,creado_en,actualizado_en,cerrado_en)
 select '03566bd8-3b85-54e2-9e2c-dd0b0f4696df'::uuid,'[FICTICIO] Escombros acumulados en vereda','Escenario de prueba para EcoBrigada: Escombros acumulados en vereda. Datos y coordenadas ilustrativos; no corresponde a una denuncia real.','Escombros','Sector referencial de Coronel (punto ficticio)','Coronel',-37.017,-73.1488,4,52,'pendiente',p.id,null,now()-interval '3 days',now()-interval '3 days',null
 from public.perfiles p where p.role='admin' order by p.creado_en limit 1
 on conflict(id) do nothing;
insert into public.incidencias(id,titulo,descripcion,tipo,direccion,comuna,lat,lng,gravedad,prioridad,estado,creador_uid,brigada_id,creado_en,actualizado_en,cerrado_en)
 select 'ddf7d2ae-81f8-5551-8e41-ad0f3a920c49'::uuid,'[FICTICIO] Basura dispersa en zona peatonal','Escenario de prueba para EcoBrigada: Basura dispersa en zona peatonal. Datos y coordenadas ilustrativos; no corresponde a una denuncia real.','Basura','Sector referencial de Lota (punto ficticio)','Lota',-37.0901,-73.1589,2,26,'validado',p.id,null,now()-interval '5 days',now()-interval '3 days',null
 from public.perfiles p where p.role='admin' order by p.creado_en limit 1
 on conflict(id) do nothing;
insert into public.incidencias(id,titulo,descripcion,tipo,direccion,comuna,lat,lng,gravedad,prioridad,estado,creador_uid,brigada_id,creado_en,actualizado_en,cerrado_en)
 select '909addc7-376c-55ae-ab31-fbbaea590df7'::uuid,'[FICTICIO] Residuos junto a área recreativa','Escenario de prueba para EcoBrigada: Residuos junto a área recreativa. Datos y coordenadas ilustrativos; no corresponde a una denuncia real.','Basura','Sector referencial de Tomé (punto ficticio)','Tomé',-36.6138,-72.9585,3,39,'asignado',p.id,'f9f195b4-86ff-5bad-97aa-100272cc6a59'::uuid,now()-interval '8 days',now()-interval '4 days',null
 from public.perfiles p where p.role='admin' order by p.creado_en limit 1
 on conflict(id) do nothing;
insert into public.incidencias(id,titulo,descripcion,tipo,direccion,comuna,lat,lng,gravedad,prioridad,estado,creador_uid,brigada_id,creado_en,actualizado_en,cerrado_en)
 select 'c2280756-b30a-5aa1-b48d-f331b1ccfecb'::uuid,'[FICTICIO] Escombros cerca de vía principal','Escenario de prueba para EcoBrigada: Escombros cerca de vía principal. Datos y coordenadas ilustrativos; no corresponde a una denuncia real.','Escombros','Sector referencial de Concepción (punto ficticio)','Concepción',-36.837,-73.0578,5,65,'en_proceso',p.id,'fec126f8-a523-53be-9b08-837242363e01'::uuid,now()-interval '11 days',now()-interval '2 days',null
 from public.perfiles p where p.role='admin' order by p.creado_en limit 1
 on conflict(id) do nothing;
insert into public.incidencias(id,titulo,descripcion,tipo,direccion,comuna,lat,lng,gravedad,prioridad,estado,creador_uid,brigada_id,creado_en,actualizado_en,cerrado_en)
 select '0118c792-c224-5517-8550-2944227c6553'::uuid,'[FICTICIO] Retiro de elementos abandonados','Escenario de prueba para EcoBrigada: Retiro de elementos abandonados. Datos y coordenadas ilustrativos; no corresponde a una denuncia real.','Otro','Sector referencial de Hualqui (punto ficticio)','Hualqui',-36.971,-72.933,2,26,'cerrado',p.id,'bcfe60e9-999c-52fa-ac6a-e7e63aa0a5a6'::uuid,now()-interval '40 days',now()-interval '13 days',now()-interval '13 days'
 from public.perfiles p where p.role='admin' order by p.creado_en limit 1
 on conflict(id) do nothing;
insert into public.incidencias(id,titulo,descripcion,tipo,direccion,comuna,lat,lng,gravedad,prioridad,estado,creador_uid,brigada_id,creado_en,actualizado_en,cerrado_en)
 select '0f42714a-e159-55cf-ad88-a5328b985b95'::uuid,'[FICTICIO] Bolsas y plásticos en plaza','Escenario de prueba para EcoBrigada: Bolsas y plásticos en plaza. Datos y coordenadas ilustrativos; no corresponde a una denuncia real.','Basura','Sector referencial de Penco (punto ficticio)','Penco',-36.7365,-72.9961,3,39,'en_revision',p.id,'f9f195b4-86ff-5bad-97aa-100272cc6a59'::uuid,now()-interval '9 days',now()-interval '2 days',null
 from public.perfiles p where p.role='admin' order by p.creado_en limit 1
 on conflict(id) do nothing;

alter table public.incidencias enable trigger tr_preparar_incidencia;
alter table public.incidencias enable trigger tr_nueva_incidencia_aviso;

-- 3) Historia transparente: marca la carga como DATOS FICTICIOS.
-- No simula una cadena de aprobaciones reales ni inventa fotografías.
insert into public.historial_incidencias(id,reporte_id,anterior,nuevo,autor_uid,comentario,fecha)
 select 'e09a68dc-7c96-5960-8a47-59565e01ba74'::uuid, i.id,'carga_ficticia',i.estado,i.creador_uid,'Estado generado para pruebas de EcoMapa y EcoAnalisis, sin validacion real.',i.actualizado_en
 from public.incidencias i where i.id='91a6ef3e-9a4d-5d94-a534-bf29e94380a9'::uuid
 on conflict(id) do nothing;
insert into public.historial_incidencias(id,reporte_id,anterior,nuevo,autor_uid,comentario,fecha)
 select '1e0a0d58-82c1-56be-81c2-6fd3479016cb'::uuid, i.id,'carga_ficticia',i.estado,i.creador_uid,'Estado generado para pruebas de EcoMapa y EcoAnalisis, sin validacion real.',i.actualizado_en
 from public.incidencias i where i.id='fda58348-bdcd-55bd-9d6b-e9db6a06fc4c'::uuid
 on conflict(id) do nothing;
insert into public.historial_incidencias(id,reporte_id,anterior,nuevo,autor_uid,comentario,fecha)
 select '8a837d20-e0a2-59bb-8640-c50ddbf0cc09'::uuid, i.id,'carga_ficticia',i.estado,i.creador_uid,'Estado generado para pruebas de EcoMapa y EcoAnalisis, sin validacion real.',i.actualizado_en
 from public.incidencias i where i.id='5429af25-0392-5d4c-9289-039b35663bc3'::uuid
 on conflict(id) do nothing;
insert into public.historial_incidencias(id,reporte_id,anterior,nuevo,autor_uid,comentario,fecha)
 select 'b3d104fc-0a3d-5a6a-946b-ebbba91ab27d'::uuid, i.id,'carga_ficticia',i.estado,i.creador_uid,'Estado generado para pruebas de EcoMapa y EcoAnalisis, sin validacion real.',i.actualizado_en
 from public.incidencias i where i.id='72ca7530-befe-50de-a64e-0499223d7c80'::uuid
 on conflict(id) do nothing;
insert into public.historial_incidencias(id,reporte_id,anterior,nuevo,autor_uid,comentario,fecha)
 select '7d7a20ac-6a29-5902-8327-ca6bb0a95c0b'::uuid, i.id,'carga_ficticia',i.estado,i.creador_uid,'Estado generado para pruebas de EcoMapa y EcoAnalisis, sin validacion real.',i.actualizado_en
 from public.incidencias i where i.id='9e6bf6b5-26d5-5207-b147-c3b9a781caee'::uuid
 on conflict(id) do nothing;
insert into public.historial_incidencias(id,reporte_id,anterior,nuevo,autor_uid,comentario,fecha)
 select '05e434a8-d01a-5a4c-a2e2-edc48d53193a'::uuid, i.id,'carga_ficticia',i.estado,i.creador_uid,'Estado generado para pruebas de EcoMapa y EcoAnalisis, sin validacion real.',i.actualizado_en
 from public.incidencias i where i.id='881dd628-a35c-5891-a5aa-4d8ddda99651'::uuid
 on conflict(id) do nothing;
insert into public.historial_incidencias(id,reporte_id,anterior,nuevo,autor_uid,comentario,fecha)
 select '3f947861-a722-5569-8852-104cf366ef55'::uuid, i.id,'carga_ficticia',i.estado,i.creador_uid,'Estado generado para pruebas de EcoMapa y EcoAnalisis, sin validacion real.',i.actualizado_en
 from public.incidencias i where i.id='ea62c147-0bef-5e32-a596-ecef495b2545'::uuid
 on conflict(id) do nothing;
insert into public.historial_incidencias(id,reporte_id,anterior,nuevo,autor_uid,comentario,fecha)
 select '6bb10fac-2e35-5e2f-ab22-b110dcd8855c'::uuid, i.id,'carga_ficticia',i.estado,i.creador_uid,'Estado generado para pruebas de EcoMapa y EcoAnalisis, sin validacion real.',i.actualizado_en
 from public.incidencias i where i.id='46ee24df-52de-5939-9675-87f7f60f1971'::uuid
 on conflict(id) do nothing;
insert into public.historial_incidencias(id,reporte_id,anterior,nuevo,autor_uid,comentario,fecha)
 select 'd887042e-2641-5b52-af66-ff5121a56e78'::uuid, i.id,'carga_ficticia',i.estado,i.creador_uid,'Estado generado para pruebas de EcoMapa y EcoAnalisis, sin validacion real.',i.actualizado_en
 from public.incidencias i where i.id='03566bd8-3b85-54e2-9e2c-dd0b0f4696df'::uuid
 on conflict(id) do nothing;
insert into public.historial_incidencias(id,reporte_id,anterior,nuevo,autor_uid,comentario,fecha)
 select 'f52f3bc6-f0fc-5fa2-babf-f2debe134c9d'::uuid, i.id,'carga_ficticia',i.estado,i.creador_uid,'Estado generado para pruebas de EcoMapa y EcoAnalisis, sin validacion real.',i.actualizado_en
 from public.incidencias i where i.id='ddf7d2ae-81f8-5551-8e41-ad0f3a920c49'::uuid
 on conflict(id) do nothing;
insert into public.historial_incidencias(id,reporte_id,anterior,nuevo,autor_uid,comentario,fecha)
 select '4fcfe9c7-ac5a-5b42-8ecd-d86a5fe38e66'::uuid, i.id,'carga_ficticia',i.estado,i.creador_uid,'Estado generado para pruebas de EcoMapa y EcoAnalisis, sin validacion real.',i.actualizado_en
 from public.incidencias i where i.id='909addc7-376c-55ae-ab31-fbbaea590df7'::uuid
 on conflict(id) do nothing;
insert into public.historial_incidencias(id,reporte_id,anterior,nuevo,autor_uid,comentario,fecha)
 select 'e5c8f134-8d23-5757-a58a-b78df76600d4'::uuid, i.id,'carga_ficticia',i.estado,i.creador_uid,'Estado generado para pruebas de EcoMapa y EcoAnalisis, sin validacion real.',i.actualizado_en
 from public.incidencias i where i.id='c2280756-b30a-5aa1-b48d-f331b1ccfecb'::uuid
 on conflict(id) do nothing;
insert into public.historial_incidencias(id,reporte_id,anterior,nuevo,autor_uid,comentario,fecha)
 select '15966b7c-7b73-5e9f-893e-49e4e9e6c78a'::uuid, i.id,'carga_ficticia',i.estado,i.creador_uid,'Estado generado para pruebas de EcoMapa y EcoAnalisis, sin validacion real.',i.actualizado_en
 from public.incidencias i where i.id='0118c792-c224-5517-8550-2944227c6553'::uuid
 on conflict(id) do nothing;
insert into public.historial_incidencias(id,reporte_id,anterior,nuevo,autor_uid,comentario,fecha)
 select '3faf5539-bba5-5deb-b63c-3b88410c3cb0'::uuid, i.id,'carga_ficticia',i.estado,i.creador_uid,'Estado generado para pruebas de EcoMapa y EcoAnalisis, sin validacion real.',i.actualizado_en
 from public.incidencias i where i.id='0f42714a-e159-55cf-ad88-a5328b985b95'::uuid
 on conflict(id) do nothing;

-- 4) Mensajes iniciales en cada brigada: accesibles SOLO a miembros/líder/admin.
insert into public.mensajes(id,brigada_id,autor_id,texto)
 select '7a852cbc-4dfe-58cc-afe5-fdc426abf17d'::uuid, b.id,b.creador_id,'[MENSAJE FICTICIO] Bienvenidos al chat de Brigada Bosque Nonguén (ficticia). Solicita ingreso a la brigada para participar.'
 from public.brigadas b where b.id='fec126f8-a523-53be-9b08-837242363e01'::uuid
 on conflict(id) do nothing;
insert into public.mensajes(id,brigada_id,autor_id,texto)
 select 'f8b0458a-f433-563e-a72a-1dae644543f7'::uuid, b.id,b.creador_id,'[MENSAJE FICTICIO] Bienvenidos al chat de Brigada Costa Talcahuano (ficticia). Solicita ingreso a la brigada para participar.'
 from public.brigadas b where b.id='fa31e029-5581-51c5-8eb8-6b24fbd1e8ec'::uuid
 on conflict(id) do nothing;
insert into public.mensajes(id,brigada_id,autor_id,texto)
 select 'efbd96b8-f884-5af2-a7af-4ae99646aaef'::uuid, b.id,b.creador_id,'[MENSAJE FICTICIO] Bienvenidos al chat de Brigada Humedales San Pedro (ficticia). Solicita ingreso a la brigada para participar.'
 from public.brigadas b where b.id='9d85ecbc-4267-5613-b87c-e48712f134cd'::uuid
 on conflict(id) do nothing;
insert into public.mensajes(id,brigada_id,autor_id,texto)
 select 'dedc907e-6235-5dee-9342-963e9acba76a'::uuid, b.id,b.creador_id,'[MENSAJE FICTICIO] Bienvenidos al chat de Brigada Río Hualpén (ficticia). Solicita ingreso a la brigada para participar.'
 from public.brigadas b where b.id='aec9c825-20cc-58ca-9135-c14ae8a954ca'::uuid
 on conflict(id) do nothing;
insert into public.mensajes(id,brigada_id,autor_id,texto)
 select '9fa85b8a-a403-52f9-8a31-b6052e0ae1d3'::uuid, b.id,b.creador_id,'[MENSAJE FICTICIO] Bienvenidos al chat de Brigada Verde Chiguayante (ficticia). Solicita ingreso a la brigada para participar.'
 from public.brigadas b where b.id='bcfe60e9-999c-52fa-ac6a-e7e63aa0a5a6'::uuid
 on conflict(id) do nothing;
insert into public.mensajes(id,brigada_id,autor_id,texto)
 select 'a303fa25-fe5d-5b75-aed5-7e3b44e0056b'::uuid, b.id,b.creador_id,'[MENSAJE FICTICIO] Bienvenidos al chat de Brigada Playa Penco (ficticia). Solicita ingreso a la brigada para participar.'
 from public.brigadas b where b.id='f9f195b4-86ff-5bad-97aa-100272cc6a59'::uuid
 on conflict(id) do nothing;
insert into public.mensajes(id,brigada_id,autor_id,texto)
 select '3ea5ffa2-dd2e-53ea-9f32-17116418a856'::uuid, b.id,b.creador_id,'[MENSAJE FICTICIO] Bienvenidos al chat de Brigada Sur Coronel (ficticia). Solicita ingreso a la brigada para participar.'
 from public.brigadas b where b.id='d0135d64-5405-560e-a00e-5a8ed9547cbf'::uuid
 on conflict(id) do nothing;

commit;

-- 5) VERIFICACIÓN: conteos exclusivos de esta carga.
select estado,count(*) as cantidad from public.incidencias
where id in ('91a6ef3e-9a4d-5d94-a534-bf29e94380a9'::uuid, 'fda58348-bdcd-55bd-9d6b-e9db6a06fc4c'::uuid, '5429af25-0392-5d4c-9289-039b35663bc3'::uuid, '72ca7530-befe-50de-a64e-0499223d7c80'::uuid, '9e6bf6b5-26d5-5207-b147-c3b9a781caee'::uuid, '881dd628-a35c-5891-a5aa-4d8ddda99651'::uuid, 'ea62c147-0bef-5e32-a596-ecef495b2545'::uuid, '46ee24df-52de-5939-9675-87f7f60f1971'::uuid, '03566bd8-3b85-54e2-9e2c-dd0b0f4696df'::uuid, 'ddf7d2ae-81f8-5551-8e41-ad0f3a920c49'::uuid, '909addc7-376c-55ae-ab31-fbbaea590df7'::uuid, 'c2280756-b30a-5aa1-b48d-f331b1ccfecb'::uuid, '0118c792-c224-5517-8550-2944227c6553'::uuid, '0f42714a-e159-55cf-ad88-a5328b985b95'::uuid)
group by estado order by estado;
select count(*) as brigadas_ficticias from public.brigadas where id in ('fec126f8-a523-53be-9b08-837242363e01'::uuid, 'fa31e029-5581-51c5-8eb8-6b24fbd1e8ec'::uuid, '9d85ecbc-4267-5613-b87c-e48712f134cd'::uuid, 'aec9c825-20cc-58ca-9135-c14ae8a954ca'::uuid, 'bcfe60e9-999c-52fa-ac6a-e7e63aa0a5a6'::uuid, 'f9f195b4-86ff-5bad-97aa-100272cc6a59'::uuid, 'd0135d64-5405-560e-a00e-5a8ed9547cbf'::uuid);
-- Para probar chat ciudadano: crea otra cuenta real, solicita ingreso y
-- apruébala desde Detalle de Brigada con la cuenta administradora.
-- Para probar EcoReincidencia: compara los casos limpio1/rec1 y limpio2/rec2.
