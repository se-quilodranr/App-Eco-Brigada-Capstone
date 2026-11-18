-- ECOBRIGADA 3.0: MIGRACION INCREMENTAL PARA EL SUPABASE ORIGINAL DEL USUARIO
-- EJECUTAR SOLO DESPUES de supabase/base_original/01_esquema.sql en un proyecto nuevo.
-- SI YA TIENES LA BASE ORIGINAL FUNCIONANDO: ejecutar SOLO este archivo.
-- NO elimina datos ni renombra tablas existentes: perfiles, brigadas, solicitudes,
-- brigada_miembros, mensajes, actividades, lugares y publicaciones se conservan.
-- Antes de ejecutarlo en un sistema real: obtener una copia de seguridad.
create extension if not exists pgcrypto;
create schema if not exists app;

-- Extensiones a las tablas originales: mantener los mismos UUID de usuarios/brigadas.
alter table public.perfiles add column if not exists role text not null default 'ciudadano';
alter table public.perfiles add column if not exists avatar_path text;
alter table public.perfiles add constraint perfiles_role_check check(role in ('ciudadano','admin'));
-- PRIVILEGIOS: la política antigua permitía editar cualquier columna del propio perfil.
-- Restringimos a nombre + foto: nunca permitir cambiar role desde Flutter.
revoke update on public.perfiles from anon, authenticated;
grant update(nombre,avatar_path) on public.perfiles to authenticated;
-- Solo permitimos a las interfaces antiguas abrir/cerrar sus brigadas.
-- La asignación de líder y coordenadas requiere SQL administrativo autorizado.
revoke update on public.brigadas from anon, authenticated;
grant update(estado) on public.brigadas to authenticated;

alter table public.brigadas add column if not exists lider_uid uuid references public.perfiles(id);
alter table public.brigadas add column if not exists lat double precision;
alter table public.brigadas add column if not exists lng double precision;
alter table public.brigadas add column if not exists disponible boolean not null default true;
alter table public.brigadas add column if not exists miembros integer not null default 0;
update public.brigadas set lider_uid=coalesce(lider_uid,creador_id),
  disponible=(estado='abierta');
update public.brigadas b set miembros=(select count(*) from public.brigada_miembros m where m.brigada_id=b.id);
-- Para nuevas brigadas creadas desde las pantallas originales:
create or replace function app.default_brigade_fields() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 new.lider_uid:=coalesce(new.lider_uid,new.creador_id);
 new.disponible:=(new.estado='abierta');
 return new;
end;$$;
create trigger ecobrigada_brigada_preparar before insert or update of estado on public.brigadas
 for each row execute function app.default_brigade_fields();
-- Las brigadas antiguas sin coordenadas mantienen lat/lng NULL.
-- No se inventan ubicaciones para dibujarlas en EcoMapa.
-- Para registrar una ubicación verificada desde SQL Editor:
-- update public.brigadas set lat=-36.0, lng=-73.0 where id='UUID';
-- El ejemplo anterior es una plantilla, NO una ubicación sugerida.
-- Sincroniza el número de miembros, tanto desde las pantallas antiguas como nuevas.
create or replace function app.actualizar_cantidad_miembros() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if tg_op='DELETE' then
  update public.brigadas b set miembros=(select count(*) from public.brigada_miembros m where m.brigada_id=b.id) where b.id=old.brigada_id;
  return old;
 end if;
 update public.brigadas b set miembros=(select count(*) from public.brigada_miembros m where m.brigada_id=b.id) where b.id=new.brigada_id;
 return new;
end;$$;
create trigger ecobrigada_miembros_cantidad after insert or delete on public.brigada_miembros
 for each row execute function app.actualizar_cantidad_miembros();

-- Nuevas incidencias, indicadores, auditoría y evidencia; no reemplazan la tabla
-- public.reportes previa (esa tabla denunciaba PUBLICACIONES, no basura).
create table public.incidencias (
 id uuid primary key default gen_random_uuid(),
 titulo text not null check (char_length(trim(titulo)) >= 5),
 descripcion text not null check (char_length(trim(descripcion)) >= 10),
 tipo text not null check (tipo in ('Basura','Escombros','Microbasural','Otro')),
 direccion text not null check (char_length(trim(direccion)) >= 3),
 comuna text not null check (char_length(trim(comuna)) >= 3),
 lat double precision not null check (lat between -90 and 90),
 lng double precision not null check (lng between -180 and 180),
 gravedad integer not null check (gravedad between 1 and 5),
 prioridad integer not null default 13 check (prioridad between 0 and 100),
 estado text not null default 'pendiente' check(estado in ('pendiente','validado','asignado','en_proceso','en_revision','cerrado','descartado')),
 creador_uid uuid not null references public.perfiles(id),
 brigada_id uuid references public.brigadas(id),
 creado_en timestamptz not null default now(),
 actualizado_en timestamptz not null default now(),
 cerrado_en timestamptz
);
create table public.historial_incidencias (
 id uuid primary key default gen_random_uuid(),
 reporte_id uuid not null references public.incidencias(id) on delete cascade,
 anterior text not null, nuevo text not null,
 autor_uid uuid not null references public.perfiles(id),
 comentario text not null default '',
 fecha timestamptz not null default now()
);
create table public.validaciones_limpieza (
 id uuid primary key default gen_random_uuid(),
 reporte_id uuid not null references public.incidencias(id) on delete cascade,
 revisor_uid uuid not null references public.perfiles(id),
 resultado text not null check(resultado in ('aprobada','devuelta')),
 observacion text not null check(char_length(trim(observacion)) >= 5),
 fecha timestamptz not null default now()
);
create table public.fotos_incidencia (
 id uuid primary key default gen_random_uuid(),
 reporte_id uuid not null references public.incidencias(id) on delete cascade,
 autor_uid uuid not null references public.perfiles(id),
 fase text not null check(fase in ('inicial','posterior')),
 storage_path text not null unique,
 creado_en timestamptz not null default now()
);
create table public.notificaciones (
 id uuid primary key default gen_random_uuid(),
 destinatario_uid uuid not null references public.perfiles(id) on delete cascade,
 titulo text not null, cuerpo text not null,
 reporte_id uuid references public.incidencias(id) on delete set null,
 leida_en timestamptz,
 creada_en timestamptz not null default now()
);
create table public.puntos_reciclaje (
 id uuid primary key default gen_random_uuid(),
 nombre text not null, descripcion text not null default '', comuna text not null,
 lat double precision not null check(lat between -90 and 90),
 lng double precision not null check(lng between -180 and 180),
 verificado boolean not null default false
);

create index idx_inc_estado_fecha on public.incidencias(estado, creado_en desc);
create index idx_inc_tipo on public.incidencias(tipo);
create index idx_hist_reporte on public.historial_incidencias(reporte_id,fecha desc);
create index idx_fotos_reporte on public.fotos_incidencia(reporte_id);
create index idx_noti_destino on public.notificaciones(destinatario_uid,creada_en desc);
-- El owner de estas funciones debe ser postgres: RLS interno sin recursión.
create function app.is_admin() returns boolean language sql stable security definer
 set search_path = '' as $$select exists(select 1 from public.perfiles where id=auth.uid() and role='admin')$$;
create function app.can_manage_brigade(p_id uuid) returns boolean language sql stable security definer
 set search_path = '' as $$select app.is_admin() or exists(select 1 from public.brigadas where id=p_id and (lider_uid=auth.uid() or creador_id=auth.uid()))$$;
create function app.can_chat(p_id uuid) returns boolean language sql stable security definer
 set search_path = '' as $$select app.can_manage_brigade(p_id) or exists(select 1 from public.brigada_miembros where brigada_id=p_id and usuario_id=auth.uid())$$;
create function app.can_view_evidence(p_id uuid) returns boolean language sql stable security definer
 set search_path = '' as $$select app.is_admin() or exists(
   select 1 from public.incidencias i where i.id=p_id
   and (i.creador_uid=auth.uid() or (i.brigada_id is not null and app.can_chat(i.brigada_id))))$$;
create function app.can_upload_phase(p_id uuid,p_phase text) returns boolean language sql stable security definer
 set search_path = '' as $$
 select case when p_phase='inicial' then exists(select 1 from public.incidencias i where i.id=p_id and i.estado in ('pendiente','validado') and (i.creador_uid=auth.uid() or app.is_admin()))
 when p_phase='posterior' then exists(select 1 from public.incidencias i where i.id=p_id and i.estado in ('asignado','en_proceso','en_revision') and (app.is_admin() or app.can_manage_brigade(i.brigada_id)))
 else false end $$;
revoke all on function app.is_admin() from public;
revoke all on function app.can_manage_brigade(uuid) from public;
revoke all on function app.can_chat(uuid) from public;
revoke all on function app.can_upload_phase(uuid,text) from public;
revoke all on function app.can_view_evidence(uuid) from public;
grant usage on schema app to authenticated;
grant execute on function app.is_admin(),app.can_manage_brigade(uuid),app.can_chat(uuid),app.can_upload_phase(uuid,text),app.can_view_evidence(uuid) to authenticated;

-- Distancia esférica Haversine en metros; limitada para evitar errores de acos.
create function app.distancia_m(a_lat double precision,a_lng double precision,b_lat double precision,b_lng double precision)
 returns double precision language sql immutable set search_path='' as $$
 select 6371000 * 2 * asin(sqrt(least(1.0, greatest(0.0,
 pow(sin(radians((b_lat-a_lat)/2)),2) + cos(radians(a_lat))*cos(radians(b_lat))*pow(sin(radians((b_lng-a_lng)/2)),2))))) $$;
create function app.preparar_incidencia() returns trigger language plpgsql security definer set search_path='' as $$
declare cercanos integer;
begin
 new.creador_uid:=auth.uid();
 if new.creador_uid is null then raise exception 'Inicia sesión'; end if;
 new.estado:='pendiente'; new.brigada_id:=null;
 new.creado_en:=now();new.actualizado_en:=now();new.cerrado_en:=null;
 select count(*) into cercanos from public.incidencias i where i.tipo=new.tipo and i.estado not in ('cerrado','descartado')
 and app.distancia_m(i.lat,i.lng,new.lat,new.lng)<=150;
 new.prioridad:=least(100,13*new.gravedad+least(15,cercanos*5));
 return new;
end;$$;
create trigger tr_preparar_incidencia before insert on public.incidencias for each row execute function app.preparar_incidencia();
-- Aviso al administrador al recibir un nuevo reporte.
create function app.nueva_incidencia_aviso() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.notificaciones(destinatario_uid,titulo,cuerpo,reporte_id)
 select p.id,'Nueva incidencia','Se registró un reporte en '||new.comuna,new.id
 from public.perfiles p where p.role='admin' and p.id<>new.creador_uid;
 return new;
end;$$;
create trigger tr_nueva_incidencia_aviso after insert on public.incidencias
 for each row execute function app.nueva_incidencia_aviso();


-- Los movimientos, validaciones y avisos se escriben atómicamente.
create function public.cambiar_estado_reporte(p_id uuid,p_nuevo text,p_brigada uuid default null,p_comentario text default '')
 returns void language plpgsql security definer set search_path='' as $$
declare r public.incidencias%rowtype; permiso_lider boolean;
begin
 if auth.uid() is null then raise exception 'Sesión requerida'; end if;
 select * into r from public.incidencias where id=p_id for update;
 if not found then raise exception 'Incidencia inexistente'; end if;
 if not ((r.estado='pendiente' and p_nuevo in ('validado','descartado')) or
 (r.estado='validado' and p_nuevo in ('asignado','descartado')) or
 (r.estado='asignado' and p_nuevo='en_proceso') or
 (r.estado='en_proceso' and p_nuevo='en_revision') or
 (r.estado='en_revision' and p_nuevo in ('en_proceso','cerrado'))) then
 raise exception 'Transición no permitida'; end if;
 permiso_lider := r.estado in ('asignado','en_proceso') and app.can_manage_brigade(r.brigada_id);
 if not app.is_admin() and not permiso_lider then raise exception 'Permisos insuficientes';end if;
 if p_nuevo='asignado' and not exists(select 1 from public.brigadas where id=p_brigada and disponible) then
 raise exception 'Brigada no disponible';end if;
 if (p_nuevo in ('en_revision','cerrado','descartado') or (r.estado='en_revision' and p_nuevo='en_proceso'))
  and char_length(trim(p_comentario))<5 then
 raise exception 'Observación obligatoria (mínimo 5 caracteres)';end if;
 if p_nuevo in ('en_revision','cerrado') and not exists(select 1 from public.fotos_incidencia where reporte_id=p_id and fase='posterior') then
 raise exception 'Adjunta fotografía posterior antes de solicitar o aprobar la revisión';end if;
 update public.incidencias set estado=p_nuevo,brigada_id=case when p_nuevo='asignado' then p_brigada else brigada_id end,
 actualizado_en=now(), cerrado_en=case when p_nuevo='cerrado' then now() else cerrado_en end where id=p_id;
 insert into public.historial_incidencias(reporte_id,anterior,nuevo,autor_uid,comentario)
 values(p_id,r.estado,p_nuevo,auth.uid(),trim(p_comentario));
 if r.estado='en_revision' and p_nuevo in ('cerrado','en_proceso') then
 insert into public.validaciones_limpieza(reporte_id,revisor_uid,resultado,observacion)
 values(p_id,auth.uid(),case when p_nuevo='cerrado' then 'aprobada' else 'devuelta' end,trim(p_comentario));
 end if;
 if p_nuevo='asignado' and p_brigada is not null then
 insert into public.notificaciones(destinatario_uid,titulo,cuerpo,reporte_id)
 select b.lider_uid,'Nueva incidencia asignada','La brigada recibió una incidencia',p_id
 from public.brigadas b where b.id=p_brigada and b.lider_uid is not null and b.lider_uid<>auth.uid();
 end if;
 if r.creador_uid<>auth.uid() then
 insert into public.notificaciones(destinatario_uid,titulo,cuerpo,reporte_id)
 values(r.creador_uid,'Actualización de incidencia','Tu reporte pasó al estado '||p_nuevo,p_id);
 end if;
end;$$;


-- Resolver solicitudes de la tabla ORIGINAL public.solicitudes, manteniendo su RPC
-- original para pantallas antiguas y agregando acceso al administrador global.
create or replace function public.eco_resolver_solicitud(p_solicitud uuid,p_aceptar boolean)
returns void language plpgsql security definer set search_path='' as $$
declare s public.solicitudes%rowtype;
begin
 if auth.uid() is null then raise exception 'Sesión requerida';end if;
 select * into s from public.solicitudes where id=p_solicitud for update;
 if not found or s.estado<>'pendiente' then raise exception 'Solicitud no disponible';end if;
 if not app.can_manage_brigade(s.brigada_id) then raise exception 'Permisos insuficientes';end if;
 if p_aceptar then
  insert into public.brigada_miembros(brigada_id,usuario_id,rol)
  values(s.brigada_id,s.usuario_id,'miembro') on conflict do nothing;
  if s.actividad_id is not null then
   insert into public.actividad_participantes(actividad_id,usuario_id)
   values(s.actividad_id,s.usuario_id) on conflict do nothing;
  end if;
 end if;
 update public.solicitudes set estado=case when p_aceptar then 'aceptada' else 'rechazada' end,
   revisada_por=auth.uid(),revisada_en=now() where id=p_solicitud;
 insert into public.notificaciones(destinatario_uid,titulo,cuerpo)
 values(s.usuario_id,'Solicitud de brigada',case when p_aceptar then
 'Tu solicitud fue aprobada' else 'Tu solicitud fue rechazada' end);
end;$$;
revoke all on function public.eco_resolver_solicitud(uuid,boolean) from public;
grant execute on function public.eco_resolver_solicitud(uuid,boolean) to authenticated;

-- Versión 3.0: crear brigadas es un acto administrativo también en el backend.
-- Los datos y las brigadas anteriores permanecen intactos.
drop policy if exists "Crear brigada propia" on public.brigadas;
create policy eco_admin_crear_brigada on public.brigadas for insert to authenticated
 with check(creador_id=auth.uid() and app.is_admin());

-- Chat de la tabla original: administrador global puede ver cualquier sala;
-- líder y miembros conservan sus permisos anteriores. RLS (no solo UI).
create policy eco_admin_chat_select on public.mensajes for select to authenticated
 using(app.can_chat(brigada_id));
create policy eco_admin_chat_insert on public.mensajes for insert to authenticated
 with check(autor_id=auth.uid() and app.can_chat(brigada_id));
-- Líder puede planificar actividades aunque no haya creado originalmente la brigada.
create policy eco_lider_actividad_insert on public.actividades for insert to authenticated
 with check(app.can_manage_brigade(brigada_id));
-- Solicitudes pueden ser revisadas por el administrador global.
create policy eco_admin_solicitud_select on public.solicitudes for select to authenticated
 using(app.can_manage_brigade(brigada_id));

revoke all on function public.cambiar_estado_reporte(uuid,text,uuid,text) from public;
grant execute on function public.cambiar_estado_reporte(uuid,text,uuid,text) to authenticated;

-- Acceso mínimo a las tablas añadidas. No se revocan permisos de tablas originales
-- ni se eliminan datos de publicaciones, actividades o lugares.
grant select on public.incidencias,public.historial_incidencias,public.validaciones_limpieza,
 public.fotos_incidencia,public.notificaciones,public.puntos_reciclaje to authenticated;
grant insert on public.incidencias,public.fotos_incidencia,public.puntos_reciclaje to authenticated;
grant update(leida_en) on public.notificaciones to authenticated;
-- La inserción en brigadas, mensajes y actividades ya existe por el esquema original.

alter table public.incidencias enable row level security;
alter table public.historial_incidencias enable row level security;
alter table public.validaciones_limpieza enable row level security;
alter table public.fotos_incidencia enable row level security;
alter table public.notificaciones enable row level security;
alter table public.puntos_reciclaje enable row level security;

create policy eco_inc_sel on public.incidencias for select to authenticated using(true);
create policy eco_inc_ins on public.incidencias for insert to authenticated
 with check(creador_uid=auth.uid() and estado='pendiente' and brigada_id is null);
create policy eco_hist_sel on public.historial_incidencias for select to authenticated using(true);
create policy eco_val_sel on public.validaciones_limpieza for select to authenticated using(true);
create policy eco_fotos_sel on public.fotos_incidencia for select to authenticated using(app.can_view_evidence(reporte_id));
create policy eco_fotos_ins on public.fotos_incidencia for insert to authenticated
 with check(autor_uid=auth.uid() and app.can_upload_phase(reporte_id,fase)
  and storage_path like 'incidencias/'||reporte_id::text||'/'||fase||'/'||auth.uid()::text||'/%'
  and exists(select 1 from storage.objects where bucket_id='eco-evidencias' and name=storage_path));
create policy eco_noti_sel on public.notificaciones for select to authenticated using(destinatario_uid=auth.uid());
create policy eco_noti_upd on public.notificaciones for update to authenticated
 using(destinatario_uid=auth.uid()) with check(destinatario_uid=auth.uid());
create policy eco_rec_sel on public.puntos_reciclaje for select to authenticated using(verificado or app.is_admin());
create policy eco_rec_ins on public.puntos_reciclaje for insert to authenticated with check(app.is_admin());
-- Storage privado: rutas precisas y archivos pequeños para minimizar abusos.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('eco-evidencias','eco-evidencias',false,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=false,file_size_limit=5242880,
 allowed_mime_types=array['image/jpeg','image/png','image/webp'];
create policy eco_storage_read on storage.objects for select to authenticated using(
 bucket_id='eco-evidencias' and (
  ((storage.foldername(name))[1]='perfiles' and
     ((storage.foldername(name))[2]=auth.uid()::text or app.is_admin()))
  or ((storage.foldername(name))[1]='incidencias' and
     app.can_view_evidence(((storage.foldername(name))[2])::uuid))
 )
);
create policy eco_storage_upload on storage.objects for insert to authenticated with check(
 bucket_id='eco-evidencias' and (
  ((storage.foldername(name))[1]='perfiles' and (storage.foldername(name))[2]=auth.uid()::text)
  or ((storage.foldername(name))[1]='incidencias' and (storage.foldername(name))[4]=auth.uid()::text
     and app.can_upload_phase(((storage.foldername(name))[2])::uuid,(storage.foldername(name))[3]))
 )
);
-- No UPDATE ni DELETE de objetos para clientes; evita sustituir evidencia de auditoría.
-- Los avatares anteriores pueden permanecer; implementar limpieza administrada con Edge Function si crece el uso.

-- Realtime de chats, incidencias y notificaciones.
do $$ begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='mensajes') then
  alter publication supabase_realtime add table public.mensajes;
 end if;
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='incidencias') then
  alter publication supabase_realtime add table public.incidencias;
 end if;
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='notificaciones') then
  alter publication supabase_realtime add table public.notificaciones;
 end if;
end $$;


-- ACTIVACIÓN MANUAL DEL ADMINISTRADOR DESDE SQL EDITOR, JAMÁS DESDE EL CLIENTE:
-- update public.perfiles set role='admin' where id='UUID_DEL_USUARIO';
-- Los antiguos usuarios mantienen UUID, contraseña y pertenencia a brigadas.
