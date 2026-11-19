begin;
alter table public.incidencias add column if not exists tomada_por uuid references public.perfiles(id),
  add column if not exists responsable_nombre text,
  add column if not exists tomada_en timestamptz;
alter table public.incidencias drop constraint if exists incidencias_estado_check;
alter table public.incidencias add constraint incidencias_estado_check check (estado in ('pendiente','validado','asignado','en_proceso','en_revision','cerrado','descartado','tomada'));
drop policy if exists eco_inc_ins on public.incidencias;
create policy eco_inc_ins on public.incidencias for insert to authenticated
with check(creador_uid=auth.uid() and estado='pendiente' and brigada_id is null and tomada_por is null and responsable_nombre is null and tomada_en is null);

create or replace function public.tomar_incidencia(p_id uuid, p_brigada uuid default null)
returns void language plpgsql security definer set search_path='' as $$
declare r public.incidencias%rowtype; nombre text;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;
  select * into r from public.incidencias where id=p_id for update;
  if not found or r.estado not in ('pendiente','validado') or r.tomada_por is not null then
    raise exception 'La incidencia ya no está disponible';
  end if;
  if p_brigada is null then
    select p.nombre into nombre from public.perfiles p where p.id=auth.uid();
  else
    select b.nombre into nombre from public.brigadas b where b.id=p_brigada and b.lider_uid=auth.uid();
    if not found then raise exception 'Solo el líder puede tomarla por su brigada'; end if;
  end if;
  if nombre is null then raise exception 'Perfil no disponible'; end if;
  update public.incidencias set estado='tomada', tomada_por=auth.uid(), brigada_id=p_brigada,
    responsable_nombre=nombre,tomada_en=now(),actualizado_en=now() where id=p_id;
  insert into public.historial_incidencias(reporte_id,anterior,nuevo,autor_uid,comentario)
    values(p_id,r.estado,'tomada',auth.uid(),'Tomada por '||case when p_brigada is null then 'persona: ' else 'brigada: ' end||nombre);
end $$;

create or replace function public.terminar_incidencia(p_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare r public.incidencias%rowtype;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;
  select * into r from public.incidencias where id=p_id for update;
  if not found or r.estado <> 'tomada' or r.tomada_por is distinct from auth.uid() then
    raise exception 'Solo quien tomó la incidencia puede finalizarla';
  end if;
  if not exists(select 1 from public.fotos_incidencia where reporte_id=p_id and fase='inicial' and autor_uid=auth.uid() and creado_en>=r.tomada_en)
     or not exists(select 1 from public.fotos_incidencia where reporte_id=p_id and fase='posterior' and autor_uid=auth.uid() and creado_en>=r.tomada_en) then
    raise exception 'Debes registrar las fotografías del antes y después';
  end if;
  update public.incidencias set estado='cerrado',cerrado_en=now(),actualizado_en=now() where id=p_id;
  insert into public.historial_incidencias(reporte_id,anterior,nuevo,autor_uid,comentario)
    values(p_id,'tomada','cerrado',auth.uid(),'Finalizada por '||r.responsable_nombre);
end $$;

create or replace function app.can_upload_phase(p_id uuid,p_phase text) returns boolean
language sql stable security definer set search_path='' as $$
select exists(select 1 from public.incidencias i where i.id=p_id and (
  (i.estado='tomada' and i.tomada_por=auth.uid() and (p_phase='inicial' or (p_phase='posterior' and exists(
    select 1 from public.fotos_incidencia f where f.reporte_id=i.id and f.fase='inicial' and f.autor_uid=auth.uid() and f.creado_en>=i.tomada_en)))) or
  (p_phase='inicial' and i.estado in ('pendiente','validado') and (i.creador_uid=auth.uid() or app.is_admin())) or
  (p_phase='posterior' and i.estado in ('asignado','en_proceso','en_revision') and (app.is_admin() or app.can_manage_brigade(i.brigada_id)))
)) $$;

create or replace function app.can_view_evidence(p_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
select auth.uid() is not null and exists(select 1 from public.incidencias where id=p_id) $$;

revoke all on function public.tomar_incidencia(uuid,uuid),public.terminar_incidencia(uuid) from public;
grant execute on function public.tomar_incidencia(uuid,uuid),public.terminar_incidencia(uuid) to authenticated;
do $$ begin
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='incidencias') then
    alter publication supabase_realtime add table public.incidencias;
  end if;
end $$;
commit;
