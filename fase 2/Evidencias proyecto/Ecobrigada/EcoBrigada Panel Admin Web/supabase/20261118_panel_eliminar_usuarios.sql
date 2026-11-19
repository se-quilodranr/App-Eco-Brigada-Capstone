-- EcoBrigada 3.1 - Eliminacion segura de cuentas administrativas
-- Ejecutar DESPUES de la migracion original 20261118_panel_admin.sql.
-- No borra usuarios al aplicarse: solo actualiza las vistas/RPC para excluir
-- del directorio a quienes hayan sido eliminados desde Supabase Auth.
BEGIN;

CREATE OR REPLACE FUNCTION public.eco_admin_usuarios(
 p_buscar text DEFAULT '', p_limite integer DEFAULT 30, p_desde integer DEFAULT 0
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_total bigint; v_items jsonb; v_q text := left(trim(coalesce(p_buscar,'')),100);
BEGIN
 IF NOT app.is_admin() THEN RAISE EXCEPTION 'Acceso restringido a administración' USING ERRCODE='42501'; END IF;
 SELECT count(*) INTO v_total FROM auth.users u JOIN public.perfiles p ON p.id=u.id
 WHERE u.deleted_at IS NULL AND (v_q='' OR p.nombre ILIKE '%'||v_q||'%' OR u.email ILIKE '%'||v_q||'%');
 SELECT coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) INTO v_items FROM (
   SELECT u.id,u.email,p.nombre,p.role,p.creado_en,
    (SELECT count(*) FROM public.brigadas b WHERE b.lider_uid=u.id) AS lidera,
    (SELECT count(*) FROM public.brigada_miembros m WHERE m.usuario_id=u.id) AS pertenece,
    (SELECT count(*) FROM public.incidencias i WHERE i.creador_uid=u.id) AS reportes
   FROM auth.users u JOIN public.perfiles p ON p.id=u.id
   WHERE u.deleted_at IS NULL AND (v_q='' OR p.nombre ILIKE '%'||v_q||'%' OR u.email ILIKE '%'||v_q||'%')
   ORDER BY p.creado_en DESC,u.id
   LIMIT greatest(1,least(coalesce(p_limite,30),100)) OFFSET greatest(0,coalesce(p_desde,0))
 ) q;
 RETURN jsonb_build_object('total',v_total,'items',v_items);
END; $$;

CREATE OR REPLACE FUNCTION public.eco_admin_estadisticas()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_result jsonb;
BEGIN
 IF NOT app.is_admin() THEN RAISE EXCEPTION 'Permisos insuficientes' USING ERRCODE='42501'; END IF;
 SELECT jsonb_build_object(
 'usuarios', (SELECT count(*) FROM auth.users u JOIN public.perfiles p ON p.id=u.id WHERE u.deleted_at IS NULL),
 'administradores',(SELECT count(*) FROM auth.users u JOIN public.perfiles p ON p.id=u.id WHERE u.deleted_at IS NULL AND p.role='admin'),
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
-- Conservar el control original de permisos de estas funciones.
REVOKE ALL ON FUNCTION public.eco_admin_usuarios(text,integer,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.eco_admin_usuarios(text,integer,integer) TO authenticated;
REVOKE ALL ON FUNCTION public.eco_admin_estadisticas() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.eco_admin_estadisticas() TO authenticated;

COMMIT;
