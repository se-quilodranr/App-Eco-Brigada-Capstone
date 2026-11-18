-- EcoBrigada MVP - ejecutar UNA VEZ en un proyecto Supabase nuevo.
-- Este esquema sustituye Firebase Auth/Firestore/Storage por Supabase.
create extension if not exists pgcrypto;

create table public.perfiles (
 id uuid primary key references auth.users(id) on delete cascade,
 nombre text not null default 'EcoBrigadista' check(length(nombre) between 2 and 100),
 puntos integer not null default 0 check(puntos >= 0),
 creado_en timestamptz not null default now()
);

create or replace function public.crear_perfil() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
 insert into public.perfiles(id,nombre)
 values(new.id, coalesce(nullif(left(trim(new.raw_user_meta_data->>'nombre'),100),''),'EcoBrigadista'))
 on conflict(id) do nothing;
 return new;
end $$;
create trigger auth_nuevo_perfil after insert on auth.users
for each row execute function public.crear_perfil();

create table public.brigadas (
 id uuid primary key default gen_random_uuid(),
 nombre text not null check(length(trim(nombre)) between 3 and 100),
 comuna text not null check(length(trim(comuna)) between 2 and 100),
 descripcion text not null default '',
 creador_id uuid not null references public.perfiles(id),
 estado text not null default 'abierta' check(estado in ('abierta','cerrada')),
 creada_en timestamptz not null default now()
);
create table public.brigada_miembros (
 brigada_id uuid not null references public.brigadas(id) on delete cascade,
 usuario_id uuid not null references public.perfiles(id) on delete cascade,
 rol text not null default 'miembro' check(rol in ('administrador','miembro')),
 unido_en timestamptz not null default now(),
 primary key(brigada_id,usuario_id)
);
create or replace function public.agregar_creador() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
 insert into public.brigada_miembros(brigada_id,usuario_id,rol)
 values(new.id,new.creador_id,'administrador');
 return new;
end $$;
create trigger brigada_creada after insert on public.brigadas
for each row execute function public.agregar_creador();

create table public.actividades (
 id uuid primary key default gen_random_uuid(),
 brigada_id uuid not null references public.brigadas(id) on delete cascade,
 titulo text not null check(length(trim(titulo)) between 3 and 150),
 descripcion text not null default '',
 latitud double precision not null check(latitud between -90 and 90),
 longitud double precision not null check(longitud between -180 and 180),
 fecha_inicio timestamptz not null default now(),
 estado text not null default 'programada' check(estado in ('programada','en_curso','finalizada')),
 creada_en timestamptz not null default now()
);
create table public.actividad_participantes (
 actividad_id uuid not null references public.actividades(id) on delete cascade,
 usuario_id uuid not null references public.perfiles(id) on delete cascade,
 unido_en timestamptz not null default now(),
 primary key(actividad_id,usuario_id)
);
create table public.solicitudes (
 id uuid primary key default gen_random_uuid(),
 brigada_id uuid not null references public.brigadas(id) on delete cascade,
 actividad_id uuid references public.actividades(id) on delete set null,
 usuario_id uuid not null references public.perfiles(id) on delete cascade,
 mensaje text not null default '',
 estado text not null default 'pendiente' check(estado in ('pendiente','aceptada','rechazada')),
 enviada_en timestamptz not null default now(),
 revisada_en timestamptz,
 revisada_por uuid references public.perfiles(id)
);
create unique index solo_una_solicitud_pendiente on public.solicitudes(
 brigada_id,usuario_id,coalesce(actividad_id,'00000000-0000-0000-0000-000000000000'::uuid)
) where estado='pendiente';

create table public.mensajes (
 id uuid primary key default gen_random_uuid(),
 brigada_id uuid not null references public.brigadas(id) on delete cascade,
 autor_id uuid not null references public.perfiles(id),
 texto text not null check(length(trim(texto)) between 1 and 2000),
 enviado_en timestamptz not null default now()
);

create table public.lugares (
 id uuid primary key default gen_random_uuid(),
 nombre text not null check(length(trim(nombre)) between 3 and 150),
 descripcion text not null default '',
 latitud double precision not null check(latitud between -90 and 90),
 longitud double precision not null check(longitud between -180 and 180),
 estado text not null default 'sucio' check(estado in ('sucio','limpio')),
 creado_por uuid not null references public.perfiles(id),
 actualizado_en timestamptz not null default now()
);
create table public.lugar_historial (
 id bigint generated always as identity primary key,
 lugar_id uuid not null references public.lugares(id) on delete cascade,
 usuario_id uuid not null references public.perfiles(id),
 estado_anterior text,
 estado_nuevo text not null check(estado_nuevo in ('sucio','limpio')),
 cambiado_en timestamptz not null default now()
);

create table public.publicaciones (
 id uuid primary key default gen_random_uuid(),
 autor_id uuid not null references public.perfiles(id),
 titulo text not null check(length(trim(titulo)) between 3 and 150),
 descripcion text not null default '',
 materiales text not null default '',
 estado text not null default 'borrador' check(estado in ('borrador','publicada')),
 creada_en timestamptz not null default now()
);
create table public.publicacion_pasos (
 id uuid primary key default gen_random_uuid(),
 publicacion_id uuid not null references public.publicaciones(id) on delete cascade,
 numero integer not null check(numero between 1 and 12),
 texto text not null check(length(trim(texto)) between 1 and 2000),
 unique(publicacion_id,numero)
);
create table public.publicacion_fotos (
 id uuid primary key default gen_random_uuid(),
 publicacion_id uuid not null references public.publicaciones(id) on delete cascade,
 ruta_storage text not null,
 posicion integer not null check(posicion between 0 and 7),
 unique(publicacion_id,posicion)
);
create table public.publicacion_likes (
 publicacion_id uuid not null references public.publicaciones(id) on delete cascade,
 usuario_id uuid not null references public.perfiles(id) on delete cascade,
 primary key(publicacion_id,usuario_id)
);
create table public.comentarios (
 id uuid primary key default gen_random_uuid(),
 publicacion_id uuid not null references public.publicaciones(id) on delete cascade,
 autor_id uuid not null references public.perfiles(id),
 texto text not null check(length(trim(texto)) between 1 and 1000),
 creado_en timestamptz not null default now()
);
create table public.reportes (
 id uuid primary key default gen_random_uuid(),
 publicacion_id uuid not null references public.publicaciones(id) on delete cascade,
 reportador_id uuid not null references public.perfiles(id),
 motivo text not null check(length(trim(motivo)) between 5 and 250),
 estado text not null default 'pendiente' check(estado in ('pendiente','revisado','descartado')),
 enviado_en timestamptz not null default now(),
 unique(publicacion_id,reportador_id)
);

-- Indices
create index on public.actividades(brigada_id,estado);
create index on public.actividades(estado,fecha_inicio);
create index on public.solicitudes(brigada_id,estado);
create index on public.brigada_miembros(usuario_id);
create index on public.mensajes(brigada_id,enviado_en);
create index on public.lugar_historial(lugar_id,cambiado_en);
create index on public.publicaciones(creada_en desc);
create index on public.comentarios(publicacion_id,creado_en);

-- Funciones privilegiadas: servidor verifica siempre auth.uid().
create or replace function public.soy_miembro(p_brigada uuid)
returns boolean language sql stable security definer set search_path = '' as $$
 select exists(
  select 1 from public.brigada_miembros
  where brigada_id=p_brigada and usuario_id=(select auth.uid())
 );
$$;
create or replace function public.soy_admin(p_brigada uuid)
returns boolean language sql stable security definer set search_path = '' as $$
 select exists(
  select 1 from public.brigadas
  where id=p_brigada and creador_id=(select auth.uid())
 );
$$;

-- Solicitud a brigada o a su actividad. Si el usuario ya es miembro,
-- puede pedir ingresar a otra actividad, con aprobación del administrador.
create or replace function public.enviar_solicitud(
 p_brigada uuid, p_actividad uuid default null, p_mensaje text default ''
) returns uuid language plpgsql security definer set search_path = '' as $$
declare v_estado text; v_solicitud uuid; v_estado_act text;
begin
 if (select auth.uid()) is null then
  raise exception 'Inicia sesión para solicitar ingreso';
 end if;
 select estado into v_estado from public.brigadas where id=p_brigada for update;
 if v_estado is null then raise exception 'Brigada inexistente'; end if;
 if v_estado='cerrada' then raise exception 'La brigada está cerrada a solicitudes'; end if;
 if p_actividad is null and public.soy_miembro(p_brigada) then
  raise exception 'Ya perteneces a esta brigada';
 end if;
 if p_actividad is not null then
  select estado into v_estado_act from public.actividades
  where id=p_actividad and brigada_id=p_brigada;
  if v_estado_act is null or v_estado_act='finalizada' then
   raise exception 'La actividad no admite solicitudes';
  end if;
  if exists(select 1 from public.actividad_participantes
     where actividad_id=p_actividad and usuario_id=(select auth.uid())) then
   raise exception 'Ya participas en esta actividad';
  end if;
 end if;
 insert into public.solicitudes(brigada_id,actividad_id,usuario_id,mensaje)
 values(p_brigada,p_actividad,(select auth.uid()),left(coalesce(p_mensaje,''),500))
 returning id into v_solicitud;
 return v_solicitud;
end $$;

create or replace function public.resolver_solicitud(
 p_solicitud uuid, p_aceptar boolean
) returns void language plpgsql security definer set search_path = '' as $$
declare s public.solicitudes%rowtype;
begin
 select * into s from public.solicitudes where id=p_solicitud for update;
 if not found then raise exception 'Solicitud inexistente'; end if;
 if not public.soy_admin(s.brigada_id) then raise exception 'Solo el administrador puede resolverla'; end if;
 if s.estado <> 'pendiente' then raise exception 'Esta solicitud ya fue revisada'; end if;
 if p_aceptar then
  insert into public.brigada_miembros(brigada_id,usuario_id,rol)
  values(s.brigada_id,s.usuario_id,'miembro') on conflict do nothing;
  if s.actividad_id is not null then
   if exists(select 1 from public.actividades where id=s.actividad_id and estado<>'finalizada') then
    insert into public.actividad_participantes(actividad_id,usuario_id)
    values(s.actividad_id,s.usuario_id) on conflict do nothing;
   else
    raise exception 'La actividad ya finalizó';
   end if;
  end if;
 end if;
 update public.solicitudes
 set estado=case when p_aceptar then 'aceptada' else 'rechazada' end,
     revisada_en=now(), revisada_por=(select auth.uid())
 where id=p_solicitud;
end $$;

-- Los lugares pueden cambiar de sucio a limpio y viceversa.
-- Se conserva trazabilidad sin permitir editar otros campos.
create or replace function public.marcar_lugar(p_lugar uuid,p_estado text)
returns void language plpgsql security definer set search_path = '' as $$
declare anterior text;
begin
 if (select auth.uid()) is null then raise exception 'Inicia sesión'; end if;
 if p_estado not in ('sucio','limpio') or p_estado is null then
  raise exception 'Estado inválido';
 end if;
 select estado into anterior from public.lugares where id=p_lugar for update;
 if anterior is null then raise exception 'Lugar inexistente'; end if;
 if anterior=p_estado then return; end if;
 update public.lugares set estado=p_estado, actualizado_en=now() where id=p_lugar;
 insert into public.lugar_historial(lugar_id,usuario_id,estado_anterior,estado_nuevo)
 values(p_lugar,(select auth.uid()),anterior,p_estado);
end $$;

create or replace function public.log_lugar_nuevo() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
 insert into public.lugar_historial(lugar_id,usuario_id,estado_anterior,estado_nuevo)
 values(new.id,new.creado_por,null,new.estado);
 return new;
end $$;
create trigger lugar_creado after insert on public.lugares
for each row execute function public.log_lugar_nuevo();

-- Activar RLS en TODAS las tablas públicas.
do $$ declare r record; begin
 for r in select table_name from information_schema.tables
 where table_schema='public' and table_name in
 ('perfiles','brigadas','brigada_miembros','actividades','actividad_participantes',
 'solicitudes','mensajes','lugares','lugar_historial','publicaciones',
 'publicacion_pasos','publicacion_fotos','publicacion_likes','comentarios','reportes')
 loop execute format('alter table public.%I enable row level security',r.table_name); end loop;
end $$;

create policy "Perfiles visibles" on public.perfiles for select to anon,authenticated using(true);
create policy "Editar solo nombre propio" on public.perfiles for update to authenticated
 using(id=(select auth.uid())) with check(id=(select auth.uid()));

create policy "Ver brigadas" on public.brigadas for select to anon,authenticated using(true);
create policy "Crear brigada propia" on public.brigadas for insert to authenticated
 with check(creador_id=(select auth.uid()));
create policy "Editar brigada admin" on public.brigadas for update to authenticated
 using(public.soy_admin(id)) with check(public.soy_admin(id));

create policy "Ver miembros" on public.brigada_miembros for select to anon,authenticated using(true);
-- Inserción en brigada_miembros solo por triggers/RPC, no por cliente.

create policy "Ver actividades" on public.actividades for select to anon,authenticated using(true);
create policy "Crear actividad admin" on public.actividades for insert to authenticated
 with check(public.soy_admin(brigada_id));
create policy "Editar actividad admin" on public.actividades for update to authenticated
 using(public.soy_admin(brigada_id)) with check(public.soy_admin(brigada_id));
create policy "Ver participantes" on public.actividad_participantes for select to authenticated using(true);

create policy "Solicitudes propias o admin" on public.solicitudes for select to authenticated
 using(usuario_id=(select auth.uid()) or public.soy_admin(brigada_id));
-- Inserción y resolución solo mediante funciones servidoras.

create policy "Leer chat solo miembros" on public.mensajes for select to authenticated
 using(public.soy_miembro(brigada_id));
create policy "Escribir chat solo miembros" on public.mensajes for insert to authenticated
 with check(autor_id=(select auth.uid()) and public.soy_miembro(brigada_id));

create policy "Ver lugares" on public.lugares for select to anon,authenticated using(true);
create policy "Agregar lugar" on public.lugares for insert to authenticated
 with check(creado_por=(select auth.uid()));
-- Cambio de estado solamente por RPC marcar_lugar.
create policy "Ver historial de lugares" on public.lugar_historial for select to anon,authenticated using(true);

create policy "Ver publicaciones" on public.publicaciones for select to anon,authenticated
 using(estado='publicada' or autor_id=(select auth.uid()));
create policy "Crear borrador propio" on public.publicaciones for insert to authenticated
 with check(autor_id=(select auth.uid()) and estado='borrador');
create policy "Editar publicación propia" on public.publicaciones for update to authenticated
 using(autor_id=(select auth.uid())) with check(autor_id=(select auth.uid()));
create policy "Ver pasos" on public.publicacion_pasos for select to anon,authenticated
 using(exists(select 1 from public.publicaciones p where p.id=publicacion_id));
create policy "Agregar pasos propios" on public.publicacion_pasos for insert to authenticated
 with check(exists(select 1 from public.publicaciones p where p.id=publicacion_id and p.autor_id=(select auth.uid()) and p.estado='borrador'));
create policy "Ver fotos" on public.publicacion_fotos for select to anon,authenticated
 using(exists(select 1 from public.publicaciones p where p.id=publicacion_id));
create policy "Agregar fotos propias" on public.publicacion_fotos for insert to authenticated
 with check(exists(select 1 from public.publicaciones p where p.id=publicacion_id and p.autor_id=(select auth.uid()) and p.estado='borrador')
 and split_part(ruta_storage,'/',1)=(select auth.uid())::text
 and split_part(ruta_storage,'/',2)=publicacion_id::text);
create policy "Ver likes" on public.publicacion_likes for select to anon,authenticated using(true);
create policy "Dar like propio" on public.publicacion_likes for insert to authenticated
 with check(usuario_id=(select auth.uid()) and exists(select 1 from public.publicaciones p where p.id=publicacion_id and p.estado='publicada'));
create policy "Quitar like propio" on public.publicacion_likes for delete to authenticated
 using(usuario_id=(select auth.uid()));
create policy "Ver comentarios" on public.comentarios for select to anon,authenticated using(true);
create policy "Comentar propio" on public.comentarios for insert to authenticated
 with check(autor_id=(select auth.uid()) and exists(select 1 from public.publicaciones p where p.id=publicacion_id and p.estado='publicada'));
create policy "Denunciar otra publicacion" on public.reportes for insert to authenticated
 with check(reportador_id=(select auth.uid()) and estado='pendiente' and exists(
 select 1 from public.publicaciones p where p.id=publicacion_id
 and p.estado='publicada' and p.autor_id<>(select auth.uid())
 ));

-- Privilegios API; RLS restringe filas y GRANT restringe operaciones/columnas.
revoke all on public.perfiles,public.brigadas,public.brigada_miembros,
 public.actividades,public.actividad_participantes,public.solicitudes,
 public.mensajes,public.lugares,public.lugar_historial,
 public.publicaciones,public.publicacion_pasos,public.publicacion_fotos,
 public.publicacion_likes,public.comentarios,public.reportes
 from anon,authenticated;
grant usage on schema public to anon, authenticated;
grant select on public.perfiles,public.brigadas,public.actividades,public.lugares,
 public.lugar_historial,public.publicaciones,public.publicacion_pasos,
 public.publicacion_fotos,public.publicacion_likes,public.comentarios
 to anon,authenticated;
grant select on public.brigada_miembros to anon,authenticated;
grant select on public.actividad_participantes,
 public.solicitudes,public.mensajes to authenticated;
grant update(nombre) on public.perfiles to authenticated;
grant insert on public.brigadas,public.actividades,public.mensajes,public.lugares,
 public.publicaciones,public.publicacion_pasos,public.publicacion_fotos,
 public.publicacion_likes,public.comentarios,public.reportes to authenticated;
grant update(nombre,comuna,descripcion,estado) on public.brigadas to authenticated;
grant update(titulo,descripcion,latitud,longitud,fecha_inicio,estado)
 on public.actividades to authenticated;
grant update(titulo,descripcion,materiales,estado) on public.publicaciones to authenticated;
grant delete on public.publicacion_likes to authenticated;

revoke all on function public.soy_admin(uuid),public.soy_miembro(uuid),
 public.enviar_solicitud(uuid,uuid,text),public.resolver_solicitud(uuid,boolean),
 public.marcar_lugar(uuid,text) from public,anon,authenticated;
grant execute on function public.soy_admin(uuid),public.soy_miembro(uuid),
 public.enviar_solicitud(uuid,uuid,text),public.resolver_solicitud(uuid,boolean),
 public.marcar_lugar(uuid,text) to authenticated;

-- Bucket público para fotografías de guías (NO para contenido privado).
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('publicaciones','publicaciones',true,5242880,
 array['image/jpeg','image/png','image/webp'])
on conflict(id) do nothing;
create policy "Guardar foto solo en carpeta propia"
 on storage.objects for insert to authenticated
 with check(bucket_id='publicaciones' and split_part(name,'/',1)=(select auth.uid())::text
 and exists(select 1 from public.publicaciones p
 where p.id::text=split_part(name,'/',2) and p.autor_id=(select auth.uid()) and p.estado='borrador'));

-- Chat en tiempo real. En Dashboard también puede habilitarse en Replication.
alter publication supabase_realtime add table public.mensajes;
