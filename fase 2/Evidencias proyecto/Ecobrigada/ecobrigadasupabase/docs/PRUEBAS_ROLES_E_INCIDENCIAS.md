# EcoBrigada 3.1: procedimiento de validación para Capstone

## Orden de instalación

1. **Respalda tu proyecto y la base de datos**. En SQL Editor, verifica que ya existen `perfiles`, `brigadas`, `incidencias`, `solicitudes`, `actividades` y `fotos_incidencia` con `to_regclass`. Si faltan tablas, aplica primero los SQL previos; no vuelvas a ejecutar el esquema `01_esquema.sql` sobre una base existente.
2. Ejecuta `supabase/migrations/202611180001_roles_jefes_informes.sql` en Supabase SQL Editor (después de las migraciones de noviembre 17).
3. Ejecuta `supabase/admin/202611180002_promover_seba_admin.sql` **desde la sesión del propietario de Supabase**, NO desde la aplicación. Este archivo solo promueve `seba@gmail.com` si ya existe en Auth. No modifica su contraseña.
4. En una máquina de confianza, ejecuta `scripts/provisionar_usuarios_prueba.py` con `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` en el entorno **solo del proceso local**. Se crean 20 jefes y 6 ciudadanos de prueba con correos `example.com` no entregables. Las contraseñas se escriben a `CREDENCIALES_LIDERES_SOLO_LOCAL.json` fuera del repositorio: no compartas ese archivo.
5. Ejecuta **opcionalmente** `supabase/fixtures/202611180003_datos_capstone_integrales.sql` para crear datos sintéticos, preferentemente en una copia de tu base. Inserta 9 brigadas nuevas, jefaturas distintas para 7 brigadas ficticias previas (si existen), 36 jornadas, 240 incidencias, 12 lugares, 12 marcadores de reciclaje NO verificados, 18 mensajes iniciales y solicitudes pendientes de integrantes ficticios. No reconfigura jefaturas de brigadas reales.
6. Ejecuta el diagnóstico **de solo lectura** `supabase/tests/202611180004_diagnostico_roles_datos.sql`.
7. Ejecuta Flutter con la clave pública: `flutter pub get`, `flutter analyze`, `flutter test`, `flutter run -d web-server --web-port 8080 --dart-define-from-file=supabase_config.json`.

### Reglas del flujo

- **Ciudadano**: registra incidencias, consulta EcoMapa, crea una brigada propia (en ese momento pasa a ser su jefe), solicita incorporarse a equipos ajenos y consulta estadísticas comunitarias. No puede aprobar su propia solicitud a otra brigada ni entrar al chat sin membresía.
- **Jefe de brigada**: cuenta auténtica de Supabase Auth, vinculada por `brigadas.lider_uid`. Acepta o rechaza solicitudes de su brigada; ve su chat; programa jornadas; inicia la limpieza asignada; adjunta imagen posterior y envía informe final con descripción y participantes. No puede validar su propia limpieza como administrador.
- **Administrador global**: `perfiles.role = 'admin'` asignado por propietario. Puede validar, asignar, consultar todos los chats, revisar evidencias y cerrar o devolver limpiezas. No puede hacerse pasar por el jefe para remitir el informe final.

### Escenarios verificables

| Caso | Prueba | Resultado esperado |
|---|---|---|
| P1 | Iniciar sesión con `seba@gmail.com` | Se habilita administración; verificar `perfiles.role` |
| P2 | Entrar con `ciudadano01` e intentar leer chat de una brigada donde hay solicitud pendiente | Acceso bloqueado por RLS |
| P3 | Iniciar como jefe `lider04` y aprobar solicitud a su equipo | Se registra membresía y cambia el estado |
| P4 | Entrar con el ciudadano cuya solicitud se aprobó | Puede leer y escribir únicamente en chats autorizados |
| P5 | Iniciar como líder `lider01`, abrir incidencia asignada en ejecución | Puede subir foto posterior y enviar informe final de limpieza |
| P6 | Intentar enviar informe sin foto posterior | RPC rechaza operación y no cambia el estado |
| P7 | Iniciar como administrador e intentar remitir informe final de una brigada ficticia | SQL rechaza suplantación de jefatura |
| P8 | Como administrador, revisar una incidencia con informe y foto | Puede cerrar con observación o devolverla a ejecución |
| P9 | EcoImpacto: usar filtros sobre registros `[FICTICIO]` | Presenta cantidades y vencimientos derivados de fechas sintéticas |
| P10 | EcoZonas/EcoReincidencia: consultar agrupaciones y pares por fechas | Los resultados deben coincidir con el historial ficticio |

### Advertencias técnicas

- Los **datos de prueba** no representan denuncias, organizaciones, instalaciones de reciclaje ni limpiezas reales. Los puntos de reciclaje sintéticos se guardan con `verificado=false`; por defecto solo el administrador puede verlos hasta que exista validación.
- Las incidencias ficticias cerradas **no tienen evidencia fotográfica real ni informe final auténtico**; sirven para probar estadística, no para afirmar que hubo limpiezas.
- El estado `en_revision` creado por los datos sintéticos no puede cerrarse mediante el nuevo flujo sin un informe final y fotografía realmente adjuntada. Para probar un cierre real usa una incidencia creada y trabajada por usuarios autenticados.
- Los jefes inventados son identidades de pruebas creadas en Supabase Auth, no personas existentes. No utilizar sus direcciones reservadas para correo real.
- La migración y la carga NO están desplegadas automáticamente. Los resultados no pueden certificarse hasta ejecutar los scripts, las pruebas de Flutter y las verificaciones de RLS sobre la instancia del usuario.
