-- ECOBRIGADA 3.1 | PANEL ADMINISTRATIVO WEB
-- Ejecutar SOLO después de las migraciones 202611170001, 202611170002 y 202611180001.
-- El SQL no borra datos ni modifica los roles existentes.
-- Todas las funciones privilegiadas comprueban el rol en PostgreSQL, no en JavaScript.
-- IMPORTANTE: ejecutar desde SQL Editor como postgres, nunca desde la aplicación.
BEGIN;

DO $$ BEGIN
  IF to_regclass('public.perfiles') IS NULL
    OR to_regclass('public.brigadas') IS NULL
    OR to_regclass('public.incidencias') IS NULL
    OR to_regclass('public.actividades') IS NULL
    OR to_regclass('public.solicitudes') IS NULL
    OR to_regclass('public.historial_incidencias') IS NULL
    OR to_regclass('public.informes_finales_brigada') IS NULL THEN
      RAISE EXCEPTION 'Instala primero las migraciones de EcoBrigada 3.1';
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.eco_admin_auditoria (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 actor_uid uuid NOT NULL REFERENCES public.perfiles(id),
 accion text NOT NULL,
 entidad text NOT NULL,
 entidad_id uuid,
 detalle jsonb NOT NULL DEFAULT '{}'::jsonb,
 creado_en timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_eco_admin_auditoria_fecha ON public.eco_admin_auditoria(creado_en DESC);
ALTER TABLE public.eco_admin_auditoria ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.eco_admin_auditoria FROM anon, authenticated;
GRANT SELECT ON public.eco_admin_auditoria TO authenticated;
DROP POLICY IF EXISTS eco_admin_auditoria_solo_admin ON public.eco_admin_auditoria;
CREATE POLICY eco_admin_auditoria_solo_admin ON public.eco_admin_auditoria
 FOR SELECT TO authenticated USING (app.is_admin());

-- Datos de Auth, incluidos los emails, salen SOLO por un RPC verificado.
-- Nunca exponer auth.users directamente ni acceder desde una service_role en el navegador.
CREATE OR REPLACE FUNCTION public.eco_admin_usuarios(
 p_buscar text DEFAULT '', p_limite integer DEFAULT 30, p_desde integer DEFAULT 0
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_total bigint; v_items jsonb; v_q text := left(trim(coalesce(p_buscar,'')),100);
BEGIN
 IF NOT app.is_admin() THEN RAISE EXCEPTION 'Acceso restringido a administración' USING ERRCODE='42501'; END IF;
 SELECT count(*) INTO v_total FROM auth.users u JOIN public.perfiles p ON p.id=u.id
 WHERE v_q='' OR p.nombre ILIKE '%'||v_q||'%' OR u.email ILIKE '%'||v_q||'%';
 SELECT coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) INTO v_items FROM (
   SELECT u.id,u.email,p.nombre,p.role,p.creado_en,
    (SELECT count(*) FROM public.brigadas b WHERE b.lider_uid=u.id) AS lidera,
    (SELECT count(*) FROM public.brigada_miembros m WHERE m.usuario_id=u.id) AS pertenece,
    (SELECT count(*) FROM public.incidencias i WHERE i.creador_uid=u.id) AS reportes
   FROM auth.users u JOIN public.perfiles p ON p.id=u.id
   WHERE v_q='' OR p.nombre ILIKE '%'||v_q||'%' OR u.email ILIKE '%'||v_q||'%'
   ORDER BY p.creado_en DESC,u.id
   LIMIT greatest(1,least(coalesce(p_limite,30),100)) OFFSET greatest(0,coalesce(p_desde,0))
 ) q;
 RETURN jsonb_build_object('total',v_total,'items',v_items);
END; $$;

CREATE OR REPLACE FUNCTION public.eco_admin_cambiar_rol(p_usuario uuid,p_rol text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_anterior text;
BEGIN
 IF NOT app.is_admin() THEN RAISE EXCEPTION 'Permisos insuficientes' USING ERRCODE='42501'; END IF;
 IF p_rol IS NULL OR p_rol NOT IN ('ciudadano','admin') THEN RAISE EXCEPTION 'Rol inválido'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(91473101);
 SELECT role INTO v_anterior FROM public.perfiles WHERE id=p_usuario FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Usuario inexistente'; END IF;
 IF p_usuario=auth.uid() AND p_rol<>v_anterior THEN
  RAISE EXCEPTION 'No puedes modificar tu propio rol desde el panel';
 END IF;
 IF v_anterior='admin' AND p_rol<>'admin' AND
   (SELECT count(*) FROM public.perfiles WHERE role='admin')<=1 THEN
   RAISE EXCEPTION 'No es posible quitar el último administrador';
 END IF;
 IF v_anterior=p_rol THEN RETURN; END IF;
 UPDATE public.perfiles SET role=p_rol WHERE id=p_usuario;
 INSERT INTO public.eco_admin_auditoria(actor_uid,accion,entidad,entidad_id,detalle)
 VALUES(auth.uid(),'cambio_rol','perfil',p_usuario,
  jsonb_build_object('anterior',v_anterior,'nuevo',p_rol));
END; $$;

CREATE OR REPLACE FUNCTION public.eco_admin_brigadas(
 p_buscar text DEFAULT '',p_limite integer DEFAULT 30,p_desde integer DEFAULT 0
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_q text := left(trim(coalesce(p_buscar,'')),100); v_total bigint; v_items jsonb;
BEGIN
 IF NOT app.is_admin() THEN RAISE EXCEPTION 'Permisos insuficientes' USING ERRCODE='42501'; END IF;
 SELECT count(*) INTO v_total FROM public.brigadas b
 WHERE v_q='' OR b.nombre ILIKE '%'||v_q||'%' OR b.comuna ILIKE '%'||v_q||'%';
 SELECT coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) INTO v_items FROM (
 SELECT b.id,b.nombre,b.comuna,b.descripcion,b.estado,b.disponible,b.miembros,b.lider_uid,
  p.nombre AS lider,b.creada_en,
  (SELECT count(*) FROM public.incidencias i WHERE i.brigada_id=b.id) AS incidencias,
  (SELECT count(*) FROM public.incidencias i WHERE i.brigada_id=b.id AND i.estado='cerrado') AS resueltas
 FROM public.brigadas b LEFT JOIN public.perfiles p ON p.id=b.lider_uid
 WHERE v_q='' OR b.nombre ILIKE '%'||v_q||'%' OR b.comuna ILIKE '%'||v_q||'%'
 ORDER BY b.creada_en DESC,b.id
 LIMIT greatest(1,least(coalesce(p_limite,30),100)) OFFSET greatest(0,coalesce(p_desde,0))
 ) q;
 RETURN jsonb_build_object('total',v_total,'items',v_items);
END; $$;

CREATE OR REPLACE FUNCTION public.eco_admin_cambiar_lider(p_brigada uuid,p_usuario uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_anterior uuid;
BEGIN
 IF NOT app.is_admin() THEN RAISE EXCEPTION 'Permisos insuficientes' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.perfiles WHERE id=p_usuario) THEN RAISE EXCEPTION 'El usuario no existe'; END IF;
 SELECT lider_uid INTO v_anterior FROM public.brigadas WHERE id=p_brigada FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Brigada inexistente'; END IF;
 IF v_anterior=p_usuario THEN RETURN; END IF;
 INSERT INTO public.brigada_miembros(brigada_id,usuario_id,rol)
 VALUES(p_brigada,p_usuario,'administrador')
 ON CONFLICT(brigada_id,usuario_id) DO UPDATE SET rol='administrador';
 IF v_anterior IS NOT NULL THEN
  UPDATE public.brigada_miembros SET rol='miembro'
  WHERE brigada_id=p_brigada AND usuario_id=v_anterior;
 END IF;
 UPDATE public.brigadas SET lider_uid=p_usuario WHERE id=p_brigada;
 INSERT INTO public.eco_admin_auditoria(actor_uid,accion,entidad,entidad_id,detalle)
 VALUES(auth.uid(),'cambio_lider','brigada',p_brigada,
   jsonb_build_object('anterior',v_anterior,'nuevo',p_usuario));
END; $$;

CREATE OR REPLACE FUNCTION public.eco_admin_estado_brigada(p_brigada uuid,p_estado text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_old text;
BEGIN
 IF NOT app.is_admin() THEN RAISE EXCEPTION 'Permisos insuficientes' USING ERRCODE='42501'; END IF;
 IF p_estado NOT IN ('abierta','cerrada') THEN RAISE EXCEPTION 'Estado inválido'; END IF;
 SELECT estado INTO v_old FROM public.brigadas WHERE id=p_brigada FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Brigada inexistente'; END IF;
 IF v_old=p_estado THEN RETURN; END IF;
 UPDATE public.brigadas SET estado=p_estado WHERE id=p_brigada;
 INSERT INTO public.eco_admin_auditoria(actor_uid,accion,entidad,entidad_id,detalle)
 VALUES(auth.uid(),'estado_brigada','brigada',p_brigada,
  jsonb_build_object('anterior',v_old,'nuevo',p_estado));
END; $$;

CREATE OR REPLACE FUNCTION public.eco_admin_miembros(p_brigada uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_items jsonb;
BEGIN
 IF NOT app.is_admin() THEN RAISE EXCEPTION 'Permisos insuficientes' USING ERRCODE='42501'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) INTO v_items FROM (
 SELECT m.usuario_id AS id,p.nombre,u.email,m.rol,m.unido_en
 FROM public.brigada_miembros m JOIN public.perfiles p ON p.id=m.usuario_id
 LEFT JOIN auth.users u ON u.id=m.usuario_id
 WHERE m.brigada_id=p_brigada ORDER BY p.nombre LIMIT 300
 ) q;
 RETURN v_items;
END; $$;

CREATE OR REPLACE FUNCTION public.eco_admin_agregar_miembro(p_brigada uuid,p_usuario uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT app.is_admin() THEN RAISE EXCEPTION 'Permisos insuficientes' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.brigadas WHERE id=p_brigada) THEN RAISE EXCEPTION 'Brigada inexistente'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.perfiles WHERE id=p_usuario) THEN RAISE EXCEPTION 'Usuario inexistente'; END IF;
 INSERT INTO public.brigada_miembros(brigada_id,usuario_id,rol)
 VALUES(p_brigada,p_usuario,'miembro') ON CONFLICT DO NOTHING;
 INSERT INTO public.eco_admin_auditoria(actor_uid,accion,entidad,entidad_id,detalle)
 VALUES(auth.uid(),'agregar_miembro','brigada',p_brigada,jsonb_build_object('usuario',p_usuario));
END; $$;

CREATE OR REPLACE FUNCTION public.eco_admin_quitar_miembro(p_brigada uuid,p_usuario uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT app.is_admin() THEN RAISE EXCEPTION 'Permisos insuficientes' USING ERRCODE='42501'; END IF;
 IF EXISTS(SELECT 1 FROM public.brigadas WHERE id=p_brigada AND lider_uid=p_usuario) THEN
  RAISE EXCEPTION 'Debes asignar un líder diferente antes de quitar este miembro';
 END IF;
 DELETE FROM public.brigada_miembros WHERE brigada_id=p_brigada AND usuario_id=p_usuario;
 IF FOUND THEN
  INSERT INTO public.eco_admin_auditoria(actor_uid,accion,entidad,entidad_id,detalle)
  VALUES(auth.uid(),'quitar_miembro','brigada',p_brigada,jsonb_build_object('usuario',p_usuario));
 END IF;
END; $$;

CREATE OR REPLACE FUNCTION public.eco_admin_incidencias(
 p_buscar text DEFAULT '',p_estado text DEFAULT '',p_limite integer DEFAULT 30,p_desde integer DEFAULT 0
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_q text:=left(trim(coalesce(p_buscar,'')),100); v_estado text:=coalesce(p_estado,''); v_total bigint;v_items jsonb;
BEGIN
 IF NOT app.is_admin() THEN RAISE EXCEPTION 'Permisos insuficientes' USING ERRCODE='42501'; END IF;
 SELECT count(*) INTO v_total FROM public.incidencias i
 WHERE (v_estado='' OR i.estado=v_estado)
 AND (v_q='' OR i.titulo ILIKE '%'||v_q||'%' OR i.comuna ILIKE '%'||v_q||'%' OR i.direccion ILIKE '%'||v_q||'%');
 SELECT coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) INTO v_items FROM (
 SELECT i.id,i.titulo,i.descripcion,i.tipo,i.direccion,i.comuna,i.prioridad,i.gravedad,
 i.estado,i.brigada_id,b.nombre AS brigada,i.creador_uid,p.nombre AS autor,
 i.creado_en,i.cerrado_en,i.lat,i.lng,
 EXISTS(SELECT 1 FROM public.informes_finales_brigada f WHERE f.reporte_id=i.id) AS tiene_informe
 FROM public.incidencias i LEFT JOIN public.brigadas b ON b.id=i.brigada_id
 LEFT JOIN public.perfiles p ON p.id=i.creador_uid
 WHERE (v_estado='' OR i.estado=v_estado)
 AND (v_q='' OR i.titulo ILIKE '%'||v_q||'%' OR i.comuna ILIKE '%'||v_q||'%' OR i.direccion ILIKE '%'||v_q||'%')
 ORDER BY i.creado_en DESC,i.id LIMIT greatest(1,least(coalesce(p_limite,30),100)) OFFSET greatest(0,coalesce(p_desde,0))
 ) q;
 RETURN jsonb_build_object('total',v_total,'items',v_items);
END; $$;

-- Se reutilizan las transiciones y verificaciones del servidor móvil.
-- En particular, cerrar requiere informe final del jefe y fotografía posterior.
CREATE OR REPLACE FUNCTION public.eco_admin_accion_incidencia(
 p_id uuid,p_nuevo text,p_brigada uuid DEFAULT NULL,p_comentario text DEFAULT ''
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_anterior text;
BEGIN
 IF NOT app.is_admin() THEN RAISE EXCEPTION 'Permisos insuficientes' USING ERRCODE='42501'; END IF;
 SELECT estado INTO v_anterior FROM public.incidencias WHERE id=p_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Incidencia inexistente'; END IF;
 PERFORM public.cambiar_estado_reporte(p_id,p_nuevo,p_brigada,p_comentario);
 INSERT INTO public.eco_admin_auditoria(actor_uid,accion,entidad,entidad_id,detalle)
 VALUES(auth.uid(),'cambio_incidencia','incidencia',p_id,
 jsonb_build_object('anterior',v_anterior,'nuevo',p_nuevo,'brigada',p_brigada,'comentario',left(coalesce(p_comentario,''),300)));
END; $$;

CREATE OR REPLACE FUNCTION public.eco_admin_jornadas(
 p_limite integer DEFAULT 50,p_desde integer DEFAULT 0
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_items jsonb;v_total bigint;
BEGIN
 IF NOT app.is_admin() THEN RAISE EXCEPTION 'Permisos insuficientes' USING ERRCODE='42501'; END IF;
 SELECT count(*) INTO v_total FROM public.actividades;
 SELECT coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) INTO v_items FROM (
  SELECT a.id,a.titulo,a.descripcion,a.estado,a.fecha_inicio,a.brigada_id,b.nombre AS brigada,
    (SELECT count(*) FROM public.actividad_participantes ap WHERE ap.actividad_id=a.id) AS participantes
  FROM public.actividades a LEFT JOIN public.brigadas b ON b.id=a.brigada_id
  ORDER BY a.fecha_inicio DESC,a.id LIMIT greatest(1,least(coalesce(p_limite,50),100)) OFFSET greatest(0,coalesce(p_desde,0))
 ) q;
 RETURN jsonb_build_object('total',v_total,'items',v_items);
END; $$;

CREATE OR REPLACE FUNCTION public.eco_admin_accion_jornada(p_jornada uuid,p_estado text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_anterior text;
BEGIN
 IF NOT app.is_admin() THEN RAISE EXCEPTION 'Permisos insuficientes' USING ERRCODE='42501'; END IF;
 SELECT estado INTO v_anterior FROM public.actividades WHERE id=p_jornada;
 IF NOT FOUND THEN RAISE EXCEPTION 'Jornada inexistente'; END IF;
 PERFORM public.eco_cambiar_estado_jornada(p_jornada,p_estado);
 INSERT INTO public.eco_admin_auditoria(actor_uid,accion,entidad,entidad_id,detalle)
 VALUES(auth.uid(),'estado_jornada','jornada',p_jornada,
 jsonb_build_object('anterior',v_anterior,'nuevo',p_estado));
END; $$;

CREATE OR REPLACE FUNCTION public.eco_admin_solicitudes(
 p_estado text DEFAULT 'pendiente',p_limite integer DEFAULT 50,p_desde integer DEFAULT 0
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_items jsonb;v_total bigint;
BEGIN
 IF NOT app.is_admin() THEN RAISE EXCEPTION 'Permisos insuficientes' USING ERRCODE='42501'; END IF;
 SELECT count(*) INTO v_total FROM public.solicitudes s
 WHERE coalesce(p_estado,'')='' OR s.estado=p_estado;
 SELECT coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) INTO v_items FROM (
 SELECT s.id,s.estado,s.mensaje,s.enviada_en,s.brigada_id,b.nombre AS brigada,
 s.usuario_id,p.nombre AS usuario,u.email
 FROM public.solicitudes s JOIN public.brigadas b ON b.id=s.brigada_id
 JOIN public.perfiles p ON p.id=s.usuario_id LEFT JOIN auth.users u ON u.id=s.usuario_id
 WHERE coalesce(p_estado,'')='' OR s.estado=p_estado
 ORDER BY s.enviada_en DESC,s.id LIMIT greatest(1,least(coalesce(p_limite,50),100)) OFFSET greatest(0,coalesce(p_desde,0))
 ) q;
 RETURN jsonb_build_object('total',v_total,'items',v_items);
END; $$;

CREATE OR REPLACE FUNCTION public.eco_admin_resolver_solicitud(p_solicitud uuid,p_aceptar boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT app.is_admin() THEN RAISE EXCEPTION 'Permisos insuficientes' USING ERRCODE='42501'; END IF;
 PERFORM public.eco_resolver_solicitud(p_solicitud,p_aceptar);
 INSERT INTO public.eco_admin_auditoria(actor_uid,accion,entidad,entidad_id,detalle)
 VALUES(auth.uid(),'resolver_solicitud','solicitud',p_solicitud,jsonb_build_object('aceptada',p_aceptar));
END; $$;

CREATE OR REPLACE FUNCTION public.eco_admin_auditoria_listar(
 p_limite integer DEFAULT 70,p_desde integer DEFAULT 0
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_items jsonb;v_total bigint;
BEGIN
 IF NOT app.is_admin() THEN RAISE EXCEPTION 'Permisos insuficientes' USING ERRCODE='42501'; END IF;
 SELECT count(*) INTO v_total FROM public.eco_admin_auditoria;
 SELECT coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) INTO v_items FROM (
 SELECT a.id,a.accion,a.entidad,a.entidad_id,a.detalle,a.creado_en,a.actor_uid,p.nombre AS actor
 FROM public.eco_admin_auditoria a LEFT JOIN public.perfiles p ON p.id=a.actor_uid
 ORDER BY a.creado_en DESC LIMIT greatest(1,least(coalesce(p_limite,70),100)) OFFSET greatest(0,coalesce(p_desde,0))
 ) q;
 RETURN jsonb_build_object('total',v_total,'items',v_items);
END; $$;

-- Estadísticas calculadas sobre TODOS los registros de la base, no sólo una página.
CREATE OR REPLACE FUNCTION public.eco_admin_estadisticas()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_result jsonb;
BEGIN
 IF NOT app.is_admin() THEN RAISE EXCEPTION 'Permisos insuficientes' USING ERRCODE='42501'; END IF;
 SELECT jsonb_build_object(
 'usuarios', (SELECT count(*) FROM public.perfiles),
 'administradores',(SELECT count(*) FROM public.perfiles WHERE role='admin'),
 'lideres',(SELECT count(DISTINCT lider_uid) FROM public.brigadas WHERE lider_uid IS NOT NULL),
 'brigadas',(SELECT count(*) FROM public.brigadas),
 'brigadas_abiertas',(SELECT count(*) FROM public.brigadas WHERE estado='abierta'),
 'integrantes',(SELECT count(*) FROM public.brigada_miembros),
 'incidencias',(SELECT count(*) FROM public.incidencias),
 'activas',(SELECT count(*) FROM public.incidencias WHERE estado NOT IN ('cerrado','descartado')),
 'cerradas',(SELECT count(*) FROM public.incidencias WHERE estado='cerrado'),
 'sin_asignar',(SELECT count(*) FROM public.incidencias WHERE estado IN ('pendiente','validado')),
 'en_revision',(SELECT count(*) FROM public.incidencias WHERE estado='en_revision'),
 'nuevas_semana',(SELECT count(*) FROM public.incidencias WHERE creado_en>=now()-interval '7 days'),
 'cerradas_semana',(SELECT count(*) FROM public.incidencias WHERE cerrado_en>=now()-interval '7 days' AND estado='cerrado'),
 'jornadas',(SELECT count(*) FROM public.actividades),
 'jornadas_finalizadas',(SELECT count(*) FROM public.actividades WHERE estado='finalizada'),
 'solicitudes_pendientes',(SELECT count(*) FROM public.solicitudes WHERE estado='pendiente'),
 'informes_finales',(SELECT count(*) FROM public.informes_finales_brigada),
 'kilos_estimados',(SELECT coalesce(round(sum(kilos_estimados),1),0) FROM public.informes_finales_brigada),
 'promedio_dias',(SELECT coalesce(round(avg((extract(epoch FROM (cerrado_en-creado_en))/86400)::numeric),1),0)
    FROM public.incidencias WHERE estado='cerrado' AND cerrado_en IS NOT NULL),
 'prioridad_promedio',(SELECT coalesce(round(avg(prioridad)::numeric,1),0) FROM public.incidencias),
 'alertas_vencidas',(SELECT count(*) FROM public.incidencias i
    WHERE i.estado NOT IN ('cerrado','descartado') AND
      i.creado_en < now()-make_interval(days => CASE WHEN i.prioridad>=70 THEN 2 WHEN i.prioridad>=40 THEN 5 ELSE 10 END)),
 'estados',(SELECT coalesce(jsonb_agg(jsonb_build_object('nombre',x.estado,'cantidad',x.cantidad)),'[]'::jsonb)
    FROM (SELECT estado,count(*) AS cantidad FROM public.incidencias GROUP BY estado ORDER BY cantidad DESC) x),
 'tipos',(SELECT coalesce(jsonb_agg(jsonb_build_object('nombre',x.tipo,'cantidad',x.cantidad)),'[]'::jsonb)
    FROM (SELECT tipo,count(*) AS cantidad FROM public.incidencias GROUP BY tipo ORDER BY cantidad DESC) x),
 'comunas',(SELECT coalesce(jsonb_agg(jsonb_build_object('nombre',x.comuna,'cantidad',x.cantidad,'activas',x.activas)),'[]'::jsonb)
    FROM (SELECT comuna,count(*) AS cantidad,count(*) FILTER (WHERE estado NOT IN ('cerrado','descartado')) AS activas
     FROM public.incidencias GROUP BY comuna ORDER BY cantidad DESC LIMIT 25) x),
 'prioridades',(SELECT coalesce(jsonb_agg(jsonb_build_object('nombre',x.etiqueta,'cantidad',x.cantidad)),'[]'::jsonb)
    FROM (SELECT CASE WHEN prioridad>=70 THEN 'Alta' WHEN prioridad>=40 THEN 'Media' ELSE 'Baja' END AS etiqueta,
       count(*) cantidad FROM public.incidencias GROUP BY 1 ORDER BY 1) x),
 'jornadas_estado',(SELECT coalesce(jsonb_agg(jsonb_build_object('nombre',x.estado,'cantidad',x.cantidad)),'[]'::jsonb)
    FROM (SELECT estado,count(*) cantidad FROM public.actividades GROUP BY estado ORDER BY estado) x),
 'brigadas_ranking',(SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) FROM (
   SELECT b.nombre,b.comuna,b.miembros,
     count(i.id) AS asignadas,count(i.id) FILTER (WHERE i.estado='cerrado') AS cerradas
   FROM public.brigadas b LEFT JOIN public.incidencias i ON i.brigada_id=b.id
   GROUP BY b.id,b.nombre,b.comuna,b.miembros ORDER BY cerradas DESC,asignadas DESC LIMIT 15
 ) x),
 'semanas',(SELECT coalesce(jsonb_agg(jsonb_build_object('semana',to_char(w.inicio,'DD/MM'),
    'reportes',r.reportes,'resueltas',r.resueltas) ORDER BY w.inicio),'[]'::jsonb)
  FROM (SELECT (date_trunc('week',now())-((11-n)*interval '1 week')) AS inicio
    FROM generate_series(0,11) AS g(n)) w
  CROSS JOIN LATERAL (SELECT
    count(*) FILTER (WHERE i.creado_en>=w.inicio AND i.creado_en<w.inicio+interval '1 week') AS reportes,
    count(*) FILTER (WHERE i.cerrado_en>=w.inicio AND i.cerrado_en<w.inicio+interval '1 week' AND i.estado='cerrado') AS resueltas
    FROM public.incidencias i) r)
 ) INTO v_result;
 RETURN v_result;
END; $$;

-- EcoAlerta: acceso paginado a TODAS las incidencias vencidas.
CREATE OR REPLACE FUNCTION public.eco_admin_alertas(p_limite integer DEFAULT 40,p_desde integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_total bigint;v_items jsonb;
BEGIN
 IF NOT app.is_admin() THEN RAISE EXCEPTION 'Permisos insuficientes' USING ERRCODE='42501'; END IF;
 SELECT count(*) INTO v_total FROM public.incidencias i
 WHERE i.estado NOT IN ('cerrado','descartado')
  AND i.creado_en < now()-make_interval(days=>CASE WHEN i.prioridad>=70 THEN 2 WHEN i.prioridad>=40 THEN 5 ELSE 10 END);
 SELECT coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) INTO v_items FROM (
 SELECT i.id,i.titulo,i.comuna,i.estado,i.prioridad,i.creado_en,
 CASE WHEN i.prioridad>=70 THEN 2 WHEN i.prioridad>=40 THEN 5 ELSE 10 END AS plazo_dias,
 round((extract(epoch FROM (now()-i.creado_en))/86400)::numeric,1) AS antiguedad_dias
 FROM public.incidencias i WHERE i.estado NOT IN ('cerrado','descartado')
  AND i.creado_en < now()-make_interval(days=>CASE WHEN i.prioridad>=70 THEN 2 WHEN i.prioridad>=40 THEN 5 ELSE 10 END)
 ORDER BY i.creado_en ASC,i.id LIMIT greatest(1,least(coalesce(p_limite,40),100)) OFFSET greatest(0,coalesce(p_desde,0))
 ) q;
 RETURN jsonb_build_object('total',v_total,'items',v_items);
END; $$;

-- EcoZonas: cuadricula aproximada ~200-250 m. Es un agrupamiento orientativo.
CREATE OR REPLACE FUNCTION public.eco_admin_zonas()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_result jsonb;
BEGIN
 IF NOT app.is_admin() THEN RAISE EXCEPTION 'Permisos insuficientes' USING ERRCODE='42501'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) INTO v_result FROM (
 SELECT i.comuna,round(avg(i.lat)::numeric,5) AS lat,round(avg(i.lng)::numeric,5) AS lng,
 count(*) AS casos,round(avg(i.prioridad)::numeric,1) AS prioridad_media,
 count(*) FILTER (WHERE i.prioridad>=70) AS alta_prioridad
 FROM public.incidencias i
 WHERE i.estado NOT IN ('cerrado','descartado')
 GROUP BY i.comuna,floor(i.lat/0.0022),floor(i.lng/0.0027)
 HAVING count(*)>=3 ORDER BY casos DESC,prioridad_media DESC LIMIT 50
 ) q;
 RETURN v_result;
END; $$;

-- EcoReincidencia: mismo tipo y a <=250m de una limpieza anterior cerrada.
-- Paginado sin inventar coincidencias; puede ser costoso con muchísimos reportes.
CREATE OR REPLACE FUNCTION public.eco_admin_reincidencias(p_limite integer DEFAULT 30,p_desde integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_total bigint;v_items jsonb;
BEGIN
 IF NOT app.is_admin() THEN RAISE EXCEPTION 'Permisos insuficientes' USING ERRCODE='42501'; END IF;
 WITH pares AS (
 SELECT i.id,i.titulo,i.comuna,i.tipo,i.creado_en,i.estado,
  anterior.id AS anterior_id,anterior.titulo AS titulo_anterior,
  anterior.distancia_m,anterior.dias
 FROM public.incidencias i
 JOIN LATERAL (
  SELECT a.id,a.titulo,
   round(app.distancia_m(a.lat,a.lng,i.lat,i.lng)::numeric,0) AS distancia_m,
   round((extract(epoch FROM (i.creado_en-a.cerrado_en))/86400)::numeric,1) AS dias
  FROM public.incidencias a
  WHERE a.estado='cerrado' AND a.tipo=i.tipo AND a.id<>i.id
    AND a.cerrado_en IS NOT NULL AND a.cerrado_en<i.creado_en
    AND app.distancia_m(a.lat,a.lng,i.lat,i.lng)<=250
  ORDER BY app.distancia_m(a.lat,a.lng,i.lat,i.lng),a.cerrado_en DESC LIMIT 1
 ) anterior ON true
 WHERE i.estado NOT IN ('cerrado','descartado')
 ) SELECT count(*) INTO v_total FROM pares;
 WITH pares AS (
 SELECT i.id,i.titulo,i.comuna,i.tipo,i.creado_en,i.estado,
  anterior.id AS anterior_id,anterior.titulo AS titulo_anterior,
  anterior.distancia_m,anterior.dias
 FROM public.incidencias i
 JOIN LATERAL (
  SELECT a.id,a.titulo,
   round(app.distancia_m(a.lat,a.lng,i.lat,i.lng)::numeric,0) AS distancia_m,
   round((extract(epoch FROM (i.creado_en-a.cerrado_en))/86400)::numeric,1) AS dias
  FROM public.incidencias a
  WHERE a.estado='cerrado' AND a.tipo=i.tipo AND a.id<>i.id
    AND a.cerrado_en IS NOT NULL AND a.cerrado_en<i.creado_en
    AND app.distancia_m(a.lat,a.lng,i.lat,i.lng)<=250
  ORDER BY app.distancia_m(a.lat,a.lng,i.lat,i.lng),a.cerrado_en DESC LIMIT 1
 ) anterior ON true
 WHERE i.estado NOT IN ('cerrado','descartado')
 ) SELECT coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) INTO v_items FROM (
  SELECT * FROM pares ORDER BY creado_en DESC,id
  LIMIT greatest(1,least(coalesce(p_limite,30),100)) OFFSET greatest(0,coalesce(p_desde,0))
 ) q;
 RETURN jsonb_build_object('total',v_total,'items',v_items);
END; $$;

-- Permisos de ejecución: siempre administrados por el servidor.
DO $$ DECLARE f record; BEGIN
 FOR f IN SELECT format('%I.%I(%s)',n.nspname,p.proname,pg_get_function_identity_arguments(p.oid)) AS sig FROM pg_proc p
 JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname IN (
  'eco_admin_usuarios',
  'eco_admin_cambiar_rol',
  'eco_admin_brigadas',
  'eco_admin_cambiar_lider',
  'eco_admin_estado_brigada',
  'eco_admin_miembros',
  'eco_admin_agregar_miembro',
  'eco_admin_quitar_miembro',
  'eco_admin_incidencias',
  'eco_admin_accion_incidencia',
  'eco_admin_jornadas',
  'eco_admin_accion_jornada',
  'eco_admin_solicitudes',
  'eco_admin_resolver_solicitud',
  'eco_admin_auditoria_listar',
  'eco_admin_estadisticas',
  'eco_admin_alertas',
  'eco_admin_zonas',
  'eco_admin_reincidencias'
 ) AND p.prokind='f'
 LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon',f.sig);
  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated',f.sig);
 END LOOP;
END $$;

-- Realtime para refrescar las pantallas automáticamente cuando cambia la aplicación.
-- No publicamos auth.users, ni perfil_datos_privados, ni la auditoría.
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['perfiles','brigadas','brigada_miembros','actividades','solicitudes','incidencias','historial_incidencias'] LOOP
  IF NOT EXISTS(SELECT 1 FROM pg_publication_tables
    WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename=t) THEN
    EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',t);
  END IF;
 END LOOP;
END $$;
COMMIT;

-- Comprobación manual opcional:
-- SELECT proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
-- WHERE n.nspname='public' AND proname LIKE 'eco_admin_%' ORDER BY proname;
