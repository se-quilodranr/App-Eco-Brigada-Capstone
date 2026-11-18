import 'models.dart';

/// Solo miembros aprobados, el líder del equipo o administración.
/// La decisión definitiva para datos reales la toman las políticas RLS de Supabase.
bool puedeLeerChatBrigada({required String uid, required bool administrador,
  required Brigada brigada, required Iterable<IntegranteBrigada> integrantes}) {
  if (uid.isEmpty) return false;
  return administrador || brigada.liderUid == uid || integrantes.any((m) =>
    m.brigadaId == brigada.id && m.uid == uid);
}
