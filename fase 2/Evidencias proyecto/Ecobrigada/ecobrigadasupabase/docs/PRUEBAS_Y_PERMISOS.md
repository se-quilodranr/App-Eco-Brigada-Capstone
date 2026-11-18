# Checklist de validación en tu Supabase real

- [ ] La migración SQL finalizó sin errores.
- [ ] Los usuarios antiguos conservan su inicio de sesión y perfiles.
- [ ] Las publicaciones/guías antiguas, likes y fotos siguen disponibles.
- [ ] Las brigadas antiguas, integrantes, solicitudes y chats siguen disponibles.
- [ ] Ciudadano no miembro no puede leer ni enviar mensajes de otra brigada, incluyendo vía API REST.
- [ ] Miembro aprobado puede leer y escribir en su chat.
- [ ] Líder puede gestionar su brigada y programar jornada con coordenadas registradas.
- [ ] Administrador global puede consultar chats y decidir solicitudes de cualquier brigada.
- [ ] Ciudadano no puede cambiar `perfiles.role`, ni `brigadas.lider_uid` desde la API.
- [ ] Usuario puede crear una incidencia con descripción, tipo, gravedad y GPS.
- [ ] EcoRadar detecta reportes abiertos cercanos del mismo tipo.
- [ ] El sistema solicita fotografía posterior antes de enviar una incidencia a revisión.
- [ ] Una persona sin permisos no puede descargar evidencias privadas mediante Storage.
- [ ] El administrador puede aprobar/devolver una limpieza con observación.
- [ ] EcoMapa muestra estados de incidencia, lugares anteriores, brigadas con GPS y reciclaje verificado.
- [ ] Alternar un `lugar` entre `limpio` y `sucio` crea registros en `lugar_historial`.
- [ ] EcoImpacto calcula reaparición desde esos eventos sin reportar fechas inventadas.
- [ ] Notificaciones internas y chats se actualizan entre dos sesiones.
- [ ] PDF/CSV se exportan solo como administrador.
- [ ] Registro sin conexión y posterior sincronización no crea duplicados.
- [ ] `flutter analyze` termina sin errores.
- [ ] `flutter test` termina correctamente.

**Observación:** marcar una casilla solo después de probarla en tu proyecto Supabase; este documento no afirma que todas las pruebas se hayan ejecutado.
