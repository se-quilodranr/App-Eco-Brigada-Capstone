/**
 * EcoBrigada Admin - Eliminación segura de cuentas
 * Desplegar como Edge Function (Supabase); NO guardar claves service_role en el panel web.
 * Mantiene el perfil anonimizado para conservar las relaciones e informes históricos.
 * Los roles se comprueban nuevamente en el servidor en cada petición.
 */
import { createSupabaseContext } from 'npm:@supabase/server@1'

const origins = new Set([
  'http://localhost:8081',
  'http://127.0.0.1:8081',
  ...((Deno.env.get('ECO_ADMIN_ALLOWED_ORIGINS') ?? '').split(',').map((s) => s.trim()).filter(Boolean)),
])

function cors(req: Request) {
  const origin = req.headers.get('origin')
  return {
    ...(origin && origins.has(origin) ? { 'Access-Control-Allow-Origin': origin } : {}),
    'Access-Control-Allow-Headers': 'authorization, apikey, x-client-info, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Vary': 'Origin',
    'Cache-Control': 'no-store',
  }
}

function json(req: Request, body: Record<string, unknown>, status = 200) {
  return Response.json(body, { status, headers: cors(req) })
}

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

export default {
  async fetch(req: Request): Promise<Response> {
    const origin = req.headers.get('origin')
    if (origin && !origins.has(origin)) return json(req, { error: 'Origen web no autorizado' }, 403)
    if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors(req) })
    if (req.method !== 'POST') return json(req, { error: 'Método no permitido' }, 405)

    // Autenticación verificada: solo acepta la sesión JWT real del administrador.
    const { data: ctx, error: sessionError } = await createSupabaseContext(req, { auth: 'user' })
    if (sessionError || !ctx) return json(req, { error: 'Debes iniciar sesión nuevamente' }, 401)
    const actor = ctx.userClaims?.id ?? ctx.jwtClaims?.sub
    if (!actor) return json(req, { error: 'Sesión no identificada' }, 401)

    const admin = ctx.supabaseAdmin
    if (!admin) return json(req, { error: 'Credenciales privadas no configuradas en Supabase' }, 503)

    // Evitar que un token JWT antiguo de una cuenta ya eliminada ejecute acciones.
    const { data: actorAuth, error: actorAuthError } = await admin.auth.admin.getUserById(actor)
    if (actorAuthError || !actorAuth?.user || actorAuth.user.deleted_at) {
      return json(req, { error: 'La cuenta administradora ya no está activa' }, 401)
    }

    const { data: actorProfile, error: actorError } = await admin
      .from('perfiles').select('role').eq('id', actor).single()
    if (actorError || actorProfile?.role !== 'admin') {
      return json(req, { error: 'Solo un administrador activo puede eliminar cuentas' }, 403)
    }

    let body: Record<string, unknown>
    try { body = await req.json() } catch { return json(req, { error: 'Solicitud JSON inválida' }, 400) }
    const target = typeof body.usuario_id === 'string' ? body.usuario_id.trim() : ''
    const email = typeof body.correo_confirmacion === 'string' ? body.correo_confirmacion.trim() : ''
    if (!uuid.test(target) || body.confirmacion !== 'ELIMINAR' || !email) {
      return json(req, { error: 'Debes confirmar el correo y escribir ELIMINAR' }, 400)
    }
    if (target === actor) return json(req, { error: 'No puedes eliminar tu propia cuenta administradora' }, 409)

    const { data: targetAuth, error: targetAuthError } = await admin.auth.admin.getUserById(target)
    if (targetAuthError || !targetAuth?.user || targetAuth.user.deleted_at) {
      return json(req, { error: 'La cuenta no existe o ya fue eliminada' }, 404)
    }
    if ((targetAuth.user.email ?? '').toLowerCase() !== email.toLowerCase()) {
      return json(req, { error: 'El correo de confirmación no corresponde al usuario' }, 400)
    }

    const { data: targetProfile, error: targetProfileError } = await admin
      .from('perfiles').select('role,id').eq('id', target).single()
    if (targetProfileError || !targetProfile) {
      return json(req, { error: 'El usuario no tiene perfil EcoBrigada' }, 409)
    }

    // Seguridad referencial: no dejar brigadas sin líder.
    const { count: leads, error: leadsError } = await admin
      .from('brigadas').select('id', { count: 'exact', head: true }).eq('lider_uid', target)
    if (leadsError) return json(req, { error: 'No se pudo comprobar la jefatura; no se eliminó nada' }, 503)
    if ((leads ?? 0) > 0) {
      return json(req, { error: `Primero debes reasignar ${leads} brigada(s) que lidera esta persona` }, 409)
    }

    if (targetProfile.role === 'admin') {
      const { count: admins, error: countError } = await admin
        .from('perfiles').select('id', { count: 'exact', head: true }).eq('role', 'admin')
      if (countError || admins === null) return json(req, { error: 'No fue posible verificar administradores' }, 503)
      if (admins <= 1) return json(req, { error: 'No se puede eliminar al último administrador' }, 409)
    }

    // Eliminar acceso de Auth. Soft delete (irreversible): conserva referencias
    // de auth.users para evitar romper incidencias, chats y otras FK existentes.
    const { error: deletionError } = await admin.auth.admin.deleteUser(target, true)
    if (deletionError) {
      console.error('Supabase Auth rechazó la eliminación:', deletionError.message)
      return json(req, { error: 'No se pudo eliminar la cuenta en Supabase Auth. Revisa los logs y sus archivos en Storage.' }, 409)
    }

    // Eliminar datos privados y pertenencias, sin borrar la historia ambiental.
    // Si alguna limpieza falla, informamos: Auth ya fue eliminado de forma irreversible.
    const advertencias: string[] = []
    const privateResult = await admin.from('perfil_datos_privados').delete().eq('usuario_id', target)
    if (privateResult.error) advertencias.push('No se pudieron borrar los datos privados adicionales')
    const membershipsResult = await admin.from('brigada_miembros').delete().eq('usuario_id', target)
    if (membershipsResult.error) advertencias.push('No se pudieron retirar algunas membresías')
    const profileResult = await admin.from('perfiles').update({
      nombre: 'Cuenta eliminada', role: 'ciudadano', avatar_path: null,
    }).eq('id', target)
    if (profileResult.error) advertencias.push('No se pudo anonimizar el perfil público')

    const auditResult = await admin.from('eco_admin_auditoria').insert({
      actor_uid: actor,
      accion: 'eliminar_cuenta_auth',
      entidad: 'perfil',
      entidad_id: target,
      detalle: { metodo: 'soft_delete_auth', historial_conservado: true, advertencias },
    })
    if (auditResult.error) advertencias.push('No se pudo registrar la auditoría de eliminación')

    return json(req, { ok: true, advertencias })
  },
}
