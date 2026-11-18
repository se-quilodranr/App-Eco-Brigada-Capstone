-- ECOBRIGADA 3.1 / PERMISOS, JEFATURAS Y ENTREGA FINAL
-- REQUISITO: ejecutar primero las migraciones 202611170001 y 202611170002.
-- Esta migración NO borra datos, cuentas, mensajes ni incidencias existentes.
-- Ejecutar desde SQL Editor con rol postgres; obtener respaldo primero.
begin;

do $$ begin
  if to_regclass('public.incidencias') is null or to_regclass('public.brigadas') is null
     or to_regclass('public.perfiles') is null or to_regclass('public.solicitudes') is null then
    raise exception 'Primero aplica la migración 202611170001: faltan tablas base de EcoBrigada 3.0';
  end if;
end $$;

-- Es administrador global SOLO quien tiene role=admin en public.perfiles.
-- Se identifica al jefe por el UUID lider_uid, no por ser un antiguo creador.
create or replace function app.is_leader(p_brigada uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.brigadas b
    where b.id=p_brigada and b.lider_uid=auth.uid())
$$;
create or replace function app.can_manage_brigade(p_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select app.is_admin() or app.is_leader(p_id)
$$;
create or replace function public.soy_admin(p_brigada uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select app.can_manage_brigade(p_brigada)
$$;
-- Un creador anterior que ya no sea jefe NO puede administrar la brigada.
create or replace function app.can_chat(p_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select app.can_manage_brigade(p_id) or exists(
  select 1 from public.brigada_miembros m
  where m.brigada_id=p_id and m.usuario_id=auth.uid())
$$;
create or replace function app.can_upload_phase(p_id uuid,p_phase text)
returns boolean language sql stable security definer set search_path='' as $$
 select case when p_phase='inicial' then exists(
   select 1 from public.incidencias i where i.id=p_id
    and i.estado in ('pendiente','validado')
    and (i.creador_uid=auth.uid() or app.is_admin()))
  when p_phase='posterior' then exists(
   select 1 from public.incidencias i where i.id=p_id
    and i.estado in ('asignado','en_proceso','en_revision')
    and app.is_leader(i.brigada_id))
 else false end
$$;
revoke all on function app.is_leader(uuid) from public,anon;
grant execute on function app.is_leader(uuid) to authenticated;

-- CIUDADANOS: pueden fundar su propia brigada y serán sus jefes.
-- Nadie puede elegir otro líder mediante la API de Flutter.
create or replace function app.default_brigade_fields()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='INSERT' then
   new.lider_uid := new.creador_id;
 end if;
 new.disponible := (new.estado='abierta');
 return new;
end;$$;
drop policy if exists eco_admin_crear_brigada on public.brigadas;
drop policy if exists eco_ciudadano_crear_brigada on public.brigadas;
create policy eco_ciudadano_crear_brigada on public.brigadas
 for insert to authenticated with check (
  creador_id=auth.uid() and lider_uid=auth.uid() and estado='abierta'
 );
-- Se permite fundar más de una brigada si un ciudadano lo necesita;
-- la unicidad de jefes se impone solo a la carga ficticia de esta entrega.

-- Memoria técnica de la limpieza: una por incidencia, con responsables verificables.
create table if not exists public.informes_finales_brigada (
 id uuid primary key default gen_random_uuid(),
 reporte_id uuid not null unique references public.incidencias(id) on delete cascade,
 brigada_id uuid not null references public.brigadas(id),
 lider_uid uuid not null references public.perfiles(id),
 resumen text not null check(char_length(btrim(resumen)) between 20 and 4000),
 participantes integer not null check(participantes between 1 and 1000),
 kilos_estimados numeric(10,2) not null default 0 check(kilos_estimados>=0),
 fecha_envio timestamptz not null default now()
);
create index if not exists idx_informes_brigada_fecha
  on public.informes_finales_brigada(brigada_id,fecha_envio desc);
alter table public.informes_finales_brigada enable row level security;
revoke all on public.informes_finales_brigada from anon,authenticated;
grant select on public.informes_finales_brigada to authenticated;
drop policy if exists eco_informe_leer on public.informes_finales_brigada;
create policy eco_informe_leer on public.informes_finales_brigada
 for select to authenticated using(
  app.is_admin() or app.is_leader(brigada_id) or exists(
    select 1 from public.incidencias i where i.id=reporte_id
      and i.creador_uid=auth.uid())
 );

-- El jefe asignado es el único que puede REMITIR la memoria final.
-- Se exige evidencia fotográfica posterior real en Storage.
create or replace function public.eco_enviar_informe_final(
 p_reporte uuid,p_resumen text,p_participantes integer,p_kilos_estimados numeric default 0)
returns void language plpgsql security definer set search_path='' as $$
declare r public.incidencias%rowtype;
begin
 if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;
 select * into r from public.incidencias where id=p_reporte for update;
 if not found then raise exception 'Incidencia inexistente'; end if;
 if r.estado <> 'en_proceso' then
   raise exception 'La incidencia debe estar en ejecución antes del informe';
 end if;
 if r.brigada_id is null or not app.is_leader(r.brigada_id) then
   raise exception 'Solo el jefe asignado puede enviar el informe final';
 end if;
 if char_length(btrim(coalesce(p_resumen,''))) < 20 or
    char_length(btrim(coalesce(p_resumen,''))) > 4000 then
   raise exception 'El resumen debe tener entre 20 y 4000 caracteres';
 end if;
 if p_participantes is null or p_participantes < 1 or p_participantes > 1000 then
   raise exception 'La cantidad de participantes no es válida';
 end if;
 if p_kilos_estimados is null or p_kilos_estimados < 0 then
   raise exception 'El peso estimado no es válido';
 end if;
 if not exists(select 1 from public.fotos_incidencia f
   where f.reporte_id=p_reporte and f.fase='posterior') then
   raise exception 'Primero adjunta fotografía del resultado de la limpieza';
 end if;
 insert into public.informes_finales_brigada(
   reporte_id,brigada_id,lider_uid,resumen,participantes,kilos_estimados)
 values(p_reporte,r.brigada_id,auth.uid(),btrim(p_resumen),
   p_participantes,p_kilos_estimados)
 on conflict (reporte_id) do update set
   lider_uid=excluded.lider_uid,brigada_id=excluded.brigada_id,
   resumen=excluded.resumen,participantes=excluded.participantes,
   kilos_estimados=excluded.kilos_estimados,fecha_envio=now();
 update public.incidencias set estado='en_revision',actualizado_en=now()
   where id=p_reporte;
 insert into public.historial_incidencias(
   reporte_id,anterior,nuevo,autor_uid,comentario)
 values(p_reporte,r.estado,'en_revision',auth.uid(),
   'Jefe de brigada: informe final presentado para revisión.');
 insert into public.notificaciones(destinatario_uid,titulo,cuerpo,reporte_id)
 select p.id,'Informe final recibido',
  'Una brigada terminó su trabajo y espera revisión administrativa',p_reporte
 from public.perfiles p where p.role='admin';
end;$$;
revoke all on function public.eco_enviar_informe_final(uuid,text,integer,numeric) from public,anon;
grant execute on function public.eco_enviar_informe_final(uuid,text,integer,numeric) to authenticated;

-- El jefe puede iniciar una limpieza asignada; NO puede validarla.
-- El administrador valida y cierra; NO puede suplantar al jefe para entregar informes.
create or replace function public.cambiar_estado_reporte(
 p_id uuid,p_nuevo text,p_brigada uuid default null,p_comentario text default '')
returns void language plpgsql security definer set search_path='' as $$
declare r public.incidencias%rowtype;
begin
 if auth.uid() is null then raise exception 'Sesión requerida'; end if;
 select * into r from public.incidencias where id=p_id for update;
 if not found then raise exception 'Incidencia inexistente'; end if;
 if not ((r.estado='pendiente' and p_nuevo in ('validado','descartado')) or
   (r.estado='validado' and p_nuevo in ('asignado','descartado')) or
   (r.estado='asignado' and p_nuevo='en_proceso') or
   (r.estado='en_revision' and p_nuevo in ('en_proceso','cerrado'))) then
    raise exception 'Transición no permitida. El jefe debe usar Enviar informe final.';
 end if;
 if r.estado='asignado' and p_nuevo='en_proceso' then
   if not (app.is_admin() or app.is_leader(r.brigada_id)) then
     raise exception 'Solo el jefe de brigada o administración inicia trabajos';
   end if;
 elsif not app.is_admin() then
   raise exception 'Solo administración valida, asigna o cierra incidencias';
 end if;
 if p_nuevo='asignado' and (
   p_brigada is null or not exists(select 1 from public.brigadas b
      where b.id=p_brigada and b.disponible)) then
   raise exception 'Selecciona una brigada disponible';
 end if;
 if (p_nuevo in ('cerrado','descartado') or
     (r.estado='en_revision' and p_nuevo='en_proceso'))
    and char_length(btrim(coalesce(p_comentario,'')))<5 then
   raise exception 'Registra una observación de al menos 5 caracteres';
 end if;
 if p_nuevo='cerrado' and not exists(
   select 1 from public.informes_finales_brigada fi
   where fi.reporte_id=p_id) then
   raise exception 'No se puede cerrar sin informe final del jefe';
 end if;
 if p_nuevo='cerrado' and not exists(
   select 1 from public.fotos_incidencia f
   where f.reporte_id=p_id and f.fase='posterior') then
   raise exception 'Falta la fotografía posterior';
 end if;
 update public.incidencias set estado=p_nuevo,
  brigada_id=case when p_nuevo='asignado' then p_brigada else brigada_id end,
  actualizado_en=now(),
  cerrado_en=case when p_nuevo='cerrado' then now() else cerrado_en end
  where id=p_id;
 insert into public.historial_incidencias(
   reporte_id,anterior,nuevo,autor_uid,comentario)
 values(p_id,r.estado,p_nuevo,auth.uid(),btrim(coalesce(p_comentario,'')));
 if r.estado='en_revision' and p_nuevo in ('cerrado','en_proceso') then
   insert into public.validaciones_limpieza(
     reporte_id,revisor_uid,resultado,observacion)
   values(p_id,auth.uid(),case when p_nuevo='cerrado' then 'aprobada' else 'devuelta' end,
     btrim(p_comentario));
 end if;
 if p_nuevo='asignado' and p_brigada is not null then
   insert into public.notificaciones(destinatario_uid,titulo,cuerpo,reporte_id)
    select b.lider_uid,'Nueva incidencia asignada',
      'Tu brigada tiene un nuevo trabajo',p_id
    from public.brigadas b where b.id=p_brigada and b.lider_uid is not null
      and b.lider_uid<>auth.uid();
 end if;
 if r.creador_uid<>auth.uid() then
   insert into public.notificaciones(destinatario_uid,titulo,cuerpo,reporte_id)
   values(r.creador_uid,'Actualización de incidencia',
     'Tu reporte cambió al estado '||p_nuevo,p_id);
 end if;
end;$$;
revoke all on function public.cambiar_estado_reporte(uuid,text,uuid,text) from public,anon;
grant execute on function public.cambiar_estado_reporte(uuid,text,uuid,text) to authenticated;

-- Jornadas: estados controlados por el jefe correspondiente o un administrador.
create or replace function public.eco_cambiar_estado_jornada(
 p_jornada uuid,p_estado text)
returns void language plpgsql security definer set search_path='' as $$
declare a public.actividades%rowtype;
begin
 if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;
 select * into a from public.actividades where id=p_jornada for update;
 if not found then raise exception 'Jornada no encontrada'; end if;
 if not app.can_manage_brigade(a.brigada_id) then
  raise exception 'Solo el jefe o administración puede modificar la jornada';
 end if;
 if not ((a.estado='programada' and p_estado='en_curso') or
         (a.estado='en_curso' and p_estado='finalizada')) then
  raise exception 'Cambio de estado de jornada no permitido';
 end if;
 update public.actividades set estado=p_estado where id=p_jornada;
end;$$;
revoke all on function public.eco_cambiar_estado_jornada(uuid,text) from public,anon;
grant execute on function public.eco_cambiar_estado_jornada(uuid,text) to authenticated;

-- Solo SQL Editor puede asignar administrador global o reasignar líderes.
-- El cliente no puede actualizar role ni lider_uid.
commit;
